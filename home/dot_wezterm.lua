local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

local theme = "Catppuccin Mocha"

config.color_scheme = theme
config.status_update_interval = 750
config.window_padding = {
	left = "1cell",
	right = "1cell",
	top = "0.5cell",
	bottom = "0",
}

config.scrollback_lines = 10000
config.audible_bell = "Disabled"

-- don't include tmux pane borders in mouse selection (add │ to default list)
-- don't include normal pipe (|)
-- don't include colon (:)
-- don't include comma (,)
config.selection_word_boundary = " \t\n{}[]()\"'`|│:,"

-- Customize hyperlinks:
--   https://wezfurlong.org/wezterm/hyperlinks.html#implicit-hyperlinks
-- Use the defaults as a base
config.hyperlink_rules = wezterm.default_hyperlink_rules()

-- make username/project paths clickable. this implies paths like the following are for github.
-- ( 'nvim-treesitter/nvim-treesitter' | wbthomason/packer.nvim | wez/wezterm | 'wez/wezterm.git' )
-- Disabled for now because _path_ names match the regex
-- table.insert(config.hyperlink_rules, {
--   regex = [[["]?([\w\d]{1}[-\w\d]+)(/){1}([-\w\d\.]+)["]?]],
--   format = 'https://www.github.com/$1/$3',
-- })


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
	{ key = "c", mods = "LEADER", action = act.SpawnCommandInNewTab({ domain = "CurrentPaneDomain", cwd = wezterm.home_dir }) },
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
		theme = theme,
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
