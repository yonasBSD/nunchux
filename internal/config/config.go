package config

import (
	"bufio"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

var (
	sectionRegex  = regexp.MustCompile(`^\[([^\]]+)\]$`)
	keyValueRegex = regexp.MustCompile(`^([^=]+)=(.*)$`)
)

// Load parses a config file and returns the configuration
func Load(path string) (*Config, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	cfg := &Config{
		Settings: DefaultSettings(),
		Order: OrderConfig{
			Submenus: make(map[string][]string),
		},
	}

	var currentSection string
	var sectionType, sectionName string
	sectionData := make(map[string]string)
	var continuationKey string
	var continuationValue strings.Builder

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		trimmed := strings.TrimSpace(line)

		// Skip comments and empty lines
		if trimmed == "" || strings.HasPrefix(trimmed, "#") {
			continue
		}

		// Handle line continuation
		if continuationKey != "" {
			// Strip trailing backslash from continuation lines
			lineContent := strings.TrimSpace(line)
			if strings.HasSuffix(lineContent, "\\") {
				lineContent = strings.TrimSuffix(lineContent, "\\")
				continuationValue.WriteString(lineContent)
				continuationValue.WriteString(" ")
				continue
			}
			// Final line of continuation (no backslash)
			continuationValue.WriteString(lineContent)
			sectionData[continuationKey] = continuationValue.String()
			continuationKey = ""
			continuationValue.Reset()
			continue
		}

		// Section header
		if match := sectionRegex.FindStringSubmatch(trimmed); match != nil {
			// Flush previous section
			flushSection(cfg, sectionType, sectionName, sectionData)
			sectionData = make(map[string]string)

			currentSection = match[1]
			sectionType, sectionName = parseSection(currentSection)
			continue
		}

		// Key = value
		if match := keyValueRegex.FindStringSubmatch(trimmed); match != nil {
			key := strings.TrimSpace(match[1])
			value := strings.TrimSpace(match[2])

			// Check for line continuation
			if strings.HasSuffix(value, "\\") {
				continuationKey = key
				continuationValue.WriteString(strings.TrimSuffix(value, "\\"))
				continuationValue.WriteString(" ")
				continue
			}

			if currentSection == "settings" {
				applySettings(&cfg.Settings, key, value)
			} else if currentSection == "taskrunner" {
				// Global taskrunner settings (no name)
				applyTaskrunnerGlobalSettings(&cfg.Settings, key, value)
			} else {
				sectionData[key] = value
			}
			continue
		}

		// Lines in [order] sections are item names
		if currentSection == "order" || strings.HasPrefix(currentSection, "order:") {
			handleOrderLine(cfg, currentSection, trimmed)
		}
	}

	// Flush final section
	flushSection(cfg, sectionType, sectionName, sectionData)

	if err := scanner.Err(); err != nil {
		return nil, err
	}

	// Post-process: extract parent from app names with /
	for i := range cfg.Apps {
		if idx := strings.Index(cfg.Apps[i].Name, "/"); idx != -1 {
			cfg.Apps[i].Parent = cfg.Apps[i].Name[:idx]
		}
	}

	return cfg, nil
}

func parseSection(s string) (sectionType, sectionName string) {
	if idx := strings.Index(s, ":"); idx != -1 {
		return s[:idx], s[idx+1:]
	}
	return s, ""
}

func flushSection(cfg *Config, sectionType, name string, data map[string]string) {
	if sectionType == "" || len(data) == 0 && sectionType != "order" {
		return
	}

	switch sectionType {
	case "app":
		cfg.Apps = append(cfg.Apps, parseApp(name, data))
	case "menu":
		cfg.Menus = append(cfg.Menus, parseMenu(name, data))
	case "dirbrowser":
		cfg.Dirbrowsers = append(cfg.Dirbrowsers, parseDirbrowser(name, data))
	case "taskrunner":
		if name != "" { // Skip global [taskrunner] section
			cfg.Taskrunners = append(cfg.Taskrunners, parseTaskrunner(name, data))
		}
	}
}

func parseApp(name string, data map[string]string) App {
	app := App{
		Name: name,
	}
	for key, value := range data {
		switch key {
		case "cmd":
			app.Cmd = value
		case "desc":
			app.Desc = value
		case "width":
			app.Width = value
		case "height":
			app.Height = value
		case "status":
			app.Status = value
		case "status_script":
			app.StatusScript = value
		case "on_exit":
			app.OnExit = value
		case "shortcut":
			app.Shortcut = value
		case "primary_action":
			app.PrimaryAction = Action(value)
		case "secondary_action":
			app.SecondaryAction = Action(value)
		}
	}
	return app
}

func parseMenu(name string, data map[string]string) Menu {
	menu := Menu{
		Name: name,
	}
	for key, value := range data {
		switch key {
		case "desc":
			menu.Desc = value
		case "status":
			menu.Status = value
		case "cache_ttl":
			menu.CacheTTL, _ = strconv.Atoi(value)
		case "shortcut":
			menu.Shortcut = value
		}
	}
	return menu
}

