package manage

import (
	"encoding/json"
	"fmt"
	"slices"
	"sort"
	"strconv"
	"strings"
	"time"
)

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
	DeviceName string      `json:"device_name,omitempty"`
	
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

var automations = []Automation{}

// Button press tracking for detecting double presses and timing
type ButtonPressState struct {
	DeviceName     string
	Property       string
	LastPressTime  time.Time
	PressCount     int
	LongPressTimer *time.Timer
	DoublePressPending bool
}

var buttonStates = make(map[string]*ButtonPressState)

// Timing constants for button press detection
const (
	DoublePressWindow = 600 * time.Millisecond  // Time window to detect double press
	LongPressDelay    = 800 * time.Millisecond  // Time to wait before triggering long press
)

// Scene configuration structures
type SceneLight struct {
	Hue        float64 `json:"hue"`        // 0-360
	Saturation float64 `json:"saturation"` // 0-1
	Brightness float64 `json:"brightness"` // 0-254
}

type LightingScene struct {
	ID         string       `json:"id"`         // Unique identifier
	Name       string       `json:"name"`
	Lights     []SceneLight `json:"lights"`
	ImagePath  string       `json:"image_path,omitempty"` // Custom uploaded image path
	Order      int          `json:"order"`      // Display order
	IsCustom   bool         `json:"is_custom"`  // True for user-created scenes
	CreatedAt  string       `json:"created_at,omitempty"`
	UpdatedAt  string       `json:"updated_at,omitempty"`
}

// getSceneConfig returns the scene configuration for a given scene name
func getSceneConfig(sceneName string) *LightingScene {
	sceneService := NewSceneService()
	return sceneService.GetSceneByName(sceneName)
}

// CreateAutomation creates a new automation
func CreateAutomation(automation Automation) string {
	id := fmt.Sprintf("auto_%d", time.Now().Unix())
	
	// Set server-side timestamps
	automation.ID = id
	automation.CreatedAt = time.Now()
	automation.UpdatedAt = time.Now()
	
	automations = append(automations, automation)
	SaveToStorage()
	return id
}

// GetAllAutomations returns all automations
func GetAllAutomations() []Automation {
	return automations
}

// GetAutomationByID returns an automation by ID
func GetAutomationByID(id string) *Automation {
	for i := range automations {
		if automations[i].ID == id {
			return &automations[i]
		}
	}
	return nil
}

// UpdateAutomation updates an existing automation
func UpdateAutomation(id string, updates map[string]interface{}) bool {
	for i := range automations {
		if automations[i].ID == id {
			if name, ok := updates["name"].(string); ok {
				automations[i].Name = name
			}
			if description, ok := updates["description"].(string); ok {
				automations[i].Description = description
			}
			if enabled, ok := updates["enabled"].(bool); ok {
				automations[i].Enabled = enabled
			}
			automations[i].UpdatedAt = time.Now()
			SaveToStorage()
			return true
		}
	}
	return false
}

// UpdateFullAutomation replaces an existing automation completely
func UpdateFullAutomation(id string, updatedAutomation Automation) bool {
	for i := range automations {
		if automations[i].ID == id {
			// Preserve original creation time and ID
			updatedAutomation.ID = id
			updatedAutomation.CreatedAt = automations[i].CreatedAt
			updatedAutomation.UpdatedAt = time.Now()
			
			// Replace the automation
			automations[i] = updatedAutomation
			SaveToStorage()
			return true
		}
	}
	return false
}

// DeleteAutomation deletes an automation by ID
func DeleteAutomation(id string) bool {
	for i, automation := range automations {
		if automation.ID == id {
			automations = append(automations[:i], automations[i+1:]...)
			SaveToStorage()
			return true
		}
	}
	return false
}

