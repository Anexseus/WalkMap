-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- Settings > Map > Fade while moving. Fades the whole window while
-- the character moves, unless the mouse, a WalkMap menu or controller focus
-- is on it. Alpha only: no size, position or visibility changes.
-- Split from WalkMap.lua in 1.11.
local core = WalkMapCore
if not core then return end
local frame, playerLayer = core.frame, core.playerLayer

local FADE_SPEED = 3
local fadeDriver = CreateFrame("Frame", nil, UIParent)
local fadeAlpha, fadeElapsed = 1, 0
local function fadeTarget()
    if not WalkMapExtras.FadeWhileMoving() or not frame:IsShown() then return 1 end
    if not (IsPlayerMoving and IsPlayerMoving()) then return 1 end
    if frame.IsMouseOver and frame:IsMouseOver() then return 1 end
    if WalkMapNativeController and WalkMapNativeController.HasFocus
        and WalkMapNativeController.HasFocus() then return 1 end
    local _, _, menu, submenu, settingsPanel = WalkMapExtras.ControllerControls()
    for _, panel in ipairs({menu, submenu, settingsPanel}) do
        if panel and panel:IsShown() then return 1 end
    end
    return WalkMapExtras.FadeAlpha()
end
fadeDriver:SetScript("OnUpdate", function(_, elapsed)
    fadeElapsed = fadeElapsed + elapsed
    if fadeElapsed < 0.03 then return end
    local step = fadeElapsed * FADE_SPEED
    fadeElapsed = 0
    local target = fadeTarget()
    if fadeAlpha == target then return end
    if fadeAlpha < target then fadeAlpha = math.min(target, fadeAlpha + step)
    else fadeAlpha = math.max(target, fadeAlpha - step) end
    pcall(frame.SetAlpha, frame, fadeAlpha)
    -- Optionally keep the player arrow (and its halo) fully visible.
    if playerLayer.SetIgnoreParentAlpha then
        pcall(playerLayer.SetIgnoreParentAlpha, playerLayer,
            fadeAlpha < 1 and WalkMapExtras.FadeKeepArrow())
    end
end)
