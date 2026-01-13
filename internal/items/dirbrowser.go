package items

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"nunchux/internal/config"
)

// DirbrowserItem represents a directory browser menu item
type DirbrowserItem struct {
	Dirbrowser config.Dirbrowser
	Settings   *config.Settings
}

// Ensure DirbrowserItem implements Item
var _ Item = (*DirbrowserItem)(nil)

func (d *DirbrowserItem) Name() string {
	return d.Dirbrowser.Name
}

func (d *DirbrowserItem) Type() ItemType {
	return TypeDirbrowser
}

func (d *DirbrowserItem) Shortcut() string {
	return d.Dirbrowser.Shortcut
}

func (d *DirbrowserItem) Parent() string {
	return "" // Dirbrowsers are always top-level
}

func (d *DirbrowserItem) DisplayName() string {
	return d.Dirbrowser.Name
}

func (d *DirbrowserItem) FormatLine(ctx context.Context, isRunning bool) string {
	icon := "▸"

	// Get file count (with timeout)
	fileCount := d.getFileCount(ctx)
	countStr := fmt.Sprintf("(%d files)", fileCount)
	if fileCount > 1000 {
		countStr = "(1000+ files)"
	} else if fileCount == 1 {
		countStr = "(1 file)"
	}

	// Use \x00 as separator between name and desc for reliable parsing
	display := fmt.Sprintf("%s %s\x00%s", icon, d.Dirbrowser.Name, countStr)

	return fmt.Sprintf("%s\t%s\t%s",
		display,
		d.Dirbrowser.Shortcut,
		"dirbrowser:"+d.Dirbrowser.Name,
	)
}

// Dirbrowser-specific accessors with defaults from Settings

func (d *DirbrowserItem) GetWidth() string {
	if d.Dirbrowser.Width != "" {
		return d.Dirbrowser.Width
	}
	return d.Settings.PopupWidth
}

func (d *DirbrowserItem) GetHeight() string {
	if d.Dirbrowser.Height != "" {
		return d.Dirbrowser.Height
	}
	return d.Settings.PopupHeight
}

func (d *DirbrowserItem) GetPrimaryAction() config.Action {
	if d.Dirbrowser.PrimaryAction != "" {
		return d.Dirbrowser.PrimaryAction
	}
	return d.Settings.PrimaryAction
}

func (d *DirbrowserItem) GetSecondaryAction() config.Action {
	if d.Dirbrowser.SecondaryAction != "" {
		return d.Dirbrowser.SecondaryAction
	}
	return d.Settings.SecondaryAction
}

// getFileCount returns the number of files in the directory
func (d *DirbrowserItem) getFileCount(ctx context.Context) int {
	ctx, cancel := context.WithTimeout(ctx, 500*time.Millisecond)
	defer cancel()

	args := d.buildFindArgs()
	cmd := exec.CommandContext(ctx, "find", args...)
	output, err := cmd.Output()
	if err != nil {
		return 0
	}

	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	if len(lines) == 1 && lines[0] == "" {
		return 0
	}
	return len(lines)
}

// expandPath expands ~ to home directory
func (d *DirbrowserItem) expandPath(path string) string {
	if strings.HasPrefix(path, "~/") {
		home, _ := os.UserHomeDir()
		return filepath.Join(home, path[2:])
	}
	return path
}

// buildFindArgs builds arguments for the find command
func (d *DirbrowserItem) buildFindArgs() []string {
	dir := d.expandPath(d.Dirbrowser.Directory)
	depth := d.Dirbrowser.Depth
	if depth == 0 {
		depth = 1 // Default depth
	}

	args := []string{dir, "-maxdepth", strconv.Itoa(depth), "-type", "f"}

	// Add exclusion patterns
	if d.Settings.ExcludePatterns != "" {
		patterns := strings.Split(d.Settings.ExcludePatterns, ",")
		for _, pattern := range patterns {
			pattern = strings.TrimSpace(pattern)
			if pattern == "" {
				continue
			}
			if strings.HasPrefix(pattern, "*") {
				// Glob pattern - match filename only
				args = append(args, "!", "-name", pattern)
			} else {
				// Directory/file name
				args = append(args, "!", "-path", "*/"+pattern+"/*", "!", "-name", pattern)
			}
		}
	}

	// Add glob filter
	if d.Dirbrowser.Glob != "" {
		args = append(args, "-name", d.Dirbrowser.Glob)
	}

	return args
}

// FileEntry represents a file in the dirbrowser listing
type FileEntry struct {
	Path     string
	RelPath  string
	Folder   string
	Filename string
	ModTime  time.Time
}

