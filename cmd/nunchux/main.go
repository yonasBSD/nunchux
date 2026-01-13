package main

import (
	"context"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"nunchux/internal/config"
	"nunchux/internal/fzf"
	"nunchux/internal/items"
	"nunchux/internal/onboarding"
	"nunchux/internal/tmux"
	"nunchux/internal/ui"
)

var (
	debug   bool
	logFile *os.File
)

// setupLogging configures logging to file. In debug mode, logs everything.
// Otherwise, only errors are logged.
func setupLogging(debugMode bool) {
	debug = debugMode

	// Create log directory
	cacheDir, err := os.UserCacheDir()
	if err != nil {
		cacheDir = filepath.Join(os.Getenv("HOME"), ".cache")
	}
	logDir := filepath.Join(cacheDir, "nunchux")
	os.MkdirAll(logDir, 0755)

	// Open log file (append mode)
	logPath := filepath.Join(logDir, "nunchux.log")
	logFile, err = os.OpenFile(logPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		// Fall back to stderr if we can't open log file
		log.SetOutput(os.Stderr)
		return
	}

	log.SetFlags(log.Ldate | log.Ltime | log.Lshortfile)
	log.SetPrefix("")

	if debug {
		// In debug mode, log to both file and stderr
		log.SetOutput(io.MultiWriter(logFile, os.Stderr))
	} else {
		// Normal mode: only log to file
		log.SetOutput(logFile)
	}
}

func logDebug(format string, v ...any) {
	if debug {
		log.Printf("[DEBUG] "+format, v...)
	}
}

func logInfo(format string, v ...any) {
	log.Printf("[INFO] "+format, v...)
}

func logError(format string, v ...any) {
	log.Printf("[ERROR] "+format, v...)
}

var Version = "dev"

