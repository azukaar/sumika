package utils

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// LoadDotEnv reads a .env file and sets environment variables that are not
// already set. It checks the working directory first, then the executable
// directory.
func LoadDotEnv() {
	candidates := []string{".env"}
	if execPath, err := os.Executable(); err == nil {
		candidates = append(candidates, filepath.Join(filepath.Dir(execPath), ".env"))
	}

	var data []byte
	for _, path := range candidates {
		var err error
		data, err = os.ReadFile(path)
		if err == nil {
			Debug(fmt.Sprintf("Loaded .env from %s", path))
			break
		}
	}
	if data == nil {
		return
	}

	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}
		key := strings.TrimSpace(parts[0])
		val := strings.TrimSpace(parts[1])
		val = strings.Trim(val, `"'`)
		if os.Getenv(key) == "" {
			os.Setenv(key, val)
		}
	}
}
