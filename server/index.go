package main

import (
	"fmt"
	"net/http"
	"os"
	"path/filepath"

	"github.com/gorilla/mux"

	"github.com/azukaar/sumika/server/MQTT"
	"github.com/azukaar/sumika/server/zigbee2mqtt"
	"github.com/azukaar/sumika/server/manage"
	"github.com/azukaar/sumika/server/realtime"
)

func main() {
	fmt.Println("Starting Sumika API Server...")
	
	// Initialize storage system
	if err := manage.InitStorage(); err != nil {
		fmt.Printf("Warning: Failed to initialize storage: %v\n", err)
		fmt.Println("Continuing with default values...")
	} else {
		fmt.Printf("Storage initialized at: %s\n", manage.GetStorageFilePath())
	}
	
	// Initialize real-time WebSocket hub
	realtime.Initialize()
	fmt.Println("WebSocket hub initialized")
	
	// Initialize automation system with device command callback
	manage.SendDeviceCommand = func(deviceName, command string) {
		zigbee2mqtt.SetDeviceState(deviceName, command)
	}
	
	// Initialize automation system with device state callback
	manage.GetDeviceState = func(deviceName string) map[string]interface{} {
		return zigbee2mqtt.GetDeviceState(deviceName)
	}

	go (func() {
		r := mux.NewRouter()
		
		r.HandleFunc("/api/zigbee2mqtt/allow_join", zigbee2mqtt.API_AllowJoin)
		r.HandleFunc("/api/zigbee2mqtt/list_devices", zigbee2mqtt.API_ListDevices)
		r.HandleFunc("/api/zigbee2mqtt/set/{device}", zigbee2mqtt.API_SetDeviceState)
		r.HandleFunc("/api/zigbee2mqtt/get/{device}", zigbee2mqtt.API_ReloadDeviceState).Methods("POST")
		r.HandleFunc("/api/zigbee2mqtt/remove/{device}", zigbee2mqtt.API_RemoveDevice).Methods("DELETE")

		r.HandleFunc("/api/manage/get-by-zone/{zone}", manage.API_GetDeviceByZone)
		r.HandleFunc("/api/manage/set-zones/{device}", manage.API_SetDeviceZones).Methods("POST")
		r.HandleFunc("/api/manage/get-zones/{device}", manage.API_GetDeviceZones)
		r.HandleFunc("/api/manage/zones", manage.API_GetAllZones).Methods("GET")
		r.HandleFunc("/api/manage/zones/{zone}", manage.API_CreateZone).Methods("POST")
		r.HandleFunc("/api/manage/zones/{zone}", manage.API_DeleteZone).Methods("DELETE")
		r.HandleFunc("/api/manage/zones/{zone}/rename", manage.API_RenameZone).Methods("PUT")
		r.HandleFunc("/api/manage/storage/info", manage.API_GetStorageInfo).Methods("GET")
		
		// Automation routes
		r.HandleFunc("/api/manage/automations", manage.API_GetAllAutomations).Methods("GET")
		r.HandleFunc("/api/manage/automations", manage.API_CreateAutomation).Methods("POST")
		r.HandleFunc("/api/manage/automations/{id}", manage.API_GetAutomation).Methods("GET")
		r.HandleFunc("/api/manage/automations/{id}", manage.API_UpdateAutomation).Methods("PUT")
		r.HandleFunc("/api/manage/automations/{id}", manage.API_DeleteAutomation).Methods("DELETE")
		r.HandleFunc("/api/manage/automations/{id}/run", manage.API_RunAutomation).Methods("POST")
		r.HandleFunc("/api/manage/automations/device/{device}", manage.API_GetAutomationsForDevice).Methods("GET")
		r.HandleFunc("/api/manage/device/{device}/properties", manage.API_GetDeviceProperties).Methods("GET")
		
		// Device metadata endpoints
		r.HandleFunc("/api/manage/device/{device}/metadata", manage.API_GetDeviceMetadata).Methods("GET")
		r.HandleFunc("/api/manage/device/{device}/custom_name", manage.API_SetDeviceCustomName).Methods("PUT")
		r.HandleFunc("/api/manage/device/{device}/custom_category", manage.API_SetDeviceCustomCategory).Methods("PUT")
		r.HandleFunc("/api/manage/device_categories", manage.API_GetAllDeviceCategories).Methods("GET")
		
		// Device specifications endpoints (from zigbee-herdsman-converters)
		specAPI := manage.NewDeviceMetadataAPI()
		r.HandleFunc("/api/manage/device-specs", specAPI.API_GetDeviceSpec).Methods("GET")
		r.HandleFunc("/api/manage/device-specs/model/{model}", specAPI.API_GetDeviceSpecByModel).Methods("GET")
		r.HandleFunc("/api/manage/device-specs/identify", specAPI.API_IdentifyDevice).Methods("POST")
		r.HandleFunc("/api/manage/device-specs/version", specAPI.API_GetSpecVersion).Methods("GET")
		r.HandleFunc("/api/manage/device-specs/cache/clear", specAPI.API_ClearSpecCache).Methods("POST")
		r.HandleFunc("/api/manage/devices", specAPI.API_GetAllDevicesWithSpecs).Methods("GET")
		
		// Zone-based automation endpoints
		r.HandleFunc("/api/manage/zones_categories", manage.API_GetZonesAndCategories).Methods("GET")
		r.HandleFunc("/api/manage/zone/{zone}/categories", manage.API_GetZoneCategories).Methods("GET")
		r.HandleFunc("/api/manage/zone/{zone}/devices", manage.API_GetDevicesByZoneAndCategory).Methods("GET")
		r.HandleFunc("/api/manage/zone/{zone}/category/{category}/properties", manage.API_GetZoneCategoryProperties).Methods("GET")
		
		// Scene endpoints (legacy)
		r.HandleFunc("/api/manage/scenes", manage.API_GetAllScenes).Methods("GET")
		r.HandleFunc("/api/manage/scenes/featured", manage.API_GetFeaturedScenes).Methods("GET")
		r.HandleFunc("/api/manage/scenes/{name}", manage.API_GetSceneByName).Methods("GET")
		
		// Scene management endpoints
		r.HandleFunc("/api/manage/scene-management", manage.API_GetAllScenesManagement).Methods("GET")
		r.HandleFunc("/api/manage/scene-management", manage.API_CreateScene).Methods("POST")
		r.HandleFunc("/api/manage/scene-management/reorder", manage.API_ReorderScenes).Methods("PUT")
		r.HandleFunc("/api/manage/scene-management/{id}", manage.API_GetSceneByID).Methods("GET")
		r.HandleFunc("/api/manage/scene-management/{id}", manage.API_UpdateScene).Methods("PUT")
		r.HandleFunc("/api/manage/scene-management/{id}", manage.API_DeleteScene).Methods("DELETE")
		r.HandleFunc("/api/manage/scene-management/{id}/duplicate", manage.API_DuplicateScene).Methods("POST")
		r.HandleFunc("/api/manage/scene-management/{id}/test", manage.API_TestSceneInZone).Methods("POST")
		
		// WebSocket endpoint for real-time updates
		r.HandleFunc("/ws", realtime.HandleWebSocket)
		
		// Serve scene images
		var webDir string
		var assetsDir string

		exePath, err := os.Executable()
		if err != nil {
			fmt.Println("Warning: Could not determine executable path, using relative ./assets")
			assetsDir = "./assets"
			webDir = "./web"
		} else {
			assetsDir = fmt.Sprintf("%s/assets", filepath.Dir(exePath))
			webDir = fmt.Sprintf("%s/web", filepath.Dir(exePath))
		}

		if _, err := os.Stat(assetsDir); err == nil {
			fmt.Println("Serving server assets from", assetsDir)
			r.PathPrefix("/server-assets/").Handler(http.StripPrefix("/server-assets/", http.FileServer(http.Dir(assetsDir))))
		}
		if _, err := os.Stat(webDir); err == nil {
			fmt.Println("Serving Flutter web app from", webDir)
			r.PathPrefix("/").Handler(http.StripPrefix("/", http.FileServer(http.Dir(webDir))))
		} else {
			fmt.Println("Flutter web app not found at", webDir, "- serving API only")
			r.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusOK)
				w.Write([]byte(`{"status":"ok","message":"Sumika API Server","version":"1.0"}`))
			})
		}
    
		http.Handle("/", r)
		http.ListenAndServe(":8081", nil)
	})();

	MQTT.Init(func() {
		zigbee2mqtt.Init();
	});
}
