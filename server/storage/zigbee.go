package storage

// GetDeviceProperties extracts controllable properties from device definition exposes
// This is a utility function to prevent circular dependencies
func GetDeviceProperties(deviceName string) []string {
	// First try to find in device cache
	cachedDevices := GetDeviceCache()
	for _, cachedDevice := range cachedDevices {
		if friendlyName, exists := cachedDevice["friendly_name"]; exists && friendlyName == deviceName {
			if definition, hasDefinition := cachedDevice["definition"].(map[string]interface{}); hasDefinition {
				if exposes, hasExposes := definition["exposes"].([]interface{}); hasExposes {
					return ExtractPropertiesFromExposes(exposes)
				}
			}
		}
	}
	
	return []string{}
}

// ExtractPropertiesFromExposes extracts property names from typed exposes array
func ExtractPropertiesFromExposes(exposes []interface{}) []string {
	properties := make([]string, 0)
	seen := make(map[string]bool)
	
	for _, expose := range exposes {
		if exposeMap, ok := expose.(map[string]interface{}); ok {
			// Direct property
			if property, hasProp := exposeMap["property"].(string); hasProp && !seen[property] {
				// Check access for automation (include both readable and writable properties)
				if access, hasAccess := exposeMap["access"].(float64); hasAccess {
					accessInt := int(access)
					isReadable := accessInt&1 != 0  // Has read access
					isWritable := accessInt&2 != 0  // Has write access
					
					// Include properties that are readable OR writable (for automation triggers/conditions)
					if isReadable || isWritable {
						properties = append(properties, property)
						seen[property] = true
					}
				} else {
					// If no access specified, assume readable/writable
					properties = append(properties, property)
					seen[property] = true
				}
			}
			
			// Nested features (for complex exposes like lights)
			if features, hasFeatures := exposeMap["features"].([]interface{}); hasFeatures {
				for _, feature := range features {
					if featureMap, ok := feature.(map[string]interface{}); ok {
						if property, hasProp := featureMap["property"].(string); hasProp && !seen[property] {
							// Check access
							if access, hasAccess := featureMap["access"].(float64); hasAccess {
								accessInt := int(access)
								isReadable := accessInt&1 != 0
								isWritable := accessInt&2 != 0
								
								if isReadable || isWritable {
									properties = append(properties, property)
									seen[property] = true
								}
							} else {
								properties = append(properties, property)
								seen[property] = true
							}
						}
					}
				}
			}
		}
	}
	
	return properties
}

// GetDeviceIEEEAddress extracts the IEEE address (real device name) from device cache
func GetDeviceIEEEAddress(friendlyName string) string {
	cachedDevices := GetDeviceCache()
	for _, device := range cachedDevices {
		if name, exists := device["friendly_name"]; exists && name == friendlyName {
			if ieeeAddr, hasIEEE := device["ieee_address"]; hasIEEE {
				if addr, ok := ieeeAddr.(string); ok {
					return addr
				}
			}
		}
	}
	return friendlyName // fallback to friendly name if IEEE not found
}