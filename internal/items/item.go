package items

import (
	"context"

	"nunchux/internal/config"
)

// ItemType identifies the kind of menu item
type ItemType int

const (
	TypeApp ItemType = iota
	TypeMenu
	TypeDirbrowser
	TypeTaskrunner
)

// Item is the common interface for all menu items
type Item interface {
	// Name returns the unique identifier
	Name() string

	// Type returns the item type
	Type() ItemType

	// Shortcut returns the keyboard shortcut (empty if none)
	Shortcut() string

	// Parent returns the parent menu name (empty for top-level items)
	Parent() string

	// FormatLine formats the item as a menu line for fzf
	// The isRunning parameter indicates if this item has a running window
	FormatLine(ctx context.Context, isRunning bool) string

	// DisplayName returns the name shown in the menu (for width calculation)
	DisplayName() string

	// GetPrimaryAction returns the primary action for this item
	GetPrimaryAction() config.Action

	// GetSecondaryAction returns the secondary action for this item
	GetSecondaryAction() config.Action
}
