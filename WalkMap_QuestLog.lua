-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- WalkMap quest log: a panel that folds out beside the map (closed by
-- default), plus the opt-in "Use map and quest log keys" setting.
-- Reads the game's own quest log; changes only watch/focus/share/abandon
-- through the client's normal quest log functions.
WalkMapQuestLog = {}
local log = WalkMapQuestLog
local owner = _G.WalkMapOverlay
if not owner or not WalkMapExtras or not WalkMapUI then return end

local settings = WalkMapCharacterSettings or {}
if type(settings.questLogCollapsed) ~= "table" then settings.questLogCollapsed = {} end
settings.questLogZoneOnly = settings.questLogZoneOnly == true
-- Own height, independent of the map; set by dragging the grip, per character.
local MIN_HEIGHT = 360
if type(settings.questLogHeight) ~= "number" or settings.questLogHeight < MIN_HEIGHT then
    settings.questLogHeight = nil
end

local PANEL_WIDTH, ROW_HEIGHT, ACTION_COLUMN = 340, 19, 104
local panel, tab, rows, headers, pager, filterButton
local detail, actions = {}, {}
local entries, visible, page, pages, selectedID = {}, {}, 1, 1, nil
local fullText, refresh, showDetail = false, nil, nil
local pendingQuest -- set by log.OpenQuest: select it and show its page

-- Parchment detail area, as in the game's own quest log; dark ink on it.
-- Near-black brown ink and the game's parchment fonts for contrast.
local INK = {0.1, 0.06, 0.02}
local INK_SOFT = {0.16, 0.1, 0.04}
local INK_DONE = {0.04, 0.33, 0.04}
local INK_TAG = {0.5, 0.08, 0.02}
local function font(name, fallback) return _G[name] and name or fallback end
local TITLE_FONT = font("QuestTitleFont", "GameFontNormalLarge")
local BODY_FONT = font("QuestFont", "GameFontHighlight")
local SMALL_FONT = font("QuestFontNormalSmall", "GameFontHighlight")

-- ---------------------------------------------------------
-- Quest log reads (modern C_QuestLog first, classic globals second)
-- ---------------------------------------------------------
local function call(fn, ...)
    if type(fn) ~= "function" then return false end
    return pcall(fn, ...)
end

-- "Elite", "Group 3", "Dungeon"... (WalkMap_QuestInfo.lua).
local function questTag(id, info)
    return WalkMapQuestInfo and WalkMapQuestInfo.Tag(id, info.suggestedGroup) or nil
end

local function objectiveList(id)
    if not C_QuestLog.GetQuestObjectives then return {} end
    local ok, list = call(C_QuestLog.GetQuestObjectives, id)
    return ok and type(list) == "table" and list or {}
end

local function readLog()
    local list, zone = {}, nil
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo) then return list end
    local count = C_QuestLog.GetNumQuestLogEntries() or 0
    for index = 1, math.min(count, 120) do
        local info = C_QuestLog.GetInfo(index)
        if info and info.isHeader then
            zone = info.title or ""
            list[#list + 1] = {header = true, title = zone, gameCollapsed = info.isCollapsed}
        elseif info and type(info.questID) == "number" then
            local _, complete = call(C_QuestLog.IsComplete, info.questID)
            local objectives = objectiveList(info.questID)
            local done = 0
            for _, objective in ipairs(objectives) do if objective.finished then done = done + 1 end end
            list[#list + 1] = {id = info.questID, index = index, zone = zone,
                title = info.title or ("Quest " .. info.questID), level = info.level,
                complete = complete == true or info.isComplete == 1 or info.isComplete == true,
                done = done, total = #objectives, objectives = objectives,
                tag = questTag(info.questID, info)}
        end
    end
    return list
end

local function selectQuest(entry)
    if C_QuestLog.SetSelectedQuest then call(C_QuestLog.SetSelectedQuest, entry.id)
    elseif SelectQuestLogEntry then call(SelectQuestLogEntry, entry.index) end
end

local function questText(entry)
    selectQuest(entry)
    if GetQuestLogQuestText then
        local ok, description, objectives = pcall(GetQuestLogQuestText, entry.index)
        if ok then return description, objectives end
    end
end

local function isWatched(entry)
    if C_QuestLog.GetQuestWatchType then
        local ok, kind = call(C_QuestLog.GetQuestWatchType, entry.id)
        if ok then return kind ~= nil end
    end
    if C_QuestLog.IsQuestWatched then
        local ok, watched = call(C_QuestLog.IsQuestWatched, entry.id)
        if ok then return watched == true end
    end
    if IsQuestWatched then
        local ok, watched = call(IsQuestWatched, entry.index)
        if ok then return watched == true or watched == 1 end
    end
    return false
end

local function setWatched(entry, watched)
    local ok
    if watched then
        if C_QuestLog.AddQuestWatch then ok = call(C_QuestLog.AddQuestWatch, entry.id) end
        if not ok and AddQuestWatch then call(AddQuestWatch, entry.index) end
    else
        if C_QuestLog.RemoveQuestWatch then ok = call(C_QuestLog.RemoveQuestWatch, entry.id) end
        if not ok and RemoveQuestWatch then call(RemoveQuestWatch, entry.index) end
    end
end

-- Track / Untrack. With WalkMap's tracker on, the button decides whether the
-- quest is listed there. The game's own watch list follows only when the
-- game's tracker is visible too (or WalkMap's tracker is off).
local function trackerOn()
    return WalkMapExtras.ZoneTracker and WalkMapExtras.ZoneTracker() and WalkMapExtras.TrackerHidden ~= nil
end

local function isTracked(entry)
    if trackerOn() then return not WalkMapExtras.TrackerHidden(entry.id) end
    return isWatched(entry)
end

local function setTracked(entry, tracked)
    if not trackerOn() then setWatched(entry, tracked) return end
    WalkMapExtras.SetTrackerHidden(entry.id, not tracked)
    local options = WalkMapExtras.TrackerOptions and WalkMapExtras.TrackerOptions()
    if not (options and options.hideGame) then setWatched(entry, tracked) end
end

-- Returns shareable, reason.
local function shareState(entry)
    if not (IsInGroup and IsInGroup()) then return false, "You are not in a group." end
    -- The game blocks sharing during combat.
    if InCombatLockdown and InCombatLockdown() then return false, "You can't share a quest in combat." end
    if C_QuestLog.IsPushableQuest then
        local ok, pushable = call(C_QuestLog.IsPushableQuest, entry.id)
        if ok then return pushable == true, "This quest can't be shared." end
    end
    selectQuest(entry)
    if GetQuestLogPushable then
        local ok, pushable = call(GetQuestLogPushable)
        if ok then return pushable == true or pushable == 1, "This quest can't be shared." end
    end
    return false, "This quest can't be shared."
end

-- Zone map whose name matches a quest-log header ("Westfall").
local function mapByName(name)
    if type(name) ~= "string" or name == "" or not (WalkMapMaps and WalkMapMaps.MenuGroups) then return nil end
    local ok, groups = pcall(WalkMapMaps.MenuGroups)
    for _, group in ipairs(ok and groups or {}) do
        for _, zone in ipairs(group.zones or {}) do
            if zone[2] == name then return zone[1] end
        end
    end
end

