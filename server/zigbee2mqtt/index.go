package zigbee2mqtt

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"time"

	"github.com/azukaar/sumika/server/MQTT"
	"github.com/azukaar/sumika/server/realtime"
	"github.com/azukaar/sumika/server/storage"
	"github.com/azukaar/sumika/server/utils"
)

// Callback functions for device management
var automationCallback func(deviceName string, oldState, newState map[string]interface{})

// SetAutomationCallback sets the callback for automation triggers
func SetAutomationCallback(callback func(deviceName string, oldState, newState map[string]interface{})) {
	automationCallback = callback
}

// Device management functions using unified storage
func GetDeviceCache() []map[string]interface{} {
	return storage.GetDeviceCache()
}

func SetDeviceCache(cache []map[string]interface{}) {
	storage.SetDeviceCache(cache)
}

func GetZonesOfDevice(deviceName string) []string {
	return storage.GetDeviceZones(deviceName)
}

func GetDeviceMetadata(deviceName string) (map[string]string, bool) {
	return storage.GetDeviceMetadata(deviceName)
}

func SetDeviceCustomCategory(deviceName, category string) {
	storage.SetDeviceCustomCategory(deviceName, category)
}

// GetDeviceProperties extracts controllable properties from device definition exposes
func GetDeviceProperties(deviceName string) []string {
	return storage.GetDeviceProperties(deviceName)
}


func GuessDeviceCategory(device map[string]interface{}) string {
	// Check definition for device type hints
	if definition, ok := device["definition"].(map[string]interface{}); ok {
		if description, hasDesc := definition["description"].(string); hasDesc {
			descLower := strings.ToLower(description)
			
			// Look for keywords in description
			if strings.Contains(descLower, "light") || strings.Contains(descLower, "bulb") || strings.Contains(descLower, "lamp") {
				return "light"
			}
			if strings.Contains(descLower, "switch") || strings.Contains(descLower, "plug") {
				return "switch"
			}
			if strings.Contains(descLower, "sensor") {
				return "sensor"
			}
			if strings.Contains(descLower, "button") || strings.Contains(descLower, "remote") {
				return "button"
			}
			if strings.Contains(descLower, "door") || strings.Contains(descLower, "window") || strings.Contains(descLower, "contact") {
				return "door_window"
			}
			if strings.Contains(descLower, "motion") || strings.Contains(descLower, "occupancy") {
				return "motion"
			}
			if strings.Contains(descLower, "thermostat") || strings.Contains(descLower, "temperature control") {
				return "thermostat"
			}
		}
		
		// Check exposes array for feature types
		if exposes, hasExposes := definition["exposes"].([]interface{}); hasExposes {
			for _, expose := range exposes {
				if exposeMap, ok := expose.(map[string]interface{}); ok {
					if exposeType, hasType := exposeMap["type"].(string); hasType {
						switch exposeType {
						case "light":
							return "light"
						case "switch":
							return "switch"
						case "binary":
							// Check the property name to determine type
							if property, hasProp := exposeMap["property"].(string); hasProp {
								propLower := strings.ToLower(property)
								if propLower == "contact" {
									return "door_window"
								}
								if propLower == "occupancy" || propLower == "motion" {
									return "motion"
								}
								if strings.Contains(propLower, "state") {
									return "switch"
								}
							}
						}
					}
					
					// Check for action property (buttons)
					if features, hasFeatures := exposeMap["features"].([]interface{}); hasFeatures {
						for _, feature := range features {
							if featureMap, ok := feature.(map[string]interface{}); ok {
								if property, hasProp := featureMap["property"].(string); hasProp && property == "action" {
									return "button"
								}
							}
						}
					}
				}
			}
		}
	}
	
	// Check device state for clues
	if state, hasState := device["state"].(map[string]interface{}); hasState {
		// Check for common light properties
		if _, hasState := state["state"]; hasState {
			if _, hasBrightness := state["brightness"]; hasBrightness {
				return "light"
			}
			if _, hasColor := state["color"]; hasColor {
				return "light"
			}
		}
		
		// Check for sensor properties
		if _, hasTemp := state["temperature"]; hasTemp {
			return "sensor"
		}
		if _, hasHumidity := state["humidity"]; hasHumidity {
			return "sensor"
		}
		if _, hasContact := state["contact"]; hasContact {
			return "door_window"
		}
		if _, hasMotion := state["motion"]; hasMotion {
			return "motion"
		}
		if _, hasOccupancy := state["occupancy"]; hasOccupancy {
			return "motion"
		}
		if _, hasAction := state["action"]; hasAction {
			return "button"
		}
		
		// Check for power measurement (smart plugs)
		if _, hasPower := state["power"]; hasPower {
			return "switch"
		}
	}
	
	// Check device type from zigbee2mqtt
	if deviceType, hasType := device["type"].(string); hasType {
		switch strings.ToLower(deviceType) {
		case "enddevice":
			// EndDevices are usually sensors or buttons
			return "sensor"
		case "router":
			// Routers are usually lights or switches
			return "light"
		}
	}
	
	return "unknown"
}

