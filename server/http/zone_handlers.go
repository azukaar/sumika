package http

import (
	"net/http"
	"strings"
	
	"github.com/azukaar/sumika/server/storage"
	"github.com/azukaar/sumika/server/zigbee2mqtt"
)

// Zone management helper functions
func GetAllZones() []string {
	return storage.GetAllZones()
}

func GetDevicesByZone(zone string) []string {
	return storage.GetDevicesByZone(zone)
}

func GetDeviceZones(device string) []string {
	return storage.GetDeviceZones(device)
}

func SetDeviceZones(device string, zones []string) error {
	return storage.SetDeviceZones(device, zones)
}

func CreateZone(zone string) bool {
	err := storage.CreateZone(zone)
	return err == nil
}

func DeleteZone(zone string) bool {
	err := storage.DeleteZone(zone)
	return err == nil
}

func RenameZone(oldName, newName string) bool {
	err := storage.RenameZone(oldName, newName)
	return err == nil
}

// Zone management API endpoints

func API_GetDeviceByZone(w http.ResponseWriter, r *http.Request) {
	// Get the zone name from the URL
	zone, ok := GetRequiredPathParam(r, w, "zone")
	if !ok {
		return
	}

	// Get the devices from the zone using the service
	devices := GetDevicesByZone(zone)

	// Return the devices as JSON
	WriteJSON(w, devices)
}

func API_SetDeviceZones(w http.ResponseWriter, r *http.Request) {
	// Get the device name from the URL
	device, ok := GetRequiredPathParam(r, w, "device")
	if !ok {
		return
	}

	zonesParam := GetQueryParam(r, "zones")
	dzones := strings.Split(zonesParam, ",")

	// Set the device zone using the service
	err := SetDeviceZones(device, dzones)
	if err != nil {
		WriteError(w, http.StatusInternalServerError, "Failed to set device zones")
		return
	}

	// Return a success message
	WriteJSON(w, map[string]string{"message": "Device zones set successfully"})
}

func API_GetDeviceZones(w http.ResponseWriter, r *http.Request) {
	// Get the device name from the URL
	device, ok := GetRequiredPathParam(r, w, "device")
	if !ok {
		return
	}

	// Get the zones for the device
	zones := GetDeviceZones(device)

	// Return the zones as JSON
	WriteJSON(w, zones)
}

func API_GetAllZones(w http.ResponseWriter, r *http.Request) {
	// Get all available zones
	zones := GetAllZones()

	// Return the zones as JSON
	WriteJSON(w, zones)
}

func API_CreateZone(w http.ResponseWriter, r *http.Request) {
	// Get the zone name from the URL
	zone, ok := GetRequiredPathParam(r, w, "zone")
	if !ok {
		return
	}

	// Create the zone
	success := CreateZone(zone)

	// Return the result as JSON
	if success {
		WriteSuccess(w, "Zone created successfully")
	} else {
		WriteConflict(w, "Zone already exists")
	}
}

func API_DeleteZone(w http.ResponseWriter, r *http.Request) {
	// Get the zone name from the URL
	zone, ok := GetRequiredPathParam(r, w, "zone")
	if !ok {
		return
	}

	// Delete the zone
	success := DeleteZone(zone)

	// Return the result as JSON
	if success {
		WriteSuccess(w, "Zone deleted successfully")
	} else {
		WriteNotFound(w, "Zone")
	}
}

func API_RenameZone(w http.ResponseWriter, r *http.Request) {
	// Get the old zone name from the URL
	oldZone, ok := GetRequiredPathParam(r, w, "zone")
	if !ok {
		return
	}

	// Get the new zone name from the query parameter
	newZone, ok := GetRequiredQueryParam(r, w, "new_name")
	if !ok {
		return
	}

	// Rename the zone
	success := RenameZone(oldZone, newZone)

	// Return the result as JSON
	if success {
		WriteSuccess(w, "Zone renamed successfully")
	} else {
		WriteBadRequest(w, "Zone not found or new name already exists")
	}
}

