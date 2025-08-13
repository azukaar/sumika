package manage

import (
	"fmt"
)

// GetDevicesByZoneAndCategory returns all devices in a zone with a specific category
func GetDevicesByZoneAndCategory(zone, category string) []string {
	var matchingDevices []string
	
	// Get all devices in the zone
	devicesInZone := GetDevicesByZone(zone)
	
	// Filter by category
	for _, deviceName := range devicesInZone {
		// Get device cache to check category
		deviceCache := findDeviceInCache(deviceName)
		if deviceCache != nil {
			effectiveCategory := GetDeviceCategory(deviceName, deviceCache)
			if effectiveCategory == category {
				matchingDevices = append(matchingDevices, deviceName)
			}
		}
	}
	
	return matchingDevices
}

// GetAvailablePropertiesForZoneCategory returns all possible properties for devices in a zone/category combination
func GetAvailablePropertiesForZoneCategory(zone, category string) []string {
	devices := GetDevicesByZoneAndCategory(zone, category)
	propertySet := make(map[string]bool)
	
	// Collect all unique properties from all devices in the zone/category
	for _, deviceName := range devices {
		properties := GetDeviceProperties(deviceName)
		for _, prop := range properties {
			propertySet[prop] = true
		}
	}
	
	// Convert to slice
	var properties []string
	for prop := range propertySet {
		properties = append(properties, prop)
	}
	
	return properties
}

// ExecuteZoneBasedAction executes an action on all devices in a zone/category combination
func ExecuteZoneBasedAction(action AutomationAction) {
	if action.Zone == "" {
		fmt.Printf("Error: Zone-based action missing zone\n")
		return
	}
	
	// If no category specified, apply to all devices in zone
	var targetDevices []string
	if action.Category == "" {
		targetDevices = GetDevicesByZone(action.Zone)
	} else {
		targetDevices = GetDevicesByZoneAndCategory(action.Zone, action.Category)
	}
	
	fmt.Printf("Executing zone-based action on %d devices in zone '%s'", len(targetDevices), action.Zone)
	if action.Category != "" {
		fmt.Printf(" with category '%s'", action.Category)
	}
	fmt.Printf(": %s = %v\n", action.Property, action.Value)
	
	// Execute action on each matching device
	for _, deviceName := range targetDevices {
		// Create individual device action
		deviceAction := AutomationAction{
			DeviceName: deviceName,
			Property:   action.Property,
			Value:      action.Value,
		}
		
		// Create a temporary automation for the device action execution
		tempAutomation := Automation{
			Name:   fmt.Sprintf("Zone action: %s", action.Zone),
			Action: deviceAction,
		}
		
		ExecuteAutomationAction(tempAutomation)
	}
}

// findDeviceInCache finds a device in the device cache
func findDeviceInCache(deviceName string) map[string]interface{} {
	deviceCache := GetDeviceCache()
	for _, cached := range deviceCache {
		if friendlyName, exists := cached["friendly_name"]; exists && friendlyName == deviceName {
			return cached
		}
	}
	return nil
}

// GetZonesAndCategories returns all zone/category combinations that have devices
func GetZonesAndCategories() []map[string]interface{} {
	var combinations []map[string]interface{}
	deviceCache := GetDeviceCache()
	
	// Create a map to track unique zone/category combinations
	combinationMap := make(map[string]map[string]interface{})
	
	for _, cached := range deviceCache {
		deviceName, hasName := cached["friendly_name"].(string)
		if !hasName {
			continue
		}
		
		// Get device zones
		zones := GetZonesOfDevice(deviceName)
		category := GetDeviceCategory(deviceName, cached)
		
		for _, zone := range zones {
			key := fmt.Sprintf("%s|%s", zone, category)
			if _, exists := combinationMap[key]; !exists {
				// Count devices in this combination
				devices := GetDevicesByZoneAndCategory(zone, category)
				
				combinationMap[key] = map[string]interface{}{
					"zone":         zone,
					"category":     category,
					"device_count": len(devices),
					"devices":      devices,
				}
			}
		}
	}
	
	// Convert map to slice
	for _, combination := range combinationMap {
		combinations = append(combinations, combination)
	}
	
	return combinations
}

// GetAllZoneCategories returns all categories present in a specific zone
func GetAllZoneCategories(zone string) []string {
	devicesInZone := GetDevicesByZone(zone)
	categorySet := make(map[string]bool)
	
	for _, deviceName := range devicesInZone {
		deviceCache := findDeviceInCache(deviceName)
		if deviceCache != nil {
			category := GetDeviceCategory(deviceName, deviceCache)
			categorySet[category] = true
		}
	}
	
	var categories []string
	for category := range categorySet {
		categories = append(categories, category)
	}
	
	return categories
}