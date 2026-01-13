package tmux

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"nunchux/internal/config"
)

// LaunchOptions contains options for launching an app/command
type LaunchOptions struct {
	Action       config.Action
	Name         string // Window/popup title
	Cmd          string // Command to execute
	Dir          string // Working directory
	Width        string // Popup width
	Height       string // Popup height
	MaxWidth     string // Maximum width (absolute columns)
	MaxHeight    string // Maximum height (absolute rows)
	OnExit       string // Command to run after exit (apps only)
	IsApp        bool   // Whether this is an app (enables error handling)
	IsTaskrunner bool   // Whether this is a taskrunner command
	ReuseWindow  bool   // Reuse existing window instead of creating new one
	RunningIcon  string // Icon to show while running
	SuccessIcon  string // Icon to show on success
	FailedIcon   string // Icon to show on failure
}

// Launch executes a command with the specified action
func (c *Client) Launch(opts LaunchOptions) error {
	// Default directory to current pane path
	if opts.Dir == "" {
		var err error
		opts.Dir, err = c.GetCurrentPath()
		if err != nil {
			opts.Dir, _ = os.Getwd()
		}
	}

	// Default dimensions
	if opts.Width == "" {
		opts.Width = "90%"
	}
	if opts.Height == "" {
		opts.Height = "90%"
	}

	// Add % suffix if just a number
	if !strings.HasSuffix(opts.Width, "%") && isNumeric(opts.Width) {
		opts.Width = opts.Width + "%"
	}
	if !strings.HasSuffix(opts.Height, "%") && isNumeric(opts.Height) {
		opts.Height = opts.Height + "%"
	}

	// Clamp dimensions to max values if set
	opts.Width, opts.Height = c.clampDimensions(opts.Width, opts.Height, opts.MaxWidth, opts.MaxHeight)

	switch opts.Action {
	case config.ActionPopup:
		return c.launchPopup(opts)
	case config.ActionWindow:
		return c.launchWindow(opts, false)
	case config.ActionBackgroundWindow:
		return c.launchWindow(opts, true)
	case config.ActionPaneRight:
		return c.launchPane(opts, "-h", false)
	case config.ActionPaneLeft:
		return c.launchPane(opts, "-h", true)
	case config.ActionPaneBelow:
		return c.launchPane(opts, "-v", false)
	case config.ActionPaneAbove:
		return c.launchPane(opts, "-v", true)
	default:
		return fmt.Errorf("unknown action: %s", opts.Action)
	}
}

func (c *Client) launchPopup(opts LaunchOptions) error {
	script, err := c.createPopupScript(opts)
	if err != nil {
		return err
	}

	title := fmt.Sprintf(" nunchux: %s ", opts.Name)

	// Use tmux run-shell with sleep to avoid race condition
	cmd := fmt.Sprintf("sleep 0.05; tmux display-popup -E -b rounded -T '%s' -w '%s' -h '%s' '%s'",
		title, opts.Width, opts.Height, script)

	return exec.Command("tmux", "run-shell", "-b", cmd).Run()
}

func (c *Client) launchWindow(opts LaunchOptions, background bool) error {
	// For taskrunners with existing window, use respawn-window
	if opts.IsTaskrunner && opts.ReuseWindow {
		return c.respawnTaskrunnerWindow(opts, background)
	}

	windowName := opts.Name
	if opts.IsTaskrunner && opts.RunningIcon != "" {
		windowName = opts.Name + " " + opts.RunningIcon
	}

	args := []string{"new-window", "-n", windowName}
	if opts.Dir != "" {
		args = append(args, "-c", opts.Dir)
	}
	if background {
		args = append(args, "-d")
	}
	args = append(args, c.WrapCommand(opts.Cmd))

	cmd := exec.Command("tmux", args...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("new-window failed: %v: %s (args: %v)", err, string(output), args)
	}
	return nil
}

