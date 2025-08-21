package http

import (
	"net/http"
)

func API_HealthCheck(w http.ResponseWriter, r *http.Request) {
	WriteJSON(w, map[string]string{
		"status": "healthy",
		"version": "1.0.0",
	})
}