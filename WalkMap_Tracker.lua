-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- WalkMap zone quest tracker: an on-screen list of your quests for the zone
-- you are in, with objectives. It only reads the quest log. The one thing it
-- does to the game's UI is optional (Settings > Quest tracker > Hide game
-- quest tracker, off by default): hide Forever's objective tracker the same
-- way Questie does, out of combat, and show it again when turned off.
-- Settings > Quest tracker. Alt-drag to move it, or move and size it in the
-- game's Edit Mode;
-- Alt-right-click to reset its position; click a quest to open it in
-- WalkMap's quest log.
WalkMapTracker = {}
local tracker = WalkMapTracker
if not WalkMapExtras then return end

-- Look comes from Settings > Quest tracker (WalkMapExtras.TrackerOptions).
local opts = WalkMapExtras.TrackerOptions and WalkMapExtras.TrackerOptions()
    or {font = 1, background = true, backgroundAlpha = 0.3, max = 12, width = 250, objectives = true, scope = "zone"}
local WIDTH = opts.width
local frame = CreateFrame("Frame", "WalkMapZoneTracker", UIParent)
frame:SetSize(WIDTH, 40)
frame:SetFrameStrata("LOW")
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:Hide()

local function call(fn, ...)
    if type(fn) ~= "function" then return false end
    return pcall(fn, ...)
end

-- Position: saved per character, default under the minimap on the right.
-- With the game tracker hidden, the default spot is where it used to be
-- (copied as numbers; WalkMap's frame is never anchored to Blizzard's).
local gameSpot
-- Keep the tracker pinned by its top edge, so a shorter list shrinks from
-- the bottom. After a drag the game anchors by the nearest edge or centre;
-- this converts that to TOPLEFT or TOPRIGHT (whichever side it is on) and
-- saves it. Positions saved by 4.75-4.83 are converted the same way.
local function anchorTop()
    local pos = WalkMapExtras.TrackerSettings()
    local left, right, top = frame:GetLeft(), frame:GetRight(), frame:GetTop()
    local uiLeft, uiRight, uiTop = UIParent:GetLeft(), UIParent:GetRight(), UIParent:GetTop()
    if not (left and right and top and uiLeft and uiRight and uiTop) then return false end
    local point, x
    if (left + right) / 2 < (uiLeft + uiRight) / 2 then
        point, x = "TOPLEFT", left - uiLeft
    else
        point, x = "TOPRIGHT", right - uiRight
    end
    pos.point, pos.x, pos.y = point, x, top - uiTop
    frame:ClearAllPoints()
    frame:SetPoint(point, UIParent, point, pos.x, pos.y)
    return true
end
tracker.AnchorTop = anchorTop

local function placeFrame()
    local pos = WalkMapExtras.TrackerSettings()
    frame:ClearAllPoints()
    if pos.point and pos.x and pos.y then
        frame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    elseif opts.hideGame and gameSpot then
        frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", gameSpot[1], gameSpot[2])
    else
        frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -24, -320)
    end
end

local header = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
header:SetJustifyH("LEFT")
local headerLine = frame:CreateTexture(nil, "ARTWORK")
headerLine:SetHeight(1)
headerLine:SetPoint("LEFT", header, "RIGHT", 6, 0)
headerLine:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
do
    local r, g, b = WalkMapUI.Accent()
    headerLine:SetColorTexture(r, g, b, 0.5)
    -- The newer looks give the zone heading a firmer metal rule.
    if WalkMapUI.Look() ~= "classic" then
        headerLine:SetHeight(2)
        headerLine:SetColorTexture(r, g, b, 0.85)
    end
end
-- Text size: scale each font string from its template's own size.
local function scaleFont(text)
    if not (text.GetFont and text.SetFont) then return end
    if not text.walkmapBaseFont then
        local file, size, flags = text:GetFont()
        if not file then return end
        text.walkmapBaseFont = {file, size or 12, flags}
    end
    local base = text.walkmapBaseFont
    text:SetFont(base[1], math.floor(base[2] * (opts.font or 1) + 0.5), base[3])
end

-- Soft backing so the text stays readable over bright terrain.
local backing = frame:CreateTexture(nil, "BACKGROUND")
backing:SetPoint("TOPLEFT", frame, "TOPLEFT", -6, 4)
backing:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 6, -4)
-- With a newer look the backing is the look's material, darkened so the
-- quest text stays easy to read.
-- Newer looks also get a title band behind the zone name and the metal
-- frame around the tracker; both follow the Background setting.
local skinned = WalkMapUI.Look() ~= "classic"
local band, border
if skinned then
    backing:ClearAllPoints()
    backing:SetPoint("TOPLEFT", frame, "TOPLEFT", -6, 6)
    backing:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 6, -6)
    band = frame:CreateTexture(nil, "BORDER")
    band:SetPoint("TOPLEFT", frame, "TOPLEFT", -6, 6)
    band:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 6, 6)
    band:SetHeight(24)
    WalkMapUI.ApplyHeader(band)
    border = WalkMapUI.FrameBorder(frame, 6, 10, 1)
