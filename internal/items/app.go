package items

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"

	"nunchux/internal/config"
)

// AppItem represents an app menu item
type AppItem struct {
	App      config.App
	Settings *config.Settings
}

// Ensure AppItem implements Item
var _ Item = (*AppItem)(nil)

func (a *AppItem) Name() string {
	return a.App.Name
}

func (a *AppItem) Type() ItemType {
	return TypeApp
}

func (a *AppItem) Shortcut() string {
	return a.App.Shortcut
}

func (a *AppItem) Parent() string {
	return a.App.Parent
}

// DisplayName returns the name to show in the menu
func (a *AppItem) DisplayName() string {
	if a.App.Parent != "" {
		return strings.TrimPrefix(a.App.Name, a.App.Parent+"/")
	}
	return a.App.Name
}

func (a *AppItem) FormatLine(ctx context.Context, isRunning bool) string {
	icon := a.Settings.IconStopped
	if isRunning {
		icon = a.Settings.IconRunning
	}

	desc := a.App.Desc
	if status := a.getStatus(ctx); status != "" {
		if desc != "" {
			desc = desc + " " + status
		} else {
			desc = status
		}
	}

	// Use \x00 as separator between name and desc for reliable parsing
	display := fmt.Sprintf("%s %s\x00%s", icon, a.DisplayName(), desc)

	return fmt.Sprintf("%s\t%s\t%s",
		display,
		a.App.Shortcut,
		a.App.Name,
	)
}

func (a *AppItem) getStatus(ctx context.Context) string {
	statusCmd := a.App.Status
	if a.App.StatusScript != "" {
		statusCmd = "source " + a.App.StatusScript
	}
	if statusCmd == "" {
		return ""
	}

	ctx, cancel := context.WithTimeout(ctx, 500*time.Millisecond)
	defer cancel()

	cmd := exec.CommandContext(ctx, "bash", "-c", statusCmd)

	// Add bin directory to PATH for helper scripts (lines, ago, nearest)
	if a.Settings.BinDir != "" {
		cmd.Env = append(os.Environ(), "PATH="+a.Settings.BinDir+":"+os.Getenv("PATH"))
	}

	output, err := cmd.Output()
	if err != nil {
		return ""
	}

	return strings.TrimSpace(string(output))
}

// App-specific accessors with defaults from Settings

func (a *AppItem) GetWidth() string {
	if a.App.Width != "" {
		return a.App.Width
	}
	return a.Settings.PopupWidth
}

func (a *AppItem) GetHeight() string {
	if a.App.Height != "" {
		return a.App.Height
	}
	return a.Settings.PopupHeight
}

func (a *AppItem) GetPrimaryAction() config.Action {
	if a.App.PrimaryAction != "" {
		return a.App.PrimaryAction
	}
	return a.Settings.PrimaryAction
}

func (a *AppItem) GetSecondaryAction() config.Action {
	if a.App.SecondaryAction != "" {
		return a.App.SecondaryAction
	}
	return a.Settings.SecondaryAction
}
