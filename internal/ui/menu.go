package ui

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"strings"

	"nunchux/internal/config"
	"nunchux/internal/fzf"
	"nunchux/internal/items"
	"nunchux/internal/tmux"
)

// Selection represents the user's menu selection
type Selection struct {
	Name     string        // Item name
	Key      string        // Key pressed (empty for Enter)
	Action   config.Action // Resolved action based on key
	Canceled bool          // True if user canceled (Ctrl-C)
	Back     bool          // True if user pressed Esc
}

// ShowMenu displays the fzf menu and returns the selection
func ShowMenu(ctx context.Context, registry *items.Registry, tmuxClient *tmux.Client, currentMenu string) (*Selection, error) {
	// Get running windows for display
	runningWindows := tmuxClient.RunningWindows()

	// Build menu content
	menuContent := registry.BuildMenu(ctx, runningWindows, currentMenu)

	// If no items, show empty config fallback menu
	if menuContent == "" && currentMenu == "" {
		return showEmptyConfigMenu(registry.Settings)
	}

	if menuContent == "" {
		return &Selection{Canceled: true}, nil
	}

	// Build fzf options
	opts := buildFzfOptions(registry.Settings, currentMenu, registry.Shortcuts)

	// Run fzf
	sel, err := fzf.Run(menuContent, opts)
	if err != nil {
		return nil, err
	}

	if sel.Canceled {
		return &Selection{Canceled: true}, nil
	}

	// Handle escape key (go back)
	if sel.Key == "esc" {
		return &Selection{Back: true}, nil
	}

	// Extract name from fzf output (fields: display, shortcut, name)
	if len(sel.Fields) < 3 {
		return &Selection{Canceled: true}, nil
	}

	name := sel.Fields[2]

	// Resolve action using item-specific settings
	action := resolveActionForItem(sel.Key, name, registry)

	return &Selection{
		Name:   name,
		Key:    sel.Key,
		Action: action,
	}, nil
}

// getPaneCurrentPath returns the tmux pane's current working directory
func getPaneCurrentPath() string {
	output, err := exec.Command("tmux", "display-message", "-p", "#{pane_current_path}").Output()
	if err != nil {
		cwd, _ := os.Getwd()
		return cwd
	}
	return strings.TrimSpace(string(output))
}

func buildFzfOptions(settings *config.Settings, currentMenu string, shortcuts map[string]string) []string {
	builder := fzf.NewOptionsBuilder(settings)

	// Build border label
	label := " " + settings.Label
	if currentMenu != "" {
		label += ": " + currentMenu
	}
	if settings.ShowCwd {
		cwd := getPaneCurrentPath()
		home, _ := os.UserHomeDir()
		if home != "" && strings.HasPrefix(cwd, home) {
			cwd = "~" + cwd[len(home):]
		}
		label += " (" + cwd + ")"
	}
	label += " "
	builder.BorderLabel(label)

	// Build header
	var header strings.Builder
	if settings.ShowHelp {
		header.WriteString("enter: open │ ")
		if settings.SecondaryKey != "" {
			header.WriteString(settings.SecondaryKey + ": " + string(settings.SecondaryAction) + " │ ")
		}
		if settings.ActionMenuKey != "" {
			header.WriteString(settings.ActionMenuKey + ": action menu │ ")
		}
		header.WriteString("esc: back")
	}
	if header.Len() > 0 {
		builder.Header(header.String())
	}

	exe, _ := os.Executable()

	// Add toggle shortcuts keybinding
	if settings.ToggleShortcutsKey != "" {
		toggleCmd := exe
		if currentMenu != "" {
			toggleCmd += " --submenu " + currentMenu
		}
		if settings.ShowHelp {
			toggleCmd += " --hide-shortcuts"
		} else {
			toggleCmd += " --show-shortcuts"
		}
		builder.Bind(settings.ToggleShortcutsKey, "become("+toggleCmd+")")
	}

	// Add shortcut bindings for each item
	for key, itemName := range shortcuts {
		launchCmd := fmt.Sprintf("become(%s --launch-shortcut '%s')", exe, itemName)
		builder.Bind(key, launchCmd)
	}

	// Add ctrl-x to kill running window and reload
	reloadCmd := exe + " --menu"
	if currentMenu != "" {
		reloadCmd += " --submenu " + currentMenu
	}
	if settings.ShowHelp {
		reloadCmd += " --show-shortcuts"
	}
	killReloadCmd := fmt.Sprintf("reload(%s --kill {3} 2>/dev/null; %s)", exe, reloadCmd)
	builder.Bind("ctrl-x", killReloadCmd)

	return builder.Build()
}

