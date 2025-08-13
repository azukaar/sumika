package manage

import (
	// "fmt"
	"slices"
)

var zones = map[string][]string{}
var allZones = []string{"kitchen", "living_room", "bedroom", "bathroom", "office", "garage"}
var deviceCache = []map[string]interface{}{}

// GetDevicesByZone returns a list of devices in a zone
func GetDevicesByZone(zone string) []string {
	var devices []string

	for device, dzones := range zones {
		if slices.Contains(dzones, zone) {
			devices = append(devices, device)
		}
	}

	return devices
}

// SetDeviceZone sets the zone of a device
func SetDeviceZone(device string, dzones []string) {
	zones[device] = dzones
	// Save to storage after modification
	SaveToStorage()
}

func GetZonesOfDevice(device string) []string {
	deviceZones := zones[device]
	if deviceZones == nil {
		return []string{} // Return empty slice instead of nil
	}
	return deviceZones
}

// GetAllZones returns all available zones
func GetAllZones() []string {
	return allZones
}

// CreateZone adds a new zone
func CreateZone(zone string) bool {
	if slices.Contains(allZones, zone) {
		return false // Zone already exists
	}
	allZones = append(allZones, zone)
	// Save to storage after modification
	SaveToStorage()
	return true
}

// DeleteZone removes a zone and all its device associations
func DeleteZone(zone string) bool {
	if !slices.Contains(allZones, zone) {
		return false // Zone doesn't exist
	}
	
	// Remove zone from all devices
	for device, deviceZones := range zones {
		newZones := []string{}
		for _, dz := range deviceZones {
			if dz != zone {
				newZones = append(newZones, dz)
			}
		}
		zones[device] = newZones
	}
	
	// Remove zone from allZones
	newAllZones := []string{}
	for _, z := range allZones {
		if z != zone {
			newAllZones = append(newAllZones, z)
		}
	}
	allZones = newAllZones
	
	// Save to storage after modification
	SaveToStorage()
	return true
}

// RenameZone renames an existing zone
func RenameZone(oldName, newName string) bool {
	if !slices.Contains(allZones, oldName) || slices.Contains(allZones, newName) {
		return false // Old zone doesn't exist or new name already exists
	}
	
	// Update zone in all devices
	for _, deviceZones := range zones {
		for i, dz := range deviceZones {
			if dz == oldName {
				deviceZones[i] = newName
			}
		}
	}
	
	// Update in allZones
	for i, z := range allZones {
		if z == oldName {
			allZones[i] = newName
			break
		}
	}
	
	// Save to storage after modification
	SaveToStorage()
	return true
}

// SetDeviceCache updates the device cache with fresh data
func SetDeviceCache(devices []map[string]interface{}) {
	deviceCache = devices
	// Save to storage after modification
	SaveToStorage()
}

// GetDeviceCache returns the current device cache
func GetDeviceCache() []map[string]interface{} {
	return deviceCache
}

// ClearDeviceCache clears the device cache
func ClearDeviceCache() {
	deviceCache = []map[string]interface{}{}
	// Save to storage after modification
	SaveToStorage()
}

// GetUnassignedDevices returns devices that are not assigned to any zone
func GetUnassignedDevices(allDevices []string) []string {
	var unassigned []string
	
	for _, device := range allDevices {
		deviceZones := GetZonesOfDevice(device)
		if len(deviceZones) == 0 {
			unassigned = append(unassigned, device)
		}
	}
	
	return unassigned
}