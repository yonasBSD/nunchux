package config

// Action represents a launch action type
type Action string

const (
	ActionPopup            Action = "popup"
	ActionWindow           Action = "window"
	ActionBackgroundWindow Action = "background_window"
	ActionPaneRight        Action = "pane_right"
	ActionPaneLeft         Action = "pane_left"
	ActionPaneAbove        Action = "pane_above"
	ActionPaneBelow        Action = "pane_below"
)

// Config holds all parsed configuration
type Config struct {
	Settings    Settings
	Apps        []App
	Menus       []Menu
	Dirbrowsers []Dirbrowser
	Taskrunners []TaskrunnerConfig
	Order       OrderConfig
}

// Settings holds global configuration
type Settings struct {
	// Icons
	IconRunning string
	IconStopped string

	// Menu dimensions
	MenuWidth     string
	MenuHeight    string
	MaxMenuWidth  string
	MaxMenuHeight string

	// Popup dimensions
	PopupWidth     string
	PopupHeight    string
	MaxPopupWidth  string
	MaxPopupHeight string

	// Keybindings
	PrimaryKey   string
	SecondaryKey string

	// Actions
	PrimaryAction   Action
	SecondaryAction Action

	// Direct action keys (empty = disabled)
	PopupKey            string
	WindowKey           string
	BackgroundWindowKey string
	PaneRightKey        string
	PaneLeftKey         string
	PaneAboveKey        string
	PaneBelowKey        string
	ActionMenuKey       string
	ToggleShortcutsKey  string

	// Display
	Label    string
	ShowHelp bool
	ShowCwd  bool
	CacheTTL int

	// FZF styling
	FzfPrompt  string
	FzfPointer string
	FzfBorder  string
	FzfColors  string

	// Exclude patterns for dirbrowser
	ExcludePatterns string

	// Runtime - set programmatically, not from config
	BinDir string // Directory containing helper scripts (lines, ago, nearest)

	// Taskrunner icons
	TaskrunnerIconRunning string
	TaskrunnerIconSuccess string
	TaskrunnerIconFailed  string
}

// App represents a configured application
type App struct {
	Name            string
	Cmd             string
	Desc            string
	Width           string
	Height          string
	Status          string // Shell command to get status
	StatusScript    string // Path to status script
	OnExit          string // Shell command to run after exit
	Shortcut        string
	PrimaryAction   Action
	SecondaryAction Action
	Parent          string // Parent menu name (for submenu items like "system/htop")
}

// Menu represents a submenu
type Menu struct {
	Name     string
	Desc     string
	Status   string
	CacheTTL int
	Shortcut string
}

// Dirbrowser represents a directory browser configuration
type Dirbrowser struct {
	Name            string
	Directory       string
	Depth           int
	Sort            string // "modified", "modified-folder", "alphabetical"
	SortDirection   string // "ascending", "descending"
	Glob            string
	Width           string
	Height          string
	CacheTTL        int
	Shortcut        string
	PrimaryAction   Action
	SecondaryAction Action
}

// TaskrunnerConfig represents taskrunner settings
type TaskrunnerConfig struct {
	Name            string
	Enabled         bool
	Icon            string
	Label           string
	PrimaryAction   Action
	SecondaryAction Action
}

// OrderConfig holds ordering configuration
type OrderConfig struct {
	Main     []string            // Main menu order
	Submenus map[string][]string // Submenu name -> item order
}
