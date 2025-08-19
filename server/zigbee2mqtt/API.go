package zigbee2mqtt

import (
	"net/http"
	httputil "github.com/azukaar/sumika/server/http"
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