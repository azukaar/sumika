package services

import (
	"fmt"
	"strings"

	"github.com/azukaar/sumika/server/manage"
	"github.com/azukaar/sumika/server/storage"
)

// AutomationService handles business logic for automation operations
type AutomationService struct {
	automationRepo storage.AutomationRepository
}

// NewAutomationService creates a new automation service
func NewAutomationService(automationRepo storage.AutomationRepository) *AutomationService {
	return &AutomationService{
		automationRepo: automationRepo,
	}
}

// GetAllAutomations returns all automations
func (s *AutomationService) GetAllAutomations() ([]manage.Automation, error) {
	return s.automationRepo.GetAllAutomations()
}

// GetAutomationByID returns an automation by ID
func (s *AutomationService) GetAutomationByID(id string) (*manage.Automation, error) {
	if strings.TrimSpace(id) == "" {
		return nil, fmt.Errorf("automation ID cannot be empty")
	}
	
	return s.automationRepo.GetAutomationByID(id)
}

// CreateAutomation creates a new automation with validation
func (s *AutomationService) CreateAutomation(automation manage.Automation) (string, error) {
	// Validate automation
	if err := s.validateAutomation(automation); err != nil {
		return "", fmt.Errorf("automation validation failed: %w", err)
	}
	
	return s.automationRepo.CreateAutomation(automation)
}

// UpdateAutomation updates an entire automation
func (s *AutomationService) UpdateAutomation(id string, automation manage.Automation) error {
	if strings.TrimSpace(id) == "" {
		return fmt.Errorf("automation ID cannot be empty")
	}
	
	// Validate automation
	if err := s.validateAutomation(automation); err != nil {
		return fmt.Errorf("automation validation failed: %w", err)
	}
	
	return s.automationRepo.UpdateAutomation(id, automation)
}

// UpdatePartialAutomation updates specific fields of an automation
func (s *AutomationService) UpdatePartialAutomation(id string, updates map[string]interface{}) error {
	if strings.TrimSpace(id) == "" {
		return fmt.Errorf("automation ID cannot be empty")
	}
	
	// Validate partial updates
	if err := s.validatePartialUpdates(updates); err != nil {
		return fmt.Errorf("partial update validation failed: %w", err)
	}
	
	return s.automationRepo.UpdatePartialAutomation(id, updates)
}

// DeleteAutomation removes an automation
func (s *AutomationService) DeleteAutomation(id string) error {
	if strings.TrimSpace(id) == "" {
		return fmt.Errorf("automation ID cannot be empty")
	}
	
	return s.automationRepo.DeleteAutomation(id)
}

// GetAutomationsForDevice returns automations for a device
func (s *AutomationService) GetAutomationsForDevice(deviceName string) ([]manage.Automation, error) {
	if strings.TrimSpace(deviceName) == "" {
		return nil, fmt.Errorf("device name cannot be empty")
	}
	
	return s.automationRepo.GetAutomationsForDevice(deviceName)
}

// validateAutomation performs comprehensive validation of an automation
func (s *AutomationService) validateAutomation(automation manage.Automation) error {
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
		// Add other supported types here
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
func (s *AutomationService) validateTrigger(trigger manage.AutomationTrigger) error {
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
func (s *AutomationService) validateAction(action manage.AutomationAction) error {
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

// validatePartialUpdates validates partial update data
func (s *AutomationService) validatePartialUpdates(updates map[string]interface{}) error {
	// Basic validation for partial updates
	if name, ok := updates["name"].(string); ok && strings.TrimSpace(name) == "" {
		return fmt.Errorf("name cannot be empty")
	}
	
	if automationType, ok := updates["type"].(string); ok {
		validTypes := map[string]bool{
			"ifttt": true,
		}
		if !validTypes[automationType] {
			return fmt.Errorf("unsupported automation type: %s", automationType)
		}
	}
	
	// TODO: Add more specific validation for trigger and action updates
	
	return nil
}