local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

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
		return "Tokyo Night Moon"
	else
		-- return "Catppuccin Latte"
		return "Tokyo Night Day"
	end
end

config.color_scheme = color_scheme()
config.status_update_interval = 750
config.window_padding = {
	left = "1cell",
	right = "1cell",
	top = "0.5cell",
	bottom = "0",
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
    action = act.DisableDefaultAssignment,
  },
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'CMD',
    action = act.OpenLinkAtMouseCursor,
  },
}

-- Actions docs: https://wezfurlong.org/wezterm/config/lua/keyassignment/index.html
local pane_resize = 5
config.leader = { key = "a", mods = "CTRL" }
config.keys = {
	-- font resizing
	{ key = "+", mods = "CMD", action = act.IncreaseFontSize },
	{ key = "-", mods = "CMD", action = act.DecreaseFontSize },
	{ key = "0", mods = "CMD", action = act.ResetFontSize },

	-- tmux like bindings
	{ key = "a", mods = "LEADER|CTRL", action = act.ActivateLastTab },
	{ key = "Escape", mods = "LEADER", action = act.ActivateCopyMode },
	{
		key = "c",
		mods = "LEADER",
		action = act.SpawnCommandInNewTab({ domain = "CurrentPaneDomain", cwd = wezterm.home_dir }),
	},
	{ key = "z", mods = "LEADER", action = act.TogglePaneZoomState },
	{ key = "p", mods = "LEADER", action = act.ActivateCommandPalette },
	{ key = "/", mods = "LEADER", action = act.Search("CurrentSelectionOrEmptyString") },
	{ key = ".", mods = "LEADER", action = act.QuickSelect },
	-- { key = 'd',      mods = 'LEADER', action = act.ShowDebugOverlay },
	--
	-- search for things that look like git hashes
	-- { key = 'H',      mods = 'SHIFT|CTRL', action = wezterm.action.Search { Regex = '[a-f0-9]{6,}' } },

	-- Navigation - Panes
	{ key = "h", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
	{ key = "j", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
	{ key = "k", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
	{ key = "l", mods = "LEADER", action = act.ActivatePaneDirection("Right") },

	-- Navigation - Tabs
	{ key = "h", mods = "LEADER|CTRL", action = act.ActivateTabRelativeNoWrap(-1) },
	{ key = "l", mods = "LEADER|CTRL", action = act.ActivateTabRelativeNoWrap(1) },

	-- Resizing Panes
	{
		key = "h",
		mods = "LEADER|SHIFT",
		action = act.Multiple({
			act.AdjustPaneSize({ "Left", pane_resize }),
			act.ActivateKeyTable({ name = "resize_pane", one_shot = false, until_unknown = true }),
		}),
	},
	{
		key = "j",
		mods = "LEADER|SHIFT",
		action = act.Multiple({
			act.AdjustPaneSize({ "Down", pane_resize }),
			act.ActivateKeyTable({ name = "resize_pane", one_shot = false, until_unknown = true }),
		}),
	},
	{
		key = "k",
		mods = "LEADER|SHIFT",
		action = act.Multiple({
			act.AdjustPaneSize({ "Up", pane_resize }),
			act.ActivateKeyTable({ name = "resize_pane", one_shot = false, until_unknown = true }),
		}),
	},
	{
		key = "l",
		mods = "LEADER|SHIFT",
		action = act.Multiple({
			act.AdjustPaneSize({ "Right", pane_resize }),
			act.ActivateKeyTable({ name = "resize_pane", one_shot = false, until_unknown = true }),
		}),
	},

	-- Splitting Panes
	{ key = "|", mods = "LEADER|SHIFT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = "-", mods = "LEADER", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },

	-- Swapping/Moving Tabs (_NOT_ selecting them)
	{ key = "<", mods = "LEADER|SHIFT", action = act.MoveTabRelative(-1) },
	{ key = ">", mods = "LEADER|SHIFT", action = act.MoveTabRelative(1) },
}

config.key_tables = {
	resize_pane = {
		{ key = "h", mods = "SHIFT", action = act.AdjustPaneSize({ "Left", pane_resize }) },
		{ key = "j", mods = "SHIFT", action = act.AdjustPaneSize({ "Down", pane_resize }) },
		{ key = "k", mods = "SHIFT", action = act.AdjustPaneSize({ "Up", pane_resize }) },
		{ key = "l", mods = "SHIFT", action = act.AdjustPaneSize({ "Right", pane_resize }) },
		{ key = "Escape", action = act.PopKeyTable },
	},
}

-- tmux'ish/nvim'ish status lines
local tabline = wezterm.plugin.require("https://github.com/michaelbrusegard/tabline.wez")
tabline.setup({
	options = {
		theme = color_scheme(),
	},
	sections = {
		tabline_a = { "mode" },
		tabline_b = { "workspace" },
		tabline_c = { " " },
		tab_active = {
			"index",
			{ "parent", padding = 0 },
			"/",
			{ "cwd", padding = { left = 0, right = 1 } },
			{ "process", padding = { left = 0, right = 1 } },
			{ "zoomed", padding = 1 },
		},
		tab_inactive = {
			"index",
			{ "parent", padding = 0 },
			"/",
			{ "cwd", padding = { left = 0, right = 1 } },
			{ "process", padding = { left = 0, right = 1 } },
		},
		tabline_x = {},
		tabline_y = {},
		tabline_z = { { "datetime", style = "%Y/%m/%d %H:%M" } },
	},
})
tabline.apply_to_config(config)

return config
