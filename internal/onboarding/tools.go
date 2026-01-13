package onboarding

import (
	"os/exec"
)

// Tool represents a known TUI tool that can be detected
type Tool struct {
	Cmd      string // Command name
	Name     string // Display name
	Desc     string // Description
	Category string // Category (git, docker, system, editor, k8s, files)
}

// KnownTools is the list of TUI tools we can detect
var KnownTools = []Tool{
	{Cmd: "lazygit", Name: "lazygit", Desc: "Git TUI", Category: "git"},
	{Cmd: "lazydocker", Name: "lazydocker", Desc: "Docker TUI", Category: "docker"},
	{Cmd: "btop", Name: "btop", Desc: "System monitor", Category: "system"},
	{Cmd: "htop", Name: "htop", Desc: "Process viewer", Category: "system"},
	{Cmd: "ncdu", Name: "ncdu", Desc: "Disk usage analyzer", Category: "system"},
	{Cmd: "nvim", Name: "neovim", Desc: "Neovim editor", Category: "editor"},
	{Cmd: "k9s", Name: "k9s", Desc: "Kubernetes TUI", Category: "k8s"},
	{Cmd: "tig", Name: "tig", Desc: "Git history browser", Category: "git"},
	{Cmd: "ranger", Name: "ranger", Desc: "File manager", Category: "files"},
	{Cmd: "lf", Name: "lf", Desc: "File manager", Category: "files"},
	{Cmd: "yazi", Name: "yazi", Desc: "File manager", Category: "files"},
	{Cmd: "nnn", Name: "nnn", Desc: "File manager", Category: "files"},
	{Cmd: "broot", Name: "broot", Desc: "File tree navigator", Category: "files"},
}

// DetectInstalledTools returns the list of tools that are installed on the system
func DetectInstalledTools() []Tool {
	var installed []Tool
	for _, tool := range KnownTools {
		if _, err := exec.LookPath(tool.Cmd); err == nil {
			installed = append(installed, tool)
		}
	}
	return installed
}
