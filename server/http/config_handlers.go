package http

import (
	"encoding/json"
	"net/http"
	"os"
	"time"
	"fmt"

	"github.com/azukaar/sumika/server/config"
)

// API_GetConfig returns the current configuration
func API_GetConfig(w http.ResponseWriter, r *http.Request) {
	cfg := config.GetConfig()
	WriteJSON(w, cfg)
}

// API_UpdateConfig updates the configuration and saves it to file
func API_UpdateConfig(w http.ResponseWriter, r *http.Request) {
	var newConfig config.Config
	
	fmt.Println("Received request to update configuration")
	
	if err := json.NewDecoder(r.Body).Decode(&newConfig); err != nil {
		WriteBadRequest(w, "Invalid JSON payload")
		return
	}
	
	// Save the updated configuration to file
	if err := config.SaveConfig(&newConfig, config.GetConfigFilePath()); err != nil {
		WriteInternalError(w, "Failed to save configuration")
		return
	}
	
	WriteJSON(w, map[string]string{
		"status": "success",
		"message": "Configuration updated successfully. Restart required for changes to take effect.",
	})
	
	// Exit the process - Docker will restart the container
	go func() {
		fmt.Println("Exiting process...")
		time.Sleep(1 * time.Second)
		os.Exit(0)
	}()
}

// API_RestartServer initiates a server restart by exiting the process
func API_RestartServer(w http.ResponseWriter, r *http.Request) {
	// Send response before exiting
	WriteJSON(w, map[string]string{
		"status": "success",
		"message": "Server restart initiated",
	})
	
	// Force response to be sent
	if f, ok := w.(http.Flusher); ok {
		f.Flush()
	}
	
	// Exit the process - Docker will restart the container
	go func() {
		fmt.Println("Exiting process...")
		time.Sleep(1 * time.Second)
		os.Exit(0)
	}()
}