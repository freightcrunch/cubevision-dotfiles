package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// ─── Nordic Night Palette ─────────────────────────────────────────
var (
	nord3  = lipgloss.Color("#4C566A")
	nord4  = lipgloss.Color("#D8DEE9")
	nord6  = lipgloss.Color("#ECEFF4")
	nord8  = lipgloss.Color("#BF616A")
	nord10 = lipgloss.Color("#EBCB8B")
	nord11 = lipgloss.Color("#A3BE8C")
	nord12 = lipgloss.Color("#88C0D0")
	nord13 = lipgloss.Color("#81A1C1")
	nord14 = lipgloss.Color("#B48EAD")
	nord15 = lipgloss.Color("#5E81AC")
)

// ─── Styles ───────────────────────────────────────────────────────
var (
	titleStyle    = lipgloss.NewStyle().Bold(true).Foreground(nord12).PaddingLeft(2)
	subtitleStyle = lipgloss.NewStyle().Foreground(nord3).PaddingLeft(2)
	selectedStyle = lipgloss.NewStyle().Foreground(nord11).Bold(true)
	cursorStyle   = lipgloss.NewStyle().Foreground(nord13).Bold(true)
	dimStyle      = lipgloss.NewStyle().Foreground(nord3)
	checkStyle    = lipgloss.NewStyle().Foreground(nord11)
	categoryStyle = lipgloss.NewStyle().Foreground(nord14).Bold(true).PaddingLeft(2).MarginTop(1)
	helpStyle     = lipgloss.NewStyle().Foreground(nord3).PaddingLeft(2)
	headerStyle   = lipgloss.NewStyle().Bold(true).Foreground(nord6).Background(nord15).Padding(0, 2)
	warnStyle     = lipgloss.NewStyle().Foreground(nord10).PaddingLeft(2)
	errStyle      = lipgloss.NewStyle().Foreground(nord8).Bold(true).PaddingLeft(2)
	okStyle       = lipgloss.NewStyle().Foreground(nord11).Bold(true).PaddingLeft(2)
	descStyle     = lipgloss.NewStyle().Foreground(nord4).PaddingLeft(2)
)

// ─── Data ─────────────────────────────────────────────────────────

type profileDef struct {
	name string
	desc string
	flag string
	// Default module preset: indices into modules to deselect
	deselect []int
}

type moduleDef struct {
	flag     string
	name     string
	desc     string
	category string
}

var profiles = []profileDef{
	{
		name:     "Ryzen 7 260",
		desc:     "8c/16t · 16 GB · Radeon 780M (current machine)",
		flag:     "ryzen",
		deselect: []int{11, 12}, // ML, CUDA off by default (no NVIDIA GPU)
	},
	{
		name:     "Threadripper PRO 5995WX",
		desc:     "64c/128t · 256 GB · NVIDIA GPU (workstation)",
		flag:     "threadripper",
		deselect: []int{}, // everything on
	},
	{
		name:     "Custom",
		desc:     "Choose your own modules",
		flag:     "custom",
		deselect: []int{},
	},
}

var modules = []moduleDef{
	// Core (0-1)
	{"--packages", "System Packages", "build-essential, compilers, CLI utils, 3D/pointcloud libs", "Core"},
	{"--git", "Git Configuration", "default branch, rebase, delta, histogram diff", "Core"},
	// Shell & Editors (2-4)
	{"--zsh", "Zsh", "zinit, powerlevel10k, autosuggestions, fzf-tab", "Shell & Editors"},
	{"--nvim", "Neovim + LazyVim", "LSPs, Nordic Night, treesitter, extras", "Shell & Editors"},
	{"--tmux", "Tmux", "Nordic Night bar, vim navigation, mouse support", "Shell & Editors"},
	// Languages (5-8)
	{"--rust", "Rust", "stable + nightly, wasm, cargo-leptos, sccache", "Languages"},
	{"--python", "Python", "ruff, uv, pipx", "Languages"},
	{"--node", "Node.js", "fnm, pnpm (corepack), typescript, eslint", "Languages"},
	{"--dotnet", ".NET SDK", "C# / F# development via dotnet-install", "Languages"},
	// Cloud & Infra (9-10)
	{"--cloud", "Cloud CLIs & DB", "Azure, AWS, Cloudflare, mssql-tools", "Cloud & Infrastructure"},
	{"--docker", "Docker", "engine, compose, NVIDIA container toolkit", "Cloud & Infrastructure"},
	// ML & Compute (11-12)
	{"--ml", "ML / Point Cloud", "PyTorch, transformers, Open3D, laspy, finetuning", "ML & Compute"},
	{"--cuda", "CUDA Toolkit", "CUDA, cuDNN, TensorRT (requires NVIDIA GPU)", "ML & Compute"},
}