// CheckTriggers checks if any automation triggers should fire based on device state changes
func CheckTriggers(deviceName string, oldState, newState map[string]interface{}) {
	fmt.Printf("[AUTOMATION] Checking triggers for device: %s\n", deviceName)
	fmt.Printf("[AUTOMATION] Total automations: %d\n", len(automations))
	
	for _, automation := range automations {
		if !automation.Enabled {
			continue
		}
		
		if automation.Trigger.DeviceName != deviceName {
			continue
		}
		
		triggered := false
		property := automation.Trigger.Property
		condition := automation.Trigger.Condition
		triggerValue := automation.Trigger.Value
		
		// Get the current value of the property
		currentValue, exists := newState[property]
		if !exists {
			continue
		}
		
		// Handle IFTTT rules with conditions
		switch condition {
		case "equals":
			triggered = compareValues(currentValue, triggerValue, "equals")
			
		case "greater_than":
			triggered = compareValues(currentValue, triggerValue, "greater_than")
			
		case "less_than":
			triggered = compareValues(currentValue, triggerValue, "less_than")
			
		case "changed":
			oldValue, oldExists := oldState[property]
			if oldExists && !compareValues(currentValue, oldValue, "equals") {
				triggered = true
			}
		
		case "pressed":
			// Handle single press with timing consideration
			if currentValue == "single" || currentValue == "press" || currentValue == true {
				triggered = handleButtonPress(deviceName, property, "pressed", automation)
			}
		
		case "double_pressed":
			// Handle double press detection
			if currentValue == "single" || currentValue == "press" || currentValue == true {
				triggered = handleButtonPress(deviceName, property, "double_pressed", automation)
			}
		
		case "long_pressed":
			// Handle long press - this will be triggered by timer, not immediately
			if currentValue == "hold" || currentValue == "long" {
				triggered = handleButtonPress(deviceName, property, "long_pressed", automation)
			}
		}
		
		if triggered {
			ExecuteAutomationAction(automation)
		}
	}
}

// handleButtonPress handles button press detection with debouncing for single, double, and long press
func handleButtonPress(deviceName, property, condition string, automation Automation) bool {
	stateKey := fmt.Sprintf("%s_%s", deviceName, property)
	now := time.Now()
	
	// Get or create button state
	state, exists := buttonStates[stateKey]
	if !exists {
		state = &ButtonPressState{
			DeviceName: deviceName,
			Property:   property,
		}
		buttonStates[stateKey] = state
	}
	
	fmt.Printf("[BUTTON] Handling %s for %s.%s\n", condition, deviceName, property)
	
	// Handle different conditions
	switch condition {
	case "long_pressed":
		// Long press from device - cancel any pending single press and trigger immediately
		fmt.Printf("[BUTTON] Long press detected for %s.%s - cancelling any pending single press\n", deviceName, property)
		state.DoublePressPending = false // Cancel any pending single press
		if state.LongPressTimer != nil {
			state.LongPressTimer.Stop()
			state.LongPressTimer = nil
		}
		return true
		
	case "pressed":
		timeSinceLastPress := now.Sub(state.LastPressTime)
		
		// Cancel any existing long press timer
		if state.LongPressTimer != nil {
			state.LongPressTimer.Stop()
			state.LongPressTimer = nil
		}
		
		if timeSinceLastPress < DoublePressWindow && state.PressCount == 1 && state.DoublePressPending {
			// Second press within double press window - this is a double press
			state.PressCount = 2
			state.LastPressTime = now
			state.DoublePressPending = false // Cancel pending single press
			fmt.Printf("[BUTTON] Double press detected for %s.%s - cancelling single press\n", deviceName, property)
			
			// Trigger any double press automations immediately
			for _, auto := range automations {
				if auto.Enabled && auto.Trigger.DeviceName == deviceName && 
				   auto.Trigger.Property == property && auto.Trigger.Condition == "double_pressed" {
					fmt.Printf("[BUTTON] Executing double press automation: %s\n", auto.Name)
					go ExecuteAutomationAction(auto)
				}
			}
			return false // Don't trigger the current single press automation
		} else {
			// First press or press after timeout - start debounce timer
			state.PressCount = 1
			state.LastPressTime = now
			state.DoublePressPending = true
			
			fmt.Printf("[BUTTON] Starting debounce for single press on %s.%s\n", deviceName, property)
			
			// Debounce the single press - wait to see if double press or long press happens
			go func() {
				time.Sleep(DoublePressWindow)
				
				// Check if single press is still pending (not cancelled by double press or long press)
				if state.DoublePressPending && state.PressCount == 1 {
					fmt.Printf("[BUTTON] Single press confirmed for %s.%s (debounce completed)\n", deviceName, property)
					state.DoublePressPending = false
					ExecuteAutomationAction(automation)
				}
			}()
			
			return false // Don't trigger immediately, wait for debounce
		}
		
	case "double_pressed":
		// This condition is handled within the "pressed" case above
		return false
	}
	
	return false
}

