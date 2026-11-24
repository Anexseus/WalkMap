-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- WalkMap picks its map window type as it loads: an ordinary window while
-- the game's gamepad UI is off, a protected one while it is on (see
-- WalkMap_Combat.lua). The game switches between its mouse-and-keyboard and
-- gamepad interface without reloading, so when the player switches, WalkMap
-- shows a small window with a Reload button. Never a StaticPopup: those
-- opened from addon code have caused blocked-action errors in gamepad mode.
WalkMapStyleReload = {}
local reload = WalkMapStyleReload

local popup, pending, shownCount = nil, false, 0
local styleNote = ""

-- WalkMap's "How you play" follows the game's interface: Both with the
-- gamepad UI, Mouse and keyboard without it (WalkMapExtras.FollowInterfaceStyle).
local STYLE_NAMES = {mouse = "Mouse and keyboard", controller = "Controller", both = "Both"}
local function followStyle()
    if not (WalkMapExtras and WalkMapExtras.FollowInterfaceStyle) then return end
    local changed = WalkMapExtras.FollowInterfaceStyle(WalkMapCombat.GamepadUI())
    if changed then
        styleNote = " WalkMap's How you play is now " .. STYLE_NAMES[changed] .. "."
        print(WalkMapL("|cff80ff80WalkMap:|r How you play: " .. STYLE_NAMES[changed]
            .. " (follows the game's interface; change it under Settings > Controller & help)."))
    end
end

-- True when the window type no longer matches the game's interface.
function reload.Mismatch()
    if not (WalkMapCombat and WalkMapCombat.GamepadUI) then return false end
    return WalkMapCombat.GamepadUI() == WalkMapCombat.Free()
end

local function manager()
    return GamepadMode and GamepadMode.FrameControlsManager
end

-- With the gamepad UI on, hand the window to the game's controller
-- navigation so A can press Reload.
local function controllerShow(frame, button)
    if not WalkMapCombat.GamepadUI() then return end
    local m = manager()
    if m and type(m.HandlePopupShown) == "function" then pcall(m.HandlePopupShown, m, frame) end
    if SmartNavigation and type(SmartNavigation.SetTargetButtonForFrame) == "function" then
        pcall(SmartNavigation.SetTargetButtonForFrame, SmartNavigation, frame, button)
    end
end

local function controllerHide(frame)
    local m = manager()
    if m and type(m.FrameHidden) == "function" then pcall(m.FrameHidden, m, frame) end
end

local function doReload()
    if C_UI and C_UI.Reload then C_UI.Reload() elseif ReloadUI then ReloadUI() end
end

local function build()
    popup = CreateFrame("Frame", "WalkMapStyleReloadFrame", UIParent)
    popup:SetSize(380, 132)
    popup:SetPoint("TOP", UIParent, "TOP", 0, -180)
    popup:SetFrameStrata("DIALOG")
    popup:EnableMouse(true)
    if WalkMapUI and WalkMapUI.Menu then pcall(WalkMapUI.Menu, popup) end
    popup.title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    popup.title:SetPoint("TOP", popup, "TOP", 0, -14)
    WalkMapLocale.Static(popup.title, "WalkMap: reload needed")
    popup.text = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    popup.text:SetPoint("TOPLEFT", popup, "TOPLEFT", 18, -36)
    popup.text:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -18, -36)
    popup.text:SetJustifyH("LEFT")
    local function button(label, x, onClick)
        local b = CreateFrame("Button", nil, popup)
        b:SetSize(110, 24)
        b:SetPoint("BOTTOM", popup, "BOTTOM", x, 14)
        if WalkMapExtras and WalkMapExtras.StyleButton then WalkMapExtras.StyleButton(b) end
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        b.text:SetPoint("CENTER")
        b.text:SetText(WalkMapL(label))
        b:SetScript("OnClick", onClick)
        return b
    end
    popup.reloadButton = button("Reload now", -60, function()
        if InCombatLockdown and InCombatLockdown() then
            print(WalkMapL("|cff80ff80WalkMap:|r Reload after combat."))
            return
        end
        doReload()
    end)
    popup.laterButton = button("Later", 60, function() reload.Hide() end)
    popup:Hide()
end

function reload.Hide()
    if popup and popup:IsShown() then
        controllerHide(popup)
        popup:Hide()
    end
end

function reload.Show()
    if not reload.Mismatch() then return end
    if InCombatLockdown and InCombatLockdown() then pending = true return end
    pending = false
    if not popup then build() end
    popup.text:SetText(WalkMapL((WalkMapCombat.GamepadUI()
        and "You switched the game to its controller interface. Reload so WalkMap's map works with the controller. Until then the map behaves as with mouse and keyboard."
        or "You switched the game to its mouse and keyboard interface. Reload so WalkMap's map can also be moved, resized and set up during combat.")
        .. styleNote))
    if not popup:IsShown() then
        shownCount = shownCount + 1
        popup:Show()
        controllerShow(popup, popup.reloadButton)
    end
end

function reload.Frame() return popup end

function reload.Status()
    return (reload.Mismatch() and "reload needed" or "matches the game's interface")
        .. "; asked " .. shownCount .. " time(s)" .. (pending and "; waiting for combat to end" or "")
end

-- The game may also reload the interface itself when its interface style
-- changes (seen in game, 2026-11-18). Then no transition event reaches
-- WalkMap, so at login compare with the interface of the last session.
-- A character from before this check counts as having used the interface
-- its How you play stands for.
local function interfaceName() return WalkMapCombat.GamepadUI() and "gamepad" or "mouse" end
local function checkAtLogin()
    local saved = WalkMapCharacterSettings
    if type(saved) ~= "table" then return end
    local now = interfaceName()
    local last = saved.lastInterface
    if last == nil and WalkMapExtras and WalkMapExtras.PlayStyle then
        last = WalkMapExtras.PlayStyle() == "mouse" and "mouse" or "gamepad"
    end
    if last ~= now then
        if InCombatLockdown and InCombatLockdown() then pending = true else followStyle() end
    end
    saved.lastInterface = now
end
reload.CheckAtLogin = checkAtLogin

local events = CreateFrame("Frame")
events:RegisterEvent("INPUT_DEVICE_INTERFACE_TRANSITION")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
local loginChecked = false
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        if loginChecked then return end
        loginChecked = true
        -- A moment later, when WalkMap's buttons and settings are set up.
        if C_Timer and C_Timer.After then C_Timer.After(1, checkAtLogin) else checkAtLogin() end
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        if pending then followStyle() reload.Show() end
        return
    end
    -- Look a moment later, once the game has finished switching. Switching
    -- back hides the window again.
    local function check()
        styleNote = ""
        if type(WalkMapCharacterSettings) == "table" then WalkMapCharacterSettings.lastInterface = interfaceName() end
        if InCombatLockdown and InCombatLockdown() then pending = true
        else followStyle() end
        if reload.Mismatch() then reload.Show() else reload.Hide() end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.5, check) else check() end
end)
