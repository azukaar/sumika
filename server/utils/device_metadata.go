package utils

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

// DeviceMetadata represents the enhanced device metadata from zigbee-herdsman-converters
type DeviceMetadata struct {
	Model       interface{} `json:"model"`       // Can be string or []string
	Vendor      string      `json:"vendor"`
	Description string      `json:"description"`
	Supports    *string     `json:"supports,omitempty"`
	Exposes     []Expose    `json:"exposes"`
	Options     []Option    `json:"options,omitempty"`
	Meta        Meta        `json:"meta,omitempty"`
	OTA         bool        `json:"ota"`
	WhiteLabel  []WhiteLabel `json:"whiteLabel,omitempty"`
}

// Expose represents a device capability/control
type Expose struct {
	Type        string     `json:"type"`
	Name        string     `json:"name,omitempty"`
	Property    string     `json:"property,omitempty"`
	Description string     `json:"description,omitempty"`
	Label       string     `json:"label,omitempty"`
	Access      int        `json:"access,omitempty"`
	Unit        string     `json:"unit,omitempty"`
	Category    string     `json:"category,omitempty"`
	
	// Numeric type fields
	ValueMin  *float64   `json:"value_min,omitempty"`
	ValueMax  *float64   `json:"value_max,omitempty"`
	ValueStep *float64   `json:"value_step,omitempty"`
	Presets   []Preset   `json:"presets,omitempty"`
	
	// Enum type fields
	Values    []string   `json:"values,omitempty"`
	
	// Binary type fields
	ValueOn   interface{} `json:"value_on,omitempty"`
	ValueOff  interface{} `json:"value_off,omitempty"`
	ValueToggle interface{} `json:"value_toggle,omitempty"`
	
	// Composite type fields
	Features  []Expose   `json:"features,omitempty"`
	
	// List type fields
	ItemType  string     `json:"item_type,omitempty"`
	LengthMin *int       `json:"length_min,omitempty"`
	LengthMax *int       `json:"length_max,omitempty"`
	
	// Dynamic expose error info
	Note      string     `json:"note,omitempty"`
	Error     string     `json:"error,omitempty"`
}

// Preset represents a numeric preset value
type Preset struct {
	Name        string  `json:"name"`
	Value       float64 `json:"value"`
	Description string  `json:"description,omitempty"`
}

// Option represents a device configuration option
type Option struct {
	Name        string      `json:"name"`
	Description string      `json:"description"`
	Type        string      `json:"type"`
	Default     interface{} `json:"default,omitempty"`
	Values      []string    `json:"values,omitempty"`
}

// Meta contains device metadata
type Meta struct {
	Configured         int    `json:"configured,omitempty"`
	DisableDefaultResponse bool `json:"disableDefaultResponse,omitempty"`
	MultiEndpoint      bool   `json:"multiEndpoint,omitempty"`
	MultiEndpointSkip  []string `json:"multiEndpointSkip,omitempty"`
}

// WhiteLabel represents alternative branding for the device
type WhiteLabel struct {
	Vendor      string `json:"vendor"`
	Model       string `json:"model"`
	Description string `json:"description,omitempty"`
}

// DeviceMetadataService manages device metadata lookups
type DeviceMetadataService struct {
	scriptPath string
	cache      map[string]*DeviceMetadata
	cacheMu    sync.RWMutex
	cacheTTL   time.Duration
	cacheTime  map[string]time.Time
}

// NewDeviceMetadataService creates a new metadata service
func NewDeviceMetadataService() *DeviceMetadataService {
	// Get the directory where the binary is located
	execPath, err := os.Executable()
	if err != nil {
		fmt.Printf("[DEBUG] DeviceMetadataService: Could not determine executable path: %v\n", err)
	}
	
	var scriptPath string
	if err == nil {
		binaryDir := filepath.Dir(execPath)
		scriptPath = filepath.Join(binaryDir, "device-metadata-script", "index.js")
		fmt.Printf("[DEBUG] DeviceMetadataService: Trying script path relative to binary: %s\n", scriptPath)
		
		// Check if script exists relative to binary
		if _, statErr := os.Stat(scriptPath); os.IsNotExist(statErr) {
			fmt.Printf("[DEBUG] DeviceMetadataService: Script not found at: %s\n", scriptPath)
			scriptPath = "" // will try other paths below
		} else {
			fmt.Printf("[DEBUG] DeviceMetadataService: Found script at: %s\n", scriptPath)
		}
	}
	
	// If not found relative to binary, try current working directory
	if scriptPath == "" {
		scriptPath = "./device-metadata-script/index.js"
		fmt.Printf("[DEBUG] DeviceMetadataService: Trying current directory path: %s\n", scriptPath)
		
		if _, statErr := os.Stat(scriptPath); os.IsNotExist(statErr) {
			// Try absolute path for Docker container
			scriptPath = "/app/device-metadata-script/index.js"
			fmt.Printf("[DEBUG] DeviceMetadataService: Trying Docker absolute path: %s\n", scriptPath)
			
			if _, statErr2 := os.Stat(scriptPath); os.IsNotExist(statErr2) {
				fmt.Printf("[DEBUG] DeviceMetadataService: WARNING: Script not found at any expected location!\n")
			} else {
				fmt.Printf("[DEBUG] DeviceMetadataService: Found script at Docker path: %s\n", scriptPath)
			}
		} else {
			fmt.Printf("[DEBUG] DeviceMetadataService: Found script at current directory: %s\n", scriptPath)
		}
	}
	
	return &DeviceMetadataService{
		scriptPath: scriptPath,
		cache:      make(map[string]*DeviceMetadata),
		cacheTime:  make(map[string]time.Time),
		cacheTTL:   24 * time.Hour, // Cache for 24 hours
	}
}

