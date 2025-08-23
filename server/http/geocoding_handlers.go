package http

import (
	"net/http"
	"strconv"
	
	"github.com/azukaar/sumika/server/services"
)

var geocodingService *services.GeocodingService

func init() {
	geocodingService = services.NewGeocodingService()
}

// API_SearchCities searches for cities using geocoding
func API_SearchCities(w http.ResponseWriter, r *http.Request) {
	// Get query parameter
	query := r.URL.Query().Get("name")
	if query == "" {
		WriteBadRequest(w, "Missing 'name' query parameter")
		return
	}
	
	// Get count parameter (optional)
	count := 10 // default
	if countStr := r.URL.Query().Get("count"); countStr != "" {
		if c, err := strconv.Atoi(countStr); err == nil && c > 0 && c <= 100 {
			count = c
		}
	}
	
	// Search for cities
	results, err := geocodingService.SearchCities(query, count)
	if err != nil {
		if err.Error() == "query must be at least 2 characters long" {
			WriteBadRequest(w, err.Error())
			return
		}
		WriteInternalError(w, "Failed to search cities")
		return
	}
	
	WriteJSON(w, results)
}