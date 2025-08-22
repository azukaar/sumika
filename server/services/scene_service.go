package services

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"mime/multipart"
	"strconv"
	"strings"
	"time"

	"github.com/azukaar/sumika/server/config"
	"github.com/azukaar/sumika/server/storage"
	"github.com/azukaar/sumika/server/types"
	"github.com/azukaar/sumika/server/zigbee2mqtt"
)

type SceneService struct {
	repository storage.SceneRepository
}

func NewSceneService() *SceneService {
	// Use existing scene repository  
	repository := storage.NewJSONSceneRepository(config.GetDataPath("scenes_data.json"), "./assets/scenes")
	return &SceneService{
		repository: repository,
	}
}

// GetAllScenes returns all scenes sorted by order
func (s *SceneService) GetAllScenes() ([]types.LightingScene, error) {
	return s.repository.GetAll()
}

// GetFeaturedScenes returns the first 5 scenes
func (s *SceneService) GetFeaturedScenes() ([]types.LightingScene, error) {
	scenes, err := s.repository.GetAll()
	if err != nil {
		return nil, err
	}

	if len(scenes) > 5 {
		return scenes[:5], nil
	}
	return scenes, nil
}

// GetSceneByID returns a scene by its ID
func (s *SceneService) GetSceneByID(id string) (*types.LightingScene, error) {
	if id == "" {
		return nil, errors.New("scene ID cannot be empty")
	}
	return s.repository.GetByID(id)
}

// GetSceneByName returns a scene by its name (for backward compatibility)
func (s *SceneService) GetSceneByName(name string) (*types.LightingScene, error) {
	if name == "" {
		return nil, errors.New("scene name cannot be empty")
	}
	return s.repository.GetByName(name)
}

// CreateScene creates a new scene with validation
func (s *SceneService) CreateScene(scene types.LightingScene) (*types.LightingScene, error) {
	// Validation
	if err := s.validateScene(scene); err != nil {
		return nil, fmt.Errorf("validation failed: %w", err)
	}

	// Generate ID if not provided
	if scene.ID == "" {
		scene.ID = s.generateSceneID(scene.Name)
	}

	// Set timestamps
	now := time.Now().Format(time.RFC3339)
	scene.CreatedAt = now
	scene.UpdatedAt = now
	scene.IsCustom = true

	// Set order to highest + 1 if not specified
	if scene.Order == 0 {
		scenes, err := s.repository.GetAll()
		if err != nil {
			return nil, fmt.Errorf("failed to get scenes for ordering: %w", err)
		}

		maxOrder := 0
		for _, existing := range scenes {
			if existing.Order > maxOrder {
				maxOrder = existing.Order
			}
		}
		scene.Order = maxOrder + 1
	}

	return s.repository.Create(scene)
}

// UpdateScene updates an existing scene
func (s *SceneService) UpdateScene(id string, scene types.LightingScene) error {
	if id == "" {
		return errors.New("scene ID cannot be empty")
	}

	// Validation
	if err := s.validateScene(scene); err != nil {
		return fmt.Errorf("validation failed: %w", err)
	}

	// Check if scene exists
	existing, err := s.repository.GetByID(id)
	if err != nil {
		return fmt.Errorf("failed to check existing scene: %w", err)
	}
	if existing == nil {
		return errors.New("scene not found")
	}

	// Preserve creation timestamp, update modification timestamp
	scene.CreatedAt = existing.CreatedAt
	scene.UpdatedAt = time.Now().Format(time.RFC3339)

	return s.repository.Update(id, scene)
}

// DeleteScene removes a scene
func (s *SceneService) DeleteScene(id string) error {
	if id == "" {
		return errors.New("scene ID cannot be empty")
	}

	// Check if scene exists
	existing, err := s.repository.GetByID(id)
	if err != nil {
		return fmt.Errorf("failed to check existing scene: %w", err)
	}
	if existing == nil {
		return errors.New("scene not found")
	}

	return s.repository.Delete(id)
}