// ─── Screens ──────────────────────────────────────────────────────

type screen int

const (
	screenProfile screen = iota
	screenModules
	screenConfirm
)

// ─── Model ────────────────────────────────────────────────────────

type model struct {
	screen     screen
	cursor     int
	profileIdx int
	selections []bool
	confirmed  bool
	cores      int
	gpu        string
	width      int
	height     int
}

func initialModel() model {
	cores := runtime.NumCPU()
	gpu := detectGPU()

	profileIdx := 0
	if cores >= 64 {
		profileIdx = 1
	}

	selections := make([]bool, len(modules))
	for i := range selections {
		selections[i] = true
	}

	// Apply profile defaults
	for _, idx := range profiles[profileIdx].deselect {
		if idx < len(selections) {
			selections[idx] = false
		}
	}

	return model{
		screen:     screenProfile,
		cursor:     profileIdx,
		profileIdx: profileIdx,
		selections: selections,
		cores:      cores,
		gpu:        gpu,
	}
}

func detectGPU() string {
	out, err := exec.Command("nvidia-smi", "--query-gpu=name", "--format=csv,noheader").Output()
	if err == nil {
		if name := strings.TrimSpace(string(out)); name != "" {
			return name
		}
	}
	out, _ = exec.Command("bash", "-c", "lspci 2>/dev/null | grep -i nvidia | head -1 | sed 's/.*: //'").Output()
	if name := strings.TrimSpace(string(out)); name != "" {
		return name
	}
	return ""
}

// ─── Init ─────────────────────────────────────────────────────────

func (m model) Init() tea.Cmd { return nil }

// ─── Update ───────────────────────────────────────────────────────

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		return m, nil
	case tea.KeyMsg:
		if msg.String() == "ctrl+c" {
			return m, tea.Quit
		}
		switch m.screen {
		case screenProfile:
			return m.updateProfile(msg)
		case screenModules:
			return m.updateModules(msg)
		case screenConfirm:
			return m.updateConfirm(msg)
		}
	}
	return m, nil
}

func (m model) updateProfile(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "up", "k":
		if m.cursor > 0 {
			m.cursor--
		}
	case "down", "j":
		if m.cursor < len(profiles)-1 {
			m.cursor++
		}
	case "enter":
		m.profileIdx = m.cursor
		// Re-apply profile defaults
		for i := range m.selections {
			m.selections[i] = true
		}
		for _, idx := range profiles[m.profileIdx].deselect {
			if idx < len(m.selections) {
				m.selections[idx] = false
			}
		}
		m.screen = screenModules
		m.cursor = 0
	case "q":
		return m, tea.Quit
	}
	return m, nil
}

func (m model) updateModules(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "up", "k":
		if m.cursor > 0 {
			m.cursor--
		}
	case "down", "j":
		if m.cursor < len(modules)-1 {
			m.cursor++
		}
	case " ", "x":
		m.selections[m.cursor] = !m.selections[m.cursor]
	case "a":
		allOn := true
		for _, s := range m.selections {
			if !s {
				allOn = false
				break
			}
		}
		for i := range m.selections {
			m.selections[i] = !allOn
		}
	case "enter":
		m.screen = screenConfirm
		m.cursor = 0
	case "esc":
		m.screen = screenProfile
		m.cursor = m.profileIdx
	case "q":
		return m, tea.Quit
	}
	return m, nil
}

