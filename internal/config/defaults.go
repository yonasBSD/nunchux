package config

// DefaultSettings returns settings with all default values
func DefaultSettings() Settings {
	return Settings{
		// Icons
		IconRunning: "●",
		IconStopped: "○",

		// Menu dimensions
		MenuWidth:     "60%",
		MenuHeight:    "50%",
		MaxMenuWidth:  "", // empty = no limit
		MaxMenuHeight: "", // empty = no limit

		// Popup dimensions
		PopupWidth:     "90%",
		PopupHeight:    "90%",
		MaxPopupWidth:  "", // empty = no limit
		MaxPopupHeight: "", // empty = no limit

		// Keybindings
		PrimaryKey:   "enter",
		SecondaryKey: "ctrl-o",

		// Actions
		PrimaryAction:   ActionPopup,
		SecondaryAction: ActionWindow,

		// Direct action keys (empty = disabled)
		PopupKey:            "",
		WindowKey:           "",
		BackgroundWindowKey: "",
		PaneRightKey:        "",
		PaneLeftKey:         "",
		PaneAboveKey:        "",
		PaneBelowKey:        "",
		ActionMenuKey:       "ctrl-j",
		ToggleShortcutsKey:  "ctrl-/",

		// Display
		Label:    "nunchux",
		ShowHelp: false,
		ShowCwd:  true,
		CacheTTL: 60,

		// FZF styling
		FzfPrompt:  "",
		FzfPointer: "▌",
		FzfBorder:  "rounded",
		FzfColors:  "fg+:white:bold,bg+:237,hl:214,hl+:214:bold,pointer:white,marker:green,header:gray,border:gray",

		// Exclude patterns for dirbrowser
		ExcludePatterns: ".git, node_modules, Cache, cache, .cache, GPUCache, CachedData, blob_storage, Code Cache, Session Storage, Local Storage, IndexedDB, databases, *.db, *.db-*, *.sqlite*, *.log, *.png, *.jpg, *.jpeg, *.gif, *.ico, *.webp, *.woff*, *.ttf, *.lock, lock, *.pid",

		// Taskrunner icons
		TaskrunnerIconRunning: "🔄",
		TaskrunnerIconSuccess: "✅",
		TaskrunnerIconFailed:  "❌",
	}
}

// DefaultDirbrowser returns a dirbrowser with default values
func DefaultDirbrowser() Dirbrowser {
	return Dirbrowser{
		Depth:           1,
		Sort:            "modified",
		SortDirection:   "descending",
		Width:           "90%",
		Height:          "80%",
		CacheTTL:        300,
		PrimaryAction:   ActionPopup,
		SecondaryAction: ActionWindow,
	}
}

// DefaultTaskrunner returns a taskrunner config with default values
func DefaultTaskrunner() TaskrunnerConfig {
	return TaskrunnerConfig{
		Enabled:         false,
		PrimaryAction:   ActionWindow,
		SecondaryAction: ActionBackgroundWindow,
	}
}

// SupportedFzfKeys lists all keys that fzf supports
var SupportedFzfKeys = []string{
	// Basic keys
	"enter", "space", "tab", "esc", "backspace", "delete", "insert",
	// Navigation
	"up", "down", "left", "right", "home", "end", "page-up", "page-down",
	// Function keys
	"f1", "f2", "f3", "f4", "f5", "f6", "f7", "f8", "f9", "f10", "f11", "f12",
	// Ctrl combinations
	"ctrl-a", "ctrl-b", "ctrl-c", "ctrl-d", "ctrl-e", "ctrl-f", "ctrl-g", "ctrl-h",
	"ctrl-i", "ctrl-j", "ctrl-k", "ctrl-l", "ctrl-m", "ctrl-n", "ctrl-o", "ctrl-p",
	"ctrl-q", "ctrl-r", "ctrl-s", "ctrl-t", "ctrl-u", "ctrl-v", "ctrl-w", "ctrl-x",
	"ctrl-y", "ctrl-z", "ctrl-space", "ctrl-delete", "ctrl-backspace",
	"ctrl-up", "ctrl-down", "ctrl-left", "ctrl-right",
	// Alt combinations
	"alt-a", "alt-b", "alt-c", "alt-d", "alt-e", "alt-f", "alt-g", "alt-h",
	"alt-i", "alt-j", "alt-k", "alt-l", "alt-m", "alt-n", "alt-o", "alt-p",
	"alt-q", "alt-r", "alt-s", "alt-t", "alt-u", "alt-v", "alt-w", "alt-x",
	"alt-y", "alt-z", "alt-enter", "alt-space", "alt-backspace", "alt-delete",
	"alt-up", "alt-down", "alt-left", "alt-right", "alt-page-up", "alt-page-down",
	// Shift combinations (limited support)
	"shift-tab", "shift-up", "shift-down", "shift-left", "shift-right",
	"shift-home", "shift-end", "shift-delete", "shift-page-up", "shift-page-down",
	// Special
	"double-click", "ctrl-/",
}

// ReservedFzfKeys lists keys that cannot be used as shortcuts
var ReservedFzfKeys = []string{"enter", "esc", "ctrl-x"}
