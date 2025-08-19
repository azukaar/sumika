package manage

import (
	"net/http"

	httputil "github.com/azukaar/sumika/server/http"
)

// Scene API endpoints (legacy)

func API_GetAllScenes(w http.ResponseWriter, r *http.Request) {
	sceneService := NewSceneService()
	scenes := sceneService.GetAllScenes()
	httputil.WriteJSON(w, scenes)
}

func API_GetFeaturedScenes(w http.ResponseWriter, r *http.Request) {
	sceneService := NewSceneService()
	scenes := sceneService.GetFeaturedScenes()
	httputil.WriteJSON(w, scenes)
}

func API_GetSceneByName(w http.ResponseWriter, r *http.Request) {
	sceneName, ok := httputil.GetRequiredPathParam(r, w, "name")
	if !ok {
		return
	}

	sceneService := NewSceneService()
	scene := sceneService.GetSceneByName(sceneName)

	if scene == nil {
		httputil.WriteNotFound(w, "Scene")
		return
	}

	httputil.WriteJSON(w, scene)
}