// resolveActionForItem determines the action based on key pressed and item-specific settings
func resolveActionForItem(key string, name string, registry *items.Registry) config.Action {
	settings := registry.Settings

	// Direct action keys always override item settings (only if key is set)
	if key != "" {
		switch key {
		case settings.PopupKey:
			return config.ActionPopup
		case settings.WindowKey:
			return config.ActionWindow
		case settings.BackgroundWindowKey:
			return config.ActionBackgroundWindow
		case settings.PaneRightKey:
			return config.ActionPaneRight
		case settings.PaneLeftKey:
			return config.ActionPaneLeft
		case settings.PaneAboveKey:
			return config.ActionPaneAbove
		case settings.PaneBelowKey:
			return config.ActionPaneBelow
		}
	}

	// Look up item to get its specific action settings
	item := registry.FindItem(name)
	if item == nil {
		// Try taskrunner items
		if trItem := registry.FindTaskrunnerItem(name); trItem != nil {
			item = trItem
		}
	}

	// Use item-specific actions if available
	if item != nil {
		switch key {
		case settings.SecondaryKey:
			return item.GetSecondaryAction()
		case "", settings.PrimaryKey:
			return item.GetPrimaryAction()
		}
	}

	// Fallback to global settings
	switch key {
	case settings.SecondaryKey:
		return settings.SecondaryAction
	case "", settings.PrimaryKey:
		return settings.PrimaryAction
	}

	return settings.PrimaryAction
}

// showEmptyConfigMenu shows fallback menu when config has no items
func showEmptyConfigMenu(settings *config.Settings) (*Selection, error) {
	// Build menu with two options
	menuContent := "Edit config file\t\t__edit_config\nOpen documentation\t\t__open_docs"

	builder := fzf.NewOptionsBuilder(settings)
	builder.BorderLabel(" nunchux ")
	builder.Header("No items configured. Add some apps to your config file.")

	sel, err := fzf.Run(menuContent, builder.Build())
	if err != nil {
		return nil, err
	}

	if sel.Canceled {
		return &Selection{Canceled: true}, nil
	}

	if sel.Key == "esc" {
		return &Selection{Back: true}, nil
	}

	if len(sel.Fields) < 3 {
		return &Selection{Canceled: true}, nil
	}

	return &Selection{
		Name: sel.Fields[2],
		Key:  sel.Key,
	}, nil
}

// ShowActionMenu displays the action selection menu
func ShowActionMenu(settings *config.Settings, itemName string) (config.Action, error) {
	actions := []struct {
		id   config.Action
		name string
	}{
		{config.ActionPopup, "Open in popup"},
		{config.ActionWindow, "Open in window"},
		{config.ActionBackgroundWindow, "Open in background window"},
		{config.ActionPaneRight, "Open in pane to the right"},
		{config.ActionPaneLeft, "Open in pane to the left"},
		{config.ActionPaneAbove, "Open in pane above"},
		{config.ActionPaneBelow, "Open in pane below"},
	}

	var lines []string
	for _, a := range actions {
		lines = append(lines, fmt.Sprintf("%s\t%s", a.id, a.name))
	}

	opts := fzf.BuildForActionMenu(settings, itemName)
	sel, err := fzf.Run(strings.Join(lines, "\n"), opts)
	if err != nil {
		return "", err
	}

	if sel.Canceled || len(sel.Fields) == 0 {
		return "", nil
	}

	return config.Action(sel.Fields[0]), nil
}
