package onboarding

import (
	"bufio"
	"fmt"
	"os"

	"golang.org/x/term"
)

const (
	cyanColor   = "\033[1;36m"
	greenColor  = "\033[1;32m"
	dimColor    = "\033[90m"
	boldColor   = "\033[1m"
	resetColor  = "\033[0m"
)

// Result represents the result of the onboarding flow
type Result struct {
	ConfigPath string
	Canceled   bool
}

// RunSetup shows the setup menu and creates config
// This is called when nunchux is launched with --init flag inside a tmux popup
func RunSetup(configPath string) Result {
	options := []string{
		"Setup wizard",
		"Quick setup",
	}
	cursor := 0

	// Hide cursor
	fmt.Print("\033[?25l")
	defer fmt.Print("\033[?25h")

	// Set terminal to raw mode
	oldState, err := term.MakeRaw(int(os.Stdin.Fd()))
	if err != nil {
		return Result{Canceled: true}
	}
	defer term.Restore(int(os.Stdin.Fd()), oldState)

	reader := bufio.NewReader(os.Stdin)

	for {
		drawSetupMenu(options, cursor)

		b, err := reader.ReadByte()
		if err != nil {
			return Result{Canceled: true}
		}

		switch b {
		case 27: // Escape
			if reader.Buffered() > 0 {
				seq := make([]byte, 2)
				reader.Read(seq)
				switch string(seq) {
				case "[A": // Up
					if cursor > 0 {
						cursor--
					}
				case "[B": // Down
					if cursor < len(options)-1 {
						cursor++
					}
				}
			} else {
				return Result{Canceled: true}
			}
		case 'k':
			if cursor > 0 {
				cursor--
			}
		case 'j':
			if cursor < len(options)-1 {
				cursor++
			}
		case 13: // Enter
			term.Restore(int(os.Stdin.Fd()), oldState)
			fmt.Print("\033[?25h")

			if cursor == 0 {
				return runWizard(configPath)
			} else {
				if err := GenerateMinimalConfig(configPath); err != nil {
					fmt.Printf("\nError: %v\n", err)
					return Result{Canceled: true}
				}
				showSuccess(configPath)
				return Result{ConfigPath: configPath}
			}
		}
	}
}

func drawSetupMenu(options []string, cursor int) {
	// Clear screen and move to top
	fmt.Print("\033[2J\033[H")

	fmt.Print("\r\n")
	fmt.Print(" " + cyanColor + "No config file found" + resetColor + "\r\n")
	fmt.Print(" " + dimColor + "Create one to get started?" + resetColor + "\r\n")
	fmt.Print("\r\n")

	for i, opt := range options {
		if cursor == i {
			fmt.Print(" " + cyanColor + "> " + opt + resetColor + "\r\n")
		} else {
			fmt.Print("   " + dimColor + opt + resetColor + "\r\n")
		}
	}

	fmt.Print("\r\n")
	fmt.Print(" " + dimColor + "↑/↓ navigate · enter select · esc exit" + resetColor + "\r\n")
}

func runWizard(configPath string) Result {
	tools := DetectInstalledTools()

	if len(tools) == 0 {
		if err := GenerateMinimalConfig(configPath); err != nil {
			fmt.Printf("\nError: %v\n", err)
			return Result{Canceled: true}
		}
		showSuccess(configPath)
		return Result{ConfigPath: configPath}
	}

	selected := make([]bool, len(tools))
	for i := range selected {
		selected[i] = true
	}
	cursor := 0

	fmt.Print("\033[?25l")
	defer fmt.Print("\033[?25h")

	oldState, err := term.MakeRaw(int(os.Stdin.Fd()))
	if err != nil {
		return Result{Canceled: true}
	}
	defer term.Restore(int(os.Stdin.Fd()), oldState)

	reader := bufio.NewReader(os.Stdin)

	for {
		drawWizard(tools, selected, cursor)

		b, err := reader.ReadByte()
		if err != nil {
			return Result{Canceled: true}
		}

		switch b {
		case 27:
			if reader.Buffered() > 0 {
				seq := make([]byte, 2)
				reader.Read(seq)
				switch string(seq) {
				case "[A":
					if cursor > 0 {
						cursor--
					}
				case "[B":
					if cursor < len(tools)-1 {
						cursor++
					}
				}
			} else {
				return Result{Canceled: true}
			}
		case 'k':
			if cursor > 0 {
				cursor--
			}
		case 'j':
			if cursor < len(tools)-1 {
				cursor++
			}
		case ' ':
			selected[cursor] = !selected[cursor]
		case 'a', 'A':
			allSelected := true
			for _, s := range selected {
				if !s {
					allSelected = false
					break
				}
			}
			for i := range selected {
				selected[i] = !allSelected
			}
		case 13:
			term.Restore(int(os.Stdin.Fd()), oldState)
			fmt.Print("\033[?25h")

			var selectedTools []Tool
			for i, t := range tools {
				if selected[i] {
					selectedTools = append(selectedTools, t)
				}
			}

			var err error
			if len(selectedTools) == 0 {
				err = GenerateMinimalConfig(configPath)
			} else {
				err = GenerateDetectedConfig(configPath, selectedTools)
			}

			if err != nil {
				fmt.Printf("\nError: %v\n", err)
				return Result{Canceled: true}
			}

			showSuccess(configPath)
			return Result{ConfigPath: configPath}
		}
	}
}

func drawWizard(tools []Tool, selected []bool, cursor int) {
	fmt.Print("\033[2J\033[H")

	fmt.Print("\r\n")
	fmt.Print(" " + cyanColor + fmt.Sprintf("Found %d tools", len(tools)) + resetColor + "\r\n")
	fmt.Print(" " + dimColor + "Select which to add:" + resetColor + "\r\n")
	fmt.Print("\r\n")

	for i, t := range tools {
		check := " "
		if selected[i] {
			check = "✓"
		}
		if cursor == i {
			fmt.Print(" " + cyanColor + ">[" + check + "] " + t.Name + resetColor + "\r\n")
		} else {
			fmt.Print("  [" + check + "] " + dimColor + t.Name + resetColor + "\r\n")
		}
	}

	fmt.Print("\r\n")
	fmt.Print(" " + dimColor + "space toggle · a all · enter create · esc back" + resetColor + "\r\n")
}

func showSuccess(configPath string) {
	fmt.Print("\033[2J\033[H")
	fmt.Print("\r\n")
	fmt.Print(" " + greenColor + "✓ Config created!" + resetColor + "\r\n")
	fmt.Print("\r\n")
	fmt.Print(" Edit to add your apps,\r\n")
	fmt.Print(" then run nunchux again.\r\n")
	fmt.Print("\r\n")
	fmt.Print(" " + dimColor + "Press any key..." + resetColor + "\r\n")

	// Wait for keypress
	reader := bufio.NewReader(os.Stdin)
	reader.ReadByte()
}

