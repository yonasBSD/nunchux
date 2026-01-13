package ui

import (
	"context"
	"strings"

	"nunchux/internal/config"
	"nunchux/internal/fzf"
	"nunchux/internal/items"
)

// DirbrowserSelection represents the user's file selection
type DirbrowserSelection struct {
	FilePath string        // Full path to selected file
	Key      string        // Key pressed
	Action   config.Action // Resolved action based on key
	Canceled bool          // True if user canceled
	Back     bool          // True if user pressed Esc (go back to main menu)
}

// ShowDirbrowser displays the file listing and returns the selection
func ShowDirbrowser(ctx context.Context, db *items.DirbrowserItem, settings *config.Settings) (*DirbrowserSelection, error) {
	// List files
	entries, err := db.ListFiles(ctx)
	if err != nil {
		return nil, err
	}

	// Build menu content
	var lines []string
	for _, e := range entries {
		lines = append(lines, db.FormatFileEntry(e))
	}
	menuContent := strings.Join(lines, "\n")

	if menuContent == "" {
		return &DirbrowserSelection{Back: true}, nil
	}

	// Build fzf options
	opts := buildDirbrowserOptions(settings, db.Dirbrowser.Name)

	// Run fzf
	sel, err := fzf.Run(menuContent, opts)
	if err != nil {
		return nil, err
	}

	if sel.Canceled {
		return &DirbrowserSelection{Canceled: true}, nil
	}

	// Handle escape key (go back)
	if sel.Key == "esc" {
		return &DirbrowserSelection{Back: true}, nil
	}

	// Extract file path from fzf output (fields: display, path, width, height)
	if len(sel.Fields) < 2 {
		return &DirbrowserSelection{Back: true}, nil
	}

	return &DirbrowserSelection{
		FilePath: sel.Fields[1],
		Key:      sel.Key,
		Action:   resolveActionForDirbrowser(sel.Key, db, settings),
	}, nil
}

// resolveActionForDirbrowser determines the action based on key pressed and dirbrowser settings
func resolveActionForDirbrowser(key string, db *items.DirbrowserItem, settings *config.Settings) config.Action {
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

	// Use dirbrowser-specific actions
	switch key {
	case settings.SecondaryKey:
		return db.GetSecondaryAction()
	case "", settings.PrimaryKey:
		return db.GetPrimaryAction()
	}

	return db.GetPrimaryAction()
}

func buildDirbrowserOptions(settings *config.Settings, name string) []string {
	builder := fzf.NewOptionsBuilder(settings)

	// Build border label
	label := " " + settings.Label + ": " + name + " "
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

	return builder.Build()
}
