-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  WezTerm Configuration — Nordic Night                                ║
-- ║  Color palette: Nord on #121212 (codeberg.org/ashton314/nordic-night)║
-- ╚══════════════════════════════════════════════════════════════════════╝

local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

-- ─── Nordic Night Color Palette ─────────────────────────────────────
local n = {
	bg     = "#121212",
	bg_alt = "#1a1a2e",
	nord0  = "#2E3440", nord1  = "#3B4252", nord2  = "#434C5E", nord3  = "#4C566A",
	nord4  = "#D8DEE9", nord5  = "#E5E9F0", nord6  = "#ECEFF4",
	nord7  = "#8FBCBB", nord8  = "#88C0D0", nord9  = "#81A1C1", nord10 = "#5E81AC",
	nord11 = "#BF616A", nord12 = "#D08770", nord13 = "#EBCB8B",
	nord14 = "#A3BE8C", nord15 = "#B48EAD",
}

-- ─── Colors ─────────────────────────────────────────────────────────
config.colors = {
	foreground = n.nord4,
	background = n.bg,
	cursor_bg = n.nord8,
	cursor_fg = n.bg,
	cursor_border = n.nord8,
	selection_bg = n.nord2,
	selection_fg = n.nord6,
	scrollbar_thumb = n.nord1,
	split = n.nord1,
	compose_cursor = n.nord12,

	ansi    = { n.nord1, n.nord11, n.nord14, n.nord13, n.nord9, n.nord15, n.nord8, n.nord5 },
	brights = { n.nord3, n.nord11, n.nord14, n.nord13, n.nord9, n.nord15, n.nord7, n.nord6 },

	tab_bar = {
		background = n.bg,
		active_tab      = { bg_color = n.nord1, fg_color = n.nord8,  intensity = "Bold" },
		inactive_tab    = { bg_color = n.bg,    fg_color = n.nord3 },
		inactive_tab_hover = { bg_color = n.nord0, fg_color = n.nord4 },
		new_tab         = { bg_color = n.bg,    fg_color = n.nord3 },
		new_tab_hover   = { bg_color = n.nord0, fg_color = n.nord8 },
	},
}

-- ─── Font ───────────────────────────────────────────────────────────
config.font = wezterm.font_with_fallback({
	{ family = "GeistMono Nerd Font",    weight = "Regular" },
	{ family = "SauceCodePro Nerd Font", weight = "Regular" },
	{ family = "Hack Nerd Font",         weight = "Regular" },
})
config.font_size = 12.0
config.line_height = 1.0
config.cell_width = 1.0

-- ─── Window ─────────────────────────────────────────────────────────
config.window_padding = { left = 12, right = 12, top = 8, bottom = 8 }
config.window_background_opacity = 0.95
config.window_decorations = "RESIZE"
config.window_close_confirmation = "NeverPrompt"
config.initial_cols = 160
config.initial_rows = 45
config.enable_scroll_bar = false
config.adjust_window_size_when_changing_font_size = false

-- ─── Tab bar ────────────────────────────────────────────────────────
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.hide_tab_bar_if_only_one_tab = false
config.tab_max_width = 36
config.show_tab_index_in_tab_bar = true

-- ─── Cursor ─────────────────────────────────────────────────────────
config.default_cursor_style = "BlinkingBlock"
config.cursor_blink_rate = 600
config.cursor_blink_ease_in = "Constant"
config.cursor_blink_ease_out = "Constant"

-- ─── Scrollback ─────────────────────────────────────────────────────
config.scrollback_lines = 50000

-- ─── Hyperlinks ─────────────────────────────────────────────────────
config.hyperlink_rules = wezterm.default_hyperlink_rules()
-- make file paths clickable
table.insert(config.hyperlink_rules, {
	regex = [[[^\s]*?/[^\s]+\.\w+(?::\d+)?]],
	format = "$0",
})

-- ─── WSL2 as default domain ─────────────────────────────────────────
config.default_domain = "WSL:Ubuntu"

