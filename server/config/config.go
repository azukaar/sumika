package config

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"time"
)

// Config holds all application configuration
type Config struct {
	// Server configuration
	Server ServerConfig `json:"server"`
	
	// Logging configuration
	Logging LoggingConfig `json:"logging"`
	
	// Database configuration
	Database DatabaseConfig `json:"database"`
	
	// API configuration
	API APIConfig `json:"api"`
	
	// WebSocket configuration
	WebSocket WebSocketConfig `json:"websocket"`
	
	// Zigbee configuration
	Zigbee ZigbeeConfig `json:"zigbee"`
	
	// Voice recognition configuration
	Voice VoiceConfig `json:"voice"`
	
	// Development/Debug settings
	Debug DebugConfig `json:"debug"`
}

// ServerConfig holds server-specific configuration
type ServerConfig struct {
	Host           string        `json:"host"`
	Port           int           `json:"port"`
	ReadTimeout    time.Duration `json:"read_timeout"`
	WriteTimeout   time.Duration `json:"write_timeout"`
	IdleTimeout    time.Duration `json:"idle_timeout"`
	MaxHeaderBytes int           `json:"max_header_bytes"`
	TLSEnabled     bool          `json:"tls_enabled"`
	CertFile       string        `json:"cert_file"`
	KeyFile        string        `json:"key_file"`
	CORSEnabled    bool          `json:"cors_enabled"`
	CORSOrigins    []string      `json:"cors_origins"`
}

// LoggingConfig holds logging configuration
type LoggingConfig struct {
	Level           string `json:"level"`
	OutputFile      string `json:"output_file"`
	ErrorFile       string `json:"error_file"`
	MaxFileSize     int    `json:"max_file_size_mb"`
	MaxBackups      int    `json:"max_backups"`
	MaxAge          int    `json:"max_age_days"`
	Compress        bool   `json:"compress"`
	StructuredLogs  bool   `json:"structured_logs"`
	ConsoleOutput   bool   `json:"console_output"`
	ColorOutput     bool   `json:"color_output"`
}

// DatabaseConfig holds database configuration
type DatabaseConfig struct {
	Type             string        `json:"type"`
	DataDirectory    string        `json:"data_directory"`
	BackupDirectory  string        `json:"backup_directory"`
	BackupInterval   time.Duration `json:"backup_interval"`
	RetentionDays    int           `json:"retention_days"`
	SyncInterval     time.Duration `json:"sync_interval"`
	PermissionMode   os.FileMode   `json:"permission_mode"`
}

// APIConfig holds API configuration
type APIConfig struct {
	RateLimitEnabled bool          `json:"rate_limit_enabled"`
	RateLimitRPS     int           `json:"rate_limit_rps"`
	RequestTimeout   time.Duration `json:"request_timeout"`
	MaxRequestSize   int64         `json:"max_request_size_bytes"`
	EnableMetrics    bool          `json:"enable_metrics"`
	MetricsPath      string        `json:"metrics_path"`
}

// WebSocketConfig holds WebSocket configuration
type WebSocketConfig struct {
	Enabled         bool          `json:"enabled"`
	ReadBufferSize  int           `json:"read_buffer_size"`
	WriteBufferSize int           `json:"write_buffer_size"`
	HandshakeTimeout time.Duration `json:"handshake_timeout"`
	PingInterval    time.Duration `json:"ping_interval"`
	PongWait        time.Duration `json:"pong_wait"`
	MaxConnections  int           `json:"max_connections"`
}

// ZigbeeConfig holds Zigbee/MQTT configuration
type ZigbeeConfig struct {
	Enabled       bool   `json:"enabled"`
	MQTTBroker    string `json:"mqtt_broker"`
	MQTTPort      int    `json:"mqtt_port"`
	MQTTUser      string `json:"mqtt_user"`
	MQTTPassword  string `json:"mqtt_password"`
	BaseTopic     string `json:"base_topic"`
	DeviceTopic   string `json:"device_topic"`
	StatusTopic   string `json:"status_topic"`
	CommandTopic  string `json:"command_topic"`
}

// VoiceConfig holds voice recognition configuration
type VoiceConfig struct {
	Enabled       bool    `json:"enabled"`
	WhisperModel  string  `json:"whisper_model"`
	WhisperDevice string  `json:"whisper_device"`
	ComputeType   string  `json:"compute_type"`
	InputDevice   string  `json:"input_device"`
	OutputDevice  string  `json:"output_device"`
	WakeThreshold float64 `json:"wake_threshold"`
}

// DebugConfig holds debug and development settings
type DebugConfig struct {
	Enabled                bool `json:"enabled"`
	ShowInternalErrors     bool `json:"show_internal_errors"`
	EnableProfiling        bool `json:"enable_profiling"`
	ProfilingPort          int  `json:"profiling_port"`
	EnableDebugEndpoints   bool `json:"enable_debug_endpoints"`
	LogStackTraces         bool `json:"log_stack_traces"`
	DetailedErrorResponses bool `json:"detailed_error_responses"`
}

