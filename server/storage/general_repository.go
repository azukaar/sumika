package storage

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/azukaar/sumika/server/config"
	"github.com/azukaar/sumika/server/types"
)

// Global storage instance
var (
	globalData *types.StorageData
	dataMutex  sync.RWMutex
	filePath   string
)

// Initialize initializes the storage system
func Initialize() error {
	cfg := config.GetConfig()
	filePath = filepath.Join(cfg.Database.DataDirectory, "storage.json")
	
	data, err := loadData()
	if err != nil {
		return err
	}
	
	dataMutex.Lock()
	globalData = data
	dataMutex.Unlock()
	
	// Log what was loaded for debugging
	fmt.Printf("Storage loaded: %d zones, %d device assignments, %d devices in cache, %d automations\n", 
		len(data.Zones), len(data.DeviceZones), len(data.DeviceCache), len(data.Automations))
	
	// Create intent generator and generate intents
	generator := NewVoiceIntentGenerator()
	if err := generator.GenerateIntents(); err != nil {
		fmt.Printf("Warning: Failed to generate voice intents: %v\n", err)
	}

	return nil
}

// saveData saves the current data to file
func saveData() error {
	dataMutex.RLock()
	data := *globalData
	dataMutex.RUnlock()
	
	data.LastUpdated = time.Now().Format("2006-01-02 15:04:05")
	
	jsonData, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal data: %v", err)
	}
	
	// Create directory if it doesn't exist
	dir := filepath.Dir(filePath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("failed to create directory: %v", err)
	}
	
	// Write to temporary file first, then rename (atomic operation)
	tempFile := filePath + ".tmp"
	if err := ioutil.WriteFile(tempFile, jsonData, 0644); err != nil {
		return fmt.Errorf("failed to write temporary file: %v", err)
	}
	
	if err := os.Rename(tempFile, filePath); err != nil {
		os.Remove(tempFile) // Clean up temp file on error
		return fmt.Errorf("failed to rename temporary file: %v", err)
	}
	
	return nil
}

// loadData loads data from file
func loadData() (*types.StorageData, error) {
	data, err := ioutil.ReadFile(filePath)
	if err != nil {
		if os.IsNotExist(err) {
			// Return empty data structure if file doesn't exist
			return &types.StorageData{
				Zones:          []string{"kitchen", "living_room", "bedroom", "bathroom", "office", "garage"},
				DeviceZones:    make(map[string][]string),
				DeviceCache:    []map[string]interface{}{},
				DeviceMetadata: make(map[string]map[string]string),
				Automations:    []types.Automation{},
			}, nil
		}
		return nil, fmt.Errorf("failed to read file: %v", err)
	}

	var storageData types.StorageData
	if err := json.Unmarshal(data, &storageData); err != nil {
		return nil, fmt.Errorf("failed to unmarshal data: %v", err)
	}

	// Initialize maps if they're nil
	if storageData.DeviceZones == nil {
		storageData.DeviceZones = make(map[string][]string)
	}
	if storageData.DeviceMetadata == nil {
		storageData.DeviceMetadata = make(map[string]map[string]string)
	}
	if storageData.DeviceCache == nil {
		storageData.DeviceCache = []map[string]interface{}{}
	}
	if storageData.Automations == nil {
		storageData.Automations = []types.Automation{}
	}
	if storageData.Zones == nil {
		storageData.Zones = []string{"kitchen", "living_room", "bedroom", "bathroom", "office", "garage"}
	}

	return &storageData, nil
}

// Zone management functions
func GetAllZones() []string {
	dataMutex.RLock()
	defer dataMutex.RUnlock()
	return append([]string{}, globalData.Zones...)
}

func GetDevicesByZone(zone string) []string {
	dataMutex.RLock()
	defer dataMutex.RUnlock()
	
	var devices []string
	for device, zones := range globalData.DeviceZones {
		for _, z := range zones {
			if z == zone {
				devices = append(devices, device)
				break
			}
		}
	}
	return devices
}

func GetDeviceZones(device string) []string {
	dataMutex.RLock()
	defer dataMutex.RUnlock()
	
	if zones, ok := globalData.DeviceZones[device]; ok {
		return append([]string{}, zones...)
	}
	return []string{}
}

func SetDeviceZones(device string, zones []string) error {
	dataMutex.Lock()
	globalData.DeviceZones[device] = append([]string{}, zones...)
	dataMutex.Unlock()
	
	return saveData()
}

func CreateZone(zone string) error {
	dataMutex.Lock()
	// Check if zone already exists
	for _, z := range globalData.Zones {
		if z == zone {
			dataMutex.Unlock()
			return nil // Already exists
		}
	}
	globalData.Zones = append(globalData.Zones, zone)
	dataMutex.Unlock()
	
	return saveData()
}

