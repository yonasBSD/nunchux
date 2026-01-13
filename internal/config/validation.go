package config

import (
	"fmt"
	"strings"
)

// ValidationError represents a shortcut validation error
type ValidationError struct {
	Key      string
	ItemName string
	Message  string
}

func (e ValidationError) Error() string {
	return fmt.Sprintf("%s: %s", e.Key, e.Message)
}

// supportedKeysSet is a set for O(1) lookup
var supportedKeysSet map[string]bool

func init() {
	supportedKeysSet = make(map[string]bool, len(SupportedFzfKeys))
	for _, k := range SupportedFzfKeys {
		supportedKeysSet[k] = true
	}
}

// IsValidFzfKey checks if a key is a recognized fzf key format
func IsValidFzfKey(key string) bool {
	return supportedKeysSet[strings.ToLower(key)]
}

// GetReservedKeys returns all reserved keys based on settings
// This includes static reserved keys plus any configured action keys
func GetReservedKeys(settings *Settings) map[string]string {
	reserved := make(map[string]string)

	// Static reserved keys
	for _, k := range ReservedFzfKeys {
		reserved[k] = "reserved by nunchux"
	}

	// Dynamic reserved keys from settings
	if settings.PrimaryKey != "" {
		reserved[settings.PrimaryKey] = "primary_key"
	}
	if settings.SecondaryKey != "" {
		reserved[settings.SecondaryKey] = "secondary_key"
	}
	if settings.ActionMenuKey != "" {
		reserved[settings.ActionMenuKey] = "action_menu_key"
	}
	if settings.ToggleShortcutsKey != "" {
		reserved[settings.ToggleShortcutsKey] = "toggle_shortcuts_key"
	}
	if settings.PopupKey != "" {
		reserved[settings.PopupKey] = "popup_key"
	}
	if settings.WindowKey != "" {
		reserved[settings.WindowKey] = "window_key"
	}
	if settings.BackgroundWindowKey != "" {
		reserved[settings.BackgroundWindowKey] = "background_window_key"
	}
	if settings.PaneRightKey != "" {
		reserved[settings.PaneRightKey] = "pane_right_key"
	}
	if settings.PaneLeftKey != "" {
		reserved[settings.PaneLeftKey] = "pane_left_key"
	}
	if settings.PaneAboveKey != "" {
		reserved[settings.PaneAboveKey] = "pane_above_key"
	}
	if settings.PaneBelowKey != "" {
		reserved[settings.PaneBelowKey] = "pane_below_key"
	}

	return reserved
}

// ValidateShortcut validates a single shortcut key
// Returns nil if valid, or a ValidationError describing the problem
func ValidateShortcut(key, itemName string, settings *Settings, registered map[string]string) *ValidationError {
	if key == "" {
		return nil // Empty shortcuts are allowed
	}

	normalizedKey := strings.ToLower(key)

	// Check if it's a valid fzf key format
	if !IsValidFzfKey(normalizedKey) {
		return &ValidationError{
			Key:      key,
			ItemName: itemName,
			Message:  fmt.Sprintf("'%s' is not a valid fzf key", key),
		}
	}

	// Check if it's a reserved key
	reserved := GetReservedKeys(settings)
	if reason, isReserved := reserved[normalizedKey]; isReserved {
		return &ValidationError{
			Key:      key,
			ItemName: itemName,
			Message:  fmt.Sprintf("'%s' is reserved (%s)", key, reason),
		}
	}

	// Check for duplicates
	if existingItem, exists := registered[normalizedKey]; exists {
		return &ValidationError{
			Key:      key,
			ItemName: itemName,
			Message:  fmt.Sprintf("'%s' is already used by '%s'", key, existingItem),
		}
	}

	return nil
}

// ShortcutValidator collects shortcuts and validates them
type ShortcutValidator struct {
	settings   *Settings
	registered map[string]string // normalized key -> item name
	errors     []ValidationError
}

// NewShortcutValidator creates a new validator
func NewShortcutValidator(settings *Settings) *ShortcutValidator {
	return &ShortcutValidator{
		settings:   settings,
		registered: make(map[string]string),
	}
}

// Register validates and registers a shortcut
// Returns the validation error if any (also collected in Errors())
func (v *ShortcutValidator) Register(key, itemName string) *ValidationError {
	if key == "" {
		return nil
	}

	err := ValidateShortcut(key, itemName, v.settings, v.registered)
	if err != nil {
		v.errors = append(v.errors, *err)
		return err
	}

	// Register the shortcut (normalized)
	v.registered[strings.ToLower(key)] = itemName
	return nil
}

// Errors returns all validation errors collected
func (v *ShortcutValidator) Errors() []ValidationError {
	return v.errors
}

// Shortcuts returns the map of validated shortcuts (normalized key -> item name)
func (v *ShortcutValidator) Shortcuts() map[string]string {
	return v.registered
}

// HasErrors returns true if any validation errors were found
func (v *ShortcutValidator) HasErrors() bool {
	return len(v.errors) > 0
}
