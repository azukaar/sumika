package services

import (
	"context"
	"fmt"
	"time"

	"github.com/hectormalot/omgo"
	"github.com/azukaar/sumika/server/config"
	"github.com/azukaar/sumika/server/utils"
)

type WeatherService struct {
	cache *WeatherCache
}

type WeatherCache struct {
	data      *WeatherResponse
	expiry    time.Time
	cacheDuration time.Duration
}

type WeatherResponse struct {
	Current  CurrentWeather  `json:"current"`
	Location LocationInfo    `json:"location"`
}

type CurrentWeather struct {
	Temperature     float64   `json:"temperature"`      // Temperature in Celsius
	WeatherCode     int       `json:"weather_code"`     // WMO weather code
	WeatherIcon     string    `json:"weather_icon"`     // Icon identifier
	WeatherDesc     string    `json:"weather_desc"`     // Weather description
	Humidity        float64   `json:"humidity"`         // Relative humidity %
	WindSpeed       float64   `json:"wind_speed"`       // Wind speed km/h
	WindDirection   float64   `json:"wind_direction"`   // Wind direction degrees
	Pressure        float64   `json:"pressure"`         // Surface pressure hPa
	Visibility      float64   `json:"visibility"`       // Visibility km
	UVIndex         float64   `json:"uv_index"`         // UV index
	IsDay           bool      `json:"is_day"`           // Is daytime
	LastUpdated     time.Time `json:"last_updated"`     // Last update time
}

type LocationInfo struct {
	Latitude    float64   `json:"latitude"`
	Longitude   float64   `json:"longitude"`
	Location    string    `json:"location"`
	Timezone    string    `json:"timezone"`
	CurrentTime time.Time `json:"current_time"`
}


type WeatherMapping struct {
	Icon        string
	Description string
}

var WeatherCodeMapping = map[int]WeatherMapping{
	0:  {Icon: "clear-day", Description: "Clear sky"},
	1:  {Icon: "partly-cloudy-day", Description: "Mainly clear"},
	2:  {Icon: "partly-cloudy-day", Description: "Partly cloudy"},
	3:  {Icon: "cloudy", Description: "Overcast"},
	45: {Icon: "fog", Description: "Fog"},
	48: {Icon: "fog", Description: "Depositing rime fog"},
	51: {Icon: "drizzle", Description: "Light drizzle"},
	53: {Icon: "drizzle", Description: "Moderate drizzle"},
	55: {Icon: "drizzle", Description: "Dense drizzle"},
	56: {Icon: "sleet", Description: "Light freezing drizzle"},
	57: {Icon: "sleet", Description: "Dense freezing drizzle"},
	61: {Icon: "rain", Description: "Slight rain"},
	63: {Icon: "rain", Description: "Moderate rain"},
	65: {Icon: "rain", Description: "Heavy rain"},
	66: {Icon: "sleet", Description: "Light freezing rain"},
	67: {Icon: "sleet", Description: "Heavy freezing rain"},
	71: {Icon: "snow", Description: "Slight snow fall"},
	73: {Icon: "snow", Description: "Moderate snow fall"},
	75: {Icon: "snow", Description: "Heavy snow fall"},
	77: {Icon: "snow", Description: "Snow grains"},
	80: {Icon: "rain", Description: "Slight rain showers"},
	81: {Icon: "rain", Description: "Moderate rain showers"},
	82: {Icon: "rain", Description: "Violent rain showers"},
	85: {Icon: "snow", Description: "Slight snow showers"},
	86: {Icon: "snow", Description: "Heavy snow showers"},
	95: {Icon: "thunderstorm", Description: "Thunderstorm"},
	96: {Icon: "thunderstorm", Description: "Thunderstorm with slight hail"},
	99: {Icon: "thunderstorm", Description: "Thunderstorm with heavy hail"},
}

func NewWeatherService() *WeatherService {
	return &WeatherService{
		cache: &WeatherCache{
			cacheDuration: 10 * time.Minute, // Cache weather data for 10 minutes
		},
	}
}

