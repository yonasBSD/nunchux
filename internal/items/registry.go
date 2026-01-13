package items

import (
	"context"
	"fmt"
	"sort"
	"strings"
	"sync"

	"nunchux/internal/config"
)

// menuResult holds formatted item data for sorting
type menuResult struct {
	name string
	line string
}

// Registry holds all configured items
type Registry struct {
	Items            []Item
	TaskrunnerItems  []Item // Taskrunner items (including dividers)
	TaskrunnerConfig []config.TaskrunnerConfig
	Settings         *config.Settings
	Order            config.OrderConfig
	Shortcuts        map[string]string         // key -> item name
	ValidationErrors []config.ValidationError  // shortcut validation errors
}

// NewRegistry creates a registry from config
func NewRegistry(cfg *config.Config) *Registry {
	r := &Registry{
		Settings:         &cfg.Settings,
		TaskrunnerConfig: cfg.Taskrunners,
		Order:            cfg.Order,
	}

	// Validate and register shortcuts
	validator := config.NewShortcutValidator(&cfg.Settings)

	// Add all items to single slice
	for _, app := range cfg.Apps {
		item := &AppItem{App: app, Settings: &cfg.Settings}
		r.Items = append(r.Items, item)
		validator.Register(app.Shortcut, app.Name)
	}

	for _, menu := range cfg.Menus {
		item := &MenuItem{Menu: menu, Settings: &cfg.Settings}
		r.Items = append(r.Items, item)
		validator.Register(menu.Shortcut, menu.Name)
	}

	for _, db := range cfg.Dirbrowsers {
		item := &DirbrowserItem{Dirbrowser: db, Settings: &cfg.Settings}
		r.Items = append(r.Items, item)
		validator.Register(db.Shortcut, db.Name)
	}

	r.Shortcuts = validator.Shortcuts()
	r.ValidationErrors = validator.Errors()

	return r
}

// LoadTaskrunners loads taskrunner items from provider scripts
// This should be called once at startup or when refreshing the menu
func (r *Registry) LoadTaskrunners(ctx context.Context) {
	r.TaskrunnerItems = nil

	for _, cfg := range r.TaskrunnerConfig {
		if !cfg.Enabled {
			continue
		}

		tasks, icon, label, err := LoadTaskrunnerTasks(ctx, cfg, r.Settings)
		if err != nil || len(tasks) == 0 {
			continue
		}

		// Add divider for this taskrunner
		r.TaskrunnerItems = append(r.TaskrunnerItems, &TaskrunnerDivider{
			Runner: cfg.Name,
			Icon:   icon,
			Label:  label,
		})

		// Add task items
		for _, task := range tasks {
			r.TaskrunnerItems = append(r.TaskrunnerItems, &TaskrunnerItem{
				Runner:   cfg.Name,
				Task:     task,
				Config:   cfg,
				Settings: r.Settings,
				Icon:     icon,
				Label:    label,
			})
		}
	}
}

// BuildMenu builds the menu content for fzf
// currentMenu is empty for main menu, or the submenu name
func (r *Registry) BuildMenu(ctx context.Context, runningWindows map[string]bool, currentMenu string) string {
	// Filter items for current menu
	var filtered []Item
	for _, item := range r.Items {
		if currentMenu == "" {
			// Main menu: show items without parent
			if item.Parent() == "" {
				filtered = append(filtered, item)
			}
		} else {
			// Submenu: show items with matching parent
			if item.Parent() == currentMenu {
				filtered = append(filtered, item)
			}
		}
	}

	// Calculate max display name width for alignment
	maxWidth := 0
	for _, item := range filtered {
		if w := len(item.DisplayName()); w > maxWidth {
			maxWidth = w
		}
	}
	// Include taskrunner items in width calculation (main menu only)
	if currentMenu == "" {
		for _, item := range r.TaskrunnerItems {
			if w := len(item.DisplayName()); w > maxWidth {
				maxWidth = w
			}
		}
	}

	// Format all items in parallel
	results := make([]menuResult, len(filtered))

	var wg sync.WaitGroup
	for i, item := range filtered {
		wg.Add(1)
		go func(i int, item Item) {
			defer wg.Done()
			isRunning := runningWindows[item.Name()]
			results[i] = menuResult{
				name: item.Name(),
				line: item.FormatLine(ctx, isRunning),
			}
		}(i, item)
	}
	wg.Wait()

	// Sort by order config
	r.sortResults(results, currentMenu)

	// Build output with aligned columns
	var lines []string
	for _, res := range results {
		line := alignDisplayColumn(res.line, maxWidth)
		if r.Settings.ShowHelp {
			line = addShortcutPrefix(line)
		}
		lines = append(lines, line)
	}

	// Add taskrunner items for main menu
	if currentMenu == "" && len(r.TaskrunnerItems) > 0 {
		for _, item := range r.TaskrunnerItems {
			// Check running status for taskrunner window
			isRunning := false
			if trItem, ok := item.(*TaskrunnerItem); ok {
				isRunning = runningWindows[trItem.WindowName()]
			}
			line := item.FormatLine(ctx, isRunning)
			// Don't align dividers
			if _, isDivider := item.(*TaskrunnerDivider); !isDivider {
				line = alignDisplayColumn(line, maxWidth)
			}
			if r.Settings.ShowHelp {
				line = addShortcutPrefix(line)
			}
			lines = append(lines, line)
		}
	}

	return strings.Join(lines, "\n")
}

