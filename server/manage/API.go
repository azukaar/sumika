package manage

import (
	"io"
	"net/http"
	"encoding/json"
	"strings"
	"fmt"

	"github.com/gorilla/mux"
)

func API_GetDeviceByZone(w http.ResponseWriter, r *http.Request) {
	// Get the zone name from the URL
	vars := mux.Vars(r)
	zone := vars["zone"]

	// Get the devices from the zone
	devices := GetDevicesByZone(zone)

	// Return the devices as JSON
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(devices)
}

func API_SetDeviceZones(w http.ResponseWriter, r *http.Request) {
	// Get the device name and zone name from the URL
	vars := mux.Vars(r)
	device := vars["device"]

	dzones := strings.Split(r.URL.Query().Get("zones"), ",")

	// Set the device zone
	SetDeviceZone(device, dzones)

	// Return a success message
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"message": "Device zone set"})
}

func API_GetDeviceZones(w http.ResponseWriter, r *http.Request) {
	// Get the device name from the URL
	vars := mux.Vars(r)
	device := vars["device"]

	// Get the zones for the device
	zones := GetZonesOfDevice(device)

	// Return the zones as JSON
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(zones)
}

func API_GetAllZones(w http.ResponseWriter, r *http.Request) {
	// Get all available zones
	zones := GetAllZones()

	// Return the zones as JSON
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(zones)
}

func API_CreateZone(w http.ResponseWriter, r *http.Request) {
	// Get the zone name from the URL
	vars := mux.Vars(r)
	zone := vars["zone"]

	// Create the zone
	success := CreateZone(zone)

	// Return the result as JSON
	w.Header().Set("Content-Type", "application/json")
	if success {
		json.NewEncoder(w).Encode(map[string]string{"message": "Zone created successfully"})
	} else {
		w.WriteHeader(http.StatusConflict)
		json.NewEncoder(w).Encode(map[string]string{"error": "Zone already exists"})
	}
}

func API_DeleteZone(w http.ResponseWriter, r *http.Request) {
	// Get the zone name from the URL
	vars := mux.Vars(r)
	zone := vars["zone"]

	// Delete the zone
	success := DeleteZone(zone)

	// Return the result as JSON
	w.Header().Set("Content-Type", "application/json")
	if success {
		json.NewEncoder(w).Encode(map[string]string{"message": "Zone deleted successfully"})
	} else {
		w.WriteHeader(http.StatusNotFound)
		json.NewEncoder(w).Encode(map[string]string{"error": "Zone not found"})
	}
}

func API_RenameZone(w http.ResponseWriter, r *http.Request) {
	// Get the old zone name from the URL
	vars := mux.Vars(r)
	oldZone := vars["zone"]

	// Get the new zone name from the query parameter
	newZone := r.URL.Query().Get("new_name")

	// Rename the zone
	success := RenameZone(oldZone, newZone)

	// Return the result as JSON
	w.Header().Set("Content-Type", "application/json")
	if success {
		json.NewEncoder(w).Encode(map[string]string{"message": "Zone renamed successfully"})
	} else {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "Zone not found or new name already exists"})
	}
}

func API_GetStorageInfo(w http.ResponseWriter, r *http.Request) {
	// Return storage information for debugging
	info := map[string]interface{}{
		"storage_file": GetStorageFilePath(),
		"zones_count": len(allZones),
		"devices_count": len(zones),
		"zones": allZones,
		"device_zone_assignments": zones,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(info)
}

// Automation API endpoints

func API_GetAllAutomations(w http.ResponseWriter, r *http.Request) {
	automations := GetAllAutomations()
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(automations)
}

func API_CreateAutomation(w http.ResponseWriter, r *http.Request) {
	var automation Automation
	if err := json.NewDecoder(r.Body).Decode(&automation); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": fmt.Sprintf("Invalid JSON: %v", err)})
		return
	}

	// Validate the automation
	if errors := ValidateAutomation(automation); len(errors) > 0 {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]interface{}{
			"error": "Validation failed",
			"details": errors,
		})
		return
	}

	// Create the automation
	id := CreateAutomation(automation)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"message": "Automation created successfully",
		"id": id,
	})
}

func API_GetAutomation(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id := vars["id"]

	automation := GetAutomationByID(id)
	if automation == nil {
		w.WriteHeader(http.StatusNotFound)
		json.NewEncoder(w).Encode(map[string]string{"error": "Automation not found"})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(automation)
}

func API_UpdateAutomation(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id := vars["id"]

	// Read the request body
	body, err := io.ReadAll(r.Body)
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "Failed to read request body"})
		return
	}
	defer r.Body.Close()

	// Try to decode as a full automation object first
	var fullAutomation Automation
	if err := json.Unmarshal(body, &fullAutomation); err == nil {
		// Check if this looks like a full automation (has required fields)
		if fullAutomation.Type != "" && fullAutomation.Trigger.DeviceName != "" {
			// Validate the automation
			if errors := ValidateAutomation(fullAutomation); len(errors) > 0 {
				w.WriteHeader(http.StatusBadRequest)
				json.NewEncoder(w).Encode(map[string]interface{}{
					"error": "Validation failed",
					"details": errors,
				})
				return
			}
			
			success := UpdateFullAutomation(id, fullAutomation)
			if !success {
				w.WriteHeader(http.StatusNotFound)
				json.NewEncoder(w).Encode(map[string]string{"error": "Automation not found"})
				return
			}
		} else {
			// Fall back to partial update if it doesn't look like a full automation
			var updates map[string]interface{}
			if err := json.Unmarshal(body, &updates); err != nil {
				w.WriteHeader(http.StatusBadRequest)
				json.NewEncoder(w).Encode(map[string]string{"error": "Invalid JSON"})
				return
			}

			success := UpdateAutomation(id, updates)
			if !success {
				w.WriteHeader(http.StatusNotFound)
				json.NewEncoder(w).Encode(map[string]string{"error": "Automation not found"})
				return
			}
		}
	} else {
		// If it fails to decode as full automation, try as partial updates
		var updates map[string]interface{}
		if err := json.Unmarshal(body, &updates); err != nil {
			w.WriteHeader(http.StatusBadRequest)
			json.NewEncoder(w).Encode(map[string]string{"error": "Invalid JSON"})
			return
		}

		success := UpdateAutomation(id, updates)
		if !success {
			w.WriteHeader(http.StatusNotFound)
			json.NewEncoder(w).Encode(map[string]string{"error": "Automation not found"})
			return
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"message": "Automation updated successfully"})
}