func SetDeviceCustomName(deviceName, customName string) {
	storage.SetDeviceCustomName(deviceName, customName)
}

func GetDeviceCustomName(deviceName string) string {
	if metadata, ok := storage.GetDeviceMetadata(deviceName); ok {
		if customName, ok := metadata["custom_name"]; ok {
			return customName
		}
	}
	return ""
}

func GetDeviceCustomCategory(deviceName string) string {
	if metadata, ok := storage.GetDeviceMetadata(deviceName); ok {
		if category, ok := metadata["custom_category"]; ok {
			return category
		}
	}
	return ""
}

func GetDeviceDisplayName(deviceName string) string {
	if customName := GetDeviceCustomName(deviceName); customName != "" {
		return customName
	}
	return deviceName
}

func GetDeviceCategory(deviceName string, deviceCache map[string]interface{}) string {
	if category := GetDeviceCustomCategory(deviceName); category != "" {
		return category
	}
	return GuessDeviceCategory(deviceCache)
}

func GetAllDeviceCategories() []string {
	categories := make(map[string]bool)
	
	// Add standard categories that should always be available
	standardCategories := []string{"light", "switch", "sensor", "button", "door_window", "motion", "thermostat", "unknown"}
	for _, category := range standardCategories {
		categories[category] = true
	}
	
	// Get all device cache to extract additional categories
	deviceCache := storage.GetDeviceCache()
	
	for _, device := range deviceCache {
		if friendlyName, ok := device["friendly_name"].(string); ok {
			// Check for custom category
			if metadata, exists := storage.GetDeviceMetadata(friendlyName); exists {
				if category, ok := metadata["custom_category"]; ok && category != "" {
					categories[category] = true
				}
			}
			
			// Also add guessed category
			category := GuessDeviceCategory(device)
			if category != "unknown" {
				categories[category] = true
			}
		}
	}
	
	result := make([]string, 0, len(categories))
	for category := range categories {
		result = append(result, category)
	}
	return result
}

func getDeviceByName(name string) int {
	for key, device := range DeviceList {
		if device.FriendlyName == name {
			return key
		}
	}
	return -1
}

func toJSON(data interface{}) []byte {
	jsonData, _ := json.Marshal(data)
	return jsonData
}