-- Map for "Show on map", in order of preference:
-- 1. the map with the most known QuestieDB locations (current zone wins a tie),
-- 2. the map of the game's next waypoint for it (e.g. the turn-in),
-- 3. the zone the quest is filed under in the quest log.
local function questMap(entry)
    local data = WalkMapLiveDB and WalkMapLiveDB.Objective(entry.id)
        or WalkMapObjectives and WalkMapObjectives[entry.id]
    local best, count
    local here = WalkMapMaps and WalkMapMaps.CurrentZone()
    for mapID, points in pairs(data and data[2] or {}) do
        local n = type(points) == "table" and #points or 0
        if n > 0 and (not count or n > count or (n == count and mapID == here)) then best, count = mapID, n end
    end
    if best then return best end
    local mapID = WalkMapQuestInfo and WalkMapQuestInfo.NextWaypoint(entry.id)
    if mapID then return mapID end
    return mapByName(entry.zone)
end

local function rewards(entry)
    selectQuest(entry)
    local result = {items = {}}
    if GetQuestLogRewardMoney then
        local ok, money = call(GetQuestLogRewardMoney)
        if ok and type(money) == "number" and money > 0 then result.money = money end
    end
    if GetQuestLogRewardXP then
        local ok, xp = call(GetQuestLogRewardXP)
        if ok and type(xp) == "number" and xp > 0 then result.xp = xp end
    end
    for _, kind in ipairs({{"reward", GetNumQuestLogRewards, GetQuestLogRewardInfo},
        {"choice", GetNumQuestLogChoices, GetQuestLogChoiceInfo}}) do
        local ok, n = call(kind[2])
        for i = 1, ok and type(n) == "number" and math.min(n, 8) or 0 do
            local okInfo, name, texture, amount = call(kind[3], i)
            if okInfo and texture and #result.items < 8 then
                result.items[#result.items + 1] = {kind = kind[1], index = i, name = name,
                    texture = texture, count = amount}
            end
        end
    end
    return result
end

local function moneyText(money)
    if GetCoinTextureString then
        local ok, text = pcall(GetCoinTextureString, money)
        if ok and text then return text end
    end
    local gold, silver, copper = math.floor(money / 10000), math.floor(money / 100) % 100, money % 100
    return (gold > 0 and gold .. "g " or "") .. (silver > 0 and silver .. "s " or "") .. copper .. "c"
end

-- The game's difficulty colour for a quest (WalkMap_QuestInfo.lua).
local function levelColor(level, questID)
    if WalkMapQuestInfo then return WalkMapQuestInfo.Color(questID, level) end
    return 0.8, 0.8, 0.8
end

local function entryByID(id)
    for _, entry in ipairs(entries) do
        if entry.id and entry.id == id then return entry end
    end
end
local function selectedEntry() return entryByID(selectedID) end

local function currentZoneName()
    local name = GetZoneText and GetZoneText()
    if (not name or name == "") and WalkMapMaps then name = WalkMapMaps.Name(WalkMapMaps.CurrentZone()) end
    return name
end

