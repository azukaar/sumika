package services

import (
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/azukaar/sumika/server/storage"
	"github.com/azukaar/sumika/server/types"
)

// Button press tracking for detecting double presses and timing
type ButtonPressState struct {
	DeviceName     string
	Property       string
	LastPressTime  time.Time
	PressCount     int
	LongPressTimer *time.Timer
	DoublePressPending bool
}

// Timing constants for button press detection
const (
	DoublePressWindow = 600 * time.Millisecond  // Time window to detect double press
	LongPressDelay    = 800 * time.Millisecond  // Time to wait before triggering long press
)

// AutomationService handles business logic for automation operations
type AutomationService struct {
	sceneService *SceneService
	buttonStates map[string]*ButtonPressState
	SendDeviceCommand func(deviceName, command string)
}

// NewAutomationService creates a new automation service
func NewAutomationService(sceneService *SceneService) *AutomationService {
	return &AutomationService{
		sceneService: sceneService,
		buttonStates: make(map[string]*ButtonPressState),
		SendDeviceCommand: func(deviceName, command string) {
			fmt.Printf("SendDeviceCommand not initialized - would send: %s to %s\n", command, deviceName)
		},
	}
}

// GetAllAutomations returns all automations
func (s *AutomationService) GetAllAutomations() ([]types.Automation, error) {
	return storage.GetAllAutomations(), nil
}

// GetAutomationByID returns an automation by ID
func (s *AutomationService) GetAutomationByID(id string) (*types.Automation, error) {
	if strings.TrimSpace(id) == "" {
		return nil, fmt.Errorf("automation ID cannot be empty")
	}
	
	return storage.GetAutomationByID(id), nil
}

// CreateAutomation creates a new automation with validation
func (s *AutomationService) CreateAutomation(automation types.Automation) (string, error) {
	// Validate automation
	if err := s.validateAutomation(automation); err != nil {
		return "", fmt.Errorf("automation validation failed: %w", err)
	}
	
	created, err := storage.CreateAutomation(automation)
	if err != nil {
		return "", err
	}
	
	return created.ID, nil
}

// UpdateAutomation updates an entire automation
func (s *AutomationService) UpdateAutomation(id string, automation types.Automation) error {
	if strings.TrimSpace(id) == "" {
		return fmt.Errorf("automation ID cannot be empty")
	}
	
	// Validate automation
	if err := s.validateAutomation(automation); err != nil {
		return fmt.Errorf("automation validation failed: %w", err)
	}
	
	return storage.UpdateAutomation(id, automation)
}

// ToggleAutomationEnabled updates only the enabled state of an automation
func (s *AutomationService) ToggleAutomationEnabled(id string, enabled bool) error {
	if strings.TrimSpace(id) == "" {
		return fmt.Errorf("automation ID cannot be empty")
	}
	
	// Get the existing automation
	existingAutomation := storage.GetAutomationByID(id)
	if existingAutomation == nil {
		return fmt.Errorf("automation with ID %s not found", id)
	}
	
	// Update only the enabled field
	existingAutomation.Enabled = enabled
	
	// Update the automation (no need for full validation since we're only changing enabled state)
	return storage.UpdateAutomation(id, *existingAutomation)
}

// DeleteAutomation removes an automation
func (s *AutomationService) DeleteAutomation(id string) error {
	if strings.TrimSpace(id) == "" {
		return fmt.Errorf("automation ID cannot be empty")
	}
	
	return storage.DeleteAutomation(id)
}

