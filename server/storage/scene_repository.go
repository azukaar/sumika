package storage

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"

	"github.com/azukaar/sumika/server/types"
)

type SceneRepository interface {
	GetAll() ([]types.LightingScene, error)
	GetByID(id string) (*types.LightingScene, error)
	GetByName(name string) (*types.LightingScene, error)
	Create(scene types.LightingScene) (*types.LightingScene, error)
	Update(id string, scene types.LightingScene) error
	Delete(id string) error
	Reorder(orders []types.SceneOrder) error
	SaveImage(filename string, data []byte) (string, error)
}

type JSONSceneRepository struct {
	dataFile  string
	assetsDir string
}

func NewJSONSceneRepository(dataFile, assetsDir string) SceneRepository {
	return &JSONSceneRepository{
		dataFile:  dataFile,
		assetsDir: assetsDir,
	}
}

func (r *JSONSceneRepository) GetAll() ([]types.LightingScene, error) {
	var scenes []types.LightingScene
	
	data, err := os.ReadFile(r.dataFile)
	if err != nil {
		if os.IsNotExist(err) {
			// Return default scenes if file doesn't exist
			return r.getDefaultScenes(), nil
		}
		return nil, err
	}

	if err := json.Unmarshal(data, &scenes); err != nil {
		// Return default scenes if JSON is invalid
		return r.getDefaultScenes(), nil
	}

	// Sort by order
	for i := 0; i < len(scenes); i++ {
		for j := i + 1; j < len(scenes); j++ {
			if scenes[i].Order > scenes[j].Order {
				scenes[i], scenes[j] = scenes[j], scenes[i]
			}
		}
	}

	return scenes, nil
}

func (r *JSONSceneRepository) GetByID(id string) (*types.LightingScene, error) {
	scenes, err := r.GetAll()
	if err != nil {
		return nil, err
	}

	for i := range scenes {
		if scenes[i].ID == id {
			return &scenes[i], nil
		}
	}
	return nil, nil
}

func (r *JSONSceneRepository) GetByName(name string) (*types.LightingScene, error) {
	scenes, err := r.GetAll()
	if err != nil {
		return nil, err
	}

	for i := range scenes {
		if scenes[i].Name == name {
			return &scenes[i], nil
		}
	}
	return nil, nil
}

func (r *JSONSceneRepository) Create(scene types.LightingScene) (*types.LightingScene, error) {
	scenes, err := r.GetAll()
	if err != nil {
		return nil, err
	}

	// Check for duplicate ID
	for _, existing := range scenes {
		if existing.ID == scene.ID {
			return nil, errors.New("scene with ID already exists")
		}
	}

	scenes = append(scenes, scene)
	
	if err := r.saveScenes(scenes); err != nil {
		return nil, err
	}

	return &scene, nil
}

func (r *JSONSceneRepository) Update(id string, scene types.LightingScene) error {
	scenes, err := r.GetAll()
	if err != nil {
		return err
	}

	for i := range scenes {
		if scenes[i].ID == id {
			// Preserve the original ID
			scene.ID = id
			scenes[i] = scene
			return r.saveScenes(scenes)
		}
	}

	return errors.New("scene not found")
}

func (r *JSONSceneRepository) Delete(id string) error {
	scenes, err := r.GetAll()
	if err != nil {
		return err
	}

	for i, scene := range scenes {
		if scene.ID == id {
			// Remove image file if it exists
			if scene.ImagePath != "" {
				os.Remove(filepath.Join(r.assetsDir, scene.ImagePath))
			}
			
			// Remove from slice
			scenes = append(scenes[:i], scenes[i+1:]...)
			return r.saveScenes(scenes)
		}
	}

	return errors.New("scene not found")
}

func (r *JSONSceneRepository) Reorder(orders []types.SceneOrder) error {
	scenes, err := r.GetAll()
	if err != nil {
		return err
	}

	// Update orders
	for _, order := range orders {
		for i := range scenes {
			if scenes[i].ID == order.ID {
				scenes[i].Order = order.Order
				break
			}
		}
	}

	return r.saveScenes(scenes)
}

func (r *JSONSceneRepository) SaveImage(filename string, data []byte) (string, error) {
	// Create assets directory if it doesn't exist
	if err := os.MkdirAll(r.assetsDir, 0755); err != nil {
		return "", err
	}

	filepath := filepath.Join(r.assetsDir, filename)
	if err := os.WriteFile(filepath, data, 0644); err != nil {
		return "", err
	}

	return filename, nil
}

func (r *JSONSceneRepository) saveScenes(scenes []types.LightingScene) error {
	// Create directory if it doesn't exist
	if err := os.MkdirAll(filepath.Dir(r.dataFile), 0755); err != nil {
		return err
	}

	data, err := json.MarshalIndent(scenes, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(r.dataFile, data, 0644)
}

func (r *JSONSceneRepository) getDefaultScenes() []types.LightingScene {
	return []types.LightingScene{
		{
			ID:    "relax",
			Name:  "Relax",
			Order: 0,
			Lights: []types.SceneLight{
				{Hue: 30, Saturation: 0.7, Brightness: 150},
				{Hue: 35, Saturation: 0.6, Brightness: 120},
			},
			IsCustom: false,
		},
		{
			ID:    "focus",
			Name:  "Focus",
			Order: 1,
			Lights: []types.SceneLight{
				{Hue: 200, Saturation: 0.3, Brightness: 220},
				{Hue: 210, Saturation: 0.2, Brightness: 200},
			},
			IsCustom: false,
		},
		{
			ID:    "party",
			Name:  "Party",
			Order: 2,
			Lights: []types.SceneLight{
				{Hue: 300, Saturation: 1.0, Brightness: 254},
				{Hue: 240, Saturation: 0.9, Brightness: 230},
				{Hue: 120, Saturation: 0.8, Brightness: 200},
			},
			IsCustom: false,
		},
		{
			ID:    "romantic",
			Name:  "Romantic",
			Order: 3,
			Lights: []types.SceneLight{
				{Hue: 0, Saturation: 0.8, Brightness: 80},
				{Hue: 10, Saturation: 0.7, Brightness: 60},
			},
			IsCustom: false,
		},
		{
			ID:    "energize",
			Name:  "Energize",
			Order: 4,
			Lights: []types.SceneLight{
				{Hue: 180, Saturation: 0.5, Brightness: 254},
				{Hue: 190, Saturation: 0.6, Brightness: 240},
			},
			IsCustom: false,
		},
	}
}