-- ─── Launch menu ────────────────────────────────────────────────────
config.launch_menu = {
	-- Shells
	{ label = " WSL Ubuntu",        args = { "wsl.exe", "--distribution", "Ubuntu" } },
	{ label = " PowerShell",        args = { "pwsh.exe", "-NoLogo" } },
	{ label = " CMD",               args = { "cmd.exe" } },
	-- Dev tools (Windows host)
	{ label = " Neovim",            args = { "nvim.exe" } },
	{ label = " LazyGit",           args = { "lazygit.exe" } },
	{ label = " LazyDocker",        args = { "lazydocker.exe" } },
	{ label = "󱃾 k9s (Kubernetes)",  args = { "k9s.exe" } },
	{ label = "󰧑 Ollama (run)",      args = { "ollama.exe", "run", "llama3.2" } },
	{ label = " Fastfetch",         args = { "cmd.exe", "/c", "fastfetch && pause" } },
	-- WSL dev tools
	{ label = " WSL: Neovim",       args = { "wsl.exe", "--", "nvim" } },
	{ label = " WSL: LazyGit",      args = { "wsl.exe", "--", "lazygit" } },
	{ label = " WSL: htop",         args = { "wsl.exe", "--", "htop" } },
	-- Databases
	{ label = " PostgreSQL (psql)", args = { "psql.exe", "-U", "postgres" } },
	{ label = " SQLite",            args = { "sqlite3.exe" } },
}

-- ─── Keys ───────────────────────────────────────────────────────────
config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 1500 }

