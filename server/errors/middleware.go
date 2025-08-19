package errors

import (
	"fmt"
	"net/http"
	"runtime/debug"

	"github.com/azukaar/sumika/server/utils"
)

// ErrorHandler is middleware that provides centralized error handling
type ErrorHandler struct {
	// ShowInternalErrorDetails controls whether internal error details are exposed
	ShowInternalErrorDetails bool
}

// NewErrorHandler creates a new error handler middleware
func NewErrorHandler(showDetails bool) *ErrorHandler {
	return &ErrorHandler{
		ShowInternalErrorDetails: showDetails,
	}
}

// HandleError processes an error and writes appropriate HTTP response
func (eh *ErrorHandler) HandleError(w http.ResponseWriter, r *http.Request, err error, context string) {
	if err == nil {
		return
	}

	var appErr *AppError
	
	// Convert error to AppError if needed
	if existingAppErr, ok := err.(*AppError); ok {
		appErr = existingAppErr
	} else {
		// Convert unknown errors to internal errors
		appErr = NewInternalError("An unexpected error occurred", err)
	}

	// Add request ID if available (from context or header)
	if requestID := r.Header.Get("X-Request-ID"); requestID != "" {
		appErr = appErr.WithRequestID(requestID)
	}

	// Log the error
	appErr.Log(context)

	// Sanitize error for client response
	clientError := eh.sanitizeErrorForClient(appErr)

	// Set response headers
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(clientError.GetStatusCode())

	// Write JSON response
	w.Write(clientError.ToJSON())
}

// sanitizeErrorForClient removes sensitive information from errors sent to clients
func (eh *ErrorHandler) sanitizeErrorForClient(err *AppError) *AppError {
	clientError := &AppError{
		Type:      err.Type,
		Message:   err.Message,
		Code:      err.Code,
		Timestamp: err.Timestamp,
		RequestID: err.RequestID,
	}

	// Only include details for non-internal errors or if explicitly allowed
	if err.Type != InternalError || eh.ShowInternalErrorDetails {
		clientError.Details = err.Details
	} else {
		// For internal errors, provide generic message unless in debug mode
		clientError.Message = "An internal server error occurred"
		clientError.Details = nil
	}

	return clientError
}

// RecoverMiddleware recovers from panics and converts them to internal errors
func (eh *ErrorHandler) RecoverMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if rec := recover(); rec != nil {
				// Log the panic with stack trace
				stack := debug.Stack()
				utils.Error(fmt.Sprintf("Panic recovered: %v", rec), fmt.Errorf("stack trace: %s", stack))

				// Convert panic to internal error
				panicErr := NewInternalError(
					"A critical error occurred while processing the request",
					fmt.Errorf("panic: %v", rec),
				).WithDetails(map[string]interface{}{
					"panic_value": fmt.Sprintf("%v", rec),
				})

				eh.HandleError(w, r, panicErr, "panic_recovery")
			}
		}()

		next.ServeHTTP(w, r)
	})
}

// LoggingMiddleware logs HTTP requests with structured information
func LoggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Log request
		utils.LogReq(fmt.Sprintf("%s %s", r.Method, r.URL.Path))

		// Create a response writer wrapper to capture status code
		wrapper := &responseWriterWrapper{
			ResponseWriter: w,
			statusCode:     http.StatusOK,
		}

		next.ServeHTTP(wrapper, r)

		// Log response status
		if wrapper.statusCode >= 400 {
			utils.Warn(fmt.Sprintf("%s %s - %d", r.Method, r.URL.Path, wrapper.statusCode))
		} else {
			utils.Debug(fmt.Sprintf("%s %s - %d", r.Method, r.URL.Path, wrapper.statusCode))
		}
	})
}

// responseWriterWrapper captures the status code for logging
type responseWriterWrapper struct {
	http.ResponseWriter
	statusCode int
}

func (rw *responseWriterWrapper) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}

// Common error response helpers

// HandleValidationError is a helper for validation errors
func HandleValidationError(w http.ResponseWriter, r *http.Request, field, message string) {
	err := NewValidationError(
		fmt.Sprintf("Validation failed for field '%s'", field),
		map[string]interface{}{
			"field":  field,
			"reason": message,
		},
	)
	
	errorHandler := NewErrorHandler(false)
	errorHandler.HandleError(w, r, err, "validation")
}

// HandleNotFound is a helper for not found errors
func HandleNotFound(w http.ResponseWriter, r *http.Request, resource string) {
	err := NewNotFoundError(resource)
	
	errorHandler := NewErrorHandler(false)
	errorHandler.HandleError(w, r, err, "not_found")
}

// HandleInternalError is a helper for internal errors
func HandleInternalError(w http.ResponseWriter, r *http.Request, message string, cause error) {
	err := NewInternalError(message, cause)
	
	errorHandler := NewErrorHandler(false) // Don't show internal details in production
	errorHandler.HandleError(w, r, err, "internal")
}

// HandleConflict is a helper for conflict errors
func HandleConflict(w http.ResponseWriter, r *http.Request, message string) {
	err := NewConflictError(message)
	
	errorHandler := NewErrorHandler(false)
	errorHandler.HandleError(w, r, err, "conflict")
}