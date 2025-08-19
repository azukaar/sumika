package errors

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/azukaar/sumika/server/utils"
)

// ErrorType represents different categories of errors
type ErrorType string

const (
	ValidationError    ErrorType = "validation"
	NotFoundError     ErrorType = "not_found"
	ConflictError     ErrorType = "conflict"
	UnauthorizedError ErrorType = "unauthorized"
	ForbiddenError    ErrorType = "forbidden"
	InternalError     ErrorType = "internal"
	NetworkError      ErrorType = "network"
	TimeoutError      ErrorType = "timeout"
)

// AppError represents a structured application error
type AppError struct {
	Type       ErrorType              `json:"type"`
	Message    string                 `json:"message"`
	Code       string                 `json:"code,omitempty"`
	Details    map[string]interface{} `json:"details,omitempty"`
	Timestamp  time.Time              `json:"timestamp"`
	RequestID  string                 `json:"request_id,omitempty"`
	StatusCode int                    `json:"-"`
	Cause      error                  `json:"-"`
}

// Error implements the error interface
func (e *AppError) Error() string {
	if e.Code != "" {
		return fmt.Sprintf("[%s:%s] %s", e.Type, e.Code, e.Message)
	}
	return fmt.Sprintf("[%s] %s", e.Type, e.Message)
}

// GetStatusCode returns the appropriate HTTP status code
func (e *AppError) GetStatusCode() int {
	if e.StatusCode != 0 {
		return e.StatusCode
	}

	switch e.Type {
	case ValidationError:
		return http.StatusBadRequest
	case NotFoundError:
		return http.StatusNotFound
	case ConflictError:
		return http.StatusConflict
	case UnauthorizedError:
		return http.StatusUnauthorized
	case ForbiddenError:
		return http.StatusForbidden
	case NetworkError, TimeoutError:
		return http.StatusServiceUnavailable
	case InternalError:
		return http.StatusInternalServerError
	default:
		return http.StatusInternalServerError
	}
}

// ToJSON converts the error to JSON for HTTP responses
func (e *AppError) ToJSON() []byte {
	response := map[string]interface{}{
		"error": map[string]interface{}{
			"type":      e.Type,
			"message":   e.Message,
			"timestamp": e.Timestamp.Format(time.RFC3339),
		},
	}

	if e.Code != "" {
		response["error"].(map[string]interface{})["code"] = e.Code
	}

	if e.Details != nil && len(e.Details) > 0 {
		response["error"].(map[string]interface{})["details"] = e.Details
	}

	if e.RequestID != "" {
		response["error"].(map[string]interface{})["request_id"] = e.RequestID
	}

	jsonBytes, _ := json.Marshal(response)
	return jsonBytes
}

// NewValidationError creates a validation error
func NewValidationError(message string, details map[string]interface{}) *AppError {
	return &AppError{
		Type:      ValidationError,
		Message:   message,
		Details:   details,
		Timestamp: time.Now(),
	}
}

// NewNotFoundError creates a not found error
func NewNotFoundError(resource string) *AppError {
	return &AppError{
		Type:      NotFoundError,
		Message:   fmt.Sprintf("%s not found", resource),
		Timestamp: time.Now(),
	}
}

// NewConflictError creates a conflict error
func NewConflictError(message string) *AppError {
	return &AppError{
		Type:      ConflictError,
		Message:   message,
		Timestamp: time.Now(),
	}
}

// NewUnauthorizedError creates an unauthorized error
func NewUnauthorizedError(message string) *AppError {
	return &AppError{
		Type:      UnauthorizedError,
		Message:   message,
		Timestamp: time.Now(),
	}
}

// NewForbiddenError creates a forbidden error
func NewForbiddenError(message string) *AppError {
	return &AppError{
		Type:      ForbiddenError,
		Message:   message,
		Timestamp: time.Now(),
	}
}

// NewInternalError creates an internal error
func NewInternalError(message string, cause error) *AppError {
	return &AppError{
		Type:      InternalError,
		Message:   message,
		Cause:     cause,
		Timestamp: time.Now(),
	}
}

// NewNetworkError creates a network error
func NewNetworkError(message string, cause error) *AppError {
	return &AppError{
		Type:      NetworkError,
		Message:   message,
		Cause:     cause,
		Timestamp: time.Now(),
	}
}

// NewTimeoutError creates a timeout error
func NewTimeoutError(operation string) *AppError {
	return &AppError{
		Type:      TimeoutError,
		Message:   fmt.Sprintf("Operation timed out: %s", operation),
		Timestamp: time.Now(),
	}
}

// WithCode adds an error code
func (e *AppError) WithCode(code string) *AppError {
	e.Code = code
	return e
}

// WithDetails adds additional details
func (e *AppError) WithDetails(details map[string]interface{}) *AppError {
	if e.Details == nil {
		e.Details = make(map[string]interface{})
	}
	for k, v := range details {
		e.Details[k] = v
	}
	return e
}

// WithRequestID adds a request ID for tracing
func (e *AppError) WithRequestID(requestID string) *AppError {
	e.RequestID = requestID
	return e
}

// WithStatusCode sets a custom status code
func (e *AppError) WithStatusCode(code int) *AppError {
	e.StatusCode = code
	return e
}

// Log logs the error with appropriate level and context
func (e *AppError) Log(context string) {
	logMessage := fmt.Sprintf("[%s] %s", context, e.Message)
	
	if e.Details != nil && len(e.Details) > 0 {
		logMessage += fmt.Sprintf(" | Details: %+v", e.Details)
	}
	
	if e.Code != "" {
		logMessage += fmt.Sprintf(" | Code: %s", e.Code)
	}

	if e.RequestID != "" {
		logMessage += fmt.Sprintf(" | RequestID: %s", e.RequestID)
	}

	// Log with appropriate level based on error type
	switch e.Type {
	case ValidationError, NotFoundError, ConflictError, UnauthorizedError, ForbiddenError:
		utils.Warn(logMessage)
		if e.Cause != nil {
			utils.Debug(fmt.Sprintf("Caused by: %v", e.Cause))
		}
	case NetworkError, TimeoutError:
		utils.Error(logMessage, e.Cause)
	case InternalError:
		utils.Error(logMessage, e.Cause)
	default:
		utils.Error(logMessage, e.Cause)
	}
}

// FromError converts a standard error to AppError
func FromError(err error, errorType ErrorType, message string) *AppError {
	if appErr, ok := err.(*AppError); ok {
		return appErr
	}

	return &AppError{
		Type:      errorType,
		Message:   message,
		Cause:     err,
		Timestamp: time.Now(),
	}
}