package types

import (
	"time"

	"github.com/azukaar/sumika/server/config"
)

// VoiceConfig represents voice recognition configuration
type VoiceConfig struct {
    WhisperModel  string
    WhisperDevice string
    ComputeType   string
    WakeThreshold float64
    InputDevice   string
    OutputDevice  string
}

// VoiceCallbacks represents callbacks for voice events
type VoiceCallbacks struct {
    OnWakeWordDetected func(label string, score float64)
    OnTranscription    func(text string, duration, processingTime float64)
    OnIntent           func(transcription string, intentResult *IntentResult)
    OnError            func(message string, processingTime float64)
    OnStatusUpdate     func(eventType, message string)
}


// AudioDevice represents an audio input/output device
type AudioDevice struct {
    ID       string `json:"id"`
    Name     string `json:"name"`
    IsDefault bool  `json:"is_default"`
}

// VoiceStatus represents the current voice service status
type VoiceStatus struct {
    Enabled     bool      `json:"enabled"`
    IsRunning   bool      `json:"is_running"`
    LastCommand string    `json:"last_command,omitempty"`
    LastIntent  string    `json:"last_intent,omitempty"`
    Timestamp   time.Time `json:"timestamp"`
}

type IntentResult struct {
    Intent   string            `json:"intent"`
    Entities map[string]string `json:"entities"`
    Command  string            `json:"command"`
    Input    string            `json:"input"`
}

// VoiceHistoryEntry represents a voice command history entry
type VoiceHistoryEntry struct {
    Timestamp     time.Time `json:"timestamp"`
    Transcription string    `json:"transcription"`
    Intent        string    `json:"intent,omitempty"`
    Command       string    `json:"command,omitempty"`
    Success       bool      `json:"success"`
    Error         string    `json:"error,omitempty"`
}

type VoiceServiceInterface interface {
	Start() error
	Stop() error
	GetConfig() config.VoiceConfig
	UpdateConfig(config.VoiceConfig) error
	GetStatus() VoiceStatus
	GetInputDevices() ([]AudioDevice, error)
	GetOutputDevices() ([]AudioDevice, error)
	GetHistory(limit int) []VoiceHistoryEntry
}