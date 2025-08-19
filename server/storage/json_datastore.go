package storage

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"time"

	"github.com/azukaar/sumika/server/manage"
)

// StorageData represents the data structure saved to JSON file
type StorageData struct {
	Zones          []string                           `json:"zones"`
	DeviceZones    map[string][]string                `json:"device_zones"`
	DeviceCache    []map[string]interface{}           `json:"device_cache,omitempty"`
	DeviceMetadata map[string]map[string]string       `json:"device_metadata,omitempty"`
	Automations    []manage.Automation                `json:"automations,omitempty"`
	LastUpdated    string                             `json:"last_updated,omitempty"`
}

// JSONDataStore implements DataStore interface using JSON files
type JSONDataStore struct {
	filePath string
	data     *StorageData
}

// NewJSONDataStore creates a new JSON-based data store
func NewJSONDataStore(filePath string) *JSONDataStore {
	// Create default data structure
	data := &StorageData{
		Zones:          []string{},
		DeviceZones:    make(map[string][]string),
		DeviceCache:    []map[string]interface{}{},
		DeviceMetadata: make(map[string]map[string]string),
		Automations:    []manage.Automation{},
	}
	
	return &JSONDataStore{
		filePath: filePath,
		data:     data,
	}
}

// GetData returns the internal data structure for repositories to use
func (ds *JSONDataStore) GetData() *StorageData {
	return ds.data
}

// Save persists the current data to the JSON file
func (ds *JSONDataStore) Save() error {
	// Update timestamp
	ds.data.LastUpdated = time.Now().Format("2006-01-02 15:04:05")
	
	jsonData, err := json.MarshalIndent(ds.data, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal data: %w", err)
	}
	
	// Create directory if it doesn't exist
	dir := filepath.Dir(ds.filePath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("failed to create directory: %w", err)
	}
	
	// Write to temporary file first, then rename (atomic operation)
	tempFile := ds.filePath + ".tmp"
	if err := ioutil.WriteFile(tempFile, jsonData, 0644); err != nil {
		return fmt.Errorf("failed to write temporary file: %w", err)
	}
	
	if err := os.Rename(tempFile, ds.filePath); err != nil {
		os.Remove(tempFile) // Clean up temp file on error
		return fmt.Errorf("failed to rename temporary file: %w", err)
	}
	
	return nil
}

// Load reads data from the JSON file
func (ds *JSONDataStore) Load() error {
	// Check if file exists
	if _, err := os.Stat(ds.filePath); os.IsNotExist(err) {
		// File doesn't exist, use default values
		return nil
	}
	
	jsonData, err := ioutil.ReadFile(ds.filePath)
	if err != nil {
		return fmt.Errorf("failed to read data file: %w", err)
	}
	
	// Parse JSON data
	var loadedData StorageData
	if err := json.Unmarshal(jsonData, &loadedData); err != nil {
		return fmt.Errorf("failed to parse JSON data: %w", err)
	}
	
	// Initialize nil maps to prevent panics
	if loadedData.DeviceZones == nil {
		loadedData.DeviceZones = make(map[string][]string)
	}
	if loadedData.DeviceMetadata == nil {
		loadedData.DeviceMetadata = make(map[string]map[string]string)
	}
	if loadedData.DeviceCache == nil {
		loadedData.DeviceCache = []map[string]interface{}{}
	}
	if loadedData.Automations == nil {
		loadedData.Automations = []manage.Automation{}
	}
	if loadedData.Zones == nil {
		loadedData.Zones = []string{}
	}
	
	ds.data = &loadedData
	return nil
}

// CreateRepository creates a complete repository with all sub-repositories
func CreateRepository(dataStorePath string) (*Repository, error) {
	// Create data store
	dataStore := NewJSONDataStore(dataStorePath)
	
	// Load existing data
	if err := dataStore.Load(); err != nil {
		return nil, fmt.Errorf("failed to load data: %w", err)
	}
	
	// Get reference to data
	data := dataStore.GetData()
	
	// Create repositories
	return &Repository{
		Zones:       NewJSONZoneRepository(dataStore, data),
		Automations: NewJSONAutomationRepository(dataStore, data),
		Devices:     NewJSONDeviceRepository(dataStore, data),
	}, nil
}