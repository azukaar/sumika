package utils

import (
	"encoding/json"
	"fmt"
	"runtime"
	"strings"
	"time"
)

// LogContext provides structured context for logging
type LogContext struct {
	Component   string                 `json:"component,omitempty"`
	Operation   string                 `json:"operation,omitempty"`
	UserID      string                 `json:"user_id,omitempty"`
	RequestID   string                 `json:"request_id,omitempty"`
	SessionID   string                 `json:"session_id,omitempty"`
	IPAddress   string                 `json:"ip_address,omitempty"`
	UserAgent   string                 `json:"user_agent,omitempty"`
	Duration    time.Duration          `json:"duration,omitempty"`
	StatusCode  int                    `json:"status_code,omitempty"`
	Method      string                 `json:"method,omitempty"`
	Path        string                 `json:"path,omitempty"`
	QueryParams map[string]string      `json:"query_params,omitempty"`
	Headers     map[string]string      `json:"headers,omitempty"`
	Metadata    map[string]interface{} `json:"metadata,omitempty"`
}

// NewLogContext creates a new logging context
func NewLogContext(component string) *LogContext {
	return &LogContext{
		Component: component,
		Metadata:  make(map[string]interface{}),
	}
}

// WithOperation adds operation context
func (lc *LogContext) WithOperation(operation string) *LogContext {
	lc.Operation = operation
	return lc
}

// WithUser adds user context
func (lc *LogContext) WithUser(userID string) *LogContext {
	lc.UserID = userID
	return lc
}

// WithRequest adds request context
func (lc *LogContext) WithRequest(requestID, method, path string) *LogContext {
	lc.RequestID = requestID
	lc.Method = method
	lc.Path = path
	return lc
}

// WithDuration adds timing information
func (lc *LogContext) WithDuration(duration time.Duration) *LogContext {
	lc.Duration = duration
	return lc
}

// WithMetadata adds custom metadata
func (lc *LogContext) WithMetadata(key string, value interface{}) *LogContext {
	if lc.Metadata == nil {
		lc.Metadata = make(map[string]interface{})
	}
	lc.Metadata[key] = value
	return lc
}

// WithError adds error information to metadata
func (lc *LogContext) WithError(err error) *LogContext {
	if err != nil {
		lc.WithMetadata("error", err.Error())
		lc.WithMetadata("error_type", fmt.Sprintf("%T", err))
	}
	return lc
}

// ToJSON converts the context to JSON string
func (lc *LogContext) ToJSON() string {
	data, _ := json.Marshal(lc)
	return string(data)
}

// Structured logging functions

// LogWithContext logs a message with structured context
func LogWithContext(level LogLevel, message string, context *LogContext) {
	// Get caller information
	_, file, line, ok := runtime.Caller(2)
	if ok {
		// Extract just the filename from the full path
		parts := strings.Split(file, "/")
		file = parts[len(parts)-1]
		context = context.WithMetadata("source", fmt.Sprintf("%s:%d", file, line))
	}

	// Create structured log message
	structuredMsg := fmt.Sprintf("%s | %s", message, context.ToJSON())

	// Log using existing infrastructure
	switch level {
	case DEBUG:
		RawLogMessage(DEBUG, "[DEBUG]", bPurple, nPurple, structuredMsg)
	case INFO:
		RawLogMessage(INFO, "[INFO] ", bBlue, nBlue, structuredMsg)
	case WARNING:
		RawLogMessage(WARNING, "[WARN] ", bYellow, nYellow, structuredMsg)
	case ERROR:
		RawLogMessage(ERROR, "[ERROR]", bRed, nRed, structuredMsg)
	case FATAL:
		RawLogMessage(FATAL, "[FATAL]", bRed, nRed, structuredMsg)
	}
}

// Convenience functions for different log levels with context

// DebugWithContext logs debug message with context
func DebugWithContext(message string, context *LogContext) {
	LogWithContext(DEBUG, message, context)
}

// InfoWithContext logs info message with context
func InfoWithContext(message string, context *LogContext) {
	LogWithContext(INFO, message, context)
}

// WarnWithContext logs warning message with context
func WarnWithContext(message string, context *LogContext) {
	LogWithContext(WARNING, message, context)
}

// ErrorWithContext logs error message with context
func ErrorWithContext(message string, context *LogContext, err error) {
	if err != nil {
		context = context.WithError(err)
	}
	LogWithContext(ERROR, message, context)
}

// FatalWithContext logs fatal message with context and exits
func FatalWithContext(message string, context *LogContext, err error) {
	if err != nil {
		context = context.WithError(err)
	}
	LogWithContext(FATAL, message, context)
}

