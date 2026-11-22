-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- The gamepad wheel's Quest & Maps in combat, while it opens WalkMap
-- (Settings, "Map key and wheel open").
--
-- In combat the game lets no addon code open or close WalkMap's (protected)
-- map, nor close the game's map; only a real key press does (WalkMap key, M,
-- X, B, or a macro with /click). The wheel clicks the game's quest log micro
-- button, so in a fight it would only open the game's map. So WalkMap greys
-- that button out for the fight: the wheel's map entry then opens nothing
-- (GamepadRadial.lua checks IsEnabled and prints a red line instead).
-- WalkMap clears that line and says in chat how to open and close the map in
-- combat. The button is enabled again when the fight ends.
-- (1.14.17 betas tried to close WalkMap from the wheel itself: impossible,
-- see the comment in WalkMap_QuestLog.lua's intercept.)
WalkMapWheelCombat = {}
local wheel = WalkMapWheelCombat

local HINT = "|cff80ff80WalkMap:|r The game does not let addons open or close the map from the wheel"
    .. " during combat. Bind a key to WalkMap in Key Bindings, or make a macro with"
    .. " /click WalkMapKeyboardToggle, to open and close it in combat."

local disabledByUs = false
local hints, lastHint = 0, -10

local function button() return _G.QuestLogMicroButton end
local function inCombat() return InCombatLockdown and InCombatLockdown() == true end
local function mapOpen() return WalkMapCore and WalkMapCore.frame and WalkMapCore.frame:IsShown() == true end
local function free() return WalkMapCombat and WalkMapCombat.Free and WalkMapCombat.Free() == true end
local function handOff()
    return WalkMapExtras and WalkMapExtras.HandOffDungeonMap and WalkMapExtras.HandOffDungeonMap() == true
end
-- Greyed out in a fight while the wheel would open WalkMap ("Map key and
-- wheel open"), and always while WalkMap is open (then the wheel would only
-- open the game's map behind it). Not inside a dungeon whose map another
-- addon draws in the game's map (the wheel opens that one on purpose).
-- 1.14.17-beta4/5 also skipped the free window (game gamepad UI off) and
-- waited for "Map key and wheel open"; beta1 only looked at an open map, and
-- that one greyed the wheel out for you. Now both count.
local function wanted()
    if handOff() then return false end
    if mapOpen() then return true end
    return WalkMapExtras and WalkMapExtras.UseGameMapKeys and WalkMapExtras.UseGameMapKeys() == true
end

-- The game enables its micro buttons again by itself (EnableMicroButtons,
-- e.g. when a window closes), also during a fight. So while the fight lasts
-- WalkMap greys the button out again whenever it finds it enabled, not only
-- once at the start (1.14.17-beta4 did only that, and the wheel stayed lit).
local enabling = false
local function update()
    local b = button()
    if not (b and b.IsEnabled and b.Enable and b.Disable) then return end
    local should = inCombat() and wanted()
    if should then
        if b:IsEnabled() and pcall(b.Disable, b) then disabledByUs = true end
    elseif disabledByUs then
        disabledByUs = false
        if not b:IsEnabled() then
            enabling = true
            pcall(b.Enable, b)
            enabling = false
        end
    end
end
wheel.Update = update

-- The red line the wheel prints for its disabled map entry.
local function isWheelLine(message)
    if type(message) ~= "string" then return false end
    local b = button()
    local own = b and b.disabledTooltip
    if type(own) == "function" then
        local ok, text = pcall(own)
        own = ok and text or nil
    end
    return message == own or message == _G.RADIAL_ERROR_FALLBACK
end

function wheel.OnError(message)
    if not disabledByUs or not isWheelLine(message) then return end
    local errors = UIErrorsFrame
    if errors and errors.Clear then pcall(errors.Clear, errors) end
    -- Free window (game gamepad UI off): addons may open and close it in
    -- combat, so the wheel's map entry simply opens or closes WalkMap.
    if free() and WalkMap_Toggle then
        pcall(WalkMap_Toggle)
        return
    end
    local now = GetTime and GetTime() or 0
    if now - lastHint >= 3 then
        lastHint = now
        hints = hints + 1
        print(HINT)
    end
end

function wheel.Status()
    local b = button()
    return (wanted() and "on" or "off") .. (disabledByUs and ", quest log button greyed out" or "")
        .. ", hints " .. hints .. " (map keys " .. tostring(WalkMapExtras and WalkMapExtras.UseGameMapKeys
        and WalkMapExtras.UseGameMapKeys()) .. ", window " .. (free() and "free" or "protected")
        .. ", hand-off " .. tostring(handOff()) .. ", button " .. tostring(b and b.IsEnabled and b:IsEnabled()) .. ")"
end

local hooked = false
local events = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_LOGIN", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED"}) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" and not hooked and UIErrorsFrame and hooksecurefunc then
        hooked = true
        hooksecurefunc(UIErrorsFrame, "AddMessage", function(_, message) wheel.OnError(message) end)
        local b = button()
        if b and b.Enable then
            hooksecurefunc(b, "Enable", function() if not enabling then update() end end)
        end
    end
    update()
end)
-- A fight can begin before PLAYER_REGEN_DISABLED is handled; check often.
local since = 0
events:SetScript("OnUpdate", function(_, elapsed)
    since = since + elapsed
    if since < 0.2 then return end
    since = 0
    if disabledByUs or inCombat() then update() end
end)
