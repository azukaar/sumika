package zigbee2mqtt

import (
	"net/http"
	"encoding/json"
	"github.com/gorilla/mux"
)

func API_AllowJoin(w http.ResponseWriter, r *http.Request) {
	AllowJoin()
	w.Write([]byte("OK"))
}

func API_ListDevices(w http.ResponseWriter, r *http.Request) {
	// json send DeviceList
	DeviceListJSON, _ := json.Marshal(ListDevices())
	w.Header().Set("Content-Type", "application/json")
	w.Write(DeviceListJSON)
}

func API_SetDeviceState(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	name := vars["device"]
	state := r.URL.Query().Get("state")

	SetDeviceState(name, state)
	w.Write([]byte("OK"))
}