// CheckTriggers checks if any automations should be triggered
func (s *AutomationService) CheckTriggers(deviceName string, oldState, newState map[string]interface{}) {
	fmt.Printf("[AUTOMATION] Checking triggers for device: %s\n", deviceName)
	
	automations, err := s.GetAllAutomations()
	if err != nil {
		fmt.Printf("Failed to get automations for trigger check: %v\n", err)
		return
	}
	
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
			triggered = s.compareValues(currentValue, triggerValue, "equals")
			
		case "greater_than":
			triggered = s.compareValues(currentValue, triggerValue, "greater_than")
			
		case "less_than":
			triggered = s.compareValues(currentValue, triggerValue, "less_than")
			
		case "changed":
			oldValue, oldExists := oldState[property]
			if oldExists && !s.compareValues(currentValue, oldValue, "equals") {
				triggered = true
			}
		
		case "pressed":
			// Handle single press with timing consideration
			if currentValue == "on" || currentValue == "press" || currentValue == "single" || currentValue == true {
				triggered = s.handleButtonPress(deviceName, property, "pressed", automation)
			}
		
		case "double_pressed":
			// Handle double press detection  
			if currentValue == "on" || currentValue == "press" || currentValue == "single" || currentValue == true {
				triggered = s.handleButtonPress(deviceName, property, "double_pressed", automation)
			}
		
		case "long_pressed":
			// Handle long press - this will be triggered by timer, not immediately
			if currentValue == "hold" || currentValue == "long" {
				triggered = s.handleButtonPress(deviceName, property, "long_pressed", automation)
			}
		}
		
		if triggered {
			s.ExecuteAutomationAction(automation)
		}
	}
}