end
local function paintBacking()
    local alpha = opts.backgroundAlpha or 0.3
    if not WalkMapUI.ApplyMaterial(backing, math.min(1, 0.35 + alpha * 1.3), 0.6) then
        backing:SetColorTexture(0, 0, 0, alpha)
    end
    local shown = opts.background ~= false and opts.frame ~= false
    if band then band:SetShown(shown) band:SetAlpha(math.min(1, 0.5 + alpha)) end
    if border then border:SetShown(shown) end
end
paintBacking()

-- Moving: Alt + left-drag on the header area; Alt + right-click resets.
local grip = CreateFrame("Button", nil, frame)
grip:SetPoint("TOPLEFT", frame, "TOPLEFT", -6, 4)
grip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 6, 4)
grip:SetHeight(22)
grip:RegisterForDrag("LeftButton")
grip:RegisterForClicks("RightButtonUp")
grip:SetScript("OnDragStart", function()
    if IsAltKeyDown and IsAltKeyDown() and not (InCombatLockdown and InCombatLockdown()) then
        frame:StartMoving()
    end
end)
grip:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    if not anchorTop() then
        local point, _, _, x, y = frame:GetPoint(1)
        local pos = WalkMapExtras.TrackerSettings()
        pos.point, pos.x, pos.y = point, x, y
    end
end)
grip:SetScript("OnClick", function()
    if IsAltKeyDown and IsAltKeyDown() then
        local pos = WalkMapExtras.TrackerSettings()
        pos.point, pos.x, pos.y = nil, nil, nil
        placeFrame()
    end
end)
grip:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("WalkMap zone quests")
    GameTooltip:AddLine("Alt-drag to move. Alt-right-click to reset. Set its size in the game's Edit Mode.", 0.85, 0.85, 0.85, true)
    GameTooltip:AddLine("Click a quest to open it in WalkMap's quest log.", 0.85, 0.85, 0.85, true)
    GameTooltip:AddLine("Right-click a quest to remove it from this tracker and the maps. Track in the quest log brings it back.", 0.85, 0.85, 0.85, true)
    GameTooltip:AddLine("Shift-click a quest to link it in chat (open the chat line first, or right after).", 0.85, 0.85, 0.85, true)
    GameTooltip:Show()
end)
grip:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

-- =========================================================
-- Size. Width is Settings > Quest tracker > Width, or any width dragged in
-- the game's Edit Mode. Height (zoneTrackerPos.h, set in Edit Mode) is the
-- most room the tracker may use: it lists the quests that fit and says how
-- many more there are. With or without a set height it stops at the bottom
-- of the screen instead of running under the action bars.
-- =========================================================
local MIN_WIDTH, MAX_WIDTH, MIN_HEIGHT = 180, 520, 60
local editing, sizing = false, false
local placeCorner -- set below; the drag handlers call it
-- Distance from the top of the screen to the tracker's top edge (negative).
local function topOffset()
    local pos = WalkMapExtras.TrackerSettings()
    if pos.point and pos.y then
        if tostring(pos.point):find("^TOP") then return pos.y end
        return nil
    end
    if opts.hideGame and gameSpot then return gameSpot[2] end
    return -320
end
local function roomLimit()
    local pos = WalkMapExtras.TrackerSettings()
    local limit = type(pos.h) == "number" and math.max(MIN_HEIGHT, pos.h) or nil
    local offset = topOffset()
    local screen = UIParent.GetHeight and UIParent:GetHeight()
    if offset and type(screen) == "number" and screen > 0 then
        local room = screen + offset - 10
        if room >= MIN_HEIGHT and (not limit or room < limit) then limit = room end
    end
    return limit
end
tracker.RoomLimit = roomLimit