// Global configuration instance
var globalConfig *Config

// Load loads configuration from file and environment variables
func Load(configPath string) (*Config, error) {
	config := getDefaultConfig()

	// Load from file if it exists
	if configPath != "" {
		if err := loadFromFile(config, configPath); err != nil {
			return nil, fmt.Errorf("failed to load config from file: %w", err)
		}
	}

	// Override with environment variables
	loadFromEnvironment(config)

	// Validate configuration
	if err := validateConfig(config); err != nil {
		return nil, fmt.Errorf("configuration validation failed: %w", err)
	}

	globalConfig = config
	return config, nil
}

// GetConfig returns the global configuration instance
func GetConfig() *Config {
	if globalConfig == nil {
		// Return default config if none loaded
		globalConfig = getDefaultConfig()
	}
	return globalConfig
}

// getDefaultConfig returns configuration with default values
func getDefaultConfig() *Config {
	return &Config{
		Server: ServerConfig{
			Host:           "localhost",
			Port:           8080,
			ReadTimeout:    15 * time.Second,
			WriteTimeout:   15 * time.Second,
			IdleTimeout:    60 * time.Second,
			MaxHeaderBytes: 1 << 20, // 1MB
			TLSEnabled:     false,
			CertFile:       "",
			KeyFile:        "",
			CORSEnabled:    true,
			CORSOrigins:    []string{"*"},
		},
		Logging: LoggingConfig{
			Level:          "INFO",
			OutputFile:     "./sumika.log",
			ErrorFile:      "./sumika.error.log",
			MaxFileSize:    15,
			MaxBackups:     2,
			MaxAge:         16,
			Compress:       true,
			StructuredLogs: true,
			ConsoleOutput:  true,
			ColorOutput:    true,
		},
		Database: DatabaseConfig{
			Type:            "json_file",
			DataDirectory:   "./build-data",
			BackupDirectory: "./backups",
			BackupInterval:  24 * time.Hour,
			RetentionDays:   30,
			SyncInterval:    5 * time.Minute,
			PermissionMode:  0644,
		},
		API: APIConfig{
			RateLimitEnabled: false,
			RateLimitRPS:     100,
			RequestTimeout:   30 * time.Second,
			MaxRequestSize:   10 << 20, // 10MB
			EnableMetrics:    false,
			MetricsPath:      "/metrics",
		},
		WebSocket: WebSocketConfig{
			Enabled:         true,
			ReadBufferSize:  1024,
			WriteBufferSize: 1024,
			HandshakeTimeout: 10 * time.Second,
			PingInterval:    54 * time.Second,
			PongWait:        60 * time.Second,
			MaxConnections:  100,
		},
		Zigbee: ZigbeeConfig{
			Enabled:      true,
			MQTTBroker:   "localhost",
			MQTTPort:     1883,
			MQTTUser:     "",
			MQTTPassword: "",
			BaseTopic:    "zigbee2mqtt",
			DeviceTopic:  "zigbee2mqtt/devices",
			StatusTopic:  "zigbee2mqtt/bridge/state",
			CommandTopic: "zigbee2mqtt/bridge/request",
		},
		Voice: VoiceConfig{
			Enabled:       true,
			WhisperModel:  "base",
			WhisperDevice: "cpu",
			ComputeType:   "int8",
			InputDevice:   "default",
			OutputDevice:  "default",
			WakeThreshold: 0.5,
		},
		Debug: DebugConfig{
			Enabled:                false,
			ShowInternalErrors:     false,
			EnableProfiling:        false,
			ProfilingPort:          6060,
			EnableDebugEndpoints:   false,
			LogStackTraces:         false,
			DetailedErrorResponses: false,
		},
	}
}

// loadFromFile loads configuration from JSON file
func loadFromFile(config *Config, filePath string) error {
	if _, err := os.Stat(filePath); os.IsNotExist(err) {
		return nil // File doesn't exist, skip
	}

	data, err := os.ReadFile(filePath)
	if err != nil {
		return err
	}

	return json.Unmarshal(data, config)
}