func main() {
	// CLI flags
	versionFlag := flag.Bool("version", false, "Print version")
	listFlag := flag.Bool("list", false, "List configured apps")
	submenuFlag := flag.String("submenu", "", "Open specific submenu")
	debugFlag := flag.Bool("debug", false, "Enable debug logging")
	logFlag := flag.Bool("log", false, "Show log file path and tail recent entries")
	showShortcutsFlag := flag.Bool("show-shortcuts", false, "Show shortcut prefixes in menu")
	hideShortcutsFlag := flag.Bool("hide-shortcuts", false, "Hide shortcut prefixes in menu")
	launchShortcutFlag := flag.String("launch-shortcut", "", "Launch item by name directly")
	killFlag := flag.String("kill", "", "Kill window by name")
	menuFlag := flag.Bool("menu", false, "Output menu content (for fzf reload)")
	shellInitFlag := flag.String("shell-init", "", "Output shell init code (bash/zsh/fish)")
	initFlag := flag.Bool("init", false, "Run first-time setup wizard (internal)")
	flag.Parse()

	if *logFlag {
		cacheDir, _ := os.UserCacheDir()
		if cacheDir == "" {
			cacheDir = filepath.Join(os.Getenv("HOME"), ".cache")
		}
		logPath := filepath.Join(cacheDir, "nunchux", "nunchux.log")
		fmt.Println(logPath)
		return
	}

	if *shellInitFlag != "" {
		printShellInit(*shellInitFlag)
		return
	}

	// Handle --init flag (setup wizard mode)
	if *initFlag {
		runInitWizard()
		return
	}

	setupLogging(*debugFlag)
	if logFile != nil {
		defer logFile.Close()
	}
	logInfo("nunchux started")

	if *debugFlag && flag.NArg() == 0 {
		cfgPath, _ := config.FindConfigFile()
		binDir := getBinDir()
		fmt.Printf("Config: %s\n", cfgPath)
		fmt.Printf("BinDir: %s\n", binDir)
		fmt.Printf("nunchux-run exists: %v\n", fileExists(filepath.Join(binDir, "nunchux-run")))
		return
	}

	if *versionFlag {
		fmt.Println("nunchux-go", Version)
		return
	}

	// Preflight checks
	if err := preflight(); err != nil {
		logError("Preflight failed: %v", err)
		ui.ShowError(err)
		os.Exit(1)
	}

	// Find and load config
	cfgPath, err := config.FindConfigFile()
	if err != nil {
		logError("Config search failed: %v", err)
		ui.ShowError(fmt.Errorf("error finding config: %w", err))
		os.Exit(1)
	}
	if cfgPath == "" {
		// No config file - relaunch in a popup with border for onboarding
		// Use run-shell -b with sleep to let current popup close first
		logInfo("No config file found, launching setup wizard in popup")
		exe, _ := os.Executable()
		popupCmd := fmt.Sprintf("sleep 0.05; tmux display-popup -E -b rounded -T ' nunchux setup ' -w 60%% -h 50%% '%s' --init", exe)
		exec.Command("tmux", "run-shell", "-b", popupCmd).Run()
		os.Exit(0)
	}

	logDebug("Loading config from %s", cfgPath)
	cfg, err := config.Load(cfgPath)
	if err != nil {
		logError("Config load failed: %v", err)
		ui.ShowError(fmt.Errorf("error loading config: %w", err))
		os.Exit(1)
	}

	// Override ShowHelp based on CLI flags
	if *showShortcutsFlag {
		cfg.Settings.ShowHelp = true
	} else if *hideShortcutsFlag {
		cfg.Settings.ShowHelp = false
	}

	// Get bin directory (where nunchux-run wrapper and helper scripts live)
	binDir := getBinDir()
	cfg.Settings.BinDir = binDir

	// Create registry and tmux client
	registry := items.NewRegistry(cfg)
	tmuxClient := tmux.NewClient(binDir)

	// Report shortcut validation errors and exit
	if len(registry.ValidationErrors) > 0 {
		var errorMsgs []string
		for _, err := range registry.ValidationErrors {
			logError("shortcut validation: %s (%s)", err.Message, err.ItemName)
			errorMsgs = append(errorMsgs, err.ItemName+": "+err.Message)
		}
		if ui.ShowConfigErrors(registry.Settings, cfgPath, errorMsgs) {
			// Launch editor in popup with border, like normal apps
			editor := ui.GetEditorCommand()
			cmd := fmt.Sprintf("%s %q", editor, cfgPath)
			tmuxClient.Launch(tmux.LaunchOptions{
				Action:    config.ActionPopup,
				Name:      "config",
				Cmd:       cmd,
				Width:     registry.Settings.PopupWidth,
				Height:    registry.Settings.PopupHeight,
				MaxWidth:  registry.Settings.MaxPopupWidth,
				MaxHeight: registry.Settings.MaxPopupHeight,
				IsApp:     false,
			})
		}
		os.Exit(0)
	}

	// Handle flags that should NOT launch a popup
	if *listFlag {
		listApps(registry)
		return
	}

	if *killFlag != "" {
		tmuxClient.KillWindow(*killFlag)
		return
	}

	// Load taskrunners
	ctx := context.Background()
	registry.LoadTaskrunners(ctx)

	// Handle menu output (for fzf reload)
	if *menuFlag {
		runningWindows := tmuxClient.RunningWindows()
		content := registry.BuildMenu(ctx, runningWindows, *submenuFlag)
		fmt.Print(content)
		return
	}

	// Handle direct launch by shortcut
	if *launchShortcutFlag != "" {
		launchItemByName(registry, tmuxClient, *launchShortcutFlag)
		return
	}

	// Run main menu loop
	runMenu(registry, tmuxClient, *submenuFlag)
}

func preflight() error {
	// Check tmux
	if !tmux.IsAvailable() {
		return fmt.Errorf("tmux is not installed")
	}

	// Check if in tmux session
	if !tmux.InSession() {
		return fmt.Errorf("must be run inside a tmux session")
	}

	// Check fzf
	if !fzf.IsAvailable() {
		return fmt.Errorf("fzf is not installed")
	}

	return nil
}