// alignDisplayColumn re-aligns the display column to the specified width
// Line format: "icon name\x00desc\t..." -> "icon name<padding>  desc\t..."
func alignDisplayColumn(line string, maxWidth int) string {
	parts := strings.SplitN(line, "\t", 2)
	if len(parts) < 2 {
		return line
	}

	display := parts[0]
	rest := parts[1]

	// Parse display: "icon name\x00desc" using null byte separator
	nullIdx := strings.Index(display, "\x00")
	if nullIdx < 0 {
		return line
	}

	prefix := display[:nullIdx] // "icon name"
	desc := display[nullIdx+1:] // description

	// Extract icon (first 2 runes) and name
	// Icon is usually "○ " or "▸ " or "● " (icon char + space)
	// Use rune-based indexing for proper Unicode handling
	runes := []rune(prefix)
	if len(runes) > 2 {
		icon := string(runes[:2])
		name := string(runes[2:])

		// Rebuild with proper padding: icon + name (padded) + two spaces + desc
		newDisplay := fmt.Sprintf("%s%-*s  %s", icon, maxWidth, name, desc)
		return newDisplay + "\t" + rest
	}

	return line
}

// addShortcutPrefix prepends a shortcut prefix to a menu line
// Line format: display\tshortcut\tname
// Output format: [shortcut]│ display\tshortcut\tname (shortcut in gray, 9 chars wide)
func addShortcutPrefix(line string) string {
	parts := strings.SplitN(line, "\t", 3)
	if len(parts) < 2 {
		return line
	}

	display := parts[0]
	shortcut := parts[1]
	rest := ""
	if len(parts) > 2 {
		rest = parts[2]
	}

	if shortcut != "" {
		// Gray color (ANSI 244) for shortcut, left-justified 9 chars
		prefix := fmt.Sprintf("\033[38;5;244m%-9s\033[0m│ ", "["+shortcut+"]")
		return prefix + display + "\t" + shortcut + "\t" + rest
	}

	// No shortcut: 9 spaces for alignment
	return "         │ " + display + "\t" + shortcut + "\t" + rest
}

func (r *Registry) sortResults(results []menuResult, currentMenu string) {
	var orderList []string
	if currentMenu == "" {
		orderList = r.Order.Main
	} else if submenuOrder, ok := r.Order.Submenus[currentMenu]; ok {
		orderList = submenuOrder
	}

	orderMap := make(map[string]int)
	for i, name := range orderList {
		orderMap[name] = i
	}

	sort.Slice(results, func(i, j int) bool {
		posI, hasI := orderMap[results[i].name]
		posJ, hasJ := orderMap[results[j].name]

		if hasI && hasJ {
			return posI < posJ
		}
		if hasI {
			return true
		}
		if hasJ {
			return false
		}
		return results[i].name < results[j].name
	})
}

// FindItem finds an item by name
func (r *Registry) FindItem(name string) Item {
	for _, item := range r.Items {
		if item.Name() == name {
			return item
		}
	}
	return nil
}

// FindApp finds an app by name (returns nil if not found or wrong type)
func (r *Registry) FindApp(name string) *AppItem {
	item := r.FindItem(name)
	if item == nil {
		return nil
	}
	if app, ok := item.(*AppItem); ok {
		return app
	}
	return nil
}

// FindMenu finds a menu by name
func (r *Registry) FindMenu(name string) *MenuItem {
	item := r.FindItem(name)
	if item == nil {
		return nil
	}
	if menu, ok := item.(*MenuItem); ok {
		return menu
	}
	return nil
}

// FindDirbrowser finds a dirbrowser by name
func (r *Registry) FindDirbrowser(name string) *DirbrowserItem {
	item := r.FindItem(name)
	if item == nil {
		return nil
	}
	if db, ok := item.(*DirbrowserItem); ok {
		return db
	}
	return nil
}

// GetItemByShortcut returns the item name for a shortcut key
func (r *Registry) GetItemByShortcut(key string) string {
	return r.Shortcuts[key]
}

// FindTaskrunnerItem finds a taskrunner item by name (format: runner:task)
func (r *Registry) FindTaskrunnerItem(name string) *TaskrunnerItem {
	for _, item := range r.TaskrunnerItems {
		if trItem, ok := item.(*TaskrunnerItem); ok {
			if trItem.Name() == name {
				return trItem
			}
		}
	}
	return nil
}
