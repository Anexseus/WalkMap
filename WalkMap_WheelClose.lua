-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- "Wheel closes WalkMap in combat" (experimental, off by default).
--
-- The gamepad wheel's Quest & Maps clicks the game's quest log micro button
-- (GamepadRadial.lua: MicroMenuButtonHandler:action -> button:Click), which
-- opens the game's map. In combat WalkMap's protected map can only be closed
-- by secure code (WalkMap_Combat.lua), and the game's map not at all.
--
-- So WalkMap wraps that button's OnClick with a secure snippet
-- (SecureHandlerWrapScript, set up out of combat): in combat, with WalkMap
-- open, the snippet hides WalkMap and returns false, so the game's handler
-- (ToggleQuestLog) never runs. Out of combat it does nothing.
--
-- The game runs wrap snippets in combat only on protected frames, and the
-- micro button is not one. A protected frame anchored to a frame makes that
-- frame protected too, so while a fight lasts WalkMap's (invisible, 1 px)
-- secure header is anchored to the button; it is let go when the fight
-- ends. Price: in a fight the micro button cannot be moved by anyone, so a
-- game layout change of the micro menu during combat could be refused.
-- Hence optional, and off by default.
WalkMapWheelClose = {}
local wheel = WalkMapWheelClose

local SNIPPET = [[
    local controls = owner:GetFrameRef("combat-controls")
    local map = owner:GetFrameRef("map")
    if map and map:IsShown() and controls and controls:GetAttribute("state-combat") == "combat" then
        map:Hide()
        return false
    end
]]

local header, wrapped, anchored = nil, false, false
local lastError

local function button() return _G.QuestLogMicroButton end
local function inCombat() return InCombatLockdown and InCombatLockdown() == true end
local function wanted()
    return WalkMapExtras and WalkMapExtras.WheelClosesInCombat and WalkMapExtras.WheelClosesInCombat()
        and not (WalkMapCombat and WalkMapCombat.Free and WalkMapCombat.Free())
end

local function ensureHeader()
    if header then return header end
    local map = WalkMapCore and WalkMapCore.frame
    local controls = _G.WalkMapCombatBindings
    if not (map and controls) then return nil end
    header = CreateFrame("Frame", "WalkMapWheelCloseHeader", UIParent, "SecureHandlerBaseTemplate")
    header:SetSize(1, 1)
    header:SetAlpha(0)
    header:EnableMouse(false)
    header:SetFrameRef("map", map)
    header:SetFrameRef("combat-controls", controls)
    return header
end

-- Out of combat only: wrap or unwrap the button's OnClick.
local function apply()
    if inCombat() then return end
    local b = button()
    if not (b and SecureHandlerWrapScript and SecureHandlerUnwrapScript) then return end
    local want = wanted()
    if want and not wrapped then
        if not ensureHeader() then return end
        local ok, message = pcall(SecureHandlerWrapScript, b, "OnClick", header, SNIPPET)
        if ok then wrapped = true else lastError = tostring(message) end
    elseif not want and wrapped then
        local ok, message = pcall(SecureHandlerUnwrapScript, b, "OnClick")
        if ok then wrapped = false else lastError = tostring(message) end
    end
end
wheel.Apply = apply

-- As a fight begins (still before the combat lock) the header is anchored
-- to the button, which makes the button protected for the fight; it is
-- let go when the fight ends.
local function anchor(on)
    local b = button()
    if not (header and b) then return end
    if on and wrapped and not anchored then
        if pcall(header.SetPoint, header, "CENTER", b, "CENTER") then anchored = true end
    elseif not on and anchored and not inCombat() then
        pcall(header.ClearAllPoints, header)
        anchored = false
    end
end
wheel.Anchor = anchor

function wheel.Status()
    local b = button()
    local protected = b and b.IsProtected and select(1, b:IsProtected())
    return (wanted() and "on" or "off") .. ", wrapped " .. tostring(wrapped)
        .. ", anchored " .. tostring(anchored) .. ", button protected " .. tostring(protected == true)
        .. (lastError and (", error " .. lastError) or "")
end
function wheel.Snippet() return SNIPPET end

local events = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_LOGIN", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED"}) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        -- Fires just before the combat lock: last moment to anchor.
        if wanted() then anchor(true) end
        return
    end
    anchor(false)
    apply()
end)
-- The setting can change in Settings at any time; apply it out of combat.
local since = 0
events:SetScript("OnUpdate", function(_, elapsed)
    since = since + elapsed
    if since < 1 then return end
    since = 0
    if not inCombat() and wrapped ~= (wanted() == true) then apply() end
end)
