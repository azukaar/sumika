package http

import (
	"encoding/json"
	"net/http"
)

// WriteJSON writes a JSON response with the given data
func WriteJSON(w http.ResponseWriter, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(data); err != nil {
		// Fallback to internal server error if encoding fails
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{
			"error": "Failed to encode response",
		})
	}
}

// WriteError writes a standardized error response
func WriteError(w http.ResponseWriter, status int, message string) {
	w.WriteHeader(status)
	WriteJSON(w, map[string]string{
		"error": message,
	})
}

// WriteSuccess writes a standardized success response
func WriteSuccess(w http.ResponseWriter, message string) {
	WriteJSON(w, map[string]string{
		"message": message,
	})
}

// WriteValidationError writes a validation error response with details
func WriteValidationError(w http.ResponseWriter, errors []string) {
	w.WriteHeader(http.StatusBadRequest)
	WriteJSON(w, map[string]interface{}{
		"error":   "Validation failed",
		"details": errors,
	})
}

// WriteNotFound writes a standardized not found response
func WriteNotFound(w http.ResponseWriter, resource string) {
	WriteError(w, http.StatusNotFound, resource+" not found")
}

// WriteBadRequest writes a standardized bad request response
func WriteBadRequest(w http.ResponseWriter, message string) {
	WriteError(w, http.StatusBadRequest, message)
}

// WriteInternalError writes a standardized internal server error response
func WriteInternalError(w http.ResponseWriter, message string) {
	WriteError(w, http.StatusInternalServerError, message)
}

// WriteConflict writes a standardized conflict response
func WriteConflict(w http.ResponseWriter, message string) {
	WriteError(w, http.StatusConflict, message)
}