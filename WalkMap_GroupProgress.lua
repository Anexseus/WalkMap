-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- Group progress: in a party, WalkMap tells the other members with WalkMap
-- how far you are with each quest in your log, and the tracker shows theirs
-- under the quests you share ("Anna  3/8, 0/1" or "Anna  ready").
--
-- Addon messages on PARTY with prefix "WalkMapQP" (raids are left out: the
-- tracker has no room for 39 people). Several quests go in one message:
--   P;<questID>=<ready 0/1>=<done>/<needed>,<done>/<needed>;<questID>=...
--   G;<questID>;<questID>   quests no longer in the log
--   R                       please send everything again (someone joined)
-- Only what changed is sent, at most one message a second.
WalkMapGroupProgress = {}
local progress = WalkMapGroupProgress

local PREFIX = "WalkMapQP"
local MAX_LENGTH = 240
local SEND_GAP = 1

local others = {}   -- sender -> {[questID] = {ready = bool, objectives = {{done, needed}}}}
local lastSent = {} -- questID -> encoded entry as last sent
local outbox = {}
local dirty, wait, since = true, 0, 0

local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end

local function wanted() return WalkMapExtras and WalkMapExtras.GroupProgress and WalkMapExtras.GroupProgress() end
local function inParty()
    return call(IsInGroup) == true and call(IsInRaid) ~= true
end

