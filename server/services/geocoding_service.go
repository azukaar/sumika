package services

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"time"

	"github.com/azukaar/sumika/server/utils"
)

type GeocodingService struct {
	cache         map[string]*GeocodingResponse
	cacheDuration time.Duration
}

type GeocodingResponse struct {
	Results []GeocodingResult `json:"results"`
	Cached  time.Time         `json:"-"`
}

type GeocodingResult struct {
	ID            int     `json:"id"`
	Name          string  `json:"name"`
	Latitude      float64 `json:"latitude"`
	Longitude     float64 `json:"longitude"`
	Elevation     float64 `json:"elevation"`
	FeatureCode   string  `json:"feature_code"`
	CountryCode   string  `json:"country_code"`
	CountryID     int     `json:"country_id"`
	Country       string  `json:"country"`
	Timezone      string  `json:"timezone"`
	Population    int     `json:"population"`
	Admin1ID      int     `json:"admin1_id,omitempty"`
	Admin1        string  `json:"admin1,omitempty"`
	Admin2ID      int     `json:"admin2_id,omitempty"`
	Admin2        string  `json:"admin2,omitempty"`
	Admin3ID      int     `json:"admin3_id,omitempty"`
	Admin3        string  `json:"admin3,omitempty"`
	Admin4ID      int     `json:"admin4_id,omitempty"`
	Admin4        string  `json:"admin4,omitempty"`
}

func NewGeocodingService() *GeocodingService {
	return &GeocodingService{
		cache:         make(map[string]*GeocodingResponse),
		cacheDuration: 24 * time.Hour, // Cache geocoding results for 24 hours
	}
}

// SearchCities searches for cities using Open-Meteo's Geocoding API
func (s *GeocodingService) SearchCities(query string, count int) (*GeocodingResponse, error) {
	context := utils.NewLogContext("geocoding").WithOperation("search_cities")
	
	// Validate query
	if len(query) < 2 {
		return nil, fmt.Errorf("query must be at least 2 characters long")
	}
	
	// Check cache first
	cacheKey := fmt.Sprintf("%s-%d", query, count)
	if cached, exists := s.cache[cacheKey]; exists {
		if time.Since(cached.Cached) < s.cacheDuration {
			utils.InfoWithContext("Returning cached geocoding results", context)
			return cached, nil
		}
		// Remove expired cache entry
		delete(s.cache, cacheKey)
	}

	// Build API URL
	baseURL := "https://geocoding-api.open-meteo.com/v1/search"
	params := url.Values{}
	params.Add("name", query)
	if count > 0 {
		params.Add("count", fmt.Sprintf("%d", count))
	}
	apiURL := fmt.Sprintf("%s?%s", baseURL, params.Encode())

	// Make API request
	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Get(apiURL)
	if err != nil {
		utils.ErrorWithContext("Failed to fetch geocoding data", context, err)
		return nil, fmt.Errorf("failed to fetch geocoding data: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("geocoding API returned status %d", resp.StatusCode)
	}

	// Parse response
	var geocodingResp GeocodingResponse
	if err := json.NewDecoder(resp.Body).Decode(&geocodingResp); err != nil {
		utils.ErrorWithContext("Failed to decode geocoding response", context, err)
		return nil, fmt.Errorf("failed to decode geocoding response: %w", err)
	}

	// Cache the results
	geocodingResp.Cached = time.Now()
	s.cache[cacheKey] = &geocodingResp

	utils.InfoWithContext(fmt.Sprintf("Found %d geocoding results for query '%s'", len(geocodingResp.Results), query), context)
	return &geocodingResp, nil
}

// GetCityByID gets a specific city by its ID (useful for getting full details)
func (s *GeocodingService) GetCityByID(id int) (*GeocodingResult, error) {
	// For now, we don't have a direct ID lookup API, so this would require
	// implementing a local database or using a different approach
	return nil, fmt.Errorf("city lookup by ID not implemented")
}

// CleanCache removes expired cache entries
func (s *GeocodingService) CleanCache() {
	context := utils.NewLogContext("geocoding").WithOperation("clean_cache")
	
	now := time.Now()
	cleaned := 0
	
	for key, cached := range s.cache {
		if now.Sub(cached.Cached) >= s.cacheDuration {
			delete(s.cache, key)
			cleaned++
		}
	}
	
	if cleaned > 0 {
		utils.InfoWithContext(fmt.Sprintf("Cleaned %d expired geocoding cache entries", cleaned), context)
	}
}