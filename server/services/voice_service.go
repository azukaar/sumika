package services

import (
	"encoding/json"
	"fmt"
	"log"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/azukaar/sumika/server/config"
	"github.com/azukaar/sumika/server/realtime"
	"github.com/azukaar/sumika/server/types"
)

// VoiceService manages voice recognition functionality
type VoiceService struct {
	config           *config.VoiceConfig
	runner           *VoiceRunner
	mutex            sync.RWMutex
	deviceCommandFunc func(deviceName, command string)
	getDeviceCacheFunc func() []map[string]interface{}
	getDeviceZonesFunc func(deviceName string) []string
	history          []types.VoiceHistoryEntry
	maxHistory       int
}


// NewVoiceService creates a new voice service
func NewVoiceService(deviceCommandFunc func(deviceName, command string)) *VoiceService {
	cfg := config.GetConfig()
	
	vs := &VoiceService{
		config:           &cfg.Voice,
		deviceCommandFunc: deviceCommandFunc,
		getDeviceCacheFunc: func() []map[string]interface{} {
			// TODO: This should be injected from zigbee2mqtt or device service
			// For now return empty to avoid crashes
			return []map[string]interface{}{}
		},
		getDeviceZonesFunc: func(deviceName string) []string {
			// TODO: This should be injected from zone service
			// For now return empty to avoid crashes
			return []string{}
		},
		history:          make([]types.VoiceHistoryEntry, 0),
		maxHistory:       100,
	}
	
	// Create voice runner with callbacks
	vs.createVoiceRunner()
	
	return vs
}

// createVoiceRunner creates a new voice runner with callbacks
func (vs *VoiceService) createVoiceRunner() {
	voiceConfig := types.VoiceConfig{
		WhisperModel:  vs.config.WhisperModel,
		WhisperDevice: vs.config.WhisperDevice,
		ComputeType:   vs.config.ComputeType,
		WakeThreshold: vs.config.WakeThreshold,
		InputDevice:   vs.config.InputDevice,
		OutputDevice:  vs.config.OutputDevice,
	}
	
	callbacks := types.VoiceCallbacks{
		OnWakeWordDetected: func(label string, score float64) {
			vs.handleWakeWordDetected(label, score)
		},
		OnTranscription: func(text string, duration, processingTime float64) {
			vs.handleTranscription(text, duration, processingTime)
		},
		OnIntent: func(transcription string, intentResult *types.IntentResult) {
			vs.handleIntent(transcription, intentResult)
		},
		OnError: func(message string, processingTime float64) {
			vs.handleError(message, processingTime)
		},
		OnStatusUpdate: func(eventType, message string) {
			vs.handleStatusUpdate(eventType, message)
		},
	}
	
	vs.runner = NewVoiceRunner(voiceConfig, callbacks)
}

// Start starts the voice recognition service if enabled
func (vs *VoiceService) Start() error {
	vs.mutex.Lock()
	defer vs.mutex.Unlock()
	
	if !vs.config.Enabled {
		log.Printf("Voice service disabled in configuration")
		return nil
	}
	
	if vs.runner != nil && vs.runner.IsRunning() {
		log.Printf("Voice service already running")
		return nil
	}
	
	log.Printf("Starting voice recognition service...")
	
	// Start the voice runner
	if err := vs.runner.Start(); err != nil {
		return fmt.Errorf("failed to start voice runner: %w", err)
	}
	
	// Send WebSocket event
	realtime.BroadcastEvent("voice_status_changed", map[string]interface{}{
		"enabled": true,
		"running": true,
	})
	
	return nil
}

// Stop stops the voice recognition service
func (vs *VoiceService) Stop() error {
	vs.mutex.Lock()
	defer vs.mutex.Unlock()
	
	if vs.runner == nil || !vs.runner.IsRunning() {
		return nil
	}
	
	log.Printf("Stopping voice recognition service...")
	
	// Stop the voice runner
	if err := vs.runner.Stop(); err != nil {
		return fmt.Errorf("failed to stop voice runner: %w", err)
	}
	
	// Send WebSocket event
	realtime.BroadcastEvent("voice_status_changed", map[string]interface{}{
		"enabled": false,
		"running": false,
	})
	
	return nil
}

// UpdateConfig updates the voice configuration and restarts if needed
func (vs *VoiceService) UpdateConfig(newConfig config.VoiceConfig) error {
	vs.mutex.Lock()
	defer vs.mutex.Unlock()
	
	wasRunning := vs.runner != nil && vs.runner.IsRunning()
	
	// Stop current service if running
	if wasRunning {
		if err := vs.runner.Stop(); err != nil {
			return fmt.Errorf("failed to stop voice service: %w", err)
		}
		// Wait a bit for clean shutdown
		time.Sleep(100 * time.Millisecond)
	}
	
	// Update config
	vs.config = &newConfig
	
	// Update global config
	globalConfig := config.GetConfig()
	globalConfig.Voice = newConfig
	
	// Recreate voice runner with new config
	vs.createVoiceRunner()
	
	// Start if enabled
	if newConfig.Enabled {
		if err := vs.runner.Start(); err != nil {
			return fmt.Errorf("failed to start voice service with new config: %w", err)
		}
		
		// Send WebSocket event
		realtime.BroadcastEvent("voice_status_changed", map[string]interface{}{
			"enabled": true,
			"running": true,
		})
	}
	
	return nil
}

