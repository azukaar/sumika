package storage

import "github.com/azukaar/sumika/server/manage"

// ZoneRepository defines operations for zone data persistence
type ZoneRepository interface {
	GetAllZones() ([]string, error)
	CreateZone(name string) error
	DeleteZone(name string) error
	RenameZone(oldName, newName string) error
	ZoneExists(name string) bool
	
	// Device-Zone assignments
	GetDevicesByZone(zone string) ([]string, error)
	GetZonesOfDevice(deviceName string) ([]string, error)
	SetDeviceZones(deviceName string, zones []string) error
}

// AutomationRepository defines operations for automation data persistence
type AutomationRepository interface {
	GetAllAutomations() ([]manage.Automation, error)
	GetAutomationByID(id string) (*manage.Automation, error)
	CreateAutomation(automation manage.Automation) (string, error)
	UpdateAutomation(id string, automation manage.Automation) error
	UpdatePartialAutomation(id string, updates map[string]interface{}) error
	DeleteAutomation(id string) error
	GetAutomationsForDevice(deviceName string) ([]manage.Automation, error)
}

// DeviceRepository defines operations for device metadata persistence
type DeviceRepository interface {
	GetDeviceMetadata(deviceName string) (map[string]string, error)
	SetDeviceMetadata(deviceName string, metadata map[string]string) error
	GetDeviceCustomName(deviceName string) (string, error)
	SetDeviceCustomName(deviceName, customName string) error
	GetDeviceCustomCategory(deviceName string) (string, error)
	SetDeviceCustomCategory(deviceName, category string) error
	
	// Device cache for runtime data
	GetDeviceCache() ([]map[string]interface{}, error)
	SetDeviceCache(cache []map[string]interface{}) error
}

// Repository aggregates all repository interfaces
type Repository struct {
	Zones       ZoneRepository
	Automations AutomationRepository
	Devices     DeviceRepository
}

// DataStore represents the unified data storage interface
type DataStore interface {
	Save() error
	Load() error
}