// DuplicateScene creates a copy of an existing scene
func (s *SceneService) DuplicateScene(sourceID string) (*types.LightingScene, error) {
	if sourceID == "" {
		return nil, errors.New("source scene ID cannot be empty")
	}

	sourceScene, err := s.repository.GetByID(sourceID)
	if err != nil {
		return nil, fmt.Errorf("failed to get source scene: %w", err)
	}
	if sourceScene == nil {
		return nil, errors.New("source scene not found")
	}

	// Create a copy
	newScene := *sourceScene
	newScene.ID = sourceScene.ID + "_copy_" + strconv.FormatInt(time.Now().Unix(), 10)
	newScene.Name = sourceScene.Name + " Copy"
	newScene.IsCustom = true
	newScene.ImagePath = "" // Don't copy image, let user upload new one
	newScene.CreatedAt = ""
	newScene.UpdatedAt = ""

	return s.CreateScene(newScene)
}

// ReorderScenes updates the display order of scenes
func (s *SceneService) ReorderScenes(orders []types.SceneOrder) error {
	// Validation
	if len(orders) == 0 {
		return errors.New("scene orders cannot be empty")
	}

	for _, order := range orders {
		if order.ID == "" {
			return errors.New("scene ID cannot be empty")
		}
		if order.Order < 0 {
			return errors.New("scene order cannot be negative")
		}
	}

	return s.repository.Reorder(orders)
}

// ApplySceneInZone applies a scene to devices in a specific zone (migrated from client logic)
func (s *SceneService) ApplySceneInZone(sceneID, zoneName string) error {
	if sceneID == "" {
		return errors.New("scene ID cannot be empty")
	}
	if zoneName == "" {
		return errors.New("zone name cannot be empty")
	}

	scene, err := s.repository.GetByID(sceneID)
	if err != nil {
		return fmt.Errorf("failed to get scene: %w", err)
	}
	if scene == nil {
		return errors.New("scene not found")
	}

	// Get devices in the zone
	zoneDevices := storage.GetDevicesByZone(zoneName)
	if len(zoneDevices) == 0 {
		return fmt.Errorf("no devices found in zone '%s'", zoneName)
	}

	// Filter for light devices only (devices that have brightness or color capabilities)
	var lightDevices []string
	for _, deviceName := range zoneDevices {
		deviceProperties := zigbee2mqtt.GetDeviceProperties(deviceName)
		isLight := false
		for _, prop := range deviceProperties {
			if prop == "brightness" || prop == "color" || prop == "color_temp" {
				isLight = true
				break
			}
		}
		if isLight {
			lightDevices = append(lightDevices, deviceName)
		}
	}

	if len(lightDevices) == 0 {
		return fmt.Errorf("no light devices found in zone '%s'", zoneName)
	}

	fmt.Printf("Applying scene %s to %d light devices in zone %s\n", scene.Name, len(lightDevices), zoneName)

	// Apply scene colors to lights, looping if more lights than colors (migrated from client)
	appliedCount := 0
	for i, deviceName := range lightDevices {
		sceneLight := scene.Lights[i%len(scene.Lights)] // Loop through colors

		// Build state update based on client logic
		jsonState := map[string]interface{}{
			"state":      "ON", // Ensure light is on
			"brightness": sceneLight.Brightness,
			"color": map[string]interface{}{
				"hue":        sceneLight.Hue,
				"saturation": sceneLight.Saturation * 100, // Convert to 0-100 for Zigbee
			},
			"transition": 0.5, // Add transition for smooth color change
		}

		// Convert to JSON for MQTT
		stateJSON, err := json.Marshal(jsonState)
		if err != nil {
			fmt.Printf("Failed to marshal device state for %s: %v\n", deviceName, err)
			continue
		}

		// Apply to device using existing zigbee2mqtt function
		zigbee2mqtt.SetDeviceState(deviceName, string(stateJSON))
		appliedCount++
		fmt.Printf("Applied scene %s to device %s in zone %s\n", scene.Name, deviceName, zoneName)
	}

	if appliedCount == 0 {
		return fmt.Errorf("failed to apply scene to any devices in zone '%s'", zoneName)
	}

	fmt.Printf("Successfully applied scene %s to %d devices in zone %s\n", scene.Name, appliedCount, zoneName)
	return nil
}

