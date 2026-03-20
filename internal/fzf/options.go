package fzf

import (
	"fmt"
	"strings"

	"nunchux/internal/config"
)

// OptionsBuilder constructs fzf command line options
type OptionsBuilder struct {
	settings       *config.Settings
	borderLabel    string
	header         string
	expectKeys     []string
	bindCommands   []string
	previewCommand string
}

// NewOptionsBuilder creates a new fzf options builder
func NewOptionsBuilder(settings *config.Settings) *OptionsBuilder {
	return &OptionsBuilder{
		settings:   settings,
		expectKeys: []string{},
	}
}

// BorderLabel sets the border label
func (b *OptionsBuilder) BorderLabel(label string) *OptionsBuilder {
	b.borderLabel = label
	return b
}

// Header sets the header text
func (b *OptionsBuilder) Header(header string) *OptionsBuilder {
	b.header = header
	return b
}

// ExpectKey adds a key to the --expect list
func (b *OptionsBuilder) ExpectKey(key string) *OptionsBuilder {
	if key != "" {
		b.expectKeys = append(b.expectKeys, key)
	}
	return b
}

// ExpectKeys adds multiple keys to the --expect list
func (b *OptionsBuilder) ExpectKeys(keys ...string) *OptionsBuilder {
	for _, key := range keys {
		if key != "" {
			b.expectKeys = append(b.expectKeys, key)
		}
	}
	return b
}

// Bind adds a key binding command
func (b *OptionsBuilder) Bind(key, action string) *OptionsBuilder {
	b.bindCommands = append(b.bindCommands, fmt.Sprintf("%s:%s", key, action))
	return b
}

// Preview sets a preview command
func (b *OptionsBuilder) Preview(command string) *OptionsBuilder {
	b.previewCommand = command
	return b
}

// PreviewWindowsMode returns the preview command for tmux windows/sessions
func PreviewWindowsMode() string {
	return `bash -c 'name={3}; if [[ "$name" == window:* ]]; then idx="${name#window:}"; tmux capture-pane -t ":$idx" -p 2>/dev/null; elif [[ "$name" == session:* ]]; then sess="${name#session:}"; tmux capture-pane -t "$sess:" -p 2>/dev/null; fi'`
}

// Build returns the complete fzf options slice
func (b *OptionsBuilder) Build() []string {
	opts := []string{
		"--ansi",
		"--delimiter=\t",
		"--with-nth=1",
		"--tiebreak=begin",
		"--layout=reverse",
		"--height=100%",
		"--highlight-line",
	}

	// Preview
	if b.previewCommand != "" {
		opts = append(opts, "--preview="+b.previewCommand)
		opts = append(opts, "--preview-window=down,50%,border-top,follow")
	} else {
		opts = append(opts, "--no-preview")
	}

	// Prompt (add padding to indent the query field)
	if b.settings.FzfPrompt != "" {
		opts = append(opts, "--prompt="+b.settings.FzfPrompt)
	} else {
		opts = append(opts, "--prompt=  ")
	}

	// Pointer
	opts = append(opts, "--pointer="+b.settings.FzfPointer)

	// Border
	opts = append(opts, "--border="+b.settings.FzfBorder)

	// Border label
	if b.borderLabel != "" {
		opts = append(opts, "--border-label="+b.borderLabel)
		opts = append(opts, "--border-label-pos=3")
	}

	// Colors
	if b.settings.FzfColors != "" {
		opts = append(opts, "--color="+b.settings.FzfColors)
	}

	// Header
	if b.header != "" {
		opts = append(opts, "--header="+b.header)
		opts = append(opts, "--header-first")
	}

	// Expect keys (always include esc for back navigation)
	expectKeys := append([]string{"esc"}, b.expectKeys...)
	// Add secondary key
	if b.settings.SecondaryKey != "" {
		expectKeys = append(expectKeys, b.settings.SecondaryKey)
	}
	// Add action menu key
	if b.settings.ActionMenuKey != "" {
		expectKeys = append(expectKeys, b.settings.ActionMenuKey)
	}
	// Add direct action keys
	for _, key := range []string{
		b.settings.PopupKey,
		b.settings.WindowKey,
		b.settings.BackgroundWindowKey,
		b.settings.PaneRightKey,
		b.settings.PaneLeftKey,
		b.settings.PaneAboveKey,
		b.settings.PaneBelowKey,
	} {
		if key != "" {
			expectKeys = append(expectKeys, key)
		}
	}
	opts = append(opts, "--expect="+strings.Join(expectKeys, ","))

	// Bindings
	for _, bind := range b.bindCommands {
		opts = append(opts, "--bind="+bind)
	}

	return opts
}

// BuildForActionMenu returns options for the action selection menu
func BuildForActionMenu(settings *config.Settings, itemName string) []string {
	opts := []string{
		"--ansi",
		"--delimiter=\t",
		"--with-nth=2",
		"--height=100%",
		"--layout=reverse",
		"--border=rounded",
		"--border-label= Action: " + itemName + " ",
		"--border-label-pos=3",
		"--no-info",
		"--pointer=" + settings.FzfPointer,
		"--expect=enter,esc",
	}
	if settings.FzfColors != "" {
		opts = append(opts, "--color="+settings.FzfColors)
	}
	return opts
}

// BuildForWindowSwitcher returns options for the window switcher menu
func BuildForWindowSwitcher(settings *config.Settings) []string {
	opts := []string{
		"--ansi",
		"--delimiter=\t",
		"--with-nth=1",
		"--height=100%",
		"--layout=reverse",
		"--border=rounded",
		"--border-label= Windows ",
		"--border-label-pos=3",
		"--no-info",
		"--pointer=" + settings.FzfPointer,
		"--expect=enter,esc",
	}
	if settings.FzfColors != "" {
		opts = append(opts, "--color="+settings.FzfColors)
	}
	return opts
}
