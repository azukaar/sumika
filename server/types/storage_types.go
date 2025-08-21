package types

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