// TestSceneDefinitionInZone tests a scene definition in a zone without saving it
func (s *SceneService) TestSceneDefinitionInZone(sceneDefinition types.LightingScene, zoneName string) error {
	if zoneName == "" {
		return errors.New("zone name cannot be empty")
	}

	// Validate the scene definition
	if err := s.validateScene(sceneDefinition); err != nil {
		return fmt.Errorf("invalid scene definition: %w", err)
	}

	// Get devices in the zone
	zoneDevices := storage.GetDevicesByZone(zoneName)
	if len(zoneDevices) == 0 {
		return fmt.Errorf("no devices found in zone '%s'", zoneName)
	}

	// Filter for light devices only (devices that have brightness or color capabilities)
	var lightDevices []string
	for _, deviceName := range zoneDevices {
		deviceProperties := zigbee2mqtt.GetDeviceProperties(deviceName)
		isLight := false
		for _, prop := range deviceProperties {
			if prop == "brightness" || prop == "color" || prop == "color_temp" {
				isLight = true
				break
			}
		}
		if isLight {
			lightDevices = append(lightDevices, deviceName)
		}
	}

	if len(lightDevices) == 0 {
		return fmt.Errorf("no light devices found in zone '%s'", zoneName)
	}

	fmt.Printf("Testing scene definition '%s' on %d light devices in zone %s\n", sceneDefinition.Name, len(lightDevices), zoneName)

	// Apply scene colors to lights, looping if more lights than colors
	appliedCount := 0
	for i, deviceName := range lightDevices {
		sceneLight := sceneDefinition.Lights[i%len(sceneDefinition.Lights)] // Loop through colors

		// Build state update based on client logic
		jsonState := map[string]interface{}{
			"state":      "ON", // Ensure light is on
			"brightness": sceneLight.Brightness,
			"color": map[string]interface{}{
				"hue":        sceneLight.Hue,
				"saturation": sceneLight.Saturation * 100, // Convert to 0-100 for Zigbee
			},
			"transition": 0.5, // Add transition for smooth color change
		}

		// Convert to JSON for MQTT
		stateJSON, err := json.Marshal(jsonState)
		if err != nil {
			fmt.Printf("Failed to marshal device state for %s: %v\n", deviceName, err)
			continue
		}

		// Apply to device using existing zigbee2mqtt function
		zigbee2mqtt.SetDeviceState(deviceName, string(stateJSON))
		appliedCount++
		fmt.Printf("Applied scene definition to device %s in zone %s\n", deviceName, zoneName)
	}

	if appliedCount == 0 {
		return fmt.Errorf("failed to apply scene definition to any devices in zone '%s'", zoneName)
	}

	fmt.Printf("Successfully tested scene definition '%s' on %d devices in zone %s\n", sceneDefinition.Name, appliedCount, zoneName)
	return nil
}



// UploadSceneImage handles scene image upload
func (s *SceneService) UploadSceneImage(sceneID string, file multipart.File, header *multipart.FileHeader) (string, error) {
	if sceneID == "" {
		return "", errors.New("scene ID cannot be empty")
	}

	// Validate file type
	contentType := header.Header.Get("Content-Type")
	if !strings.HasPrefix(contentType, "image/") {
		return "", errors.New("file must be an image")
	}

	// Read file data
	data, err := io.ReadAll(file)
	if err != nil {
		return "", fmt.Errorf("failed to read file: %w", err)
	}

	// Generate filename
	filename := fmt.Sprintf("scene_%s_%d_%s", sceneID, time.Now().Unix(), header.Filename)

	// Save to repository
	savedPath, err := s.repository.SaveImage(filename, data)
	if err != nil {
		return "", fmt.Errorf("failed to save image: %w", err)
	}

	return savedPath, nil
}

// Validation helpers
func (s *SceneService) validateScene(scene types.LightingScene) error {
	if scene.Name == "" {
		return errors.New("scene name cannot be empty")
	}

	if len(scene.Name) > 50 {
		return errors.New("scene name cannot exceed 50 characters")
	}

	if len(scene.Lights) == 0 {
		return errors.New("scene must have at least one light")
	}

	for i, light := range scene.Lights {
		if err := s.validateSceneLight(light); err != nil {
			return fmt.Errorf("light %d validation failed: %w", i, err)
		}
	}

	return nil
}

func (s *SceneService) validateSceneLight(light types.SceneLight) error {
	if light.Hue < 0 || light.Hue > 360 {
		return errors.New("hue must be between 0 and 360")
	}

	if light.Saturation < 0 || light.Saturation > 1 {
		return errors.New("saturation must be between 0 and 1")
	}

	if light.Brightness < 0 || light.Brightness > 254 {
		return errors.New("brightness must be between 0 and 254")
	}

	return nil
}

func (s *SceneService) generateSceneID(name string) string {
	// Simple ID generation from name + timestamp
	cleanName := strings.ToLower(strings.ReplaceAll(name, " ", "_"))
	return fmt.Sprintf("%s_%d", cleanName, time.Now().Unix())
}