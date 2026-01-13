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

// MenuItem represents a submenu item
type MenuItem struct {
	Menu     config.Menu
	Settings *config.Settings
}

// Ensure MenuItem implements Item
var _ Item = (*MenuItem)(nil)

func (m *MenuItem) Name() string {
	return m.Menu.Name
}

func (m *MenuItem) Type() ItemType {
	return TypeMenu
}

func (m *MenuItem) Shortcut() string {
	return m.Menu.Shortcut
}

func (m *MenuItem) Parent() string {
	return "" // Menus are always top-level
}

func (m *MenuItem) DisplayName() string {
	return m.Menu.Name
}

func (m *MenuItem) FormatLine(ctx context.Context, isRunning bool) string {
	icon := "▸"

	desc := m.Menu.Desc
	if status := m.getStatus(ctx); status != "" {
		if desc != "" {
			desc = desc + " " + status
		} else {
			desc = status
		}
	}

	// Use \x00 as separator between name and desc for reliable parsing
	display := fmt.Sprintf("%s %s\x00%s", icon, m.Menu.Name, desc)

	return fmt.Sprintf("%s\t%s\t%s",
		display,
		m.Menu.Shortcut,
		m.Menu.Name,
	)
}

// GetPrimaryAction returns empty - menus don't have actions (they open submenus)
func (m *MenuItem) GetPrimaryAction() config.Action {
	return ""
}

// GetSecondaryAction returns empty - menus don't have actions
func (m *MenuItem) GetSecondaryAction() config.Action {
	return ""
}

func (m *MenuItem) getStatus(ctx context.Context) string {
	if m.Menu.Status == "" {
		return ""
	}

	ctx, cancel := context.WithTimeout(ctx, 500*time.Millisecond)
	defer cancel()

	cmd := exec.CommandContext(ctx, "bash", "-c", m.Menu.Status)

	// Add bin directory to PATH for helper scripts (lines, ago, nearest)
	if m.Settings.BinDir != "" {
		cmd.Env = append(os.Environ(), "PATH="+m.Settings.BinDir+":"+os.Getenv("PATH"))
	}

	output, err := cmd.Output()
	if err != nil {
		return ""
	}

	return strings.TrimSpace(string(output))
}
