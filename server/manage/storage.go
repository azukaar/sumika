package manage

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"time"
)

// StorageData represents the data structure saved to file
type StorageData struct {
	Zones          []string                           `json:"zones"`
	DeviceZones    map[string][]string                `json:"device_zones"`
	DeviceCache    []map[string]interface{}           `json:"device_cache,omitempty"`
	DeviceMetadata map[string]map[string]string       `json:"device_metadata,omitempty"`
	Automations    []Automation                       `json:"automations,omitempty"`
	LastUpdated    string                             `json:"last_updated,omitempty"`
}

// Storage interface defines methods for persisting data
type Storage interface {
	SaveData() error
	LoadData() error
}

// FileStorage implements Storage interface using JSON files
type FileStorage struct {
	filePath string
}

// NewFileStorage creates a new file storage instance
func NewFileStorage() *FileStorage {
	// Use a dedicated build-data folder relative to current working directory
	dataDir := "./build-data"
	filePath := filepath.Join(dataDir, "zones_data.json")
	
	return &FileStorage{
		filePath: filePath,
	}
}

// SaveData saves the current zones and device assignments to file
func (fs *FileStorage) SaveData() error {
	data := StorageData{
		Zones:          allZones,
		DeviceZones:    zones,
		DeviceCache:    deviceCache,
		DeviceMetadata: deviceMetadata,
		Automations:    automations,
		LastUpdated:    time.Now().Format("2006-01-02 15:04:05"),
	}
	
	jsonData, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal data: %v", err)
	}
	
	// Create directory if it doesn't exist
	dir := filepath.Dir(fs.filePath)
	fmt.Printf("DEBUG: Creating directory: %s\n", dir)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("failed to create directory: %v", err)
	}
	
	// Get absolute path for debugging
	absPath, _ := filepath.Abs(fs.filePath)
	fmt.Printf("DEBUG: Saving to absolute path: %s\n", absPath)
	
	// Write to temporary file first, then rename (atomic operation)
	tempFile := fs.filePath + ".tmp"
	if err := ioutil.WriteFile(tempFile, jsonData, 0644); err != nil {
		return fmt.Errorf("failed to write temporary file: %v", err)
	}
	
	if err := os.Rename(tempFile, fs.filePath); err != nil {
		os.Remove(tempFile) // Clean up temp file on error
		return fmt.Errorf("failed to rename temporary file: %v", err)
	}
	
	fmt.Printf("Data successfully saved to: %s\n", fs.filePath)
	fmt.Printf("Data contains %d zones and %d device assignments\n", len(allZones), len(zones))
	return nil
}

// LoadData loads zones and device assignments from file
func (fs *FileStorage) LoadData() error {
	// Get absolute path for debugging
	absPath, _ := filepath.Abs(fs.filePath)
	fmt.Printf("DEBUG: Attempting to load from absolute path: %s\n", absPath)
	
	// Check if file exists
	if _, err := os.Stat(fs.filePath); os.IsNotExist(err) {
		fmt.Printf("Data file not found at %s, using defaults\n", fs.filePath)
		return nil // Not an error, just use default values
	}
	
	jsonData, err := ioutil.ReadFile(fs.filePath)
	if err != nil {
		return fmt.Errorf("failed to read file: %v", err)
	}
	
	var data StorageData
	if err := json.Unmarshal(jsonData, &data); err != nil {
		return fmt.Errorf("failed to unmarshal data: %v", err)
	}
	
	// Update global variables
	if data.Zones != nil {
		allZones = data.Zones
	}
	
	if data.DeviceZones != nil {
		zones = data.DeviceZones
	} else {
		zones = make(map[string][]string)
	}
	
	if data.DeviceCache != nil {
		deviceCache = data.DeviceCache
	} else {
		deviceCache = []map[string]interface{}{}
	}
	
	if data.Automations != nil {
		automations = data.Automations
	} else {
		automations = []Automation{}
	}
	
	if data.DeviceMetadata != nil {
		SetAllDeviceMetadata(data.DeviceMetadata)
	} else {
		SetAllDeviceMetadata(make(map[string]map[string]string))
	}
	
	fmt.Printf("Data loaded from: %s\n", fs.filePath)
	fmt.Printf("Loaded %d zones, %d device assignments, %d automations, and %d device metadata entries\n", len(allZones), len(zones), len(automations), len(deviceMetadata))
	return nil
}

// Global storage instance
var storage Storage

// InitStorage initializes the storage system
func InitStorage() error {
	storage = NewFileStorage()
	return storage.LoadData()
}

// SaveToStorage saves current data to storage
func SaveToStorage() error {
	if storage == nil {
		return fmt.Errorf("storage not initialized")
	}
	return storage.SaveData()
}

// GetStorageFilePath returns the current storage file path (for debugging)
func GetStorageFilePath() string {
	if fs, ok := storage.(*FileStorage); ok {
		return fs.filePath
	}
	return "unknown"
}