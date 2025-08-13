package manage

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"time"

	"github.com/gorilla/mux"
)

// API_GetAllScenesManagement returns all scenes with management info
func API_GetAllScenesManagement(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	
	sceneManager := GetSceneManager()
	scenes := sceneManager.GetAllScenes()
	
	if err := json.NewEncoder(w).Encode(scenes); err != nil {
		http.Error(w, "Failed to encode scenes", http.StatusInternalServerError)
		return
	}
}

// API_GetSceneByID returns a specific scene by ID
func API_GetSceneByID(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	
	vars := mux.Vars(r)
	sceneID := vars["id"]
	
	sceneManager := GetSceneManager()
	scene := sceneManager.GetSceneByID(sceneID)
	
	if scene == nil {
		http.Error(w, "Scene not found", http.StatusNotFound)
		return
	}
	
	if err := json.NewEncoder(w).Encode(scene); err != nil {
		http.Error(w, "Failed to encode scene", http.StatusInternalServerError)
		return
	}
}

// API_CreateScene creates a new scene
func API_CreateScene(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	
	var newScene LightingScene
	if err := json.NewDecoder(r.Body).Decode(&newScene); err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}
	
	fmt.Printf("Creating scene with data: %+v\n", newScene)
	
	sceneManager := GetSceneManager()
	createdScene, err := sceneManager.CreateScene(newScene)
	if err != nil {
		fmt.Printf("CreateScene error: %v\n", err)
		http.Error(w, "Failed to create scene: "+err.Error(), http.StatusBadRequest)
		return
	}
	
	fmt.Printf("Created scene: %+v\n", createdScene)
	
	// Return the created scene
	if createdScene == nil {
		fmt.Printf("Created scene is nil!\n")
		http.Error(w, "Failed to create scene: returned nil", http.StatusInternalServerError)
		return
	}
	
	if err := json.NewEncoder(w).Encode(*createdScene); err != nil {
		fmt.Printf("JSON encode error: %v\n", err)
		http.Error(w, "Failed to encode scene", http.StatusInternalServerError)
		return
	}
	
	fmt.Printf("Scene creation completed successfully\n")
}

// API_UpdateScene updates an existing scene
func API_UpdateScene(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	
	vars := mux.Vars(r)
	sceneID := vars["id"]
	
	var updatedScene LightingScene
	if err := json.NewDecoder(r.Body).Decode(&updatedScene); err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}
	
	sceneManager := GetSceneManager()
	if err := sceneManager.UpdateScene(sceneID, updatedScene); err != nil {
		http.Error(w, "Failed to update scene: "+err.Error(), http.StatusBadRequest)
		return
	}
	
	// Return the updated scene
	updated := sceneManager.GetSceneByID(sceneID)
	if err := json.NewEncoder(w).Encode(updated); err != nil {
		http.Error(w, "Failed to encode scene", http.StatusInternalServerError)
		return
	}
}

// API_DeleteScene deletes a scene
func API_DeleteScene(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	
	vars := mux.Vars(r)
	sceneID := vars["id"]
	
	sceneManager := GetSceneManager()
	if err := sceneManager.DeleteScene(sceneID); err != nil {
		http.Error(w, "Failed to delete scene: "+err.Error(), http.StatusBadRequest)
		return
	}
	
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"message": "Scene deleted successfully"})
}

// API_ReorderScenes updates the display order of scenes
func API_ReorderScenes(w http.ResponseWriter, r *http.Request) {
	fmt.Printf("ReorderScenes: Received %s request to %s\n", r.Method, r.URL.Path)
	fmt.Printf("ReorderScenes: Content-Type: %s\n", r.Header.Get("Content-Type"))
	
	// Read the raw body for debugging
	bodyBytes, err := io.ReadAll(r.Body)
	if err != nil {
		fmt.Printf("ReorderScenes: Error reading body: %v\n", err)
		http.Error(w, "Error reading request body", http.StatusBadRequest)
		return
	}
	fmt.Printf("ReorderScenes: Raw body: %s\n", string(bodyBytes))
	
	w.Header().Set("Content-Type", "application/json")
	
	var sceneOrders []struct {
		ID    string `json:"id"`
		Order int    `json:"order"`
	}
	
	// Parse the body we just read
	if err := json.Unmarshal(bodyBytes, &sceneOrders); err != nil {
		fmt.Printf("ReorderScenes: JSON decode error: %v\n", err)
		http.Error(w, "Invalid JSON: "+err.Error(), http.StatusBadRequest)
		return
	}
	
	fmt.Printf("ReorderScenes: Successfully parsed %d scene orders\n", len(sceneOrders))
	
	// Validate the data
	for _, order := range sceneOrders {
		if order.ID == "" {
			http.Error(w, "Scene ID cannot be empty", http.StatusBadRequest)
			return
		}
		if order.Order < 0 {
			http.Error(w, "Scene order cannot be negative", http.StatusBadRequest)
			return
		}
	}
	
	sceneManager := GetSceneManager()
	if err := sceneManager.ReorderScenes(sceneOrders); err != nil {
		http.Error(w, "Failed to reorder scenes: "+err.Error(), http.StatusBadRequest)
		return
	}
	
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"message": "Scenes reordered successfully"})
}


// API_TestSceneInZone tests a scene in a specific zone
func API_TestSceneInZone(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	
	vars := mux.Vars(r)
	sceneID := vars["id"]
	
	// Get zone from query parameter
	zoneName := r.URL.Query().Get("zone")
	if zoneName == "" {
		http.Error(w, "Zone parameter is required", http.StatusBadRequest)
		return
	}
	
	sceneManager := GetSceneManager()
	if err := sceneManager.TestSceneInZone(sceneID, zoneName); err != nil {
		http.Error(w, "Failed to test scene: "+err.Error(), http.StatusInternalServerError)
		return
	}
	
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{
		"message": "Scene applied to zone " + zoneName,
	})
}

// API_DuplicateScene creates a copy of an existing scene
func API_DuplicateScene(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	
	vars := mux.Vars(r)
	sourceSceneID := vars["id"]
	
	sceneManager := GetSceneManager()
	sourceScene := sceneManager.GetSceneByID(sourceSceneID)
	
	if sourceScene == nil {
		http.Error(w, "Source scene not found", http.StatusNotFound)
		return
	}
	
	// Create a copy
	newScene := *sourceScene
	newScene.ID = sourceScene.ID + "_copy_" + strconv.FormatInt(time.Now().Unix(), 10) // Simple unique ID
	newScene.Name = sourceScene.Name + " Copy"
	newScene.IsCustom = true
	newScene.ImagePath = "" // Don't copy image, let user upload new one
	newScene.CreatedAt = ""
	newScene.UpdatedAt = ""
	
	duplicatedScene, err := sceneManager.CreateScene(newScene)
	if err != nil {
		http.Error(w, "Failed to duplicate scene: "+err.Error(), http.StatusInternalServerError)
		return
	}
	
	// Return the new scene
	if duplicatedScene == nil {
		http.Error(w, "Failed to duplicate scene: returned nil", http.StatusInternalServerError)
		return
	}
	
	if err := json.NewEncoder(w).Encode(*duplicatedScene); err != nil {
		http.Error(w, "Failed to encode scene", http.StatusInternalServerError)
		return
	}
}