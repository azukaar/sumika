package storage

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// getExecutableDir returns the directory of the current executable
func getExecutableDir() (string, error) {
    exePath, err := os.Executable()
    if err != nil {
        return "", err
    }
    // Resolve any symlinks
    exePath, err = filepath.EvalSymlinks(exePath)
    if err != nil {
        return "", err
    }
    return filepath.Dir(exePath), nil
}

// buildPath constructs a path relative to the executable directory
func buildPath(relativePath string) string {
    execDir, err := getExecutableDir()
    if err != nil {
        fmt.Printf("⚠️  Failed to get executable directory, using relative path: %v", err)
        return relativePath
    }
    return filepath.Join(execDir, relativePath)
}

// DeviceProperty represents a single property with its capabilities
type DeviceProperty struct {
	Name         string            `json:"name"`
	Type         string            `json:"type"`           // binary, numeric, enum
	Access       int               `json:"access"`         // 1=read, 2=write, 4=state_set
	IsReadable   bool              `json:"is_readable"`
	IsWritable   bool              `json:"is_writable"`
	MinValue     *float64          `json:"min_value,omitempty"`
	MaxValue     *float64          `json:"max_value,omitempty"`
	Unit         string            `json:"unit,omitempty"`
	Values       []string          `json:"values,omitempty"`      // For enums
	Presets      []DevicePreset    `json:"presets,omitempty"`     // For numeric with presets
	Commands     []string          `json:"commands"`              // Voice commands for this property
}

type DevicePreset struct {
	Name        string  `json:"name"`
	Value       float64 `json:"value"`
	Description string  `json:"description,omitempty"`
}

// Device represents a single device with all its information
type Device struct {
	FriendlyName   string            `json:"friendly_name"`
	IEEEAddress    string            `json:"ieee_address"`
	CustomName     string            `json:"custom_name,omitempty"`
	Zones          []string          `json:"zones"`
	Properties     []DeviceProperty  `json:"properties"`      // Detailed property info with commands
	VoicePatterns  []string          `json:"voice_patterns"`  // How users can refer to this device
}

// VoiceIntentData represents the structure that matches intent.py format
type VoiceIntentData struct {
	IntentPatterns   map[string][]string            `json:"intent_patterns"`
	EntityPatterns   map[string]map[string]string   `json:"entity_patterns"`
	Devices          []Device                       `json:"devices"`              // Clean list of all devices with property-specific commands
	Zones            map[string][]string            `json:"zones"`               // zone -> [friendly_names]
}

// VoiceIntentGenerator generates voice intents from storage data
type VoiceIntentGenerator struct {
	assetsPath string
}

// NewVoiceIntentGenerator creates a new voice intent generator
func NewVoiceIntentGenerator() *VoiceIntentGenerator {
	return &VoiceIntentGenerator{
		assetsPath: buildPath(filepath.Join("assets", "voice")),
	}
}

// GenerateIntents generates voice intents from storage data and saves to JSON
func (g *VoiceIntentGenerator) GenerateIntents() error {
	intents := g.createIntentData()
	return g.saveIntents(intents)
}

// createIntentData creates the intent data structure from storage data
func (g *VoiceIntentGenerator) createIntentData() *VoiceIntentData {
	devices, zones := g.createDevicesAndZones()
	
	intents := &VoiceIntentData{
		IntentPatterns:   g.createIntentPatterns(),
		EntityPatterns:   g.createEntityPatterns(devices),
		Devices:          devices,
		Zones:            zones,
	}
	return intents
}

// createDevicesAndZones creates clean device list and zone mappings
func (g *VoiceIntentGenerator) createDevicesAndZones() ([]Device, map[string][]string) {
	var devices []Device
	zones := make(map[string][]string)
	
	// Get all devices from cache
	deviceCache := GetDeviceCache()
	for _, deviceData := range deviceCache {
		if friendlyName, ok := deviceData["friendly_name"].(string); ok {
			// Get IEEE address
			ieeeAddr := ""
			if addr, exists := deviceData["ieee_address"]; exists {
				if addrStr, ok := addr.(string); ok {
					ieeeAddr = addrStr
				}
			}
			
			// Get custom name if it exists
			customName := ""
			if metadata, exists := GetDeviceMetadata(friendlyName); exists {
				if custom, hasCustom := metadata["custom_name"]; hasCustom {
					customName = custom
				}
			}
			
			// Get device zones
			deviceZones := GetDeviceZones(friendlyName)
			
			// Get detailed device properties with commands
			properties := g.createDeviceProperties(friendlyName)
			
			// Create voice patterns (how users can refer to this device)
			voicePatterns := g.createVoicePatterns(friendlyName, customName)
			
			device := Device{
				FriendlyName:  friendlyName,
				IEEEAddress:   ieeeAddr,
				CustomName:    customName,
				Zones:         deviceZones,
				Properties:    properties,
				VoicePatterns: voicePatterns,
			}
			
			devices = append(devices, device)
		}
	}
	
	// Create zone mappings
	allZones := GetAllZones()
	for _, zone := range allZones {
		devicesInZone := []string{}
		for _, device := range devices {
			for _, deviceZone := range device.Zones {
				if deviceZone == zone {
					devicesInZone = append(devicesInZone, device.FriendlyName)
					break
				}
			}
		}
		zones[zone] = devicesInZone
	}
	
	return devices, zones
}

