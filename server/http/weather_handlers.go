package http

import (
	"net/http"
	
	"github.com/azukaar/sumika/server/services"
	"github.com/azukaar/sumika/server/errors"
)

var weatherService *services.WeatherService

func init() {
	weatherService = services.NewWeatherService()
}

// API_GetCurrentWeather returns current weather data
func API_GetCurrentWeather(w http.ResponseWriter, r *http.Request) {
	weather, err := weatherService.GetCurrentWeather()
	if err != nil {
		if err.Error() == "weather is disabled" || err.Error() == "weather location not configured" {
			WriteBadRequest(w, err.Error())
			return
		}
		errorHandler := errors.NewErrorHandler(false)
		errorHandler.HandleError(w, r, err, "get_weather")
		return
	}

	WriteJSON(w, weather)
}