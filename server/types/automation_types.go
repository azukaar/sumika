package types

import "time"

type Automation struct {
	ID          string            `json:"id"`
	Name        string            `json:"name"`
	Description string            `json:"description"`
	Enabled     bool              `json:"enabled"`
	Type        string            `json:"type"` // "ifttt"
	Trigger     AutomationTrigger `json:"trigger"`
	Action      AutomationAction  `json:"action"`
	CreatedAt   time.Time         `json:"created_at,omitempty"`
	UpdatedAt   time.Time         `json:"updated_at,omitempty"`
}

type AutomationTrigger struct {
	DeviceName    string      `json:"device_name"`
	Property      string      `json:"property"`      // e.g., "state", "brightness", "temperature"
	Condition     string      `json:"condition"`     // "equals", "greater_than", "less_than", "changed", "pressed", "double_pressed", "triple_pressed", "long_pressed"
	Value         interface{} `json:"value"`
	PreviousValue interface{} `json:"previous_value,omitempty"` // For "changed" condition
}

type AutomationAction struct {
	// Individual device action
	DeviceName string `json:"device_name,omitempty"`
	
	// Zone-based action
	Zone     string `json:"zone,omitempty"`
	Category string `json:"category,omitempty"`
	
	// Scene-based action
	SceneZone string `json:"scene_zone,omitempty"`
	SceneName string `json:"scene_name,omitempty"`
	
	// Common fields (not used for scene actions)
	Property string      `json:"property,omitempty"`
	Value    interface{} `json:"value,omitempty"`
}

// Button press tracking for detecting double presses and timing
type ButtonPressState struct {
	DeviceName     string
	Property       string
	LastPressTime  time.Time
	PressCount     int
	LongPressTimer *time.Timer
	DoublePressPending bool
}