// GetCurrentWeather retrieves current weather data
func (s *WeatherService) GetCurrentWeather() (*WeatherResponse, error) {
	logContext := utils.NewLogContext("weather").WithOperation("get_current")

	// Get configuration
	cfg := config.GetConfig()
	weatherCfg := &cfg.Weather

	// Check if weather is enabled and configured
	if !weatherCfg.Enabled {
		utils.InfoWithContext("Weather is disabled", logContext)
		return nil, fmt.Errorf("weather is disabled")
	}

	if weatherCfg.Latitude == 0.0 && weatherCfg.Longitude == 0.0 {
		utils.InfoWithContext("Weather location not configured", logContext)
		return nil, fmt.Errorf("weather location not configured")
	}

	// Check cache first
	if s.cache.data != nil && time.Now().Before(s.cache.expiry) {
		utils.InfoWithContext("Returning cached weather data", logContext)
		return s.cache.data, nil
	}

	// Fetch weather data from Open-Meteo using omgo
	weatherData, err := s.fetchWeatherFromOpenMeteo(weatherCfg, cfg.Server.Timezone)
	if err != nil {
		utils.ErrorWithContext("Failed to fetch weather data", logContext, err)
		return nil, fmt.Errorf("failed to fetch weather data: %w", err)
	}

	// Cache the data
	s.cache.data = weatherData
	s.cache.expiry = time.Now().Add(s.cache.cacheDuration)

	utils.InfoWithContext("Weather data fetched and cached successfully", logContext)
	return weatherData, nil
}

// fetchWeatherFromOpenMeteo fetches weather data from Open-Meteo API using omgo
func (s *WeatherService) fetchWeatherFromOpenMeteo(weatherCfg *config.WeatherConfig, timezone string) (*WeatherResponse, error) {
	// Create omgo client
	client, err := omgo.NewClient()
	if err != nil {
		return nil, fmt.Errorf("failed to create weather client: %w", err)
	}

	// Create location
	loc, err := omgo.NewLocation(weatherCfg.Latitude, weatherCfg.Longitude)
	if err != nil {
		return nil, fmt.Errorf("failed to create location: %w", err)
	}

	// Set options for the API call
	opts := &omgo.Options{
		Timezone: timezone,
	}

	// Fetch current weather
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	resp, err := client.CurrentWeather(ctx, loc, opts)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch weather: %w", err)
	}

	// Convert omgo response to our weather response format
	weatherResp := s.convertOmgoResponse(&resp, weatherCfg, timezone)
	return weatherResp, nil
}

// convertOmgoResponse converts omgo response to our weather response format
func (s *WeatherService) convertOmgoResponse(resp *omgo.CurrentWeather, weatherCfg *config.WeatherConfig, timezone string) *WeatherResponse {
	// Get weather code value
	weatherCode := int(resp.WeatherCode)

	// Get weather description and icon from weather code
	weatherMapping, exists := WeatherCodeMapping[weatherCode]
	if !exists {
		weatherMapping = WeatherMapping{
			Icon:        "unknown",
			Description: "Unknown",
		}
	}

	// Assume it's day for now (omgo doesn't provide is_day info)
	isDay := true
	icon := weatherMapping.Icon

	// Parse last updated time
	lastUpdated := resp.Time.Time

	// Get current time in the location's timezone
	loc, err := time.LoadLocation(timezone)
	var currentTime time.Time
	if err != nil {
		// Fallback to UTC if timezone is invalid
		currentTime = time.Now().UTC()
	} else {
		currentTime = time.Now().In(loc)
	}

	return &WeatherResponse{
		Current: CurrentWeather{
			Temperature:     resp.Temperature,
			WeatherCode:     weatherCode,
			WeatherIcon:     icon,
			WeatherDesc:     weatherMapping.Description,
			Humidity:        0, // Not available in omgo response
			WindSpeed:       resp.WindSpeed,
			WindDirection:   resp.WindDirection,
			Pressure:        0, // Not available in omgo response
			Visibility:      0, // Not available in omgo response
			UVIndex:         0, // Not available in omgo response
			IsDay:           isDay,
			LastUpdated:     lastUpdated,
		},
		Location: LocationInfo{
			Latitude:    weatherCfg.Latitude,
			Longitude:   weatherCfg.Longitude,
			Location:    weatherCfg.Location,
			Timezone:    timezone,
			CurrentTime: currentTime,
		},
	}
}