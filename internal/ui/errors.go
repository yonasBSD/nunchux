package ui

import (
	"bufio"
	"fmt"
	"math/rand"
	"os"
	"strings"

	"nunchux/internal/config"
	"nunchux/internal/fzf"
)

// Chuck Norris programming facts for error screens
var chuckFacts = []string{
	"Chuck Norris can unit test entire applications with a single assert.",
	"Chuck Norris doesn't use web frameworks. The internet obeys him.",
	"Chuck Norris can delete the root folder and still boot.",
	"Chuck Norris's code doesn't follow conventions. Conventions follow his code.",
	"Chuck Norris can instantiate an abstract class.",
	"Chuck Norris doesn't need sudo. The system always trusts him.",
	"Chuck Norris can divide by zero.",
	"When Chuck Norris throws an exception, nothing can catch it.",
	"Chuck Norris's keyboard doesn't have a Ctrl key. He's always in control.",
	"Chuck Norris can compile syntax errors.",
	"Chuck Norris doesn't need garbage collection. Memory is too afraid to leak.",
	"Chuck Norris can read from /dev/null.",
	"Chuck Norris finished World of Warcraft.",
	"Chuck Norris can write infinite loops that finish in under 2 seconds.",
	"Chuck Norris's code is self-documenting. In binary.",
	"Chuck Norris doesn't pair program. The code pairs with him.",
	"When Chuck Norris git pushes, the remote pulls.",
	"Chuck Norris can access private methods. Publicly.",
	"Chuck Norris doesn't get compiler errors. The compiler gets Chuck Norris errors.",
	"Chuck Norris can make a class that is both abstract and final.",
}

// RandomChuckFact returns a random Chuck Norris fact
func RandomChuckFact() string {
	return chuckFacts[rand.Intn(len(chuckFacts))]
}

// ShowError displays an error with Chuck Norris fact
func ShowError(err error) {
	fmt.Println()
	fmt.Printf("\033[1;33m%s\033[0m\n", RandomChuckFact())
	fmt.Println()
	fmt.Printf("\033[90m... but you are not Chuck Norris :)\033[0m\n")
	fmt.Println()
	fmt.Printf("\033[1;31m%s\033[0m\n", err.Error())
	fmt.Println()
	fmt.Println("Press any key...")
	waitForKey()
}

// ShowMissingDependencies shows missing dependencies error
func ShowMissingDependencies(deps []string) {
	fmt.Println()
	fmt.Printf("\033[1;31mMissing Dependencies\033[0m\n")
	fmt.Println()
	for _, dep := range deps {
		fmt.Printf("  - %s\n", dep)
	}
	fmt.Println()
	fmt.Println("Install the missing dependencies and try again.")
	fmt.Println()
	fmt.Println("Press any key to exit...")
	waitForKey()
}

// ShowInvalidKey shows invalid keybinding error
func ShowInvalidKey(key string) {
	fmt.Println()
	fmt.Printf("\033[1;33mChuck Norris's keyboard doesn't have a Ctrl key.\033[0m\n")
	fmt.Printf("\033[1;33mHe's always in control.\033[0m\n")
	fmt.Printf("\033[90mbut your keyboard needs valid bindings...\033[0m\n")
	fmt.Println()
	fmt.Printf("\033[1;31mUnsupported key: %s\033[0m\n", key)
	fmt.Println()
	fmt.Println("Keys like shift-enter and ctrl-enter are not")
	fmt.Println("supported by terminals.")
	fmt.Println()
	fmt.Println("Good alternatives: alt-enter, ctrl-s, tab, ctrl-o")
	fmt.Println()
	fmt.Printf("\033[90mSee: https://man.archlinux.org/man/fzf.1.en\033[0m\n")
	fmt.Println()
	fmt.Printf("\033[90mPress any key...\033[0m\n")
	waitForKey()
}

// ShowConfigErrors shows config validation errors using fzf
// Returns true if user wants to edit the config file
func ShowConfigErrors(settings *config.Settings, configPath string, errors []string) bool {
	// Build header with Chuck Norris fact
	header := fmt.Sprintf("\033[1;33m%s\033[0m\n\033[90m... but you are not Chuck Norris :)\033[0m\n\n\033[1;31mConfig has problems:\033[0m\n\033[90menter: edit config │ esc: exit\033[0m",
		RandomChuckFact())

	// Build error list
	var lines []string
	for _, err := range errors {
		lines = append(lines, fmt.Sprintf("\033[31m•\033[0m %s", err))
	}

	opts := []string{
		"--ansi",
		"--layout=reverse",
		"--height=100%",
		"--highlight-line",
		"--no-preview",
		"--no-info",
		"--prompt= ",
		"--pointer=" + settings.FzfPointer,
		"--border=" + settings.FzfBorder,
		"--border-label= " + settings.Label + ": config error ",
		"--border-label-pos=3",
		"--color=" + settings.FzfColors,
		"--header=" + header,
		"--header-first",
		"--expect=enter,esc",
	}

	sel, err := fzf.Run(strings.Join(lines, "\n"), opts)
	if err != nil {
		return false
	}

	// Enter = edit config, Esc = just exit
	return sel.Key == "" || sel.Key == "enter"
}

// GetEditorCommand returns the user's preferred editor
func GetEditorCommand() string {
	editor := os.Getenv("VISUAL")
	if editor == "" {
		editor = os.Getenv("EDITOR")
	}
	if editor == "" {
		editor = "vim"
	}
	return editor
}

func waitForKey() {
	reader := bufio.NewReader(os.Stdin)
	reader.ReadByte()
}