-- Edit Mode: while the game's Edit Mode is open the tracker gets a blue
-- outline like the game's own frames. Drag it to move it, drag the corner to
-- set its width and height, right-click it to go back to automatic height.
-- WalkMap only listens for EventRegistry's "EditMode.Enter"/"EditMode.Exit"
-- (the game runs those callbacks through secureexecuterange); it never
-- touches the Edit Mode frames themselves.
local editBox = CreateFrame("Button", nil, frame)
editBox:SetPoint("TOPLEFT", frame, "TOPLEFT", -6, 6)
editBox:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 6, -6)
editBox:SetFrameLevel((frame:GetFrameLevel() or 1) + 30)
editBox:RegisterForDrag("LeftButton")
editBox:RegisterForClicks("RightButtonUp")
editBox:Hide()
do
    local fill = editBox:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints(editBox)
    fill:SetColorTexture(0.2, 0.5, 1, 0.16)
    local function edge(a, b, horizontal)
        local line = editBox:CreateTexture(nil, "BORDER")
        line:SetColorTexture(0.35, 0.7, 1, 0.9)
        line:SetPoint(a, editBox, a)
        line:SetPoint(b, editBox, b)
        if horizontal then line:SetHeight(2) else line:SetWidth(2) end
    end
    edge("TOPLEFT", "TOPRIGHT", true)
    edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
    edge("TOPLEFT", "BOTTOMLEFT", false)
    edge("TOPRIGHT", "BOTTOMRIGHT", false)
    local tag = editBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tag:SetPoint("BOTTOMLEFT", editBox, "TOPLEFT", 2, 2)
    tag:SetText("WalkMap quest tracker")
end
local corner = CreateFrame("Button", nil, editBox)
corner:SetSize(18, 18)
corner:SetPoint("BOTTOMRIGHT", editBox, "BOTTOMRIGHT", -2, 2)
corner:SetFrameLevel((editBox:GetFrameLevel() or 1) + 2)
if corner.SetNormalTexture then
    corner:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    corner:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    corner:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
end
tracker.EditBox, tracker.SizeCorner = editBox, corner

local function saveSize(width, height)
    local pos = WalkMapExtras.TrackerSettings()
    if type(height) == "number" then
        pos.h = math.floor(math.max(MIN_HEIGHT, height) + 0.5)
    end
    if type(width) == "number" and WalkMapExtras.SetTrackerWidth then
        WalkMapExtras.SetTrackerWidth(math.floor(math.min(MAX_WIDTH, math.max(MIN_WIDTH, width)) + 0.5))
        opts = WalkMapExtras.TrackerOptions and WalkMapExtras.TrackerOptions() or opts
    end
    if tracker.Refresh then tracker.Refresh() end
end
tracker.SaveSize = saveSize

editBox:SetScript("OnDragStart", function()
    if InCombatLockdown and InCombatLockdown() then return end
    frame:StartMoving()
end)
editBox:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    anchorTop()
    placeCorner()
    if tracker.Refresh then tracker.Refresh() end
end)
editBox:SetScript("OnClick", function()
    WalkMapExtras.TrackerSettings().h = nil
    if tracker.Refresh then tracker.Refresh() end
end)
editBox:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("WalkMap quest tracker")
    GameTooltip:AddLine("Drag to move. Drag the corner to set width and height: the tracker lists the quests that fit.", 0.85, 0.85, 0.85, true)
    GameTooltip:AddLine("Right-click: automatic height (down to the bottom of the screen).", 0.85, 0.85, 0.85, true)
    GameTooltip:Show()
end)
editBox:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
-- The corner sits on the side away from the screen edge the tracker is
-- pinned to, so dragging it moves the free edge.
local cornerPoint = "BOTTOMRIGHT"
placeCorner = function()
    local pos = WalkMapExtras.TrackerSettings()
    local pinnedRight = pos.point == "TOPRIGHT" or not pos.point
    cornerPoint = pinnedRight and "BOTTOMLEFT" or "BOTTOMRIGHT"
    corner:ClearAllPoints()
    corner:SetPoint(cornerPoint, editBox, cornerPoint, pinnedRight and 2 or -2, 2)
    for _, texture in ipairs({corner.GetNormalTexture and corner:GetNormalTexture(),
        corner.GetPushedTexture and corner:GetPushedTexture(),
        corner.GetHighlightTexture and corner:GetHighlightTexture()}) do
        if texture and texture.SetTexCoord then
            if pinnedRight then texture:SetTexCoord(1, 0, 0, 1) else texture:SetTexCoord(0, 1, 0, 1) end
        end
    end
end
tracker.CornerPoint = function() return cornerPoint end
corner:SetScript("OnMouseDown", function()
    if InCombatLockdown and InCombatLockdown() then return end
    sizing = true
    if frame.SetResizable then frame:SetResizable(true) end
    if frame.SetResizeBounds then
        pcall(frame.SetResizeBounds, frame, MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, 2000)
    elseif frame.SetMinResize then
        pcall(frame.SetMinResize, frame, MIN_WIDTH, MIN_HEIGHT)
        if frame.SetMaxResize then pcall(frame.SetMaxResize, frame, MAX_WIDTH, 2000) end
    end
    frame:StartSizing(cornerPoint)
end)
corner:SetScript("OnMouseUp", function()
    if not sizing then return end
    frame:StopMovingOrSizing()
    sizing = false
    anchorTop()
    saveSize(frame:GetWidth(), frame:GetHeight())
end)