// Debug helper to save MQTT messages when DEBUG_MQTT env var is set
func debugSaveMQTTMessage(messageType, topic string, payload []byte) {
	if os.Getenv("DEBUG_MQTT") == "" || os.Getenv("DEBUG_MQTT") == "false" || os.Getenv("DEBUG_MQTT") == "0" {
		return
	}
	
	// Create debug directory
	debugDir := "_DEBUG"
	if err := os.MkdirAll(debugDir, 0755); err != nil {
		utils.Debug(fmt.Sprintf("Failed to create debug directory: %v", err))
		return
	}
	
	// Generate filename with timestamp and message type
	timestamp := time.Now().Format("2006-01-02_15-04-05")
	// Clean topic name for filename (replace / with -)
	cleanTopic := strings.ReplaceAll(topic, "/", "-")
	filename := fmt.Sprintf("%s_mqtt_%s_%s.json", timestamp, messageType, cleanTopic)
	filepath := filepath.Join(debugDir, filename)
	
	// Create debug data structure
	debugData := map[string]interface{}{
		"timestamp": time.Now().Format("2006-01-02T15:04:05Z07:00"),
		"message_type": messageType,
		"topic": topic,
		"payload_raw": string(payload),
	}
	
	// Try to parse payload as JSON for pretty formatting
	var jsonPayload interface{}
	if err := json.Unmarshal(payload, &jsonPayload); err == nil {
		debugData["payload_parsed"] = jsonPayload
	}
	
	// Write to debug file
	debugJson, _ := json.MarshalIndent(debugData, "", "  ")
	if err := ioutil.WriteFile(filepath, debugJson, 0644); err != nil {
		utils.Debug(fmt.Sprintf("Failed to write debug file: %v", err))
	} else {
		utils.Debug(fmt.Sprintf("Saved MQTT message to: %s", filepath))
	}
}

func AllowJoin() {
	payload := map[string]interface{}{
			"value": true,
			"time": 250,
	}
	MQTT.Publish("zb2m-sumika/bridge/request/permit_join", toJSON(payload))
}

func RemoveDevice(deviceName string) {
	// First remove from Zigbee2MQTT via MQTT bridge command
	payload := map[string]interface{}{
		"id": deviceName,
	}
	MQTT.Publish("zb2m-sumika/bridge/request/device/remove", toJSON(payload))
	utils.Log(fmt.Sprintf("Requested removal of device: %s from Zigbee2MQTT", deviceName))
}

func RestartZigbee2MQTT() {
	// Send restart command to Zigbee2MQTT
	MQTT.Publish("zb2m-sumika/bridge/request/restart", []byte("{}"))
	utils.Log("Requested Zigbee2MQTT restart")
}

func ReloadDeviceState(deviceName string) {
	// Send get command to request fresh device state from Zigbee2MQTT
	topic := fmt.Sprintf("zb2m-sumika/%s/get", deviceName)
	MQTT.Publish(topic, []byte("{}"))
	utils.Debug(fmt.Sprintf("Requested device state refresh for: %s", deviceName))
}

var DeviceList []Device

func Init() {
	MQTT.Subscribe("zb2m-sumika/bridge/devices", func(topic string, payload []byte) {
		// Debug: Save broadcast message
		debugSaveMQTTMessage("broadcast", topic, payload)
		
		var allDevices []Device
		json.Unmarshal([]byte(payload), &allDevices)
		
		// Filter out coordinator devices (devices without a model AND typically named "Coordinator")
		DeviceList = []Device{}
		for _, device := range allDevices {
			// More specific coordinator detection
			isCoordinator := (device.Definition.Model == "" && 
							 (device.FriendlyName == "Coordinator" || 
							  device.FriendlyName == "Bridge" ||
							  strings.Contains(strings.ToLower(device.FriendlyName), "coordinator")))
			
			if !isCoordinator {
				DeviceList = append(DeviceList, device)
				utils.Debug(fmt.Sprintf("Including device: %s (model: %s)", device.FriendlyName, device.Definition.Model))
			} else {
				utils.Debug(fmt.Sprintf("Excluding coordinator/bridge device: %s", device.FriendlyName))
			}
		}
		
		// Update device cache
		updateDeviceCache()
		
		utils.Debug(fmt.Sprintf("Saved %d devices to cache (filtered from %d total)", len(DeviceList), len(allDevices)))
	})
	SaveUpdates()
}

func SetDeviceState(name string, state string) {
	MQTT.Publish("zb2m-sumika/" + name + "/set", []byte(state))
}