config.keys = {
	-- Clipboard
	{ key = "v", mods = "CTRL|SHIFT", action = act.PasteFrom("Clipboard") },
	{ key = "c", mods = "CTRL|SHIFT", action = act.CopyTo("Clipboard") },

	-- Font size
	{ key = "+", mods = "CTRL", action = act.IncreaseFontSize },
	{ key = "-", mods = "CTRL", action = act.DecreaseFontSize },
	{ key = "0", mods = "CTRL", action = act.ResetFontSize },

	-- Pane splitting (leader-based, tmux-like)
	{ key = "\\", mods = "LEADER",     action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = "-",  mods = "LEADER",     action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
	{ key = "z",  mods = "LEADER",     action = act.TogglePaneZoomState },
	{ key = "x",  mods = "LEADER",     action = act.CloseCurrentPane({ confirm = true }) },

	-- Pane navigation (vim-style)
	{ key = "h", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Left") },
	{ key = "j", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Down") },
	{ key = "k", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Up") },
	{ key = "l", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Right") },

	-- Pane resize
	{ key = "H", mods = "CTRL|SHIFT|ALT", action = act.AdjustPaneSize({ "Left", 5 }) },
	{ key = "J", mods = "CTRL|SHIFT|ALT", action = act.AdjustPaneSize({ "Down", 5 }) },
	{ key = "K", mods = "CTRL|SHIFT|ALT", action = act.AdjustPaneSize({ "Up", 5 }) },
	{ key = "L", mods = "CTRL|SHIFT|ALT", action = act.AdjustPaneSize({ "Right", 5 }) },

	-- Tab management
	{ key = "t", mods = "CTRL|SHIFT",   action = act.SpawnTab("CurrentPaneDomain") },
	{ key = "w", mods = "CTRL|SHIFT",   action = act.CloseCurrentTab({ confirm = false }) },
	{ key = "Tab", mods = "CTRL",        action = act.ActivateTabRelative(1) },
	{ key = "Tab", mods = "CTRL|SHIFT",  action = act.ActivateTabRelative(-1) },

	-- Direct tab access (Alt+1..9)
	{ key = "1", mods = "ALT", action = act.ActivateTab(0) },
	{ key = "2", mods = "ALT", action = act.ActivateTab(1) },
	{ key = "3", mods = "ALT", action = act.ActivateTab(2) },
	{ key = "4", mods = "ALT", action = act.ActivateTab(3) },
	{ key = "5", mods = "ALT", action = act.ActivateTab(4) },
	{ key = "6", mods = "ALT", action = act.ActivateTab(5) },
	{ key = "7", mods = "ALT", action = act.ActivateTab(6) },
	{ key = "8", mods = "ALT", action = act.ActivateTab(7) },
	{ key = "9", mods = "ALT", action = act.ActivateTab(-1) },

	-- Workspaces
	{ key = "s", mods = "LEADER", action = act.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES" }) },
	{ key = "f", mods = "LEADER", action = act.ShowLauncherArgs({ flags = "FUZZY|LAUNCH_MENU_ITEMS" }) },

	-- Quick-launch (leader + key → spawn tool in new tab)
	{ key = "g", mods = "LEADER", action = act.SpawnCommandInNewTab({
		args = { "lazygit.exe" }, set_environment_variables = { TERM = "xterm-256color" },
	})},
	{ key = "d", mods = "LEADER", action = act.SpawnCommandInNewTab({
		args = { "lazydocker.exe" }, set_environment_variables = { TERM = "xterm-256color" },
	})},
	{ key = "n", mods = "LEADER", action = act.SpawnCommandInNewTab({
		args = { "nvim.exe" }, set_environment_variables = { TERM = "xterm-256color" },
	})},

	-- Search / scrollback
	{ key = "/", mods = "CTRL|SHIFT", action = act.Search("CurrentSelectionOrEmptyString") },

	-- Command palette
	{ key = "p", mods = "CTRL|SHIFT", action = act.ActivateCommandPalette },

	-- Open URL under cursor
	{ key = "u", mods = "CTRL|SHIFT", action = act.QuickSelectArgs({
		label = "open url",
		patterns = { "https?://\\S+" },
		action = wezterm.action_callback(function(window, pane)
			local url = window:get_selection_text_for_pane(pane)
			wezterm.open_with(url)
		end),
	})},
}

-- ─── Mouse bindings ─────────────────────────────────────────────────
config.mouse_bindings = {
	-- Ctrl+Click opens hyperlinks
	{
		event = { Up = { streak = 1, button = "Left" } },
		mods = "CTRL",
		action = act.OpenLinkAtMouseCursor,
	},
	-- Right-click paste
	{
		event = { Down = { streak = 1, button = "Right" } },
		mods = "NONE",
		action = act.PasteFrom("Clipboard"),
	},
}

-- ─── Right status bar (hostname · cwd · time) ──────────────────────
wezterm.on("update-right-status", function(window, pane)
	local cwd_uri = pane:get_current_working_dir()
	local cwd = ""
	if cwd_uri then
		cwd = cwd_uri.file_path or ""
		-- shorten home directory
		local home = os.getenv("USERPROFILE") or os.getenv("HOME") or ""
		if home ~= "" then
			cwd = cwd:gsub("^" .. wezterm.glob_escape(home), "~")
		end
		-- keep only last 3 path components
		local parts = {}
		for part in cwd:gmatch("[^/\\]+") do table.insert(parts, part) end
		if #parts > 3 then
			cwd = ".../" .. table.concat({ parts[#parts - 2], parts[#parts - 1], parts[#parts] }, "/")
		end
	end

	local time = wezterm.strftime("%H:%M")
	local hostname = wezterm.hostname()

	local status = wezterm.format({
		{ Foreground = { Color = n.nord3 } },  { Text = " " .. cwd .. "  " },
		{ Foreground = { Color = n.nord10 } }, { Text = hostname .. "  " },
		{ Foreground = { Color = n.nord8 } },  { Text = time .. "  " },
	})
	window:set_right_status(status)
end)

-- ─── Tab title formatting ───────────────────────────────────────────
wezterm.on("format-tab-title", function(tab, _tabs, _panes, _config, _hover, _max_width)
	local pane = tab.active_pane
	local title = pane.title
	-- strip full path, keep just the process name
	if title then
		title = title:gsub("^.*[/\\]", "")
	end
	local idx = tab.tab_index + 1
	local icon = tab.is_active and "" or ""
	return string.format(" %s %d:%s ", icon, idx, title or "shell")
end)

-- ─── GPU ────────────────────────────────────────────────────────────
config.front_end = "WebGpu"
config.webgpu_power_preference = "HighPerformance"

-- ─── Misc ───────────────────────────────────────────────────────────
config.check_for_updates = false
config.audible_bell = "Disabled"
config.visual_bell = {
	fade_in_duration_ms = 75,
	fade_out_duration_ms = 75,
	target = "CursorColor",
}
config.exit_behavior = "CloseOnCleanExit"
config.clean_exit_codes = { 130 }
config.notification_handling = "AlwaysShow"

return config