function tracker.SetEditing(on)
    on = on and true or false
    if sizing and not on then corner:GetScript("OnMouseUp")() end
    editing = on
    if on then placeCorner() end
    editBox:SetShown(on)
    if tracker.Refresh then tracker.Refresh() end
end
function tracker.Editing() return editing end
if EventRegistry and EventRegistry.RegisterCallback then
    pcall(EventRegistry.RegisterCallback, EventRegistry, "EditMode.Enter",
        function() tracker.SetEditing(true) end, tracker)
    pcall(EventRegistry.RegisterCallback, EventRegistry, "EditMode.Exit",
        function() tracker.SetEditing(false) end, tracker)
end

local blocks = {}
local function blockFor(i)
    local block = blocks[i]
    if block then return block end
    block = CreateFrame("Button", nil, frame)
    block:SetWidth(WIDTH)
    block:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    block.title = block:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    block.title:SetPoint("TOPLEFT", block, "TOPLEFT", 0, 0)
    -- Distance to the quest ("230 yd"), right-aligned on the title line.
    block.distance = block:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    block.distance:SetPoint("TOPRIGHT", block, "TOPRIGHT", 0, -1)
    block.distance:SetJustifyH("RIGHT")
    block.distance:SetTextColor(0.75, 0.75, 0.7)
    scaleFont(block.distance)
    block.title:SetWidth(WIDTH - 52)
    scaleFont(block.title)
    -- Experience ("460 XP"), right-aligned on the first line below the title.
    block.xp = block:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    block.xp:SetJustifyH("RIGHT")
    scaleFont(block.xp)
    block.title:SetJustifyH("LEFT")
    block.title:SetWordWrap(false)
    block.lines = {}
    local glow = block:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints(block)
    glow:SetColorTexture(1, 0.8, 0.3, 0.12)
    block:SetScript("OnClick", function(self, button)
        -- Right-click: remove this quest from the tracker.
        if button == "RightButton" then
            if self.questID and WalkMapExtras.SetTrackerHidden then
                WalkMapExtras.SetTrackerHidden(self.questID, true)
                if print then
                    print("|cff80ff80WalkMap:|r " .. tostring(self.questTitle or "Quest")
                        .. " removed from the tracker. Track in WalkMap's quest log brings it back.")
                end
            end
            return
        end
        if self.questID and WalkMapQuestInfo and WalkMapQuestInfo.LinkClick(self.questID) then return end
        if (InCombatLockdown and InCombatLockdown()) or not self.questID then return end
        if WalkMapQuestLog and WalkMapQuestLog.OpenQuest then WalkMapQuestLog.OpenQuest(self.questID) end
    end)
    blocks[i] = block
    return block
end

local function lineFor(block, i)
    local line = block.lines[i]
    if line then return line end
    line = block:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line:SetWidth(WIDTH - 10)
    scaleFont(line)
    line:SetJustifyH("LEFT")
    line:SetWordWrap(true)
    block.lines[i] = line
    return line
end

-- The game's difficulty colour for the quest (WalkMap_QuestInfo.lua).
local function levelColor(level, questID)
    if WalkMapQuestInfo then return WalkMapQuestInfo.Color(questID, level, 1, 0.82, 0) end
    return 1, 0.82, 0
end

local function distanceText(questID)
    local yards = WalkMapQuestInfo and WalkMapQuestInfo.Distance(questID)
    if not yards then return "" end
    if yards >= 1000 then return string.format("%.1fk yd", yards / 1000) end
    return string.format("%d yd", math.floor(yards / 10 + 0.5) * 10)
end

local function currentZone()
    local name = GetZoneText and GetZoneText() or nil
    local mapID = WalkMapMaps and WalkMapMaps.CurrentZone()
    if (not name or name == "") and mapID and WalkMapMaps then name = WalkMapMaps.Name(mapID) end
    return name, mapID
end

