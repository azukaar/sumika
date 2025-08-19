package http

import (
	"net/http"
	"strconv"

	"github.com/gorilla/mux"
)

// GetPathParam extracts a path parameter from the URL and validates it's not empty
func GetPathParam(r *http.Request, name string) (string, bool) {
	vars := mux.Vars(r)
	value := vars[name]
	return value, value != ""
}

// GetRequiredPathParam extracts a path parameter and returns error response if missing
func GetRequiredPathParam(r *http.Request, w http.ResponseWriter, name string) (string, bool) {
	value, exists := GetPathParam(r, name)
	if !exists || value == "" {
		WriteBadRequest(w, "Missing required parameter: "+name)
		return "", false
	}
	return value, true
}

// GetQueryParam extracts a query parameter
func GetQueryParam(r *http.Request, name string) string {
	return r.URL.Query().Get(name)
}

// GetRequiredQueryParam extracts a query parameter and returns error response if missing
func GetRequiredQueryParam(r *http.Request, w http.ResponseWriter, name string) (string, bool) {
	value := r.URL.Query().Get(name)
	if value == "" {
		WriteBadRequest(w, "Missing required query parameter: "+name)
		return "", false
	}
	return value, true
}

// GetIntQueryParam extracts and parses an integer query parameter
func GetIntQueryParam(r *http.Request, name string, defaultValue int) int {
	value := r.URL.Query().Get(name)
	if value == "" {
		return defaultValue
	}
	
	intValue, err := strconv.Atoi(value)
	if err != nil {
		return defaultValue
	}
	
	return intValue
}

// GetBoolQueryParam extracts and parses a boolean query parameter
func GetBoolQueryParam(r *http.Request, name string, defaultValue bool) bool {
	value := r.URL.Query().Get(name)
	if value == "" {
		return defaultValue
	}
	
	boolValue, err := strconv.ParseBool(value)
	if err != nil {
		return defaultValue
	}
	
	return boolValue
}

// ValidatePathParams validates multiple required path parameters at once
func ValidatePathParams(r *http.Request, w http.ResponseWriter, paramNames ...string) (map[string]string, bool) {
	params := make(map[string]string)
	vars := mux.Vars(r)
	
	for _, name := range paramNames {
		value := vars[name]
		if value == "" {
			WriteBadRequest(w, "Missing required parameter: "+name)
			return nil, false
		}
		params[name] = value
	}
	
	return params, true
}