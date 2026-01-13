package config

import "testing"

func TestIsValidFzfKey(t *testing.T) {
	tests := []struct {
		key   string
		valid bool
	}{
		// Valid keys
		{"ctrl-a", true},
		{"alt-x", true},
		{"f1", true},
		{"enter", true},
		{"ctrl-/", true},
		{"CTRL-A", true}, // case insensitive

		// Invalid keys
		{"a", false},
		{"hello", false},
		{"ctrl-1", false},
		{"", false},
	}

	for _, tt := range tests {
		t.Run(tt.key, func(t *testing.T) {
			got := IsValidFzfKey(tt.key)
			if got != tt.valid {
				t.Errorf("IsValidFzfKey(%q) = %v, want %v", tt.key, got, tt.valid)
			}
		})
	}
}

func TestGetReservedKeys(t *testing.T) {
	settings := DefaultSettings()

	reserved := GetReservedKeys(&settings)

	// Static reserved keys
	if _, ok := reserved["enter"]; !ok {
		t.Error("expected 'enter' to be reserved")
	}
	if _, ok := reserved["esc"]; !ok {
		t.Error("expected 'esc' to be reserved")
	}
	if _, ok := reserved["ctrl-x"]; !ok {
		t.Error("expected 'ctrl-x' to be reserved")
	}

	// Dynamic reserved keys from defaults
	if _, ok := reserved["ctrl-o"]; !ok {
		t.Error("expected 'ctrl-o' (secondary_key) to be reserved")
	}
	if _, ok := reserved["ctrl-j"]; !ok {
		t.Error("expected 'ctrl-j' (action_menu_key) to be reserved")
	}
	if _, ok := reserved["ctrl-/"]; !ok {
		t.Error("expected 'ctrl-/' (toggle_shortcuts_key) to be reserved")
	}
}

func TestValidateShortcut(t *testing.T) {
	settings := DefaultSettings()
	registered := make(map[string]string)

	// Valid shortcut
	err := ValidateShortcut("alt-a", "myapp", &settings, registered)
	if err != nil {
		t.Errorf("expected no error for valid shortcut, got: %v", err)
	}

	// Invalid fzf key
	err = ValidateShortcut("x", "myapp", &settings, registered)
	if err == nil {
		t.Error("expected error for invalid fzf key 'x'")
	}

	// Reserved key
	err = ValidateShortcut("enter", "myapp", &settings, registered)
	if err == nil {
		t.Error("expected error for reserved key 'enter'")
	}

	// Duplicate detection
	registered["alt-b"] = "otherapp"
	err = ValidateShortcut("alt-b", "myapp", &settings, registered)
	if err == nil {
		t.Error("expected error for duplicate shortcut")
	}
	if err != nil && err.Message != "'alt-b' is already used by 'otherapp'" {
		t.Errorf("unexpected error message: %s", err.Message)
	}

	// Empty shortcut is allowed
	err = ValidateShortcut("", "myapp", &settings, registered)
	if err != nil {
		t.Errorf("expected no error for empty shortcut, got: %v", err)
	}
}

func TestShortcutValidator(t *testing.T) {
	settings := DefaultSettings()
	v := NewShortcutValidator(&settings)

	// Register valid shortcuts
	v.Register("alt-a", "app1")
	v.Register("alt-b", "app2")

	if v.HasErrors() {
		t.Errorf("expected no errors, got: %v", v.Errors())
	}

	// Duplicate should cause error
	v.Register("alt-a", "app3")
	if !v.HasErrors() {
		t.Error("expected error for duplicate shortcut")
	}

	// Check shortcuts map uses normalized keys
	shortcuts := v.Shortcuts()
	if shortcuts["alt-a"] != "app1" {
		t.Errorf("expected alt-a -> app1, got %s", shortcuts["alt-a"])
	}

	// Invalid key should cause error
	v2 := NewShortcutValidator(&settings)
	v2.Register("invalid-key", "app")
	if !v2.HasErrors() {
		t.Error("expected error for invalid key")
	}
}
