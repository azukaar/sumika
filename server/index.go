package main

import (
	"fmt"
	"net/http"
	"os"
	"path/filepath"

	"github.com/gorilla/mux"

	"github.com/azukaar/sumika/server/MQTT"
	"github.com/azukaar/sumika/server/config"
	"github.com/azukaar/sumika/server/zigbee2mqtt"
	"github.com/azukaar/sumika/server/realtime"
	"github.com/azukaar/sumika/server/services"
	"github.com/azukaar/sumika/server/storage"
	httpHandlers "github.com/azukaar/sumika/server/http"
)

func main() {
	fmt.Println("Starting Sumika API Server...")
	
	// Load configuration from file and environment
	cfg, err := config.Load(config.GetConfigFilePath())
	if err != nil {
		fmt.Printf("Warning: Failed to load configuration: %v\n", err)
		fmt.Println("Using default configuration...")
		cfg = config.GetConfig()
	} else {
		fmt.Println("Configuration loaded successfully")
	}
	
	// Initialize storage system
	if err := storage.Initialize(); err != nil {
		fmt.Printf("Warning: Failed to initialize storage: %v\n", err)
		fmt.Println("Continuing with default values...")
	} else {
		fmt.Println("Storage initialized successfully")
	}
	
	// Initialize real-time WebSocket hub
	realtime.Initialize()
	fmt.Println("WebSocket hub initialized")
	
	// Initialize services
	sceneService := services.NewSceneService()
	automationService := services.NewAutomationService(sceneService)
	
	// Set up automation callbacks for device control
	zigbee2mqtt.SetAutomationCallback(func(deviceName string, oldState, newState map[string]interface{}) {
		automationService.CheckTriggers(deviceName, oldState, newState)
	})
	
	// Set up device command callback for automation service
	automationService.SetSendDeviceCommandCallback(func(deviceName, command string) {
		zigbee2mqtt.SetDeviceState(deviceName, command)
	})
	
	// Initialize voice service with device command callback
	voiceService := services.NewVoiceService(func(deviceName, command string) {
		zigbee2mqtt.SetDeviceState(deviceName, command)
	})
	
	// Initialize HTTP handlers with ALL services
	httpHandlers.InitServices(sceneService, automationService, voiceService)
	
	// Start voice service if enabled
	if voiceService.GetConfig().Enabled {
		if err := voiceService.Start(); err != nil {
			fmt.Printf("Warning: Failed to start voice service: %v\n", err)
		}
	}

	go (func() {
		r := mux.NewRouter()
		
		r.HandleFunc("/api/zigbee2mqtt/allow_join", zigbee2mqtt.API_AllowJoin)
		r.HandleFunc("/api/zigbee2mqtt/list_devices", zigbee2mqtt.API_ListDevices)
		r.HandleFunc("/api/zigbee2mqtt/set/{device}", zigbee2mqtt.API_SetDeviceState)
		r.HandleFunc("/api/zigbee2mqtt/get/{device}", zigbee2mqtt.API_ReloadDeviceState).Methods("POST")
		r.HandleFunc("/api/zigbee2mqtt/remove/{device}", zigbee2mqtt.API_RemoveDevice).Methods("DELETE")

		r.HandleFunc("/api/manage/get-by-zone/{zone}", httpHandlers.API_GetDeviceByZone)
		r.HandleFunc("/api/manage/set-zones/{device}", httpHandlers.API_SetDeviceZones).Methods("POST")
		r.HandleFunc("/api/manage/get-zones/{device}", httpHandlers.API_GetDeviceZones)
		r.HandleFunc("/api/manage/zones", httpHandlers.API_GetAllZones).Methods("GET")
		r.HandleFunc("/api/manage/zones/{zone}", httpHandlers.API_CreateZone).Methods("POST")  
		r.HandleFunc("/api/manage/zones/{zone}", httpHandlers.API_DeleteZone).Methods("DELETE")
		r.HandleFunc("/api/manage/zones/{zone}/rename", httpHandlers.API_RenameZone).Methods("PUT")
		r.HandleFunc("/api/manage/storage/info", httpHandlers.API_GetStorageInfo).Methods("GET")
		
		// Automation routes
		r.HandleFunc("/api/manage/automations", httpHandlers.API_GetAllAutomations).Methods("GET")
		r.HandleFunc("/api/manage/automations", httpHandlers.API_CreateAutomation).Methods("POST")
		r.HandleFunc("/api/manage/automations/{id}", httpHandlers.API_GetAutomationByID).Methods("GET")
		r.HandleFunc("/api/manage/automations/{id}", httpHandlers.API_UpdateAutomation).Methods("PUT")
		r.HandleFunc("/api/manage/automations/{id}", httpHandlers.API_DeleteAutomation).Methods("DELETE")
		r.HandleFunc("/api/manage/automations/{id}/run", httpHandlers.API_RunAutomation).Methods("POST")
		r.HandleFunc("/api/manage/automations/{id}/toggle", httpHandlers.API_ToggleAutomationEnabled).Methods("PUT")
		r.HandleFunc("/api/manage/automations/device/{device}", httpHandlers.API_GetAutomationsForDevice).Methods("GET")
		r.HandleFunc("/api/manage/device/{device}/properties", httpHandlers.API_GetDeviceProperties).Methods("GET")
		
		// Device metadata endpoints
		r.HandleFunc("/api/manage/device/{device}/metadata", httpHandlers.API_GetDeviceMetadata).Methods("GET")
		r.HandleFunc("/api/manage/device/{device}/custom_name", httpHandlers.API_SetDeviceCustomName).Methods("PUT")
		r.HandleFunc("/api/manage/device/{device}/custom_category", httpHandlers.API_SetDeviceCustomCategory).Methods("PUT")
		r.HandleFunc("/api/manage/device_categories", httpHandlers.API_GetAllDeviceCategories).Methods("GET")
		
		// Device specifications endpoints (from zigbee-herdsman-converters)
		specAPI := httpHandlers.NewDeviceMetadataAPI()
		r.HandleFunc("/api/manage/device-specs", specAPI.API_GetDeviceSpec).Methods("GET")
		r.HandleFunc("/api/manage/device-specs/model/{model}", specAPI.API_GetDeviceSpecByModel).Methods("GET")
		r.HandleFunc("/api/manage/device-specs/identify", specAPI.API_IdentifyDevice).Methods("POST")
		r.HandleFunc("/api/manage/device-specs/version", specAPI.API_GetSpecVersion).Methods("GET")
		r.HandleFunc("/api/manage/device-specs/cache/clear", specAPI.API_ClearSpecCache).Methods("POST")
		r.HandleFunc("/api/manage/devices", specAPI.API_GetAllDevicesWithSpecs).Methods("GET")
		
		// Zone-based automation endpoints
		r.HandleFunc("/api/manage/zones_categories", httpHandlers.API_GetZonesAndCategories).Methods("GET")
		r.HandleFunc("/api/manage/zone/{zone}/categories", httpHandlers.API_GetZoneCategories).Methods("GET")
		r.HandleFunc("/api/manage/zone/{zone}/devices", httpHandlers.API_GetDevicesByZoneAndCategory).Methods("GET")
		r.HandleFunc("/api/manage/zone/{zone}/category/{category}/properties", httpHandlers.API_GetZoneCategoryProperties).Methods("GET")
		
		// Scene management endpoints
		r.HandleFunc("/api/manage/scene-management", httpHandlers.API_GetAllScenesManagement).Methods("GET")
		r.HandleFunc("/api/manage/scene-management", httpHandlers.API_CreateScene).Methods("POST")
		r.HandleFunc("/api/manage/scene-management/reorder", httpHandlers.API_ReorderScenes).Methods("PUT")
		r.HandleFunc("/api/manage/scene-management/{id}", httpHandlers.API_GetSceneByID).Methods("GET")
		r.HandleFunc("/api/manage/scene-management/{id}", httpHandlers.API_UpdateScene).Methods("PUT")
		r.HandleFunc("/api/manage/scene-management/{id}", httpHandlers.API_DeleteScene).Methods("DELETE")
		r.HandleFunc("/api/manage/scene-management/{id}/duplicate", httpHandlers.API_DuplicateScene).Methods("POST")
		r.HandleFunc("/api/manage/scene-management/{id}/apply", httpHandlers.API_ApplySceneInZone).Methods("POST")
		r.HandleFunc("/api/manage/scene-management/test", httpHandlers.API_TestSceneDefinitionInZone).Methods("POST")
		
		// Voice recognition endpoints
		r.HandleFunc("/api/voice/config", httpHandlers.API_GetVoiceConfig).Methods("GET")
		r.HandleFunc("/api/voice/config", httpHandlers.API_UpdateVoiceConfig).Methods("POST")
		r.HandleFunc("/api/voice/devices", httpHandlers.API_GetVoiceDevices).Methods("GET")
		r.HandleFunc("/api/voice/history", httpHandlers.API_GetVoiceHistory).Methods("GET")
		r.HandleFunc("/api/voice/status", httpHandlers.API_GetVoiceStatus).Methods("GET")
		
		// WebSocket endpoint for real-time updates
		r.HandleFunc("/ws", realtime.HandleWebSocket)

		// Config management endpoints
		r.HandleFunc("/api/config", httpHandlers.API_GetConfig).Methods("GET")
		r.HandleFunc("/api/config", httpHandlers.API_UpdateConfig).Methods("PUT")
		r.HandleFunc("/api/restart", httpHandlers.API_RestartServer).Methods("POST")
		
		// Health check endpoint
		r.HandleFunc("/healthcheck", httpHandlers.API_HealthCheck).Methods("GET")

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
		
		address := fmt.Sprintf("%s:%d", cfg.Server.Host, cfg.Server.Port)
		fmt.Printf("Server starting on %s\n", address)
		
		server := &http.Server{
			Addr:           address,
			ReadTimeout:    cfg.Server.ReadTimeout,
			WriteTimeout:   cfg.Server.WriteTimeout,
			IdleTimeout:    cfg.Server.IdleTimeout,
			MaxHeaderBytes: cfg.Server.MaxHeaderBytes,
		}
		
		if err := server.ListenAndServe(); err != nil {
			fmt.Printf("Server failed to start: %v\n", err)
		}
	})();

	MQTT.Init(func() {
		zigbee2mqtt.Init();
	});
}
