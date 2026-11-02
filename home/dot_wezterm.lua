local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

config.front_end = "WebGpu"  -- uses Metal on macOS
wezterm.font = "JetBrainsMono Nerd Font Mono"
config.hide_tab_bar_if_only_one_tab = true

config.mux_enable_ssh_agent = false

-- Nord (https://www.nordtheme.com/docs/colors-and-palettes) with every text
-- color at 4.5:1 or better against the background. ANSI black stays near the
-- background in both schemes.
config.color_schemes = {
	["Nord"] = {
		background = "#2E3440", -- nord0
		foreground = "#D8DEE9", -- nord4
		cursor_bg = "#D8DEE9",
		cursor_fg = "#2E3440",
		cursor_border = "#D8DEE9",
		selection_bg = "#434C5E", -- nord2
		selection_fg = "#ECEFF4",
		ansi = {
			"#3B4252", -- nord1
			"#E0848C", -- nord11, lightened from 3.05:1
			"#A3BE8C", -- nord14
			"#EBCB8B", -- nord13
			"#81A1C1", -- nord9
			"#B691AF", -- nord15, lightened from 4.41:1
			"#88C0D0", -- nord8
			"#E5E9F0", -- nord5
		},
		brights = {
			"#8490A7", -- nord3 lightened from 1.69:1: 3.9:1 as text, 2.8:1 under color 15
			"#E0848C",
			"#A3BE8C",
			"#EBCB8B",
			"#81A1C1",
			"#B691AF",
			"#8FBCBB", -- nord7
			"#ECEFF4", -- nord6
		},
	},
	["Nord Light"] = {
		background = "#ECEFF4", -- nord6
		foreground = "#2E3440", -- nord0
		cursor_bg = "#2E3440",
		cursor_fg = "#ECEFF4",
		cursor_border = "#2E3440",
		selection_bg = "#D8DEE9", -- nord4
		selection_fg = "#2E3440",
		-- Nord accents are made for dark backgrounds: each one is darkened,
		-- same hue, to 4.5:1 on nord6.
		-- Black and white are swapped (as Tokyo Night Day does): most TUIs
		-- assume a dark background and use white for text and black for
		-- panels and selections.
		ansi = {
			"#D8DEE9", -- nord4
			"#B54954", -- nord11
			"#597442", -- nord14
			"#8D6618", -- nord13
			"#496F95", -- nord9
			"#8C5D83", -- nord15
			"#357587", -- nord8
			"#4C566A", -- nord3
		},
		brights = {
			"#687591", -- nord3 hue: 4.0:1 as text, 2.7:1 under color 15
			"#B54954",
			"#597442",
			"#8D6618",
			"#496F95",
			"#8C5D83",
			"#457473", -- nord7
			"#2E3440", -- nord0
		},
	},
}

local function get_appearance()
	-- wezterm.gui is not available to the mux server, so take care to
	-- do something reasonable when this config is evaluated by the mux
	if wezterm.gui then
		return wezterm.gui.get_appearance()
	end
	return "Dark"
end

local function color_scheme()
	local appearance = get_appearance()
	if appearance:find("Dark") then
		-- return "Catppuccin Mocha"
		-- return "Tokyo Night Moon"
		return "Nord"
	else
		-- return "Catppuccin Latte"
		-- return "Tokyo Night Day"
		return "Nord Light"
	end
end

config.color_scheme = color_scheme()
config.status_update_interval = 750
config.window_padding = {
	left = "0cell",
	right = "0cell",
	top = "0.25cell",
	bottom = "0cell",
}

config.scrollback_lines = 10000
config.audible_bell = "Disabled"

-- don't include tmux pane borders in mouse selection (│)
-- don't include normal pipe (|), colon (:), comma (,)
config.selection_word_boundary = " \t\n{}[]()\"'`|│:,="

config.mouse_bindings = {
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'NONE',
    action = act.CompleteSelection("ClipboardAndPrimarySelection")
  },
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'CMD',
    action = act.OpenLinkAtMouseCursor,
  },
}

