package zigbee2mqtt

import (
	"encoding/json"
	"fmt"
	"strings"
	"io/ioutil"
	"time"

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

func AllowJoin() {
	payload := map[string]interface{}{
			"value": true,
			"time": 250,
	}
	MQTT.Publish("zb2m-sumika/bridge/request/permit_join", toJSON(payload))
}

var DeviceList []Device

func Init() {
	MQTT.Subscribe("zb2m-sumika/bridge/devices", func(topic string, payload []byte) {
		// save devices list to json file for debug
		ioutil.WriteFile("devices-debug.json", payload, 0644)

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
	// Convert DeviceList to cache format and save to device cache
	deviceCache := make([]map[string]interface{}, len(DeviceList))
	for i, device := range DeviceList {
		deviceData, _ := json.Marshal(device)
		var deviceMap map[string]interface{}
		json.Unmarshal(deviceData, &deviceMap)
		deviceCache[i] = deviceMap
	}
	manage.SetDeviceCache(deviceCache)
}

func SaveUpdates() {
	MQTT.Subscribe("zb2m-sumika/+", func(topic string, payload []byte) {
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
				"ieee_address":  deviceName,
				"state":         mapData,
				"last_seen":     time.Now().Format("2006-01-02T15:04:05Z07:00"),
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