-- With the game's gamepad UI off at load, the map is an ordinary window
-- that works in combat; switching the game's interface asks for a reload.
local function start(Mock, gamepad, secure)
    local env = Mock.new({playerMap = 1436, quests = {{header = "Westfall"}, {id = 101, title = "Westfall Stew", level = 13}}})
    if secure then
        -- The secure combat parts (state driver, key bindings) for the shield.
        env.RegisterStateDriver = function() end
        env.GetBindingKey = function() end
    end
    env.__gamepad = gamepad
    env.InputUtil = {IsGamepadUIEnabled = function() return env.__gamepad end}
    env.loadAddon({welcomeSeen = true}, {follow = true})
    env.fire("PLAYER_LOGIN")
    env.fire("PLAYER_ENTERING_WORLD")
    env.tick(0.3, 5)
    return env
end

local function combat(env, on)
    env.InCombatLockdown = function() return on end
    if on then env.fire("PLAYER_REGEN_DISABLED") else env.fire("PLAYER_REGEN_ENABLED") end
    env.tick(0.3, 2)
end

return {
    {"Gamepad UI in combat: a dark bar over the footer says what works, inside the bar", function(Mock)
        local env = start(Mock, true, true)
        Mock.eq(env.WalkMapCombat.Free(), false, "protected window")
        Mock.eq(env.WalkMapCombat.Ready(), true, env.WalkMapCombat.Diagnostics())
        env.WalkMap_Toggle()
        env.tick(0.3, 2)
        combat(env, true)
        env.WalkMapCombat.SetPassive(true)
        local shield, label = env.WalkMapCombat.ShieldParts()
        Mock.ok(shield and shield:IsShown(), "shield shown")
        local footer = shield.pieces[2]
        Mock.ok(shield.footerCover, "a dark cover over the footer")
        Mock.ok(label.__parent == footer or label:GetParent() == footer, "the text sits in the footer bar")
        Mock.ok(tostring(label:GetText()):find("work with the mouse", 1, true), "says what works")
        local width = tonumber(footer:GetWidth()) or 0
        if width > 40 then
            Mock.ok(label:GetStringWidth() <= width - 24, "and fits the bar")
        end
        env.WalkMapCombat.SetPassive(false)
        combat(env, false)
    end},
    {"Gamepad UI off: open, close and settings in combat", function(Mock)
        local env = start(Mock, false)
        Mock.eq(env.WalkMapCombat.Free(), true, "free window")
        combat(env, true)
        Mock.eq(env.WalkMapCombat.FrameLocked(), false, "map window not locked in combat")
        env.WalkMap_Toggle()
        env.tick(0.3, 2)
        Mock.ok(env.WalkMapCore.frame:IsShown(), "opens in combat")
        env.WalkMapCombat.SetPassive(true)
        Mock.eq(env.WalkMapCombat.Passive(), false, "no combat shield")
        local s = env.WalkMapCharacterSettings
        local panel = env.WalkMapExtras.SettingsPanel()
        env.WalkMapExtras.ShowSettingsPage("Map")
        local followRow, miniRow
        for _, row in ipairs(panel.options) do
            local text = row.label:GetText() or ""
            if row:IsShown() and text:find("^Follow player") then followRow = row end
        end
        followRow:GetScript("OnClick")(followRow)
        Mock.eq(s.follow, false, "a map setting changes in combat")
        env.WalkMapExtras.ShowSettingsPage("Minimap")
        for _, row in ipairs(panel.options) do
            local text = row.label:GetText() or ""
            if row:IsShown() and text:find("^WalkMap minimap") then miniRow = row end
        end
        local before = s.miniMap
        miniRow:GetScript("OnClick")(miniRow)
        Mock.eq(s.miniMap, before, "the minimap waits until after combat")
        Mock.ok(env.__printed[#env.__printed]:find("after combat", 1, true), "and says so")
        env.WalkMap_Toggle()
        env.tick(0.3, 2)
        Mock.ok(not env.WalkMapCore.frame:IsShown(), "closes in combat")
    end},
    {"Gamepad UI on: protected window, locked in combat as before", function(Mock)
        local env = start(Mock, true)
        Mock.eq(env.WalkMapCombat.Free(), false, "protected window")
        combat(env, true)
        Mock.eq(env.WalkMapCombat.FrameLocked(), true, "map window locked in combat")
    end},
    {"Switching the game's interface asks for a reload", function(Mock)
        local env = start(Mock, false)
        local reloads = 0
        env.C_UI = {Reload = function() reloads = reloads + 1 end}
        Mock.eq(env.WalkMapStyleReload.Mismatch(), false, "matches at first")
        env.__gamepad = true
        env.fire("INPUT_DEVICE_INTERFACE_TRANSITION")
        env.tick(1, 5)
        local popup = env.WalkMapStyleReload.Frame()
        Mock.ok(popup and popup:IsShown(), "reload window shown")
        local cs = env.WalkMapCharacterSettings
        Mock.eq(cs.playStyle, "both", "How you play follows: Both with the gamepad UI")
        Mock.eq(cs.controllerMode, true, "Pad focus on")
        Mock.ok(popup.text:GetText():find("How you play is now Both", 1, true), "the window says so")
        popup.laterButton:GetScript("OnClick")(popup.laterButton)
        Mock.ok(not popup:IsShown(), "Later closes it")
        env.__gamepad = false
        env.fire("INPUT_DEVICE_INTERFACE_TRANSITION")
        env.tick(1, 5)
        Mock.ok(not popup:IsShown(), "switched back: nothing to do")
        Mock.eq(env.WalkMapCharacterSettings.playStyle, "mouse", "back to Mouse and keyboard")
        Mock.eq(env.WalkMapCharacterSettings.controllerMode, false, "Pad focus off again")
        env.__gamepad = true
        combat(env, true)
        env.fire("INPUT_DEVICE_INTERFACE_TRANSITION")
        env.tick(1, 5)
        Mock.ok(not popup:IsShown(), "not in combat")
        combat(env, false)
        Mock.ok(popup:IsShown(), "shown when combat ends")
        Mock.eq(popup.reloadButton:GetAttribute("type"), "macro", "Reload now is a secure macro button")
        Mock.eq(popup.reloadButton:GetAttribute("macrotext"), "/reload", "that runs the game's /reload")
    end},
    {"A chosen Controller style is kept when the gamepad UI comes on", function(Mock)
        local env = start(Mock, false)
        env.WalkMapCharacterSettings.playStyle = "controller"
        env.__gamepad = true
        env.fire("INPUT_DEVICE_INTERFACE_TRANSITION")
        env.tick(1, 5)
        Mock.eq(env.WalkMapCharacterSettings.playStyle, "controller", "Controller kept")
    end},
    {"Game reloaded after switching to mouse and keyboard: How you play follows at login", function(Mock)
        local env = Mock.new({playerMap = 1436})
        env.InputUtil = {IsGamepadUIEnabled = function() return false end}
        env.loadAddon({welcomeSeen = true}, {playStyle = "both", controllerMode = true, lastInterface = "gamepad"})
        env.fire("PLAYER_LOGIN")
        env.fire("PLAYER_ENTERING_WORLD")
        env.tick(2, 10)
        local s = env.WalkMapCharacterSettings
        Mock.eq(s.playStyle, "mouse", "Mouse and keyboard after the switch")
        Mock.eq(s.controllerMode, false, "Pad focus off")
        Mock.eq(s.lastInterface, "mouse", "remembered")
        Mock.eq(env.WalkMapStyleReload.Frame(), nil, "no reload window needed")
    end},
    {"Character from before the check: inferred from How you play", function(Mock)
        local env = Mock.new({playerMap = 1436})
        env.InputUtil = {IsGamepadUIEnabled = function() return false end}
        env.loadAddon({welcomeSeen = true}, {playStyle = "controller", controllerMode = true})
        env.fire("PLAYER_LOGIN")
        env.fire("PLAYER_ENTERING_WORLD")
        env.tick(2, 10)
        Mock.eq(env.WalkMapCharacterSettings.playStyle, "mouse", "controller style with the mouse UI: follows")
    end},
    {"Same interface as last time: nothing changes", function(Mock)
        local env = Mock.new({playerMap = 1436})
        env.InputUtil = {IsGamepadUIEnabled = function() return false end}
        env.loadAddon({welcomeSeen = true}, {playStyle = "controller", controllerMode = true, lastInterface = "mouse"})
        env.fire("PLAYER_LOGIN")
        env.fire("PLAYER_ENTERING_WORLD")
        env.tick(2, 10)
        Mock.eq(env.WalkMapCharacterSettings.playStyle, "controller", "a choice made with this interface is kept")
    end},
}