// GetConfig returns the current voice configuration
func (vs *VoiceService) GetConfig() config.VoiceConfig {
	vs.mutex.RLock()
	defer vs.mutex.RUnlock()
	
	return *vs.config
}

// GetStatus returns the current voice service status
func (vs *VoiceService) GetStatus() types.VoiceStatus {
	vs.mutex.RLock()
	defer vs.mutex.RUnlock()
	
	isRunning := vs.runner != nil && vs.runner.IsRunning()
	
	return types.VoiceStatus{
		Enabled:   vs.config.Enabled,
		IsRunning: isRunning,
		Timestamp: time.Now(),
	}
}

// GetInputDevices returns available audio input devices
func (vs *VoiceService) GetInputDevices() ([]types.AudioDevice, error) {
	return vs.getAudioDevices(true)
}

// GetOutputDevices returns available audio output devices
func (vs *VoiceService) GetOutputDevices() ([]types.AudioDevice, error) {
	return vs.getAudioDevices(false)
}

// getAudioDevices gets input or output audio devices
func (vs *VoiceService) getAudioDevices(input bool) ([]types.AudioDevice, error) {
	// Use the ListDevices functionality from voice package
	// This would need to be adapted from the existing ListDevices()
	
	// For now, return a placeholder implementation
	// In a real implementation, you'd call the malgo device enumeration
	devices := []types.AudioDevice{
		{
			ID:       "default",
			Name:     "Default Audio Device",
			IsDefault: true,
		},
	}
	
	return devices, nil
}

// Callback handlers for voice events

// handleWakeWordDetected handles wake word detection events
func (vs *VoiceService) handleWakeWordDetected(label string, score float64) {
	log.Printf("Voice service: Wake word '%s' detected (score: %.3f)", label, score)
	
	// Send WebSocket event
	realtime.BroadcastEvent("voice_wake_detected", map[string]interface{}{
		"label":     label,
		"score":     score,
		"timestamp": time.Now(),
	})
}

// handleTranscription handles speech transcription events
func (vs *VoiceService) handleTranscription(text string, duration, processingTime float64) {
	log.Printf("Voice service: Transcription '%s' (%.2fs audio, %.3fs processing)", 
		text, duration, processingTime)
	
	// Send WebSocket event
	realtime.BroadcastEvent("voice_transcription", map[string]interface{}{
		"text":            text,
		"audio_duration":  duration,
		"processing_time": processingTime,
		"timestamp":       time.Now(),
	})
}

// handleIntent handles voice intent processing and device command execution
func (vs *VoiceService) handleIntent(transcription string, intentResult *types.IntentResult) {
	log.Printf("Voice service: Intent '%s' -> Command '%s'", intentResult.Intent, intentResult.Command)

	// Add to history
	vs.addToHistory(types.VoiceHistoryEntry{
		Timestamp:     time.Now(),
		Transcription: transcription,
		Intent:        intentResult.Intent,
		Command:       intentResult.Command,
		Success:       true,
	})
	
	// Send WebSocket event
	realtime.BroadcastEvent("voice_command_processed", map[string]interface{}{
		"transcription": transcription,
		"intent":        intentResult.Intent,
		"command":       intentResult.Command,
		"timestamp":     time.Now(),
	})
	
	// Execute device command if available
	if vs.deviceCommandFunc != nil && intentResult.Command != "" {
		vs.executeDeviceCommand(intentResult)
	}
}

// handleError handles voice processing errors
func (vs *VoiceService) handleError(message string, processingTime float64) {
	log.Printf("Voice service error: %s (%.3fs processing)", message, processingTime)
	
	// Add to history as failed entry
	vs.addToHistory(types.VoiceHistoryEntry{
		Timestamp:      time.Now(),
		Success:        false,
		Error:          message,
	})
	
	// Send WebSocket event
	realtime.BroadcastEvent("voice_error", map[string]interface{}{
		"message":        message,
		"processing_time": processingTime,
		"timestamp":      time.Now(),
	})
}

// handleStatusUpdate handles general status updates
func (vs *VoiceService) handleStatusUpdate(eventType, message string) {
	log.Printf("Voice service: %s - %s", eventType, message)
	
	// Send WebSocket event
	realtime.BroadcastEvent("voice_status_update", map[string]interface{}{
		"event_type": eventType,
		"message":    message,
		"timestamp":  time.Now(),
	})
}