// createDeviceProperties creates detailed property information for a device
func (g *VoiceIntentGenerator) createDeviceProperties(friendlyName string) []DeviceProperty {
	var properties []DeviceProperty
	
	// Get the actual expose definitions for this device
	exposes := g.getDeviceExposes(friendlyName)
	
	for _, expose := range exposes {
		deviceProps := g.parseExposeToProperties(expose)
		properties = append(properties, deviceProps...)
	}
	
	return properties
}

// parseExposeToProperties converts an expose definition to DeviceProperty objects
func (g *VoiceIntentGenerator) parseExposeToProperties(expose interface{}) []DeviceProperty {
	var properties []DeviceProperty
	
	exposeMap, ok := expose.(map[string]interface{})
	if !ok {
		return properties
	}
	
	// Handle expose with features (like lights)
	if features, hasFeatures := exposeMap["features"].([]interface{}); hasFeatures {
		for _, feature := range features {
			properties = append(properties, g.parseExposeToProperties(feature)...)
		}
		return properties
	}
	
	// Parse single property
	property := g.parseExposeProperty(exposeMap)
	if property.Name != "" {
		properties = append(properties, property)
	}
	
	return properties
}

// parseExposeProperty parses a single expose definition into a DeviceProperty
func (g *VoiceIntentGenerator) parseExposeProperty(expose map[string]interface{}) DeviceProperty {
	property := DeviceProperty{}
	
	// Get basic info
	if name, hasName := expose["property"].(string); hasName {
		property.Name = name
	}
	
	if propType, hasType := expose["type"].(string); hasType {
		property.Type = propType
	}
	
	// Get access level
	if access, hasAccess := expose["access"].(float64); hasAccess {
		property.Access = int(access)
		property.IsReadable = property.Access&1 != 0
		property.IsWritable = property.Access&2 != 0
	}
	
	// Get unit
	if unit, hasUnit := expose["unit"].(string); hasUnit {
		property.Unit = unit
	}
	
	// Type-specific parsing
	switch property.Type {
	case "numeric":
		g.parseNumericProperty(expose, &property)
	case "enum":
		g.parseEnumProperty(expose, &property)
	case "binary":
		g.parseBinaryProperty(expose, &property)
	}
	
	// Generate commands for this property
	property.Commands = g.generatePropertyCommands(property)
	
	return property
}

// parseNumericProperty parses numeric-specific fields
func (g *VoiceIntentGenerator) parseNumericProperty(expose map[string]interface{}, property *DeviceProperty) {
	if minVal, hasMin := expose["value_min"].(float64); hasMin {
		property.MinValue = &minVal
	}
	if maxVal, hasMax := expose["value_max"].(float64); hasMax {
		property.MaxValue = &maxVal
	}
	
	// Parse presets
	if presets, hasPresets := expose["presets"].([]interface{}); hasPresets {
		for _, preset := range presets {
			if presetMap, ok := preset.(map[string]interface{}); ok {
				devicePreset := DevicePreset{}
				if name, hasName := presetMap["name"].(string); hasName {
					devicePreset.Name = name
				}
				if value, hasValue := presetMap["value"].(float64); hasValue {
					devicePreset.Value = value
				}
				if desc, hasDesc := presetMap["description"].(string); hasDesc {
					devicePreset.Description = desc
				}
				property.Presets = append(property.Presets, devicePreset)
			}
		}
	}
}

// parseEnumProperty parses enum-specific fields
func (g *VoiceIntentGenerator) parseEnumProperty(expose map[string]interface{}, property *DeviceProperty) {
	if values, hasValues := expose["values"].([]interface{}); hasValues {
		for _, value := range values {
			if valueStr, ok := value.(string); ok {
				property.Values = append(property.Values, valueStr)
			}
		}
	}
}