-- Header rows and quests after zone filter and WalkMap's own collapse state.
local function visibleEntries()
    local list, zoneOnly, zone = {}, settings.questLogZoneOnly, currentZoneName()
    local skipping = false
    for _, entry in ipairs(entries) do
        if entry.header then
            skipping = zoneOnly and entry.title ~= zone
            if not skipping then list[#list + 1] = entry end
        elseif not skipping and not settings.questLogCollapsed[entry.zone or ""] then
            list[#list + 1] = entry
        end
    end
    return list
end

-- ---------------------------------------------------------
-- Panel
-- ---------------------------------------------------------
local function placePanel()
    -- Fold out to the right; use the left side when the screen edge is near.
    local right = owner:GetRight() or 0
    local screen = UIParent:GetRight() or (GetScreenWidth and GetScreenWidth()) or 0
    panel:ClearAllPoints()
    local onLeft = right + PANEL_WIDTH > screen and (owner:GetLeft() or 0) > PANEL_WIDTH
    if onLeft then
        panel:SetPoint("TOPRIGHT", owner, "TOPLEFT", 2, 0)
    else
        panel:SetPoint("TOPLEFT", owner, "TOPRIGHT", -2, 0)
    end
    -- Saved height, or the map's height until the player drags the grip.
    panel:SetHeight(settings.questLogHeight or math.max(MIN_HEIGHT, owner:GetHeight() or MIN_HEIGHT))
end

local function updateTab()
    if not tab then return end
    local open = panel:IsShown()
    tab.icon:SetDesaturated(not open)
    tab.icon:SetAlpha(open and 1 or 0.85)
    tab.lit:SetShown(open)
end

local function setShown(shown)
    if shown then placePanel() end
    if WalkMapNativeController and WalkMapNativeController.SetVisible then
        WalkMapNativeController.SetVisible(panel, shown)
    elseif shown then panel:Show() else panel:Hide() end
    updateTab()
end

local function makeButton(parent, width, height, text)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, height)
    button:EnableMouse(true)
    WalkMapExtras.StyleButton(button)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label:SetPoint("CENTER")
    button.label:SetText(text)
    return button
end

local function fill(parent, layer, r, g, b, a)
    local texture = parent:CreateTexture(nil, layer)
    texture:SetColorTexture(r, g, b, a)
    return texture
end

local function ink(fontString, color)
    fontString:SetTextColor(color[1], color[2], color[3])
    fontString:SetShadowOffset(0, 0)
end

local function tooltip(button, title, line)
    button:HookScript("OnEnter", function(self)
        if not GameTooltip then return end
        -- No tooltip when the controller lands here just because the map opened.
        if WalkMapJustOpened and WalkMapJustOpened(self) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(type(title) == "function" and title(self) or title)
        local text = type(line) == "function" and line(self) or line
        if text then GameTooltip:AddLine(text, 0.85, 0.85, 0.85, true) end
        GameTooltip:Show()
    end)
    button:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

local function arrowTexture(parent, size)
    local texture = parent:CreateTexture(nil, "ARTWORK")
    texture:SetSize(size, size)
    if texture:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow") == false then
        texture:SetColorTexture(1, 0.82, 0.3, 0.9)
    end
    return texture
end

local function setScroll(offset)
    local scroll = detail.scroll
    local maxScroll = math.max(0, (detail.contentHeight or 0) - scroll:GetHeight())
    offset = math.max(0, math.min(maxScroll, offset))
    scroll:SetVerticalScroll(offset)
    return offset, maxScroll
end

local function updateFullButton()
    local button = actions.full
    if not button then return end
    if not fullText then button.label:SetText("Full text") return end
    local offset, maxScroll = detail.scroll:GetVerticalScroll() or 0, math.max(0,
        (detail.contentHeight or 0) - detail.scroll:GetHeight())
    button.label:SetText(offset < maxScroll - 1 and "More text" or "Back")
end

local function buildPanel()
    panel = CreateFrame("Frame", "WalkMapQuestLogPanel", owner)
    panel:SetWidth(PANEL_WIDTH)
    panel:SetFrameLevel(owner:GetFrameLevel() + 6)
    panel:EnableMouse(true)
    panel:SetClampedToScreen(true)
    WalkMapUI.Window(panel)
    panel:Hide()

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -9)
    title:SetText("Quest log")
    panel.count = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.count:SetPoint("LEFT", title, "RIGHT", 8, 0)
    panel.count:SetTextColor(0.85, 0.78, 0.6)

    -- No close button: B (from the list), Y, L or the book button close it.

    -- Drag the bottom-right grip to set the quest log's length.
    local grip = CreateFrame("Button", nil, panel)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -3, 3)
    grip:SetFrameLevel(panel:GetFrameLevel() + 10)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        local _, y = GetCursorPosition()
        self.startY, self.startHeight = y, panel:GetHeight()
        self.dragging = true
    end)
    grip:SetScript("OnMouseUp", function(self)
        if not self.dragging then return end
        self.dragging = false
        settings.questLogHeight = math.floor(panel:GetHeight() + 0.5)
        refresh()
    end)
    grip:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            self:GetScript("OnMouseUp")(self)
            return
        end
        local _, y = GetCursorPosition()
        local scale = panel:GetEffectiveScale()
        local top = panel:GetTop() or 0
        local maxHeight = math.max(MIN_HEIGHT, top - 4)
        local height = self.startHeight + (self.startY - y) / scale
        panel:SetHeight(math.max(MIN_HEIGHT, math.min(maxHeight, height)))
    end)
    grip:HookScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Drag to set the quest log's length")
        GameTooltip:AddLine("Right-click to match the map's height again.", 0.85, 0.85, 0.85)
        GameTooltip:Show()
    end)
    grip:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    grip:RegisterForClicks("RightButtonUp")
    grip:SetScript("OnClick", function()
        settings.questLogHeight = nil
        placePanel()
        refresh()
    end)

    -- Zone filter, in the title band.
    -- Small enough to sit inside the title band, between its edges.
    filterButton = makeButton(panel, 92, 15, "")
    filterButton:SetPoint("RIGHT", panel, "TOPRIGHT", -12, -14)
    filterButton:SetScript("OnClick", function()
        settings.questLogZoneOnly = not settings.questLogZoneOnly
        page = 1
        refresh()
    end)
    tooltip(filterButton, "Zone filter", "Show every quest, or only quests filed under your current zone.")

    -- List area: dark, warm inset with a gold edge.
    local listR, listG, listB, listA = WalkMapUI.ListColor()
    local accentR, accentG, accentB = WalkMapUI.Accent()
    panel.listBg = fill(panel, "BACKGROUND", listR, listG, listB, listA)
    panel.listEdge = fill(panel, "BORDER", accentR, accentG, accentB, 0.45)
    panel.listEdge:SetHeight(1)
    panel.emptyText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.emptyText:SetPoint("TOP", panel, "TOP", 0, -48)
    panel.emptyText:SetTextColor(0.85, 0.78, 0.6)

    -- Detail area: parchment, with the text in a clipped scroll frame.
    panel.paper = panel:CreateTexture(nil, "BACKGROUND")
    if panel.paper:SetTexture("Interface\\QuestFrame\\QuestBG") == false then
        panel.paper:SetColorTexture(0.86, 0.78, 0.6, 1)
    else
        panel.paper:SetTexCoord(0, 0.586, 0, 0.66)
    end
    panel.paperEdge = fill(panel, "BORDER", 0.45, 0.32, 0.15, 0.9)
    panel.paperEdge:SetHeight(2)
    panel.paperEdge:SetPoint("BOTTOMLEFT", panel.paper, "TOPLEFT", 0, 0)
    panel.paperEdge:SetPoint("BOTTOMRIGHT", panel.paper, "TOPRIGHT", 0, 0)

    local scroll = CreateFrame("ScrollFrame", nil, panel)
    scroll:SetPoint("TOPLEFT", panel.paper, "TOPLEFT", 12, -10)
    scroll:SetPoint("BOTTOMRIGHT", panel.paper, "BOTTOMRIGHT", -ACTION_COLUMN, 8)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        setScroll((scroll:GetVerticalScroll() or 0) - delta * 40)
        updateFullButton()
    end)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(PANEL_WIDTH - 16 - 12 - ACTION_COLUMN, 400)
    scroll:SetScrollChild(content)
    detail.scroll, detail.content = scroll, content
    local width = content:GetWidth()

    detail.title = content:CreateFontString(nil, "OVERLAY", TITLE_FONT)
    detail.title:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -2)
    detail.title:SetWidth(width)
    detail.title:SetJustifyH("LEFT")
    detail.title:SetWordWrap(true)
    ink(detail.title, INK)
    detail.tag = content:CreateFontString(nil, "OVERLAY", SMALL_FONT)
    detail.tag:SetPoint("TOPLEFT", detail.title, "BOTTOMLEFT", 0, -2)
    detail.tag:SetWidth(width)
    detail.tag:SetJustifyH("LEFT")
    ink(detail.tag, INK_TAG)
    detail.lines = {}
    for i = 1, 10 do
        local line = content:CreateFontString(nil, "OVERLAY", BODY_FONT)
        line:SetWidth(width)
        line:SetJustifyH("LEFT")
        line:SetWordWrap(true)
        ink(line, INK)
        detail.lines[i] = line
    end
    detail.rewardTitle = content:CreateFontString(nil, "OVERLAY", TITLE_FONT)
    detail.rewardTitle:SetText("Rewards")
    ink(detail.rewardTitle, INK)
    detail.rewardLine = content:CreateFontString(nil, "OVERLAY", BODY_FONT)
    detail.rewardLine:SetWidth(width)
    detail.rewardLine:SetJustifyH("LEFT")
    ink(detail.rewardLine, INK_SOFT)
    detail.items = {}
    for i = 1, 8 do
        local item = CreateFrame("Button", nil, content)
        item:SetSize(22, 22)
        item.icon = item:CreateTexture(nil, "ARTWORK")
        item.icon:SetAllPoints(item)
        item.count = item:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        item.count:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", 1, 0)
        item:SetPoint("LEFT", content, "LEFT", (i - 1) * 25, 0)
        item:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if not (GameTooltip.SetQuestLogItem and pcall(GameTooltip.SetQuestLogItem, GameTooltip, self.kind, self.index)) then
                GameTooltip:SetText(self.name or "")
            end
            if self.kind == "choice" then GameTooltip:AddLine("Choose one", 0.7, 0.8, 1) end
            GameTooltip:Show()
        end)
        item:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        detail.items[i] = item
    end
    detail.text = content:CreateFontString(nil, "OVERLAY", BODY_FONT)
    detail.text:SetWidth(width)
    detail.text:SetJustifyH("LEFT")
    detail.text:SetJustifyV("TOP")
    detail.text:SetWordWrap(true)
    ink(detail.text, INK_SOFT)

    local function action(index, text, onClick)
        local button = makeButton(panel, 86, 22, text)
        button:SetPoint("TOPRIGHT", panel.paper, "TOPRIGHT", -10, -10 - (index - 1) * 27)
        button:SetScript("OnClick", function()
            local entry = selectedEntry()
            if entry then onClick(entry) end
        end)
        -- Native focus calls OnEnter: remember that focus is on the buttons.
        button:HookScript("OnEnter", function() panel.walkmapFocusArea = "actions" end)
        actions[#actions + 1] = button
        return button
    end
    actions.focus = action(1, "Focus", function(entry)
        WalkMapExtras.SetQuestFocus(WalkMapExtras.QuestFocus() ~= entry.id and entry.id or nil)
        refresh()
    end)
    actions.track = action(2, "Track", function(entry)
        setTracked(entry, not isTracked(entry))
        refresh()
    end)
    tooltip(actions.track, function(self) return self.label:GetText() or "Track" end, function()
        if trackerOn() then
            return "Show or hide this quest in WalkMap's quest tracker and on the maps. Right-click a quest in the tracker also removes it."
        end
        return "Add this quest to, or remove it from, the game's quest tracker."
    end)
    actions.map = action(3, "Show on map", function(entry)
        local mapID = questMap(entry)
        if not mapID or not WalkMapMaps then return end
        WalkMapMaps.Choose(mapID ~= WalkMapMaps.CurrentZone() and mapID or nil)
        -- Pulse this quest's markers until the log closes or another quest
        -- is chosen (WalkMap.lua).
        if WalkMapPinHighlight then WalkMapPinHighlight.Set(entry.id) end
    end)
    tooltip(actions.map, "Show on map", function(self)
        return self.reason or "Open the zone with this quest's known locations and make its markers pulse."
    end)
    actions.full = action(4, "Full text", function()
        if not fullText then
            fullText = true
            refresh()
            setScroll(0)
        else
            -- More text below: scroll a page. At the end: back to the list.
            local current = detail.scroll:GetVerticalScroll() or 0
            local maxScroll = math.max(0, (detail.contentHeight or 0) - detail.scroll:GetHeight())
            if current >= maxScroll - 1 then
                fullText = false
                refresh()
            else
                setScroll(current + detail.scroll:GetHeight() - 30)
            end
        end
        updateFullButton()
    end)
    tooltip(actions.full, "Full text", "Show the whole description. Press again to read further, then to go back.")
    actions.share = action(5, "Share", function(entry)
        if InCombatLockdown and InCombatLockdown() then return end
        selectQuest(entry)
        if QuestLogPushQuest then call(QuestLogPushQuest) end
    end)
    tooltip(actions.share, "Share", function(self) return self.reason end)
    -- The same as Shift-click on the quest, for the controller.
    actions.link = action(6, "Link", function(entry)
        if WalkMapQuestInfo and WalkMapQuestInfo.LinkToChat then WalkMapQuestInfo.LinkToChat(entry.id) end
    end)
    tooltip(actions.link, "Link", "Put this quest into the chat line. If the chat line is closed, open it within 30 seconds and the quest is put in. Shift-click on a quest does the same.")
    -- Confirm inside the button: opening the game's popup from WalkMap moved
    -- controller focus through tainted code and the client blocked
    -- SetPreferredGamepadInteractTarget. First press arms, second abandons.
    local ABANDON_WINDOW = 4
    actions.abandon = action(7, "Abandon", function(entry)
        local button = actions.abandon
        local now = GetTime and GetTime() or 0
        if button.armedID ~= entry.id or now > (button.armedUntil or 0) then
            button.armedID, button.armedUntil = entry.id, now + ABANDON_WINDOW
            button.label:SetText("Confirm?")
            button.label:SetTextColor(1, 0.45, 0.35)
            if C_Timer and C_Timer.After then
                C_Timer.After(ABANDON_WINDOW, function()
                    if button.armedID == entry.id and (GetTime and GetTime() or 0) >= (button.armedUntil or 0) then
                        button.armedID = nil
                        button.label:SetText("Abandon")
                        button.label:SetTextColor(1, 1, 1)
                    end
                end)
            end
            return
        end
        button.armedID = nil
        button.label:SetText("Abandon")
        button.label:SetTextColor(1, 1, 1)
        selectQuest(entry)
        if C_QuestLog.SetAbandonQuest then call(C_QuestLog.SetAbandonQuest)
        elseif SetAbandonQuest then call(SetAbandonQuest) end
        if C_QuestLog.AbandonQuest then call(C_QuestLog.AbandonQuest)
        elseif AbandonQuest then call(AbandonQuest) end
    end)
    tooltip(actions.abandon, "Abandon", "Press twice within 4 seconds to abandon this quest.")

    rows, headers = {}, {}
    pager = CreateFrame("Frame", nil, panel)
    pager:SetSize(150, 18)
    pager.label = pager:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pager.label:SetPoint("CENTER")
    pager.label:SetTextColor(0.85, 0.78, 0.6)
    local function arrow(direction)
        local button = CreateFrame("Button", nil, pager)
        button:SetSize(16, 16)
        button.icon = arrowTexture(button, 16)
        button.icon:SetAllPoints(button)
        if direction < 0 then button.icon:SetTexCoord(1, 0, 0, 1) end
        local glow = button:CreateTexture(nil, "HIGHLIGHT")
        glow:SetAllPoints(button)
        glow:SetColorTexture(1, 0.8, 0.3, 0.25)
        button:SetPoint(direction < 0 and "LEFT" or "RIGHT", pager, direction < 0 and "LEFT" or "RIGHT")
        button:SetScript("OnClick", function() log.Page(direction) end)
        return button
    end
    pager.prev, pager.next = arrow(-1), arrow(1)
    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel", function(_, delta) log.Page(delta > 0 and -1 or 1) end)

    panel.categories, panel.options = {}, actions
    -- B: from the buttons (or Full text) back to the last selected quest;
    -- only from the list does B close the quest log.
    -- True when controller focus is on one of the quest's buttons. The
    -- remembered area can be wrong: after Abandon the list moves, and a row
    -- that slides under a resting mouse pointer reports "list". So the
    -- button the controller is really on decides when it is known.
    local function onActionButtons()
        local native = WalkMapNativeController
        if native and native.IsSelecting then
            for _, button in ipairs(actions) do
                if button:IsShown() and native.IsSelecting(button) then return true end
            end
        end
        return panel.walkmapFocusArea == "actions"
    end
    panel.walkmapOnBack = function()
        if fullText then
            fullText = false
            refresh()
        elseif not onActionButtons() then
            return false
        end
        panel.walkmapFocusArea = "list"
        -- Back to the selected quest; if it is not on this page (or was just
        -- abandoned), to the first quest on the page.
        local row = panel.walkmapSelectedRow
        if not (row and row:IsShown()) then
            row = nil
            for _, item in ipairs(panel.walkmapListItems or {}) do
                if item.questID and item:IsShown() then row = item break end
            end
        end
        if row and WalkMapNativeController and WalkMapNativeController.FocusButton then
            WalkMapNativeController.FocusButton(panel, row)
            return true
        end
        return false
    end
    panel:SetScript("OnShow", function() refresh() end)
    panel:SetScript("OnSizeChanged", function() if panel:IsShown() then refresh() end end)
    panel:HookScript("OnHide", function()
        fullText = false
        updateTab()
    end)

    -- Toolbar button (placed by WalkMapExtras.Resize at the toolbar's end).
    tab = CreateFrame("Button", "WalkMapQuestLogTab", owner)
    tab:SetFrameLevel(owner:GetFrameLevel() + 4)
    tab:EnableMouse(true)
    WalkMapExtras.StyleButton(tab)
    tab.icon = tab:CreateTexture(nil, "OVERLAY")
    tab.icon:SetSize(16, 16)
    tab.icon:SetPoint("CENTER")
    tab.icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    tab.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    tab.lit = fill(tab, "ARTWORK", 1, 0.8, 0.3, 0.22)
    tab.lit:SetPoint("TOPLEFT", tab, "TOPLEFT", 3, -3)
    tab.lit:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -3, 3)
    tab:SetScript("OnClick", function() setShown(not panel:IsShown()) end)
    -- The book and the log work with the mouse in combat too.
    panel.walkmapCombatPanel = true
    if WalkMapCombat and WalkMapCombat.AllowInCombat then WalkMapCombat.AllowInCombat(tab) end
    tooltip(tab, function() return panel:IsShown() and "Hide quest log" or "Quest log" end)
    updateTab()

    if WalkMapNativeController and WalkMapNativeController.WatchPanel then
        WalkMapNativeController.WatchPanel(panel, tab)
    end
end

-- Keep "last selected quest" routes in step with the selection: Left from
-- the buttons, B from the buttons and reopening all land on it.
local function updateSelectionRoutes()
    if not panel then return end
    local selectedRow
    for _, item in ipairs(panel.walkmapListItems or {}) do
        if item.questID and item.questID == selectedID then selectedRow = item end
    end
    panel.walkmapSelectedRow = selectedRow
    -- Left anywhere in the log goes to the map's quest log button
    -- (ControllerNative); B from the buttons returns to this row.
    panel.walkmapRouteOverrides = nil
    panel.walkmapNativeFirstButton = fullText and actions.full or selectedRow
        or (panel.walkmapListItems or {})[1] or filterButton
end

local function paintRow(row)
    local selected = row.questID ~= nil and row.questID == selectedID
    row.bar:SetShown(row.hovered == true or selected)
    row.accent:SetShown(selected)
end

-- Is the mouse really being used on this row? With controller focus on the
-- quest log the pointer is often hidden and just resting over a row, so
-- "the mouse is over it" is not enough: it must also have moved just now.
local mouseX, mouseY, mouseMovedAt = nil, nil, -100
local function trackMouse()
    local x, y = GetCursorPosition()
    if x ~= mouseX or y ~= mouseY then
        -- The first reading only records where the pointer rests.
        if mouseX then mouseMovedAt = GetTime and GetTime() or 0 end
        mouseX, mouseY = x, y
    end
end
local function mouseUsedOn(row)
    if not (row.IsMouseOver and row:IsMouseOver()) then return false end
    trackMouse()
    return (GetTime and GetTime() or 0) - mouseMovedAt < 1.5
end

local function rowFor(i)
    local row = rows[i]
    if row then return row end
    -- The panel exists by now; follow the mouse while it is open.
    if not panel.walkmapMouseTracked then
        panel.walkmapMouseTracked = true
        panel:HookScript("OnUpdate", trackMouse)
        panel:HookScript("OnShow", function() mouseX, mouseY, mouseMovedAt = nil, nil, -100 end)
    end
    row = CreateFrame("Button", nil, panel)
    row:SetHeight(ROW_HEIGHT)
    row:EnableMouse(true)
    row.bar = fill(row, "BACKGROUND", 1, 0.76, 0.28, 0.16)
    row.bar:SetAllPoints(row)
    row.accent = fill(row, "BORDER", 1, 0.82, 0.3, 0.95)
    row.accent:SetWidth(2)
    row.accent:SetPoint("TOPLEFT", row, "TOPLEFT")
    row.accent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT")
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetPoint("LEFT", row, "LEFT", 18, 0)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)
    row.detail = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.detail:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.detail:SetJustifyH("RIGHT")
    row.label:SetPoint("RIGHT", row.detail, "LEFT", -6, 0)
    row.mark = row:CreateTexture(nil, "OVERLAY")
    row.mark:SetSize(11, 11)
    row.mark:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.mark:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
    -- Mouse hover and controller focus both preview the quest.
    row:SetScript("OnEnter", function(self)
        panel.walkmapFocusArea = "list"
        self.hovered = true
        -- Controller focus selects, so the action buttons apply to it; mouse
        -- hover only previews, also while controller focus is on the quest
        -- log (moving the mouse down to the buttons must not change the
        -- quest you clicked).
        local pad = WalkMapNativeController and WalkMapNativeController.PadFocused
            and WalkMapNativeController.PadFocused()
        if not mouseUsedOn(self) and (pad or not (self.IsMouseOver and self:IsMouseOver()))
            and selectedID ~= self.questID then
            selectedID = self.questID
            for _, other in ipairs(rows) do paintRow(other) end
            updateSelectionRoutes()
            if WalkMapNativeController and WalkMapNativeController.RequestRefresh then
                WalkMapNativeController.RequestRefresh()
            end
        end
        paintRow(self)
        showDetail(self.questID)
    end)
    row:SetScript("OnLeave", function(self)
        self.hovered = false
        paintRow(self)
        showDetail(selectedID)
    end)
    row:SetScript("OnClick", function(self)
        -- Shift-click links the quest in chat and leaves the selection alone.
        if WalkMapQuestInfo and WalkMapQuestInfo.LinkClick(self.questID) then return end
        selectedID = self.questID
        for _, other in ipairs(rows) do paintRow(other) end
        updateSelectionRoutes()
        if WalkMapNativeController and WalkMapNativeController.RequestRefresh then
            WalkMapNativeController.RequestRefresh()
        end
        showDetail(selectedID)
        -- Controller A: jump to the action buttons. A mouse click on the row
        -- stays put. The hidden mouse pointer may rest over a row while the
        -- controller is used, so the controller's focus decides first.
        local pad = WalkMapNativeController and WalkMapNativeController.PadFocused
            and WalkMapNativeController.PadFocused()
        if not mouseUsedOn(self) and (pad or not (self.IsMouseOver and self:IsMouseOver()))
            and actions.focus:IsShown()
            and WalkMapNativeController and WalkMapNativeController.FocusButton then
            WalkMapNativeController.FocusButton(panel, actions.focus)
        end
    end)
    rows[i] = row
    return row
