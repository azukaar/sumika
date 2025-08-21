package storage

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// VoiceIntentData represents the structure that matches intent.py format
type VoiceIntentData struct {
	IntentPatterns  map[string][]string            `json:"intent_patterns"`
	EntityPatterns  map[string]map[string]string   `json:"entity_patterns"`
	CommandTemplates []string                      `json:"command_templates"`
}

// VoiceIntentGenerator generates voice intents from storage data
type VoiceIntentGenerator struct {
	assetsPath string
}

// NewVoiceIntentGenerator creates a new voice intent generator
func NewVoiceIntentGenerator(assetsPath string) *VoiceIntentGenerator {
	return &VoiceIntentGenerator{
		assetsPath: assetsPath,
	}
}

// GenerateIntents generates voice intents from storage data and saves to JSON
func (g *VoiceIntentGenerator) GenerateIntents(data *StorageData) error {
	intents := g.createIntentData(data)
	return g.saveIntents(intents)
}

// createIntentData creates the intent data structure from storage data
func (g *VoiceIntentGenerator) createIntentData(data *StorageData) *VoiceIntentData {
	intents := &VoiceIntentData{
		IntentPatterns:   g.createIntentPatterns(),
		EntityPatterns:   g.createEntityPatterns(data),
		CommandTemplates: g.createCommandTemplates(data),
	}
	return intents
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

// createEntityPatterns creates entity patterns from storage data
func (g *VoiceIntentGenerator) createEntityPatterns(data *StorageData) map[string]map[string]string {
	entities := map[string]map[string]string{
		"device":    g.createDevicePatterns(data),
		"location":  g.createLocationPatterns(data),
		"intensity": g.createIntensityPatterns(),
		"color":     g.createColorPatterns(),
	}
	return entities
}

// createDevicePatterns creates device patterns from device cache and metadata
func (g *VoiceIntentGenerator) createDevicePatterns(data *StorageData) map[string]string {
	devices := make(map[string]string)
	
	// Add generic device patterns
	devices["light"] = "light[s]?"
	devices["lights"] = "lights|all\\s+light[s]?"
	devices["lamp"] = "lamp[s]?"
	devices["switch"] = "switch[es]?"
	
	// Process devices from cache
	for _, device := range data.DeviceCache {
		if deviceName, ok := device["friendly_name"].(string); ok {
			// Clean device name for regex
			cleanName := g.cleanDeviceName(deviceName)
			if cleanName != "" {
				// Create regex pattern for device name
				pattern := g.createDeviceRegex(deviceName)
				devices[cleanName] = pattern
				
				// Check for custom name in metadata
				if metadata, exists := data.DeviceMetadata[deviceName]; exists {
					if customName, hasCustom := metadata["custom_name"]; hasCustom && customName != "" {
						customClean := g.cleanDeviceName(customName)
						if customClean != "" {
							customPattern := g.createDeviceRegex(customName)
							devices[customClean] = customPattern
						}
					}
				}
			}
		}
	}
	
	return devices
}

// createLocationPatterns creates location patterns from zones
func (g *VoiceIntentGenerator) createLocationPatterns(data *StorageData) map[string]string {
	locations := make(map[string]string)
	
	// Add default location patterns
	locations["living_room"] = "living\\s*room|lounge"
	locations["bedroom"] = "bedroom|bed\\s*room"
	locations["kitchen"] = "kitchen"
	locations["bathroom"] = "bathroom|bath\\s*room"
	locations["hallway"] = "hallway|hall\\s*way|corridor"
	
	// Add zones from storage
	for _, zone := range data.Zones {
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

// createCommandTemplates creates command templates based on available devices and zones
func (g *VoiceIntentGenerator) createCommandTemplates(data *StorageData) []string {
	templates := []string{
		// Basic device commands
		"switch on {device}",
		"switch off {device}",
		"turn on {device}",
		"turn off {device}",
		
		// Location-based commands
		"switch on lights in {location}",
		"switch off lights in {location}",
		"turn on lights in {location}",
		"turn off lights in {location}",
		
		// Brightness commands
		"dim {device}",
		"brighten {device}",
		"dim lights in {location}",
		"brighten lights in {location}",
		"set brightness to {intensity}",
		"set {device} brightness to {intensity}",
		
		// Color commands  
		"set color to {color}",
		"set {device} color to {color}",
		"make {device} {color}",
		
		// Generic commands
		"turn on all lights",
		"turn off all lights",
		"dim all lights",
		"brighten all lights",
	}
	
	return templates
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