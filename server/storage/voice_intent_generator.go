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
	Name         string                 `json:"name"`
	Type         string                 `json:"type"`           // binary, numeric, enum
	Access       int                    `json:"access"`         // 1=read, 2=write, 4=state_set
	IsReadable   bool                   `json:"is_readable"`
	IsWritable   bool                   `json:"is_writable"`
	MinValue     *float64               `json:"min_value,omitempty"`
	MaxValue     *float64               `json:"max_value,omitempty"`
	Unit         string                 `json:"unit,omitempty"`
	Values       []string               `json:"values,omitempty"`      // For enums
	Presets      []DevicePreset         `json:"presets,omitempty"`     // For numeric with presets
	Commands     map[string]interface{} `json:"commands"`              // Voice commands mapped to resulting states
	CurrentValue interface{}            `json:"current_value,omitempty"` // Current state of the property
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
	Categories     []string          `json:"categories"`      // Device category with synonyms
	Zones          []string          `json:"zones"`
	Properties     []DeviceProperty  `json:"properties"`      // Detailed property info with commands
	VoicePatterns  []string          `json:"voice_patterns"`  // How users can refer to this device
}

// VoiceIntentData represents the structure that matches intent.py format
type VoiceIntentData struct {
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
			
			// Get device category and its synonyms
			category := g.getDeviceCategory(friendlyName, deviceData)
			categories := g.getCategoryWithSynonyms(category)
			
			device := Device{
				FriendlyName:  friendlyName,
				IEEEAddress:   ieeeAddr,
				CustomName:    customName,
				Categories:    categories,
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
	
	// Get current device state
	deviceState := g.getDeviceState(friendlyName)
	
	for _, expose := range exposes {
		deviceProps := g.parseExposeToProperties(expose, deviceState)
		properties = append(properties, deviceProps...)
	}
	
	return properties
}

// parseExposeToProperties converts an expose definition to DeviceProperty objects
func (g *VoiceIntentGenerator) parseExposeToProperties(expose interface{}, deviceState map[string]interface{}) []DeviceProperty {
	var properties []DeviceProperty
	
	exposeMap, ok := expose.(map[string]interface{})
	if !ok {
		return properties
	}
	
	// Handle expose with features (like lights)
	if features, hasFeatures := exposeMap["features"].([]interface{}); hasFeatures {
		for _, feature := range features {
			properties = append(properties, g.parseExposeToProperties(feature, deviceState)...)
		}
		return properties
	}
	
	// Parse single property
	property := g.parseExposeProperty(exposeMap, deviceState)
	if property.Name != "" {
		properties = append(properties, property)
	}
	
	return properties
}

// parseExposeProperty parses a single expose definition into a DeviceProperty
func (g *VoiceIntentGenerator) parseExposeProperty(expose map[string]interface{}, deviceState map[string]interface{}) DeviceProperty {
	property := DeviceProperty{}
	
	// Get basic info
	if name, hasName := expose["property"].(string); hasName {
		property.Name = name
		// Get current value for THIS specific property from device state
		if deviceState != nil {
			// The actual property values are nested under deviceState["state"]
			// e.g., deviceState["state"]["brightness"], deviceState["state"]["state"], etc.
			if stateMap, hasState := deviceState["state"].(map[string]interface{}); hasState {
				if currentVal, hasVal := stateMap[name]; hasVal {
					property.CurrentValue = currentVal
				}
			}
		}
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
func (g *VoiceIntentGenerator) generatePropertyCommands(property DeviceProperty) map[string]interface{} {
	// Only generate commands for writable properties
	if !property.IsWritable {
		return map[string]interface{}{}
	}
	
	commands := make(map[string]interface{})
	
	switch property.Type {
	case "binary":
		// For binary properties, determine on/off values
		var onValue, offValue interface{}
		onValue = true  // default
		offValue = false // default
		
		// Check if specific values are defined
		if len(property.Values) >= 2 {
			for _, val := range property.Values {
				valLower := strings.ToLower(val)
				if valLower == "on" {
					onValue = val
				} else if valLower == "off" {
					offValue = val
				}
			}
		}
		
		commands["turn on"] = onValue
		commands["turn off"] = offValue
		commands["switch on"] = onValue
		commands["switch off"] = offValue
		commands["toggle"] = "TOGGLE" // Special value to indicate toggle
		
	case "numeric":
		// Get current value as float
		var currentValue float64
		if property.CurrentValue != nil {
			switch v := property.CurrentValue.(type) {
			case float64:
				currentValue = v
			case int:
				currentValue = float64(v)
			case int64:
				currentValue = float64(v)
			default:
				// If we can't get current value, use midpoint
				if property.MinValue != nil && property.MaxValue != nil {
					currentValue = (*property.MinValue + *property.MaxValue) / 2
				}
			}
		} else if property.MinValue != nil && property.MaxValue != nil {
			// No current value, use midpoint
			currentValue = (*property.MinValue + *property.MaxValue) / 2
		}
		
		// Calculate actual resulting values for relative commands
		var higherValue, lowerValue float64
		if property.MinValue != nil && property.MaxValue != nil {
			range_ := *property.MaxValue - *property.MinValue
			step := range_ * 0.2 // 20% step
			higherValue = currentValue + step
			lowerValue = currentValue - step
			
			// Clamp to min/max
			if higherValue > *property.MaxValue {
				higherValue = *property.MaxValue
			}
			if lowerValue < *property.MinValue {
				lowerValue = *property.MinValue
			}
		} else {
			// Default step of 10
			higherValue = currentValue + 10
			lowerValue = currentValue - 10
		}
		
		// Property-specific relative commands based on property name
		propLower := strings.ToLower(property.Name)
		
		if strings.Contains(propLower, "brightness") || strings.Contains(propLower, "dimmer") {
			commands["brighter"] = higherValue
			commands["dimmer"] = lowerValue
		}
		if strings.Contains(propLower, "volume") || strings.Contains(propLower, "sound") {
			commands["louder"] = higherValue
			commands["quieter"] = lowerValue
		}
		if strings.Contains(propLower, "temperature") || strings.Contains(propLower, "temp") {
			commands["warmer"] = higherValue
			commands["cooler"] = lowerValue
		}
		if strings.Contains(propLower, "speed") || strings.Contains(propLower, "fan") {
			commands["faster"] = higherValue
			commands["slower"] = lowerValue
		}
		
		// Generic relative commands that work for any numeric property
		commands["higher"] = higherValue
		commands["lower"] = lowerValue
		commands["increase"] = higherValue
		commands["decrease"] = lowerValue
		
		// Min/max commands
		if property.MinValue != nil {
			commands["minimum"] = *property.MinValue
			commands["min"] = *property.MinValue
			commands["lowest"] = *property.MinValue
		}
		if property.MaxValue != nil {
			commands["maximum"] = *property.MaxValue
			commands["max"] = *property.MaxValue
			commands["highest"] = *property.MaxValue
			commands["full"] = *property.MaxValue
		}
		
						
	case "enum":
		for _, value := range property.Values {
			commands[value] = value
			if value != "" {
				commands[value] = value
			}
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

// getDeviceState gets the current state values for a device
func (g *VoiceIntentGenerator) getDeviceState(friendlyName string) map[string]interface{} {
	deviceCache := GetDeviceCache()
	for _, device := range deviceCache {
		if name, exists := device["friendly_name"]; exists && name == friendlyName {
			// Return the entire device map which contains the current state values
			return device
		}
	}
	return nil
}

// getCategoryWithSynonyms returns a category with its natural language synonyms
func (g *VoiceIntentGenerator) getCategoryWithSynonyms(category string) []string {
	switch category {
	case "light":
		return []string{"light", "lamp", "bulb"}
	case "switch":
		return []string{"switch", "plug", "outlet"}
	case "sensor":
		return []string{"sensor"}
	case "button":
		return []string{"button", "remote", "controller"}
	case "door_window":
		return []string{"door", "window", "contact", "door sensor", "window sensor"}
	case "motion":
		return []string{"motion", "occupancy", "presence", "motion sensor"}
	case "thermostat":
		return []string{"thermostat", "climate", "temperature control", "hvac"}
	case "unknown":
		return []string{} // Skip unknown devices
	default:
		// For any custom category, return it as-is
		return []string{category}
	}
}

// getDeviceCategory extracts the category from device data or metadata
func (g *VoiceIntentGenerator) getDeviceCategory(friendlyName string, deviceData map[string]interface{}) string {
	// First check for custom category in metadata
	if metadata, exists := GetDeviceMetadata(friendlyName); exists {
		if customCategory, hasCategory := metadata["custom_category"]; hasCategory {
			return customCategory
		}
	}
	
	// Check if category is already in the device cache
	if category, hasCategory := deviceData["category"].(string); hasCategory {
		return category
	}
	
	return "unknown"
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