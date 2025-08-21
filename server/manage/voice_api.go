package manage

import (
	"encoding/json"
	"net/http"

	"github.com/azukaar/sumika/server/config"
	httputil "github.com/azukaar/sumika/server/http"
	"github.com/azukaar/sumika/server/voice"
)

// VoiceService interface to avoid circular imports
type VoiceServiceInterface interface {
	Start() error
	Stop() error
	GetConfig() config.VoiceConfig
	UpdateConfig(config.VoiceConfig) error
	GetStatus() voice.VoiceStatus
	GetInputDevices() ([]voice.AudioDevice, error)
	GetOutputDevices() ([]voice.AudioDevice, error)
	GetHistory(limit int) []voice.VoiceHistoryEntry
}


var voiceService VoiceServiceInterface

// InitVoiceService initializes the voice service
func InitVoiceService(service VoiceServiceInterface) {
	voiceService = service
	
	// Start voice service if enabled in config
	cfg := config.GetConfig()
	if cfg.Voice.Enabled {
		if err := voiceService.Start(); err != nil {
			// Log error but don't fail startup
			println("Failed to start voice service:", err.Error())
		}
	}
}

// API_GetVoiceConfig handles GET /api/voice/config
func API_GetVoiceConfig(w http.ResponseWriter, r *http.Request) {
	if voiceService == nil {
		httputil.WriteInternalError(w, "Voice service not initialized")
		return
	}

	config := voiceService.GetConfig()
	httputil.WriteJSON(w, config)
}

// API_UpdateVoiceConfig handles POST /api/voice/config
func API_UpdateVoiceConfig(w http.ResponseWriter, r *http.Request) {
	if voiceService == nil {
		httputil.WriteInternalError(w, "Voice service not initialized")
		return
	}

	var newConfig config.VoiceConfig
	if err := json.NewDecoder(r.Body).Decode(&newConfig); err != nil {
		httputil.WriteBadRequest(w, "Invalid JSON in request body")
		return
	}

	// Validate configuration
	if validationErrors := validateVoiceConfig(newConfig); len(validationErrors) > 0 {
		httputil.WriteValidationError(w, validationErrors)
		return
	}

	// Update voice service configuration
	if err := voiceService.UpdateConfig(newConfig); err != nil {
		httputil.WriteInternalError(w, "Failed to update voice configuration: "+err.Error())
		return
	}

	httputil.WriteJSON(w, map[string]string{
		"status": "updated",
	})
}

// API_GetVoiceDevices handles GET /api/voice/devices
func API_GetVoiceDevices(w http.ResponseWriter, r *http.Request) {
	if voiceService == nil {
		httputil.WriteInternalError(w, "Voice service not initialized")
		return
	}

	// Get device type from query parameter
	deviceType := httputil.GetQueryParam(r, "type")
	
	var devices interface{}
	var err error
	
	switch deviceType {
	case "input":
		devices, err = voiceService.GetInputDevices()
	case "output":
		devices, err = voiceService.GetOutputDevices()
	case "":
		// Return both input and output devices
		inputDevices, inputErr := voiceService.GetInputDevices()
		outputDevices, outputErr := voiceService.GetOutputDevices()
		
		if inputErr != nil {
			err = inputErr
		} else if outputErr != nil {
			err = outputErr
		} else {
			devices = map[string]interface{}{
				"input":  inputDevices,
				"output": outputDevices,
			}
		}
	default:
		httputil.WriteBadRequest(w, "Invalid device type. Must be 'input', 'output', or empty for both")
		return
	}

	if err != nil {
		httputil.WriteInternalError(w, "Failed to get audio devices: "+err.Error())
		return
	}

	httputil.WriteJSON(w, devices)
}

// API_GetVoiceHistory handles GET /api/voice/history
func API_GetVoiceHistory(w http.ResponseWriter, r *http.Request) {
	if voiceService == nil {
		httputil.WriteInternalError(w, "Voice service not initialized")
		return
	}

	// Parse optional limit parameter
	limit := httputil.GetIntQueryParam(r, "limit", 50)
	if limit > 1000 {
		limit = 1000 // Max limit
	}

	// Get history from voice service
	history := voiceService.GetHistory(limit)

	httputil.WriteJSON(w, map[string]interface{}{
		"history": history,
		"total":   len(history),
		"limit":   limit,
	})
}

// API_GetVoiceStatus handles GET /api/voice/status
func API_GetVoiceStatus(w http.ResponseWriter, r *http.Request) {
	if voiceService == nil {
		httputil.WriteInternalError(w, "Voice service not initialized")
		return
	}

	status := voiceService.GetStatus()
	httputil.WriteJSON(w, status)
}

// validateVoiceConfig validates voice configuration and returns validation errors
func validateVoiceConfig(config config.VoiceConfig) []string {
	var errors []string
	
	// Validate whisper model
	validModels := []string{"tiny", "base", "small", "medium", "large-v1", "large-v2", "large-v3", "turbo"}
	if !contains(validModels, config.WhisperModel) {
		errors = append(errors, "Invalid whisper model: "+config.WhisperModel)
	}
	
	// Validate whisper device
	validDevices := []string{"cpu", "cuda", "auto"}
	if !contains(validDevices, config.WhisperDevice) {
		errors = append(errors, "Invalid whisper device: "+config.WhisperDevice)
	}
	
	// Validate compute type
	validComputeTypes := []string{"int8", "int16", "float16", "float32"}
	if !contains(validComputeTypes, config.ComputeType) {
		errors = append(errors, "Invalid compute type: "+config.ComputeType)
	}
	
	// Validate wake threshold
	if config.WakeThreshold < 0.0 || config.WakeThreshold > 1.0 {
		errors = append(errors, "Wake threshold must be between 0.0 and 1.0")
	}
	
	return errors
}

// Helper function to check if slice contains string
func contains(slice []string, item string) bool {
	for _, s := range slice {
		if s == item {
			return true
		}
	}
	return false
}