-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- Shared quest facts from the game, used by the map, quest log and tracker:
-- difficulty colour, tags (Elite, Group 3, Dungeon...), distance, the game's
-- next waypoint for a quest, and the optional waypoint to a turn-in.
-- Read-only except for WalkMap's own waypoint.
WalkMapQuestInfo = {}
local info = WalkMapQuestInfo

local function call(fn, ...)
    if type(fn) ~= "function" then return false end
    return pcall(fn, ...)
end

-- The game's own difficulty level for a quest (falls back to the log level).
function info.DifficultyLevel(questID, fallback)
    if type(questID) == "number" and C_QuestLog then
        local ok, level = call(C_QuestLog.GetQuestDifficultyLevel, questID)
        if ok and type(level) == "number" and level > 0 then return level end
    end
    return fallback
end

-- r, g, b for a quest: grey, green, yellow, orange or red against your level.
function info.Color(questID, fallbackLevel, defaultR, defaultG, defaultB)
    local level = info.DifficultyLevel(questID, fallbackLevel)
    if GetQuestDifficultyColor and type(level) == "number" then
        local ok, color = pcall(GetQuestDifficultyColor, level)
        if ok and type(color) == "table" and color.r then return color.r, color.g, color.b end
    end
    return defaultR or 0.8, defaultG or 0.8, defaultB or 0.8
end

-- Short tag: "Elite", "Group 3", "Dungeon", "Raid", "PvP"... or nil.
function info.Tag(questID, suggestedGroup)
    if type(questID) ~= "number" then return nil end
    local name, elite
    if C_QuestLog then
        local ok, tag = call(C_QuestLog.GetQuestTagInfo, questID)
        if ok and type(tag) == "table" then
            if type(tag.tagName) == "string" and tag.tagName ~= "" then name = tag.tagName end
            elite = tag.isElite == true
        end
    end
    if not name and GetQuestTagInfo then
        local ok, _, tagName = call(GetQuestTagInfo, questID)
        if ok and type(tagName) == "string" and tagName ~= "" then name = tagName end
    end
    local size
    if C_QuestLog then
        local ok, value = call(C_QuestLog.GetSuggestedGroupSize, questID)
        if ok and type(value) == "number" and value > 1 then size = value end
    end
    if not size and type(suggestedGroup) == "number" and suggestedGroup > 1 then size = suggestedGroup end
    if size and (not name or name == "Group") then
        name = "Group " .. size
    elseif elite and not name then
        name = "Elite"
    end
    return name
end

-- The game's quest tag ID (81 Dungeon, 62 Raid, 41 PvP, 1 Elite...), or nil.
-- Quests that are not in your log may need loading first: the first call
-- asks the game for the data, and WalkMap redraws when it arrives.
local DUNGEON_TAGS = {[81] = "Dungeon", [62] = "Raid", [88] = "Raid", [89] = "Raid"}
local requested, loadedSince = {}, false
function info.TagID(questID)
    if type(questID) ~= "number" then return nil end
    if C_QuestLog then
        local ok, tag = call(C_QuestLog.GetQuestTagInfo, questID)
        if ok and type(tag) == "table" and type(tag.tagID) == "number" then return tag.tagID end
    end
    if GetQuestTagInfo then
        local ok, tagID = call(GetQuestTagInfo, questID)
        if ok and type(tagID) == "number" and tagID > 0 then return tagID end
    end
    if not requested[questID] and C_QuestLog and C_QuestLog.RequestLoadQuestByID then
        requested[questID] = true
        call(C_QuestLog.RequestLoadQuestByID, questID)
    end
    return nil
end

-- "Dungeon" or "Raid" for instance quests, else nil.
function info.InstanceTag(questID)
    return DUNGEON_TAGS[info.TagID(questID) or 0]
end

-- "PvP" for PvP quests (the game's tag 41: battleground quests and the
-- like), else nil.
function info.PvPTag(questID)
    return info.TagID(questID) == 41 and "PvP" or nil
end

-- Experience for a quest at your level, from QuestieDB's quest XP table and
-- the same level scaling Questie uses (cmangos rules); nil at max level or
-- when the quest is unknown. Temporary XP buffs are not included.
local function xpTable()
    local lib = _G.LibQuestieDB
    local get = lib and lib.Support and lib.Support.Get
    if type(get) ~= "function" then return nil end
    local ok, module = pcall(get, "QuestXP")
    return ok and type(module) == "table" and type(module.db) == "table" and module.db or nil
end

