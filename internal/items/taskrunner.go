package items

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"nunchux/internal/config"
)

// TaskrunnerTask represents a single task from a taskrunner
type TaskrunnerTask struct {
	TaskName    string // e.g., "build"
	Cmd         string // e.g., "just build"
	Description string
}

// TaskrunnerItem represents a taskrunner task as a menu item
type TaskrunnerItem struct {
	Runner   string // e.g., "just"
	Task     TaskrunnerTask
	Config   config.TaskrunnerConfig
	Settings *config.Settings
	Icon     string
	Label    string
}

// Ensure TaskrunnerItem implements Item
var _ Item = (*TaskrunnerItem)(nil)

func (t *TaskrunnerItem) Name() string {
	return t.Runner + ":" + t.Task.TaskName
}

func (t *TaskrunnerItem) Type() ItemType {
	return TypeTaskrunner
}

func (t *TaskrunnerItem) Shortcut() string {
	return "" // Taskrunner items don't have shortcuts
}

func (t *TaskrunnerItem) Parent() string {
	return "" // Taskrunners are always top-level
}

// DisplayName returns the formatted display name (label + task)
func (t *TaskrunnerItem) DisplayName() string {
	return t.Label + " " + t.Task.TaskName
}

func (t *TaskrunnerItem) FormatLine(ctx context.Context, isRunning bool) string {
	icon := t.Settings.IconStopped
	if isRunning {
		icon = t.Settings.TaskrunnerIconRunning
	}

	// Use \x00 as separator between name and desc for reliable parsing
	display := fmt.Sprintf("%s %s\x00%s", icon, t.DisplayName(), t.Task.Description)

	// Format: display\tshortcut\tname\tcmd
	return fmt.Sprintf("%s\t\t%s\t%s",
		display,
		t.Name(),
		t.Task.Cmd,
	)
}

// GetPrimaryAction returns the action for this taskrunner
func (t *TaskrunnerItem) GetPrimaryAction() config.Action {
	if t.Config.PrimaryAction != "" {
		return t.Config.PrimaryAction
	}
	// Default for taskrunners is window (not popup like apps)
	return config.ActionWindow
}

// GetSecondaryAction returns the secondary action for this taskrunner
func (t *TaskrunnerItem) GetSecondaryAction() config.Action {
	if t.Config.SecondaryAction != "" {
		return t.Config.SecondaryAction
	}
	return config.ActionBackgroundWindow
}

// WindowName returns the window name for tmux
func (t *TaskrunnerItem) WindowName() string {
	return t.Runner + " » " + t.Task.TaskName
}

// TaskrunnerDivider represents a divider line in the menu
type TaskrunnerDivider struct {
	Runner string
	Icon   string
	Label  string
}

func (d *TaskrunnerDivider) Name() string {
	return "divider:" + d.Runner
}

func (d *TaskrunnerDivider) Type() ItemType {
	return TypeTaskrunner
}

func (d *TaskrunnerDivider) Shortcut() string {
	return ""
}

func (d *TaskrunnerDivider) Parent() string {
	return ""
}

func (d *TaskrunnerDivider) DisplayName() string {
	return "" // Dividers don't contribute to width calculation
}

func (d *TaskrunnerDivider) FormatLine(ctx context.Context, isRunning bool) string {
	// Build divider: "   ─── label icon ─────────"
	iconPart := ""
	if d.Icon != "" {
		iconPart = " " + d.Icon
	}

	content := d.Label + iconPart
	contentLen := len(content) + 2 // account for icon width
	tailLen := 24 - contentLen
	if tailLen < 3 {
		tailLen = 3
	}
	tail := strings.Repeat("─", tailLen)

	display := fmt.Sprintf("   ─── %s%s %s", d.Label, iconPart, tail)
	// Dividers have empty shortcut and name to prevent selection
	return fmt.Sprintf("%s\t\t\t",
		display,
	)
}

// IsDivider returns true if this is a divider (not a real item)
func (d *TaskrunnerDivider) IsDivider() bool {
	return true
}

// GetPrimaryAction returns empty - dividers aren't selectable
func (d *TaskrunnerDivider) GetPrimaryAction() config.Action {
	return ""
}