-- Actions docs: https://wezfurlong.org/wezterm/config/lua/keyassignment/index.html
-- local pane_resize = 5
-- config.leader = { key = "a", mods = "CTRL" }
config.keys = {
	-- Send CSI u encoded Shift+Enter for Claude Code multiline input
	{ key = "Enter", mods = "SHIFT", action = act.SendString("\x1b[13;2u") },

	-- font resizing
	{ key = "+", mods = "CMD", action = act.IncreaseFontSize },
	{ key = "-", mods = "CMD", action = act.DecreaseFontSize },
	{ key = "0", mods = "CMD", action = act.ResetFontSize },

	-- -- tmux like bindings
	-- { key = "a", mods = "LEADER|CTRL", action = act.ActivateLastTab },
	-- { key = "Escape", mods = "LEADER", action = act.ActivateCopyMode },
	-- {
	-- 	key = "c",
	-- 	mods = "LEADER",
	-- 	action = act.SpawnCommandInNewTab({ domain = "CurrentPaneDomain", cwd = wezterm.home_dir }),
	-- },
	-- { key = "z", mods = "LEADER", action = act.TogglePaneZoomState },
	-- { key = "p", mods = "LEADER", action = act.ActivateCommandPalette },
	-- { key = "/", mods = "LEADER", action = act.Search("CurrentSelectionOrEmptyString") },
	-- { key = ".", mods = "LEADER", action = act.QuickSelect },
	-- -- { key = 'd',      mods = 'LEADER', action = act.ShowDebugOverlay },
	-- --
	-- -- search for things that look like git hashes
	-- -- { key = 'H',      mods = 'SHIFT|CTRL', action = wezterm.action.Search { Regex = '[a-f0-9]{6,}' } },
	--
	-- -- Navigation - Panes
	-- { key = "h", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
	-- { key = "j", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
	-- { key = "k", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
	-- { key = "l", mods = "LEADER", action = act.ActivatePaneDirection("Right") },
	--
	-- -- Navigation - Tabs
	-- { key = "h", mods = "LEADER|CTRL", action = act.ActivateTabRelativeNoWrap(-1) },
	-- { key = "l", mods = "LEADER|CTRL", action = act.ActivateTabRelativeNoWrap(1) },
	--
	-- -- Resizing Panes
	-- {
	-- 	key = "h",
	-- 	mods = "LEADER|SHIFT",
	-- 	action = act.Multiple({
	-- 		act.AdjustPaneSize({ "Left", pane_resize }),
	-- 		act.ActivateKeyTable({ name = "resize_pane", one_shot = false, until_unknown = true }),
	-- 	}),
	-- },
	-- {
	-- 	key = "j",
	-- 	mods = "LEADER|SHIFT",
	-- 	action = act.Multiple({
	-- 		act.AdjustPaneSize({ "Down", pane_resize }),
	-- 		act.ActivateKeyTable({ name = "resize_pane", one_shot = false, until_unknown = true }),
	-- 	}),
	-- },
	-- {
	-- 	key = "k",
	-- 	mods = "LEADER|SHIFT",
	-- 	action = act.Multiple({
	-- 		act.AdjustPaneSize({ "Up", pane_resize }),
	-- 		act.ActivateKeyTable({ name = "resize_pane", one_shot = false, until_unknown = true }),
	-- 	}),
	-- },
	-- {
	-- 	key = "l",
	-- 	mods = "LEADER|SHIFT",
	-- 	action = act.Multiple({
	-- 		act.AdjustPaneSize({ "Right", pane_resize }),
	-- 		act.ActivateKeyTable({ name = "resize_pane", one_shot = false, until_unknown = true }),
	-- 	}),
	-- },
	--
	-- -- Splitting Panes
	-- { key = "|", mods = "LEADER|SHIFT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	-- { key = "-", mods = "LEADER", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
	--
	-- -- Swapping/Moving Tabs (_NOT_ selecting them)
	-- { key = "<", mods = "LEADER|SHIFT", action = act.MoveTabRelative(-1) },
	-- { key = ">", mods = "LEADER|SHIFT", action = act.MoveTabRelative(1) },
}

-- config.key_tables = {
-- 	resize_pane = {
-- 		{ key = "h", mods = "SHIFT", action = act.AdjustPaneSize({ "Left", pane_resize }) },
-- 		{ key = "j", mods = "SHIFT", action = act.AdjustPaneSize({ "Down", pane_resize }) },
-- 		{ key = "k", mods = "SHIFT", action = act.AdjustPaneSize({ "Up", pane_resize }) },
-- 		{ key = "l", mods = "SHIFT", action = act.AdjustPaneSize({ "Right", pane_resize }) },
-- 		{ key = "Escape", action = act.PopKeyTable },
-- 	},
-- }

-- tmux'ish/nvim'ish status lines
-- local tabline = wezterm.plugin.require("https://github.com/michaelbrusegard/tabline.wez")
-- tabline.setup({
-- 	options = {
-- 		theme = color_scheme(),
-- 	},
-- 	sections = {
-- 		tabline_a = { "mode" },
-- 		tabline_b = { "workspace" },
-- 		tabline_c = { " " },
-- 		tab_active = {
-- 			"index",
-- 			{ "parent", padding = 0 },
-- 			"/",
-- 			{ "cwd", padding = { left = 0, right = 1 } },
-- 			{ "process", padding = { left = 0, right = 1 } },
-- 			{ "zoomed", padding = 1 },
-- 		},
-- 		tab_inactive = {
-- 			"index",
-- 			{ "parent", padding = 0 },
-- 			"/",
-- 			{ "cwd", padding = { left = 0, right = 1 } },
-- 			{ "process", padding = { left = 0, right = 1 } },
-- 		},
-- 		tabline_x = {},
-- 		tabline_y = {},
-- 		tabline_z = { { "datetime", style = "%Y/%m/%d %H:%M" } },
-- 	},
-- })
-- tabline.apply_to_config(config)

-- WezTerm does not send the DEC 2031 light/dark report (?997), so herdr keeps
-- answering OSC 11 with the old background after an appearance change. Send
-- herdr the report it waits for. herdr then queries the colors again.
-- shortcut: remove when wezterm#6454 ships DEC 2031 support.
wezterm.on("window-config-reloaded", function(window, _)
	local appearance = window:get_appearance()
	local id = tostring(window:window_id())
	wezterm.GLOBAL.last_appearance = wezterm.GLOBAL.last_appearance or {}
	local last = wezterm.GLOBAL.last_appearance[id]
	wezterm.GLOBAL.last_appearance[id] = appearance
	if last == appearance then
		return
	end
	local report = appearance:find("Dark") and "\x1b[?997;1n" or "\x1b[?997;2n"
	for _, tab in ipairs(window:mux_window():tabs()) do
		for _, pane in ipairs(tab:panes()) do
			local name = pane:get_foreground_process_name() or ""
			if name:match("herdr$") then
				window:perform_action(act.SendString(report), pane)
			end
		end
	end
end)

return config
