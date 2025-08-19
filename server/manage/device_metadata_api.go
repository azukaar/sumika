package manage

import (
	"net/http"

	httputil "github.com/azukaar/sumika/server/http"
)

// Device metadata API endpoints

func API_SetDeviceCustomName(w http.ResponseWriter, r *http.Request) {
	deviceName, ok := httputil.GetRequiredPathParam(r, w, "device")
	if !ok {
		return
	}
	customName, ok := httputil.GetRequiredQueryParam(r, w, "custom_name")
	if !ok {
		return
	}

	SetDeviceCustomName(deviceName, customName)
	httputil.WriteSuccess(w, "Device custom name set successfully")
}

func API_SetDeviceCustomCategory(w http.ResponseWriter, r *http.Request) {
	deviceName, ok := httputil.GetRequiredPathParam(r, w, "device")
	if !ok {
		return
	}
	category, ok := httputil.GetRequiredQueryParam(r, w, "category")
	if !ok {
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
		response := map[string]interface{}{
			"error":            "Invalid category",
			"valid_categories": validCategories,
		}
		httputil.WriteBadRequest(w, "")
		httputil.WriteJSON(w, response)
		return
	}

	SetDeviceCustomCategory(deviceName, category)
	httputil.WriteSuccess(w, "Device custom category set successfully")
}

func API_GetDeviceMetadata(w http.ResponseWriter, r *http.Request) {
	deviceName, ok := httputil.GetRequiredPathParam(r, w, "device")
	if !ok {
		return
	}

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

	httputil.WriteJSON(w, metadata)
}

func API_GetAllDeviceCategories(w http.ResponseWriter, r *http.Request) {
	categories := GetAllDeviceCategories()
	httputil.WriteJSON(w, categories)
}