function info.XP(questID)
    if type(questID) ~= "number" or not UnitLevel then return nil end
    local player = UnitLevel("player") or 0
    local maxLevel = GetMaxPlayerLevel and GetMaxPlayerLevel() or 60
    if player <= 0 or player >= maxLevel then return nil end
    local db = xpTable()
    local row = db and db[questID]
    if type(row) ~= "table" then return nil end
    local level, xp = row[1], row[2]
    if type(level) ~= "number" or level <= 0 or type(xp) ~= "number" or xp <= 0 then return nil end
    local multiplier = math.max(1, math.min(10, 2 * (level - player) + 20))
    xp = xp * multiplier / 10
    if xp <= 100 then xp = 5 * math.floor((xp + 2) / 5)
    elseif xp <= 500 then xp = 10 * math.floor((xp + 5) / 10)
    elseif xp <= 1000 then xp = 25 * math.floor((xp + 12) / 25)
    else xp = 50 * math.floor((xp + 25) / 50) end
    return xp > 0 and math.floor(xp) or nil
end

-- "460 XP" in light blue, or "" when unknown.
function info.XPText(questID)
    if WalkMapExtras and WalkMapExtras.ShowQuestXP and not WalkMapExtras.ShowQuestXP() then return "" end
    local xp = info.XP(questID)
    return xp and ("|cff8fb8ff" .. xp .. " XP|r") or ""
end

-- Yards to the quest's nearest objective, from the game; nil if unknown or
-- on another continent.
function info.Distance(questID)
    if type(questID) ~= "number" or not C_QuestLog then return nil end
    local ok, distanceSq, onContinent = call(C_QuestLog.GetDistanceSqToQuest, questID)
    if not ok or type(distanceSq) ~= "number" or distanceSq < 0 or onContinent == false then return nil end
    return math.sqrt(distanceSq)
end

-- The game's next waypoint for a quest (often the turn-in): mapID, x, y.
function info.NextWaypoint(questID)
    if type(questID) ~= "number" or not C_QuestLog then return nil end
    local ok, mapID, x, y = call(C_QuestLog.GetNextWaypoint, questID)
    if ok and type(mapID) == "number" and mapID > 0 and type(x) == "number" and type(y) == "number"
        and (x > 0 or y > 0) then
        return mapID, x, y
    end
end

-- Settings > Map > Waypoint to turn-ins: when a quest becomes ready
-- to turn in, WalkMap's waypoint moves to the game's next waypoint for it.
-- The first reading after login and newly accepted quests never trigger it.
local known = nil
local function questTitle(questID)
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local ok, title = call(C_QuestLog.GetTitleForQuestID, questID)
        if ok and type(title) == "string" and title ~= "" then return title end
    end
    return "Quest " .. questID
end

local function readComplete()
    local list = {}
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo) then return list end
    for index = 1, math.min(C_QuestLog.GetNumQuestLogEntries() or 0, 120) do
        local entry = C_QuestLog.GetInfo(index)
        if entry and not entry.isHeader and type(entry.questID) == "number" then
            local ok, complete = call(C_QuestLog.IsComplete, entry.questID)
            list[entry.questID] = ok and complete == true
        end
    end
    return list
end

local function check()
    local now = readComplete()
    local enabled = WalkMapExtras and WalkMapExtras.TurnInWaypoint and WalkMapExtras.TurnInWaypoint()
    if known and enabled and WalkMapWaypoint and WalkMapWaypoint.Set then
        for questID, complete in pairs(now) do
            if complete and known[questID] == false then
                local mapID, x, y = info.NextWaypoint(questID)
                if mapID then
                    WalkMapWaypoint.Set(mapID, x, y, "Turn in: " .. questTitle(questID))
                    info.lastTurnIn = questID
                end
            end
        end
    end
    known = now
end

local pending, waited, loadWait = false, 0, 0
local events = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE", "UNIT_QUEST_LOG_CHANGED",
    "QUEST_DATA_LOAD_RESULT"}) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event, unit)
    if event == "QUEST_DATA_LOAD_RESULT" then
        -- Quest tags we asked for arrived: redraw the map markers once.
        if requested[unit] then loadedSince = true end
        return
    end
    if event == "UNIT_QUEST_LOG_CHANGED" and unit ~= "player" then return end
    pending = true
end)
events:SetScript("OnUpdate", function(_, elapsed)
    if loadedSince then
        loadWait = loadWait + elapsed
        if loadWait >= 1 then
            loadWait, loadedSince = 0, false
            if WalkMapExtras and WalkMapExtras.Invalidate then WalkMapExtras.Invalidate() end
        end
    end
    if not pending then return end
    waited = waited + elapsed
    -- The new state is often readable a moment after the event.
    if waited < 0.5 then return end
    waited, pending = 0, false
    check()
end)