-- Quests for this zone: filed under its header in the log, shown on its map
-- by the game, or with QuestieDB objective locations on it. With the scope
-- "nearby" or "all", quests of a neighbouring zone that reach into this map
-- follow in a "Nearby: <zone>" group with their distance. With "all", the
-- rest of the log comes last, grouped by its quest-log zone.
local function zoneQuests()
    local list = {}
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo) then return list end
    local zoneName, mapID = currentZone()
    local onMap = {}
    if mapID and C_QuestLog.GetQuestsOnMap then
        local ok, quests = call(C_QuestLog.GetQuestsOnMap, mapID)
        if ok and type(quests) == "table" then
            for _, quest in ipairs(quests) do if quest.questID then onMap[quest.questID] = true end end
        end
    end
    local headerTitle, zoneOrder, groups = nil, {}, 0
    local everything = opts.scope == "all"
    local neighbours = everything or opts.scope == "nearby"
    local count = C_QuestLog.GetNumQuestLogEntries() or 0
    -- Quests the player removed from the tracker stay out of it, except the
    -- focused quest: focusing a quest is asking to see it.
    local isHidden = WalkMapExtras.TrackerHidden
    local focusID = WalkMapExtras.QuestFocus and WalkMapExtras.QuestFocus()
    local inLog, logQuests = {}, 0
    for index = 1, math.min(count, 120) do
        local info = C_QuestLog.GetInfo(index)
        if info and info.isHeader then
            headerTitle = info.title
            groups = groups + 1
            zoneOrder[headerTitle or ""] = zoneOrder[headerTitle or ""] or groups
        elseif info and type(info.questID) == "number" then
            inLog[info.questID] = true
            logQuests = logQuests + 1
        end
        if info and not info.isHeader and type(info.questID) == "number"
            and not (isHidden and isHidden(info.questID) and info.questID ~= focusID) then
            local id = info.questID
            local data = WalkMapLiveDB and WalkMapLiveDB.Objective(id)
            local relevant = headerTitle == zoneName
                or WalkMapMaps.QuestHere(mapID, headerTitle, onMap[id], data)
            local near = not relevant and neighbours and WalkMapMaps.QuestNearby
                and WalkMapMaps.QuestNearby(mapID, headerTitle, onMap[id], data) or false
            if relevant or everything or near then
                local _, complete = call(C_QuestLog.IsComplete, id)
                list[#list + 1] = {id = id, title = info.title or ("Quest " .. id), level = info.level,
                    tag = WalkMapQuestInfo and WalkMapQuestInfo.Tag(id, info.suggestedGroup),
                    distance = (relevant or near) and WalkMapQuestInfo and WalkMapQuestInfo.Distance(id) or nil,
                    complete = complete == true, here = relevant and true or false, near = near,
                    zone = headerTitle or "Other", group = zoneOrder[headerTitle or ""] or 0}
            end
        end
    end
    -- Forget removed quests that are no longer in the log. Not while the log
    -- reads as empty (it does for a moment at login).
    if logQuests > 0 and count <= 120 and WalkMapExtras.PruneTrackerHidden then
        WalkMapExtras.PruneTrackerHidden(inLog)
    end
    -- WalkMap's focused quest first, then this zone, then nearby quests of
    -- neighbouring zones, then other zones in quest-log order; inside each:
    -- ready to turn in, then (here and nearby) distance, then level.
    local focus = WalkMapExtras.QuestFocus and WalkMapExtras.QuestFocus()
    table.sort(list, function(a, b)
        if (a.id == focus) ~= (b.id == focus) then return a.id == focus end
        if a.here ~= b.here then return a.here end
        if a.near ~= b.near then return a.near end
        if not a.here and a.group ~= b.group then return a.group < b.group end
        if a.complete ~= b.complete then return a.complete end
        -- This zone and nearby: nearest first when the game knows both distances.
        if (a.here or a.near) and a.distance and b.distance and a.distance ~= b.distance then
            return a.distance < b.distance
        end
        if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) < (b.level or 0) end
        return a.title < b.title
    end)
    return list, zoneName, focus
end

-- Apply size, width and background to everything already created.
local function applyLook()
    WIDTH = opts.width or 250
    frame:SetWidth(WIDTH)
    scaleFont(header)
    backing:SetShown(opts.background ~= false)
    paintBacking()
    for _, block in ipairs(blocks) do
        block:SetWidth(WIDTH)
        block.title:SetWidth(WIDTH - 52)
        scaleFont(block.title)
        scaleFont(block.distance)
        scaleFont(block.xp)
        for _, line in ipairs(block.lines) do
            line:SetWidth(WIDTH - 10)
            scaleFont(line)
        end
    end
end

-- Grey zone names between groups when other zones are shown.
local groupLabels = {}
local function groupLabel(i)
    local label = groupLabels[i]
    if not label then
        label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetJustifyH("LEFT")
        groupLabels[i] = label
    end
    scaleFont(label)
    label:SetWidth(WIDTH)
    return label
end

