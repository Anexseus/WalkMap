-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- Turn-in markers the game does not provide. The "?" for a quest that is
-- ready to hand in normally comes from the game's own list of quests on the
-- map. Quests handed in at an object (the sleeping bag chain's planks,
-- satchels and mounds of dirt) may not be on that list; for those the place
-- comes from QuestieDB's finishers instead.
WalkMapTurnIns = {}
local turnIns = WalkMapTurnIns

-- True when QuestieDB is loaded but has no objective locations for this
-- quest on this map. The map then shows the game's own quest marker for it
-- even when quest icons are otherwise off, so the quest's goal is not
-- invisible (quests new to Forever that QuestieDB has no objectives for).
function turnIns.Unlocated(questID, mapID)
    if not (questID and mapID and WalkMapLiveDB and WalkMapLiveDB.State and WalkMapLiveDB.Objective) then
        return false
    end
    if (WalkMapLiveDB.State()) ~= "ready" then return false end
    local data = WalkMapLiveDB.Objective(questID)
    return not (data and data[2] and data[2][mapID])
end

-- The game's quest list for a map, plus an entry per QuestieDB turn-in spot
-- on that map for every ready quest in the log the game did not list there.
-- The game's own list is never changed; a new list is returned when
-- something is added. isReady(questID) is the map's own ready check.
function turnIns.Add(mapID, quests, isReady)
    if not (mapID and type(quests) == "table" and type(isReady) == "function"
        and WalkMapLiveDB and WalkMapLiveDB.TurnIn
        and C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo) then
        return quests
    end
    local listed = {}
    for _, quest in ipairs(quests) do
        if quest.questID then listed[quest.questID] = true end
    end
    local okCount, count = pcall(C_QuestLog.GetNumQuestLogEntries)
    if not okCount or type(count) ~= "number" then return quests end
    local result
    for index = 1, math.min(count, 120) do
        local ok, info = pcall(C_QuestLog.GetInfo, index)
        local id = ok and type(info) == "table" and not info.isHeader and info.questID
        if type(id) == "number" and not listed[id] and isReady(id) then
            listed[id] = true
            local places = WalkMapLiveDB.TurnIn(id)
            for _, point in ipairs(places and places[mapID] or {}) do
                if not result then
                    result = {}
                    for i, quest in ipairs(quests) do result[i] = quest end
                end
                result[#result + 1] = {questID = id, x = point[1] / 100, y = point[2] / 100,
                    walkmapTurnIn = point[3]}
            end
        end
    end
    return result or quests
end
