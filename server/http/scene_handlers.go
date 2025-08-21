package http

import (
	"encoding/json"
	"net/http"

	"github.com/azukaar/sumika/server/types"
)

// Services are initialized via InitServices function

// API_GetAllScenesManagement returns all scenes with management info
func API_GetAllScenesManagement(w http.ResponseWriter, r *http.Request) {
	scenes, err := sceneService.GetAllScenes()
	if err != nil {
		WriteError(w, http.StatusInternalServerError, "Failed to load scenes")
		return
	}

	WriteJSON(w, scenes)
}

// API_GetSceneByID returns a specific scene by ID
func API_GetSceneByID(w http.ResponseWriter, r *http.Request) {
	id, ok := GetRequiredPathParam(r, w, "id")
	if !ok {
		return
	}

	scene, err := sceneService.GetSceneByID(id)
	if err != nil {
		WriteError(w, http.StatusInternalServerError, "Failed to load scene")
		return
	}

	if scene == nil {
		WriteError(w, http.StatusNotFound, "Scene not found")
		return
	}

	WriteJSON(w, scene)
}

// API_CreateScene creates a new scene
func API_CreateScene(w http.ResponseWriter, r *http.Request) {
	var newScene types.LightingScene
	if err := json.NewDecoder(r.Body).Decode(&newScene); err != nil {
		WriteError(w, http.StatusBadRequest, "Invalid JSON")
		return
	}

	createdScene, err := sceneService.CreateScene(newScene)
	if err != nil {
		WriteError(w, http.StatusBadRequest, "Failed to create scene: "+err.Error())
		return
	}

	WriteJSON(w, createdScene)
}

// API_UpdateScene updates an existing scene
func API_UpdateScene(w http.ResponseWriter, r *http.Request) {
	id, ok := GetRequiredPathParam(r, w, "id")
	if !ok {
		return
	}

	var updatedScene types.LightingScene
	if err := json.NewDecoder(r.Body).Decode(&updatedScene); err != nil {
		WriteError(w, http.StatusBadRequest, "Invalid JSON")
		return
	}

	if err := sceneService.UpdateScene(id, updatedScene); err != nil {
		WriteError(w, http.StatusBadRequest, "Failed to update scene: "+err.Error())
		return
	}

	// Return the updated scene
	updated, err := sceneService.GetSceneByID(id)
	if err != nil {
		WriteError(w, http.StatusInternalServerError, "Failed to get updated scene")
		return
	}

	WriteJSON(w, updated)
}

// API_DeleteScene deletes a scene
func API_DeleteScene(w http.ResponseWriter, r *http.Request) {
	id, ok := GetRequiredPathParam(r, w, "id")
	if !ok {
		return
	}

	if err := sceneService.DeleteScene(id); err != nil {
		WriteError(w, http.StatusBadRequest, "Failed to delete scene: "+err.Error())
		return
	}

	WriteJSON(w, map[string]string{"message": "Scene deleted successfully"})
}

// API_DuplicateScene creates a copy of an existing scene
func API_DuplicateScene(w http.ResponseWriter, r *http.Request) {
	sourceID, ok := GetRequiredPathParam(r, w, "id")
	if !ok {
		return
	}

	duplicatedScene, err := sceneService.DuplicateScene(sourceID)
	if err != nil {
		WriteError(w, http.StatusInternalServerError, "Failed to duplicate scene: "+err.Error())
		return
	}

	WriteJSON(w, duplicatedScene)
}

// API_ReorderScenes updates the display order of scenes
func API_ReorderScenes(w http.ResponseWriter, r *http.Request) {
	var sceneOrders []types.SceneOrder
	if err := json.NewDecoder(r.Body).Decode(&sceneOrders); err != nil {
		WriteError(w, http.StatusBadRequest, "Invalid JSON: "+err.Error())
		return
	}

	if err := sceneService.ReorderScenes(sceneOrders); err != nil {
		WriteError(w, http.StatusBadRequest, "Failed to reorder scenes: "+err.Error())
		return
	}

	WriteJSON(w, map[string]string{"message": "Scenes reordered successfully"})
}

// API_ApplySceneInZone applies a scene to devices in a specific zone
func API_ApplySceneInZone(w http.ResponseWriter, r *http.Request) {
	sceneID, ok := GetRequiredPathParam(r, w, "id")
	if !ok {
		return
	}

	zoneName, ok := GetRequiredQueryParam(r, w, "zone")
	if !ok {
		return
	}

	if err := sceneService.ApplySceneInZone(sceneID, zoneName); err != nil {
		WriteError(w, http.StatusInternalServerError, "Failed to apply scene: "+err.Error())
		return
	}

	WriteJSON(w, map[string]string{
		"message": "Scene applied to zone " + zoneName,
	})
}

// API_TestSceneDefinitionInZone tests a scene definition in a specific zone without saving
func API_TestSceneDefinitionInZone(w http.ResponseWriter, r *http.Request) {
	zoneName, ok := GetRequiredQueryParam(r, w, "zone")
	if !ok {
		return
	}

	var sceneDefinition types.LightingScene
	if err := json.NewDecoder(r.Body).Decode(&sceneDefinition); err != nil {
		WriteError(w, http.StatusBadRequest, "Invalid scene definition: "+err.Error())
		return
	}

	if err := sceneService.TestSceneDefinitionInZone(sceneDefinition, zoneName); err != nil {
		WriteError(w, http.StatusInternalServerError, "Failed to test scene: "+err.Error())
		return
	}

	WriteJSON(w, map[string]string{
		"message": "Scene definition tested in zone " + zoneName,
	})
}

