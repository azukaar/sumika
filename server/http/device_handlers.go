package http

import (
	"net/http"
	"github.com/azukaar/sumika/server/errors"
	"fmt"
	"github.com/azukaar/sumika/server/utils"
	"time"
	
	"github.com/azukaar/sumika/server/zigbee2mqtt"
)

// Device metadata API endpoints

func API_SetDeviceCustomName(w http.ResponseWriter, r *http.Request) {
	deviceName, ok := GetRequiredPathParam(r, w, "device")
	if !ok {
		return
	}
	customName, ok := GetRequiredQueryParam(r, w, "custom_name")
	if !ok {
		return
	}

	zigbee2mqtt.SetDeviceCustomName(deviceName, customName)
	WriteSuccess(w, "Device custom name set successfully")
}

func API_SetDeviceCustomCategory(w http.ResponseWriter, r *http.Request) {
	deviceName, ok := GetRequiredPathParam(r, w, "device")
	if !ok {
		return
	}
	category, ok := GetRequiredQueryParam(r, w, "category")
	if !ok {
		return
	}

	// Validate category
	validCategories := zigbee2mqtt.GetAllDeviceCategories()
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
		WriteBadRequest(w, "")
		WriteJSON(w, response)
		return
	}

	zigbee2mqtt.SetDeviceCustomCategory(deviceName, category)
	WriteSuccess(w, "Device custom category set successfully")
}

func API_GetDeviceMetadata(w http.ResponseWriter, r *http.Request) {
	deviceName, ok := GetRequiredPathParam(r, w, "device")
	if !ok {
		return
	}

	// Get device from cache to provide full info including guessed category
	var deviceCache map[string]interface{}
	cachedDevices := zigbee2mqtt.GetDeviceCache()
	for _, cached := range cachedDevices {
		if friendlyName, exists := cached["friendly_name"]; exists && friendlyName == deviceName {
			deviceCache = cached
			break
		}
	}

	metadata := map[string]interface{}{
		"device_name":     deviceName,
		"custom_name":     zigbee2mqtt.GetDeviceCustomName(deviceName),
		"custom_category": zigbee2mqtt.GetDeviceCustomCategory(deviceName),
		"display_name":    zigbee2mqtt.GetDeviceDisplayName(deviceName),
	}

	if deviceCache != nil {
		metadata["guessed_category"] = zigbee2mqtt.GuessDeviceCategory(deviceCache)
		metadata["effective_category"] = zigbee2mqtt.GetDeviceCategory(deviceName, deviceCache)
	}

	WriteJSON(w, metadata)
}

func API_GetAllDeviceCategories(w http.ResponseWriter, r *http.Request) {
	categories := zigbee2mqtt.GetAllDeviceCategories()
	WriteJSON(w, categories)
}

func API_GetDeviceProperties(w http.ResponseWriter, r *http.Request) {
	device, ok := GetRequiredPathParam(r, w, "device")
	if !ok {
		return
	}

	fmt.Printf("[DEBUG] API_GetDeviceProperties: Looking for properties for device '%s'\n", device)

	// Get device properties from exposes (not state)
	properties := zigbee2mqtt.GetDeviceProperties(device)
	
	fmt.Printf("[DEBUG] API_GetDeviceProperties: Found %d properties for device '%s': %v\n", len(properties), device, properties)
	WriteJSON(w, properties)
}

// DeviceMetadataAPI handles device metadata requests
type DeviceMetadataAPI struct {
	metadataService *utils.DeviceMetadataService
	errorHandler    *errors.ErrorHandler
}

// NewDeviceMetadataAPI creates a new device metadata API handler
func NewDeviceMetadataAPI() *DeviceMetadataAPI {
	return &DeviceMetadataAPI{
		metadataService: utils.NewDeviceMetadataService(),
		errorHandler:    errors.NewErrorHandler(false),
	}
}

