package storage

import (
	"fmt"
	"slices"
)

// JSONDeviceRepository implements DeviceRepository using JSON file storage
type JSONDeviceRepository struct {
	dataStore DataStore
	data      *StorageData
}

// NewJSONDeviceRepository creates a new JSON-based device repository
func NewJSONDeviceRepository(dataStore DataStore, data *StorageData) *JSONDeviceRepository {
	return &JSONDeviceRepository{
		dataStore: dataStore,
		data:      data,
	}
}

// GetDeviceMetadata returns all metadata for a device
func (r *JSONDeviceRepository) GetDeviceMetadata(deviceName string) (map[string]string, error) {
	if r.data.DeviceMetadata == nil {
		return map[string]string{}, nil
	}
	
	metadata := r.data.DeviceMetadata[deviceName]
	if metadata == nil {
		return map[string]string{}, nil
	}
	
	// Return a copy to prevent external modification
	result := make(map[string]string, len(metadata))
	for k, v := range metadata {
		result[k] = v
	}
	return result, nil
}

// SetDeviceMetadata sets all metadata for a device
func (r *JSONDeviceRepository) SetDeviceMetadata(deviceName string, metadata map[string]string) error {
	if r.data.DeviceMetadata == nil {
		r.data.DeviceMetadata = make(map[string]map[string]string)
	}
	
	// Create a copy to prevent external modification
	deviceMetadata := make(map[string]string, len(metadata))
	for k, v := range metadata {
		deviceMetadata[k] = v
	}
	
	r.data.DeviceMetadata[deviceName] = deviceMetadata
	return r.dataStore.Save()
}

// GetDeviceCustomName returns the custom name for a device
func (r *JSONDeviceRepository) GetDeviceCustomName(deviceName string) (string, error) {
	if r.data.DeviceMetadata == nil {
		return "", nil
	}
	
	deviceMetadata := r.data.DeviceMetadata[deviceName]
	if deviceMetadata == nil {
		return "", nil
	}
	
	return deviceMetadata["custom_name"], nil
}

// SetDeviceCustomName sets the custom name for a device
func (r *JSONDeviceRepository) SetDeviceCustomName(deviceName, customName string) error {
	if r.data.DeviceMetadata == nil {
		r.data.DeviceMetadata = make(map[string]map[string]string)
	}
	
	if r.data.DeviceMetadata[deviceName] == nil {
		r.data.DeviceMetadata[deviceName] = make(map[string]string)
	}
	
	if customName == "" {
		delete(r.data.DeviceMetadata[deviceName], "custom_name")
		// Clean up empty metadata maps
		if len(r.data.DeviceMetadata[deviceName]) == 0 {
			delete(r.data.DeviceMetadata, deviceName)
		}
	} else {
		r.data.DeviceMetadata[deviceName]["custom_name"] = customName
	}
	
	return r.dataStore.Save()
}

// GetDeviceCustomCategory returns the custom category for a device
func (r *JSONDeviceRepository) GetDeviceCustomCategory(deviceName string) (string, error) {
	if r.data.DeviceMetadata == nil {
		return "", nil
	}
	
	deviceMetadata := r.data.DeviceMetadata[deviceName]
	if deviceMetadata == nil {
		return "", nil
	}
	
	return deviceMetadata["custom_category"], nil
}

// SetDeviceCustomCategory sets the custom category for a device
func (r *JSONDeviceRepository) SetDeviceCustomCategory(deviceName, category string) error {
	if r.data.DeviceMetadata == nil {
		r.data.DeviceMetadata = make(map[string]map[string]string)
	}
	
	if r.data.DeviceMetadata[deviceName] == nil {
		r.data.DeviceMetadata[deviceName] = make(map[string]string)
	}
	
	if category == "" {
		delete(r.data.DeviceMetadata[deviceName], "custom_category")
		// Clean up empty metadata maps
		if len(r.data.DeviceMetadata[deviceName]) == 0 {
			delete(r.data.DeviceMetadata, deviceName)
		}
	} else {
		r.data.DeviceMetadata[deviceName]["custom_category"] = category
	}
	
	return r.dataStore.Save()
}

// GetDeviceCache returns the device cache
func (r *JSONDeviceRepository) GetDeviceCache() ([]map[string]interface{}, error) {
	if r.data.DeviceCache == nil {
		return []map[string]interface{}{}, nil
	}
	return slices.Clone(r.data.DeviceCache), nil
}

// SetDeviceCache updates the device cache
func (r *JSONDeviceRepository) SetDeviceCache(cache []map[string]interface{}) error {
	r.data.DeviceCache = slices.Clone(cache)
	return r.dataStore.Save()
}