func API_GetStorageInfo(w http.ResponseWriter, r *http.Request) {
	// Return storage information for debugging
	allZones := GetAllZones()
	
	info := map[string]interface{}{
		"storage_file":             "./build-data/storage.json",
		"zones_count":              len(allZones),
		"zones":                   allZones,
	}

	WriteJSON(w, info)
}

// Zone-based automation API endpoints

func API_GetDevicesByZoneAndCategory(w http.ResponseWriter, r *http.Request) {
	zone, ok := GetRequiredPathParam(r, w, "zone")
	if !ok {
		return
	}
	category := GetQueryParam(r, "category")

	var devices []string
	allZoneDevices := GetDevicesByZone(zone)
	
	if category == "" {
		devices = allZoneDevices
	} else {
		// Filter devices by category
		for _, deviceName := range allZoneDevices {
			if metadata, exists := storage.GetDeviceMetadata(deviceName); exists {
				if deviceCategory, ok := metadata["custom_category"]; ok && deviceCategory == category {
					devices = append(devices, deviceName)
				}
			}
		}
	}

	WriteJSON(w, devices)
}

func API_GetZoneCategories(w http.ResponseWriter, r *http.Request) {
	zone, ok := GetRequiredPathParam(r, w, "zone")
	if !ok {
		return
	}

	// Get all devices in the zone
	zoneDevices := storage.GetDevicesByZone(zone)
	
	// Extract unique categories from devices in this zone
	categoriesMap := make(map[string]bool)
	for _, deviceName := range zoneDevices {
		if metadata, exists := storage.GetDeviceMetadata(deviceName); exists {
			if category, ok := metadata["custom_category"]; ok && category != "" {
				categoriesMap[category] = true
			}
		}
	}
	
	// Convert map to sorted slice
	categories := make([]string, 0, len(categoriesMap))
	for category := range categoriesMap {
		categories = append(categories, category)
	}

	WriteJSON(w, categories)
}

func API_GetZoneCategoryProperties(w http.ResponseWriter, r *http.Request) {
	params, ok := ValidatePathParams(r, w, "zone", "category")
	if !ok {
		return
	}
	zone := params["zone"]
	category := params["category"]

	// Get all devices in the zone that match the category
	zoneDevices := storage.GetDevicesByZone(zone)

	// Find common properties across all devices in the zone with the specified category
	var commonProperties []string
	deviceCount := 0

	for _, deviceName := range zoneDevices {
		// Check if device matches the category
		if metadata, exists := storage.GetDeviceMetadata(deviceName); exists {
			if deviceCategory, ok := metadata["custom_category"]; ok && deviceCategory == category {
				// Get device properties from exposes (not state)
				deviceProperties := zigbee2mqtt.GetDeviceProperties(deviceName)
				if len(deviceProperties) > 0 {
					deviceCount++

					if deviceCount == 1 {
						// First device - initialize common properties
						commonProperties = deviceProperties
					} else {
						// Find intersection with previous common properties
						newCommon := []string{}
						for _, prop := range commonProperties {
							for _, deviceProp := range deviceProperties {
								if prop == deviceProp {
									newCommon = append(newCommon, prop)
									break
								}
							}
						}
						commonProperties = newCommon
					}
				}
			}
		}
	}

	if deviceCount == 0 {
		commonProperties = []string{}
	}

	WriteJSON(w, commonProperties)
}

func API_GetZonesAndCategories(w http.ResponseWriter, r *http.Request) {
	// Get all zones and their available categories
	allZones := storage.GetAllZones()
	combinations := make(map[string][]string)
	
	for _, zone := range allZones {
		// Get devices in this zone
		zoneDevices := storage.GetDevicesByZone(zone)
		
		// Extract unique categories from devices in this zone
		categoriesMap := make(map[string]bool)
		for _, deviceName := range zoneDevices {
			if metadata, exists := storage.GetDeviceMetadata(deviceName); exists {
				if category, ok := metadata["custom_category"]; ok && category != "" {
					categoriesMap[category] = true
				}
			}
		}
		
		// Convert to slice
		categories := make([]string, 0, len(categoriesMap))
		for category := range categoriesMap {
			categories = append(categories, category)
		}
		
		combinations[zone] = categories
	}

	WriteJSON(w, combinations)
}