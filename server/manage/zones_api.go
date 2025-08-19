package manage

import (
	"net/http"
	"strings"

	httputil "github.com/azukaar/sumika/server/http"
)

// Zone management API endpoints

func API_GetDeviceByZone(w http.ResponseWriter, r *http.Request) {
	// Get the zone name from the URL
	zone, ok := httputil.GetRequiredPathParam(r, w, "zone")
	if !ok {
		return
	}

	// Get the devices from the zone
	devices := GetDevicesByZone(zone)

	// Return the devices as JSON
	httputil.WriteJSON(w, devices)
}

func API_SetDeviceZones(w http.ResponseWriter, r *http.Request) {
	// Get the device name from the URL
	device, ok := httputil.GetRequiredPathParam(r, w, "device")
	if !ok {
		return
	}

	zonesParam := httputil.GetQueryParam(r, "zones")
	dzones := strings.Split(zonesParam, ",")

	// Set the device zone
	SetDeviceZone(device, dzones)

	// Return a success message
	httputil.WriteSuccess(w, "Device zone set")
}

func API_GetDeviceZones(w http.ResponseWriter, r *http.Request) {
	// Get the device name from the URL
	device, ok := httputil.GetRequiredPathParam(r, w, "device")
	if !ok {
		return
	}

	// Get the zones for the device
	zones := GetZonesOfDevice(device)

	// Return the zones as JSON
	httputil.WriteJSON(w, zones)
}

func API_GetAllZones(w http.ResponseWriter, r *http.Request) {
	// Get all available zones
	zones := GetAllZones()

	// Return the zones as JSON
	httputil.WriteJSON(w, zones)
}

func API_CreateZone(w http.ResponseWriter, r *http.Request) {
	// Get the zone name from the URL
	zone, ok := httputil.GetRequiredPathParam(r, w, "zone")
	if !ok {
		return
	}

	// Create the zone
	success := CreateZone(zone)

	// Return the result as JSON
	if success {
		httputil.WriteSuccess(w, "Zone created successfully")
	} else {
		httputil.WriteConflict(w, "Zone already exists")
	}
}

func API_DeleteZone(w http.ResponseWriter, r *http.Request) {
	// Get the zone name from the URL
	zone, ok := httputil.GetRequiredPathParam(r, w, "zone")
	if !ok {
		return
	}

	// Delete the zone
	success := DeleteZone(zone)

	// Return the result as JSON
	if success {
		httputil.WriteSuccess(w, "Zone deleted successfully")
	} else {
		httputil.WriteNotFound(w, "Zone")
	}
}

func API_RenameZone(w http.ResponseWriter, r *http.Request) {
	// Get the old zone name from the URL
	oldZone, ok := httputil.GetRequiredPathParam(r, w, "zone")
	if !ok {
		return
	}

	// Get the new zone name from the query parameter
	newZone, ok := httputil.GetRequiredQueryParam(r, w, "new_name")
	if !ok {
		return
	}

	// Rename the zone
	success := RenameZone(oldZone, newZone)

	// Return the result as JSON
	if success {
		httputil.WriteSuccess(w, "Zone renamed successfully")
	} else {
		httputil.WriteBadRequest(w, "Zone not found or new name already exists")
	}
}

func API_GetStorageInfo(w http.ResponseWriter, r *http.Request) {
	// Return storage information for debugging
	info := map[string]interface{}{
		"storage_file":             GetStorageFilePath(),
		"zones_count":              len(allZones),
		"devices_count":            len(zones),
		"zones":                   allZones,
		"device_zone_assignments": zones,
	}

	httputil.WriteJSON(w, info)
}

// Zone-based automation API endpoints

func API_GetDevicesByZoneAndCategory(w http.ResponseWriter, r *http.Request) {
	zone, ok := httputil.GetRequiredPathParam(r, w, "zone")
	if !ok {
		return
	}
	category := httputil.GetQueryParam(r, "category")

	var devices []string
	if category == "" {
		devices = GetDevicesByZone(zone)
	} else {
		devices = GetDevicesByZoneAndCategory(zone, category)
	}

	httputil.WriteJSON(w, devices)
}

func API_GetZoneCategories(w http.ResponseWriter, r *http.Request) {
	zone, ok := httputil.GetRequiredPathParam(r, w, "zone")
	if !ok {
		return
	}

	categories := GetAllZoneCategories(zone)

	httputil.WriteJSON(w, categories)
}

func API_GetZoneCategoryProperties(w http.ResponseWriter, r *http.Request) {
	params, ok := httputil.ValidatePathParams(r, w, "zone", "category")
	if !ok {
		return
	}
	zone := params["zone"]
	category := params["category"]

	properties := GetAvailablePropertiesForZoneCategory(zone, category)

	httputil.WriteJSON(w, properties)
}

func API_GetZonesAndCategories(w http.ResponseWriter, r *http.Request) {
	combinations := GetZonesAndCategories()

	httputil.WriteJSON(w, combinations)
}