func getBinDir() string {
	// Try to find nunchux-run relative to executable (same directory)
	exe, err := os.Executable()
	if err == nil {
		dir := filepath.Dir(exe)
		if _, err := os.Stat(filepath.Join(dir, "nunchux-run")); err == nil {
			return dir
		}
	}

	// Check common locations for Go version
	home, _ := os.UserHomeDir()
	locations := []string{
		filepath.Join(home, "source", "nunchux-go"),
		filepath.Join(home, ".local", "share", "nunchux-go"),
		filepath.Join(home, ".local", "bin"),
		"/usr/local/share/nunchux-go",
	}
	for _, loc := range locations {
		if _, err := os.Stat(filepath.Join(loc, "nunchux-run")); err == nil {
			return loc
		}
	}

	return ""
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func launchItemByName(registry *items.Registry, tmuxClient *tmux.Client, name string) {
	// Handle dirbrowser: prefix
	lookupName := name
	if strings.HasPrefix(name, "dirbrowser:") {
		lookupName = strings.TrimPrefix(name, "dirbrowser:")
	}

	item := registry.FindItem(lookupName)
	if item == nil {
		logError("Item not found: %s", name)
		return
	}

	switch item.Type() {
	case items.TypeApp:
		app := item.(*items.AppItem)

		// If already running, just select the window
		if tmuxClient.IsWindowRunning(name) {
			tmuxClient.SelectWindow(name)
			return
		}

		// Launch with primary action
		action := app.GetPrimaryAction()
		logInfo("Launching %s (%s) via shortcut", name, action)
		err := tmuxClient.Launch(tmux.LaunchOptions{
			Action:    action,
			Name:      name,
			Cmd:       app.App.Cmd,
			Width:     app.GetWidth(),
			Height:    app.GetHeight(),
			MaxWidth:  registry.Settings.MaxPopupWidth,
			MaxHeight: registry.Settings.MaxPopupHeight,
			OnExit:    app.App.OnExit,
			IsApp:     true,
		})
		if err != nil {
			logError("Launch failed for %s: %v", name, err)
		}

	case items.TypeMenu:
		// Open the submenu
		runMenu(registry, tmuxClient, name)

	case items.TypeDirbrowser:
		db := item.(*items.DirbrowserItem)
		launchDirbrowser(registry, tmuxClient, db)
	}
}

func printShellInit(shell string) {
	switch shell {
	case "fish":
		fmt.Print(`# Nunchux shell integration - saves environment for inheritance
# This runs after each command, so apps launched via nunchux
# inherit your current shell environment (PATH, nvm, pyenv, etc.)
if set -q TMUX_PANE
    function _nunchux_save_env --on-event fish_postexec
        env > "/tmp/nunchux-env-$TMUX_PANE" 2>/dev/null
    end

    # Clean up env file when shell exits
    function _nunchux_cleanup --on-event fish_exit
        rm -f "/tmp/nunchux-env-$TMUX_PANE" 2>/dev/null
    end
end
`)
	case "zsh":
		fmt.Print(`# Nunchux shell integration - saves environment for inheritance
# This runs after each command, so apps launched via nunchux
# inherit your current shell environment (PATH, nvm, pyenv, etc.)
if [[ -n "$TMUX_PANE" ]]; then
    _nunchux_save_env() {
        env > "/tmp/nunchux-env-$TMUX_PANE" 2>/dev/null
    }
    precmd_functions+=(_nunchux_save_env)

    # Clean up env file when shell exits
    trap 'rm -f "/tmp/nunchux-env-$TMUX_PANE" 2>/dev/null' EXIT
fi
`)
	default: // bash
		fmt.Print(`# Nunchux shell integration - saves environment for inheritance
# This runs after each command, so apps launched via nunchux
# inherit your current shell environment (PATH, nvm, pyenv, etc.)
if [[ -n "$TMUX_PANE" ]]; then
    _nunchux_save_env() {
        env > "/tmp/nunchux-env-$TMUX_PANE" 2>/dev/null
    }
    PROMPT_COMMAND="_nunchux_save_env${PROMPT_COMMAND:+;$PROMPT_COMMAND}"

    # Clean up env file when shell exits
    trap 'rm -f "/tmp/nunchux-env-$TMUX_PANE" 2>/dev/null' EXIT
fi
`)
	}
}

func listApps(registry *items.Registry) {
	for _, item := range registry.Items {
		switch it := item.(type) {
		case *items.AppItem:
			fmt.Printf("○ %s - %s\n", it.Name(), it.App.Desc)
		case *items.MenuItem:
			fmt.Printf("▸ %s - %s\n", it.Name(), it.Menu.Desc)
		case *items.DirbrowserItem:
			fmt.Printf("📁 %s - %s\n", it.Name(), it.Dirbrowser.Directory)
		}
	}
}

func launchDirbrowser(registry *items.Registry, tmuxClient *tmux.Client, db *items.DirbrowserItem) {
	ctx := context.Background()

	for {
		sel, err := ui.ShowDirbrowser(ctx, db, registry.Settings)
		if err != nil {
			logError("Dirbrowser error: %v", err)
			ui.ShowError(err)
			return
		}

		if sel.Canceled || sel.Back {
			return
		}

		if sel.FilePath == "" {
			return
		}

		// Get editor from environment
		editor := os.Getenv("VISUAL")
		if editor == "" {
			editor = os.Getenv("EDITOR")
		}
		if editor == "" {
			editor = "nvim"
		}

		// Handle action menu key
		action := sel.Action
		if sel.Key == registry.Settings.ActionMenuKey {
			var err error
			action, err = ui.ShowActionMenu(registry.Settings, filepath.Base(sel.FilePath))
			if err != nil || action == "" {
				continue // User canceled
			}
		}

		// Default to primary action
		if action == "" {
			action = registry.Settings.PrimaryAction
		}

		// Build editor command
		cmd := fmt.Sprintf("%s %q", editor, sel.FilePath)
		windowName := filepath.Base(sel.FilePath)
		if action == config.ActionPopup {
			windowName = db.Dirbrowser.Name + " | " + filepath.Base(sel.FilePath)
		}

		logInfo("Opening %s with %s (%s)", sel.FilePath, editor, action)
		err = tmuxClient.Launch(tmux.LaunchOptions{
			Action:    action,
			Name:      windowName,
			Cmd:       cmd,
			Width:     db.GetWidth(),
			Height:    db.GetHeight(),
			MaxWidth:  registry.Settings.MaxPopupWidth,
			MaxHeight: registry.Settings.MaxPopupHeight,
			IsApp:     false,
		})
		if err != nil {
			logError("Launch failed: %v", err)
			ui.ShowError(err)
		}
		return
	}
}

func launchTaskrunner(registry *items.Registry, tmuxClient *tmux.Client, tr *items.TaskrunnerItem, key string, action config.Action) {
	windowName := tr.WindowName()

	// Check if already running - reuse window if so
	isRunning := tmuxClient.IsWindowRunning(windowName)

	// Handle action menu key
	if key == registry.Settings.ActionMenuKey {
		var err error
		action, err = ui.ShowActionMenu(registry.Settings, windowName)
		if err != nil || action == "" {
			return // User canceled
		}
	}

	// Resolve action
	if action == "" {
		action = tr.GetPrimaryAction()
	}

	logInfo("Launching taskrunner %s (%s), running=%v", tr.Name(), action, isRunning)

	// Build the command with completion handling
	cmd := tr.Task.Cmd
	fullCmd := buildTaskrunnerCmd(registry.Settings, cmd, windowName)

	err := tmuxClient.Launch(tmux.LaunchOptions{
		Action:       action,
		Name:         windowName,
		Cmd:          fullCmd,
		Width:        registry.Settings.PopupWidth,
		Height:       registry.Settings.PopupHeight,
		MaxWidth:     registry.Settings.MaxPopupWidth,
		MaxHeight:    registry.Settings.MaxPopupHeight,
		IsApp:        false,
		IsTaskrunner: true,
		ReuseWindow:  isRunning,
		SuccessIcon:  registry.Settings.TaskrunnerIconSuccess,
		FailedIcon:   registry.Settings.TaskrunnerIconFailed,
		RunningIcon:  registry.Settings.TaskrunnerIconRunning,
	})
	if err != nil {
		logError("Launch failed for taskrunner %s: %v", tr.Name(), err)
		ui.ShowError(err)
	}
}

// buildTaskrunnerCmd wraps a task command with status indicator and wait
func buildTaskrunnerCmd(settings *config.Settings, cmd, windowName string) string {
	// Shell script that runs the command and shows success/failure
	return fmt.Sprintf(`bash -c '
source "%s/nunchux-run" 2>/dev/null || true
%s
exit_code=$?
echo
if [[ $exit_code -eq 0 ]]; then
    tmux rename-window -t "$TMUX_PANE" "%s %s" 2>/dev/null
    echo -e "\033[32m✓ Task completed successfully\033[0m"
else
    tmux rename-window -t "$TMUX_PANE" "%s %s" 2>/dev/null
    echo -e "\033[31m✗ Task failed with exit code $exit_code\033[0m"
fi
echo
echo "Press any key to close..."
read -n 1 -s
'`, settings.BinDir, cmd, windowName, settings.TaskrunnerIconSuccess, windowName, settings.TaskrunnerIconFailed)
}

func runMenu(registry *items.Registry, tmuxClient *tmux.Client, currentMenu string) {
	ctx := context.Background()
	logDebug("Starting menu loop, items: %d", len(registry.Items))

	for {
		sel, err := ui.ShowMenu(ctx, registry, tmuxClient, currentMenu)
		if err != nil {
			logError("Menu error: %v", err)
			ui.ShowError(err)
			return
		}

		// Handle cancel and back
		if sel.Canceled {
			return
		}
		if sel.Back {
			if currentMenu != "" {
				currentMenu = ""
				continue
			}
			return
		}

		// Skip divider lines (empty name field)
		if sel.Name == "" {
			continue
		}

		// Handle special empty-config menu items
		if sel.Name == "__edit_config" {
			handleEditConfig(registry, tmuxClient)
			return
		}
		if sel.Name == "__open_docs" {
			handleOpenDocs()
			return
		}

		// Check for taskrunner items first (format: runner:task)
		if strings.Contains(sel.Name, ":") && !strings.HasPrefix(sel.Name, "dirbrowser:") {
			trItem := registry.FindTaskrunnerItem(sel.Name)
			if trItem != nil {
				launchTaskrunner(registry, tmuxClient, trItem, sel.Key, sel.Action)
				return
			}
		}

		// Look up item from registry to determine type
		// Handle dirbrowser: prefix
		lookupName := sel.Name
		if strings.HasPrefix(sel.Name, "dirbrowser:") {
			lookupName = strings.TrimPrefix(sel.Name, "dirbrowser:")
		}

		item := registry.FindItem(lookupName)
		if item == nil {
			logError("Item not found in registry: %s", sel.Name)
			ui.ShowError(fmt.Errorf("item not found: %s", sel.Name))
			return
		}

		logDebug("Selected: %s (type=%d)", sel.Name, item.Type())

		switch item.Type() {
		case items.TypeMenu:
			currentMenu = sel.Name
			continue

		case items.TypeApp:
			app := item.(*items.AppItem)
			logDebug("App cmd=%q, width=%s, height=%s", app.App.Cmd, app.GetWidth(), app.GetHeight())

			// Check if already running
			if tmuxClient.IsWindowRunning(sel.Name) && sel.Action != config.ActionBackgroundWindow {
				tmuxClient.SelectWindow(sel.Name)
				return
			}

			// Handle action menu key (user picks action from a menu)
			action := sel.Action
			if sel.Key == registry.Settings.ActionMenuKey {
				var err error
				action, err = ui.ShowActionMenu(registry.Settings, sel.Name)
				if err != nil || action == "" {
					continue // User canceled
				}
			}

			// Launch the app
			logInfo("Launching %s (%s)", sel.Name, action)
			err := tmuxClient.Launch(tmux.LaunchOptions{
				Action:    action,
				Name:      sel.Name,
				Cmd:       app.App.Cmd,
				Width:     app.GetWidth(),
				Height:    app.GetHeight(),
				MaxWidth:  registry.Settings.MaxPopupWidth,
				MaxHeight: registry.Settings.MaxPopupHeight,
				OnExit:    app.App.OnExit,
				IsApp:     true,
			})
			if err != nil {
				logError("Launch failed for %s: %v", sel.Name, err)
				ui.ShowError(err)
			}
			return

		case items.TypeDirbrowser:
			db := item.(*items.DirbrowserItem)
			launchDirbrowser(registry, tmuxClient, db)
			return
		}
	}
}

// runInitWizard runs the first-time setup wizard (called via --init flag)
func runInitWizard() {
	configPath := onboarding.GetDefaultConfigPath()
	result := onboarding.RunSetup(configPath)
	if result.Canceled {
		os.Exit(0)
	}
	// Config was created - exit so user can restart nunchux
	os.Exit(0)
}

// handleEditConfig opens the config file in the user's editor
func handleEditConfig(registry *items.Registry, tmuxClient *tmux.Client) {
	cfgPath, _ := config.FindConfigFile()
	if cfgPath == "" {
		cfgPath = onboarding.GetDefaultConfigPath()
	}

	editor := ui.GetEditorCommand()
	cmd := fmt.Sprintf("%s %q", editor, cfgPath)

	tmuxClient.Launch(tmux.LaunchOptions{
		Action:    config.ActionPopup,
		Name:      "config",
		Cmd:       cmd,
		Width:     registry.Settings.PopupWidth,
		Height:    registry.Settings.PopupHeight,
		MaxWidth:  registry.Settings.MaxPopupWidth,
		MaxHeight: registry.Settings.MaxPopupHeight,
		IsApp:     false,
	})
}

// handleOpenDocs opens the documentation in a browser
func handleOpenDocs() {
	docsURL := "https://github.com/datamadsen/nunchux/blob/main/docs/configuration.md"

	// Use tmux run-shell -b to run outside the popup
	var openCmd string
	switch {
	case fileExists("/usr/bin/xdg-open"):
		openCmd = "xdg-open"
	case fileExists("/usr/bin/open"): // macOS
		openCmd = "open"
	default:
		openCmd = "xdg-open"
	}

	exec.Command("tmux", "run-shell", "-b", fmt.Sprintf("%s '%s'", openCmd, docsURL)).Run()
}