// ExecuteAutomationAction executes the action of an automation
func ExecuteAutomationAction(automation Automation) {
	action := automation.Action
	
	// Check if this is a scene-based action
	if action.SceneZone != "" && action.SceneName != "" {
		ExecuteSceneBasedAction(action)
		return
	}
	
	// Check if this is a zone-based action
	if action.Zone != "" {
		ExecuteZoneBasedAction(action)
		return
	}
	
	// Individual device action
	ExecuteAutomationActionWithValue(automation, automation.Action.Value)
}

// ExecuteAutomationActionWithValue executes the action of an automation with a specific value (for device linking)
func ExecuteAutomationActionWithValue(automation Automation, value interface{}) {
	action := automation.Action
	
	// Create the command to send to the device
	command := map[string]interface{}{
		action.Property: value,
	}
	
	// Convert to JSON for the zigbee2mqtt topic
	commandJSON, err := json.Marshal(command)
	if err != nil {
		fmt.Printf("Error marshaling automation command: %v\n", err)
		return
	}
	
	fmt.Printf("Executing automation '%s': sending %s to device %s\n", 
		automation.Name, string(commandJSON), action.DeviceName)
	
	// Send the command via zigbee2mqtt
	SendDeviceCommand(action.DeviceName, string(commandJSON))
}

// compareValues compares two values based on the given condition
func compareValues(a, b interface{}, condition string) bool {
	switch condition {
	case "equals":
		return a == b
		
	case "greater_than":
		aFloat, aOk := convertToFloat(a)
		bFloat, bOk := convertToFloat(b)
		if aOk && bOk {
			return aFloat > bFloat
		}
		return false
		
	case "less_than":
		aFloat, aOk := convertToFloat(a)
		bFloat, bOk := convertToFloat(b)
		if aOk && bOk {
			return aFloat < bFloat
		}
		return false
	}
	return false
}

// convertToFloat converts an interface{} to float64 if possible
func convertToFloat(v interface{}) (float64, bool) {
	switch val := v.(type) {
	case float64:
		return val, true
	case float32:
		return float64(val), true
	case int:
		return float64(val), true
	case int64:
		return float64(val), true
	case string:
		if f, err := strconv.ParseFloat(val, 64); err == nil {
			return f, true
		}
	}
	return 0, false
}

// GetAutomationsForDevice returns all automations that involve a specific device
func GetAutomationsForDevice(deviceName string) []Automation {
	var result []Automation
	for _, automation := range automations {
		if automation.Trigger.DeviceName == deviceName || automation.Action.DeviceName == deviceName {
			result = append(result, automation)
		}
	}
	return result
}

// ValidateAutomation validates an automation's structure
func ValidateAutomation(automation Automation) []string {
	var errors []string
	
	if automation.Name == "" {
		errors = append(errors, "name is required")
	}
	
	if automation.Type != "ifttt" {
		errors = append(errors, "type must be 'ifttt'")
	}
	
	if automation.Trigger.DeviceName == "" {
		errors = append(errors, "trigger device name is required")
	}
	
	if automation.Trigger.Property == "" {
		errors = append(errors, "trigger property is required")
	}
	
	validConditions := []string{"equals", "greater_than", "less_than", "changed", "pressed", "double_pressed", "long_pressed"}
	if !slices.Contains(validConditions, automation.Trigger.Condition) {
		errors = append(errors, "trigger condition must be one of: equals, greater_than, less_than, changed, pressed, double_pressed, long_pressed")
	}
	
	// Action must have either a device name OR a zone OR a scene
	actionCount := 0
	if automation.Action.DeviceName != "" {
		actionCount++
	}
	if automation.Action.Zone != "" {
		actionCount++
	}
	if automation.Action.SceneZone != "" && automation.Action.SceneName != "" {
		actionCount++
	}
	
	if actionCount == 0 {
		errors = append(errors, "action must specify either device_name, zone, or scene")
	}
	if actionCount > 1 {
		errors = append(errors, "action cannot specify multiple action types (device_name, zone, scene)")
	}
	
	// Property is required for device and zone actions, but not for scene actions
	if automation.Action.Property == "" && automation.Action.SceneZone == "" {
		errors = append(errors, "action property is required for device and zone actions")
	}
	
	// For IFTTT rules, trigger value is required unless condition is "changed" or button conditions
	buttonConditions := []string{"changed", "pressed", "double_pressed", "long_pressed"}
	if !slices.Contains(buttonConditions, automation.Trigger.Condition) && automation.Trigger.Value == nil {
		errors = append(errors, "trigger value is required (except for 'changed' and button conditions)")
	}
	// Action value is required for device and zone actions, but not for scene actions
	if automation.Action.Value == nil && automation.Action.SceneZone == "" {
		errors = append(errors, "action value is required for device and zone actions")
	}
	
	return errors
}