end

-- Zone headers are buttons: A/click folds the zone in or out.
local function headerFor(i)
    local header = headers[i]
    if header then return header end
    header = CreateFrame("Button", nil, panel)
    header:SetHeight(ROW_HEIGHT)
    header:EnableMouse(true)
    header.bar = fill(header, "BACKGROUND", 1, 0.76, 0.28, 0.12)
    header.bar:SetAllPoints(header)
    header.bar:Hide()
    header.arrow = arrowTexture(header, 11)
    header.arrow:SetPoint("LEFT", header, "LEFT", 2, 0)
    header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header.text:SetPoint("LEFT", header.arrow, "RIGHT", 4, 0)
    header.text:SetJustifyH("LEFT")
    header.count = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    header.count:SetPoint("RIGHT", header, "RIGHT", -6, 0)
    header.count:SetTextColor(0.85, 0.78, 0.6)
    local accentR, accentG, accentB = WalkMapUI.Accent()
    header.line = fill(header, "ARTWORK", accentR, accentG, accentB, 0.35)
    header.line:SetHeight(1)
    header.line:SetPoint("LEFT", header.text, "RIGHT", 8, 0)
    header.line:SetPoint("RIGHT", header.count, "LEFT", -6, 0)
    header:SetScript("OnEnter", function(self) self.bar:Show() end)
    header:SetScript("OnLeave", function(self) self.bar:Hide() end)
    header:SetScript("OnClick", function(self)
        local key = self.zone or ""
        settings.questLogCollapsed[key] = not settings.questLogCollapsed[key] or nil
        refresh()
    end)
    headers[i] = header
    return header