func ListDevices() []Device {
	// Try to use cached devices first
	cachedDevices := GetDeviceCache()
	if len(cachedDevices) > 0 {
		utils.Debug(fmt.Sprintf("Using cached device list with %d devices", len(cachedDevices)))
		// Convert cached devices back to Device structs
		var devices []Device
		for _, cachedDevice := range cachedDevices {
			deviceData, _ := json.Marshal(cachedDevice)
			var device Device
			json.Unmarshal(deviceData, &device)
			// populate zones for each device
			device.Zones = GetZonesOfDevice(device.FriendlyName)
			
			// populate custom metadata for each device
			if metadata, exists := GetDeviceMetadata(device.FriendlyName); exists {
				device.CustomName = metadata["custom_name"]
				device.CustomCategory = metadata["custom_category"]
			}
			
			// If no custom category is set, auto-detect and save it
			if device.CustomCategory == "" {
				guessedCategory := GuessDeviceCategory(cachedDevice)
				if guessedCategory != "unknown" {
					utils.Debug(fmt.Sprintf("Auto-categorizing device '%s' as '%s'", device.FriendlyName, guessedCategory))
					SetDeviceCustomCategory(device.FriendlyName, guessedCategory)
					device.CustomCategory = guessedCategory
				}
			}
			
			devices = append(devices, device)
		}
		return devices
	}
	
	// Fallback to live DeviceList
	utils.Debug(fmt.Sprintf("Cache empty, using live device list with %d devices", len(DeviceList)))
	// populate zones and custom metadata for each device
	for key, device := range DeviceList {
		DeviceList[key].Zones = GetZonesOfDevice(device.FriendlyName)
		
		// populate custom metadata for each device
		if metadata, exists := GetDeviceMetadata(device.FriendlyName); exists {
			DeviceList[key].CustomName = metadata["custom_name"]
			DeviceList[key].CustomCategory = metadata["custom_category"]
		}
		
		// If no custom category is set, auto-detect and save it
		if DeviceList[key].CustomCategory == "" {
			// Convert device to cache format for GuessDeviceCategory
			deviceData, _ := json.Marshal(DeviceList[key])
			var deviceCache map[string]interface{}
			json.Unmarshal(deviceData, &deviceCache)
			
			guessedCategory := GuessDeviceCategory(deviceCache)
			if guessedCategory != "unknown" {
				utils.Debug(fmt.Sprintf("Auto-categorizing device '%s' as '%s'", device.FriendlyName, guessedCategory))
				SetDeviceCustomCategory(device.FriendlyName, guessedCategory)
				DeviceList[key].CustomCategory = guessedCategory
			}
		}
	}
	return DeviceList
}

// GetDeviceState returns the current state of a device by name
func GetDeviceState(deviceName string) map[string]interface{} {
	utils.Debug(fmt.Sprintf("Looking for device state: %s", deviceName))

	utils.Debug(fmt.Sprintf("DeviceList contains %d devices:", len(DeviceList)))
	for i, device := range DeviceList {
		utils.Debug(fmt.Sprintf("  [%d] FriendlyName: '%s'", i, device.FriendlyName))
	}
	
	// First try to find in live DeviceList
	deviceIndex := getDeviceByName(deviceName)
	if deviceIndex != -1 {
		if DeviceList[deviceIndex].State != nil {
			utils.Debug(fmt.Sprintf("Device %s found in live list with state: %+v", deviceName, DeviceList[deviceIndex].State))
			return DeviceList[deviceIndex].State
		} else {
			utils.Debug(fmt.Sprintf("Device %s found in live list but has no state", deviceName))
		}
	} else {
		utils.Debug(fmt.Sprintf("Device %s not found in live DeviceList", deviceName))
	}
	
	// If not found in live list, try cached devices
	cachedDevices := GetDeviceCache()
	utils.Debug(fmt.Sprintf("Cache contains %d devices:", len(cachedDevices)))
	for i, cachedDevice := range cachedDevices {
		if friendlyName, exists := cachedDevice["friendly_name"]; exists {
			utils.Debug(fmt.Sprintf("  [%d] friendly_name: '%s'", i, friendlyName))
		}
		if friendlyName, exists := cachedDevice["friendly_name"]; exists && friendlyName == deviceName {
			if state, hasState := cachedDevice["state"]; hasState {
				utils.Debug(fmt.Sprintf("Device %s state type: %T, value: %+v", deviceName, state, state))
				if stateMap, ok := state.(map[string]interface{}); ok {
					utils.Debug(fmt.Sprintf("Device %s found in cache with state: %+v", deviceName, stateMap))
					return stateMap
				} else {
					utils.Debug(fmt.Sprintf("Device %s found in cache but state is not a map (type: %T)", deviceName, state))
				}
			} else {
				utils.Debug(fmt.Sprintf("Device %s found in cache but has no state", deviceName))
			}
		}
	}
	
	utils.Debug(fmt.Sprintf("Device %s not found or has no state", deviceName))
	return map[string]interface{}{}
}

