package zigbee2mqtt

import (
	"encoding/json"
	"fmt"
	"strings"
	"io/ioutil"
	"time"
	"os"
	"path/filepath"

	"github.com/azukaar/sumika/server/MQTT"
	"github.com/azukaar/sumika/server/manage"
	"github.com/azukaar/sumika/server/realtime"
)

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
		fmt.Printf("[DEBUG] Failed to create debug directory: %v\n", err)
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
		fmt.Printf("[DEBUG] Failed to write debug file: %v\n", err)
	} else {
		fmt.Printf("[DEBUG] Saved MQTT message to: %s\n", filepath)
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
	fmt.Printf("[MQTT] Requested removal of device: %s from Zigbee2MQTT\n", deviceName)
}

func RestartZigbee2MQTT() {
	// Send restart command to Zigbee2MQTT
	MQTT.Publish("zb2m-sumika/bridge/request/restart", []byte("{}"))
	fmt.Printf("[MQTT] Requested Zigbee2MQTT restart\n")
}

func ReloadDeviceState(deviceName string) {
	// Send get command to request fresh device state from Zigbee2MQTT
	topic := fmt.Sprintf("zb2m-sumika/%s/get", deviceName)
	MQTT.Publish(topic, []byte("{}"))
	fmt.Printf("[MQTT] Requested device state refresh for: %s\n", deviceName)
}

var DeviceList []Device

func Init() {
	MQTT.Subscribe("zb2m-sumika/bridge/devices", func(topic string, payload []byte) {
		// Debug: Save broadcast message
		debugSaveMQTTMessage("broadcast", topic, payload)
		
		json.Unmarshal([]byte(payload), &DeviceList)
		
		// Update device cache
		updateDeviceCache()
		
		fmt.Printf("[CACHE] Saved %d devices to cache\n", len(DeviceList))
	})
	SaveUpdates()
}

func SetDeviceState(name string, state string) {
	MQTT.Publish("zb2m-sumika/" + name + "/set", []byte(state))
}

func ListDevices() []Device {
	// Try to use cached devices first
	cachedDevices := manage.GetDeviceCache()
	if len(cachedDevices) > 0 {
		fmt.Printf("[CACHE] Using cached device list with %d devices\n", len(cachedDevices))
		// Convert cached devices back to Device structs
		var devices []Device
		for _, cachedDevice := range cachedDevices {
			deviceData, _ := json.Marshal(cachedDevice)
			var device Device
			json.Unmarshal(deviceData, &device)
			// populate zones for each device
			device.Zones = manage.GetZonesOfDevice(device.FriendlyName)
			
			// populate custom metadata for each device
			if metadata, exists := manage.GetDeviceMetadata(device.FriendlyName); exists {
				device.CustomName = metadata["custom_name"]
				device.CustomCategory = metadata["custom_category"]
			}
			
			devices = append(devices, device)
		}
		return devices
	}
	
	// Fallback to live DeviceList
	fmt.Printf("[CACHE] Cache empty, using live device list with %d devices\n", len(DeviceList))
	// populate zones and custom metadata for each device
	for key, device := range DeviceList {
		DeviceList[key].Zones = manage.GetZonesOfDevice(device.FriendlyName)
		
		// populate custom metadata for each device
		if metadata, exists := manage.GetDeviceMetadata(device.FriendlyName); exists {
			DeviceList[key].CustomName = metadata["custom_name"]
			DeviceList[key].CustomCategory = metadata["custom_category"]
		}
	}
	return DeviceList
}

