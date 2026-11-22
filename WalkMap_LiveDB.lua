-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- Read-only QuestieDB consumer. Questie itself does not need to be enabled.
-- Keep the map operational while the live index is built or if it fails.
WalkMapLiveDB = {}
local live = WalkMapLiveDB
local status = "Waiting for QuestieDB..."
local phase, progress = "waiting", 0
local db, areaToMap
local objectiveCache = {}
local turnInCache = {}
local dropCache = {}
local scanning = false

local function bit(value, mask)
    return math.floor((value or 0) / mask) % 2 == 1
end

local professions = {
    alchemy = {"alchem"}, blacksmithing = {"blacksmith", "weaponsmith", "armorsmith"},
    enchanting = {"enchant"}, engineering = {"engineer"},
    herbalism = {"herbal"}, leatherworking = {"leatherwork"},
    mining = {"mining", "miner"}, skinning = {"skinning", "skinner"},
    tailoring = {"tailor"}, ["first aid"] = {"first aid"},
    cooking = {"cook"}, fishing = {"fishing", "fisher"},
}
local classes = {
    warrior = {"warrior trainer"}, paladin = {"paladin trainer"},
    hunter = {"hunter trainer"}, rogue = {"rogue trainer", "grand master rogue"},
    priest = {"priest trainer", "high priest"}, shaman = {"shaman trainer"},
    mage = {"mage trainer", "portal trainer", "master mage"},
    warlock = {"warlock trainer", "demon trainer"}, druid = {"druid trainer"},
}

-- QuestieDB's Object API has positions but no gathering category field.
-- Match known Classic gathering node names, excluding quest mineral objects.
local herbNames = {}
for _, name in ipairs({"silverleaf", "peacebloom", "earthroot", "mageroyal",
    "briarthorn", "bruiseweed", "wild steelbloom", "kingsblood",
    "liferoot", "fadeleaf", "khadgar's whisker", "wintersbite",
    "stranglekelp", "goldthorn", "firebloom", "purple lotus",
    "arthas' tears", "sungrass", "blindweed", "ghost mushroom",
    "gromsblood", "golden sansam", "dreamfoil", "mountain silversage",
    "plaguebloom", "icecap", "black lotus"}) do herbNames[name] = true end
local oreNames = {"copper vein", "tin vein", "silver vein", "gold vein",
    "iron deposit", "mithril deposit", "truesilver deposit", "thorium vein"}
local function resourceKind(name)
    if type(name) ~= "string" then return end
    local lower = name:lower()
    if herbNames[lower] then return "herb" end
    for _, mineral in ipairs(oreNames) do
        if lower:find(mineral, 1, true) then return "ore" end
    end
end
local function includes(title, terms)
    for _, term in ipairs(terms) do
        if title:find(term, 1, true) then return true end
    end
    return false