// ExecuteSceneBasedAction executes a lighting scene in a specific zone
func ExecuteSceneBasedAction(action AutomationAction) {
	if action.SceneZone == "" || action.SceneName == "" {
		fmt.Printf("Error: Scene-based action missing zone or scene name\n")
		return
	}
	
	fmt.Printf("Executing scene automation: applying scene '%s' to zone '%s'\n", action.SceneName, action.SceneZone)
	
	// Get all light devices in the zone
	lightDevices := GetDevicesByZoneAndCategory(action.SceneZone, "light")
	
	if len(lightDevices) == 0 {
		fmt.Printf("No light devices found in zone '%s'\n", action.SceneZone)
		return
	}
	
	// Sort light devices by display name to match dashboard behavior
	// Dashboard sorts by GetDeviceDisplayName() which returns custom name or friendly name
	sort.Slice(lightDevices, func(i, j int) bool {
		displayNameI := GetDeviceDisplayName(lightDevices[i])
		displayNameJ := GetDeviceDisplayName(lightDevices[j])
		return strings.Compare(displayNameI, displayNameJ) < 0
	})
	
	fmt.Printf("Found %d light devices in zone '%s' for scene '%s'\n", len(lightDevices), action.SceneZone, action.SceneName)
	
	// Get scene configuration
	sceneConfig := getSceneConfig(action.SceneName)
	if sceneConfig == nil {
		fmt.Printf("Unknown scene: %s\n", action.SceneName)
		return
	}
	
	// Apply scene to each light device
	for i, deviceName := range lightDevices {
		// Get the scene light configuration (loop through colors if more lights than colors)
		lightIndex := i % len(sceneConfig.Lights)
		sceneLight := sceneConfig.Lights[lightIndex]
		
		// Build command JSON for Zigbee2MQTT
		command := map[string]interface{}{
			"state":      "ON",
			"brightness": int(sceneLight.Brightness),
			"color": map[string]interface{}{
				"hue":        int(sceneLight.Hue),
				"saturation": int(sceneLight.Saturation * 100), // Convert to 0-100 for Zigbee
			},
			"transition": 0.5, // Smooth transition
		}
		
		// Convert to JSON string
		commandJSON, err := json.Marshal(command)
		if err != nil {
			fmt.Printf("Error marshaling scene command for device %s: %v\n", deviceName, err)
			continue
		}
		
		fmt.Printf("Applying scene '%s' to device %s: %s\n", action.SceneName, deviceName, string(commandJSON))
		
		// Send the command via zigbee2mqtt
		SendDeviceCommand(deviceName, string(commandJSON))
	}
}

// SendDeviceCommand is a callback function that will be set by the main application
// to bridge the automation system with the zigbee2mqtt command sending
var SendDeviceCommand func(deviceName, command string) = func(deviceName, command string) {
	fmt.Printf("SendDeviceCommand not initialized - would send: %s to %s\n", command, deviceName)
}


// GetDeviceState is a callback function that will be set by the main application
// to get current device state for property extraction
var GetDeviceState func(deviceName string) map[string]interface{} = func(deviceName string) map[string]interface{} {
	fmt.Printf("GetDeviceState not initialized - cannot get state for %s\n", deviceName)
	return map[string]interface{}{}
}

// GetDeviceProperties returns the available properties for a device based on its current state
func GetDeviceProperties(deviceName string) []string {
	state := GetDeviceState(deviceName)
	if state == nil {
		return []string{}
	}
	
	var properties []string
	for key := range state {
		// Skip empty or nil keys
		if key == "" {
			continue
		}
		// Filter out internal/system properties that shouldn't be used in automations
		if !isSystemProperty(key) {
			properties = append(properties, key)
		}
	}
	
	return properties
}

// isSystemProperty checks if a property is a system/internal property that shouldn't be exposed
func isSystemProperty(property string) bool {
	systemProperties := map[string]bool{
		"last_seen":        true,
		"linkquality":     true,
		"update":          true,
		"update_available": true,
		"device_temperature": true,
		"power_on_behavior": true,
	}
	return systemProperties[property]
}