func updateDeviceCache() {
	// Get existing cache to merge with
	existingCache := GetDeviceCache()
	utils.Debug(fmt.Sprintf("Merging %d Zigbee2MQTT devices with %d existing cached devices", len(DeviceList), len(existingCache)))
	
	// Convert new DeviceList to map for easy lookup by friendly_name
	newDevicesMap := make(map[string]map[string]interface{})
	for _, device := range DeviceList {
		deviceData, _ := json.Marshal(device)
		var deviceMap map[string]interface{}
		json.Unmarshal(deviceData, &deviceMap)
		
		if friendlyName, exists := deviceMap["friendly_name"]; exists {
			if name, ok := friendlyName.(string); ok {
				newDevicesMap[name] = deviceMap
			}
		}
	}
	
	// Merge logic: preserve non-Zigbee devices, update Zigbee devices
	mergedCache := []map[string]interface{}{}
	
	// First, add all devices from existing cache
	for _, existingDevice := range existingCache {
		if friendlyName, exists := existingDevice["friendly_name"]; exists {
			if name, ok := friendlyName.(string); ok {
				if newDevice, inNewList := newDevicesMap[name]; inNewList {
					// Device exists in both - merge them
					mergedDevice := mergeDevice(existingDevice, newDevice)
					mergedCache = append(mergedCache, mergedDevice)
					delete(newDevicesMap, name) // Mark as processed
					utils.Debug(fmt.Sprintf("Updated existing device: %s", name))
				} else {
						mergedCache = append(mergedCache, existingDevice)
				}
			}
		}
	}
	
	// Add any new devices not in existing cache
	for name, newDevice := range newDevicesMap {
		utils.Log(fmt.Sprintf("New Zigbee device discovered: %s", name))
		mergedCache = append(mergedCache, newDevice)
	}
	
	utils.Debug(fmt.Sprintf("Final merged cache has %d devices", len(mergedCache)))
	SetDeviceCache(mergedCache)
}

// Helper function to merge existing device data with new Zigbee2MQTT data
func mergeDevice(existing, new map[string]interface{}) map[string]interface{} {
	// Start with new device data as base (has latest Zigbee2MQTT info)
	merged := make(map[string]interface{})
	for k, v := range new {
		merged[k] = v
	}
	
	// Preserve certain fields from existing device if they exist
	preserveFields := []string{
		"zones",           // Zone assignments
		"custom_name",     // Custom display name
		"custom_category", // Custom category
		"server_metadata", // Any server-specific metadata
		"state",           // Device state (CRITICAL - don't lose this!)
		"last_seen",       // Last seen timestamp
	}
	
	for _, field := range preserveFields {
		if existingValue, exists := existing[field]; exists {
			merged[field] = existingValue
		}
	}
	
	return merged
}

