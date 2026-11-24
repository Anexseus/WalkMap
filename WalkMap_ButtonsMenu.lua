-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- Split from WalkMap.lua in 1.11; loads right after it and reaches the map
-- window through WalkMapCore.
local core = WalkMapCore
if not core then return end
local frame, status, closeButton = core.frame, core.status, core.closeButton
local mapPickerButton, dbBadge, padToggle = core.mapPickerButton, core.dbBadge, core.padToggle
local miniZoomInButton, miniZoomOutButton = core.miniZoomInButton, core.miniZoomOutButton
local centerButton = core.centerButton
local updateZoomLabels, updatePadMode = core.UpdateZoomLabels, core.UpdatePadMode

-- =========================================================
-- Buttons menu (footer, next to Settings): choose which map buttons to hide.
-- Everything except Settings and this button itself can be hidden. Saved
-- per character in WalkMapCharacterSettings.hiddenButtons.
-- =========================================================

do
    local layoutButton = CreateFrame("Button", nil, frame)
    local top, view, _, _, _, questButton = WalkMapExtras.ControllerControls()
    layoutButton:SetFrameLevel(frame:GetFrameLevel() + 4)
    layoutButton:SetSize(64, 19)
    layoutButton:SetPoint("BOTTOMLEFT", view, "BOTTOMRIGHT", 4, 0)
    layoutButton:EnableMouse(true)
    WalkMapExtras.StyleButton(layoutButton)
    local label = layoutButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER")
    WalkMapLocale.Static(label, "Buttons")
    -- Quests moves one place right to make room.
    -- Quests takes the old Player slot on the right (Player is gone; its
    -- hidden button still follows the footer layout, M+/M- included).
    questButton:ClearAllPoints()
    questButton:SetPoint("BOTTOMRIGHT", centerButton, "BOTTOMRIGHT", 0, 0)
    -- Coordinates centred in the footer again, between Buttons and Quests.
    status:ClearAllPoints()
    status:SetPoint("BOTTOM", frame, "BOTTOM", 0, 8)
    status:SetWidth(150)
    status:SetJustifyH("CENTER")
    status:SetWordWrap(false)
    WalkMapCombat.AllowInCombat(layoutButton)

    local tab = function() return WalkMapQuestLog and WalkMapQuestLog.Tab and WalkMapQuestLog.Tab() end
    -- key, menu label, frames. The close button is protected: it only changes
    -- out of combat.
    local ITEMS = {
        {"pad", "Pad focus", function() return {padToggle} end},
        {"title", "Zone title", function() return {mapPickerButton} end},
        {"db", "DB status", function() return {dbBadge} end},
        {"close", "Close button (X)", function() return {closeButton} end, true},
        {"places", "Places", function() return {top[1]} end},
        {"clearview", "Clear view", function() return {top[2]} end},
        {"mini", "WalkMap mini", function() return {top[3]} end},
        {"follow", "Follow", function() return {top[4]} end},
        {"friends", "Friends and guild", function() return {} end},
        {"questlog", "Quest log book", function() return {tab()} end},
        {"quests", "Quests", function() return {questButton} end},
        {"zoom", "M+ / M-", function() return {miniZoomInButton, miniZoomOutButton} end},
        {"coords", "Coordinates", function() return {} end},
        {"up", "Map level up", function() return {} end},
    }
    local function saved()
        return type(WalkMapCharacterSettings) == "table" and WalkMapCharacterSettings or {}
    end
    local function hiddenSet()
        local settings = saved()
        if type(settings.hiddenButtons) ~= "table" then
            settings.hiddenButtons = {}
            -- The earlier Simple button (1.09 test builds) hid this set.
            if settings.simpleMap == true then
                for _, key in ipairs({"db", "places", "clearview", "mini", "follow", "player", "zoom"}) do
                    settings.hiddenButtons[key] = true
                end
            end
            settings.simpleMap = nil
        end
        return settings.hiddenButtons
    end
    local function isHidden(key) return hiddenSet()[key] == true end

    local hooked, wasShown = {}, {}
    local function applyItem(item)
        local key, protected = item[1], item[4]
        local hide = isHidden(key)
        if key == "coords" then
            -- Read again by updateZoomLabels, which also hides them on narrow maps.
            status.walkmapHidden = hide
            status:SetAlpha(hide and 0 or 1)
            return
        end
        if key == "up" then
            -- WalkMap_Levels.lua shows and hides its own button and reads
            -- the same saved choice.
            if WalkMapLevels and WalkMapLevels.Refresh then WalkMapLevels.Refresh() end
            return
        end
        if key == "friends" then
            -- WalkMapFriends.TabWanted reads the same saved choice; the toolbar
            -- lays out again so the other buttons take the space.
            if not (InCombatLockdown and InCombatLockdown()) and WalkMapExtras.Resize then
                WalkMapExtras.Resize()
            end
            return
        end
        if protected and InCombatLockdown and InCombatLockdown() then return end
        for _, button in ipairs(item[3]()) do
            if button then
                if not hooked[button] and not protected then
                    hooked[button] = true
                    -- Other code shows some of these again (e.g. M+/M- with
                    -- the minimap); hidden ones hide straight away.
                    button:HookScript("OnShow", function(self)
                        if isHidden(key) then self:Hide() end
                    end)
                end
                if hide then
                    -- Remember what was on screen, so showing restores exactly that.
                    if wasShown[button] == nil then wasShown[button] = button:IsShown() end
                    if button:IsShown() then button:Hide() end
                elseif wasShown[button] then
                    wasShown[button] = nil
                    if not button:IsShown() then button:Show() end
                end
            end
        end
    end
    local function apply()
        for _, item in ipairs(ITEMS) do applyItem(item) end
        -- Let the map put back what belongs on screen (M+/M-, labels).
        updateZoomLabels()
        if updatePadMode then updatePadMode() end
        if WalkMapNativeController and WalkMapNativeController.RequestRefresh then
            WalkMapNativeController.RequestRefresh()
        end
    end

    WalkMapExtras.SetButtonsMenu({
        Items = function()
            local list = {}
            for _, item in ipairs(ITEMS) do list[#list + 1] = {item[1], item[2]} end
            return list
        end,
        IsHidden = isHidden,
        Toggle = function(key)
            for _, item in ipairs(ITEMS) do
                if item[1] == key then
                    if item[4] and InCombatLockdown and InCombatLockdown() then
                        print(WalkMapL("|cff80ff80WalkMap:|r The close button can change after combat."))
                        return
                    end
                    hiddenSet()[key] = not isHidden(key) or nil
                end
            end
            apply()
        end,
        SetAll = function(hide)
            local set = hiddenSet()
            for _, item in ipairs(ITEMS) do
                if not (item[4] and InCombatLockdown and InCombatLockdown()) then
                    set[item[1]] = hide or nil
                end
            end
            apply()
        end,
    })
    layoutButton:SetScript("OnClick", function(self) WalkMapExtras.OpenButtonsMenu(self) end)
    layoutButton:HookScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(WalkMapL("Map buttons"))
        GameTooltip:AddLine(WalkMapL("Choose which buttons the map shows. Settings and this button always stay."),
            0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    layoutButton:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    -- The quest log's book button exists once its file has loaded.
    frame:HookScript("OnShow", function() if next(hiddenSet()) then apply() end end)
    local login = CreateFrame("Frame")
    login:RegisterEvent("PLAYER_LOGIN")
    login:SetScript("OnEvent", function() if next(hiddenSet()) then apply() end end)
    WalkMapSimpleButton = layoutButton
end