// parseBinaryProperty parses binary-specific fields
func (g *VoiceIntentGenerator) parseBinaryProperty(expose map[string]interface{}, property *DeviceProperty) {
	// Binary properties have value_on, value_off, value_toggle
	if onVal, hasOn := expose["value_on"].(string); hasOn {
		property.Values = append(property.Values, onVal)
	}
	if offVal, hasOff := expose["value_off"].(string); hasOff {
		property.Values = append(property.Values, offVal)
	}
	if toggleVal, hasToggle := expose["value_toggle"].(string); hasToggle {
		property.Values = append(property.Values, toggleVal)
	}
}

// generatePropertyCommands generates voice commands for a specific property
func (g *VoiceIntentGenerator) generatePropertyCommands(property DeviceProperty) []string {
	// Only generate commands for writable properties
	if !property.IsWritable {
		return []string{}
	}
	
	var commands []string
	commandSet := make(map[string]bool)
	
	addCommand := func(cmd string) {
		if !commandSet[cmd] {
			commands = append(commands, cmd)
			commandSet[cmd] = true
		}
	}
	
	switch property.Type {
	case "binary":
		addCommand("turn on {device}")
		addCommand("turn off {device}")
		addCommand("switch on {device}")
		addCommand("switch off {device}")
		addCommand("toggle {device}")
		
	case "numeric":
		// Relative commands
		addCommand("brighter {device}")
		addCommand("dimmer {device}")
		addCommand("louder {device}")
		addCommand("quieter {device}")
		addCommand("warmer {device}")
		addCommand("cooler {device}")
		addCommand("faster {device}")
		addCommand("slower {device}")
		addCommand("higher {device}")
		addCommand("lower {device}")
		addCommand("increase {device}")
		addCommand("decrease {device}")
		
		// Absolute commands
		addCommand("set {device} to {intensity}")
		addCommand("set {device} " + property.Name + " to {intensity}")
		
		// Preset commands
		for _, preset := range property.Presets {
			addCommand("set {device} to " + preset.Name)
			addCommand("set to " + preset.Name)
		}
		
	case "enum":
		for _, value := range property.Values {
			addCommand("set {device} to " + value)
			addCommand("set " + value)
			addCommand(value + " {device}")
		}
	}
	
	return commands
}

// createVoicePatterns creates voice patterns for how users can refer to a device
func (g *VoiceIntentGenerator) createVoicePatterns(friendlyName, customName string) []string {
	patterns := []string{}
	
	// Only add custom name pattern (user-friendly name)
	if customName != "" {
		patterns = append(patterns, g.createDeviceRegex(customName))
	} else if friendlyName != "" && !g.isIEEEAddress(friendlyName) {
		// Only add friendly name if it's not an IEEE address
		patterns = append(patterns, g.createDeviceRegex(friendlyName))
	}
	
	return patterns
}

// isIEEEAddress checks if a string looks like an IEEE address
func (g *VoiceIntentGenerator) isIEEEAddress(name string) bool {
	// IEEE addresses start with 0x and are 16 hex characters
	return len(name) == 18 && name[:2] == "0x"
}

// createIntentPatterns creates static intent patterns
func (g *VoiceIntentGenerator) createIntentPatterns() map[string][]string {
	return map[string][]string{
		"switch_on": {
			"switch on|turn on|activate|enable",
			"light up|illuminate",
		},
		"switch_off": {
			"switch off|turn off|deactivate|disable",
			"shut off",
		},
		"dim": {
			"dim|lower|reduce brightness",
			"make.*darker",
		},
		"brighten": {
			"brighten|increase brightness|make.*brighter",
			"set brightness.*high",
		},
		"set_brightness": {
			"set brightness to|brightness to|set.*brightness.*to",
		},
		"set_color": {
			"set color to|change color to|make.*color",
		},
	}
}

// createEntityPatterns creates entity patterns from devices
func (g *VoiceIntentGenerator) createEntityPatterns(devices []Device) map[string]map[string]string {
	entities := map[string]map[string]string{
		"device":    g.createDevicePatterns(devices),
		"location":  g.createLocationPatterns(),
		"intensity": g.createIntensityPatterns(),
		"color":     g.createColorPatterns(),
	}
	return entities
}

// createDevicePatterns creates device patterns from devices list
func (g *VoiceIntentGenerator) createDevicePatterns(devices []Device) map[string]string {
	patterns := make(map[string]string)
	
	// Add generic device patterns
	patterns["light"] = "light[s]?"
	patterns["lights"] = "lights|all\\s+light[s]?"
	patterns["lamp"] = "lamp[s]?"
	patterns["switch"] = "switch[es]?"
	
	// Add patterns for each device
	for _, device := range devices {
		// Add friendly name pattern
		cleanName := g.cleanDeviceName(device.FriendlyName)
		if cleanName != "" {
			patterns[cleanName] = g.createDeviceRegex(device.FriendlyName)
		}
		
		// Add custom name pattern if it exists
		if device.CustomName != "" {
			customClean := g.cleanDeviceName(device.CustomName)
			if customClean != "" {
				patterns[customClean] = g.createDeviceRegex(device.CustomName)
			}
		}
	}
	
	return patterns
}

