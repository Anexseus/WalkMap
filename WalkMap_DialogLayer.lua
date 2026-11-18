-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- NPC dialogs on top: while you talk to an NPC (gossip, quests, vendors,
-- trainers, flight masters, bank, mail, auction house and similar), the
-- WalkMap window drops below those windows; afterwards it comes back up.
-- Game windows (talents, spellbook, character, collections... - anything
-- the game opens as a UI panel) work by "last opened is on top": opened
-- after the map, they cover it; opening the map again brings it back up.
-- The window is protected, so its layer only changes out of combat.
WalkMapDialogLayer = {}
local layer = WalkMapDialogLayer
local map = WalkMapOverlay
if not map then return end

local NORMAL, UNDER = "HIGH", "LOW"
-- NPC windows are MEDIUM, so the map drops to LOW. The controller's action
-- bars, target buttons and D-pad labels are also LOW; a high frame level
-- keeps the map above them while it is down.
local UNDER_LEVEL = 200
local normalLevel
local DIALOGS = {
    "GossipFrame", "QuestFrame", "MerchantFrame", "ClassTrainerFrame", "TaxiFrame",
    "FlightMapFrame", "BankFrame", "MailFrame", "OpenMailFrame", "ItemTextFrame",
    "TabardFrame", "PetStableFrame", "AuctionHouseFrame", "AuctionFrame",
    "GuildRegistrarFrame", "PetitionFrame", "TradeFrame", "InboxFrame",
    "QuestLogPopupDetailFrame",
}

local lowered = false

-- Game UI panels that are on screen now, by name.
local PANEL_AREAS = {"left", "center", "right", "doublewide", "fullscreen"}
local function visiblePanels()
    local found = {}
    if GetUIPanel then
        for _, area in ipairs(PANEL_AREAS) do
            local ok, panel = pcall(GetUIPanel, area)
            if ok and panel and panel ~= map and panel.IsVisible and panel:IsVisible() then
                found[panel.GetName and panel:GetName() or tostring(panel)] = true
            end
        end
    end
    if type(UIPanelWindows) == "table" then
        for name in pairs(UIPanelWindows) do
            local panel = _G[name]
            if panel and panel ~= map and type(panel) == "table" and panel.IsVisible and panel:IsVisible() then
                found[name] = true
            end
        end
    end
    return found
end

-- Lowered because a game window opened while the map was up.
local panelBelow, knownPanels = false, {}
local function checkPanels()
    local now = visiblePanels()
    if next(now) == nil then
        panelBelow = false
    elseif map:IsShown() then
        for name in pairs(now) do
            if not knownPanels[name] then panelBelow = true end
        end
    end
    knownPanels = now
    return next(now)
end
-- Opening the map puts it on top again (the windows already open stay
-- behind it).
map:HookScript("OnShow", function()
    knownPanels = visiblePanels()
    panelBelow = false
end)

local function dialogOpen()
    for _, name in ipairs(DIALOGS) do
        local dialog = _G[name]
        -- IsVisible, not IsShown: InboxFrame sits inside MailFrame and keeps
        -- its own "shown" flag after the mailbox closes, which kept the map
        -- lowered (below the controller's buttons) for the rest of the session.
        if dialog and dialog.IsVisible and dialog:IsVisible() then return name end
    end
end

local function locked()
    return (InCombatLockdown and InCombatLockdown()) or (WalkMapCombat and WalkMapCombat.Locked())
end

local function apply()
    if not map:IsShown() and not lowered then return end
    checkPanels()
    local want = dialogOpen() ~= nil or panelBelow
    if want == lowered or locked() then return end
    if want then normalLevel = normalLevel or map:GetFrameLevel() end
    if pcall(map.SetFrameStrata, map, want and UNDER or NORMAL) then
        lowered = want
        if want then
            pcall(map.SetFrameLevel, map, math.max(UNDER_LEVEL, normalLevel or 0))
        elseif normalLevel then
            pcall(map.SetFrameLevel, map, normalLevel)
            normalLevel = nil
        end
    end
end

-- A cheap check four times a second; NPC windows open and close on their
-- own schedule, so polling is simpler and safer than hooking each one.
local driver = CreateFrame("Frame")
local elapsedSince = 0
driver:SetScript("OnUpdate", function(_, elapsed)
    elapsedSince = elapsedSince + elapsed
    if elapsedSince < 0.25 then return end
    elapsedSince = 0
    apply()
end)

function layer.Status()
    return (lowered and ("below game window, level " .. map:GetFrameLevel()) or "normal")
        .. (dialogOpen() and ("; NPC: " .. dialogOpen()) or "")
        .. (panelBelow and ("; panel: " .. tostring(next(knownPanels))) or "")
end