// Operation logging helpers

// LogOperationStart logs the start of an operation
func LogOperationStart(component, operation string, metadata map[string]interface{}) *LogContext {
	context := NewLogContext(component).WithOperation(operation)
	
	if metadata != nil {
		for k, v := range metadata {
			context.WithMetadata(k, v)
		}
	}
	
	InfoWithContext(fmt.Sprintf("Starting operation: %s", operation), context)
	return context
}

// LogOperationEnd logs the completion of an operation
func LogOperationEnd(context *LogContext, success bool, duration time.Duration, err error) {
	context = context.WithDuration(duration)
	
	if success {
		InfoWithContext("Operation completed successfully", context)
	} else {
		if err != nil {
			context = context.WithError(err)
		}
		ErrorWithContext("Operation failed", context, err)
	}
}

// LogOperationTiming logs operation timing information
func LogOperationTiming(component, operation string, duration time.Duration, metadata map[string]interface{}) {
	context := NewLogContext(component).
		WithOperation(operation).
		WithDuration(duration)
	
	if metadata != nil {
		for k, v := range metadata {
			context.WithMetadata(k, v)
		}
	}

	// Log as warning if operation is slow (>1 second), info otherwise
	message := fmt.Sprintf("Operation timing: %s took %v", operation, duration)
	if duration > time.Second {
		WarnWithContext(message, context)
	} else {
		InfoWithContext(message, context)
	}
}

// HTTP request logging helpers

// LogHTTPRequest logs HTTP request details
func LogHTTPRequest(method, path, userAgent, ipAddress string, headers map[string]string) {
	context := NewLogContext("http").
		WithRequest("", method, path).
		WithMetadata("user_agent", userAgent).
		WithMetadata("ip_address", ipAddress)
	
	if headers != nil {
		context.Headers = headers
	}

	InfoWithContext("HTTP request received", context)
}

// LogHTTPResponse logs HTTP response details
func LogHTTPResponse(method, path string, statusCode int, duration time.Duration, responseSize int64) {
	context := NewLogContext("http").
		WithRequest("", method, path).
		WithDuration(duration).
		WithMetadata("status_code", statusCode).
		WithMetadata("response_size", responseSize)

	message := fmt.Sprintf("HTTP response: %d", statusCode)
	
	// Log level based on status code
	if statusCode >= 500 {
		ErrorWithContext(message, context, nil)
	} else if statusCode >= 400 {
		WarnWithContext(message, context)
	} else {
		InfoWithContext(message, context)
	}
}

// Database operation logging

// LogDatabaseOperation logs database operations
func LogDatabaseOperation(operation, table string, duration time.Duration, rowsAffected int64, err error) {
	context := NewLogContext("database").
		WithOperation(operation).
		WithDuration(duration).
		WithMetadata("table", table).
		WithMetadata("rows_affected", rowsAffected)

	if err != nil {
		ErrorWithContext(fmt.Sprintf("Database operation failed: %s", operation), context, err)
	} else {
		if duration > 100*time.Millisecond {
			WarnWithContext(fmt.Sprintf("Slow database operation: %s", operation), context)
		} else {
			DebugWithContext(fmt.Sprintf("Database operation completed: %s", operation), context)
		}
	}
}

// Security logging

// LogSecurityEvent logs security-related events
func LogSecurityEvent(eventType, userID, ipAddress, details string) {
	context := NewLogContext("security").
		WithUser(userID).
		WithMetadata("event_type", eventType).
		WithMetadata("ip_address", ipAddress).
		WithMetadata("details", details)

	WarnWithContext(fmt.Sprintf("Security event: %s", eventType), context)
}

// LogAuthenticationAttempt logs authentication attempts
func LogAuthenticationAttempt(userID, ipAddress string, success bool, reason string) {
	context := NewLogContext("auth").
		WithUser(userID).
		WithMetadata("ip_address", ipAddress).
		WithMetadata("success", success).
		WithMetadata("reason", reason)

	if success {
		InfoWithContext("Authentication successful", context)
	} else {
		WarnWithContext("Authentication failed", context)
	}
}

// Performance monitoring

// LogPerformanceMetric logs performance metrics
func LogPerformanceMetric(component, metric string, value interface{}, unit string) {
	context := NewLogContext("performance").
		WithOperation(metric).
		WithMetadata("value", value).
		WithMetadata("unit", unit).
		WithMetadata("metric_name", metric)

	InfoWithContext(fmt.Sprintf("Performance metric: %s = %v %s", metric, value, unit), context)
}