// addToHistory adds an entry to the voice command history
func (vs *VoiceService) addToHistory(entry types.VoiceHistoryEntry) {
	vs.mutex.Lock()
	defer vs.mutex.Unlock()
	
	// Add to beginning of history
	vs.history = append([]types.VoiceHistoryEntry{entry}, vs.history...)
	
	// Trim to max size
	if len(vs.history) > vs.maxHistory {
		vs.history = vs.history[:vs.maxHistory]
	}
}

// executeDeviceCommand executes a device command parsed from voice intent
func (vs *VoiceService) executeDeviceCommand(intentResult *types.IntentResult) {
	// Skip if no intent was detected
	if intentResult.Command == "" {
		log.Printf("No intent detected in voice command: %s", intentResult.Input)
		return
	}
		
	// Resolve device names from entities
	deviceNames := vs.resolveDeviceNames(intentResult.Entities)
	if len(deviceNames) == 0 {
		log.Printf("No devices resolved from entities: %v", intentResult.Entities)
		return
	}
	
	// Convert intent to device commands
	deviceCommands := vs.intentToDeviceCommands(intentResult.Intent, intentResult.Entities)
	if len(deviceCommands) == 0 {
		log.Printf("No device commands generated for intent: %s", intentResult.Intent)
		return
	}
	
	// Execute commands for each resolved device
	if vs.deviceCommandFunc != nil {
		for _, deviceName := range deviceNames {
			for _, command := range deviceCommands {
				commandJSON, err := json.Marshal(command)
				if err != nil {
					log.Printf("Failed to marshal device command: %v", err)
					continue
				}
				
				log.Printf("Executing voice command: %s -> %s", deviceName, string(commandJSON))
				vs.deviceCommandFunc(deviceName, string(commandJSON))
			}
		}
	}
}

// resolveDeviceNames resolves device names from voice entities
func (vs *VoiceService) resolveDeviceNames(entities map[string]string) []string {
	var deviceNames []string
	
	// Get device and location from entities
	deviceType, hasDevice := entities["device"]
	location, hasLocation := entities["location"]
	
	// If no specific device mentioned, return empty
	if !hasDevice {
		return deviceNames
	}
	
	// Handle special cases like "all lights"
	if deviceType == "lights" || deviceType == "all_lights" {
		// Get all light devices from the system
		devices := vs.getAllLightDevices()
		if hasLocation {
			// Filter by location
			return vs.filterDevicesByLocation(devices, location)
		}
		return devices
	}
	
	// Get all device cache to search through
	deviceCache := vs.getDeviceCacheFunc()
	
	// Search for devices matching the criteria
	for _, device := range deviceCache {
		friendlyName, ok := device["friendly_name"].(string)
		if !ok {
			continue
		}
		
		// Check if device matches the type
		if vs.deviceMatchesType(device, deviceType) {
			// If location specified, check if device is in that location
			if hasLocation {
				if vs.deviceInLocation(friendlyName, location) {
					deviceNames = append(deviceNames, friendlyName)
				}
			} else {
				deviceNames = append(deviceNames, friendlyName)
			}
		}
	}
	
	// If no devices found by type and location, try to find exact device name matches
	if len(deviceNames) == 0 {
		for _, device := range deviceCache {
			friendlyName, ok := device["friendly_name"].(string)
			if !ok {
				continue
			}
			
			// Check for exact name match or custom name match
			if vs.deviceNameMatches(friendlyName, deviceType) {
				if !hasLocation || vs.deviceInLocation(friendlyName, location) {
					deviceNames = append(deviceNames, friendlyName)
				}
			}
		}
	}
	
	return deviceNames
}

// intentToDeviceCommands converts voice intents to device commands
func (vs *VoiceService) intentToDeviceCommands(intent string, entities map[string]string) []map[string]interface{} {
	var commands []map[string]interface{}
	
	switch intent {
	case "switch_on":
		commands = append(commands, map[string]interface{}{
			"state": "ON",
		})
		
	case "switch_off":
		commands = append(commands, map[string]interface{}{
			"state": "OFF",
		})
		
	case "dim":
		// Try to set a dim brightness (30% of max)
		commands = append(commands, map[string]interface{}{
			"brightness": 76, // 30% of 255
		})
		
	case "brighten":
		// Set to brighter level (80% of max)
		commands = append(commands, map[string]interface{}{
			"brightness": 204, // 80% of 255
		})
		
	case "set_brightness":
		if intensity, ok := entities["intensity"]; ok {
			if brightness := vs.parseIntensity(intensity); brightness >= 0 {
				commands = append(commands, map[string]interface{}{
					"brightness": brightness,
				})
			}
		}
		
	case "set_color":
		if color, ok := entities["color"]; ok {
			if colorHex := vs.parseColor(color); colorHex != "" {
				commands = append(commands, map[string]interface{}{
					"color": map[string]interface{}{
						"hex": colorHex,
					},
				})
			}
		}
	}
	
	return commands
}

