package config

import (
	"bufio"
	"os"
	"path/filepath"
	"strings"
)

// GetTrustedConfigsPath returns the path to the trusted configs file
func GetTrustedConfigsPath() string {
	return filepath.Join(getStateDir(), "trusted_configs")
}

// GetBlockedConfigsPath returns the path to the blocked configs file
func GetBlockedConfigsPath() string {
	return filepath.Join(getStateDir(), "blocked_configs")
}

func getStateDir() string {
	stateDir := os.Getenv("XDG_STATE_HOME")
	if stateDir == "" {
		home, _ := os.UserHomeDir()
		stateDir = filepath.Join(home, ".local", "state")
	}
	return filepath.Join(stateDir, "nunchux")
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

// IsConfigBlocked checks if a config path is in the blocked list
func IsConfigBlocked(configPath string) bool {
	blockedFile := GetBlockedConfigsPath()

	file, err := os.Open(blockedFile)
	if err != nil {
		return false
	}
	defer file.Close()

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

// BlockConfig adds a config path to the blocked list
func BlockConfig(configPath string) error {
	blockedFile := GetBlockedConfigsPath()

	dir := filepath.Dir(blockedFile)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}

	absPath, err := filepath.Abs(configPath)
	if err != nil {
		absPath = configPath
	}

	if IsConfigBlocked(absPath) {
		return nil
	}

	file, err := os.OpenFile(blockedFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return err
	}
	defer file.Close()

	_, err = file.WriteString(absPath + "\n")
	return err
}
