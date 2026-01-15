package config

import (
	"bufio"
	"os"
	"path/filepath"
	"strings"
)

// GetTrustedConfigsPath returns the path to the trusted configs file
func GetTrustedConfigsPath() string {
	stateDir := os.Getenv("XDG_STATE_HOME")
	if stateDir == "" {
		home, _ := os.UserHomeDir()
		stateDir = filepath.Join(home, ".local", "state")
	}
	return filepath.Join(stateDir, "nunchux", "trusted_configs")
}

// IsConfigTrusted checks if a config path is in the trusted list
func IsConfigTrusted(configPath string) bool {
	trustedFile := GetTrustedConfigsPath()

	file, err := os.Open(trustedFile)
	if err != nil {
		return false // File doesn't exist or can't be read
	}
	defer file.Close()

	// Normalize the path for comparison
	absPath, err := filepath.Abs(configPath)
	if err != nil {
		absPath = configPath
	}

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		if line == absPath {
			return true
		}
	}

	return false
}

// TrustConfig adds a config path to the trusted list
func TrustConfig(configPath string) error {
	trustedFile := GetTrustedConfigsPath()

	// Create directory if needed
	dir := filepath.Dir(trustedFile)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}

	// Normalize the path
	absPath, err := filepath.Abs(configPath)
	if err != nil {
		absPath = configPath
	}

	// Check if already trusted
	if IsConfigTrusted(absPath) {
		return nil
	}

	// Append to file
	file, err := os.OpenFile(trustedFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return err
	}
	defer file.Close()

	_, err = file.WriteString(absPath + "\n")
	return err
}
