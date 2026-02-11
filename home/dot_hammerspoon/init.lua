-- A global variable for the Hyper Mode
hyper =  {"command", "control", "option"}	-- caps lock held down
hypers =  {"command", "control", "option", "shift"}	-- caps lock and shift held down

-- Bind this early so that it'll work even even there's an error later on
hs.hotkey.bind(hypers, "r", hs.reload)

-- app hotkeys
-- hs.hotkey.bind(hyper, "i", function() hs.application.launchOrFocus("IntelliJ IDEA") end)
hs.hotkey.bind(hyper, "s", function() hs.application.launchOrFocus("Slack") end)
hs.hotkey.bind(hyper, "t", function() hs.application.launchOrFocus("WezTerm") end)
hs.hotkey.bind(hyper, "b", function() hs.application.launchOrFocus("Firefox") end)
hs.hotkey.bind(hyper, "f", function() hs.application.launchOrFocus("Finder") end)
-- hs.hotkey.bind(hyper, "n", function() hs.application.launchOrFocus("Obsidian") end)
hs.hotkey.bind(hyper, "z", function() hs.application.launchOrFocus("zoom.us") end)
-- hs.hotkey.bind(hyper, "k", function() hs.application.launchOrFocus("Keybase") end)

-- Fancy paste -- pretends to be a keyboard
hs.hotkey.bind({"cmd", "alt", "shift"}, "V", function() hs.eventtap.keyStrokes(hs.pasteboard.getContents()) end)

-- ¯\_(ツ)_/¯
hs.hotkey.bind(hypers, "s", function() hs.eventtap.keyStrokes("¯\\_(ツ)_/¯") end)

-- SpoonInstall: installed manually (managed by chezmoi)
hs.loadSpoon("SpoonInstall")

spoon.SpoonInstall:andUse("ClipboardTool")
spoon.ClipboardTool.show_copied_alert = false
spoon.ClipboardTool:start()
spoon.ClipboardTool:bindHotkeys({show_clipboard = {hyper, "c"}})
hs.hotkey.bind(hypers, "c", function() spoon.ClipboardTool:clearAll() end)

spoon.SpoonInstall:andUse("HoldToQuit")
spoon.HoldToQuit:start()

-- KSheet spoon to show current application hotkeys
spoon.SpoonInstall:andUse("KSheet")
local cheat_visible = false
function toggleCheatSheet()
  if not cheat_visible then
    spoon.KSheet:show()
    cheat_visible = true
  else
    spoon.KSheetk:hide()
    cheat_visible = false
  end
end
hs.hotkey.bind(hyper, '/', toggleCheatSheet)

-- Keychain access
--spoon.SpoonInstall:andUse("Keychain")
--pass = spoon.Keychain:getItem({service="onelogin.com"})


-- grid based window movement/arrangement
hs.window.animationDuration = 0
hs.grid.setGrid('6x6')
hs.hotkey.bind(hypers, "z", hs.grid.show)
hs.hotkey.bind(hypers, hs.keycodes.map["space"], function() hs.window.focusedWindow():move(hs.layout.maximized,  nil, true) end)
hs.hotkey.bind(hypers, 'j', function() hs.grid.set(hs.window.focusedWindow(), '0,0 3x6') end)
hs.hotkey.bind(hypers, ',', function() hs.grid.set(hs.window.focusedWindow(), '0,3 6x3') end)
hs.hotkey.bind(hypers, 'i', function() hs.grid.set(hs.window.focusedWindow(), '0,0 6x3') end)
hs.hotkey.bind(hypers, 'l', function() hs.grid.set(hs.window.focusedWindow(), '3,0 3x6') end)
hs.hotkey.bind(hypers, 'u', function() hs.grid.set(hs.window.focusedWindow(), '0,0 3x3') end)
hs.hotkey.bind(hypers, 'm', function() hs.grid.set(hs.window.focusedWindow(), '0,3 3x3') end)
hs.hotkey.bind(hypers, 'o', function() hs.grid.set(hs.window.focusedWindow(), '3,0 3x3') end)
hs.hotkey.bind(hypers, ".", function() hs.grid.set(hs.window.focusedWindow(), '3,3 3x3') end)
hs.hotkey.bind(hypers, "k", function() hs.grid.set(hs.window.focusedWindow(), '1,1 4x4') end)
-- fullscreen toggle
hs.hotkey.bind(hyper, "return", function()
  local win = hs.window.frontmostWindow()
  win:setFullscreen(not win:isFullscreen())
end)