// Helper functions for device resolution

func (vs *VoiceService) getAllLightDevices() []string {
	var lights []string
	
	deviceCache := vs.getDeviceCacheFunc()
	
	for _, device := range deviceCache {
		if vs.deviceMatchesType(device, "light") {
			if friendlyName, ok := device["friendly_name"].(string); ok {
				lights = append(lights, friendlyName)
			}
		}
	}
	
	return lights
}

func (vs *VoiceService) filterDevicesByLocation(devices []string, location string) []string {
	var filtered []string
	for _, device := range devices {
		if vs.deviceInLocation(device, location) {
			filtered = append(filtered, device)
		}
	}
	return filtered
}

func (vs *VoiceService) deviceMatchesType(device map[string]interface{}, deviceType string) bool {
	// Check device definition/type
	if definition, ok := device["definition"].(map[string]interface{}); ok {
		if model, ok := definition["model"].(string); ok {
			modelLower := strings.ToLower(model)
			typeLower := strings.ToLower(deviceType)
			
			// Simple keyword matching for device types
			switch typeLower {
			case "light", "lights":
				return strings.Contains(modelLower, "light") || 
				       strings.Contains(modelLower, "bulb") ||
				       strings.Contains(modelLower, "lamp")
			case "switch", "switches":
				return strings.Contains(modelLower, "switch")
			case "sensor", "sensors":
				return strings.Contains(modelLower, "sensor")
			}
		}
	}
	
	// Check friendly name for type
	if friendlyName, ok := device["friendly_name"].(string); ok {
		nameLower := strings.ToLower(friendlyName)
		typeLower := strings.ToLower(deviceType)
		return strings.Contains(nameLower, typeLower)
	}
	
	return false
}

func (vs *VoiceService) deviceInLocation(deviceName, location string) bool {
	// Get device zones
	zones := vs.getDeviceZonesFunc(deviceName)
	
	// Check if any zone matches the location
	locationLower := strings.ToLower(location)
	for _, zone := range zones {
		zoneLower := strings.ToLower(zone)
		if zoneLower == locationLower || strings.Contains(zoneLower, locationLower) {
			return true
		}
	}
	
	// Also check device name for location hints
	deviceLower := strings.ToLower(deviceName)
	return strings.Contains(deviceLower, locationLower)
}

func (vs *VoiceService) deviceNameMatches(deviceName, targetName string) bool {
	deviceLower := strings.ToLower(deviceName)
	targetLower := strings.ToLower(targetName)
	
	// Exact match or contains
	return deviceLower == targetLower || strings.Contains(deviceLower, targetLower)
}

func (vs *VoiceService) parseIntensity(intensity string) int {
	// Remove % sign if present
	intensity = strings.TrimSuffix(intensity, "%")
	intensity = strings.TrimSpace(intensity)
	
	// Parse as integer
	if val, err := strconv.Atoi(intensity); err == nil {
		// If it's a percentage (0-100), convert to 0-255 range
		if val <= 100 {
			return int(float64(val) * 2.55) // Convert percentage to 0-255
		}
		// If already in 0-255 range, return as is
		if val <= 255 {
			return val
		}
	}
	
	return -1 // Invalid intensity
}

func (vs *VoiceService) parseColor(color string) string {
	colorLower := strings.ToLower(strings.TrimSpace(color))
	
	// Map common color names to hex values
	colorMap := map[string]string{
		"red":    "#FF0000",
		"green":  "#00FF00",
		"blue":   "#0000FF",
		"yellow": "#FFFF00",
		"white":  "#FFFFFF",
		"warm":   "#FFE4B5", // Warm white
		"cool":   "#E0F6FF", // Cool white
		"purple": "#800080",
		"orange": "#FFA500",
		"pink":   "#FFC0CB",
	}
	
	if hex, ok := colorMap[colorLower]; ok {
		return hex
	}
	
	// If already a hex color, return as is
	if strings.HasPrefix(colorLower, "#") && len(colorLower) == 7 {
		return colorLower
	}
	
	return "" // Unknown color
}

// GetHistory returns recent voice command history
func (vs *VoiceService) GetHistory(limit int) []types.VoiceHistoryEntry {
	vs.mutex.RLock()
	defer vs.mutex.RUnlock()
	
	if limit <= 0 || limit > len(vs.history) {
		limit = len(vs.history)
	}
	
	// Return a copy of the history slice
	result := make([]types.VoiceHistoryEntry, limit)
	copy(result, vs.history[:limit])
	return result
}

