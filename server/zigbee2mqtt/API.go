package zigbee2mqtt

import (
	"net/http"
	httputil "github.com/azukaar/sumika/server/http"
	"github.com/azukaar/sumika/server/manage"
)

func API_AllowJoin(w http.ResponseWriter, r *http.Request) {
	AllowJoin()
	httputil.WriteSuccess(w, "Join mode enabled")
}

func API_ListDevices(w http.ResponseWriter, r *http.Request) {
	devices := ListDevices()
	httputil.WriteJSON(w, devices)
}

func API_SetDeviceState(w http.ResponseWriter, r *http.Request) {
	name, ok := httputil.GetRequiredPathParam(r, w, "device")
	if !ok {
		return
	}
	state := httputil.GetQueryParam(r, "state")

	SetDeviceState(name, state)
	httputil.WriteSuccess(w, "Device state updated")
}

func API_RemoveDevice(w http.ResponseWriter, r *http.Request) {
	deviceName, ok := httputil.GetRequiredPathParam(r, w, "device")
	if !ok {
		return
	}

	// Remove from server's device cache and associated data
	deviceRemoved := manage.RemoveDevice(deviceName)
	
	// Remove from Zigbee2MQTT
	RemoveDevice(deviceName)
	
	if deviceRemoved {
		httputil.WriteSuccess(w, "Device removed successfully")
	} else {
		httputil.WriteSuccess(w, "Device not found in server cache, but removal requested from Zigbee2MQTT")
	}
}