// GetSecondaryAction returns empty - dividers aren't selectable
func (d *TaskrunnerDivider) GetSecondaryAction() config.Action {
	return ""
}

// LoadTaskrunnerTasks loads tasks from a taskrunner provider script
func LoadTaskrunnerTasks(ctx context.Context, cfg config.TaskrunnerConfig, settings *config.Settings) ([]TaskrunnerTask, string, string, error) {
	// Find the provider script
	scriptPath := findProviderScript(cfg.Name, settings.BinDir)
	if scriptPath == "" {
		return nil, "", "", fmt.Errorf("taskrunner provider script not found: %s", cfg.Name)
	}

	// Get icon and label from provider (or use config overrides)
	icon := cfg.Icon
	label := cfg.Label

	if icon == "" {
		icon = getProviderValue(ctx, scriptPath, "plugin_icon")
	}
	if label == "" || label == cfg.Name {
		providerLabel := getProviderValue(ctx, scriptPath, "plugin_label")
		if providerLabel != "" {
			label = providerLabel
		}
	}

	// Get tasks from provider
	tasks, err := getProviderTasks(ctx, scriptPath)
	if err != nil {
		return nil, icon, label, err
	}

	return tasks, icon, label, nil
}

// findProviderScript looks for a taskrunner provider script
func findProviderScript(name string, binDir string) string {
	// Check locations in order:
	// 1. BinDir (same as nunchux binary)
	// 2. BinDir/taskrunners
	// 3. Home directory locations

	locations := []string{}

	if binDir != "" {
		locations = append(locations,
			filepath.Join(binDir, name+".sh"),
			filepath.Join(binDir, "taskrunners", name+".sh"),
		)
	}

	home, _ := os.UserHomeDir()
	locations = append(locations,
		filepath.Join(home, "source", "nunchux-go", "taskrunners", name+".sh"),
		filepath.Join(home, "source", "nunchux", "taskrunners", name+".sh"),
		filepath.Join(home, ".local", "share", "nunchux-go", "taskrunners", name+".sh"),
		filepath.Join(home, ".local", "share", "nunchux", "taskrunners", name+".sh"),
	)

	for _, loc := range locations {
		if _, err := os.Stat(loc); err == nil {
			return loc
		}
	}

	return ""
}

// getPaneCurrentPath returns the tmux pane's current working directory
func getPaneCurrentPath() string {
	// Allow override via environment (useful for testing)
	if override := os.Getenv("NUNCHUX_CWD"); override != "" {
		return override
	}

	output, err := exec.Command("tmux", "display-message", "-p", "#{pane_current_path}").Output()
	if err != nil {
		// Fall back to current working directory
		cwd, _ := os.Getwd()
		return cwd
	}
	return strings.TrimSpace(string(output))
}

// getProviderValue calls a function in the provider script and returns its output
func getProviderValue(ctx context.Context, scriptPath, funcName string) string {
	ctx, cancel := context.WithTimeout(ctx, 500*time.Millisecond)
	defer cancel()

	script := fmt.Sprintf("source %q && %s 2>/dev/null", scriptPath, funcName)
	cmd := exec.CommandContext(ctx, "bash", "-c", script)
	output, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(output))
}

// getProviderTasks calls plugin_items and parses the output
func getProviderTasks(ctx context.Context, scriptPath string) ([]TaskrunnerTask, error) {
	ctx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()

	// Get tmux pane's current directory (not nunchux's cwd)
	paneDir := getPaneCurrentPath()

	script := fmt.Sprintf("cd %q 2>/dev/null; source %q && plugin_items 2>/dev/null", paneDir, scriptPath)
	cmd := exec.CommandContext(ctx, "bash", "-c", script)
	output, err := cmd.Output()
	if err != nil {
		return nil, err
	}

	var tasks []TaskrunnerTask
	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	for _, line := range lines {
		if line == "" {
			continue
		}
		parts := strings.SplitN(line, "\t", 3)
		if len(parts) < 2 {
			continue
		}
		task := TaskrunnerTask{
			TaskName: parts[0],
			Cmd:      parts[1],
		}
		if len(parts) > 2 {
			task.Description = parts[2]
		}
		tasks = append(tasks, task)
	}

	return tasks, nil
}