end

local function layoutContent(entry, full)
    local width = detail.content:GetWidth()
    local y = 2
    local function place(region, gap)
        region:ClearAllPoints()
        region:SetPoint("TOPLEFT", detail.content, "TOPLEFT", 0, -(y + (gap or 0)))
        y = y + (gap or 0) + (region.GetStringHeight and region:GetStringHeight() or region:GetHeight() or 0)
    end
    place(detail.title)
    if detail.tag:GetText() and detail.tag:GetText() ~= "" then place(detail.tag, 1) end
    for _, line in ipairs(detail.lines) do
        if line:GetText() and line:GetText() ~= "" then place(line, 4) end
    end
    if detail.hasRewards then
        place(detail.rewardTitle, 10)
        if detail.rewardLine:GetText() and detail.rewardLine:GetText() ~= "" then place(detail.rewardLine, 2) end
        local shown = 0
        for _, item in ipairs(detail.items) do
            if item:IsShown() then
                shown = shown + 1
                item:ClearAllPoints()
                item:SetPoint("TOPLEFT", detail.content, "TOPLEFT", (shown - 1) * 25, -(y + 4))
            end
        end
        if shown > 0 then y = y + 4 + 22 end
    end
    place(detail.text, 10)
    detail.contentHeight = y + 6
    detail.content:SetSize(width, math.max(detail.contentHeight, 10))
