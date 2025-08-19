package storage

import (
	"fmt"
	"slices"
	"time"

	"github.com/azukaar/sumika/server/manage"
)

// JSONAutomationRepository implements AutomationRepository using JSON file storage
type JSONAutomationRepository struct {
	dataStore DataStore
	data      *StorageData
}

// NewJSONAutomationRepository creates a new JSON-based automation repository
func NewJSONAutomationRepository(dataStore DataStore, data *StorageData) *JSONAutomationRepository {
	return &JSONAutomationRepository{
		dataStore: dataStore,
		data:      data,
	}
}

// GetAllAutomations returns all automations
func (r *JSONAutomationRepository) GetAllAutomations() ([]manage.Automation, error) {
	return slices.Clone(r.data.Automations), nil
}

// GetAutomationByID returns an automation by ID
func (r *JSONAutomationRepository) GetAutomationByID(id string) (*manage.Automation, error) {
	for i := range r.data.Automations {
		if r.data.Automations[i].ID == id {
			// Return a pointer to a copy to prevent external modification
			automation := r.data.Automations[i]
			return &automation, nil
		}
	}
	return nil, fmt.Errorf("automation with ID '%s' not found", id)
}

// CreateAutomation creates a new automation
func (r *JSONAutomationRepository) CreateAutomation(automation manage.Automation) (string, error) {
	// Validate automation has required fields
	if automation.Name == "" {
		return "", fmt.Errorf("automation name is required")
	}
	if automation.Type == "" {
		return "", fmt.Errorf("automation type is required")
	}
	
	// Generate ID if not provided
	if automation.ID == "" {
		automation.ID = fmt.Sprintf("auto_%d", time.Now().Unix())
	}
	
	// Check for duplicate IDs
	if _, err := r.GetAutomationByID(automation.ID); err == nil {
		return "", fmt.Errorf("automation with ID '%s' already exists", automation.ID)
	}
	
	// Set timestamps
	now := time.Now()
	automation.CreatedAt = now
	automation.UpdatedAt = now
	
	r.data.Automations = append(r.data.Automations, automation)
	
	if err := r.dataStore.Save(); err != nil {
		return "", fmt.Errorf("failed to save automation: %w", err)
	}
	
	return automation.ID, nil
}

// UpdateAutomation updates an entire automation
func (r *JSONAutomationRepository) UpdateAutomation(id string, automation manage.Automation) error {
	for i := range r.data.Automations {
		if r.data.Automations[i].ID == id {
			// Preserve original timestamps
			automation.ID = id
			automation.CreatedAt = r.data.Automations[i].CreatedAt
			automation.UpdatedAt = time.Now()
			
			r.data.Automations[i] = automation
			return r.dataStore.Save()
		}
	}
	return fmt.Errorf("automation with ID '%s' not found", id)
}

// UpdatePartialAutomation updates specific fields of an automation
func (r *JSONAutomationRepository) UpdatePartialAutomation(id string, updates map[string]interface{}) error {
	for i := range r.data.Automations {
		if r.data.Automations[i].ID == id {
			automation := &r.data.Automations[i]
			
			// Apply updates to specific fields
			if name, ok := updates["name"].(string); ok {
				automation.Name = name
			}
			if description, ok := updates["description"].(string); ok {
				automation.Description = description
			}
			if enabled, ok := updates["enabled"].(bool); ok {
				automation.Enabled = enabled
			}
			if automationType, ok := updates["type"].(string); ok {
				automation.Type = automationType
			}
			
			// Handle trigger updates
			if trigger, ok := updates["trigger"].(map[string]interface{}); ok {
				if deviceName, exists := trigger["device_name"].(string); exists {
					automation.Trigger.DeviceName = deviceName
				}
				if property, exists := trigger["property"].(string); exists {
					automation.Trigger.Property = property
				}
				if condition, exists := trigger["condition"].(string); exists {
					automation.Trigger.Condition = condition
				}
				if value, exists := trigger["value"]; exists {
					automation.Trigger.Value = value
				}
				if previousValue, exists := trigger["previous_value"]; exists {
					automation.Trigger.PreviousValue = previousValue
				}
			}
			
			// Handle action updates
			if action, ok := updates["action"].(map[string]interface{}); ok {
				if deviceName, exists := action["device_name"].(string); exists {
					automation.Action.DeviceName = deviceName
				}
				if zone, exists := action["zone"].(string); exists {
					automation.Action.Zone = zone
				}
				if category, exists := action["category"].(string); exists {
					automation.Action.Category = category
				}
				if sceneZone, exists := action["scene_zone"].(string); exists {
					automation.Action.SceneZone = sceneZone
				}
				if sceneName, exists := action["scene_name"].(string); exists {
					automation.Action.SceneName = sceneName
				}
				if property, exists := action["property"].(string); exists {
					automation.Action.Property = property
				}
				if value, exists := action["value"]; exists {
					automation.Action.Value = value
				}
			}
			
			automation.UpdatedAt = time.Now()
			return r.dataStore.Save()
		}
	}
	return fmt.Errorf("automation with ID '%s' not found", id)
}

// DeleteAutomation removes an automation
func (r *JSONAutomationRepository) DeleteAutomation(id string) error {
	for i := range r.data.Automations {
		if r.data.Automations[i].ID == id {
			// Remove automation from slice
			r.data.Automations = append(r.data.Automations[:i], r.data.Automations[i+1:]...)
			return r.dataStore.Save()
		}
	}
	return fmt.Errorf("automation with ID '%s' not found", id)
}

// GetAutomationsForDevice returns all automations that involve a specific device
func (r *JSONAutomationRepository) GetAutomationsForDevice(deviceName string) ([]manage.Automation, error) {
	var matchingAutomations []manage.Automation
	
	for _, automation := range r.data.Automations {
		// Check if device is mentioned in trigger or action
		if automation.Trigger.DeviceName == deviceName ||
			automation.Action.DeviceName == deviceName {
			matchingAutomations = append(matchingAutomations, automation)
		}
	}
	
	return matchingAutomations, nil
}