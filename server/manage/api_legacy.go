package manage

// This file contains legacy API functions that haven't been moved to domain-specific files yet.
// TODO: Move remaining functions to appropriate domain files and remove this file.

import (
	"net/http"
	httputil "github.com/azukaar/sumika/server/http"
)

// Placeholder for any remaining legacy API functions
// Most functions have been moved to:
// - zones_api.go (zone management)
// - automations_api.go (automation CRUD)
// - device_metadata_api.go (device metadata)
// - scenes_api.go (scene operations)

func API_HealthCheck(w http.ResponseWriter, r *http.Request) {
	httputil.WriteJSON(w, map[string]string{
		"status": "healthy",
		"version": "1.0.0",
	})
}