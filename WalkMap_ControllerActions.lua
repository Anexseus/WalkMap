-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- Private, focus-scoped shortcuts. Do not add bindings to the native stack.
WalkMapControllerActions = {}
local actions = WalkMapControllerActions
local callbacks, bindingOwner, mode, ready, focused, errorText, pendingInit

local function locked()
    return (WalkMapCombat and WalkMapCombat.Locked()) or (InCombatLockdown and InCombatLockdown())
end

local function run(fn, ...)
    local ok, message = pcall(fn, ...)
    if not ok then
        errorText = tostring(message)
        if WalkMapExtras then WalkMapExtras.DebugEvent("Controller shortcut: " .. errorText) end
    end
    return ok
end

function actions.Release()
    if not bindingOwner or locked() then return end
    if run(ClearOverrideBindings, bindingOwner) then mode = nil end
end

function actions.Focus(value)
    focused = value == true
    if focused then actions.Refresh() else actions.Release() end
end

function actions.Refresh()
    if pendingInit and not locked() then actions.Init(callbacks) end
    if not ready or locked() then return end
    local wanted = focused and callbacks.FocusMode() or nil
    if wanted == mode then return end
    actions.Release()
    if wanted then
        local ok = run(function()
            -- X: map control from the map's buttons or pan mode (not the log).
            if wanted ~= "log" then
                SetOverrideBindingClick(bindingOwner, true, GAMEPAD_FACE_LEFT or "PAD3", "WalkMapNativePanShortcut", "LeftButton")
            end
            -- Y: quest log on the map's buttons and inside the log; pan mode
            -- keeps Y for stepping through markers.
            if wanted ~= "pan" and callbacks.QuestLog then
                SetOverrideBindingClick(bindingOwner, true, GAMEPAD_FACE_UP or "PAD4", "WalkMapNativeQuestLogShortcut", "LeftButton")
            end
            if wanted == "pan" then
                SetOverrideBindingClick(bindingOwner, true, GAMEPAD_SHOULDER_LEFT or "PADLSHOULDER", "WalkMapNativeZoomOutShortcut", "LeftButton")
                SetOverrideBindingClick(bindingOwner, true, GAMEPAD_SHOULDER_RIGHT or "PADRSHOULDER", "WalkMapNativeZoomInShortcut", "LeftButton")
                if callbacks.NextMarker then
                    SetOverrideBindingClick(bindingOwner, true, GAMEPAD_FACE_UP or "PAD4", "WalkMapNativeMarkerShortcut", "LeftButton")
                end
            end
        end)
        if ok then mode = wanted else actions.Release() end
    end
end

function actions.Diagnostics()
    return "ready=" .. tostring(ready == true) .. "; active=" .. tostring(mode or "none")
        .. "; " .. tostring(errorText or "private X; Y quest log; pan-mode LB/RB/Y; secure combat cleanup")
end

function actions.Init(handlers)
    callbacks, focused = handlers, focused == true
    if locked() then pendingInit = true;errorText = "waiting for combat to end";return end
    pendingInit, errorText = nil, nil
    if not SetOverrideBindingClick or not ClearOverrideBindings or not RegisterStateDriver then
        errorText = "shortcut APIs unavailable";return
    end
    local ok, message = pcall(function()
        bindingOwner = CreateFrame("Frame", "WalkMapNativeShortcutBindings", UIParent, "SecureHandlerStateTemplate")
        bindingOwner:EnableMouse(false)
        bindingOwner:EnableKeyboard(false)
        bindingOwner:SetAttribute("_onstate-combat", [[
            if newstate == "combat" then self:ClearBindings() end
        ]])
        bindingOwner:HookScript("OnAttributeChanged", function(_, name, value)
            if name == "state-combat" and value == "combat" then mode, focused = nil, false end
        end)
        RegisterStateDriver(bindingOwner, "combat", "[combat] combat; safe")
        local function button(name, action, panOnly, notPan)
            local control = CreateFrame("Button", name, bindingOwner)
            control:SetSize(1, 1)
            control:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", -100, -100)
            control:EnableMouse(false)
            control:RegisterForClicks("AnyUp")
            control:SetScript("OnClick", function()
                if locked() or not focused then return end
                local current = callbacks.FocusMode()
                if current and (not panOnly or current == "pan") and (not notPan or current ~= "pan") then run(action) end
            end)
        end
        button("WalkMapNativePanShortcut", callbacks.TogglePan)
        button("WalkMapNativeZoomOutShortcut", function() callbacks.Zoom(-1) end, true)
        button("WalkMapNativeZoomInShortcut", function() callbacks.Zoom(1) end, true)
        if callbacks.NextMarker then button("WalkMapNativeMarkerShortcut", callbacks.NextMarker, true) end
        if callbacks.QuestLog then button("WalkMapNativeQuestLogShortcut", callbacks.QuestLog, false, true) end
        ready = true
    end)
    if not ok then ready, errorText = false, tostring(message) end
end
