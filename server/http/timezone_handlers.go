package http

import (
	"net/http"
	"strconv"
)

// API_SearchTimezones searches for timezones
func API_SearchTimezones(w http.ResponseWriter, r *http.Request) {
	// Get query parameter
	query := r.URL.Query().Get("q")
	
	// Get limit parameter (optional)
	limit := 50 // default
	if limitStr := r.URL.Query().Get("limit"); limitStr != "" {
		if l, err := strconv.Atoi(limitStr); err == nil && l > 0 && l <= 500 {
			limit = l
		}
	}
	
	// Search for timezones
	results, err := timezoneService.SearchTimezones(query, limit)
	if err != nil {
		WriteInternalError(w, "Failed to search timezones")
		return
	}
	
	WriteJSON(w, results)
}

// API_GetAllTimezones returns all available timezones
func API_GetAllTimezones(w http.ResponseWriter, r *http.Request) {
	results := timezoneService.GetAllTimezones()
	WriteJSON(w, results)
}