func (c *Client) respawnTaskrunnerWindow(opts LaunchOptions, background bool) error {
	// Find existing window by name prefix (might have icon suffix)
	windowID, err := c.findWindowByPrefix(opts.Name)
	if err != nil || windowID == "" {
		// No existing window, create new one
		return c.launchWindow(LaunchOptions{
			Action:       opts.Action,
			Name:         opts.Name,
			Cmd:          opts.Cmd,
			Dir:          opts.Dir,
			Width:        opts.Width,
			Height:       opts.Height,
			IsTaskrunner: true,
			ReuseWindow:  false, // Prevent recursion
			RunningIcon:  opts.RunningIcon,
		}, background)
	}

	// Remember current window
	currentWindow, _ := c.RunOutput("display-message", "-p", "#{window_id}")

	windowName := opts.Name
	if opts.RunningIcon != "" {
		windowName = opts.Name + " " + opts.RunningIcon
	}

	// Rename and respawn existing window
	exec.Command("tmux", "rename-window", "-t", windowID, windowName).Run()
	err = exec.Command("tmux", "respawn-window", "-k", "-t", windowID, "-c", opts.Dir, c.WrapCommand(opts.Cmd)).Run()
	if err != nil {
		return err
	}

	if !background {
		return exec.Command("tmux", "select-window", "-t", windowID).Run()
	}
	// Background: stay on current window
	if currentWindow != "" {
		exec.Command("tmux", "select-window", "-t", currentWindow).Run()
	}
	return nil
}

func (c *Client) findWindowByPrefix(prefix string) (string, error) {
	output, err := exec.Command("tmux", "list-windows", "-F", "#{window_id} #{window_name}").Output()
	if err != nil {
		return "", err
	}

	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	for _, line := range lines {
		parts := strings.SplitN(line, " ", 2)
		if len(parts) < 2 {
			continue
		}
		windowID := parts[0]
		windowName := parts[1]
		if strings.HasPrefix(windowName, prefix) {
			return windowID, nil
		}
	}
	return "", nil
}

func (c *Client) launchPane(opts LaunchOptions, direction string, before bool) error {
	args := []string{"split-window", direction}
	if before {
		args = append(args, "-b")
	}
	args = append(args, "-c", opts.Dir, c.WrapCommand(opts.Cmd))

	return exec.Command("tmux", args...).Run()
}