func API_DeleteAutomation(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id := vars["id"]

	success := DeleteAutomation(id)
	if !success {
		w.WriteHeader(http.StatusNotFound)
		json.NewEncoder(w).Encode(map[string]string{"error": "Automation not found"})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"message": "Automation deleted successfully"})
}

func API_GetAutomationsForDevice(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	deviceName := vars["device"]

	automations := GetAutomationsForDevice(deviceName)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(automations)
}

func API_GetDeviceProperties(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	deviceName := vars["device"]

	properties := GetDeviceProperties(deviceName)
	
	// Ensure we never return nil, always return an empty array if no properties
	if properties == nil {
		properties = []string{}
	}
	
	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(properties); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{
			"error": "Failed to encode device properties",
		})
	}
}

// Device metadata API endpoints

func API_SetDeviceCustomName(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	deviceName := vars["device"]
	customName := r.URL.Query().Get("custom_name")

	if customName == "" {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "custom_name parameter is required"})
		return
	}

	SetDeviceCustomName(deviceName, customName)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"message": "Device custom name set successfully"})
}

func API_SetDeviceCustomCategory(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	deviceName := vars["device"]
	category := r.URL.Query().Get("category")

	if category == "" {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "category parameter is required"})
		return
	}

	// Validate category
	validCategories := GetAllDeviceCategories()
	isValid := false
	for _, validCategory := range validCategories {
		if category == validCategory {
			isValid = true
			break
		}
	}

	if !isValid {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]interface{}{
			"error": "Invalid category",
			"valid_categories": validCategories,
		})
		return
	}

	SetDeviceCustomCategory(deviceName, category)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"message": "Device custom category set successfully"})
}

func API_GetDeviceMetadata(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	deviceName := vars["device"]

	// Get device from cache to provide full info including guessed category
	var deviceCache map[string]interface{}
	cachedDevices := GetDeviceCache()
	for _, cached := range cachedDevices {
		if friendlyName, exists := cached["friendly_name"]; exists && friendlyName == deviceName {
			deviceCache = cached
			break
		}
	}

	metadata := map[string]interface{}{
		"device_name":     deviceName,
		"custom_name":     GetDeviceCustomName(deviceName),
		"custom_category": GetDeviceCustomCategory(deviceName),
		"display_name":    GetDeviceDisplayName(deviceName),
	}

	if deviceCache != nil {
		metadata["guessed_category"] = GuessDeviceCategory(deviceCache)
		metadata["effective_category"] = GetDeviceCategory(deviceName, deviceCache)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(metadata)
}

func API_GetAllDeviceCategories(w http.ResponseWriter, r *http.Request) {
	categories := GetAllDeviceCategories()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(categories)
}

// Zone-based automation API endpoints

func API_GetDevicesByZoneAndCategory(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	zone := vars["zone"]
	category := r.URL.Query().Get("category")

	var devices []string
	if category == "" {
		devices = GetDevicesByZone(zone)
	} else {
		devices = GetDevicesByZoneAndCategory(zone, category)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(devices)
}

func API_GetZoneCategories(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	zone := vars["zone"]

	categories := GetAllZoneCategories(zone)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(categories)
}

func API_GetZoneCategoryProperties(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	zone := vars["zone"]
	category := vars["category"]

	properties := GetAvailablePropertiesForZoneCategory(zone, category)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(properties)
}

func API_GetZonesAndCategories(w http.ResponseWriter, r *http.Request) {
	combinations := GetZonesAndCategories()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(combinations)
}

// Scene API endpoints

func API_GetAllScenes(w http.ResponseWriter, r *http.Request) {
	sceneService := NewSceneService()
	scenes := sceneService.GetAllScenes()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(scenes)
}

func API_GetFeaturedScenes(w http.ResponseWriter, r *http.Request) {
	sceneService := NewSceneService()
	scenes := sceneService.GetFeaturedScenes()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(scenes)
}

func API_GetSceneByName(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	sceneName := vars["name"]

	sceneService := NewSceneService()
	scene := sceneService.GetSceneByName(sceneName)

	if scene == nil {
		w.WriteHeader(http.StatusNotFound)
		json.NewEncoder(w).Encode(map[string]string{"error": "Scene not found"})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(scene)
}

func API_RunAutomation(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id := vars["id"]

	automation := GetAutomationByID(id)
	if automation == nil {
		w.WriteHeader(http.StatusNotFound)
		json.NewEncoder(w).Encode(map[string]string{"error": "Automation not found"})
		return
	}

	// Execute the automation action
	ExecuteAutomationAction(*automation)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"message": fmt.Sprintf("Automation '%s' executed successfully", automation.Name),
	})
}