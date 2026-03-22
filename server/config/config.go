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
	Server   ServerConfig   `json:"server"`
	Logging  LoggingConfig  `json:"logging"`
	Database DatabaseConfig `json:"database"`
	Voice    VoiceConfig    `json:"voice"`
	Weather  WeatherConfig  `json:"weather"`
	Debug    DebugConfig    `json:"debug"`
}

// ServerConfig holds server-specific configuration
type ServerConfig struct {
	Host           string        `json:"host"`
	Port           int           `json:"port"`
	ReadTimeout    time.Duration `json:"read_timeout"`
	WriteTimeout   time.Duration `json:"write_timeout"`
	IdleTimeout    time.Duration `json:"idle_timeout"`
	MaxHeaderBytes int           `json:"max_header_bytes"`
	Timezone       string        `json:"timezone"`
}

// LoggingConfig holds logging configuration
type LoggingConfig struct {
	Level string `json:"level"`
}

// DatabaseConfig holds database configuration
type DatabaseConfig struct {
	DataDirectory string `json:"data_directory"`
}

// VoiceConfig holds voice recognition configuration
type VoiceConfig struct {
	Enabled                bool    `json:"enabled"`
	WhisperModel           string  `json:"whisper_model"`
	WhisperDevice          string  `json:"whisper_device"`
	ComputeType            string  `json:"compute_type"`
	InputDevice            string  `json:"input_device"`
	OutputDevice           string  `json:"output_device"`
	WakeThreshold          float64 `json:"wake_threshold"`
	EchoCancellation bool `json:"echo_cancellation"`
}

// WeatherConfig holds weather configuration
type WeatherConfig struct {
	Enabled   bool    `json:"enabled"`
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
	Location  string  `json:"location"`
}

// DebugConfig holds debug and development settings
type DebugConfig struct {
	Enabled bool `json:"enabled"`
}

// Global configuration instance
var globalConfig *Config

// Load loads configuration from file and environment variables
func Load(configPath string) (*Config, error) {
	config := getDefaultConfig()
	fileLoaded := false

	// Load from file if it exists
	if configPath != "" {
		if err := loadFromFile(config, configPath); err != nil {
			return nil, fmt.Errorf("failed to load config from file: %w", err)
		} else {
			// Check if file actually existed and was loaded
			if _, err := os.Stat(configPath); err == nil {
				fileLoaded = true
			}
		}
	}

	// Override with environment variables
	loadFromEnvironment(config)

	// Validate configuration
	if err := validateConfig(config); err != nil {
		return nil, fmt.Errorf("configuration validation failed: %w", err)
	}

	// Save default configuration to file if no config file was found
	if configPath != "" && !fileLoaded {
		if err := SaveConfig(config, configPath); err != nil {
			return nil, fmt.Errorf("failed to save default config to file: %w", err)
		}
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
	// Get timezone from environment, default to UTC
	timezone := os.Getenv("TZ")
	if timezone == "" {
		timezone = "UTC"
	}

	return &Config{
		Server: ServerConfig{
			Host:           "0.0.0.0",
			Port:           8081,
			ReadTimeout:    15 * time.Second,
			WriteTimeout:   15 * time.Second,
			IdleTimeout:    60 * time.Second,
			MaxHeaderBytes: 1 << 20, // 1MB
			Timezone:       timezone,
		},
		Logging: LoggingConfig{
			Level: "INFO",
		},
		Database: DatabaseConfig{
			DataDirectory: "./build-data",
		},
		Voice: VoiceConfig{
			Enabled:                 true,
			WhisperModel:            "base",
			WhisperDevice:           "cpu",
			ComputeType:             "int8",
			InputDevice:             "default",
			OutputDevice:            "default",
			WakeThreshold:           0.5,
			EchoCancellation: false,
		},
		Weather: WeatherConfig{
			Enabled:   false,
			Latitude:  0.0,
			Longitude: 0.0,
			Location:  "",
		},
		Debug: DebugConfig{
			Enabled: false,
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
	if timezone := os.Getenv("SUMIKA_TIMEZONE"); timezone != "" {
		config.Server.Timezone = timezone
	}

	// Logging configuration
	if level := os.Getenv("SUMIKA_LOG_LEVEL"); level != "" {
		config.Logging.Level = level
	}

	// Database configuration
	if dataDir := os.Getenv("SUMIKA_DATA_DIR"); dataDir != "" {
		config.Database.DataDirectory = dataDir
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
	if ec := os.Getenv("SUMIKA_ECHO_CANCELLATION"); ec != "" {
		config.Voice.EchoCancellation = ec == "true"
	}

	// Weather configuration
	if enabled := os.Getenv("SUMIKA_WEATHER_ENABLED"); enabled != "" {
		config.Weather.Enabled = enabled == "true"
	}
	if latitude := os.Getenv("SUMIKA_WEATHER_LATITUDE"); latitude != "" {
		if lat, err := strconv.ParseFloat(latitude, 64); err == nil {
			config.Weather.Latitude = lat
		}
	}
	if longitude := os.Getenv("SUMIKA_WEATHER_LONGITUDE"); longitude != "" {
		if lon, err := strconv.ParseFloat(longitude, 64); err == nil {
			config.Weather.Longitude = lon
		}
	}
	if location := os.Getenv("SUMIKA_WEATHER_LOCATION"); location != "" {
		config.Weather.Location = location
	}

	// Debug configuration
	if debug := os.Getenv("SUMIKA_DEBUG"); debug != "" {
		config.Debug.Enabled = debug == "true"
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

// IsDevelopment returns true if running in development mode
func IsDevelopment() bool {
	return GetConfig().Debug.Enabled
}

// IsProduction returns true if running in production mode
func IsProduction() bool {
	return !IsDevelopment()
}

// GetConfigFilePath returns the default path for the config file
func GetConfigFilePath() string {
	// Use default data directory since we can't rely on loaded config
	return filepath.Join("./build-data", "sumika.json")
}
