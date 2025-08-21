package http

import (
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/azukaar/sumika/server/types"
)

// Automation API endpoints

func API_GetAllAutomations(w http.ResponseWriter, r *http.Request) {
	automations, err := automationService.GetAllAutomations()
	if err != nil {
		WriteError(w, http.StatusInternalServerError, "Failed to load automations")
		return
	}
	WriteJSON(w, automations)
}

func API_CreateAutomation(w http.ResponseWriter, r *http.Request) {
	var automation types.Automation
	if err := json.NewDecoder(r.Body).Decode(&automation); err != nil {
		WriteError(w, http.StatusBadRequest, fmt.Sprintf("Invalid JSON: %v", err))
		return
	}

	// Validate the automation
	if err := validateAutomation(automation); err != nil {
		WriteError(w, http.StatusBadRequest, err.Error())
		return
	}

	id, err := automationService.CreateAutomation(automation)
	if err != nil {
		WriteError(w, http.StatusInternalServerError, fmt.Sprintf("Failed to create automation: %v", err))
		return
	}

	WriteJSON(w, map[string]string{"id": id})
}

func API_GetAutomationByID(w http.ResponseWriter, r *http.Request) {
	id, ok := GetRequiredPathParam(r, w, "id")
	if !ok {
		return
	}

	automation, err := automationService.GetAutomationByID(id)
	if err != nil {
		WriteError(w, http.StatusInternalServerError, "Failed to load automation")
		return
	}

	if automation == nil {
		WriteError(w, http.StatusNotFound, "Automation not found")
		return
	}

	WriteJSON(w, automation)
}

func API_UpdateAutomation(w http.ResponseWriter, r *http.Request) {
	id, ok := GetRequiredPathParam(r, w, "id")
	if !ok {
		return
	}

	var automation types.Automation
	if err := json.NewDecoder(r.Body).Decode(&automation); err != nil {
		WriteError(w, http.StatusBadRequest, fmt.Sprintf("Invalid JSON: %v", err))
		return
	}

	err := automationService.UpdateAutomation(id, automation)
	if err != nil {
		WriteError(w, http.StatusBadRequest, fmt.Sprintf("Failed to update automation: %v", err))
		return
	}

	WriteJSON(w, map[string]string{"message": "Automation updated successfully"})
}

func API_DeleteAutomation(w http.ResponseWriter, r *http.Request) {
	id, ok := GetRequiredPathParam(r, w, "id")
	if !ok {
		return
	}

	err := automationService.DeleteAutomation(id)
	if err != nil {
		WriteError(w, http.StatusBadRequest, fmt.Sprintf("Failed to delete automation: %v", err))
		return
	}

	WriteJSON(w, map[string]string{"message": "Automation deleted successfully"})
}

func API_RunAutomation(w http.ResponseWriter, r *http.Request) {
	id, ok := GetRequiredPathParam(r, w, "id")
	if !ok {
		return
	}

	// Execute the automation
	err := automationService.RunAutomation(id)
	if err != nil {
		WriteError(w, 404, fmt.Sprintf("Failed to run automation: %v", err))
		return
	}

	WriteJSON(w, map[string]string{"message": "Automation executed successfully"})
}

func API_ToggleAutomationEnabled(w http.ResponseWriter, r *http.Request) {
	id, ok := GetRequiredPathParam(r, w, "id")
	if !ok {
		return
	}

	var toggleRequest struct {
		Enabled bool `json:"enabled"`
	}
	if err := json.NewDecoder(r.Body).Decode(&toggleRequest); err != nil {
		WriteError(w, http.StatusBadRequest, fmt.Sprintf("Invalid JSON: %v", err))
		return
	}

	err := automationService.ToggleAutomationEnabled(id, toggleRequest.Enabled)
	if err != nil {
		WriteError(w, http.StatusBadRequest, fmt.Sprintf("Failed to toggle automation: %v", err))
		return
	}

	WriteJSON(w, map[string]string{"message": "Automation enabled state updated successfully"})
}

func API_GetAutomationsForDevice(w http.ResponseWriter, r *http.Request) {
	device, ok := GetRequiredPathParam(r, w, "device")
	if !ok {
		return
	}

	// Get all automations and filter by device
	allAutomations, err := automationService.GetAllAutomations()
	if err != nil {
		WriteError(w, 500, "Failed to load automations")
		return
	}
	
	var deviceAutomations []types.Automation
	for _, automation := range allAutomations {
		// Check if automation involves this device in trigger or action
		deviceInvolved := false
		
		// Check trigger
		if automation.Trigger.DeviceName == device {
			deviceInvolved = true
		}
		
		// Check action if not found in trigger
		if !deviceInvolved && automation.Action.DeviceName == device {
			deviceInvolved = true
		}
		
		if deviceInvolved {
			deviceAutomations = append(deviceAutomations, automation)
		}
	}

	WriteJSON(w, deviceAutomations)
}

// validateAutomation validates an automation structure
func validateAutomation(automation types.Automation) error {
	if automation.Name == "" {
		return fmt.Errorf("automation name is required")
	}

	if automation.Trigger.DeviceName == "" {
		return fmt.Errorf("trigger device name is required")
	}

	if automation.Trigger.Property == "" {
		return fmt.Errorf("trigger property is required")
	}

	if automation.Trigger.Condition == "" {
		return fmt.Errorf("trigger condition is required")
	}

	// Validate action
	hasAction := automation.Action.DeviceName != "" || 
		automation.Action.Zone != "" || 
		(automation.Action.SceneZone != "" && automation.Action.SceneName != "")

	if !hasAction {
		return fmt.Errorf("automation must have a valid action")
	}

	return nil
}