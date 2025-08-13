package manage

import (
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"os"
	"path/filepath"
	"strings"
	"time"
)

type SceneManager struct {
	scenes     []LightingScene
	dataFile   string
	assetsDir  string
}

func NewSceneManager() *SceneManager {
	manager := &SceneManager{
		dataFile:  "./build-data/scenes_data.json",
		assetsDir: "./assets/scenes",
	}
	manager.loadScenes()
	return manager
}

// loadScenes loads scenes from file, falling back to default scenes if file doesn't exist
func (sm *SceneManager) loadScenes() {
	// Try to load from file first
	if data, err := os.ReadFile(sm.dataFile); err == nil {
		var loadedScenes []LightingScene
		if json.Unmarshal(data, &loadedScenes) == nil && len(loadedScenes) > 0 {
			sm.scenes = loadedScenes
			return
		}
	}

	// Fall back to default scenes
	sm.scenes = sm.getDefaultScenes()
	sm.saveScenes() // Save defaults to file
}

func (sm *SceneManager) getDefaultScenes() []LightingScene {
	return []LightingScene{
		{
			ID:       "relax",
			Name:     "Relax", 
			Order:    0,
			IsCustom: false,
			Lights: []SceneLight{
				{Hue: 30, Saturation: 0.8, Brightness: 100},
			},
		},
		{
			ID:       "focus",
			Name:     "Focus",
			Order:    1,
			IsCustom: false,
			Lights: []SceneLight{
				{Hue: 200, Saturation: 0.3, Brightness: 180},
			},
		},
		{
			ID:       "sunset",
			Name:     "Sunset",
			Order:    2,
			IsCustom: false,
			Lights: []SceneLight{
				{Hue: 15, Saturation: 0.9, Brightness: 150},
				{Hue: 35, Saturation: 0.7, Brightness: 120},
				{Hue: 350, Saturation: 0.6, Brightness: 100},
			},
		},
		{
			ID:       "supernova",
			Name:     "Supernova",
			Order:    3,
			IsCustom: false,
			Lights: []SceneLight{
				{Hue: 280, Saturation: 0.8, Brightness: 254},
				{Hue: 0, Saturation: 0.0, Brightness: 254},
				{Hue: 200, Saturation: 0.5, Brightness: 200},
			},
		},
		{
			ID:       "party_in_tokyo",
			Name:     "Party in Tokyo",
			Order:    4,
			IsCustom: false,
			Lights: []SceneLight{
				{Hue: 240, Saturation: 0.9, Brightness: 200},
				{Hue: 260, Saturation: 0.7, Brightness: 180},
				{Hue: 200, Saturation: 0.8, Brightness: 190},
				{Hue: 15, Saturation: 0.8, Brightness: 160},
				{Hue: 50, Saturation: 0.9, Brightness: 170},
			},
		},
		{
			ID:       "romance",
			Name:     "Romance",
			Order:    5,
			IsCustom: false,
			Lights: []SceneLight{
				{Hue: 340, Saturation: 0.6, Brightness: 80},
				{Hue: 10, Saturation: 0.5, Brightness: 70},
			},
		},
		{
			ID:       "ocean",
			Name:     "Ocean",
			Order:    6,
			IsCustom: false,
			Lights: []SceneLight{
				{Hue: 180, Saturation: 0.8, Brightness: 120},
				{Hue: 200, Saturation: 0.7, Brightness: 140},
				{Hue: 220, Saturation: 0.6, Brightness: 100},
			},
		},
		{
			ID:       "forest",
			Name:     "Forest",
			Order:    7,
			IsCustom: false,
			Lights: []SceneLight{
				{Hue: 120, Saturation: 0.7, Brightness: 130},
				{Hue: 140, Saturation: 0.6, Brightness: 110},
				{Hue: 100, Saturation: 0.5, Brightness: 90},
			},
		},
		{
			ID:       "aurora",
			Name:     "Aurora",
			Order:    8,
			IsCustom: false,
			Lights: []SceneLight{
				{Hue: 280, Saturation: 0.7, Brightness: 150},
				{Hue: 140, Saturation: 0.8, Brightness: 130},
				{Hue: 200, Saturation: 0.6, Brightness: 120},
				{Hue: 320, Saturation: 0.5, Brightness: 100},
			},
		},
		{
			ID:       "energy",
			Name:     "Energy",
			Order:    9,
			IsCustom: false,
			Lights: []SceneLight{
				{Hue: 60, Saturation: 1.0, Brightness: 220},
				{Hue: 120, Saturation: 0.9, Brightness: 200},
				{Hue: 300, Saturation: 0.8, Brightness: 210},
				{Hue: 180, Saturation: 0.9, Brightness: 190},
			},
		},
	}
}

