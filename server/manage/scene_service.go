package manage

// SceneService provides the predefined lighting scenes
type SceneService struct{}

// NewSceneService creates a new scene service
func NewSceneService() *SceneService {
	return &SceneService{}
}

// GetAllScenes returns all available lighting scenes
func (s *SceneService) GetAllScenes() []LightingScene {
	manager := GetSceneManager()
	return manager.GetAllScenes()
}

// GetFeaturedScenes returns the first 5 scenes for the supercard
func (s *SceneService) GetFeaturedScenes() []LightingScene {
	scenes := s.GetAllScenes()
	if len(scenes) > 5 {
		return scenes[:5]
	}
	return scenes
}

// GetSceneByName returns a specific scene by name
func (s *SceneService) GetSceneByName(name string) *LightingScene {
	manager := GetSceneManager()
	return manager.GetSceneByName(name)
}