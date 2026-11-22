-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- "Wheel closes WalkMap in combat" (optional, off by default).
--
-- The gamepad wheel's Quest & Maps clicks the game's quest log micro button,
-- which opens the game's map, and in combat addons may not close that map
-- again. But the wheel checks the button first: a disabled button opens
-- nothing and only prints a red line (GamepadRadial.lua, Trigger). So while
-- WalkMap is open in combat, WalkMap disables that button; a press on the
-- wheel's map then prints the line, WalkMap clears it and closes itself, and
-- the button is enabled again. The button is enabled again as soon as WalkMap
-- closes or combat ends.
--
-- Price: meanwhile the wheel's map icon and the micro button look disabled,
-- and disabling the button runs a little of the game's own code from WalkMap
-- (its OnDisable). Hence optional, and off by default.
WalkMapWheelClose = {}
local wheel = WalkMapWheelClose

local disabledByUs = false
local closes = 0

local function button() return _G.QuestLogMicroButton end
local function inCombat() return InCombatLockdown and InCombatLockdown() == true end
local function mapOpen() return WalkMapCore and WalkMapCore.frame and WalkMapCore.frame:IsShown() end
local function wanted()
    return WalkMapExtras and WalkMapExtras.WheelClosesInCombat and WalkMapExtras.WheelClosesInCombat()
end

local function update()
    local b = button()
    if not (b and b.IsEnabled and b.Enable and b.Disable) then return end
    local should = wanted() and inCombat() and mapOpen()
    if should and not disabledByUs then
        if b:IsEnabled() then
            if pcall(b.Disable, b) then disabledByUs = true end
        end
    elseif not should and disabledByUs then
        disabledByUs = false
        if not b:IsEnabled() then pcall(b.Enable, b) end
    end
end
wheel.Update = update

-- The red line the wheel prints for a disabled map entry.
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
    closes = closes + 1
    if mapOpen() and WalkMap_Toggle then pcall(WalkMap_Toggle) end
    update()
end

function wheel.Status()
    return (wanted() and "on" or "off") .. (disabledByUs and ", map button held" or "")
        .. ", closed " .. closes .. " time(s)"
end

local hooked = false
local function hook()
    if hooked or not (UIErrorsFrame and hooksecurefunc) then return end
    hooked = true
    hooksecurefunc(UIErrorsFrame, "AddMessage", function(_, message) wheel.OnError(message) end)
end

local events = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_LOGIN", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED"}) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then hook() end
    update()
end)
-- WalkMap opens and closes in combat too; look a few times a second.
local elapsedSince = 0
events:SetScript("OnUpdate", function(_, elapsed)
    elapsedSince = elapsedSince + elapsed
    if elapsedSince < 0.1 then return end
    elapsedSince = 0
    if disabledByUs or (inCombat() and wanted()) then update() end
end)
