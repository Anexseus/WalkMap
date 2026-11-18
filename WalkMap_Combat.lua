-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- Keep the rendered map visible while native navigation is suspended.
-- Combat toggling is a preconfigured hardware click on our own protected frame.
WalkMapCombat = {}
local combat = WalkMapCombat
local owner, header, shield, passive, ready, viewportFrame, shieldLabel
local keyCount, lastError = 0, nil
local allowed, savedLevels = {}, {}

function combat.Locked()
    if InCombatLockdown and InCombatLockdown() then return true end
    if C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive
        and Enum and Enum.AddOnRestrictionType then
        local ok, active = pcall(C_RestrictedActions.IsAddOnRestrictionActive, Enum.AddOnRestrictionType.Combat)
        return not ok or active == true
    end
    return false
end

-- "Free" map window: when the game's own gamepad UI is off as WalkMap
-- loads, the map is an ordinary window. It is not protected, so in combat
-- it can still be opened, closed, moved and resized, and its footer and
-- settings work. The protected (secure) window is only needed for the
-- game's controller navigation, whose window handling is restricted in
-- combat. Decided once per load; switching the game's interface style asks
-- for a reload (WalkMap_StyleReload.lua).
local function gamepadUI()
    if InputUtil and type(InputUtil.IsGamepadUIEnabled) == "function" then
        local ok, on = pcall(InputUtil.IsGamepadUIEnabled)
        if ok then return on == true end
    end
    return false
end
local free = not gamepadUI()
function combat.Free() return free end
function combat.GamepadUI() return gamepadUI() end
-- Locked for things that change the map window itself (show, hide, move,
-- size, footer, settings): only when the window is protected.
function combat.FrameLocked() return not free and combat.Locked() end

function combat.Passive() return passive == true end
function combat.Ready() return ready == true end

-- Title-area buttons that stay usable with the mouse in combat. They only
-- change what WalkMap shows, so they are lifted above the shield while it
-- is up and put back afterwards.
function combat.AllowInCombat(button)
    if button then allowed[#allowed + 1] = button end
end

local function liftAllowed(lift)
    if not shield then return end
    for _, button in ipairs(allowed) do
        if lift then
            if savedLevels[button] == nil then savedLevels[button] = button:GetFrameLevel() end
            button:SetFrameLevel(shield:GetFrameLevel() + 2)
        elseif savedLevels[button] then
            button:SetFrameLevel(savedLevels[button])
            savedLevels[button] = nil
        end
    end
end

-- The shield blocks the title bar, footer and edges in combat (moving,
-- resizing and settings are protected there) but leaves the map itself free
-- for the mouse: hover tooltips, wheel zoom, drag to pan, Alt-click waypoint.
local function layoutShield()
    if not (shield and owner and viewportFrame) then return end
    local fTop, fBottom, fLeft, fRight = owner:GetTop(), owner:GetBottom(), owner:GetLeft(), owner:GetRight()
    local vTop, vBottom, vLeft, vRight = viewportFrame:GetTop(), viewportFrame:GetBottom(),
        viewportFrame:GetLeft(), viewportFrame:GetRight()
    local pieces = shield.pieces
    if not (fTop and vTop and fBottom and vBottom and fLeft and vLeft and fRight and vRight) then
        -- No layout yet: cover everything, as before.
        pieces[1]:ClearAllPoints() pieces[1]:SetAllPoints(owner)
        for i = 2, 4 do pieces[i]:ClearAllPoints() pieces[i]:Hide() end
        return
    end
    local top, bottom = math.max(0, fTop - vTop), math.max(0, vBottom - fBottom)
    local left, right = math.max(0, vLeft - fLeft), math.max(0, fRight - vRight)
    for i = 1, 4 do pieces[i]:ClearAllPoints() pieces[i]:Show() end
    pieces[1]:SetPoint("TOPLEFT", owner, "TOPLEFT", 0, 0)
    pieces[1]:SetPoint("BOTTOMRIGHT", owner, "TOPRIGHT", 0, -top)
    pieces[2]:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, bottom)
    pieces[2]:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", 0, 0)
    pieces[3]:SetPoint("TOPLEFT", owner, "TOPLEFT", 0, -top)
    pieces[3]:SetPoint("BOTTOMRIGHT", owner, "BOTTOMLEFT", left, bottom)
    pieces[4]:SetPoint("TOPLEFT", owner, "TOPRIGHT", -right, -top)
    pieces[4]:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", 0, bottom)