local more
local function render()
    if sizing then return end
    if not WalkMapExtras.ZoneTracker() then frame:Hide() return end
    local quests, zoneName, focus = zoneQuests()
    if #quests == 0 and not editing then frame:Hide() return end
    header:SetText(zoneName or "Zone")
    if not more then
        more = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        more:SetJustifyH("LEFT")
        more:SetTextColor(0.62, 0.6, 0.52)
    end
    scaleFont(more)
    local limit = roomLimit()
    local moreHeight = (more.GetStringHeight and more:GetStringHeight() or 11) + 4
    local headerHeight = header.GetStringHeight and header:GetStringHeight() or 14
    local y, shown = -(math.max(14, headerHeight) + 6), math.min(#quests, opts.max or 12)
    local lastGroup, labelsUsed, placed = "", 0, 0
    for i = 1, shown do
        local quest = quests[i]
        local yBefore, labelsBefore, groupBefore = y, labelsUsed, lastGroup
        local group = (quest.here or quest.id == focus) and ""
            or (quest.near and ("Nearby: " .. quest.zone) or quest.zone)
        if group ~= lastGroup and group ~= "" then
            labelsUsed = labelsUsed + 1
            local label = groupLabel(labelsUsed)
            label:SetText(group)
            label:SetTextColor(0.62, 0.6, 0.52)
            label:ClearAllPoints()
            label:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, y - 2)
            label:Show()
            y = y - (label.GetStringHeight and label:GetStringHeight() or 11) - 5
        end
        lastGroup = group
        local block = blockFor(i)
        block.questID = quest.id
        block.questTitle = quest.title
        block:ClearAllPoints()
        block:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, y)
        local r, g, b = levelColor(quest.level, quest.id)
        local prefix = quest.id == focus and "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:12|t " or ""
        block.title:SetText(prefix .. (type(quest.level) == "number" and quest.level > 0
            and ("[" .. quest.level .. "] ") or "") .. quest.title
            .. (quest.tag and (" |cffc8a0ff(" .. quest.tag .. ")|r") or ""))
        block.distance:SetText((quest.here or quest.near) and distanceText(quest.id) or "")
        block.title:SetTextColor(r, g, b)
        local height = (block.title.GetStringHeight and block.title:GetStringHeight() or 13) + 1
        local used = 0
        if opts.objectives == false then
            if quest.complete then
                block.title:SetText(block.title:GetText() .. " |cff80f080(ready)|r")
            end
        elseif quest.complete then
            used = 1
            local line = lineFor(block, 1)
            line:SetText("Ready to turn in")
            line:SetTextColor(0.5, 0.95, 0.5)
        else
            local ok, objectives = call(C_QuestLog.GetQuestObjectives, quest.id)
            for _, objective in ipairs(ok and type(objectives) == "table" and objectives or {}) do
                used = used + 1
                local line = lineFor(block, used)
                line:SetText("- " .. tostring(objective.text or ""))
                if objective.finished then line:SetTextColor(0.5, 0.95, 0.5)
                else line:SetTextColor(0.9, 0.9, 0.9) end
                if used >= 6 then break end
            end
        end
        -- Party members' progress on this quest (WalkMap_GroupProgress.lua).
        if opts.objectives ~= false and WalkMapGroupProgress then
            for _, row in ipairs(WalkMapGroupProgress.Lines(quest.id)) do
                used = used + 1
                local line = lineFor(block, used)
                line:SetText(row[1])
                line:SetTextColor(row[2], row[3], row[4])
            end
        end
        local xpText = WalkMapQuestInfo and WalkMapQuestInfo.XPText(quest.id) or ""
        block.xp:ClearAllPoints()
        if xpText ~= "" and used > 0 then
            block.xp:SetPoint("TOPRIGHT", block, "TOPRIGHT", 0, -height - 1)
            block.xp:SetText(xpText)
            block.xp:Show()
        else
            block.xp:Hide()
            if xpText ~= "" then block.title:SetText(block.title:GetText() .. " " .. xpText) end
        end
        for n = 1, used do
            local line = block.lines[n]
            -- The first line makes room for the XP on its right.
            -- (as wide as the XP text really is: larger fonts draw it wider).
            local xpRoom = math.max(56, (tonumber(block.xp:GetStringWidth()) or 0) + 8)
            line:SetWidth(WIDTH - 10 - ((n == 1 and block.xp:IsShown()) and xpRoom or 0))
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", block, "TOPLEFT", 10, -height)
            line:Show()
            height = height + (line.GetStringHeight and line:GetStringHeight() or 12) + 1
        end
        for n = used + 1, #block.lines do block.lines[n]:Hide() end
        -- Room left? The first quest always shows; later ones only when they
        -- fit, with room kept for the "+N more" line when quests follow.
        local after = #quests - i
        if limit and i > 1 and (-y + height + (after > 0 and moreHeight or 0)) > limit then
            y, lastGroup = yBefore, groupBefore
            for n = labelsBefore + 1, labelsUsed do groupLabels[n]:Hide() end
            labelsUsed = labelsBefore
            break
        end
        block:SetHeight(height)
        block:Show()
        placed = i
        y = y - height - (opts.objectives == false and 2 or 6)
    end
    for i = placed + 1, #blocks do blocks[i]:Hide() end
    for i = labelsUsed + 1, #groupLabels do groupLabels[i]:Hide() end
    local left = #quests - placed
    if left > 0 then
        more:SetWidth(WIDTH)
        more:SetText("+" .. left .. (left == 1 and " more quest" or " more quests"))
        more:ClearAllPoints()
        more:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, y - 1)
        more:Show()
        y = y - moreHeight
    else
        more:Hide()
    end
    tracker.lastPlaced, tracker.lastMore = placed, left
    if editing then
        -- Show the whole box while it is being sized.
        local pos = WalkMapExtras.TrackerSettings()
        frame:SetHeight(math.max(-y, type(pos.h) == "number" and pos.h or 0, MIN_HEIGHT))
    else
        frame:SetHeight(-y)
    end
    frame:Show()
    -- An older save anchored by its bottom or centre: pin it by the top
    -- where it is now drawn.
    local pos = WalkMapExtras.TrackerSettings()
    if pos.point and not tostring(pos.point):find("^TOP") then anchorTop() end