// createLocationPatterns creates location patterns from zones
func (g *VoiceIntentGenerator) createLocationPatterns() map[string]string {
	locations := make(map[string]string)
		
	// Add zones from storage using storage function
	zones := GetAllZones()
	for _, zone := range zones {
		if zone != "" {
			cleanZone := g.cleanZoneName(zone)
			pattern := g.createZoneRegex(zone)
			locations[cleanZone] = pattern
		}
	}
	
	return locations
}

// createIntensityPatterns creates intensity patterns for brightness/levels
func (g *VoiceIntentGenerator) createIntensityPatterns() map[string]string {
	return map[string]string{
		"percentage": "(\\d+)\\s*%|(\\d+)\\s*percent",
		"level":      "level\\s*(\\d+)|brightness\\s*(\\d+)",
	}
}

// createColorPatterns creates color patterns
func (g *VoiceIntentGenerator) createColorPatterns() map[string]string {
	return map[string]string{
		"red":    "red",
		"blue":   "blue",
		"green":  "green",
		"yellow": "yellow",
		"white":  "white",
		"warm":   "warm|warm\\s*white",
		"cool":   "cool|cool\\s*white|cold",
		"purple": "purple|violet",
		"orange": "orange",
		"pink":   "pink",
	}
}

// getDeviceExposes gets the expose definitions for a device
func (g *VoiceIntentGenerator) getDeviceExposes(friendlyName string) []interface{} {
	deviceCache := GetDeviceCache()
	for _, device := range deviceCache {
		if name, exists := device["friendly_name"]; exists && name == friendlyName {
			if definition, hasDefinition := device["definition"].(map[string]interface{}); hasDefinition {
				if exposes, hasExposes := definition["exposes"].([]interface{}); hasExposes {
					return exposes
				}
			}
		}
	}
	return []interface{}{}
}

// Helper functions for cleaning and creating regex patterns

// cleanDeviceName cleans device name for use as entity key
func (g *VoiceIntentGenerator) cleanDeviceName(name string) string {
	// Convert to lowercase and replace spaces/special chars with underscores
	clean := strings.ToLower(name)
	reg := regexp.MustCompile(`[^a-z0-9]+`)
	clean = reg.ReplaceAllString(clean, "_")
	clean = strings.Trim(clean, "_")
	return clean
}

// cleanZoneName cleans zone name for use as entity key
func (g *VoiceIntentGenerator) cleanZoneName(name string) string {
	return g.cleanDeviceName(name) // Same logic
}

// createDeviceRegex creates regex pattern for device name matching
func (g *VoiceIntentGenerator) createDeviceRegex(deviceName string) string {
	// Escape special regex characters and make flexible matching
	escaped := regexp.QuoteMeta(strings.ToLower(deviceName))
	// Replace spaces with flexible space matching
	flexible := strings.ReplaceAll(escaped, `\ `, `[\\s_]*`)
	// Add optional 's' for plurals
	if !strings.HasSuffix(flexible, "s") {
		flexible += "[s]?"
	}
	return flexible
}

// createZoneRegex creates regex pattern for zone name matching
func (g *VoiceIntentGenerator) createZoneRegex(zoneName string) string {
	// Similar to device regex but for zone names
	escaped := regexp.QuoteMeta(strings.ToLower(zoneName))
	flexible := strings.ReplaceAll(escaped, `\ `, `\\s*`)
	return flexible
}

// saveIntents saves the intent data to JSON file
func (g *VoiceIntentGenerator) saveIntents(intents *VoiceIntentData) error {
	// Create the intents.json path in the voice assets directory
	intentsPath := filepath.Join(g.assetsPath, "intents.json")
	
	// Marshal to JSON with proper formatting
	jsonData, err := json.MarshalIndent(intents, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal intents to JSON: %w", err)
	}
	
	// Ensure directory exists
	if err := os.MkdirAll(filepath.Dir(intentsPath), 0755); err != nil {
		return fmt.Errorf("failed to create intents directory: %w", err)
	}
	
	// Write to file
	if err := os.WriteFile(intentsPath, jsonData, 0644); err != nil {
		return fmt.Errorf("failed to write intents file: %w", err)
	}
	
	fmt.Printf("Generated voice intents: %s\n", intentsPath)
	return nil
}