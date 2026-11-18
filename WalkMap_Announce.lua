-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- WalkMap party announcements: tell your group when you finish a quest
-- objective (or make any progress) and when a quest is ready to turn in.
-- Settings > Quest tracker > Tell group about quest progress.
-- Off by default. Only reads the quest log and sends chat to your own group.
WalkMapAnnounce = {}
local announce = WalkMapAnnounce
if not WalkMapExtras then return end

local known = nil      -- questID -> {title, complete, objectives = {text, done, finished}}
local lastMessage, lastAt = nil, 0
local sentCount = 0

local function call(fn, ...)
    if type(fn) ~= "function" then return false end
    return pcall(fn, ...)
end

local function now() return GetTime and GetTime() or 0 end

local function groupChannel()
    if IsInRaid and IsInRaid() then return "RAID" end
    if IsInGroup and IsInGroup() then return "PARTY" end
end

local function send(text)
    local channel = groupChannel()
    if not channel or not SendChatMessage then return end
    -- The same line twice in a row within 3 seconds is sent once.
    if text == lastMessage and now() - lastAt < 3 then return end
    lastMessage, lastAt = text, now()
    if call(SendChatMessage, text, channel) then sentCount = sentCount + 1 end
end

local function readLog()
    local quests = {}
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo) then return quests end
    local count = C_QuestLog.GetNumQuestLogEntries() or 0
    for index = 1, math.min(count, 120) do
        local info = C_QuestLog.GetInfo(index)
        if info and not info.isHeader and type(info.questID) == "number" then
            local _, complete = call(C_QuestLog.IsComplete, info.questID)
            local ok, objectives = call(C_QuestLog.GetQuestObjectives, info.questID)
            local list = {}
            for i, objective in ipairs(ok and type(objectives) == "table" and objectives or {}) do
                list[i] = {text = tostring(objective.text or ""), done = objective.numFulfilled,
                    finished = objective.finished == true}
            end
            quests[info.questID] = {title = info.title or ("Quest " .. info.questID),
                complete = complete == true, objectives = list}
        end
    end
    return quests
end

-- Compare with the last reading. New quests and the first reading after
-- login are only remembered, never announced.
local function check()
    local mode = WalkMapExtras.Announce and WalkMapExtras.Announce() or "off"
    local quests = readLog()
    if known and mode ~= "off" and groupChannel() then
        for id, quest in pairs(quests) do
            local before = known[id]
            if before then
                for i, objective in ipairs(quest.objectives) do
                    local old = before.objectives[i]
                    if old and objective.text ~= "" then
                        local justFinished = objective.finished and not old.finished
                        local progressed = mode == "progress" and objective.text ~= old.text
                            and (objective.done or 0) > (old.done or 0)
                        if justFinished or progressed then
                            send("WalkMap: " .. objective.text .. " - " .. quest.title)
                        end
                    end
                end
                if quest.complete and not before.complete then
                    send("WalkMap: " .. quest.title .. " is ready to turn in")
                end
            end
        end
    end
    known = quests
end

local pending, elapsedSince = false, 0
local events = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE", "UNIT_QUEST_LOG_CHANGED",
    "QUEST_ACCEPTED", "QUEST_REMOVED"}) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_QUEST_LOG_CHANGED" and unit ~= "player" then return end
    pending = true
end)
-- Quest updates come in bursts; read the log at most four times a second.
events:SetScript("OnUpdate", function(_, elapsed)
    if not pending then return end
    elapsedSince = elapsedSince + elapsed
    if elapsedSince < 0.25 then return end
    elapsedSince, pending = 0, false
    check()
end)

function announce.Status()
    local mode = WalkMapExtras.Announce and WalkMapExtras.Announce() or "off"
    return mode .. "; group " .. (groupChannel() or "none") .. "; sent " .. sentCount
end