// ParseScriptOutput extracts and parses JSON from script output,
// handling console log contamination from various scripts
func ParseScriptOutput(output []byte, target interface{}) error {
	outputStr := string(output)
	
	// Extract JSON portion (first { to last })
	startIdx := strings.Index(outputStr, "{")
	if startIdx == -1 {
		return fmt.Errorf("no JSON found in output")
	}
	
	endIdx := strings.LastIndex(outputStr, "}")
	if endIdx == -1 || endIdx <= startIdx {
		return fmt.Errorf("invalid JSON structure in output")
	}
	
	// Extract clean JSON
	jsonBytes := []byte(outputStr[startIdx : endIdx+1])
	
	// Try parsing as requested type
	if err := json.Unmarshal(jsonBytes, target); err != nil {
		// Check if it's an error response
		var errorResp struct {
			Error string `json:"error"`
		}
		if json.Unmarshal(jsonBytes, &errorResp) == nil && errorResp.Error != "" {
			return fmt.Errorf("node script error: %s", errorResp.Error)
		}
		return fmt.Errorf("failed to parse JSON: %v", err)
	}
	
	return nil
}

// GetDeviceMetadata finds device metadata by model ID and manufacturer
func (s *DeviceMetadataService) GetDeviceMetadata(modelID, manufacturerName string) (*DeviceMetadata, error) {
	// Check cache first
	cacheKey := fmt.Sprintf("%s:%s", modelID, manufacturerName)
	s.cacheMu.RLock()
	if cached, exists := s.cache[cacheKey]; exists {
		if time.Since(s.cacheTime[cacheKey]) < s.cacheTTL {
			s.cacheMu.RUnlock()
			return cached, nil
		}
	}
	s.cacheMu.RUnlock()

	// Execute Node script
	fmt.Printf("[DEBUG] DeviceMetadataService: Executing Node script at path: %s\n", s.scriptPath)
	fmt.Printf("[DEBUG] DeviceMetadataService: Command args: --identify %s %s\n", modelID, manufacturerName)
	cmd := exec.Command("node", s.scriptPath, "--identify", modelID, manufacturerName)
	output, err := cmd.Output()
	fmt.Printf("[DEBUG] DeviceMetadataService: Command output length: %d bytes\n", len(output))
	if err != nil {
		fmt.Printf("[DEBUG] DeviceMetadataService: Command error: %v\n", err)
	}
	if err != nil {
		// Check if the error output contains JSON error message
		if exitErr, ok := err.(*exec.ExitError); ok && len(exitErr.Stderr) > 0 {
			var errorResp struct {
				Error string `json:"error"`
			}
			if json.Unmarshal(exitErr.Stderr, &errorResp) == nil {
				return nil, fmt.Errorf("device metadata error: %s", errorResp.Error)
			}
		}
		return nil, fmt.Errorf("failed to get device metadata: %v", err)
	}

	// Parse the JSON output using utility function
	var metadata DeviceMetadata
	if err := ParseScriptOutput(output, &metadata); err != nil {
		return nil, fmt.Errorf("failed to parse device metadata: %v", err)
	}

	// Update cache
	s.cacheMu.Lock()
	s.cache[cacheKey] = &metadata
	s.cacheTime[cacheKey] = time.Now()
	s.cacheMu.Unlock()

	return &metadata, nil
}