end

-- =========================================================
-- Optional: hide the game's own quest tracker. Forever re-shows it whenever
-- a quest is added, so an OnShow hook hides it again. Like Questie, a
-- protected tracker is only hidden or restored outside combat.
-- =========================================================
local hidingGame, hookedGame, gameStatus = false, false, "shown (setting off)"
local applyGameTracker
local function gameTracker()
    return ObjectiveTrackerFrame or QuestWatchFrame or WatchFrame
end

local function rememberGameSpot(game)
    if gameSpot or not (game.GetRight and game.GetTop) then return end
    local right, top = game:GetRight(), game:GetTop()
    local uiRight, uiTop = UIParent:GetRight(), UIParent:GetTop()
    if not (right and top and uiRight and uiTop) then return end
    local ratio = (game:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
    gameSpot = {right * ratio - uiRight, top * ratio - uiTop}
end

-- While WalkMap hides Forever's tracker, new quests should not be added to
-- the game's tracking list either (CVar autoQuestWatch). The earlier value is
-- kept in WalkMapSettings and put back when WalkMap releases the tracker.
local autoWatchStatus = "unchanged"
local function setAutoWatch(off)
    if not (GetCVar and SetCVar) then autoWatchStatus = "unavailable" return end
    if InCombatLockdown and InCombatLockdown() then tracker.pendingCombat = true return end
    local saved = type(WalkMapSettings) == "table" and WalkMapSettings or nil
    local ok, now = pcall(GetCVar, "autoQuestWatch")
    if not ok or now == nil then autoWatchStatus = "unavailable" return end
    if off then
        if now ~= "0" then
            if saved and saved.autoQuestWatchBefore == nil then saved.autoQuestWatchBefore = now end
            pcall(SetCVar, "autoQuestWatch", "0")
        end
        autoWatchStatus = "off (by WalkMap)"
    elseif saved and saved.autoQuestWatchBefore ~= nil then
        pcall(SetCVar, "autoQuestWatch", saved.autoQuestWatchBefore)
        saved.autoQuestWatchBefore = nil
        autoWatchStatus = "restored"
    else
        autoWatchStatus = "unchanged (" .. tostring(now) .. ")"
    end
end

applyGameTracker = function()
    local game = gameTracker()
    if not game then gameStatus = "no game tracker frame found" return end
    local want = opts.hideGame == true and WalkMapExtras.ZoneTracker()
    local protected = game.IsProtected and game:IsProtected()
    -- Alpha is not protected (Questie 12.10 does the same): if the game
    -- shows its protected tracker during a fight, it stays invisible until
    -- it can be hidden after combat.
    if want and game.SetAlpha then pcall(game.SetAlpha, game, 0) end
    if InCombatLockdown and InCombatLockdown() and (protected or not want) then
        gameStatus = "waiting for combat to end"
        tracker.pendingCombat = true
        return
    end
    tracker.pendingCombat = false
    if want then
        if not hookedGame and game.HookScript then
            hookedGame = true
            game:HookScript("OnShow", function()
                if hidingGame then applyGameTracker() end
            end)
        end
        rememberGameSpot(game)
        if not hidingGame then hidingGame = true placeFrame() end
        if game:IsShown() then game:Hide() end
        setAutoWatch(true)
        gameStatus = "hidden by WalkMap"
    elseif hidingGame then
        -- Release only what WalkMap hid; Blizzard decides from here.
        hidingGame = false
        if game.SetAlpha then pcall(game.SetAlpha, game, 1) end
        game:Show()
        placeFrame()
        setAutoWatch(false)
        gameStatus = "shown again"
    else
        setAutoWatch(false)
        gameStatus = "shown (setting off)"
    end
end

function tracker.Status()
    local game = gameTracker()
    return (WalkMapExtras.ZoneTracker() and "on" or "off") .. "; game tracker "
        .. gameStatus .. (game and game.GetName and game:GetName() and (" (" .. game:GetName() .. ")") or "")
        .. "; auto-tracking " .. autoWatchStatus
end

-- Redraw at most twice a second, only when something changed. Quest events
-- often arrive before the new quest is readable in the log, so each one also
-- schedules follow-up redraws; a slow safety redraw catches anything missed.
local dirty, elapsedSince, sinceFull = true, 0, 0
local followUps = {}
local FOLLOW_UP = {0.3, 1, 2.5}
local QUEST_EVENTS = {QUEST_ACCEPTED = true, QUEST_REMOVED = true, QUEST_TURNED_IN = true,
    QUEST_LOG_UPDATE = true, UNIT_QUEST_LOG_CHANGED = true, QUEST_WATCH_LIST_CHANGED = true,
    QUEST_COMPLETE = true, QUEST_FINISHED = true}
function tracker.Refresh() dirty = true end
local events = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED",
    "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED_INDOORS", "UNIT_QUEST_LOG_CHANGED",
    "PLAYER_LEVEL_UP", "PLAYER_REGEN_ENABLED", "QUEST_ACCEPTED",
    "QUEST_REMOVED", "QUEST_TURNED_IN", "QUEST_COMPLETE", "QUEST_FINISHED"}) do
    pcall(events.RegisterEvent, events, event)