end
local function rolesFor(title, flags)
    local roles = {}
    local lower = title:lower()
    if lower:find("innkeeper", 1, true) or bit(flags, 128) then
        roles[#roles + 1] = {"inn", ""}
    elseif bit(flags, 16) then
        if lower:find("pet trainer", 1, true) then
            roles[#roles + 1] = {"pet", ""}
        else
            for profession, terms in pairs(professions) do
                if includes(lower, terms) then
                    roles[#roles + 1] = {"trainer", profession}
                    break
                end
            end
            if #roles == 0 then
                for class, terms in pairs(classes) do
                    if includes(lower, terms) then
                        roles[#roles + 1] = {"class", class}
                        break
                    end
                end
            end
        end
    end
    if #roles == 0 and bit(flags, 4)
        and includes(lower, {"weapon", "weaponsmith", "gunsmith", "bowyer",
            "sword vendor", "axe vendor", "mace vendor", "blade merchant"}) then
        roles[#roles + 1] = {"weapon", ""}
    end
    if #roles == 0 and bit(flags, 8) then roles[#roles + 1] = {"flight", ""} end
    for _, special in ipairs({{256, "bank"}, {4096, "auction"},
        {8192, "stable"}, {16384, "repair"}}) do
        if bit(flags, special[1]) then roles[#roles + 1] = {special[2], ""} end
    end
    return roles
end

local function validPoint(point)
    return type(point) == "table" and type(point[1]) == "number"
        and type(point[2]) == "number" and point[1] >= 0 and point[1] <= 100
        and point[2] >= 0 and point[2] <= 100
end
local function round(value)
    return math.floor(value * 100 + 0.5) / 100
end
local function addZonePoint(target, mapID, point)
    if not target[mapID] then target[mapID] = {} end
    target[mapID][#target[mapID] + 1] = point
end

-- Use only canonical area IDs. Descendant subzones need coordinate reprojection.
local function mapping(source)
    local result = {}
    for mapID, areaID in source:gmatch("%[(%d+)%]%s*=%s*(%d+)") do
        result[tonumber(areaID)] = tonumber(mapID)
    end
    return result
end

local function questRow(id, quests, prereqs)
    if quests[id] then return end
    local quest = db.Quest
    if not quest.Exists(id) then return end
    local row = {}
    for i, field in ipairs({4, 5, 6, 7, 32, 25, 22, 33, 34}) do
        row[i] = quest.GetByIndex(id, field) or 0
    end
    for name, field in pairs({name = 1, exclusive = 16, skill = 18,
        minRep = 19, maxRep = 20, breadcrumbFor = 27, breadcrumbs = 28,
        spell = 30, specialization = 31, disabledBy = 36}) do
        -- Optional fields may be absent from older QuestieDB contracts.
        local ok, value = pcall(quest.GetByIndex, id, field)
        if ok and value ~= 0 then row[name] = value end
    end
    quests[id] = row
    local group = quest.GetByIndex(id, 12) or {}
    local single = quest.GetByIndex(id, 13) or {}
    if #single > 0 or #group > 0 then prereqs[id] = {single, group} end
end

-- Rare mobs (QuestieDB rank 4 rare, 2 rare elite), any faction: Places >
-- Rare mobs. {x, y, name, rank, minLevel, maxLevel} per zone.
local function consumeRare(id, name, result)
    local npc = db.Npc
    local okRank, rank = pcall(npc.GetByIndex, id, 6)
    if not okRank or (rank ~= 2 and rank ~= 4) then return end
    local okSpawns, spawns = pcall(npc.GetByIndex, id, 7)
    if not okSpawns or type(spawns) ~= "table" then return end
    local _, low = pcall(npc.GetByIndex, id, 4)
    local _, high = pcall(npc.GetByIndex, id, 5)
    for areaID, coords in pairs(spawns) do
        local mapID = areaToMap[areaID]
        if mapID and type(coords) == "table" then
            for index = 1, math.min(#coords, 8) do
                local point = coords[index]
                if validPoint(point) then
                    addZonePoint(result.rares, mapID, {round(point[1]), round(point[2]), name, rank,
                        type(low) == "number" and low or nil, type(high) == "number" and high or nil})
                end
            end
        end
    end
end

local function consumeNpc(id, result)
    local npc = db.Npc
    local name = npc.GetByIndex(id, 1)
    if type(name) == "string" and result.rares then consumeRare(id, name, result) end
    local faction = npc.GetByIndex(id, 13)
    if type(name) ~= "string" or (faction ~= "A" and faction ~= "H" and faction ~= "AH") then return end
    local title = npc.GetByIndex(id, 14) or ""
    local roles = rolesFor(title, npc.GetByIndex(id, 15) or 0)
    local starts = npc.GetByIndex(id, 10)
    if #roles == 0 and (type(starts) ~= "table" or #starts == 0) then return end
    local spawns = npc.GetByIndex(id, 7)
    if type(spawns) ~= "table" then return end
    local questIDs = {}
    if type(starts) == "table" then
        for _, questID in ipairs(starts) do
            if type(questID) == "number" and db.Quest.Exists(questID) then
                questRow(questID, result.quests, result.prereqs)
                questIDs[#questIDs + 1] = questID
            end
        end
    end
    for areaID, coords in pairs(spawns) do
        local mapID = areaToMap[areaID]
        if mapID and type(coords) == "table" then
            for index = 1, math.min(#coords, 12) do
                local point = coords[index]
                if validPoint(point) then
                    local x, y = round(point[1]), round(point[2])
                    for _, role in ipairs(roles) do
                        addZonePoint(result.services, mapID,
                            {x, y, name, faction, role[1], role[2], title})
                    end
                    if #questIDs > 0 then
                        addZonePoint(result.givers, mapID, {x, y, name, faction, questIDs})
                    end
                end
            end
        end
    end
end

local function consumeObject(id, result, seen, perName)
    local object = db.Object
    local name = object.GetByIndex(id, 1)
    local kind = resourceKind(name)
    -- Objects that start quests (wanted posters, notes, crates, the remains
    -- that begin the sleeping bag chain) are quest givers like NPCs.
    local questIDs
    local okStarts, starts = pcall(object.GetByIndex, id, 2)
    if okStarts and type(name) == "string" and type(starts) == "table" then
        for _, questID in ipairs(starts) do
            if type(questID) == "number" and db.Quest.Exists(questID) then
                questRow(questID, result.quests, result.prereqs)
                questIDs = questIDs or {}
                questIDs[#questIDs + 1] = questID
            end
        end
    end
    if not kind and not questIDs then return end
    local spawns = object.GetByIndex(id, 4)
    if type(spawns) ~= "table" then return end
    for areaID, coords in pairs(spawns) do
        local mapID = areaToMap[areaID]
        if mapID and type(coords) == "table" then
            if questIDs then
                -- Objects carry no faction; the quest's own race rule decides
                -- who is offered it.
                for index = 1, math.min(#coords, 12) do
                    local point = coords[index]
                    if validPoint(point) then
                        addZonePoint(result.givers, mapID,
                            {round(point[1]), round(point[2]), name, "AH", questIDs})
                    end
                end
            end
            local group = tostring(mapID) .. ":" .. tostring(name)
            for _, point in ipairs(kind and coords or {}) do
                if validPoint(point) and (perName[group] or 0) < 120 then
                    local x, y = round(point[1]), round(point[2])
                    local key = group .. ":" .. math.floor(x * 10 + 0.5)
                        .. ":" .. math.floor(y * 10 + 0.5)
                    if not seen[key] then
                        seen[key] = true
                        perName[group] = (perName[group] or 0) + 1
                        addZonePoint(result.resources, mapID, {x, y, name, kind})
                    end
                end
            end
        end
    end
end
local function spawnPoints(kind, id)
    local entity = db[kind]
    if not entity then return end
    local spawns = entity.GetByIndex(id, kind == "Npc" and 7 or 4)
    if type(spawns) ~= "table" then return end
    local result = {}
    for areaID, coords in pairs(spawns) do
        local mapID = areaToMap[areaID]
        if mapID and type(coords) == "table" then
            for _, point in ipairs(coords) do
                if validPoint(point) then
                    if not result[mapID] then result[mapID] = {} end
                    result[mapID][#result[mapID] + 1] = point
                end
            end
        end
    end
    return result
end

-- For the Debug report: an NPC's spawns as QuestieDB has them, area by area
-- ("1581: 41.3,77.4 42.0,77.1"), to see whether dungeon bosses carry
-- coordinates that fit the dungeon maps.
function live.RawSpawns(npcID)
    if not (db and db.Npc) then return "QuestieDB not ready" end
    local ok, spawns = pcall(db.Npc.GetByIndex, npcID, 7)
    if not ok or type(spawns) ~= "table" then return "none" end
    local parts = {}
    for areaID, coords in pairs(spawns) do
        local points = {}
        for i, point in ipairs(type(coords) == "table" and coords or {}) do
            if i > 3 then break end
            if type(point) == "table" then
                points[#points + 1] = ("%s,%s"):format(tostring(point[1]), tostring(point[2]))
            end
        end
        parts[#parts + 1] = tostring(areaID) .. ": " .. table.concat(points, " ")
    end
    table.sort(parts)
    return #parts > 0 and table.concat(parts, "; ") or "none"
end

-- Typed reads first (QuestieDB contract API), positional index as fallback.
local npcRankCache = {}
local function npcRank(npcID)
    if type(npcID) ~= "number" then return nil end
    if npcRankCache[npcID] == nil then
        local npc, rank = db.Npc, nil
        if type(npc.rank) == "function" then
            local ok, value = pcall(npc.rank, npcID)
            if ok then rank = value end
        end
        if rank == nil then
            local ok, value = pcall(npc.GetByIndex, npcID, 6)
            if ok then rank = value end
        end
        npcRankCache[npcID] = type(rank) == "number" and rank or false
    end
    return npcRankCache[npcID] or nil
end

-- NPC level range as {min, max}: typed readers, positional 4/5 fallback.
local npcLevelCache = {}
local function npcLevels(npcID)
    if type(npcID) ~= "number" then return nil end
    if npcLevelCache[npcID] == nil then
        local npc, low, high = db.Npc, nil, nil
        local function read(field, index)
            if type(npc[field]) == "function" then
                local ok, value = pcall(npc[field], npcID)
                if ok and type(value) == "number" then return value end
            end
            local ok, value = pcall(npc.GetByIndex, npcID, index)
            if ok and type(value) == "number" then return value end
        end
        low, high = read("minLevel", 4), read("maxLevel", 5)
        if low and low > 0 then
            npcLevelCache[npcID] = {low, high and high >= low and high or low}
        else
            npcLevelCache[npcID] = false
        end
    end
    return npcLevelCache[npcID] or nil
end

-- Patrol paths: QuestieDB waypoint lists, {[areaID] = {path, ...}}.
local function npcWaypoints(npcID)
    local npc, value = db.Npc, nil
    if type(npc.waypoints) == "function" then
        local ok, result = pcall(npc.waypoints, npcID)
        if ok then value = result end
    end
    if value == nil then
        local ok, result = pcall(npc.GetByIndex, npcID, 8)
        if ok then value = result end
    end
    return type(value) == "table" and value or nil
end

local function addPatrols(target, npcID, seen)
    if seen[npcID] then return end
    seen[npcID] = true
    for areaID, paths in pairs(npcWaypoints(npcID) or {}) do
        local mapID = areaToMap[areaID]
        if mapID and type(paths) == "table" then
            for _, path in ipairs(paths) do
                if type(path) == "table" and #path >= 2 then
                    local clean = {}
                    for _, point in ipairs(path) do
                        if validPoint(point) then clean[#clean + 1] = {point[1], point[2]} end
                        if #clean >= 120 then break end
                    end
                    if #clean >= 2 then
                        target[mapID] = target[mapID] or {}
                        if #target[mapID] < 24 then target[mapID][#target[mapID] + 1] = clean end
                    end
                end
            end
        end
    end
end

local function dropRate(itemID, npcID)
    local cached = dropCache[itemID]
    if not cached then
        local support = db.Support
        local drops = support.Get("QuestieClassicItemDrops")
        local corrections = support.Get("QuestieItemDropCorrections")
        local keys = support.Get("DropDB")
        local function rates(data)
            local out = {}
            if type(data) ~= "string" then return out end
            local first = data:find("\n    [" .. itemID .. "] = {", 1, true)
            if not first then return out end
            local last = data:find("\n    }", first, true)
            if not last then return out end
            local block = data:sub(first, last)
            for npc, value in block:gmatch("%[(%d+)%]%s*=%s*([%d%.]+)") do
                out[tonumber(npc)] = tonumber(value)
            end
            return out
        end
        cached = {
            wowhead = rates(drops and drops.wowheadData),
            pserver = rates(drops and drops.cmangosData),
            corrections = corrections and corrections.Era and corrections.Era[itemID] or {},
            sentinels = keys and keys.correctionKeys or {},
        }
        dropCache[itemID] = cached
    end
    local correction = cached.corrections[npcID]
    if type(correction) == "number" and correction > 0 and correction <= 100 then
        return math.floor(correction * 100 + 0.5) / 100
    end
    local value
    if cached.sentinels.WOWHEAD and correction == cached.sentinels.WOWHEAD then
        value = cached.wowhead[npcID]
    elseif cached.sentinels.PSERVER and correction == cached.sentinels.PSERVER then
        value = cached.pserver[npcID]
    end
    value = value or cached.pserver[npcID] or cached.wowhead[npcID]
    if value and value > 0 and value <= 100 then
        return math.floor(value * 100 + 0.5) / 100
    end
end

-- Where a quest is handed in, from QuestieDB's finishers (NPCs and objects):
-- [mapID] = {{x, y, name}, ...}. At most three spots per map, and spots
-- closer than two map units count as one.
local function buildTurnIn(questID)
    local quest = db.Quest
    if not quest.Exists(questID) then return end
    local finishers = quest.GetByIndex(questID, 3)
    if type(finishers) ~= "table" then return end
    local byMap, occupied = {}, {}
    for index, kind in ipairs({"Npc", "Object"}) do
        local ids = finishers[index]
        for _, id in ipairs(type(ids) == "table" and ids or {}) do
            local name = db[kind].GetByIndex(id, 1)
            for mapID, points in pairs(type(name) == "string" and spawnPoints(kind, id) or {}) do
                for _, point in ipairs(points) do
                    local cell = mapID .. ":" .. math.floor(point[1] / 2) .. ":" .. math.floor(point[2] / 2)
                    if not occupied[cell] and #(byMap[mapID] or {}) < 3 then
                        occupied[cell] = true
                        addZonePoint(byMap, mapID, {round(point[1]), round(point[2]), name})
                    end
                end
            end
        end
    end
    if next(byMap) then return byMap end
end

function live.TurnIn(questID)
    if not db or not areaToMap or type(questID) ~= "number" then return end
    if turnInCache[questID] == nil then
        local ok, result = pcall(buildTurnIn, questID)
        turnInCache[questID] = ok and result or false
    end
    return turnInCache[questID] or nil
end

-- A quest with nothing to kill, collect or reach (a delivery, or a step of
-- the sleeping bag chain) still has somewhere to go: where it is handed in.
-- That place stands in as its one location, so the map, the tracker and
-- "Show on map" know which zone the quest is in.
local function turnInObjective(questID)
    -- Not when the game itself lists objectives for the quest (a quest new
    -- to Forever that QuestieDB has no objective data for, like Brewer's
    -- Trade): its goal is somewhere else than where it is handed in, and
    -- the map then shows the game's own marker instead.
    if C_QuestLog and C_QuestLog.GetQuestObjectives then
        local ok, objectives = pcall(C_QuestLog.GetQuestObjectives, questID)
        if ok and type(objectives) == "table" and #objectives > 0 then return end
    end
    local places = buildTurnIn(questID)
    if not places then return end
    local labels, byMap, index = {}, {}, {}
    for mapID, points in pairs(places) do
        for _, point in ipairs(points) do
            if not index[point[3]] then
                labels[#labels + 1] = "Turn in: " .. point[3]
                index[point[3]] = #labels
            end
            addZonePoint(byMap, mapID, {point[1], point[2], index[point[3]], 4})
        end
    end
    return {labels, byMap, nil}
end

local function buildObjective(questID)
    local quest = db.Quest
    if not quest.Exists(questID) then return end
    local objectives = quest.GetByIndex(questID, 10)
    local trigger = quest.GetByIndex(questID, 9)
    if type(objectives) ~= "table" and type(trigger) ~= "table" then return turnInObjective(questID) end
    local labels, byMap, patrols, patrolSeen = {}, {}, {}, {}
    for kind = 1, 3 do
        local group = objectives and objectives[kind] or {}
        if type(group) == "table" then
            for _, objective in ipairs(group) do
                local entityID = type(objective) == "table" and objective[1]
                if type(entityID) == "number" then
                    local entity = kind == 1 and db.Npc or kind == 2 and db.Object or db.Item
                    labels[#labels + 1] = entity.GetByIndex(entityID, 1) or "Quest objective"
                    local labelIndex = #labels
                    local sources = {}
                    if kind == 3 then
                        local npcs = db.Item.GetByIndex(entityID, 2) or {}
                        local objects = db.Item.GetByIndex(entityID, 3) or {}
                        if #npcs + #objects <= 80 then
                            for _, id in ipairs(npcs) do sources[#sources + 1] = {"Npc", id} end
                            for _, id in ipairs(objects) do sources[#sources + 1] = {"Object", id} end
                        end
                    else
                        sources[1] = {kind == 1 and "Npc" or "Object", entityID}
                    end
                    local candidates = {}
                    for _, source in ipairs(sources) do
                        local rate = kind == 3 and source[1] == "Npc"
                            and dropRate(entityID, source[2]) or nil
                        -- The mob that drops it, named even when QuestieDB
                        -- has no drop rate for it.
                        local npcName = kind == 3 and source[1] == "Npc"
                            and db.Npc.GetByIndex(source[2], 1) or nil
                        local rank = source[1] == "Npc" and npcRank(source[2]) or nil
                        -- Levels for kill targets, and for drop sources we name.
                        local levels = source[1] == "Npc" and (kind == 1 or npcName)
                            and npcLevels(source[2]) or nil
                        if source[1] == "Npc" then addPatrols(patrols, source[2], patrolSeen) end
                        for mapID, points in pairs(spawnPoints(source[1], source[2]) or {}) do
                            for _, point in ipairs(points) do
                                addZonePoint(candidates, mapID,
                                    {point[1], point[2], rate, npcName, rank, levels})
                            end
                        end
                    end
                    for mapID, points in pairs(candidates) do
                        local occupied, count = {}, 0
                        for _, point in ipairs(points) do
                            local cell = math.floor(point[1] / 2) .. ":" .. math.floor(point[2] / 2)
                            if not occupied[cell] then
                                occupied[cell] = true
                                local row = {round(point[1]), round(point[2]), labelIndex, kind}
                                -- [5] drop rate (may be unknown), [6] the mob.
                                if point[3] then row[5] = point[3] end
                                if point[4] then row[6] = point[4] end
                                -- [7]: NPC rank (1 elite, 2 rare elite, 3 boss, 4 rare).
                                if type(point[5]) == "number" and point[5] > 0 then row[7] = point[5] end
                                -- [8]: NPC level range {min, max}.
                                if point[6] then row[8] = point[6] end
                                addZonePoint(byMap, mapID, row)
                                count = count + 1
                                if count >= 36 then break end
                            end
                        end
                    end
                end
            end
        end
    end
    if type(trigger) == "table" and type(trigger[2]) == "table" then
        labels[#labels + 1] = trigger[1] or "Quest location"
        for areaID, points in pairs(trigger[2]) do
            local mapID = areaToMap[areaID]
            if mapID and type(points) == "table" then
                for index = 1, math.min(#points, 8) do
                    local point = points[index]
                    if validPoint(point) then
                        addZonePoint(byMap, mapID,
                            {round(point[1]), round(point[2]), #labels, 4})
                    end
                end
            end
        end
    end
    -- [3]: patrol paths of the objective's NPCs by map.
    if next(byMap) then return {labels, byMap, next(patrols) and patrols or nil} end
    -- Nothing to kill, collect or reach at all: the hand-in place stands in.
    -- (Objectives without known locations stay as they were: no markers.)
    if #labels == 0 then return turnInObjective(questID) end
end

function live.Objective(questID)
    if not db or not areaToMap or type(questID) ~= "number" then return end
    if objectiveCache[questID] == nil then
        local ok, result = pcall(buildObjective, questID)
        objectiveCache[questID] = ok and result or false
    end
    return objectiveCache[questID] or nil
end

-- Next quest in the chain: id and name, or nil.
local chainCache = {}
function live.NextQuest(questID)
    if not db or type(questID) ~= "number" then return nil end
    if chainCache[questID] == nil then
        local quest, nextID = db.Quest, nil
        local ok, value = pcall(type(quest.nextQuestInChain) == "function"
            and quest.nextQuestInChain or function() return nil end, questID)
        if ok and type(value) == "number" and value > 0 then nextID = value end
        local name
        if nextID then
            local okName, result = pcall(type(quest.name) == "function" and quest.name
                or function(id) return quest.GetByIndex(id, 1) end, nextID)
            if okName and type(result) == "string" then name = result end
        end
        chainCache[questID] = nextID and {nextID, name or ("Quest " .. nextID)} or false
    end
    local entry = chainCache[questID]
    if entry then return entry[1], entry[2] end
end

function live.Status()
    return status
end

function live.State()
    return phase, progress
end

function live.Version()
    local metadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local version
    if metadata then
        local ok, value = pcall(metadata, "QuestieDB", "Version")
        if ok then version = value end
    end
    return tostring(version or "unknown") .. " / contract "
        .. tostring(db and db.contractVersion or "unknown")
end

local function start()
    if scanning or db then return end
    local candidate = _G.LibQuestieDB
    if type(candidate) ~= "table" or type(candidate.RequireContract) ~= "function" then return end
    local ok, compatible = pcall(candidate.RequireContract, 2)
    if not ok or not compatible or not candidate.Npc or not candidate.Quest
        or not candidate.Item or not candidate.Object or not candidate.Support then
        status = "QuestieDB contract is incompatible"
        phase = "error"
        return
    end
    local zones = candidate.Support.Get("ZoneDB")
    local encoded = zones and zones.private and zones.private.uiMapIdToAreaId
    if type(encoded) ~= "string" then
        status = "QuestieDB zone map is unavailable"
        phase = "error"
        return
    end
    local mapped = mapping(encoded)
    if not next(mapped) then
        status, phase = "QuestieDB has no mapped zones", "error"
        return
    end
    local success, ids = pcall(candidate.Npc.GetAllIds)
    if not success or type(ids) ~= "table" then
        status, phase = "QuestieDB NPC index is unavailable", "error"
        return
    end
    local objectsOK, objectIds = pcall(candidate.Object.GetAllIds)
    if not objectsOK or type(objectIds) ~= "table" then objectIds = {} end
    db, areaToMap = candidate, mapped
    scanning = true
    phase, progress = "loading", 0
    objectiveCache = {}
    turnInCache = {}
    dropCache = {}
    status = "Reading QuestieDB locations..."
    local result = {services = {}, givers = {}, quests = {}, prereqs = {}, resources = {}, rares = {}}
    local position, objectPosition = 1, 1
    local seenResources, resourceCount = {}, {}
    local worker = CreateFrame("Frame")
    worker:SetScript("OnUpdate", function(self)
        local okBatch, failure = pcall(function()
            for _ = 1, 20 do
                if position > #ids then break end
                consumeNpc(ids[position], result)
                position = position + 1
            end
            for _ = 1, 20 do
                if objectPosition > #objectIds then break end
                consumeObject(objectIds[objectPosition], result,
                    seenResources, resourceCount)
                objectPosition = objectPosition + 1
            end
        end)
        if not okBatch then
            self:SetScript("OnUpdate", nil)
            scanning, db, areaToMap = false, nil, nil
            objectiveCache = {}
            turnInCache = {}
            status = "QuestieDB read failed: " .. tostring(failure)
            phase = "error"
            return
        end
        local total = #ids + #objectIds
        if total > 0 then
            local done = math.min(position - 1, #ids)
                + math.min(objectPosition - 1, #objectIds)
            progress = math.min(99, math.floor(done * 100 / total))
            status = "Reading QuestieDB locations: " .. progress .. "%"
        end
        if position > #ids and objectPosition > #objectIds then
            self:SetScript("OnUpdate", nil)
            scanning = false
            if not next(result.services) or not next(result.givers) then
                db, areaToMap = nil, nil
                status = "QuestieDB returned no mapped locations"
                phase = "error"
                return
            end
            WalkMapData.services = result.services
            WalkMapData.givers = result.givers
            WalkMapData.quests = result.quests
            WalkMapData.prereqs = result.prereqs
            WalkMapData.resources = result.resources
            WalkMapData.rares = result.rares
            status = "Using QuestieDB locations (" .. tostring(#ids)
                .. " NPCs, " .. tostring(#objectIds) .. " objects scanned)"
            phase, progress = "ready", 100
            if WalkMapExtras and WalkMapExtras.Invalidate then WalkMapExtras.Invalidate() end
            if live.OnReady then live.OnReady() end
        end
    end)
end

local listener = CreateFrame("Frame")
listener:RegisterEvent("PLAYER_LOGIN")
listener:RegisterEvent("ADDON_LOADED")
listener:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_LOGIN" or name == "QuestieDB" then
        start()
        if event == "PLAYER_LOGIN" and phase == "waiting" then
            status, phase = "QuestieDB API is unavailable", "error"
        end
    end
end)
-- QuestieDB normally loads before WalkMap (and is not a hard dependency).
start()