// loadFromEnvironment loads configuration from environment variables
func loadFromEnvironment(config *Config) {
	// Server configuration
	if host := os.Getenv("SUMIKA_HOST"); host != "" {
		config.Server.Host = host
	}
	if port := os.Getenv("SUMIKA_PORT"); port != "" {
		if p, err := strconv.Atoi(port); err == nil {
			config.Server.Port = p
		}
	}
	if cors := os.Getenv("SUMIKA_CORS_ENABLED"); cors != "" {
		config.Server.CORSEnabled = cors == "true"
	}

	// Logging configuration
	if level := os.Getenv("SUMIKA_LOG_LEVEL"); level != "" {
		config.Logging.Level = level
	}
	if file := os.Getenv("SUMIKA_LOG_FILE"); file != "" {
		config.Logging.OutputFile = file
	}
	if structured := os.Getenv("SUMIKA_STRUCTURED_LOGS"); structured != "" {
		config.Logging.StructuredLogs = structured == "true"
	}

	// Database configuration
	if dataDir := os.Getenv("SUMIKA_DATA_DIR"); dataDir != "" {
		config.Database.DataDirectory = dataDir
	}
	if backupDir := os.Getenv("SUMIKA_BACKUP_DIR"); backupDir != "" {
		config.Database.BackupDirectory = backupDir
	}

	// Zigbee configuration
	if broker := os.Getenv("SUMIKA_MQTT_BROKER"); broker != "" {
		config.Zigbee.MQTTBroker = broker
	}
	if port := os.Getenv("SUMIKA_MQTT_PORT"); port != "" {
		if p, err := strconv.Atoi(port); err == nil {
			config.Zigbee.MQTTPort = p
		}
	}
	if user := os.Getenv("SUMIKA_MQTT_USER"); user != "" {
		config.Zigbee.MQTTUser = user
	}
	if password := os.Getenv("SUMIKA_MQTT_PASSWORD"); password != "" {
		config.Zigbee.MQTTPassword = password
	}

	// Voice configuration
	if enabled := os.Getenv("SUMIKA_VOICE_ENABLED"); enabled != "" {
		config.Voice.Enabled = enabled == "true"
	}
	if model := os.Getenv("SUMIKA_WHISPER_MODEL"); model != "" {
		config.Voice.WhisperModel = model
	}
	if device := os.Getenv("SUMIKA_WHISPER_DEVICE"); device != "" {
		config.Voice.WhisperDevice = device
	}
	if computeType := os.Getenv("SUMIKA_COMPUTE_TYPE"); computeType != "" {
		config.Voice.ComputeType = computeType
	}
	if inputDevice := os.Getenv("SUMIKA_INPUT_DEVICE"); inputDevice != "" {
		config.Voice.InputDevice = inputDevice
	}
	if outputDevice := os.Getenv("SUMIKA_OUTPUT_DEVICE"); outputDevice != "" {
		config.Voice.OutputDevice = outputDevice
	}
	if threshold := os.Getenv("SUMIKA_WAKE_THRESHOLD"); threshold != "" {
		if t, err := strconv.ParseFloat(threshold, 64); err == nil {
			config.Voice.WakeThreshold = t
		}
	}

	// Debug configuration
	if debug := os.Getenv("SUMIKA_DEBUG"); debug != "" {
		config.Debug.Enabled = debug == "true"
	}
	if showErrors := os.Getenv("SUMIKA_SHOW_INTERNAL_ERRORS"); showErrors != "" {
		config.Debug.ShowInternalErrors = showErrors == "true"
	}
}

// validateConfig validates the configuration
func validateConfig(config *Config) error {
	// Validate server configuration
	if config.Server.Port < 1 || config.Server.Port > 65535 {
		return fmt.Errorf("invalid server port: %d", config.Server.Port)
	}

	// Validate logging level
	validLevels := []string{"DEBUG", "INFO", "WARNING", "ERROR", "FATAL"}
	levelValid := false
	for _, level := range validLevels {
		if config.Logging.Level == level {
			levelValid = true
			break
		}
	}
	if !levelValid {
		return fmt.Errorf("invalid logging level: %s", config.Logging.Level)
	}

	// Validate data directory
	if err := ensureDirectory(config.Database.DataDirectory); err != nil {
		return fmt.Errorf("invalid data directory: %w", err)
	}

	// Validate backup directory
	if err := ensureDirectory(config.Database.BackupDirectory); err != nil {
		return fmt.Errorf("invalid backup directory: %w", err)
	}

	return nil
}

// ensureDirectory creates directory if it doesn't exist
func ensureDirectory(path string) error {
	if path == "" {
		return fmt.Errorf("directory path cannot be empty")
	}

	absPath, err := filepath.Abs(path)
	if err != nil {
		return err
	}

	if err := os.MkdirAll(absPath, 0755); err != nil {
		return err
	}

	return nil
}

// SaveConfig saves the current configuration to file
func SaveConfig(config *Config, filePath string) error {
	data, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(filePath, data, 0644)
}

// GetDataPath returns the absolute path for data files
func GetDataPath(filename string) string {
	config := GetConfig()
	return filepath.Join(config.Database.DataDirectory, filename)
}

// GetBackupPath returns the absolute path for backup files
func GetBackupPath(filename string) string {
	config := GetConfig()
	return filepath.Join(config.Database.BackupDirectory, filename)
}

// IsDevelopment returns true if running in development mode
func IsDevelopment() bool {
	return GetConfig().Debug.Enabled
}

// IsProduction returns true if running in production mode
func IsProduction() bool {
	return !IsDevelopment()
}