// saveScenes saves scenes to persistent storage
func (sm *SceneManager) saveScenes() error {
	// Ensure directory exists
	if err := os.MkdirAll(filepath.Dir(sm.dataFile), 0755); err != nil {
		return err
	}

	data, err := json.MarshalIndent(sm.scenes, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(sm.dataFile, data, 0644)
}

// GetAllScenes returns all scenes sorted by order
func (sm *SceneManager) GetAllScenes() []LightingScene {
	// Sort by order
	sortedScenes := make([]LightingScene, len(sm.scenes))
	copy(sortedScenes, sm.scenes)
	
	for i := 0; i < len(sortedScenes); i++ {
		for j := i + 1; j < len(sortedScenes); j++ {
			if sortedScenes[i].Order > sortedScenes[j].Order {
				sortedScenes[i], sortedScenes[j] = sortedScenes[j], sortedScenes[i]
			}
		}
	}
	
	return sortedScenes
}

// GetSceneByID returns a scene by its ID
func (sm *SceneManager) GetSceneByID(id string) *LightingScene {
	for i := range sm.scenes {
		if sm.scenes[i].ID == id {
			return &sm.scenes[i]
		}
	}
	return nil
}

// GetSceneByName returns a scene by its name (for backward compatibility)
func (sm *SceneManager) GetSceneByName(name string) *LightingScene {
	for i := range sm.scenes {
		if sm.scenes[i].Name == name {
			return &sm.scenes[i]
		}
	}
	return nil
}

// CreateScene creates a new custom scene
func (sm *SceneManager) CreateScene(scene LightingScene) (*LightingScene, error) {
	// Generate ID from name if not provided
	if scene.ID == "" {
		scene.ID = strings.ToLower(strings.ReplaceAll(scene.Name, " ", "_"))
	}

	// Check for duplicate ID
	if sm.GetSceneByID(scene.ID) != nil {
		return nil, fmt.Errorf("scene with ID %s already exists", scene.ID)
	}

	// Set metadata
	scene.IsCustom = true
	scene.CreatedAt = time.Now().Format(time.RFC3339)
	scene.UpdatedAt = time.Now().Format(time.RFC3339)
	
	// Set order to end
	if scene.Order == 0 {
		scene.Order = len(sm.scenes)
	}

	sm.scenes = append(sm.scenes, scene)
	if err := sm.saveScenes(); err != nil {
		return nil, err
	}
	
	return &scene, nil
}

// UpdateScene updates an existing scene
func (sm *SceneManager) UpdateScene(id string, updates LightingScene) error {
	for i := range sm.scenes {
		if sm.scenes[i].ID == id {
			// Preserve certain fields
			updates.ID = sm.scenes[i].ID
			updates.IsCustom = sm.scenes[i].IsCustom
			updates.CreatedAt = sm.scenes[i].CreatedAt
			updates.UpdatedAt = time.Now().Format(time.RFC3339)
			
			// Keep original order if not specified
			if updates.Order == 0 {
				updates.Order = sm.scenes[i].Order
			}

			sm.scenes[i] = updates
			return sm.saveScenes()
		}
	}
	return fmt.Errorf("scene with ID %s not found", id)
}

// DeleteScene deletes a scene
func (sm *SceneManager) DeleteScene(id string) error {
	for i, scene := range sm.scenes {
		if scene.ID == id {
			// Don't allow deletion of default scenes
			if !scene.IsCustom {
				return fmt.Errorf("cannot delete default scene")
			}

			// Remove associated image file if it exists
			if scene.ImagePath != "" {
				imagePath := filepath.Join(sm.assetsDir, scene.ImagePath)
				os.Remove(imagePath) // Ignore errors
			}

			// Remove from slice
			sm.scenes = append(sm.scenes[:i], sm.scenes[i+1:]...)
			return sm.saveScenes()
		}
	}
	return fmt.Errorf("scene with ID %s not found", id)
}

// ReorderScenes updates the order of scenes
func (sm *SceneManager) ReorderScenes(sceneOrders []struct {
	ID    string `json:"id"`
	Order int    `json:"order"`
}) error {
	// Update orders
	for _, orderUpdate := range sceneOrders {
		for i := range sm.scenes {
			if sm.scenes[i].ID == orderUpdate.ID {
				sm.scenes[i].Order = orderUpdate.Order
				break
			}
		}
	}
	
	return sm.saveScenes()
}

// UploadSceneImage handles image upload for a scene
func (sm *SceneManager) UploadSceneImage(sceneID string, file multipart.File, filename string) error {
	scene := sm.GetSceneByID(sceneID)
	if scene == nil {
		return fmt.Errorf("scene with ID %s not found", sceneID)
	}

	// Ensure assets directory exists
	if err := os.MkdirAll(sm.assetsDir, 0755); err != nil {
		return err
	}

	// Generate unique filename
	ext := filepath.Ext(filename)
	newFilename := fmt.Sprintf("%s_%d%s", sceneID, time.Now().Unix(), ext)
	imagePath := filepath.Join(sm.assetsDir, newFilename)

	// Create destination file
	dst, err := os.Create(imagePath)
	if err != nil {
		return err
	}
	defer dst.Close()

	// Copy file data
	if _, err := io.Copy(dst, file); err != nil {
		return err
	}

	// Remove old image if it exists
	if scene.ImagePath != "" {
		oldPath := filepath.Join(sm.assetsDir, scene.ImagePath)
		os.Remove(oldPath) // Ignore errors
	}

	// Update scene with new image path
	return sm.UpdateScene(sceneID, LightingScene{
		ID:        scene.ID,
		Name:      scene.Name,
		Lights:    scene.Lights,
		ImagePath: newFilename,
		Order:     scene.Order,
		IsCustom:  scene.IsCustom,
		CreatedAt: scene.CreatedAt,
	})
}

// TestSceneInZone applies a scene to devices in a specific zone for testing
func (sm *SceneManager) TestSceneInZone(sceneID string, zoneName string) error {
	scene := sm.GetSceneByID(sceneID)
	if scene == nil {
		return fmt.Errorf("scene with ID %s not found", sceneID)
	}

	// Get all light devices in the zone (reuse working logic)
	lightDevices := GetDevicesByZoneAndCategory(zoneName, "light")
	
	if len(lightDevices) == 0 {
		return fmt.Errorf("no light devices found in zone '%s'", zoneName)
	}
	
	if len(scene.Lights) == 0 {
		return fmt.Errorf("scene has no colors defined")
	}

	// Apply scene to each light device (using same logic as ExecuteSceneBasedAction)
	for i, deviceName := range lightDevices {
		// Get the scene light configuration (loop through colors if more lights than colors)
		lightIndex := i % len(scene.Lights)
		sceneLight := scene.Lights[lightIndex]
		
		// Build command JSON for Zigbee2MQTT (same format as working code)
		command := map[string]interface{}{
			"state":      "ON",
			"brightness": int(sceneLight.Brightness),
			"color": map[string]interface{}{
				"hue":        int(sceneLight.Hue),
				"saturation": int(sceneLight.Saturation * 100), // Convert to 0-100 for Zigbee
			},
			"transition": 0.5, // Smooth transition
		}
		
		// Send command to device
		if SendDeviceCommand != nil {
			commandJSON, _ := json.Marshal(command)
			SendDeviceCommand(deviceName, string(commandJSON))
		}
	}

	return nil
}

// Global scene manager instance
var sceneManager *SceneManager

// GetSceneManager returns the global scene manager instance
func GetSceneManager() *SceneManager {
	if sceneManager == nil {
		sceneManager = NewSceneManager()
	}
	return sceneManager
}