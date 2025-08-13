package manage

import (
	"strings"
)

// Device metadata storage
var deviceMetadata = map[string]map[string]string{}

// Device categories
const (
	CategoryLight      = "light"
	CategorySwitch     = "switch"
	CategorySensor     = "sensor"
	CategoryButton     = "button"
	CategoryDoorWindow = "door_window"
	CategoryMotion     = "motion"
	CategoryThermostat = "thermostat"
	CategoryUnknown    = "unknown"
)

// GetAllDeviceCategories returns all available device categories
func GetAllDeviceCategories() []string {
	return []string{
		CategoryLight,
		CategorySwitch,
		CategorySensor,
		CategoryButton,
		CategoryDoorWindow,
		CategoryMotion,
		CategoryThermostat,
		CategoryUnknown,
	}
}

// SetDeviceCustomName sets a custom display name for a device
func SetDeviceCustomName(deviceName, customName string) {
	if deviceMetadata[deviceName] == nil {
		deviceMetadata[deviceName] = make(map[string]string)
	}
	deviceMetadata[deviceName]["custom_name"] = customName
	SaveToStorage()
}

// SetDeviceCustomCategory sets a custom category for a device
func SetDeviceCustomCategory(deviceName, category string) {
	if deviceMetadata[deviceName] == nil {
		deviceMetadata[deviceName] = make(map[string]string)
	}
	deviceMetadata[deviceName]["custom_category"] = category
	SaveToStorage()
}

// GetDeviceCustomName returns the custom name for a device, or empty string if not set
func GetDeviceCustomName(deviceName string) string {
	if metadata, exists := deviceMetadata[deviceName]; exists {
		return metadata["custom_name"]
	}
	return ""
}

// GetDeviceCustomCategory returns the custom category for a device, or empty string if not set
func GetDeviceCustomCategory(deviceName string) string {
	if metadata, exists := deviceMetadata[deviceName]; exists {
		return metadata["custom_category"]
	}
	return ""
}

// GuessDeviceCategory attempts to guess the device category based on its definition and state
func GuessDeviceCategory(deviceCache map[string]interface{}) string {
	// Check definition for device type hints
	if definition, ok := deviceCache["definition"].(map[string]interface{}); ok {
		if description, hasDesc := definition["description"].(string); hasDesc {
			descLower := strings.ToLower(description)
			
			// Look for keywords in description
			if strings.Contains(descLower, "light") || strings.Contains(descLower, "bulb") || strings.Contains(descLower, "lamp") {
				return CategoryLight
			}
			if strings.Contains(descLower, "switch") || strings.Contains(descLower, "plug") {
				return CategorySwitch
			}
			if strings.Contains(descLower, "sensor") {
				return CategorySensor
			}
			if strings.Contains(descLower, "button") || strings.Contains(descLower, "remote") {
				return CategoryButton
			}
			if strings.Contains(descLower, "door") || strings.Contains(descLower, "window") || strings.Contains(descLower, "contact") {
				return CategoryDoorWindow
			}
			if strings.Contains(descLower, "motion") || strings.Contains(descLower, "occupancy") {
				return CategoryMotion
			}
			if strings.Contains(descLower, "thermostat") || strings.Contains(descLower, "temperature control") {
				return CategoryThermostat
			}
		}
		
		// Check exposes array for feature types
		if exposes, hasExposes := definition["exposes"].([]interface{}); hasExposes {
			for _, expose := range exposes {
				if exposeMap, ok := expose.(map[string]interface{}); ok {
					if exposeType, hasType := exposeMap["type"].(string); hasType {
						switch exposeType {
						case "light":
							return CategoryLight
						case "switch":
							return CategorySwitch
						case "binary":
							// Check the property name to determine type
							if property, hasProp := exposeMap["property"].(string); hasProp {
								propLower := strings.ToLower(property)
								if propLower == "contact" {
									return CategoryDoorWindow
								}
								if propLower == "occupancy" || propLower == "motion" {
									return CategoryMotion
								}
								if strings.Contains(propLower, "state") {
									return CategorySwitch
								}
							}
						}
					}
					
					// Check for action property (buttons)
					if features, hasFeatures := exposeMap["features"].([]interface{}); hasFeatures {
						for _, feature := range features {
							if featureMap, ok := feature.(map[string]interface{}); ok {
								if property, hasProp := featureMap["property"].(string); hasProp && property == "action" {
									return CategoryButton
								}
							}
						}
					}
				}
			}
		}
	}
	
	// Check device state for clues
	if state, hasState := deviceCache["state"].(map[string]interface{}); hasState {
		// Check for common light properties
		if _, hasState := state["state"]; hasState {
			if _, hasBrightness := state["brightness"]; hasBrightness {
				return CategoryLight
			}
			if _, hasColor := state["color"]; hasColor {
				return CategoryLight
			}
		}
		
		// Check for sensor properties
		if _, hasTemp := state["temperature"]; hasTemp {
			return CategorySensor
		}
		if _, hasHumidity := state["humidity"]; hasHumidity {
			return CategorySensor
		}
		if _, hasContact := state["contact"]; hasContact {
			return CategoryDoorWindow
		}
		if _, hasMotion := state["motion"]; hasMotion {
			return CategoryMotion
		}
		if _, hasOccupancy := state["occupancy"]; hasOccupancy {
			return CategoryMotion
		}
		if _, hasAction := state["action"]; hasAction {
			return CategoryButton
		}
		
		// Check for power measurement (smart plugs)
		if _, hasPower := state["power"]; hasPower {
			return CategorySwitch
		}
	}
	
	// Check device type from zigbee2mqtt
	if deviceType, hasType := deviceCache["type"].(string); hasType {
		switch strings.ToLower(deviceType) {
		case "enddevice":
			// EndDevices are usually sensors or buttons
			return CategorySensor
		case "router":
			// Routers are usually lights or switches
			return CategoryLight
		}
	}
	
	return CategoryUnknown
}

// GetDeviceDisplayName returns the display name for a device (custom name if set, otherwise friendly name)
func GetDeviceDisplayName(deviceName string) string {
	customName := GetDeviceCustomName(deviceName)
	if customName != "" {
		return customName
	}
	return deviceName
}

// GetDeviceCategory returns the category for a device (custom category if set, otherwise guessed)
func GetDeviceCategory(deviceName string, deviceCache map[string]interface{}) string {
	customCategory := GetDeviceCustomCategory(deviceName)
	if customCategory != "" {
		return customCategory
	}
	return GuessDeviceCategory(deviceCache)
}

// GetAllDeviceMetadata returns all device metadata
func GetAllDeviceMetadata() map[string]map[string]string {
	return deviceMetadata
}

// SetAllDeviceMetadata sets all device metadata (for loading from storage)
func SetAllDeviceMetadata(metadata map[string]map[string]string) {
	deviceMetadata = metadata
}

// GetDeviceMetadata returns the metadata for a specific device
func GetDeviceMetadata(deviceName string) (map[string]string, bool) {
	metadata, exists := deviceMetadata[deviceName]
	return metadata, exists
}