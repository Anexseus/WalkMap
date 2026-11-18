-- "Select keeps the map released" with a small fake of the game's gamepad
-- window manager (FrameControlsManager) and with the custom controller.
local function fakeManager(env)
    local m = {shownFrames = {}, isUIFocused = false, calls = {}}
    function m:FrameShown(frame, isPopup, focus)
        for _, f in ipairs(self.shownFrames) do if f == frame then return false end end
        table.insert(self.shownFrames, frame)
        self.calls[#self.calls + 1] = {frame = frame, popup = isPopup, focus = focus}
        if not self.isUIFocused then
            if isPopup then self.isUIFocused = not frame.skipGamepadAutoFocus else self.isUIFocused = true end
        end
        if self.isUIFocused and (isPopup and not frame.skipGamepadAutoFocus or not isPopup and focus) then
            self.focusedFrame = frame
        elseif not self.focusedFrame then
            self.focusedFrame = frame
        end
        return true
    end
    function m:FrameHidden(frame)
        for i, f in ipairs(self.shownFrames) do if f == frame then table.remove(self.shownFrames, i) break end end
        if self.focusedFrame == frame then self.focusedFrame = self.shownFrames[1] end
        if #self.shownFrames == 0 then self.isUIFocused = false end
        return true
    end
    function m:HandlePopupShown(frame) return self:FrameShown(frame, true, true) end
    function m:GetActiveFrame() return self.isUIFocused and self.focusedFrame or nil end
    -- The game's red error line (UIErrorsFrame, one line per message type).
    local errorLine = {text = nil}
    function errorLine:GetText() return self.text end
    function errorLine:SetText(text) self.text = text end
    env.LE_GAME_ERR_SYSTEM = 22
    env.ERROR_NO_FRAME_TO_FOCUS = "No interface frame to focus!"
    env.UIErrorsFrame = {GetFontStringByID = function(_, id) return id == 22 and errorLine or nil end,
        Clear = function() errorLine.text = "" end}
    m.errorLine = errorLine
    function m:ToggleUIFocus()
        -- The game refuses to focus the UI with no window in its list.
        if not self.isUIFocused and #self.shownFrames == 0 then
            errorLine.text = env.ERROR_NO_FRAME_TO_FOCUS
            return
        end
        self.isUIFocused = not self.isUIFocused
    end
    env.GamepadMode = {FrameControlsManager = m}
    -- Post-hooks on the manager's methods run, as in the game.
    local plainHook = env.hooksecurefunc
    env.hooksecurefunc = function(target, name, fn)
        if target == m and type(name) == "string" and type(m[name]) == "function" then
            local original = m[name]
            m[name] = function(...)
                local a, b, c = original(...)
                fn(...)
                return a, b, c
            end
            return
        end
        if plainHook then return plainHook(target, name, fn) end
    end
    env.SmartNavigationSecureHelper = {}
    env.C_RestrictedActions = {IsAddOnRestrictionActive = function() return false end}
    env.Enum = env.Enum or {}
    env.Enum.AddOnRestrictionType = {Combat = 1}
    env.SmartNavigation = {RefreshButtonGroups = function() end, SetTargetButtonForFrame = function() end,
        GetCurrentButton = function() end}
    env.SmartNavigation_MarkFrameIgnored = function() end
    env.SmartNavigation_MarkFrameIgnoredContainerFrame = function() end
    env.InputUtil = {IsGamepadUIEnabled = function() return true end}
    return m
end

local function start(Mock, character)
    local env = Mock.new({playerMap = 1436, quests = {{header = "Westfall"}, {id = 101, title = "Westfall Stew", level = 13}}})
    local m = fakeManager(env)
    env.loadAddon({welcomeSeen = true}, character)
    env.fire("PLAYER_LOGIN")
    env.fire("PLAYER_ENTERING_WORLD")
    env.tick(0.3, 5)
    return env, m
end

local function open(env)
    if not env.WalkMapCore.frame:IsShown() then env.WalkMap_Toggle() end
    env.tick(0.3, 5)
end
local function close(env)
    if env.WalkMapCore.frame:IsShown() then env.WalkMap_Toggle() end
    env.tick(0.3, 5)
end

return {
    {"Native: with the map open, Select focuses the map before the group window", function(Mock)
        local env, m = start(Mock, {controllerMode = true, nativeController = true, selectKeepsReleased = true})
        local crfm = env.CreateFrame("Frame", "CompactRaidFrameManager")
        crfm:Show()
        m:FrameShown(crfm)
        m.isUIFocused = false
        open(env)
        Mock.eq(env.WalkMapNativeController.HasFocus(), true, "the map takes focus when it opens")
        m:ToggleUIFocus()  -- Select: back to the game
        env.tick(0.3, 3)
        m:ToggleUIFocus()  -- Select again
        m.focusedFrame = crfm  -- the game picks the leftmost window: the group window
        env.WalkMapNativeController.AfterToggle()
        env.tick(0.3, 3)
        Mock.eq(m.focusedFrame, env.WalkMapCore.frame, "the map is focused, not the group window")
        Mock.ok(m.isUIFocused, "UI focus kept")
        local listed = false
        for _, f in ipairs(m.shownFrames) do if f == crfm then listed = true end end
        Mock.ok(listed, "the group window stays reachable")
        -- Reopened while released: Select takes the map, not the group window.
        m:ToggleUIFocus()
        env.tick(0.3, 3)
        close(env)
        open(env)
        Mock.eq(env.WalkMapNativeController.HasFocus(), false, "held back")
        m:ToggleUIFocus()
        m.focusedFrame = crfm
        env.WalkMapNativeController.AfterToggle()
        env.tick(0.3, 3)
        Mock.eq(m.focusedFrame, env.WalkMapCore.frame, "map first after reopening too")
        -- Released, closed and reopened with the group window collapsed: the
        -- game turns Select into "open the group window" (no Select hook).
        m:ToggleUIFocus()
        env.tick(0.3, 3)
        m:FrameHidden(crfm)  -- collapsed
        close(env)
        open(env)
        Mock.eq(env.WalkMapNativeController.HasFocus(), false, "held back again")
        m:FrameShown(crfm, false, true)  -- Select expands the group window
        env.tick(0.3, 3)
        Mock.eq(m.focusedFrame, env.WalkMapCore.frame, "Select still takes the map")
        Mock.eq(env.WalkMapExtras.MapReleased(), false, "no longer released")
        -- Focus lands on the group window some other way (LB/RB): back to the map.
        m.focusedFrame = crfm
        env.tick(0.5, 5)
        Mock.eq(m.focusedFrame, env.WalkMapCore.frame, "the map takes focus back from the group window")
        Mock.eq(env.WalkMapCore.frame:GetFrameStrata(), "HIGH", "the map stays on its layer")
        -- The group changes: the game re-adds and focuses its group window.
        m:FrameHidden(crfm)
        m:FrameShown(crfm, false, true)
        env.tick(0.5, 5)
        Mock.eq(m.focusedFrame, env.WalkMapCore.frame, "re-added group window does not keep focus")
    end},
    {"Native: Select keeps the map released across close and open", function(Mock)
        local env, m = start(Mock, {controllerMode = true, nativeController = true, selectKeepsReleased = true})
        local map = env.WalkMapCore.frame
        open(env)
        Mock.eq(env.WalkMapNativeController.HasFocus(), true, "the map takes focus when it opens")
        m:ToggleUIFocus()  -- Select: back to the game
        env.tick(0.3, 3)
        Mock.eq(env.WalkMapExtras.MapReleased(), true, "released is remembered")
        close(env)
        local calls = #m.calls
        open(env)
        Mock.eq(env.WalkMapNativeController.HasFocus(), false, "reopened: the game keeps control")
        Mock.eq(#m.calls, calls, "map held back from the game's window list")
        Mock.ok(not env.WalkMapCore.resumeButton:IsShown(), "no Resume button: Select takes the map back")
        for _, call in ipairs(m.calls) do
            Mock.ok(not call.frame.skipGamepadAutoFocus, "never writes fields the game reads")
        end
        m:ToggleUIFocus()  -- Select again: take the map
        env.WalkMapNativeController.AfterToggle()  -- what the hooksecurefunc runs
        env.tick(0.3, 3)
        Mock.eq(env.WalkMapNativeController.HasFocus(), true, "Select takes the map back")
        Mock.eq(env.WalkMapExtras.MapReleased(), false, "no longer released")
        Mock.eq(m.errorLine.text, "", "the game's \"No interface frame to focus!\" is blanked")
        close(env)
        open(env)
        Mock.eq(env.WalkMapNativeController.HasFocus(), true, "and it takes focus on the next open again")
    end},
    {"Native: Select out of another window does not grab the held-back map", function(Mock)
        local env, m = start(Mock, {controllerMode = true, nativeController = true, selectKeepsReleased = true,
            mapReleased = true})
        open(env)
        local bags = {}
        m:FrameShown(bags, false, true)  -- a game window (bags) is focused
        m:ToggleUIFocus()                -- Select: leave the bags for gameplay
        env.WalkMapNativeController.AfterToggle()
        Mock.eq(env.WalkMapExtras.MapReleased(), true, "still released")
        Mock.eq(env.WalkMapNativeController.HasFocus(), false, "map not taken")
        m:ToggleUIFocus()                -- Select again: UI focus comes back
        env.WalkMapNativeController.AfterToggle()
        env.tick(0.3, 3)
        Mock.eq(env.WalkMapNativeController.HasFocus(), true, "now the map is taken")
    end},
    {"Native: setting off works as before", function(Mock)
        local env, m = start(Mock, {controllerMode = true, nativeController = true})
        local map = env.WalkMapCore.frame
        open(env)
        m:ToggleUIFocus()
        env.tick(0.3, 3)
        Mock.eq(env.WalkMapExtras.MapReleased(), false, "nothing remembered")
        close(env)
        open(env)
        Mock.eq(env.WalkMapNativeController.HasFocus(), true, "the map takes focus again on open")
    end},
    {"Native: combat release does not count", function(Mock)
        local env, m = start(Mock, {controllerMode = true, nativeController = true, selectKeepsReleased = true})
        open(env)
        env.InCombatLockdown = function() return true end
        m.isUIFocused = false
        env.tick(0.3, 3)
        env.InCombatLockdown = function() return false end
        env.tick(0.3, 3)
        Mock.eq(env.WalkMapExtras.MapReleased(), false, "focus lost in combat is not a release")
    end},
    {"Custom controller: Select pause is kept across close and open", function(Mock)
        local env = start(Mock, {controllerMode = true, nativeController = false, selectKeepsReleased = true})
        open(env)
        local press = env.WalkMapCore.frame:GetScript("OnGamePadButtonDown")
        press(env.WalkMapCore.frame, "PADBACK")
        Mock.eq(env.WalkMapExtras.MapReleased(), true, "Select released the map")
        close(env)
        open(env)
        Mock.eq((env.WalkMapCore.PadState()), true, "still paused after reopening")
        Mock.ok(not env.WalkMapCore.resumeButton:IsShown(), "no Resume button while released")
        press(env.WalkMapCore.frame, "PADBACK")
        Mock.eq(env.WalkMapExtras.MapReleased(), false, "Select takes it back")
    end},
}
