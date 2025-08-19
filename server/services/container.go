package services

import (
	"path/filepath"

	"github.com/azukaar/sumika/server/storage"
)

// Container holds all services and provides dependency injection
type Container struct {
	// Services
	ZoneService       *ZoneService
	AutomationService *AutomationService
	DeviceService     *DeviceService
	
	// Infrastructure
	Repository *storage.Repository
}

// NewContainer creates a new service container with all dependencies
func NewContainer() (*Container, error) {
	// Create repository with default data path
	dataDir := "./build-data"
	dataPath := filepath.Join(dataDir, "zones_data.json")
	
	repository, err := storage.CreateRepository(dataPath)
	if err != nil {
		return nil, err
	}
	
	// Create services
	zoneService := NewZoneService(repository.Zones)
	automationService := NewAutomationService(repository.Automations)
	deviceService := NewDeviceService(repository.Devices)
	
	return &Container{
		ZoneService:       zoneService,
		AutomationService: automationService,
		DeviceService:     deviceService,
		Repository:        repository,
	}, nil
}

// NewContainerWithPath creates a container with a custom data path
func NewContainerWithPath(dataPath string) (*Container, error) {
	repository, err := storage.CreateRepository(dataPath)
	if err != nil {
		return nil, err
	}
	
	// Create services
	zoneService := NewZoneService(repository.Zones)
	automationService := NewAutomationService(repository.Automations)
	deviceService := NewDeviceService(repository.Devices)
	
	return &Container{
		ZoneService:       zoneService,
		AutomationService: automationService,
		DeviceService:     deviceService,
		Repository:        repository,
	}, nil
}