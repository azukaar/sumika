package services

import (
	"encoding/json"
	"fmt"
	"log"
	"sync"
	"time"

	"github.com/azukaar/sumika/server/config"
	"github.com/azukaar/sumika/server/realtime"
	"github.com/azukaar/sumika/server/types"
	"github.com/gen2brain/malgo"
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
	if input {
		return getAudioInputDevices()
	} else {
		return getAudioOutputDevices()
	}
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
	if !intentResult.Success {
		log.Printf("Voice service: Intent processing failed for '%s': %s", transcription, intentResult.Error)
		
		// Add failed entry to history
		vs.addToHistory(types.VoiceHistoryEntry{
			Timestamp:     time.Now(),
			Transcription: transcription,
			Success:       false,
			Error:         intentResult.Error,
		})
		
		// Send WebSocket event for failed intent
		realtime.BroadcastEvent("voice_intent_failed", map[string]interface{}{
			"transcription": transcription,
			"error":         intentResult.Error,
			"timestamp":     time.Now(),
		})
		return
	}

	log.Printf("Voice service: Successfully processed '%s' -> %d device commands", transcription, len(intentResult.Commands))

	// Add to history
	commandSummary := ""
	if len(intentResult.Commands) > 0 {
		commandSummary = fmt.Sprintf("%d commands", len(intentResult.Commands))
	}
	
	vs.addToHistory(types.VoiceHistoryEntry{
		Timestamp:     time.Now(),
		Transcription: transcription,
		Command:       commandSummary,
		Success:       true,
	})
	
	// Send WebSocket event
	realtime.BroadcastEvent("voice_command_processed", map[string]interface{}{
		"transcription": transcription,
		"commands":      intentResult.Commands,
		"timestamp":     time.Now(),
	})
	
	// Execute device commands if available
	if vs.deviceCommandFunc != nil && len(intentResult.Commands) > 0 {
		vs.executeDeviceCommands(intentResult)
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

// executeDeviceCommands executes device commands from voice intent
func (vs *VoiceService) executeDeviceCommands(intentResult *types.IntentResult) {
	if len(intentResult.Commands) == 0 {
		log.Printf("No device commands to execute")
		return
	}
	
	// Execute each device command
	for _, deviceCmd := range intentResult.Commands {
		// Create the device command structure for MQTT
		command := map[string]interface{}{
			deviceCmd.Property: deviceCmd.Value,
		}
		
		commandJSON, err := json.Marshal(command)
		if err != nil {
			log.Printf("Failed to marshal device command: %v", err)
			continue
		}
		
		// Use IEEE address as the device identifier
		deviceName := deviceCmd.IEEEAddress
		displayName := deviceCmd.CustomName
		if displayName == "" {
			displayName = deviceCmd.FriendlyName
		}
		
		log.Printf("Executing voice command: %s (%s) -> %s = %v", 
			displayName, deviceName, deviceCmd.Property, deviceCmd.Value)
		
		// Execute the command via the registered callback
		if vs.deviceCommandFunc != nil {
			vs.deviceCommandFunc(deviceName, string(commandJSON))
		}
	}
}

// GetHistory returns the voice command history
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

// getAudioInputDevices returns available audio input devices
func getAudioInputDevices() ([]types.AudioDevice, error) {
	ctx, err := malgo.InitContext(nil, malgo.ContextConfig{}, func(message string) {
		// Silent callback for device enumeration
	})
	if err != nil {
		return nil, fmt.Errorf("failed to initialize audio context: %w", err)
	}
	defer func() {
		_ = ctx.Uninit()
		ctx.Free()
	}()

	devices, err := ctx.Devices(malgo.Capture)
	if err != nil {
		return nil, fmt.Errorf("failed to enumerate input devices: %w", err)
	}

	var audioDevices []types.AudioDevice
	var defaultDeviceName string = "System Default"
	
	// Find the actual default device name
	for _, device := range devices {
		info, err := ctx.DeviceInfo(malgo.Capture, device.ID, malgo.Shared)
		if err != nil {
			log.Printf("Warning: Failed to get info for input device %s: %v", device.Name(), err)
			continue
		}
		
		if info.IsDefault == 1 {
			defaultDeviceName = device.Name()
		}
	}
	
	// Add default device first with actual default device name
	audioDevices = append(audioDevices, types.AudioDevice{
		ID:        "default",
		Name:      fmt.Sprintf("Default (%s)", defaultDeviceName),
		IsDefault: true,
	})

	for _, device := range devices {
		audioDevices = append(audioDevices, types.AudioDevice{
			ID:        fmt.Sprintf("%v", device.ID),
			Name:      device.Name(),
			IsDefault: false,
		})
		
		log.Printf("Found input device: %s", device.Name())
	}

	return audioDevices, nil
}

// getAudioOutputDevices returns available audio output devices
func getAudioOutputDevices() ([]types.AudioDevice, error) {
	ctx, err := malgo.InitContext(nil, malgo.ContextConfig{}, func(message string) {
		// Silent callback for device enumeration
	})
	if err != nil {
		return nil, fmt.Errorf("failed to initialize audio context: %w", err)
	}
	defer func() {
		_ = ctx.Uninit()
		ctx.Free()
	}()

	devices, err := ctx.Devices(malgo.Playback)
	if err != nil {
		return nil, fmt.Errorf("failed to enumerate output devices: %w", err)
	}

	var audioDevices []types.AudioDevice
	var defaultDeviceName string = "System Default"
	
	// Find the actual default device name
	for _, device := range devices {
		info, err := ctx.DeviceInfo(malgo.Playback, device.ID, malgo.Shared)
		if err != nil {
			log.Printf("Warning: Failed to get info for output device %s: %v", device.Name(), err)
			continue
		}
		
		if info.IsDefault == 1 {
			defaultDeviceName = device.Name()
		}
	}
	
	// Add default device first with actual default device name
	audioDevices = append(audioDevices, types.AudioDevice{
		ID:        "default",
		Name:      fmt.Sprintf("Default (%s)", defaultDeviceName),
		IsDefault: true,
	})

	for _, device := range devices {
		audioDevices = append(audioDevices, types.AudioDevice{
			ID:        fmt.Sprintf("%v", device.ID),
			Name:      device.Name(),
			IsDefault: false,
		})
		
		log.Printf("Found output device: %s", device.Name())
	}

	return audioDevices, nil
}