// ListFiles returns files in the directory with metadata
func (d *DirbrowserItem) ListFiles(ctx context.Context) ([]FileEntry, error) {
	dir := d.expandPath(d.Dirbrowser.Directory)
	args := d.buildFindArgs()

	// Add printf to get mtime
	args = append(args, "-printf", "%T@\t%p\n")

	cmd := exec.CommandContext(ctx, "find", args...)
	output, err := cmd.Output()
	if err != nil {
		return nil, err
	}

	var entries []FileEntry
	lines := strings.Split(strings.TrimSpace(string(output)), "\n")

	for _, line := range lines {
		if line == "" {
			continue
		}

		parts := strings.SplitN(line, "\t", 2)
		if len(parts) != 2 {
			continue
		}

		mtimeFloat, _ := strconv.ParseFloat(parts[0], 64)
		modTime := time.Unix(int64(mtimeFloat), 0)
		filePath := parts[1]

		// Get relative path
		relPath := filePath
		if strings.HasPrefix(filePath, dir+"/") {
			relPath = filePath[len(dir)+1:]
		}

		// Get folder (first component of relative path)
		folder := relPath
		filename := filepath.Base(filePath)
		if idx := strings.Index(relPath, "/"); idx != -1 {
			folder = relPath[:idx]
		} else {
			folder = filename
		}

		entries = append(entries, FileEntry{
			Path:     filePath,
			RelPath:  relPath,
			Folder:   folder,
			Filename: filename,
			ModTime:  modTime,
		})
	}

	// Sort entries based on sort mode
	d.sortEntries(entries)

	return entries, nil
}

// sortEntries sorts file entries based on the configured sort mode
func (d *DirbrowserItem) sortEntries(entries []FileEntry) {
	sortMode := d.Dirbrowser.Sort
	if sortMode == "" {
		sortMode = "modified"
	}
	sortDir := d.Dirbrowser.SortDirection
	if sortDir == "" {
		sortDir = "descending"
	}
	descending := sortDir == "descending"

	switch sortMode {
	case "alphabetical":
		// Sort by relative path
		for i := 0; i < len(entries)-1; i++ {
			for j := i + 1; j < len(entries); j++ {
				less := entries[i].RelPath < entries[j].RelPath
				if descending {
					less = !less
				}
				if !less {
					entries[i], entries[j] = entries[j], entries[i]
				}
			}
		}

	case "modified-folder":
		// Group by folder, sort folders by newest file, then files by mtime within folder
		folderMaxTime := make(map[string]time.Time)
		for _, e := range entries {
			if t, ok := folderMaxTime[e.Folder]; !ok || e.ModTime.After(t) {
				folderMaxTime[e.Folder] = e.ModTime
			}
		}

		for i := 0; i < len(entries)-1; i++ {
			for j := i + 1; j < len(entries); j++ {
				ti := folderMaxTime[entries[i].Folder]
				tj := folderMaxTime[entries[j].Folder]

				var less bool
				if ti.Equal(tj) {
					// Same folder max time, sort by file mtime
					less = entries[i].ModTime.Before(entries[j].ModTime)
				} else {
					less = ti.Before(tj)
				}
				if descending {
					less = !less
				}
				if !less {
					entries[i], entries[j] = entries[j], entries[i]
				}
			}
		}

	default: // "modified"
		// Sort by modification time
		for i := 0; i < len(entries)-1; i++ {
			for j := i + 1; j < len(entries); j++ {
				less := entries[i].ModTime.Before(entries[j].ModTime)
				if descending {
					less = !less
				}
				if !less {
					entries[i], entries[j] = entries[j], entries[i]
				}
			}
		}
	}
}

// FormatFileEntry formats a file entry for fzf display
func (d *DirbrowserItem) FormatFileEntry(e FileEntry) string {
	// Format modification time as "Xm ago", "Xh ago", etc.
	ago := formatAgo(time.Since(e.ModTime))

	// Format display: folder/filename with folder in gray if different from filename
	var display string
	if e.Folder == e.Filename {
		display = e.Filename
	} else {
		// Gray color for folder
		display = fmt.Sprintf("\033[38;5;244m%s/\033[0m%s", e.Folder, e.Filename)
	}

	// Format: ○  Xh ago │ display\tpath\twidth\theight
	return fmt.Sprintf("○  %8s │ %s\t%s\t%s\t%s",
		ago, display, e.Path, d.GetWidth(), d.GetHeight())
}

// formatAgo formats a duration as a human-readable "ago" string
func formatAgo(d time.Duration) string {
	secs := int(d.Seconds())
	if secs < 60 {
		return fmt.Sprintf("%ds ago", secs)
	} else if secs < 3600 {
		return fmt.Sprintf("%dm ago", secs/60)
	} else if secs < 86400 {
		return fmt.Sprintf("%dh ago", secs/3600)
	}
	return fmt.Sprintf("%dd ago", secs/86400)
}