func (m model) updateConfirm(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "y", "Y", "enter":
		m.confirmed = true
		return m, tea.Quit
	case "n", "N", "esc":
		m.screen = screenModules
		m.cursor = 0
	case "q":
		return m, tea.Quit
	}
	return m, nil
}

// ─── Views ────────────────────────────────────────────────────────

func (m model) View() string {
	var s strings.Builder
	s.WriteString(m.renderHeader())

	switch m.screen {
	case screenProfile:
		s.WriteString(m.viewProfile())
	case screenModules:
		s.WriteString(m.viewModules())
	case screenConfirm:
		s.WriteString(m.viewConfirm())
	}
	return s.String()
}

func (m model) renderHeader() string {
	banner := headerStyle.Render("  cubevision-dotfiles  ") + "\n"
	det := subtitleStyle.Render(fmt.Sprintf("Detected: %d cores", m.cores))
	if m.gpu != "" {
		det += dimStyle.Render("  ·  ") + dimStyle.Render(m.gpu)
	} else {
		det += dimStyle.Render("  ·  ") + warnStyle.Render("no NVIDIA GPU")
	}
	return banner + det + "\n"
}

func (m model) viewProfile() string {
	var s strings.Builder
	s.WriteString("\n")
	s.WriteString(titleStyle.Render("Select Machine Profile"))
	s.WriteString("\n\n")

	for i, p := range profiles {
		cursor := "  "
		nameStyle := dimStyle
		if i == m.cursor {
			cursor = cursorStyle.Render("▸ ")
			nameStyle = selectedStyle
		}
		s.WriteString(fmt.Sprintf("  %s%s\n", cursor, nameStyle.Render(p.name)))
		s.WriteString(fmt.Sprintf("      %s\n", dimStyle.Render(p.desc)))
	}

	s.WriteString("\n")
	s.WriteString(helpStyle.Render("j/k navigate  •  enter select  •  q quit"))
	s.WriteString("\n")
	return s.String()
}

func (m model) viewModules() string {
	var s strings.Builder
	s.WriteString("\n")
	s.WriteString(titleStyle.Render("Select Modules"))
	s.WriteString("  ")
	s.WriteString(dimStyle.Render(fmt.Sprintf("(%s)", profiles[m.profileIdx].name)))
	s.WriteString("\n")

	lastCat := ""
	for i, mod := range modules {
		if mod.category != lastCat {
			s.WriteString(categoryStyle.Render("■ " + mod.category))
			s.WriteString("\n")
			lastCat = mod.category
		}

		cursor := "  "
		if i == m.cursor {
			cursor = cursorStyle.Render("▸ ")
		}

		check := dimStyle.Render("○")
		if m.selections[i] {
			check = checkStyle.Render("●")
		}

		name := dimStyle.Render(mod.name)
		if i == m.cursor {
			name = lipgloss.NewStyle().Foreground(nord4).Bold(true).Render(mod.name)
		}

		desc := dimStyle.Render(" — " + mod.desc)
		s.WriteString(fmt.Sprintf("  %s%s %s%s\n", cursor, check, name, desc))
	}

	n := m.countSelected()
	s.WriteString("\n")
	s.WriteString(subtitleStyle.Render(fmt.Sprintf("%d/%d modules selected", n, len(modules))))
	s.WriteString("\n\n")
	s.WriteString(helpStyle.Render("j/k navigate  •  space toggle  •  a all/none  •  enter confirm  •  esc back"))
	s.WriteString("\n")
	return s.String()
}