func SaveUpdates() {
	MQTT.Subscribe("zb2m-sumika/+", func(topic string, payload []byte) {
		// Debug: Save device state update message  
		debugSaveMQTTMessage("device_state", topic, payload)
		
		// get last part of topic
		parts := strings.Split(topic, "/")
		deviceName := parts[len(parts)-1]

		mapData := map[string]interface{}{}
		json.Unmarshal([]byte(payload), &mapData)

		// Get old state from cache for automation trigger checking
		oldState := make(map[string]interface{})
		cachedDevices := GetDeviceCache()
		
		// Find device in cache to get old state
		var deviceFound bool
		var newDeviceCache map[string]interface{}
		
		for i, cachedDevice := range cachedDevices {
			if friendlyName, exists := cachedDevice["friendly_name"]; exists && friendlyName == deviceName {
				deviceFound = true
				// utils.Debug(fmt.Sprintf("Found device %s in cache", deviceName))
				
				// Get old state from cache
				if state, hasState := cachedDevice["state"]; hasState {
					if stateMap, ok := state.(map[string]interface{}); ok {
						// Deep copy the old state
						oldStateBytes, _ := json.Marshal(stateMap)
						json.Unmarshal(oldStateBytes, &oldState)
					}
				}
				
				// Update state in cache
				cachedDevices[i]["state"] = mapData
				cachedDevices[i]["last_seen"] = time.Now().Format("2006-01-02T15:04:05Z07:00")
				break
			}
		}

		// Short-circuit: if state hasn't changed (ignoring noisy metadata), skip all processing
		if deviceFound {
			oldFiltered := make(map[string]interface{})
			newFiltered := make(map[string]interface{})
			for k, v := range oldState {
				if k != "linkquality" {
					oldFiltered[k] = v
				}
			}
			for k, v := range mapData {
				if k != "linkquality" {
					newFiltered[k] = v
				}
			}
			if reflect.DeepEqual(oldFiltered, newFiltered) {
				// utils.Debug(fmt.Sprintf("Device %s state unchanged, skipping update", deviceName))
				return
			}
		}

		if !deviceFound {
			utils.Log(fmt.Sprintf("New device %s detected, creating cache entry", deviceName))
			// Create new cache entry if device not found
			newDeviceCache = map[string]interface{}{
				"friendly_name": deviceName,
				// Note: We don't know the real IEEE address from state messages
				// This will be updated when the device appears in bridge/devices broadcast
				"ieee_address":  fmt.Sprintf("unknown_%s", deviceName),
				"state":         mapData,
				"last_seen":     time.Now().Format("2006-01-02T15:04:05Z07:00"),
				"source":        "state_message", // Mark source for debugging
			}
			cachedDevices = append(cachedDevices, newDeviceCache)
		}

		// Update cache
		utils.Debug(fmt.Sprintf("SaveUpdates: Saving device cache with %d devices", len(cachedDevices)))
		for i, device := range cachedDevices {
			if friendlyName, exists := device["friendly_name"]; exists {
				if state, hasState := device["state"]; hasState {
					utils.Debug(fmt.Sprintf("SaveUpdates: Device [%d] %s has state: %+v", i, friendlyName, state))
				} else {
					utils.Debug(fmt.Sprintf("SaveUpdates: Device [%d] %s has no state", i, friendlyName))
				}
			}
		}
		SetDeviceCache(cachedDevices)
		
		// For new devices (not found in cache), guess the device category
		if !deviceFound && newDeviceCache != nil {
			guessedCategory := GuessDeviceCategory(newDeviceCache)
			if guessedCategory != "unknown" {
				utils.Debug(fmt.Sprintf("Setting guessed category '%s' for new device: %s", guessedCategory, deviceName))
				SetDeviceCustomCategory(deviceName, guessedCategory)
			}
		}
		
		// Check automation triggers when device state changes
		utils.Debug(fmt.Sprintf("Checking automation triggers for device: %s", deviceName))
		if automationCallback != nil {
			automationCallback(deviceName, oldState, mapData)
		}
		
		// Broadcast real-time update to WebSocket clients
		if hub := realtime.GetHub(); hub != nil {
			hub.BroadcastDeviceUpdate(deviceName, mapData, oldState)
		}

		// Also try to find and update device in live DeviceList if it exists
		deviceIndex := getDeviceByName(deviceName)
		if deviceIndex != -1 {
			DeviceList[deviceIndex].State = mapData
			DeviceList[deviceIndex].LastSeen = time.Now().Format("2006-01-02T15:04:05Z07:00")
			utils.Debug(fmt.Sprintf("Device updated in live list: %s", deviceName))
		} else {
			utils.Debug(fmt.Sprintf("Device %s not in live DeviceList (bridge/devices not received yet)", deviceName))
		}
	})
}