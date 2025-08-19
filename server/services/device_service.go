package services

import (
	"fmt"
	"strings"

	"github.com/azukaar/sumika/server/storage"
)

// DeviceService handles business logic for device metadata operations
type DeviceService struct {
	deviceRepo storage.DeviceRepository
}

// NewDeviceService creates a new device service
func NewDeviceService(deviceRepo storage.DeviceRepository) *DeviceService {
	return &DeviceService{
		deviceRepo: deviceRepo,
	}
}

// GetDeviceMetadata returns all metadata for a device
func (s *DeviceService) GetDeviceMetadata(deviceName string) (map[string]string, error) {
	if strings.TrimSpace(deviceName) == "" {
		return nil, fmt.Errorf("device name cannot be empty")
	}
	
	return s.deviceRepo.GetDeviceMetadata(deviceName)
}

// SetDeviceMetadata sets all metadata for a device
func (s *DeviceService) SetDeviceMetadata(deviceName string, metadata map[string]string) error {
	if strings.TrimSpace(deviceName) == "" {
		return fmt.Errorf("device name cannot be empty")
	}
	
	// Validate metadata values
	cleanMetadata := make(map[string]string)
	for key, value := range metadata {
		cleanKey := strings.TrimSpace(key)
		cleanValue := strings.TrimSpace(value)
		
		if cleanKey == "" {
			continue // Skip empty keys
		}
		
		cleanMetadata[cleanKey] = cleanValue
	}
	
	return s.deviceRepo.SetDeviceMetadata(deviceName, cleanMetadata)
}

// GetDeviceCustomName returns the custom name for a device
func (s *DeviceService) GetDeviceCustomName(deviceName string) (string, error) {
	if strings.TrimSpace(deviceName) == "" {
		return "", fmt.Errorf("device name cannot be empty")
	}
	
	return s.deviceRepo.GetDeviceCustomName(deviceName)
}

// SetDeviceCustomName sets the custom name for a device
func (s *DeviceService) SetDeviceCustomName(deviceName, customName string) error {
	if strings.TrimSpace(deviceName) == "" {
		return fmt.Errorf("device name cannot be empty")
	}
	
	// Clean the custom name
	cleanCustomName := strings.TrimSpace(customName)
	
	// Validate custom name (business rules)
	if len(cleanCustomName) > 100 { // Reasonable limit
		return fmt.Errorf("custom name too long (max 100 characters)")
	}
	
	// Check for potentially problematic characters
	if strings.ContainsAny(cleanCustomName, "<>\"'&") {
		return fmt.Errorf("custom name contains invalid characters")
	}
	
	return s.deviceRepo.SetDeviceCustomName(deviceName, cleanCustomName)
}

// GetDeviceCustomCategory returns the custom category for a device
func (s *DeviceService) GetDeviceCustomCategory(deviceName string) (string, error) {
	if strings.TrimSpace(deviceName) == "" {
		return "", fmt.Errorf("device name cannot be empty")
	}
	
	return s.deviceRepo.GetDeviceCustomCategory(deviceName)
}

// SetDeviceCustomCategory sets the custom category for a device
func (s *DeviceService) SetDeviceCustomCategory(deviceName, category string) error {
	if strings.TrimSpace(deviceName) == "" {
		return fmt.Errorf("device name cannot be empty")
	}
	
	cleanCategory := strings.TrimSpace(category)
	
	// Validate category against allowed values
	if cleanCategory != "" {
		validCategories := s.getValidCategories()
		isValid := false
		for _, validCategory := range validCategories {
			if cleanCategory == validCategory {
				isValid = true
				break
			}
		}
		
		if !isValid {
			return fmt.Errorf("invalid category '%s', valid categories: %v", cleanCategory, validCategories)
		}
	}
	
	return s.deviceRepo.SetDeviceCustomCategory(deviceName, cleanCategory)
}

// GetDeviceCache returns the device cache
func (s *DeviceService) GetDeviceCache() ([]map[string]interface{}, error) {
	return s.deviceRepo.GetDeviceCache()
}

// SetDeviceCache updates the device cache
func (s *DeviceService) SetDeviceCache(cache []map[string]interface{}) error {
	if cache == nil {
		cache = []map[string]interface{}{}
	}
	
	return s.deviceRepo.SetDeviceCache(cache)
}

// getValidCategories returns the list of valid device categories
func (s *DeviceService) getValidCategories() []string {
	return []string{
		"light",
		"switch", 
		"sensor",
		"door_window",
		"thermostat",
		"unknown",
	}
}

// GetValidCategories returns the list of valid device categories (public method)
func (s *DeviceService) GetValidCategories() []string {
	return s.getValidCategories()
}