end

local SHIELD_TEXT = "Combat: map, top menus and quest log work with the mouse"

function combat.SetPassive(value)
    -- A free window needs no shield.
    passive = value == true and not free
    if shield then
        if passive then
            layoutShield()
            liftAllowed(true)
            shield:Show()
        else
            shield:Hide()
            liftAllowed(false)
        end
    end
end

local function refreshKeys()
    if not ready or combat.Locked() then return end
    local keys, seen = {}, {}
    for _, action in ipairs({"WALKMAP_TOGGLE", "CLICK WalkMapKeyboardToggle:LeftButton"}) do
        for _, key in ipairs({GetBindingKey(action)}) do
            if type(key) == "string" and key ~= "" and not seen[key] then
                seen[key] = true
                keys[#keys + 1] = key
            end
        end
    end
    -- A free window opens and closes with the normal key binding in combat;
    -- no private combat key overrides.
    if free then keys = {} end
    for i = 1, math.max(keyCount, #keys) do header:SetAttribute("close-key-" .. i, keys[i]) end
    header:SetAttribute("close-key-count", #keys)
    keyCount = #keys
    -- Settings > Map > Close map when combat starts.
    header:SetAttribute("close-on-combat",
        (WalkMapExtras and WalkMapExtras.CloseMapInCombat and WalkMapExtras.CloseMapInCombat()) or nil)
end

-- A setting the secure handler reads changed; applies now out of combat,
-- otherwise when combat ends.
function combat.SettingChanged()
    if ready and not combat.Locked() then pcall(refreshKeys) end
end

function combat.Diagnostics()
    return "window=" .. (free and "free (game gamepad UI off at load)" or "protected")
        .. "; ready=" .. tostring(ready == true) .. "; passive=" .. tostring(passive == true)
        .. "; existing close keys=" .. keyCount .. "; error=" .. tostring(lastError or "none")
end

function combat.Init(frame, closeButton, toggleButton, viewport)
    owner = frame
    viewportFrame = viewport
    local ok, message = pcall(function()
        assert(RegisterStateDriver and GetBindingKey, "secure combat APIs unavailable")
        header = CreateFrame("Frame", "WalkMapCombatBindings", UIParent, "SecureHandlerStateTemplate")
        -- Secure snippets may only show and hide a protected map; a free map
        -- gets no reference, so those snippets leave it alone.
        if not free then header:SetFrameRef("map", frame) end
        header:SetFrameRef("toggle", toggleButton)
        header:SetAttribute("_onstate-combat", [[
            self:ClearBindings()
            if newstate == "combat" then
                local map = self:GetFrameRef("map")
                local toggle = self:GetFrameRef("toggle")
                -- Only as the fight begins: opening it later in the fight
                -- does not trigger this again.
                if map and map:IsShown() and self:GetAttribute("close-on-combat") then map:Hide() end
                if map and toggle then
                    for i = 1, self:GetAttribute("close-key-count") or 0 do
                        local key = self:GetAttribute("close-key-" .. i)
                        if key then self:SetBindingClick(true, key, toggle:GetName(), "LeftButton") end
                    end
                end
            end
        ]])
        local closeSnippet = [[
            local controls = self:GetFrameRef("combat-controls")
            local map = self:GetFrameRef("map")
            if controls and controls:GetAttribute("state-combat") == "combat" then
                if map and map:IsShown() then map:Hide() end
            end
        ]]
        for _, button in ipairs({closeButton, toggleButton}) do
            if not free then button:SetFrameRef("map", frame) end
            button:SetFrameRef("combat-controls", header)
            button:SetAttribute("_onclick", closeSnippet)
        end
        -- Macro target: /click WalkMapCloseMacro closes the map, also in
        -- combat (the secure snippet runs there; out of combat the hook does).
        local macroClose = CreateFrame("Button", "WalkMapCloseMacro", UIParent, "SecureHandlerClickTemplate")
        macroClose:RegisterForClicks("AnyUp", "AnyDown")
        if not free then macroClose:SetFrameRef("map", frame) end
        macroClose:SetFrameRef("combat-controls", header)
        macroClose:SetAttribute("_onclick", closeSnippet)
        macroClose:HookScript("OnClick", function()
            if not combat.FrameLocked() and frame:IsShown() and WalkMap_Toggle then
                WalkMap_Toggle()
            end
        end)
        macroClose:Hide()
        -- Escape closes an open map (out of combat). Bound only while the map
        -- is shown, on its own binding owner; a secure state driver drops it
        -- as combat starts, so Escape works normally in a fight.
        local escape = CreateFrame("Frame", "WalkMapEscapeBindings", UIParent, "SecureHandlerStateTemplate")
        escape:SetAttribute("_onstate-combat", [[
            if newstate == "combat" then self:ClearBindings() end
        ]])
        RegisterStateDriver(escape, "combat", "[combat] combat; safe")
        -- Escape steps back like the game's windows: an open menu first,
        -- then Settings, then the map itself.
        local escapeButton = CreateFrame("Button", "WalkMapEscapeClose", UIParent)
        escapeButton:RegisterForClicks("AnyUp")
        escapeButton:SetScript("OnClick", function()
            if combat.Locked() then return end
            local _, _, menu, submenu, settingsPanel = WalkMapExtras.ControllerControls()
            if (menu and menu:IsShown()) or (submenu and submenu:IsShown()) then
                WalkMapExtras.CloseMenus()
            elseif settingsPanel and settingsPanel:IsShown() and settingsPanel.doneButton then
                settingsPanel.doneButton:Click()
            elseif frame:IsShown() and WalkMap_Toggle then
                WalkMap_Toggle()
            end
        end)
        escapeButton:Hide()
        combat.BindEscape = function(on)
            if combat.Locked() or not (ClearOverrideBindings and SetOverrideBindingClick) then return end
            pcall(ClearOverrideBindings, escape)
            if on then pcall(SetOverrideBindingClick, escape, true, "ESCAPE", "WalkMapEscapeClose", "LeftButton") end
        end
        frame:HookScript("OnShow", function() combat.BindEscape(true) end)
        frame:HookScript("OnHide", function() combat.BindEscape(false) end)
        toggleButton:SetAttribute("_onclick", [[
            local controls = self:GetFrameRef("combat-controls")
            local map = self:GetFrameRef("map")
            if controls and controls:GetAttribute("state-combat") == "combat" and map then
                if map:IsShown() then map:Hide() else map:Show() end
            end
        ]])
        -- Holder frame (no mouse) with four mouse-blocking pieces around
        -- the map area; see layoutShield.
        shield = CreateFrame("Frame", nil, frame)
        shield:SetAllPoints(frame)
        shield:SetFrameLevel(frame:GetFrameLevel() + 100)
        shield:EnableMouse(false)
        shield.pieces = {}
        for i = 1, 4 do
            local piece = CreateFrame("Frame", nil, shield)
            piece:SetFrameLevel(shield:GetFrameLevel())
            piece:EnableMouse(true)
            if piece.EnableGamePadButton then piece:EnableGamePadButton(false) end
            shield.pieces[i] = piece
        end
        shieldLabel = shield:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        shieldLabel:SetPoint("BOTTOM", shield, "BOTTOM", 0, 7)
        shieldLabel:SetText(SHIELD_TEXT)
        shield:Hide()
        closeButton:SetFrameLevel(shield:GetFrameLevel() + 2)
        -- Opened during combat: fit the shield to the map area again.
        frame:HookScript("OnShow", function()
            if passive then pcall(layoutShield) end
        end)
        ready = true
        refreshKeys()
        RegisterStateDriver(header, "combat", "[combat] combat; safe")
    end)
    if not ok then ready, lastError = false, tostring(message) end
    local driver = CreateFrame("Frame")
    for _, event in ipairs({"PLAYER_LOGIN", "UPDATE_BINDINGS", "PLAYER_REGEN_ENABLED"}) do driver:RegisterEvent(event) end
    driver:SetScript("OnEvent", function(_, event)
        if combat.Locked() then return end
        -- After a fight, an open map gets its Escape binding back.
        if event == "PLAYER_REGEN_ENABLED" and combat.BindEscape then combat.BindEscape(owner:IsShown()) end
        local changed, errorText = pcall(refreshKeys)
        if not changed then lastError = tostring(errorText) end
    end)
end