end

showDetail = function(questID)
    local entry = entryByID(questID)
    for _, button in ipairs(actions) do button:SetShown(entry ~= nil and entry.id == selectedID) end
    for _, item in ipairs(detail.items) do item:Hide() end
    detail.hasRewards = false
    if not entry then
        detail.title:SetText(#entries == 0 and "Your quest log is empty." or "Choose a quest.")
        detail.tag:SetText("")
        for _, line in ipairs(detail.lines) do line:SetText("") end
        detail.text:SetText("")
        layoutContent(nil, fullText)
        return
    end
    detail.title:SetText(entry.title)
    local tagParts = {}
    if type(entry.level) == "number" and entry.level > 0 then tagParts[#tagParts + 1] = "Level " .. entry.level end
    if entry.tag then tagParts[#tagParts + 1] = entry.tag end
    detail.tag:SetText(table.concat(tagParts, "  -  "))
    local used = 0
    for _, objective in ipairs(entry.objectives or {}) do
        if used >= #detail.lines then break end
        used = used + 1
        detail.lines[used]:SetText("- " .. tostring(objective.text or ""))
        local color = objective.finished and INK_DONE or INK
        detail.lines[used]:SetTextColor(color[1], color[2], color[3])
    end
    if used == 0 then
        used = 1
        detail.lines[1]:SetText(entry.complete and "Ready to turn in." or "No objectives listed.")
        local color = entry.complete and INK_DONE or INK
        detail.lines[1]:SetTextColor(color[1], color[2], color[3])
    end
    for i = used + 1, #detail.lines do detail.lines[i]:SetText("") end

    local reward = rewards(entry)
    local parts = {}
    if reward.xp then parts[#parts + 1] = reward.xp .. " XP" end
    if reward.money then parts[#parts + 1] = moneyText(reward.money) end
    detail.rewardLine:SetText(table.concat(parts, "   "))
    for i, item in ipairs(reward.items) do
        local button = detail.items[i]
        button.kind, button.index, button.name = item.kind, item.index, item.name
        button.icon:SetTexture(item.texture)
        button.count:SetText(type(item.count) == "number" and item.count > 1 and item.count or "")
        button:Show()
    end
    detail.hasRewards = #parts > 0 or #reward.items > 0

    local description, summary = questText(entry)
    if fullText then
        -- Whole quest text: the objective summary, then the full story.
        local text = tostring(summary or "")
        if description and description ~= "" then
            text = text .. (text ~= "" and "\n\n" or "") .. tostring(description)
        end
        detail.text:SetText(text)
    else
        detail.text:SetText(tostring(summary or description or ""))
    end
    layoutContent(entry, fullText)
    if not fullText then setScroll(0) end
    updateFullButton()

    if entry.id ~= selectedID then return end
    if actions.abandon.armedID and actions.abandon.armedID ~= entry.id then
        actions.abandon.armedID = nil
        actions.abandon.label:SetText("Abandon")
        actions.abandon.label:SetTextColor(1, 1, 1)
    end
    actions.track.label:SetText(isTracked(entry) and "Untrack" or "Track")
    actions.focus.label:SetText(WalkMapExtras.QuestFocus() == entry.id and "Unfocus" or "Focus")
    local mapID = questMap(entry)
    actions.map:SetEnabled(mapID ~= nil)
    actions.map.label:SetTextColor(mapID and 1 or 0.5, mapID and 1 or 0.5, mapID and 1 or 0.5)
    actions.map.reason = not mapID and "No known location or zone for this quest." or nil
    local shareable, reason = shareState(entry)
    actions.share:SetEnabled(shareable)
    actions.share.label:SetTextColor(shareable and 1 or 0.5, shareable and 1 or 0.5, shareable and 1 or 0.5)
    actions.share.reason = shareable and "Offer this quest to your group." or reason
end

refresh = function()
    if not panel or not panel:IsShown() then return end
    entries = readLog()
    local quests = 0
    for _, entry in ipairs(entries) do if entry.id then quests = quests + 1 end end
    local maxQuests = (C_QuestLog.GetMaxNumQuestsCanAccept and C_QuestLog.GetMaxNumQuestsCanAccept())
        or MAX_QUESTLOG_QUESTS or 20
    panel.count:SetText(quests .. "/" .. maxQuests)
    filterButton.label:SetText(settings.questLogZoneOnly and "This zone" or "All zones")
    if settings.questLogZoneOnly then filterButton.label:SetTextColor(0.4, 1, 0.8)
    else filterButton.label:SetTextColor(1, 1, 1) end
    visible = visibleEntries()
    if not selectedEntry() then
        selectedID = nil
        local focus = WalkMapExtras.QuestFocus()
        for _, entry in ipairs(visible) do
            if entry.id and (entry.id == focus or not selectedID) then selectedID = entry.id end
        end
    end

    local height = panel:GetHeight() or 400
    local paperHeight = fullText and (height - 30 - 8) or math.max(220, math.min(320, math.floor(height * 0.45)))
    panel.paper:ClearAllPoints()
    panel.paper:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 8, 8)
    panel.paper:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 8)
    panel.paper:SetHeight(paperHeight)
    local listBottom = paperHeight + 8 + 6
    panel.listBg:ClearAllPoints()
    panel.listBg:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -30)
    panel.listBg:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, listBottom)
    panel.listEdge:ClearAllPoints()
    panel.listEdge:SetPoint("TOPLEFT", panel.listBg, "TOPLEFT")
    panel.listEdge:SetPoint("TOPRIGHT", panel.listBg, "TOPRIGHT")
    panel.listBg:SetShown(not fullText)
    panel.listEdge:SetShown(not fullText)
    filterButton:SetShown(not fullText)

    local listHeight = height - 30 - listBottom - 6
    local capacity = math.max(3, math.floor((listHeight - 4) / ROW_HEIGHT))
    pages = math.max(1, math.ceil(#visible / capacity))
    if pages > 1 then
        capacity = math.max(3, math.floor((listHeight - 28) / ROW_HEIGHT))
        pages = math.max(1, math.ceil(#visible / capacity))
    end
    if pendingQuest then
        for index, entry in ipairs(visible) do
            if entry.id == pendingQuest then
                selectedID = pendingQuest
                page = math.floor((index - 1) / capacity) + 1
            end
        end
        pendingQuest = nil
    end
    if page > pages then page = pages end
    local first = (page - 1) * capacity + 1
    local rowCount, headerCount = 0, 0
    panel.categories = {}
    if not fullText then panel.categories[1] = filterButton end
    local focus = WalkMapExtras.QuestFocus()
    local counts = {}
    for _, entry in ipairs(entries) do
        if entry.id then counts[entry.zone or ""] = (counts[entry.zone or ""] or 0) + 1 end
    end
    for slot = 0, fullText and -1 or capacity - 1 do
        local entry = visible[first + slot]
        if not entry then break end
        local y = -34 - slot * ROW_HEIGHT
        if entry.header then
            headerCount = headerCount + 1
            local header = headerFor(headerCount)
            header:ClearAllPoints()
            header:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, y)
            header:SetPoint("RIGHT", panel, "RIGHT", -12, 0)
            header.zone = entry.title
            local collapsed = settings.questLogCollapsed[entry.title] == true
            header.text:SetText(entry.title .. (entry.gameCollapsed and "  (collapsed in game)" or ""))
            header.count:SetText(collapsed and tostring(counts[entry.title] or 0) or "")
            -- Arrow points right when folded in, down when open.
            if header.arrow.SetRotation then header.arrow:SetRotation(collapsed and 0 or -math.pi / 2) end
            header:Show()
            panel.categories[#panel.categories + 1] = header
        else
            rowCount = rowCount + 1
            local row = rowFor(rowCount)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, y)
            row:SetPoint("RIGHT", panel, "RIGHT", -12, 0)
            row.questID = entry.id
            row.hovered = false
            row.label:SetText(entry.title .. (entry.tag and ("  |cffff9966" .. entry.tag .. "|r") or ""))
            local r, g, b = levelColor(entry.level, entry.id)
            row.label:SetTextColor(r, g, b)
            local xpText = WalkMapQuestInfo and WalkMapQuestInfo.XPText(entry.id) or ""
            if xpText ~= "" then xpText = xpText .. "   " end
            if entry.complete then
                row.detail:SetText(xpText .. "|cff80f280Done|r")
                row.detail:SetTextColor(0.5, 0.95, 0.5)
            else
                local progress = entry.total > 0 and (entry.done .. "/" .. entry.total .. "   ") or ""
                local level = type(entry.level) == "number" and entry.level > 0 and tostring(entry.level) or ""
                row.detail:SetText(xpText .. "|cffbfb38a" .. progress .. "|r" .. level)
                row.detail:SetTextColor(0.85, 0.78, 0.6)
            end
            row.mark:SetShown(entry.id == focus)
            paintRow(row)
            row:Show()
            panel.categories[#panel.categories + 1] = row
        end
    end
    for i = rowCount + 1, #rows do rows[i]:Hide() end
    for i = headerCount + 1, #headers do headers[i]:Hide() end
    panel.emptyText:SetShown(not fullText and #visible == 0)
    panel.emptyText:SetText(settings.questLogZoneOnly and "No quests filed under this zone." or "Your quest log is empty.")

    pager:ClearAllPoints()
    pager:SetPoint("BOTTOM", panel.listBg, "BOTTOM", 0, 4)
    pager:SetShown(not fullText and pages > 1)
    pager.label:SetText(string.format("Page %d/%d", page, pages))
    pager.prev:SetEnabled(page > 1)
    pager.prev:SetAlpha(page > 1 and 1 or 0.3)
    pager.next:SetEnabled(page < pages)
    pager.next:SetAlpha(page < pages and 1 or 0.3)
    -- Controller paging: Down on the last item / Up on the first item.
    local listItems = {}
    for _, item in ipairs(panel.categories) do
        if item ~= filterButton then listItems[#listItems + 1] = item end
    end
    panel.walkmapListItems = listItems
    updateSelectionRoutes()
    panel.walkmapPages = (not fullText) and pages or 1
    panel.walkmapPageEdges = (not fullText) and {
        first = page > 1 and listItems[1] or nil,
        last = page < pages and listItems[#listItems] or nil,
    } or nil

    -- Controller focus enters on the selected quest (or Full text button).

    showDetail(selectedID)
    if WalkMapNativeController and WalkMapNativeController.RequestRefresh then
        WalkMapNativeController.RequestRefresh()
    end
end

-- Change page; after a controller move, focus lands on the new page: on its
-- first or last row after Up/Down past the list's edge, or on the same row
-- number (keepRow) after Left/Right. With wrap, going past the last page
-- continues on the first and the other way round.
function log.Page(direction, focusEdge, keepRow, wrap)
    if not panel or not panel:IsShown() or fullText then return false end
    local target = page + direction
    if wrap and pages > 1 then
        if target < 1 then target = pages elseif target > pages then target = 1 end
    end
    if target < 1 or target > pages then return false end
    page = target
    refresh()
    if focusEdge and WalkMapNativeController and WalkMapNativeController.FocusButton then
        local list = panel.walkmapListItems or {}
        local button = direction > 0 and list[1] or list[#list]
        if type(keepRow) == "number" then button = list[math.max(1, math.min(#list, keepRow))] end
        if button then WalkMapNativeController.FocusButton(panel, button) end
    end
    return true
end
function log.PageNumber() return page, pages end

function log.Tab() return tab end
function log.Refresh() if panel and panel:IsShown() and refresh then refresh() end end
function log.SelectedID() return selectedID end
function log.Panel() return panel end
function log.Toggle() if panel then setShown(not panel:IsShown()) end end
function log.IsOpen() return panel ~= nil and panel:IsShown() end
-- Open the map and quest log with one quest selected (zone tracker clicks).
function log.OpenQuest(questID)
    pendingQuest = questID
    if panel and panel:IsShown() then refresh() return end
    log.Open()
end

-- Open the map with the quest log folded out (quest log key).
local openingWithLog = false
function log.Open()
    if WalkMapCombat and WalkMapCombat.Locked() then return end
    openingWithLog = true
    if not owner:IsShown() and WalkMap_Toggle then WalkMap_Toggle() end
    openingWithLog = false
    if panel and not panel:IsShown() then setShown(true) end
end

-- The map always opens with the quest log closed (M, the WalkMap key, the
-- minimap button...). Only the quest log key (L) opens both.
owner:HookScript("OnShow", function()
    if openingWithLog or not panel or not panel:IsShown() then return end
    if WalkMapCombat and WalkMapCombat.Locked() then return end
    setShown(false)
end)

-- ---------------------------------------------------------
-- Opt-in: the game's world map and quest log keys open WalkMap.
-- Private override bindings only; the player's key bindings are untouched.
-- ---------------------------------------------------------
local keyOwner = CreateFrame("Frame", "WalkMapGameKeyOverrides", UIParent)
local keyStatus, appliedKeys = "off", nil

-- Secure like WalkMapKeyboardToggle: in combat it toggles the map.
local questKey = CreateFrame("Button", "WalkMapQuestLogKey", UIParent, "SecureHandlerClickTemplate")
questKey:RegisterForClicks("AnyUp")
questKey:Hide()
local function prepareQuestKey()
    local header = _G.WalkMapCombatBindings
    if questKey.prepared or not header or (InCombatLockdown and InCombatLockdown()) then return end
    if not WalkMapCombat.Free() then questKey:SetFrameRef("map", owner) end
    questKey:SetFrameRef("combat-controls", header)
    questKey:SetAttribute("_onclick", [[
        local controls = self:GetFrameRef("combat-controls")
        local map = self:GetFrameRef("map")
        if controls and controls:GetAttribute("state-combat") == "combat" and map then
            if map:IsShown() then map:Hide() else map:Show() end
        end
    ]])
    questKey.prepared = true
end
questKey:HookScript("OnClick", function()
    if WalkMapCombat and WalkMapCombat.FrameLocked() then return end
    if owner:IsShown() and panel and panel:IsShown() then
        if WalkMap_Toggle then WalkMap_Toggle() end
    else
        log.Open()
    end
end)

local function keysFor(action)
    local list = {}
    if GetBindingKey then
        for _, key in ipairs({GetBindingKey(action)}) do
            if type(key) == "string" and key ~= "" then list[#list + 1] = key end
        end
    end
    return list
end

local function applyKeys()
    if InCombatLockdown and InCombatLockdown() then return end
    local wanted = WalkMapExtras.UseGameMapKeys()
    local mapKeys = wanted and keysFor("TOGGLEWORLDMAP") or {}
    local questKeys = wanted and keysFor("TOGGLEQUESTLOG") or {}
    local signature = table.concat(mapKeys, ",") .. "|" .. table.concat(questKeys, ",")
    if signature == appliedKeys then return end
    if ClearOverrideBindings then ClearOverrideBindings(keyOwner) end
    appliedKeys = signature
    if not wanted then keyStatus = "off" return end
    if not SetOverrideBindingClick then keyStatus = "override API unavailable" return end
    prepareQuestKey()
    for _, key in ipairs(mapKeys) do
        SetOverrideBindingClick(keyOwner, false, key, "WalkMapKeyboardToggle", "LeftButton")
    end
    for _, key in ipairs(questKeys) do
        SetOverrideBindingClick(keyOwner, false, key, "WalkMapQuestLogKey", "LeftButton")
    end
    keyStatus = "map " .. (#mapKeys > 0 and table.concat(mapKeys, "/") or "none")
        .. ", quest log " .. (#questKeys > 0 and table.concat(questKeys, "/") or "none")
end
function log.KeyStatus() return keyStatus end

-- The gamepad wheel's "Quest & Maps" (and anything else that opens the
-- game's map or quest log) cannot be rebound. With the setting on, WalkMap
-- closes the game's window right after it opens and opens WalkMap with its
-- quest log instead. Out of combat only; in combat the game's map stays.
local interceptCount, lastIntercept = 0, 0
-- True while WalkMap is closing the game's window. Closing it from addon
-- code can make the game refuse SetPreferredGamepadInteractTarget (the
-- gamepad bar's interact icon); that is not a controller-navigation failure.
local closingGameWindow, interceptBlocks = false, 0
function log.Intercepting() return closingGameWindow end
function log.InterceptBlocked() interceptBlocks = interceptBlocks + 1 end
local function intercept(frame, isQuestLog)
    if not frame or frame.walkmapIntercept then return end
    frame.walkmapIntercept = true
    frame:HookScript("OnShow", function(self)
        if not WalkMapExtras.UseGameMapKeys() then return end
        if (InCombatLockdown and InCombatLockdown()) or (WalkMapCombat and WalkMapCombat.Locked()) then return end
        -- Pressing Quest & Maps (or M/L) while WalkMap is open closes it.
        local wasOpen = owner:IsShown()
        -- Invisible at once, so the game's map never appears; it is closed
        -- on the next frame and gets its normal opacity back once hidden.
        local alpha = self:GetAlpha()
        pcall(self.SetAlpha, self, 0)
        local function swap()
            if InCombatLockdown and InCombatLockdown() then
                pcall(self.SetAlpha, self, alpha > 0 and alpha or 1)
                return
            end
            local function closeGameWindow()
                if self:IsShown() then
                    closingGameWindow = true
                    if HideUIPanel then pcall(HideUIPanel, self) end
                    if self:IsShown() then pcall(self.Hide, self) end
                    closingGameWindow = false
                end
                pcall(self.SetAlpha, self, alpha > 0 and alpha or 1)
            end
            closeGameWindow()
            interceptCount, lastIntercept = interceptCount + 1, GetTime and GetTime() or 0
            if wasOpen then
                if owner:IsShown() and WalkMap_Toggle then WalkMap_Toggle() end
                return
            end
            -- The game's quest log always brings WalkMap's; the world map
            -- (wheel's Quest & Maps) follows "Wheel opens quest log too".
            if isQuestLog or WalkMapExtras.WheelOpensQuestLog() then
                log.Open()
            elseif not owner:IsShown() and WalkMap_Toggle then
                WalkMap_Toggle()
            end
        end
        -- Let the opening finish first. The game's quest map also defers a
        -- gamepad focus step (QuestMapFrame -> WorldMapFrame:FocusMap); if
        -- the map is already closed then, Blizzard's SoftCursor errors with
        -- "inX (a nil value)". So wait a frame, then a little more.
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function() C_Timer.After(0.1, swap) end)
        else
            swap()
        end
    end)
end
local function interceptAll()
    intercept(_G.WorldMapFrame, false)
    intercept(_G.QuestLogFrame, true)
end
function log.InterceptStatus()
    return "game map/quest log hooked: " .. tostring(_G.WorldMapFrame and _G.WorldMapFrame.walkmapIntercept == true)
        .. "/" .. tostring(_G.QuestLogFrame and _G.QuestLogFrame.walkmapIntercept == true)
        .. ", redirected " .. interceptCount .. " time(s)"
        .. ", blocked while closing " .. interceptBlocks .. " time(s)"
end

local events = CreateFrame("Frame", "WalkMapQuestLogEvents")
for _, event in ipairs({"PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "UPDATE_BINDINGS",
    "PLAYER_REGEN_ENABLED", "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED", "GROUP_ROSTER_UPDATE",
    "ADDON_LOADED"}) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event)
    -- The world map can be load-on-demand; hook it once it exists.
    if event == "ADDON_LOADED" or event == "PLAYER_LOGIN" then interceptAll() end
    if event == "ADDON_LOADED" then return end
    if event == "QUEST_LOG_UPDATE" or event == "QUEST_WATCH_LIST_CHANGED" or event == "GROUP_ROSTER_UPDATE" then
        if refresh then refresh() end
        return
    end
    if event == "UPDATE_BINDINGS" then appliedKeys = nil end
    applyKeys()
end)
-- The setting can change at any time from Settings; check it cheaply.
local settingElapsed = 0
events:SetScript("OnUpdate", function(_, elapsed)
    settingElapsed = settingElapsed + elapsed
    if settingElapsed < 1 then return end
    settingElapsed = 0
    applyKeys()
end)

buildPanel()
interceptAll()
if WalkMapExtras.Resize then pcall(WalkMapExtras.Resize) end
