package http

import (
	"github.com/azukaar/sumika/server/services"
)

// Global service references for HTTP handlers
var (
	sceneService      *services.SceneService
	automationService *services.AutomationService
	voiceService      *services.VoiceService
)

// InitServices initializes ALL HTTP handlers with service dependencies
func InitServices(scene *services.SceneService, automation *services.AutomationService, voice *services.VoiceService) {
	sceneService = scene
	automationService = automation
	voiceService = voice
}