func (m model) viewConfirm() string {
	var s strings.Builder
	s.WriteString("\n")
	s.WriteString(titleStyle.Render("Review & Install"))
	s.WriteString("\n\n")

	s.WriteString(descStyle.Render(fmt.Sprintf("Profile   %s", profiles[m.profileIdx].name)))
	s.WriteString("\n")
	s.WriteString(descStyle.Render(fmt.Sprintf("Modules   %d selected", m.countSelected())))
	s.WriteString("\n\n")

	lastCat := ""
	for i, mod := range modules {
		if !m.selections[i] {
			continue
		}
		if mod.category != lastCat {
			s.WriteString(categoryStyle.Render(mod.category))
			s.WriteString("\n")
			lastCat = mod.category
		}
		s.WriteString(fmt.Sprintf("    %s %s\n",
			checkStyle.Render("✓"),
			lipgloss.NewStyle().Foreground(nord4).Render(mod.name)))
	}

	s.WriteString("\n")

	// Show skipped
	skipped := []string{}
	for i, mod := range modules {
		if !m.selections[i] {
			skipped = append(skipped, mod.name)
		}
	}
	if len(skipped) > 0 {
		s.WriteString(warnStyle.Render("Skipping: " + strings.Join(skipped, ", ")))
		s.WriteString("\n\n")
	}

	s.WriteString(lipgloss.NewStyle().Foreground(nord10).Bold(true).PaddingLeft(2).
		Render("Proceed with installation?"))
	s.WriteString("\n\n")
	s.WriteString(helpStyle.Render("y/enter install  •  n/esc go back  •  q quit"))
	s.WriteString("\n")
	return s.String()
}

// ─── Helpers ──────────────────────────────────────────────────────

func (m model) countSelected() int {
	n := 0
	for _, s := range m.selections {
		if s {
			n++
		}
	}
	return n
}

func findDotfiles() string {
	// Relative to binary / cwd
	for _, base := range []string{
		filepath.Dir(os.Args[0]),
		func() string { d, _ := os.Getwd(); return d }(),
	} {
		for _, rel := range []string{".", ".."} {
			candidate := filepath.Join(base, rel)
			if _, err := os.Stat(filepath.Join(candidate, "wsl", "install.sh")); err == nil {
				abs, _ := filepath.Abs(candidate)
				return abs
			}
		}
	}
	// fallback: env
	if d := os.Getenv("DOTFILES"); d != "" {
		return d
	}
	d, _ := os.Getwd()
	return d
}

// ─── Main ─────────────────────────────────────────────────────────

func main() {
	p := tea.NewProgram(initialModel(), tea.WithAltScreen())
	result, err := p.Run()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error running TUI: %v\n", err)
		os.Exit(1)
	}

	final := result.(model)
	if !final.confirmed {
		fmt.Println("\n  Installation cancelled.")
		return
	}

	// Gather selected flags
	var flags []string
	for i, mod := range modules {
		if final.selections[i] {
			flags = append(flags, mod.flag)
		}
	}
	if len(flags) == 0 {
		fmt.Println("\n  No modules selected.")
		return
	}

	// Locate install.sh
	dotfiles := findDotfiles()
	script := filepath.Join(dotfiles, "wsl", "install.sh")
	if _, err := os.Stat(script); os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "%s install.sh not found at %s\n",
			errStyle.Render("✗"), script)
		os.Exit(1)
	}

	// Print summary line
	fmt.Printf("\n%s %s  ⟶  bash install.sh %s\n\n",
		okStyle.Render("━━━"),
		profiles[final.profileIdx].name,
		strings.Join(flags, " "))

	// Execute install.sh with full terminal I/O
	cmd := exec.Command("bash", append([]string{script}, flags...)...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Env = append(os.Environ(),
		"DOTFILES="+dotfiles,
		"MACHINE_PROFILE="+profiles[final.profileIdx].flag,
	)

	if err := cmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "\n%s Installation finished with errors: %v\n",
			errStyle.Render("✗"), err)
		os.Exit(1)
	}

	fmt.Printf("\n%s Done! Restart your shell or run: exec zsh\n",
		okStyle.Render("✓"))
}