end
pcall(events.RegisterEvent, events, "INPUT_DEVICE_INTERFACE_TRANSITION")
events:SetScript("OnEvent", function(_, event)
    -- Each game interface has its own tracker place and size.
    if event == "PLAYER_ENTERING_WORLD" or event == "INPUT_DEVICE_INTERFACE_TRANSITION" then placeFrame() end
    if event == "INPUT_DEVICE_INTERFACE_TRANSITION" and C_Timer and C_Timer.After then
        C_Timer.After(0.5, function() placeFrame() tracker.Refresh() end)
    end
    if event == "PLAYER_REGEN_ENABLED" and tracker.pendingCombat then applyGameTracker() end
    if QUEST_EVENTS[event] or event:find("^ZONE_CHANGED") then
        for i, delay in ipairs(FOLLOW_UP) do followUps[i] = delay end
    end
    dirty = true
end)
events:SetScript("OnUpdate", function(_, elapsed)
    for i, left in pairs(followUps) do
        left = left - elapsed
        if left <= 0 then followUps[i], dirty = nil, true else followUps[i] = left end
    end
    sinceFull = sinceFull + elapsed
    if sinceFull >= 5 then sinceFull, dirty = 0, true end
    -- Distances change as you walk; update just those once a second.
    tracker.distanceAt = (tracker.distanceAt or 0) + elapsed
    if tracker.distanceAt >= 1 and frame:IsShown() then
        tracker.distanceAt = 0
        for _, block in ipairs(blocks) do
            if block:IsShown() and block.questID and block.distance:GetText() ~= nil then
                if block.distance:GetText() ~= "" then block.distance:SetText(distanceText(block.questID)) end
            end
        end
    end
    elapsedSince = elapsedSince + elapsed
    -- A fresh change (event or follow-up) redraws within 0.2 s.
    if elapsedSince < (dirty and 0.2 or 0.5) then return end
    elapsedSince = 0
    -- The setting and WalkMap's focus can change at any time.
    local enabled = WalkMapExtras.ZoneTracker()
    if enabled ~= tracker.lastEnabled then tracker.lastEnabled, dirty = enabled, true end
    local focus = WalkMapExtras.QuestFocus and WalkMapExtras.QuestFocus()
    if focus ~= tracker.lastFocus then tracker.lastFocus, dirty = focus, true end
    if WalkMapExtras.TrackerOptions then
        opts = WalkMapExtras.TrackerOptions()
        local look = table.concat({tostring(opts.font), tostring(opts.background),
            tostring(opts.backgroundAlpha), tostring(opts.max), tostring(opts.width),
            tostring(opts.objectives), tostring(opts.scope), tostring(opts.frame)}, "|")
        if look ~= tracker.lastLook then
            tracker.lastLook, dirty = look, true
            applyLook()
        end
        local hide = tostring(opts.hideGame) .. tostring(enabled)
        if hide ~= tracker.lastHide then
            tracker.lastHide = hide
            applyGameTracker()
        end
    end
    if dirty then
        dirty = false
        render()
    end
end)
placeFrame()