-- The party unit a sender stands for ("party1".."party4"), or nil (yourself,
-- or someone not in your party). Names may carry a realm, and on Forever a
-- second name that not every call includes.
local function sameName(a, b)
    return a == b or a:sub(1, #b + 1) == b .. " " or b:sub(1, #a + 1) == a .. " "
end
local function unitFor(sender)
    if type(sender) ~= "string" then return nil end
    local short = sender:match("^([^%-]+)") or sender
    for i = 1, 4 do
        local unit = "party" .. i
        local name = call(UnitName, unit)
        if type(name) == "string" and name ~= "" and sameName(name, short) then return unit end
    end
end

-- =========================================================
-- Sending
-- =========================================================
local function encode(questID)
    local ready = call(C_QuestLog.IsComplete, questID) == true
    local parts = {}
    local objectives = call(C_QuestLog.GetQuestObjectives, questID)
    for _, o in ipairs(type(objectives) == "table" and objectives or {}) do
        local done, needed = tonumber(o.numFulfilled), tonumber(o.numRequired)
        if not needed or needed <= 0 then done, needed = o.finished and 1 or 0, 1 end
        parts[#parts + 1] = math.floor(done or 0) .. "/" .. math.floor(needed)
        if #parts >= 6 then break end
    end
    return questID .. "=" .. (ready and 1 or 0) .. "=" .. table.concat(parts, ",")
end

local function snapshot()
    local now = {}
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo) then return now end
    for index = 1, call(C_QuestLog.GetNumQuestLogEntries) or 0 do
        local info = call(C_QuestLog.GetInfo, index)
        if type(info) == "table" and not info.isHeader and type(info.questID) == "number" and info.questID > 0 then
            now[info.questID] = encode(info.questID)
        end
    end
    return now
end

-- Pack entries into messages "<kind>;a;b;..." no longer than MAX_LENGTH.
local function pack(kind, entries)
    local message = kind
    for _, entry in ipairs(entries) do
        if #message + 1 + #entry > MAX_LENGTH and message ~= kind then
            outbox[#outbox + 1] = message
            message = kind
        end
        message = message .. ";" .. entry
    end
    if message ~= kind then outbox[#outbox + 1] = message end
end

local function sendChanges()
    local now = snapshot()
    local changed, gone = {}, {}
    for questID, entry in pairs(now) do
        if lastSent[questID] ~= entry then changed[#changed + 1] = entry end
    end
    for questID in pairs(lastSent) do
        if not now[questID] then gone[#gone + 1] = tostring(questID) end
    end
    table.sort(changed)
    table.sort(gone)
    pack("P", changed)
    pack("G", gone)
    lastSent = now
end

local function flush()
    local message = table.remove(outbox, 1)
    if message and C_ChatInfo and C_ChatInfo.SendAddonMessage then
        pcall(C_ChatInfo.SendAddonMessage, PREFIX, message, "PARTY")
    end
end

-- =========================================================
-- Receiving
-- =========================================================
local function refreshTracker()
    if WalkMapTracker and WalkMapTracker.Refresh then WalkMapTracker.Refresh() end
end

local function heard(text, sender)
    if type(text) ~= "string" or not unitFor(sender) then return end
    local kind = text:sub(1, 1)
    if kind == "R" then
        lastSent, dirty = {}, true -- everything again, for whoever joined
        return
    end
    local mine = others[sender] or {}
    others[sender] = mine
    for entry in text:sub(3):gmatch("[^;]+") do
        if kind == "G" then
            local questID = tonumber(entry)
            if questID then mine[questID] = nil end
        elseif kind == "P" then
            local id, ready, list = entry:match("^(%d+)=([01])=(.*)$")
            local questID = tonumber(id)
            if questID then
                local objectives = {}
                for done, needed in (list or ""):gmatch("(%d+)/(%d+)") do
                    objectives[#objectives + 1] = {tonumber(done), tonumber(needed)}
                end
                mine[questID] = {ready = ready == "1", objectives = objectives}
            end
        end
    end
    refreshTracker()
end
progress.Heard = heard

local function forgetLeavers()
    for sender in pairs(others) do
        if not unitFor(sender) then others[sender] = nil end
    end
end

-- =========================================================
-- For the tracker
-- =========================================================
local function classHex(unit)
    local _, class = call(UnitClass, unit)
    local colors = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)
    local c = colors and class and colors[class]
    if not c then return "ffd8d8d8" end
    return string.format("ff%02x%02x%02x", math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5),
        math.floor(c.b * 255 + 0.5))
end

-- Lines for the tracker under a quest: {text, r, g, b} per party member who
-- has it, in party order.
function progress.Lines(questID)
    local lines = {}
    if not wanted() or not inParty() then return lines end
    local seen = {}
    for i = 1, 4 do
        local unit = "party" .. i
        for sender, quests in pairs(others) do
            local entry = quests[questID]
            if entry and not seen[sender] and unitFor(sender) == unit then
                seen[sender] = true
                local name = call(UnitName, unit) or sender:match("^([^%-]+)")
                local text
                if entry.ready then
                    text = "|cff80f080ready|r"
                else
                    local parts = {}
                    for _, o in ipairs(entry.objectives) do
                        local part = o[1] .. "/" .. o[2]
                        if o[1] >= o[2] then part = "|cff80f080" .. part .. "|r" end
                        parts[#parts + 1] = part
                    end
                    text = #parts > 0 and table.concat(parts, ", ") or "-"
                end
                lines[#lines + 1] = {"|c" .. classHex(unit) .. tostring(name) .. "|r  " .. text, 0.85, 0.85, 0.85}
            end
        end
    end
    return lines
end

function progress.Status()
    local count = 0
    for _ in pairs(others) do count = count + 1 end
    return (wanted() and "on" or "off") .. (inParty() and (", party, " .. count .. " with WalkMap") or ", not in a party")
end

-- =========================================================
-- Events
-- =========================================================
local events = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "QUEST_LOG_UPDATE",
    "UNIT_QUEST_LOG_CHANGED", "QUEST_REMOVED", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "CHAT_MSG_ADDON"}) do
    pcall(events.RegisterEvent, events, event)
end
local members = {}
events:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
        end
        return
    end
    if event == "CHAT_MSG_ADDON" then
        local prefix, text, channel, sender = ...
        if prefix == PREFIX and channel == "PARTY" and wanted() then heard(text, sender) end
        return
    end
    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        forgetLeavers()
        -- Someone new: ask everyone for all of theirs, and send all of ours.
        local now, joined = {}, false
        for i = 1, 4 do
            local name = call(UnitName, "party" .. i)
            if type(name) == "string" then
                now[name] = true
                if not members[name] then joined = true end
            end
        end
        members = now
        if joined and inParty() and wanted() then
            outbox[#outbox + 1] = "R"
            lastSent = {}
        end
        refreshTracker()
    end
    dirty = true
end)
events:SetScript("OnUpdate", function(_, elapsed)
    wait, since = wait - elapsed, since + elapsed
    if not inParty() or not wanted() then
        if next(others) then others = {} refreshTracker() end
        lastSent, outbox = {}, {}
        return
    end
    -- Quest events come in bursts: look at most once a second.
    if dirty and since >= 1 then
        dirty, since = false, 0
        local ok, message = pcall(sendChanges)
        if not ok and WalkMapExtras and WalkMapExtras.DebugEvent then
            WalkMapExtras.DebugEvent("Group progress: " .. tostring(message))
        end
    end
    if wait <= 0 and #outbox > 0 then
        wait = SEND_GAP
        flush()
    end
end)
