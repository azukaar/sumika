package storage

import (
	"fmt"
	"slices"
)

// JSONZoneRepository implements ZoneRepository using JSON file storage
type JSONZoneRepository struct {
	dataStore DataStore
	data      *StorageData
}

// NewJSONZoneRepository creates a new JSON-based zone repository
func NewJSONZoneRepository(dataStore DataStore, data *StorageData) *JSONZoneRepository {
	return &JSONZoneRepository{
		dataStore: dataStore,
		data:      data,
	}
}

// GetAllZones returns all zones
func (r *JSONZoneRepository) GetAllZones() ([]string, error) {
	return slices.Clone(r.data.Zones), nil
}

// CreateZone creates a new zone if it doesn't exist
func (r *JSONZoneRepository) CreateZone(name string) error {
	if r.ZoneExists(name) {
		return fmt.Errorf("zone '%s' already exists", name)
	}
	
	r.data.Zones = append(r.data.Zones, name)
	return r.dataStore.Save()
}

// DeleteZone removes a zone and all its device assignments
func (r *JSONZoneRepository) DeleteZone(name string) error {
	if !r.ZoneExists(name) {
		return fmt.Errorf("zone '%s' not found", name)
	}
	
	// Remove zone from list
	for i, zone := range r.data.Zones {
		if zone == name {
			r.data.Zones = append(r.data.Zones[:i], r.data.Zones[i+1:]...)
			break
		}
	}
	
	// Remove zone from all device assignments
	for deviceName, deviceZones := range r.data.DeviceZones {
		updatedZones := make([]string, 0, len(deviceZones))
		for _, zone := range deviceZones {
			if zone != name {
				updatedZones = append(updatedZones, zone)
			}
		}
		if len(updatedZones) != len(deviceZones) {
			r.data.DeviceZones[deviceName] = updatedZones
		}
	}
	
	return r.dataStore.Save()
}

// RenameZone changes a zone's name
func (r *JSONZoneRepository) RenameZone(oldName, newName string) error {
	if !r.ZoneExists(oldName) {
		return fmt.Errorf("zone '%s' not found", oldName)
	}
	
	if r.ZoneExists(newName) {
		return fmt.Errorf("zone '%s' already exists", newName)
	}
	
	// Update zone in list
	for i, zone := range r.data.Zones {
		if zone == oldName {
			r.data.Zones[i] = newName
			break
		}
	}
	
	// Update zone in all device assignments
	for deviceName, deviceZones := range r.data.DeviceZones {
		for i, zone := range deviceZones {
			if zone == oldName {
				deviceZones[i] = newName
			}
		}
	}
	
	return r.dataStore.Save()
}

// ZoneExists checks if a zone exists
func (r *JSONZoneRepository) ZoneExists(name string) bool {
	return slices.Contains(r.data.Zones, name)
}

// GetDevicesByZone returns all devices assigned to a zone
func (r *JSONZoneRepository) GetDevicesByZone(zone string) ([]string, error) {
	var devices []string
	
	for deviceName, deviceZones := range r.data.DeviceZones {
		if slices.Contains(deviceZones, zone) {
			devices = append(devices, deviceName)
		}
	}
	
	return devices, nil
}

// GetZonesOfDevice returns all zones a device is assigned to
func (r *JSONZoneRepository) GetZonesOfDevice(deviceName string) ([]string, error) {
	zones := r.data.DeviceZones[deviceName]
	if zones == nil {
		return []string{}, nil
	}
	return slices.Clone(zones), nil
}

// SetDeviceZones assigns a device to multiple zones
func (r *JSONZoneRepository) SetDeviceZones(deviceName string, zones []string) error {
	// Validate that all zones exist
	for _, zone := range zones {
		if !r.ZoneExists(zone) {
			return fmt.Errorf("zone '%s' does not exist", zone)
		}
	}
	
	// Remove duplicates and sort for consistency
	uniqueZones := make([]string, 0, len(zones))
	seen := make(map[string]bool)
	for _, zone := range zones {
		if !seen[zone] {
			uniqueZones = append(uniqueZones, zone)
			seen[zone] = true
		}
	}
	
	if r.data.DeviceZones == nil {
		r.data.DeviceZones = make(map[string][]string)
	}
	
	r.data.DeviceZones[deviceName] = uniqueZones
	return r.dataStore.Save()
}