// GetDeviceByModel finds device metadata by exact model ID
func (s *DeviceMetadataService) GetDeviceByModel(model string) (*DeviceMetadata, error) {
	// Check cache first
	cacheKey := fmt.Sprintf("model:%s", model)
	s.cacheMu.RLock()
	if cached, exists := s.cache[cacheKey]; exists {
		if time.Since(s.cacheTime[cacheKey]) < s.cacheTTL {
			s.cacheMu.RUnlock()
			return cached, nil
		}
	}
	s.cacheMu.RUnlock()

	// Execute Node script
	cmd := exec.Command("node", s.scriptPath, "--model", model)
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("failed to get device by model: %v", err)
	}

	// Parse the JSON output using utility function
	var metadata DeviceMetadata
	if err := ParseScriptOutput(output, &metadata); err != nil {
		return nil, fmt.Errorf("failed to parse device metadata: %v", err)
	}

	// Update cache
	s.cacheMu.Lock()
	s.cache[cacheKey] = &metadata
	s.cacheTime[cacheKey] = time.Now()
	s.cacheMu.Unlock()

	return &metadata, nil
}

// SearchDevices searches for devices by query string
func (s *DeviceMetadataService) SearchDevices(query string) ([]map[string]interface{}, error) {
	cmd := exec.Command("node", s.scriptPath, "--search", query)
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("failed to search devices: %v", err)
	}

	var result struct {
		Count   int                      `json:"count"`
		Query   string                   `json:"query"`
		Devices []map[string]interface{} `json:"devices"`
	}
	if err := ParseScriptOutput(output, &result); err != nil {
		return nil, fmt.Errorf("failed to parse search results: %v", err)
	}

	return result.Devices, nil
}

// ListVendors returns all unique device vendors
func (s *DeviceMetadataService) ListVendors() ([]string, error) {
	cmd := exec.Command("node", s.scriptPath, "--vendors")
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("failed to list vendors: %v", err)
	}

	var result struct {
		Count   int      `json:"count"`
		Vendors []string `json:"vendors"`
	}
	if err := ParseScriptOutput(output, &result); err != nil {
		return nil, fmt.Errorf("failed to parse vendors: %v", err)
	}

	return result.Vendors, nil
}

// GetVersion returns version information
func (s *DeviceMetadataService) GetVersion() (map[string]interface{}, error) {
	cmd := exec.Command("node", s.scriptPath, "--version")
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("failed to get version: %v", err)
	}

	var result map[string]interface{}
	if err := ParseScriptOutput(output, &result); err != nil {
		return nil, fmt.Errorf("failed to parse version info: %v", err)
	}

	return result, nil
}

// GetBulkDeviceMetadata processes multiple devices and returns their enhanced metadata
func (s *DeviceMetadataService) GetBulkDeviceMetadata(devices []map[string]interface{}) ([]map[string]interface{}, error) {
	var results []map[string]interface{}
	
	for _, device := range devices {
		// Extract device information
		ieeeAddress, ok := device["ieee_address"].(string)
		if !ok || ieeeAddress == "" {
			continue
		}
		
		modelID, hasModel := device["model_id"].(string)
		manufacturer, hasManufacturer := device["manufacturer"].(string)
		
		// Create base result with device information
		result := map[string]interface{}{
			"ieee_address":         ieeeAddress,
			"friendly_name":        device["friendly_name"],
			"type":                device["type"],
			"supported":           device["supported"],
			"disabled":            device["disabled"],
			"network_address":     device["network_address"],
			"power_source":        device["power_source"],
			"date_code":           device["date_code"],
			"interview_completed": device["interview_completed"],
			"interviewing":        device["interviewing"],
			"last_seen":           device["last_seen"],
			"state":               device["state"],
			"zones":               device["zones"],
			"endpoint":            device["endpoint"],
		}
		
		// Add basic device identification
		if hasModel && modelID != "" {
			result["model_id"] = modelID
		}
		if hasManufacturer && manufacturer != "" {
			result["manufacturer"] = manufacturer
		}
		
		// Try to get enhanced metadata if we have model and manufacturer
		if hasModel && hasManufacturer && modelID != "" && manufacturer != "" {
			metadata, err := s.GetDeviceMetadata(modelID, manufacturer)
			if err == nil && metadata != nil {
				result["enhanced_metadata"] = map[string]interface{}{
					"model":        metadata.Model,
					"vendor":       metadata.Vendor,
					"description":  metadata.Description,
					"supports":     metadata.Supports,
					"exposes":      metadata.Exposes,
					"options":      metadata.Options,
					"meta":         metadata.Meta,
					"ota":          metadata.OTA,
					"whiteLabel":   metadata.WhiteLabel,
				}
			} else {
				result["enhanced_metadata_error"] = err.Error()
			}
		}
		
		results = append(results, result)
	}
	
	return results, nil
}

// ClearCache clears the metadata cache
func (s *DeviceMetadataService) ClearCache() {
	s.cacheMu.Lock()
	defer s.cacheMu.Unlock()
	s.cache = make(map[string]*DeviceMetadata)
	s.cacheTime = make(map[string]time.Time)
}

// SetScriptPath allows overriding the default script path (useful for development)
func (s *DeviceMetadataService) SetScriptPath(path string) {
	s.scriptPath = filepath.Clean(path)
}