func DeleteZone(zone string) error {
	dataMutex.Lock()
	
	// Remove from zones list
	for i, z := range globalData.Zones {
		if z == zone {
			globalData.Zones = append(globalData.Zones[:i], globalData.Zones[i+1:]...)
			break
		}
	}
	
	// Remove from device mappings
	for device, zones := range globalData.DeviceZones {
		for i, z := range zones {
			if z == zone {
				globalData.DeviceZones[device] = append(zones[:i], zones[i+1:]...)
				break
			}
		}
	}
	
	dataMutex.Unlock()
	return saveData()
}

func RenameZone(oldName, newName string) error {
	dataMutex.Lock()
	
	// Update in zones list
	for i, zone := range globalData.Zones {
		if zone == oldName {
			globalData.Zones[i] = newName
			break
		}
	}
	
	// Update in device mappings
	for device, zones := range globalData.DeviceZones {
		for i, zone := range zones {
			if zone == oldName {
				globalData.DeviceZones[device][i] = newName
			}
		}
	}
	
	dataMutex.Unlock()
	return saveData()
}

// Automation management functions
func GetAllAutomations() []types.Automation {
	dataMutex.RLock()
	defer dataMutex.RUnlock()
	return append([]types.Automation{}, globalData.Automations...)
}

func GetAutomationByID(id string) *types.Automation {
	dataMutex.RLock()
	defer dataMutex.RUnlock()
	
	for _, automation := range globalData.Automations {
		if automation.ID == id {
			automationCopy := automation
			return &automationCopy
		}
	}
	return nil
}

func CreateAutomation(automation types.Automation) (*types.Automation, error) {
	dataMutex.Lock()
	
	// Generate ID if not provided
	if automation.ID == "" {
		automation.ID = fmt.Sprintf("auto_%d", time.Now().Unix())
	}
	
	globalData.Automations = append(globalData.Automations, automation)
	dataMutex.Unlock()
	
	err := saveData()
	if err != nil {
		return nil, err
	}
	
	return &automation, nil
}

func UpdateAutomation(id string, automation types.Automation) error {
	dataMutex.Lock()
	
	for i, auto := range globalData.Automations {
		if auto.ID == id {
			automation.ID = id // Preserve the ID
			globalData.Automations[i] = automation
			dataMutex.Unlock()
			return saveData()
		}
	}
	
	dataMutex.Unlock()
	return fmt.Errorf("automation with ID %s not found", id)
}

func DeleteAutomation(id string) error {
	dataMutex.Lock()
	found := false
	for i, automation := range globalData.Automations {
		if automation.ID == id {
			globalData.Automations = append(globalData.Automations[:i], globalData.Automations[i+1:]...)
			found = true
			break
		}
	}
	dataMutex.Unlock()
	
	if !found {
		return fmt.Errorf("automation with ID %s not found", id)
	}
	
	return saveData()
}

// Device management functions  
func GetDeviceCache() []map[string]interface{} {
	dataMutex.RLock()
	defer dataMutex.RUnlock()
	
	// Create a deep copy
	cache := make([]map[string]interface{}, len(globalData.DeviceCache))
	for i, device := range globalData.DeviceCache {
		deviceCopy := make(map[string]interface{})
		for k, v := range device {
			deviceCopy[k] = v
		}
		cache[i] = deviceCopy
	}
	return cache
}

func SetDeviceCache(cache []map[string]interface{}) error {
	dataMutex.Lock()
	globalData.DeviceCache = cache
	dataMutex.Unlock()
	
	return saveData()
}

func GetDeviceMetadata(device string) (map[string]string, bool) {
	dataMutex.RLock()
	defer dataMutex.RUnlock()
	
	if metadata, ok := globalData.DeviceMetadata[device]; ok {
		// Return a copy
		metadataCopy := make(map[string]string)
		for k, v := range metadata {
			metadataCopy[k] = v
		}
		return metadataCopy, true
	}
	return nil, false
}

func SetDeviceMetadata(device string, metadata map[string]string) error {
	dataMutex.Lock()
	if globalData.DeviceMetadata[device] == nil {
		globalData.DeviceMetadata[device] = make(map[string]string)
	}
	// Copy the metadata
	for k, v := range metadata {
		globalData.DeviceMetadata[device][k] = v
	}
	dataMutex.Unlock()
	
	return saveData()
}

func SetDeviceCustomName(device, customName string) error {
	dataMutex.Lock()
	if globalData.DeviceMetadata[device] == nil {
		globalData.DeviceMetadata[device] = make(map[string]string)
	}
	globalData.DeviceMetadata[device]["custom_name"] = customName
	dataMutex.Unlock()
	
	return saveData()
}

func SetDeviceCustomCategory(device, category string) error {
	dataMutex.Lock()
	if globalData.DeviceMetadata[device] == nil {
		globalData.DeviceMetadata[device] = make(map[string]string)
	}
	globalData.DeviceMetadata[device]["custom_category"] = category
	dataMutex.Unlock()
	
	return saveData()
}