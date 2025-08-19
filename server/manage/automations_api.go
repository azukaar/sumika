package manage

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"

	httputil "github.com/azukaar/sumika/server/http"
)

// Automation API endpoints

func API_GetAllAutomations(w http.ResponseWriter, r *http.Request) {
	automations := GetAllAutomations()
	httputil.WriteJSON(w, automations)
}

func API_CreateAutomation(w http.ResponseWriter, r *http.Request) {
	var automation Automation
	if err := json.NewDecoder(r.Body).Decode(&automation); err != nil {
		httputil.WriteBadRequest(w, fmt.Sprintf("Invalid JSON: %v", err))
		return
	}

	// Validate the automation
	if errors := ValidateAutomation(automation); len(errors) > 0 {
		httputil.WriteValidationError(w, errors)
		return
	}

	// Create the automation
	id := CreateAutomation(automation)

	response := map[string]string{
		"message": "Automation created successfully",
		"id":      id,
	}
	httputil.WriteJSON(w, response)
}

func API_GetAutomation(w http.ResponseWriter, r *http.Request) {
	id, ok := httputil.GetRequiredPathParam(r, w, "id")
	if !ok {
		return
	}

	automation := GetAutomationByID(id)
	if automation == nil {
		httputil.WriteNotFound(w, "Automation")
		return
	}

	httputil.WriteJSON(w, automation)
}

func API_UpdateAutomation(w http.ResponseWriter, r *http.Request) {
	id, ok := httputil.GetRequiredPathParam(r, w, "id")
	if !ok {
		return
	}

	// Read the request body
	body, err := io.ReadAll(r.Body)
	if err != nil {
		httputil.WriteBadRequest(w, "Failed to read request body")
		return
	}
	defer r.Body.Close()

	// Parse and update the automation
	if err := updateAutomationFromBody(id, body, w); err != nil {
		// Error response already sent by helper function
		return
	}

	httputil.WriteSuccess(w, "Automation updated successfully")
}

// Helper function to handle the complex update logic
func updateAutomationFromBody(id string, body []byte, w http.ResponseWriter) error {
	// Try to decode as a full automation object first
	var fullAutomation Automation
	if err := json.Unmarshal(body, &fullAutomation); err == nil {
		// Check if this looks like a full automation (has required fields)
		if fullAutomation.Type != "" && fullAutomation.Trigger.DeviceName != "" {
			return handleFullAutomationUpdate(id, fullAutomation, w)
		}
	}

	// Fall back to partial update
	return handlePartialAutomationUpdate(id, body, w)
}

func handleFullAutomationUpdate(id string, automation Automation, w http.ResponseWriter) error {
	// Validate the automation
	if errors := ValidateAutomation(automation); len(errors) > 0 {
		httputil.WriteValidationError(w, errors)
		return fmt.Errorf("validation failed")
	}

	success := UpdateFullAutomation(id, automation)
	if !success {
		httputil.WriteNotFound(w, "Automation")
		return fmt.Errorf("automation not found")
	}

	return nil
}

func handlePartialAutomationUpdate(id string, body []byte, w http.ResponseWriter) error {
	var updates map[string]interface{}
	if err := json.Unmarshal(body, &updates); err != nil {
		httputil.WriteBadRequest(w, "Invalid JSON")
		return err
	}

	success := UpdateAutomation(id, updates)
	if !success {
		httputil.WriteNotFound(w, "Automation")
		return fmt.Errorf("automation not found")
	}

	return nil
}

func API_DeleteAutomation(w http.ResponseWriter, r *http.Request) {
	id, ok := httputil.GetRequiredPathParam(r, w, "id")
	if !ok {
		return
	}

	success := DeleteAutomation(id)
	if !success {
		httputil.WriteNotFound(w, "Automation")
		return
	}

	httputil.WriteSuccess(w, "Automation deleted successfully")
}

func API_GetAutomationsForDevice(w http.ResponseWriter, r *http.Request) {
	deviceName, ok := httputil.GetRequiredPathParam(r, w, "device")
	if !ok {
		return
	}

	automations := GetAutomationsForDevice(deviceName)
	httputil.WriteJSON(w, automations)
}

func API_GetDeviceProperties(w http.ResponseWriter, r *http.Request) {
	deviceName, ok := httputil.GetRequiredPathParam(r, w, "device")
	if !ok {
		return
	}

	properties := GetDeviceProperties(deviceName)

	// Ensure we never return nil, always return an empty array if no properties
	if properties == nil {
		properties = []string{}
	}

	httputil.WriteJSON(w, properties)
}

func API_RunAutomation(w http.ResponseWriter, r *http.Request) {
	id, ok := httputil.GetRequiredPathParam(r, w, "id")
	if !ok {
		return
	}

	automation := GetAutomationByID(id)
	if automation == nil {
		httputil.WriteNotFound(w, "Automation")
		return
	}

	// Execute the automation action
	ExecuteAutomationAction(*automation)

	httputil.WriteSuccess(w, fmt.Sprintf("Automation '%s' executed successfully", automation.Name))
}