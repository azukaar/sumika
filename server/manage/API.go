package manage

// API entry point - all API handlers have been split into domain-specific files:
//
// - zones_api.go: Zone management endpoints
// - automations_api.go: Automation CRUD endpoints  
// - device_metadata_api.go: Device metadata endpoints
// - scenes_api.go: Scene operation endpoints
// - scene_management_api.go: Advanced scene management (existing)
//
// All handlers use the standardized response helpers from server/http/response.go

// Re-export all API functions for backward compatibility
// Zone API functions are in zones_api.go
// Automation API functions are in automations_api.go  
// Device metadata API functions are in device_metadata_api.go
// Scene API functions are in scenes_api.go