package tmux

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
)

// Client handles tmux command execution
type Client struct {
	binDir string // Path to nunchux bin directory for nunchux-run wrapper
}

// NewClient creates a new tmux client
func NewClient(binDir string) *Client {
	return &Client{binDir: binDir}
}

// InSession checks if we're running inside a tmux session
func InSession() bool {
	return os.Getenv("TMUX") != ""
}

// IsAvailable checks if tmux is installed
func IsAvailable() bool {
	_, err := exec.LookPath("tmux")
	return err == nil
}

// ListWindows returns list of window names in the current session
func (c *Client) ListWindows() ([]string, error) {
	output, err := exec.Command("tmux", "list-windows", "-F", "#{window_name}").Output()
	if err != nil {
		return nil, err
	}
	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	if len(lines) == 1 && lines[0] == "" {
		return nil, nil
	}
	return lines, nil
}

// WindowInfo contains information about a tmux window
type WindowInfo struct {
	Index  int
	Name   string
	Active bool
}

// ListWindowsInfo returns list of windows with index and active state
func (c *Client) ListWindowsInfo() ([]WindowInfo, error) {
	output, err := exec.Command("tmux", "list-windows", "-F", "#{window_index}\t#{window_name}\t#{window_active}").Output()
	if err != nil {
		return nil, err
	}
	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	if len(lines) == 1 && lines[0] == "" {
		return nil, nil
	}

	var windows []WindowInfo
	for _, line := range lines {
		parts := strings.Split(line, "\t")
		if len(parts) < 3 {
			continue
		}
		var index int
		fmt.Sscanf(parts[0], "%d", &index)
		windows = append(windows, WindowInfo{
			Index:  index,
			Name:   parts[1],
			Active: parts[2] == "1",
		})
	}
	return windows, nil
}

// SessionInfo contains information about a tmux session
type SessionInfo struct {
	Name     string
	Attached bool
	Current  bool
}

// ListSessionsInfo returns list of sessions with attached state
func (c *Client) ListSessionsInfo() ([]SessionInfo, error) {
	// Get current session name
	currentSession, _ := exec.Command("tmux", "display-message", "-p", "#{session_name}").Output()
	currentName := strings.TrimSpace(string(currentSession))

	output, err := exec.Command("tmux", "list-sessions", "-F", "#{session_name}\t#{session_attached}").Output()
	if err != nil {
		return nil, err
	}
	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	if len(lines) == 1 && lines[0] == "" {
		return nil, nil
	}

	var sessions []SessionInfo
	for _, line := range lines {
		parts := strings.Split(line, "\t")
		if len(parts) < 2 {
			continue
		}
		sessions = append(sessions, SessionInfo{
			Name:     parts[0],
			Attached: parts[1] != "0",
			Current:  parts[0] == currentName,
		})
	}
	return sessions, nil
}

// SwitchSession switches to a different tmux session
func (c *Client) SwitchSession(name string) error {
	return exec.Command("tmux", "switch-client", "-t", name).Run()
}

// RunningWindows returns a map of running window names for efficient lookup
func (c *Client) RunningWindows() map[string]bool {
	windows, err := c.ListWindows()
	if err != nil {
		return nil
	}
	result := make(map[string]bool)
	for _, w := range windows {
		result[w] = true
	}
	return result
}

// IsWindowRunning checks if a window with the given name exists
func (c *Client) IsWindowRunning(name string) bool {
	windows, err := c.ListWindows()
	if err != nil {
		return false
	}
	for _, w := range windows {
		if w == name {
			return true
		}
	}
	return false
}

// GetCurrentPath returns the current pane's working directory
func (c *Client) GetCurrentPath() (string, error) {
	output, err := exec.Command("tmux", "display-message", "-p", "#{pane_current_path}").Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(output)), nil
}

// GetPaneID returns the current pane ID
func (c *Client) GetPaneID() (string, error) {
	output, err := exec.Command("tmux", "display-message", "-p", "#{pane_id}").Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(output)), nil
}

// SelectWindow switches to a window by name
func (c *Client) SelectWindow(name string) error {
	return exec.Command("tmux", "select-window", "-t", name).Run()
}

// KillWindow kills a window by name
func (c *Client) KillWindow(name string) error {
	return exec.Command("tmux", "kill-window", "-t", name).Run()
}

// Run executes a tmux command
func (c *Client) Run(args ...string) error {
	return exec.Command("tmux", args...).Run()
}

// RunOutput executes a tmux command and returns output
func (c *Client) RunOutput(args ...string) (string, error) {
	output, err := exec.Command("tmux", args...).Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(output)), nil
}

// WrapCommand wraps a command with the nunchux-run environment wrapper
func (c *Client) WrapCommand(cmd string) string {
	if c.binDir != "" {
		return c.binDir + "/nunchux-run bash -c " + shellQuote(cmd)
	}
	return "bash -c " + shellQuote(cmd)
}

// shellQuote quotes a string for safe shell usage
func shellQuote(s string) string {
	// Use single quotes and escape any single quotes in the string
	return "'" + strings.ReplaceAll(s, "'", "'\"'\"'") + "'"
}