// GetDeviceState returns the current state of a device by name
func GetDeviceState(deviceName string) map[string]interface{} {
	fmt.Printf("Looking for device state: %s\n", deviceName)
	
	// First try to find in live DeviceList
	deviceIndex := getDeviceByName(deviceName)
	if deviceIndex != -1 && DeviceList[deviceIndex].State != nil {
		fmt.Printf("Device %s found in live list with state: %+v\n", deviceName, DeviceList[deviceIndex].State)
		return DeviceList[deviceIndex].State
	}
	
	// If not found in live list, try cached devices
	cachedDevices := manage.GetDeviceCache()
	for _, cachedDevice := range cachedDevices {
		if friendlyName, exists := cachedDevice["friendly_name"]; exists && friendlyName == deviceName {
			if state, hasState := cachedDevice["state"]; hasState {
				if stateMap, ok := state.(map[string]interface{}); ok {
					fmt.Printf("Device %s found in cache with state: %+v\n", deviceName, stateMap)
					return stateMap
				}
			}
		}
	}
	
	fmt.Printf("Device %s not found or has no state\n", deviceName)
	return map[string]interface{}{}
}

func updateDeviceCache() {
	// Get existing cache to merge with
	existingCache := manage.GetDeviceCache()
	fmt.Printf("[CACHE] Merging %d Zigbee2MQTT devices with %d existing cached devices\n", len(DeviceList), len(existingCache))
	
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
					fmt.Printf("[CACHE] Updated existing device: %s\n", name)
				} else {
						mergedCache = append(mergedCache, existingDevice)
				}
			}
		}
	}
	
	// Add any new devices not in existing cache
	for name, newDevice := range newDevicesMap {
		fmt.Printf("[CACHE] Adding new Zigbee device: %s\n", name)
		mergedCache = append(mergedCache, newDevice)
	}
	
	fmt.Printf("[CACHE] Final merged cache has %d devices\n", len(mergedCache))
	manage.SetDeviceCache(mergedCache)
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
		
		fmt.Println("[MQTT] SAVE UPDATE:", topic, (string)(payload))
		// get last part of topic
		parts := strings.Split(topic, "/")
		deviceName := parts[len(parts)-1]

		fmt.Println("[MQTT] Device name:", deviceName)

		mapData := map[string]interface{}{}
		json.Unmarshal([]byte(payload), &mapData)

		// Get old state from cache for automation trigger checking
		oldState := make(map[string]interface{})
		cachedDevices := manage.GetDeviceCache()
		
		// Find device in cache to get old state
		var deviceFound bool
		var newDeviceCache map[string]interface{}
		
		for i, cachedDevice := range cachedDevices {
			if friendlyName, exists := cachedDevice["friendly_name"]; exists && friendlyName == deviceName {
				deviceFound = true
				fmt.Printf("[MQTT] Found device %s in cache\n", deviceName)
				
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
		
		if !deviceFound {
			fmt.Printf("[MQTT] Device %s not found in cache, creating new entry\n", deviceName)
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
		manage.SetDeviceCache(cachedDevices)
		
		// For new devices (not found in cache), guess the device category
		if !deviceFound && newDeviceCache != nil {
			guessedCategory := manage.GuessDeviceCategory(newDeviceCache)
			if guessedCategory != "unknown" {
				fmt.Printf("[MQTT] Setting guessed category '%s' for new device: %s\n", guessedCategory, deviceName)
				manage.SetDeviceCustomCategory(deviceName, guessedCategory)
			}
		}
		
		// Check automation triggers when device state changes
		fmt.Printf("[MQTT] Checking automation triggers for device: %s\n", deviceName)
		manage.CheckTriggers(deviceName, oldState, mapData)
		
		// Broadcast real-time update to WebSocket clients
		if hub := realtime.GetHub(); hub != nil {
			hub.BroadcastDeviceUpdate(deviceName, mapData, oldState)
		}

		// Also try to find and update device in live DeviceList if it exists
		deviceIndex := getDeviceByName(deviceName)
		if deviceIndex != -1 {
			DeviceList[deviceIndex].State = mapData
			DeviceList[deviceIndex].LastSeen = time.Now().Format("2006-01-02T15:04:05Z07:00")
			fmt.Println("[MQTT] Device updated in live list:", deviceName, "last seen:", DeviceList[deviceIndex].LastSeen)
		} else {
			fmt.Printf("[MQTT] Device %s not in live DeviceList (this is normal if bridge/devices hasn't been received yet)\n", deviceName)
		}
	})
}