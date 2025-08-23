package types

import "time"

// WeatherConfig represents weather configuration settings
type WeatherConfig struct {
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
	Timezone  string  `json:"timezone"`
	Location  string  `json:"location"` // Human-readable location name
}

// WeatherResponse represents the complete weather data response
type WeatherResponse struct {
	Current  CurrentWeather `json:"current"`
	Location WeatherConfig  `json:"location"`
}

// CurrentWeather represents current weather conditions
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

// OpenMeteoResponse represents the response from Open-Meteo API
type OpenMeteoResponse struct {
	Current struct {
		Time                string  `json:"time"`
		Temperature2m       float64 `json:"temperature_2m"`
		WeatherCode         int     `json:"weather_code"`
		RelativeHumidity2m  float64 `json:"relative_humidity_2m"`
		WindSpeed10m        float64 `json:"wind_speed_10m"`
		WindDirection10m    float64 `json:"wind_direction_10m"`
		SurfacePressure     float64 `json:"surface_pressure"`
		Visibility          float64 `json:"visibility"`
		UVIndex             float64 `json:"uv_index"`
		IsDay               int     `json:"is_day"`
	} `json:"current"`
	CurrentUnits struct {
		Time                string `json:"time"`
		Temperature2m       string `json:"temperature_2m"`
		WeatherCode         string `json:"weather_code"`
		RelativeHumidity2m  string `json:"relative_humidity_2m"`
		WindSpeed10m        string `json:"wind_speed_10m"`
		WindDirection10m    string `json:"wind_direction_10m"`
		SurfacePressure     string `json:"surface_pressure"`
		Visibility          string `json:"visibility"`
		UVIndex             string `json:"uv_index"`
		IsDay               string `json:"is_day"`
	} `json:"current_units"`
	Timezone string `json:"timezone"`
}

// WeatherCodeMapping maps WMO weather codes to descriptions and icons
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

type WeatherMapping struct {
	Icon        string
	Description string
}