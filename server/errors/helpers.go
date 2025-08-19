package errors

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"

	"github.com/gorilla/mux"
)

// ValidationResult holds validation error information
type ValidationResult struct {
	IsValid bool                   `json:"is_valid"`
	Errors  map[string]interface{} `json:"errors,omitempty"`
}

// AddError adds a validation error
func (vr *ValidationResult) AddError(field, message string) {
	vr.IsValid = false
	if vr.Errors == nil {
		vr.Errors = make(map[string]interface{})
	}
	vr.Errors[field] = message
}

// AddFieldError adds a field-specific validation error
func (vr *ValidationResult) AddFieldError(field, message string, details map[string]interface{}) {
	vr.IsValid = false
	if vr.Errors == nil {
		vr.Errors = make(map[string]interface{})
	}
	vr.Errors[field] = map[string]interface{}{
		"message": message,
		"details": details,
	}
}

// ToAppError converts validation result to AppError
func (vr *ValidationResult) ToAppError() *AppError {
	if vr.IsValid {
		return nil
	}

	return NewValidationError(
		"Request validation failed",
		map[string]interface{}{
			"validation_errors": vr.Errors,
		},
	)
}

// NewValidator creates a new validation result
func NewValidator() *ValidationResult {
	return &ValidationResult{IsValid: true}
}

// Request parsing helpers with error handling

// ParseJSONBody parses JSON request body with validation
func ParseJSONBody(r *http.Request, target interface{}) *AppError {
	if r.Body == nil {
		return NewValidationError("Request body is required", nil)
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		return NewInternalError("Failed to read request body", err)
	}

	if len(body) == 0 {
		return NewValidationError("Request body cannot be empty", nil)
	}

	if err := json.Unmarshal(body, target); err != nil {
		return NewValidationError("Invalid JSON format", map[string]interface{}{
			"parse_error": err.Error(),
		})
	}

	return nil
}

// GetPathParam extracts and validates path parameters
func GetPathParam(r *http.Request, paramName string) (string, *AppError) {
	vars := mux.Vars(r)
	value, exists := vars[paramName]
	
	if !exists || value == "" {
		return "", NewValidationError(
			fmt.Sprintf("Missing required path parameter: %s", paramName),
			map[string]interface{}{
				"parameter": paramName,
				"type":      "path",
			},
		)
	}

	return value, nil
}

// GetQueryParam extracts and validates query parameters
func GetQueryParam(r *http.Request, paramName string, required bool) (string, *AppError) {
	value := r.URL.Query().Get(paramName)
	
	if required && value == "" {
		return "", NewValidationError(
			fmt.Sprintf("Missing required query parameter: %s", paramName),
			map[string]interface{}{
				"parameter": paramName,
				"type":      "query",
			},
		)
	}

	return value, nil
}

// GetIntQueryParam extracts and validates integer query parameters
func GetIntQueryParam(r *http.Request, paramName string, required bool, defaultValue int) (int, *AppError) {
	valueStr := r.URL.Query().Get(paramName)
	
	if valueStr == "" {
		if required {
			return 0, NewValidationError(
				fmt.Sprintf("Missing required query parameter: %s", paramName),
				map[string]interface{}{
					"parameter": paramName,
					"type":      "query",
					"expected":  "integer",
				},
			)
		}
		return defaultValue, nil
	}

	value, err := strconv.Atoi(valueStr)
	if err != nil {
		return 0, NewValidationError(
			fmt.Sprintf("Invalid integer value for parameter: %s", paramName),
			map[string]interface{}{
				"parameter": paramName,
				"value":     valueStr,
				"expected":  "integer",
			},
		)
	}

	return value, nil
}