func parseDirbrowser(name string, data map[string]string) Dirbrowser {
	db := DefaultDirbrowser()
	db.Name = name

	for key, value := range data {
		switch key {
		case "directory":
			db.Directory = expandHome(value)
		case "depth":
			db.Depth, _ = strconv.Atoi(value)
		case "sort":
			db.Sort = value
		case "sort_direction":
			db.SortDirection = value
		case "glob":
			db.Glob = value
		case "width":
			db.Width = value
		case "height":
			db.Height = value
		case "cache_ttl":
			db.CacheTTL, _ = strconv.Atoi(value)
		case "shortcut":
			db.Shortcut = value
		case "primary_action":
			db.PrimaryAction = Action(value)
		case "secondary_action":
			db.SecondaryAction = Action(value)
		}
	}
	return db
}

func parseTaskrunner(name string, data map[string]string) TaskrunnerConfig {
	tr := DefaultTaskrunner()
	tr.Name = name
	tr.Label = name // Default label is the name

	for key, value := range data {
		switch key {
		case "enabled":
			tr.Enabled = value == "true"
		case "icon":
			tr.Icon = value
		case "label":
			tr.Label = value
		case "primary_action":
			tr.PrimaryAction = Action(value)
		case "secondary_action":
			tr.SecondaryAction = Action(value)
		}
	}
	return tr
}

func applySettings(s *Settings, key, value string) {
	switch key {
	case "icon_running":
		s.IconRunning = value
	case "icon_stopped":
		s.IconStopped = value
	case "menu_width":
		s.MenuWidth = value
	case "menu_height":
		s.MenuHeight = value
	case "max_menu_width":
		s.MaxMenuWidth = value
	case "max_menu_height":
		s.MaxMenuHeight = value
	case "popup_width":
		s.PopupWidth = value
	case "popup_height":
		s.PopupHeight = value
	case "max_popup_width":
		s.MaxPopupWidth = value
	case "max_popup_height":
		s.MaxPopupHeight = value
	case "primary_key":
		s.PrimaryKey = value
	case "secondary_key":
		s.SecondaryKey = value
	case "primary_action":
		s.PrimaryAction = Action(value)
	case "secondary_action":
		s.SecondaryAction = Action(value)
	case "popup_key":
		s.PopupKey = value
	case "window_key":
		s.WindowKey = value
	case "background_window_key":
		s.BackgroundWindowKey = value
	case "pane_right_key":
		s.PaneRightKey = value
	case "pane_left_key":
		s.PaneLeftKey = value
	case "pane_above_key":
		s.PaneAboveKey = value
	case "pane_below_key":
		s.PaneBelowKey = value
	case "action_menu_key":
		s.ActionMenuKey = value
	case "toggle_shortcuts_key":
		s.ToggleShortcutsKey = value
	case "label":
		s.Label = value
	case "show_help":
		s.ShowHelp = value == "true"
	case "show_cwd":
		s.ShowCwd = value == "true"
	case "cache_ttl":
		s.CacheTTL, _ = strconv.Atoi(value)
	case "fzf_prompt":
		s.FzfPrompt = value
	case "fzf_pointer":
		s.FzfPointer = value
	case "fzf_border":
		s.FzfBorder = value
	case "fzf_colors":
		s.FzfColors = value
	case "exclude_patterns":
		s.ExcludePatterns = value
	}
}

func applyTaskrunnerGlobalSettings(s *Settings, key, value string) {
	switch key {
	case "icon_running":
		s.TaskrunnerIconRunning = value
	case "icon_success":
		s.TaskrunnerIconSuccess = value
	case "icon_failed":
		s.TaskrunnerIconFailed = value
	}
}

func handleOrderLine(cfg *Config, section, line string) {
	item := strings.TrimSpace(line)
	if item == "" {
		return
	}

	if section == "order" {
		cfg.Order.Main = append(cfg.Order.Main, item)
	} else if strings.HasPrefix(section, "order:") {
		submenuName := strings.TrimPrefix(section, "order:")
		cfg.Order.Submenus[submenuName] = append(cfg.Order.Submenus[submenuName], item)
	}
}

func expandHome(path string) string {
	if strings.HasPrefix(path, "~/") {
		home, _ := os.UserHomeDir()
		return filepath.Join(home, path[2:])
	}
	return path
}

// FindConfigFile searches for config file in priority order
func FindConfigFile() (string, error) {
	// 1. Environment variable
	if envFile := os.Getenv("NUNCHUX_RC_FILE"); envFile != "" {
		if _, err := os.Stat(envFile); err == nil {
			return envFile, nil
		}
	}

	// 2. Search upward for .nunchuxrc
	cwd, err := os.Getwd()
	if err == nil {
		for dir := cwd; dir != "/" && dir != "."; dir = filepath.Dir(dir) {
			rc := filepath.Join(dir, ".nunchuxrc")
			if _, err := os.Stat(rc); err == nil {
				return rc, nil
			}
		}
	}

	// 3. XDG config
	configDir := os.Getenv("XDG_CONFIG_HOME")
	if configDir == "" {
		home, _ := os.UserHomeDir()
		configDir = filepath.Join(home, ".config")
	}
	xdgConfig := filepath.Join(configDir, "nunchux", "config")
	if _, err := os.Stat(xdgConfig); err == nil {
		return xdgConfig, nil
	}

	return "", nil // No config found
}