func (c *Client) createPopupScript(opts LaunchOptions) (string, error) {
	script := filepath.Join(os.TempDir(), fmt.Sprintf("nunchux-popup-%d", os.Getpid()))

	// Substitute variables in cmd and on_exit
	paneID, _ := c.GetPaneID()
	tmpFile := filepath.Join(os.TempDir(), fmt.Sprintf("nunchux-tmp-%d", os.Getpid()))

	cmd := opts.Cmd
	cmd = strings.ReplaceAll(cmd, "{pane_id}", paneID)
	cmd = strings.ReplaceAll(cmd, "{tmp}", tmpFile)
	cmd = strings.ReplaceAll(cmd, "{dir}", opts.Dir)

	onExit := opts.OnExit
	onExit = strings.ReplaceAll(onExit, "{pane_id}", paneID)
	onExit = strings.ReplaceAll(onExit, "{tmp}", tmpFile)
	onExit = strings.ReplaceAll(onExit, "{dir}", opts.Dir)

	var content strings.Builder
	content.WriteString("#!/usr/bin/env bash\n")

	// Source nunchux-run for environment inheritance if available
	if c.binDir != "" {
		content.WriteString(fmt.Sprintf("source \"%s/nunchux-run\" 2>/dev/null || true\n", c.binDir))
		content.WriteString(fmt.Sprintf("export PATH=\"%s:$PATH\"\n", c.binDir))
	}

	content.WriteString(fmt.Sprintf("cd \"%s\"\n\n", opts.Dir))

	if opts.IsApp {
		// App popup: error handling with Chuck Norris facts
		content.WriteString("# Run the command (suppress stderr, we show our own error)\n")
		content.WriteString(fmt.Sprintf("%s 2>/dev/null\n", cmd))
		content.WriteString("exit_code=$?\n\n")

		if onExit != "" {
			content.WriteString("# Run on_exit if defined\n")
			content.WriteString(onExit + "\n\n")
		}

		content.WriteString("# If command failed, show error with Chuck Norris fact\n")
		content.WriteString("if [[ $exit_code -ne 0 ]]; then\n")
		content.WriteString("    echo \"\"\n")
		content.WriteString("    echo -e \"\\033[1;33m$(random_chuck_fact)\\033[0m\"\n")
		content.WriteString("    echo \"\"\n")
		content.WriteString("    echo -e \"\\033[90m... but you are not Chuck Norris :)\\033[0m\"\n")
		content.WriteString("    echo \"\"\n")
		content.WriteString("    if [[ $exit_code -eq 127 ]]; then\n")
		content.WriteString(fmt.Sprintf("        echo -e \"\\033[1;31mCommand not found: %s\\033[0m\"\n", opts.Name))
		content.WriteString("    else\n")
		content.WriteString(fmt.Sprintf("        echo -e \"\\033[1;31m%s exited with code $exit_code\\033[0m\"\n", opts.Name))
		content.WriteString("    fi\n")
		content.WriteString("    echo \"\"\n")
		content.WriteString("    echo \"Press any key...\"\n")
		content.WriteString("    read -n 1 -s\n")
		content.WriteString("fi\n")
	} else {
		// Simple popup (dirbrowser, etc.)
		content.WriteString(cmd + "\n")
	}

	content.WriteString(fmt.Sprintf("rm -f \"%s\"\n", script))

	err := os.WriteFile(script, []byte(content.String()), 0755)
	if err != nil {
		return "", err
	}

	return script, nil
}

func isNumeric(s string) bool {
	for _, c := range s {
		if c < '0' || c > '9' {
			return false
		}
	}
	return len(s) > 0
}

// clampDimensions clamps width/height to max values if set
// If dimensions are percentages, they're converted to absolute values and compared to max
func (c *Client) clampDimensions(width, height, maxWidth, maxHeight string) (string, string) {
	// Get terminal dimensions
	termWidth, termHeight := c.getTerminalSize()

	// Clamp width
	if maxWidth != "" && strings.HasSuffix(width, "%") {
		maxW := parseNum(maxWidth)
		if maxW > 0 && termWidth > 0 {
			pct := parseNum(strings.TrimSuffix(width, "%"))
			absWidth := termWidth * pct / 100
			if absWidth > maxW {
				width = maxWidth
			}
		}
	}

	// Clamp height
	if maxHeight != "" && strings.HasSuffix(height, "%") {
		maxH := parseNum(maxHeight)
		if maxH > 0 && termHeight > 0 {
			pct := parseNum(strings.TrimSuffix(height, "%"))
			absHeight := termHeight * pct / 100
			if absHeight > maxH {
				height = maxHeight
			}
		}
	}

	return width, height
}

// getTerminalSize returns the terminal width and height in columns/rows
func (c *Client) getTerminalSize() (int, int) {
	widthOut, err := exec.Command("tmux", "display-message", "-p", "#{window_width}").Output()
	if err != nil {
		return 0, 0
	}
	heightOut, err := exec.Command("tmux", "display-message", "-p", "#{window_height}").Output()
	if err != nil {
		return 0, 0
	}

	width := parseNum(strings.TrimSpace(string(widthOut)))
	height := parseNum(strings.TrimSpace(string(heightOut)))
	return width, height
}

// parseNum parses a string as an integer, returning 0 on failure
func parseNum(s string) int {
	var n int
	for _, c := range s {
		if c >= '0' && c <= '9' {
			n = n*10 + int(c-'0')
		} else {
			break
		}
	}
	return n
}