// handleButtonPress handles button press detection with debouncing for single, double, and long press
func (s *AutomationService) handleButtonPress(deviceName, property, condition string, automation types.Automation) bool {
	stateKey := fmt.Sprintf("%s_%s", deviceName, property)
	now := time.Now()
	
	// Get or create button state
	state, exists := s.buttonStates[stateKey]
	if !exists {
		state = &ButtonPressState{
			DeviceName: deviceName,
			Property:   property,
		}
		s.buttonStates[stateKey] = state
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
			automations, err := s.GetAllAutomations()
			if err == nil {
				for _, auto := range automations {
					if auto.Enabled && auto.Trigger.DeviceName == deviceName && 
					   auto.Trigger.Property == property && auto.Trigger.Condition == "double_pressed" {
						fmt.Printf("[BUTTON] Executing double press automation: %s\n", auto.Name)
						go s.ExecuteAutomationAction(auto)
					}
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
					s.ExecuteAutomationAction(automation)
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

// RunAutomation executes an automation by ID
func (s *AutomationService) RunAutomation(id string) error {
	automations, err := s.GetAllAutomations()
	if err != nil {
		return fmt.Errorf("failed to load automations: %v", err)
	}
	
	for _, automation := range automations {
		if automation.ID == id {
			s.ExecuteAutomationAction(automation)
			return nil
		}
	}
	
	return fmt.Errorf("automation with ID %s not found", id)
}

// ExecuteAutomationAction executes the action of an automation (public method)
func (s *AutomationService) ExecuteAutomationAction(automation types.Automation) {
	action := automation.Action
	
	// Check if this is a scene-based action
	if action.SceneZone != "" && action.SceneName != "" {
		s.ExecuteSceneBasedAction(action)
		return
	}
	
	// Check if this is a zone-based action
	if action.Zone != "" {
		s.ExecuteZoneBasedAction(action)
		return
	}
	
	// Individual device action
	s.ExecuteAutomationActionWithValue(automation, automation.Action.Value)
}

// ExecuteAutomationActionWithValue executes the action of an automation with a specific value
func (s *AutomationService) ExecuteAutomationActionWithValue(automation types.Automation, value interface{}) {
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
	s.SendDeviceCommand(action.DeviceName, string(commandJSON))
}

// ExecuteSceneBasedAction executes a lighting scene in a specific zone
func (s *AutomationService) ExecuteSceneBasedAction(action types.AutomationAction) {
	if action.SceneZone == "" || action.SceneName == "" {
		fmt.Printf("Error: Scene-based action missing zone or scene name\n")
		return
	}
	
	fmt.Printf("Executing scene automation: applying scene '%s' to zone '%s'\n", action.SceneName, action.SceneZone)
	
	// Use the scene service to apply the scene
	scenes, err := s.sceneService.GetAllScenes()
	if err != nil {
		fmt.Printf("Failed to get scenes for automation: %v\n", err)
		return
	}
	
	for _, scene := range scenes {
		if scene.Name == action.SceneName {
			fmt.Printf("Executing scene '%s' in zone '%s'\n", action.SceneName, action.SceneZone)
			err := s.sceneService.ApplySceneInZone(scene.ID, action.SceneZone)
			if err != nil {
				fmt.Printf("Failed to apply scene '%s' in zone '%s': %v\n", action.SceneName, action.SceneZone, err)
			} else {
				fmt.Printf("Successfully applied scene '%s' to zone '%s'\n", action.SceneName, action.SceneZone)
			}
			break
		}
	}
}

// ExecuteZoneBasedAction executes an action on all devices in a zone/category combination
func (s *AutomationService) ExecuteZoneBasedAction(action types.AutomationAction) {
	if action.Zone == "" {
		fmt.Printf("Error: Zone-based action missing zone\n")
		return
	}
	
	// Get devices in zone/category
	var targetDevices []string
	if action.Category == "" {
		targetDevices = storage.GetDevicesByZone(action.Zone)
	} else {
		targetDevices = s.GetDevicesByZoneAndCategory(action.Zone, action.Category)
	}
	
	fmt.Printf("Executing zone-based action on %d devices in zone '%s'", len(targetDevices), action.Zone)
	if action.Category != "" {
		fmt.Printf(" with category '%s'", action.Category)
	}
	fmt.Printf(": %s = %v\n", action.Property, action.Value)
	
	// Execute action on each matching device
	for _, deviceName := range targetDevices {
		// Create individual device action
		deviceAction := types.AutomationAction{
			DeviceName: deviceName,
			Property:   action.Property,
			Value:      action.Value,
		}
		
		// Create a temporary automation for the device action execution
		tempAutomation := types.Automation{
			Name:   fmt.Sprintf("Zone action: %s", action.Zone),
			Action: deviceAction,
		}
		
		s.ExecuteAutomationAction(tempAutomation)
	}
}

// validateAutomation performs comprehensive validation of an automation
func (s *AutomationService) validateAutomation(automation types.Automation) error {
	var errors []string
	
	// Validate basic fields
	if strings.TrimSpace(automation.Name) == "" {
		errors = append(errors, "automation name is required")
	}
	
	if strings.TrimSpace(automation.Type) == "" {
		errors = append(errors, "automation type is required")
	}
	
	// Validate supported types
	validTypes := map[string]bool{
		"ifttt": true,
	}
	if !validTypes[automation.Type] {
		errors = append(errors, fmt.Sprintf("unsupported automation type: %s", automation.Type))
	}
	
	// Validate trigger
	if err := s.validateTrigger(automation.Trigger); err != nil {
		errors = append(errors, fmt.Sprintf("invalid trigger: %v", err))
	}
	
	// Validate action
	if err := s.validateAction(automation.Action); err != nil {
		errors = append(errors, fmt.Sprintf("invalid action: %v", err))
	}
	
	if len(errors) > 0 {
		return fmt.Errorf("validation errors: %s", strings.Join(errors, "; "))
	}
	
	return nil
}

// validateTrigger validates automation trigger
func (s *AutomationService) validateTrigger(trigger types.AutomationTrigger) error {
	if strings.TrimSpace(trigger.DeviceName) == "" {
		return fmt.Errorf("device name is required")
	}
	
	if strings.TrimSpace(trigger.Property) == "" {
		return fmt.Errorf("property is required")
	}
	
	if strings.TrimSpace(trigger.Condition) == "" {
		return fmt.Errorf("condition is required")
	}
	
	// Validate condition types
	validConditions := map[string]bool{
		"equals":         true,
		"greater_than":   true,
		"less_than":      true,
		"changed":        true,
		"pressed":        true,
		"double_pressed": true,
		"triple_pressed": true,
		"long_pressed":   true,
	}
	
	if !validConditions[trigger.Condition] {
		return fmt.Errorf("unsupported condition: %s", trigger.Condition)
	}
	
	// Validate that value is provided for conditions that need it
	needsValue := map[string]bool{
		"equals":       true,
		"greater_than": true,
		"less_than":    true,
	}
	
	if needsValue[trigger.Condition] && trigger.Value == nil {
		return fmt.Errorf("condition '%s' requires a value", trigger.Condition)
	}
	
	return nil
}

// validateAction validates automation action
func (s *AutomationService) validateAction(action types.AutomationAction) error {
	// Count how many action types are specified
	actionCount := 0
	
	if strings.TrimSpace(action.DeviceName) != "" {
		actionCount++
	}
	
	if strings.TrimSpace(action.Zone) != "" {
		actionCount++
	}
	
	if strings.TrimSpace(action.SceneName) != "" {
		actionCount++
	}
	
	if actionCount == 0 {
		return fmt.Errorf("action must specify either device_name, zone, or scene_name")
	}
	
	if actionCount > 1 {
		return fmt.Errorf("action can only specify one target: device_name, zone, or scene_name")
	}
	
	// Validate device action
	if strings.TrimSpace(action.DeviceName) != "" {
		if strings.TrimSpace(action.Property) == "" {
			return fmt.Errorf("device action requires property")
		}
		if action.Value == nil {
			return fmt.Errorf("device action requires value")
		}
	}
	
	// Validate zone action
	if strings.TrimSpace(action.Zone) != "" {
		if strings.TrimSpace(action.Category) == "" {
			return fmt.Errorf("zone action requires category")
		}
		if strings.TrimSpace(action.Property) == "" {
			return fmt.Errorf("zone action requires property")
		}
		if action.Value == nil {
			return fmt.Errorf("zone action requires value")
		}
	}
	
	// Validate scene action
	if strings.TrimSpace(action.SceneName) != "" {
		if strings.TrimSpace(action.SceneZone) == "" {
			return fmt.Errorf("scene action requires scene_zone")
		}
	}
	
	return nil
}

// compareValues compares two values based on the given condition
func (s *AutomationService) compareValues(a, b interface{}, condition string) bool {
	switch condition {
	case "equals":
		return a == b
		
	case "greater_than":
		aFloat, aOk := s.convertToFloat(a)
		bFloat, bOk := s.convertToFloat(b)
		if aOk && bOk {
			return aFloat > bFloat
		}
		return false
		
	case "less_than":
		aFloat, aOk := s.convertToFloat(a)
		bFloat, bOk := s.convertToFloat(b)
		if aOk && bOk {
			return aFloat < bFloat
		}
		return false
	}
	return false
}

// convertToFloat converts an interface{} to float64 if possible
func (s *AutomationService) convertToFloat(v interface{}) (float64, bool) {
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

// GetDevicesByZoneAndCategory returns all devices in a zone with a specific category
func (s *AutomationService) GetDevicesByZoneAndCategory(zone, category string) []string {
	var matchingDevices []string
	
	// Get all devices in the zone
	devicesInZone := storage.GetDevicesByZone(zone)
	
	// Filter by category  
	for _, deviceName := range devicesInZone {
		// Get device cache to check category
		deviceCache := s.findDeviceInCache(deviceName)
		if deviceCache != nil {
			effectiveCategory := s.GetDeviceCategory(deviceName, deviceCache)
			if effectiveCategory == category {
				matchingDevices = append(matchingDevices, deviceName)
			}
		}
	}
	
	return matchingDevices
}

// findDeviceInCache finds a device in the device cache
func (s *AutomationService) findDeviceInCache(deviceName string) map[string]interface{} {
	deviceCache := storage.GetDeviceCache()
	for _, cached := range deviceCache {
		if friendlyName, exists := cached["friendly_name"]; exists && friendlyName == deviceName {
			return cached
		}
	}
	return nil
}

// GetDeviceCategory determines device category
func (s *AutomationService) GetDeviceCategory(deviceName string, deviceCache map[string]interface{}) string {
	if metadata, ok := storage.GetDeviceMetadata(deviceName); ok {
		if category, ok := metadata["custom_category"]; ok && category != "" {
			return category
		}
	}
	// TODO: Implement GuessDeviceCategory logic or call zigbee2mqtt function
	return "unknown"
}

// SetSendDeviceCommandCallback sets the callback for sending commands to devices
func (s *AutomationService) SetSendDeviceCommandCallback(callback func(deviceName, command string)) {
	s.SendDeviceCommand = callback
}