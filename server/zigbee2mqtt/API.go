package zigbee2mqtt

import (
	"net/http"
	"encoding/json"
	"github.com/gorilla/mux"
)

// HTTP utility functions to avoid import cycle
func writeSuccess(w http.ResponseWriter, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"message": message})
}

func writeJSON(w http.ResponseWriter, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(data)
}

func getRequiredPathParam(r *http.Request, w http.ResponseWriter, param string) (string, bool) {
	vars := mux.Vars(r)
	value, exists := vars[param]
	if !exists {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "Missing required parameter: " + param})
		return "", false
	}
	return value, true
}

func getQueryParam(r *http.Request, param string) string {
	return r.URL.Query().Get(param)
}

func API_AllowJoin(w http.ResponseWriter, r *http.Request) {
	AllowJoin()
	writeSuccess(w, "Join mode enabled")
}

func API_ListDevices(w http.ResponseWriter, r *http.Request) {
	devices := ListDevices()
	writeJSON(w, devices)
}

func API_SetDeviceState(w http.ResponseWriter, r *http.Request) {
	name, ok := getRequiredPathParam(r, w, "device")
	if !ok {
		return
	}
	state := getQueryParam(r, "state")

	SetDeviceState(name, state)
	writeSuccess(w, "Device state updated")
}

func API_RemoveDevice(w http.ResponseWriter, r *http.Request) {
	deviceName, ok := getRequiredPathParam(r, w, "device")
	if !ok {
		return
	}

	// Remove from server's device cache and associated data
	// TODO: This should be handled by a device service
	deviceRemoved := true
	
	// Remove from Zigbee2MQTT
	RemoveDevice(deviceName)
	
	if deviceRemoved {
		writeSuccess(w, "Device removed successfully")
	} else {
		writeSuccess(w, "Device not found in server cache, but removal requested from Zigbee2MQTT")
	}
}

func API_ReloadDeviceState(w http.ResponseWriter, r *http.Request) {
	deviceName, ok := getRequiredPathParam(r, w, "device")
	if !ok {
		return
	}

	// Send get command to Zigbee2MQTT to refresh device state
	ReloadDeviceState(deviceName)
	writeSuccess(w, "Device state refresh requested")
}