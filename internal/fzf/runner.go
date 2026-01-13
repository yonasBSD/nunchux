package fzf

import (
	"os"
	"os/exec"
	"strings"
)

// Selection represents the fzf selection result
type Selection struct {
	Key      string   // The key pressed (empty for default/enter)
	Line     string   // The full selected line
	Fields   []string // Tab-split fields from the line
	Canceled bool     // True if user pressed Esc or canceled
}

// Run executes fzf with the given input and options, returns the selection
func Run(input string, opts []string) (*Selection, error) {
	cmd := exec.Command("fzf", opts...)
	cmd.Stdin = strings.NewReader(input)
	cmd.Stderr = os.Stderr

	output, err := cmd.Output()
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			// Exit code 130 = canceled (Esc/Ctrl-C)
			// Exit code 1 = no match
			if exitErr.ExitCode() == 130 || exitErr.ExitCode() == 1 {
				return &Selection{Canceled: true}, nil
			}
		}
		return nil, err
	}

	return ParseOutput(string(output))
}

// ParseOutput parses fzf output into a Selection
// Format: first line is the key pressed (from --expect), second line is selection
func ParseOutput(output string) (*Selection, error) {
	// Don't TrimSpace - the leading newline means "enter" was pressed
	output = strings.TrimSuffix(output, "\n")
	lines := strings.SplitN(output, "\n", 2)

	if len(lines) == 0 || (len(lines) == 1 && lines[0] == "") {
		return &Selection{Canceled: true}, nil
	}

	sel := &Selection{}

	// First line is the key pressed (from --expect)
	// Empty means enter was pressed
	sel.Key = lines[0]

	// Second line is the selection
	if len(lines) >= 2 {
		sel.Line = lines[1]
		sel.Fields = strings.Split(sel.Line, "\t")
	}

	return sel, nil
}

// IsAvailable checks if fzf is installed
func IsAvailable() bool {
	_, err := exec.LookPath("fzf")
	return err == nil
}

// Version returns the installed fzf version
func Version() (string, error) {
	output, err := exec.Command("fzf", "--version").Output()
	if err != nil {
		return "", err
	}
	// Output format: "0.54.3 (brew)" or "0.54.3"
	version := strings.TrimSpace(string(output))
	if idx := strings.Index(version, " "); idx != -1 {
		version = version[:idx]
	}
	return version, nil
}