// API_GetDeviceSpec retrieves device specifications from zigbee-herdsman-converters
func (api *DeviceMetadataAPI) API_GetDeviceSpec(w http.ResponseWriter, r *http.Request) {
	modelID := r.URL.Query().Get("model_id")
	manufacturerName := r.URL.Query().Get("manufacturer")
	
	if modelID == "" || manufacturerName == "" {
		api.errorHandler.HandleError(w, r, 
			errors.NewValidationError("model_id and manufacturer are required", nil), 
			"missing_parameters")
		return
	}
	
	metadata, err := api.metadataService.GetDeviceMetadata(modelID, manufacturerName)
	if err != nil {
		api.errorHandler.HandleError(w, r, err, "get_metadata")
		return
	}
	
	WriteJSON(w, metadata)
}

// API_GetDeviceSpecByModel retrieves device specifications by exact model ID
func (api *DeviceMetadataAPI) API_GetDeviceSpecByModel(w http.ResponseWriter, r *http.Request) {
	model, err := errors.GetPathParam(r, "model")
	if err != nil {
		api.errorHandler.HandleError(w, r, err, "extract_model")
		return
	}
	
	metadata, err2 := api.metadataService.GetDeviceByModel(model)
	if err2 != nil {
		api.errorHandler.HandleError(w, r, errors.NewInternalError("Failed to get device metadata", err2), "get_by_model")
		return
	}
	
	WriteJSON(w, metadata)
}

// API_IdentifyDevice identifies a device and returns its specifications
func (api *DeviceMetadataAPI) API_IdentifyDevice(w http.ResponseWriter, r *http.Request) {
	var request struct {
		ModelID          string `json:"model_id"`
		ManufacturerName string `json:"manufacturer_name"`
		ManufacturerID   string `json:"manufacturer_id,omitempty"`
		Type             string `json:"type,omitempty"`
	}
	
	if err := errors.ParseJSONBody(r, &request); err != nil {
		api.errorHandler.HandleError(w, r, err, "parse_request")
		return
	}
	
	validator := errors.NewValidator()
	errors.ValidateRequired(validator, "model_id", request.ModelID)
	errors.ValidateRequired(validator, "manufacturer_name", request.ManufacturerName)
	
	if err := validator.ToAppError(); err != nil {
		api.errorHandler.HandleError(w, r, err, "validation")
		return
	}
	
	metadata, err := api.metadataService.GetDeviceMetadata(request.ModelID, request.ManufacturerName)
	if err != nil {
		api.errorHandler.HandleError(w, r, err, "identify_device")
		return
	}
	
	WriteJSON(w, metadata)
}

// API_GetAllDevicesWithSpecs retrieves all devices from local storage with their specifications
func (api *DeviceMetadataAPI) API_GetAllDevicesWithSpecs(w http.ResponseWriter, r *http.Request) {
	devices := zigbee2mqtt.GetDeviceCache()
	fmt.Printf("[DEBUG] DeviceMetadataAPI: Retrieved %d devices from cache\n", len(devices))
	
	enrichedDevices, err := api.metadataService.GetBulkDeviceMetadata(devices)
	if err != nil {
		fmt.Printf("[DEBUG] DeviceMetadataAPI: Error processing bulk metadata: %v\n", err)
		api.errorHandler.HandleError(w, r, 
			errors.NewInternalError("Failed to process device metadata", err), 
			"process_bulk_metadata")
		return
	}
	fmt.Printf("[DEBUG] DeviceMetadataAPI: Successfully enriched %d devices\n", len(enrichedDevices))
	
	WriteJSON(w, map[string]interface{}{
		"count":     len(enrichedDevices),
		"devices":   enrichedDevices,
		"timestamp": time.Now().Format(time.RFC3339),
	})
}

// API_GetSpecVersion returns zigbee-herdsman-converters version information
func (api *DeviceMetadataAPI) API_GetSpecVersion(w http.ResponseWriter, r *http.Request) {
	version, err := api.metadataService.GetVersion()
	if err != nil {
		api.errorHandler.HandleError(w, r, err, "get_version")
		return
	}
	
	WriteJSON(w, version)
}

// API_ClearSpecCache clears the device specifications cache
func (api *DeviceMetadataAPI) API_ClearSpecCache(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		WriteJSON(w, map[string]string{
			"error": "Method not allowed. Only POST is supported.",
		})
		return
	}
	
	api.metadataService.ClearCache()
	
	WriteJSON(w, map[string]string{
		"status":  "success",
		"message": "Device specifications cache cleared",
	})
}