package services

import (
	"fmt"
	"strings"

	"github.com/azukaar/sumika/server/storage"
)

// ZoneService handles business logic for zone operations
type ZoneService struct {
	zoneRepo storage.ZoneRepository
}

// NewZoneService creates a new zone service
func NewZoneService(zoneRepo storage.ZoneRepository) *ZoneService {
	return &ZoneService{
		zoneRepo: zoneRepo,
	}
}

// GetAllZones returns all zones
func (s *ZoneService) GetAllZones() ([]string, error) {
	return s.zoneRepo.GetAllZones()
}

// CreateZone creates a new zone with validation
func (s *ZoneService) CreateZone(name string) error {
	// Validate zone name
	if strings.TrimSpace(name) == "" {
		return fmt.Errorf("zone name cannot be empty")
	}
	
	// Clean up the name
	cleanName := strings.TrimSpace(name)
	
	// Check for invalid characters (optional business rule)
	if strings.ContainsAny(cleanName, "/\\<>:\"|?*") {
		return fmt.Errorf("zone name contains invalid characters")
	}
	
	return s.zoneRepo.CreateZone(cleanName)
}

// DeleteZone removes a zone with validation
func (s *ZoneService) DeleteZone(name string) error {
	if strings.TrimSpace(name) == "" {
		return fmt.Errorf("zone name cannot be empty")
	}
	
	// Check if zone has devices (business rule - could be configurable)
	devices, err := s.zoneRepo.GetDevicesByZone(name)
	if err != nil {
		return fmt.Errorf("failed to check zone devices: %w", err)
	}
	
	if len(devices) > 0 {
		// You might want to make this configurable - some users might want to force delete
		return fmt.Errorf("cannot delete zone '%s' with %d assigned devices", name, len(devices))
	}
	
	return s.zoneRepo.DeleteZone(name)
}

// RenameZone changes a zone's name with validation
func (s *ZoneService) RenameZone(oldName, newName string) error {
	// Validate inputs
	if strings.TrimSpace(oldName) == "" {
		return fmt.Errorf("old zone name cannot be empty")
	}
	if strings.TrimSpace(newName) == "" {
		return fmt.Errorf("new zone name cannot be empty")
	}
	
	cleanNewName := strings.TrimSpace(newName)
	
	// Check for invalid characters
	if strings.ContainsAny(cleanNewName, "/\\<>:\"|?*") {
		return fmt.Errorf("new zone name contains invalid characters")
	}
	
	return s.zoneRepo.RenameZone(oldName, cleanNewName)
}

// GetDevicesByZone returns devices in a zone
func (s *ZoneService) GetDevicesByZone(zone string) ([]string, error) {
	if strings.TrimSpace(zone) == "" {
		return nil, fmt.Errorf("zone name cannot be empty")
	}
	
	return s.zoneRepo.GetDevicesByZone(zone)
}

// GetZonesOfDevice returns zones a device belongs to
func (s *ZoneService) GetZonesOfDevice(deviceName string) ([]string, error) {
	if strings.TrimSpace(deviceName) == "" {
		return nil, fmt.Errorf("device name cannot be empty")
	}
	
	return s.zoneRepo.GetZonesOfDevice(deviceName)
}

// SetDeviceZones assigns a device to zones with validation
func (s *ZoneService) SetDeviceZones(deviceName string, zones []string) error {
	if strings.TrimSpace(deviceName) == "" {
		return fmt.Errorf("device name cannot be empty")
	}
	
	// Clean and validate zone names
	cleanZones := make([]string, 0, len(zones))
	for _, zone := range zones {
		cleanZone := strings.TrimSpace(zone)
		if cleanZone != "" {
			cleanZones = append(cleanZones, cleanZone)
		}
	}
	
	return s.zoneRepo.SetDeviceZones(deviceName, cleanZones)
}

// ZoneExists checks if a zone exists
func (s *ZoneService) ZoneExists(name string) bool {
	return s.zoneRepo.ZoneExists(name)
}