// GetBoolQueryParam extracts and validates boolean query parameters
func GetBoolQueryParam(r *http.Request, paramName string, required bool, defaultValue bool) (bool, *AppError) {
	valueStr := r.URL.Query().Get(paramName)
	
	if valueStr == "" {
		if required {
			return false, NewValidationError(
				fmt.Sprintf("Missing required query parameter: %s", paramName),
				map[string]interface{}{
					"parameter": paramName,
					"type":      "query",
					"expected":  "boolean",
				},
			)
		}
		return defaultValue, nil
	}

	// Accept various boolean representations
	valueStr = strings.ToLower(valueStr)
	switch valueStr {
	case "true", "1", "yes", "on":
		return true, nil
	case "false", "0", "no", "off":
		return false, nil
	default:
		return false, NewValidationError(
			fmt.Sprintf("Invalid boolean value for parameter: %s", paramName),
			map[string]interface{}{
				"parameter": paramName,
				"value":     valueStr,
				"expected":  "boolean (true/false, 1/0, yes/no, on/off)",
			},
		)
	}
}

// Validation helpers

// ValidateRequired checks if a field is present and not empty
func ValidateRequired(validator *ValidationResult, fieldName string, value interface{}) {
	if value == nil {
		validator.AddError(fieldName, "This field is required")
		return
	}

	switch v := value.(type) {
	case string:
		if strings.TrimSpace(v) == "" {
			validator.AddError(fieldName, "This field cannot be empty")
		}
	case []interface{}:
		if len(v) == 0 {
			validator.AddError(fieldName, "This field must contain at least one item")
		}
	}
}

// ValidateStringLength validates string length constraints
func ValidateStringLength(validator *ValidationResult, fieldName string, value string, minLen, maxLen int) {
	length := len(strings.TrimSpace(value))
	
	if minLen > 0 && length < minLen {
		validator.AddFieldError(fieldName, 
			fmt.Sprintf("Must be at least %d characters long", minLen),
			map[string]interface{}{
				"min_length":     minLen,
				"actual_length": length,
			},
		)
	}

	if maxLen > 0 && length > maxLen {
		validator.AddFieldError(fieldName,
			fmt.Sprintf("Must be no more than %d characters long", maxLen),
			map[string]interface{}{
				"max_length":     maxLen,
				"actual_length": length,
			},
		)
	}
}

// ValidateInSlice validates that a value is in a list of allowed values
func ValidateInSlice(validator *ValidationResult, fieldName string, value string, allowedValues []string) {
	for _, allowed := range allowedValues {
		if value == allowed {
			return
		}
	}
	
	validator.AddFieldError(fieldName,
		fmt.Sprintf("Invalid value. Must be one of: %s", strings.Join(allowedValues, ", ")),
		map[string]interface{}{
			"allowed_values": allowedValues,
			"provided_value": value,
		},
	)
}

// ValidateEmail validates email format (basic validation)
func ValidateEmail(validator *ValidationResult, fieldName string, email string) {
	email = strings.TrimSpace(email)
	if email == "" {
		return // Empty validation should be handled by ValidateRequired
	}

	// Basic email validation
	if !strings.Contains(email, "@") || strings.Count(email, "@") != 1 {
		validator.AddError(fieldName, "Invalid email format")
		return
	}

	parts := strings.Split(email, "@")
	if len(parts[0]) == 0 || len(parts[1]) == 0 || !strings.Contains(parts[1], ".") {
		validator.AddError(fieldName, "Invalid email format")
	}
}

// WrapDatabaseError converts database errors to appropriate AppErrors
func WrapDatabaseError(err error, operation string) *AppError {
	if err == nil {
		return nil
	}

	errMsg := err.Error()
	
	// Check for common database error patterns
	if strings.Contains(errMsg, "not found") || strings.Contains(errMsg, "no rows") {
		return NewNotFoundError("Resource").WithDetails(map[string]interface{}{
			"operation": operation,
		})
	}

	if strings.Contains(errMsg, "duplicate") || strings.Contains(errMsg, "unique constraint") {
		return NewConflictError("Resource already exists").WithDetails(map[string]interface{}{
			"operation": operation,
		})
	}

	if strings.Contains(errMsg, "timeout") || strings.Contains(errMsg, "deadline exceeded") {
		return NewTimeoutError(operation)
	}

	// Default to internal error for unknown database errors
	return NewInternalError(fmt.Sprintf("Database operation failed: %s", operation), err)
}