function info.Title(questID) return questTitle(questID) end

-- A quest for the chat. The game's own quest link when the client makes one;
-- otherwise the title in brackets as plain text. WalkMap never builds a link
-- itself: the server may reject a chat message with a made-up link.
function info.Link(questID)
    if type(questID) ~= "number" then return nil end
    if GetQuestLink then
        local ok, link = call(GetQuestLink, questID)
        if ok and type(link) == "string" and link ~= "" then return link, true end
    end
    return "[" .. questTitle(questID) .. "]", false
end

-- Put the quest into the chat line.
-- WalkMap never opens or focuses the chat line itself (ChatFrame_OpenChat,
-- ChatEdit_InsertLink's SetFocus): done from an addon, that leaves the game's
-- chat state "tainted", and Forever then blocks its own gamepad code
-- (SetPreferredGamepadInteractTarget) the next time chat or a window opens.
-- So: with the chat line open and focused, the quest goes in at the cursor.
-- Otherwise WalkMap keeps it for a short while and puts it in when YOU open
-- the chat line.
local PENDING_FOR = 30
local pendingLink, pendingUntil, chatHooked = nil, 0, false

local function now() return GetTime and GetTime() or 0 end

local function focusedChatBox()
    local box = _G.ACTIVE_CHAT_EDIT_BOX
    if type(box) == "table" and box.HasFocus and box.Insert then
        local ok, focused = pcall(box.HasFocus, box)
        if ok and focused then return box end
    end
    return nil
end

local function hookChat()
    if chatHooked then return end
    chatHooked = true
    for i = 1, _G.NUM_CHAT_WINDOWS or 10 do
        local box = _G["ChatFrame" .. i .. "EditBox"]
        if box and box.HookScript then
            pcall(box.HookScript, box, "OnEditFocusGained", function(self)
                if not pendingLink or now() > pendingUntil then pendingLink = nil return end
                -- A frame later, when the game has finished opening the line.
                local function insert()
                    if not pendingLink or now() > pendingUntil then pendingLink = nil return end
                    local ok, focused = pcall(self.HasFocus, self)
                    if not (ok and focused) then return end
                    pcall(self.Insert, self, pendingLink)
                    pendingLink = nil
                    info.lastLink = (info.lastLink or "") .. "; put in when chat opened"
                end
                if C_Timer and C_Timer.After then C_Timer.After(0, insert) else insert() end
            end)
        end
    end
end

-- Returns true when the quest went into the chat line now, false when it
-- waits for the chat line to be opened.
function info.LinkToChat(questID)
    local link, real = info.Link(questID)
    if not link then return false end
    info.lastLink = (real and "game link" or "plain text") .. " for quest " .. questID
    local box = focusedChatBox()
    if box then
        pendingLink = nil
        pcall(box.Insert, box, link)
        return true
    end
    hookChat()
    pendingLink, pendingUntil = link, now() + PENDING_FOR
    info.lastLink = info.lastLink .. " (waiting for chat)"
    if print then
        print("|cff80ff80WalkMap:|r open the chat line within " .. PENDING_FOR
            .. " seconds to put in " .. questTitle(questID) .. ".")
    end
    return false
end

function info.PendingLink() return pendingLink ~= nil and now() <= pendingUntil end

-- True when this click is a Shift-click that linked the quest.
function info.LinkClick(questID)
    if not (IsShiftKeyDown and IsShiftKeyDown()) then return false end
    info.LinkToChat(questID)
    return true
end

function info.Status()
    local enabled = WalkMapExtras and WalkMapExtras.TurnInWaypoint and WalkMapExtras.TurnInWaypoint()
    local db = xpTable()
    local xpState = db and ("XP table ok, quest 347 = " .. tostring(info.XP(347)))
        or ("no XP table (LibQuestieDB " .. (_G.LibQuestieDB and "loaded" or "missing") .. ")")
    return "turn-in waypoint " .. (enabled and "on" or "off")
        .. (info.lastTurnIn and ("; last " .. info.lastTurnIn) or "")
        .. "; quest link " .. (info.lastLink or (GetQuestLink and "not used yet" or "not used yet, no GetQuestLink"))
        .. "; " .. xpState .. "; max level " .. tostring(GetMaxPlayerLevel and GetMaxPlayerLevel())
end
