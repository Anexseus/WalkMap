-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- Maps inside the classic dungeons. The Forever client has no map of them and
-- gives no position there, so the large map showed the zone outside. Inside
-- one of them WalkMap now draws the dungeon's own floors (WalkMap_DungeonMapData.lua,
-- Blizzard's artwork shipped in Maps/Dungeons) under a map ID of its own;
-- the zone menu picks the floor. Dungeons the client has a map for (with
-- your position) keep the game's map.
WalkMapDungeons = {}
local dungeons = WalkMapDungeons

local BASE = 2000000           -- our map IDs: BASE + instance ID * 100 + floor
local FOLDER = "Interface\\AddOns\\WalkMap\\Maps\\Dungeons\\"
local LAYER = {layerWidth = 1002, layerHeight = 668, tileWidth = 256, tileHeight = 256}
-- Painted maps: one 1024 px picture, the map in its top 1024 x 683, shown
-- whole with its watermark (the tile height makes the renderer use exactly
-- that part).
local PAINTED_LAYER = {layerWidth = 1002, layerHeight = 668, tileWidth = 1002, tileHeight = 668 * 1024 / 683}
local CREDIT = "Map by Santiago Reyes - patreon.com/c/SantiagoReyesMaps"
local floorChosen = {}         -- instance ID -> floor, for this session

local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g, h end
end

local function normalize(name)
    return (type(name) == "string" and name or ""):lower():gsub("^the%s+", ""):gsub("[^%w]", "")
end

-- The dungeon you stand in, from its instance ID or its name.
local function instanceHere()
    if call(IsInInstance) ~= true then return nil end
    local name, _, _, _, _, _, _, instanceID = call(GetInstanceInfo)
    local data = WalkMapDungeonMapData or {}
    if type(instanceID) == "number" and data[instanceID] then return instanceID, name end
    local wanted = normalize(name)
    if wanted == "" then return nil end
    for id, entry in pairs(data) do
        for _, known in ipairs(entry.names or {}) do
            if normalize(known) == wanted then return id, name end
        end
    end
end

-- Whether the game has its own map with your position here; then that one wins.
local function gameMapWorks()
    if not (C_Map and C_Map.GetBestMapForUnit) then return false end
    local best = call(C_Map.GetBestMapForUnit, "player")
    if type(best) ~= "number" then return false end
    local layers = call(C_Map.GetMapArtLayers, best)
    if not (layers and layers[1]) then return false end
    local position = call(C_Map.GetPlayerMapPosition, best, "player")
    if not (position and position.GetXY) then return false end
    local x, y = call(position.GetXY, position)
    return type(x) == "number" and type(y) == "number"
end

local function split(mapID)
    if type(mapID) ~= "number" or mapID < BASE then return nil end
    local instanceID, floor = math.floor((mapID - BASE) / 100), (mapID - BASE) % 100
    local entry = WalkMapDungeonMapData and WalkMapDungeonMapData[instanceID]
    if not entry or not entry.floors[floor] then return nil end
    return instanceID, floor, entry
end

function dungeons.IsDungeonMap(mapID) return split(mapID) ~= nil end

-- The last zone you stood in outside (map art and a position), for
-- dungeons WalkMap has no map of.
local lastOutside
local function noteOutside()
    if call(IsInInstance) == true or not (C_Map and C_Map.GetBestMapForUnit) then return end
    if gameMapWorks() then lastOutside = call(C_Map.GetBestMapForUnit, "player") end
end

-- Inside a dungeon with no map at all - not one of ours, and the game's
-- has no position (Forever's newer dungeons such as Excavation Site:
-- Wetlands): the zone you came from, so the map is not left black.
function dungeons.Fallback()
    noteOutside()
    if call(IsInInstance) ~= true or instanceHere() or gameMapWorks() then return nil end
    if lastOutside then return lastOutside end
    -- Logged in inside: the zone the game files the dungeon under.
    local best = C_Map and call(C_Map.GetBestMapForUnit, "player")
    local info = best and call(C_Map.GetMapInfo, best)
    local parent = info and info.parentMapID
    if type(parent) == "number" and parent > 0 and call(C_Map.GetMapArtLayers, parent) then return parent end
end

-- Our map ID for the dungeon you are in (its chosen floor), or nil.
function dungeons.Current()
    local instanceID = instanceHere()
    if not instanceID or gameMapWorks() then return nil end
    local entry = WalkMapDungeonMapData[instanceID]
    local floor = floorChosen[instanceID] or 1
    if not entry.floors[floor] then floor = 1 end
    return BASE + instanceID * 100 + floor
end

-- Art for one of our map IDs: the layer (C_Map.GetMapArtLayers' shape) and
-- the tile files, or nil.
function dungeons.Art(mapID)
    local _, floor, entry = split(mapID)
    if not entry then return nil end
    local files = {}
    local folder = entry.painted and (FOLDER .. "Painted\\") or FOLDER
    for i, tile in ipairs(entry.floors[floor][2]) do
        files[i] = type(tile) == "number" and tile or (folder .. tile)
    end
    return {layer = entry.painted and PAINTED_LAYER or LAYER, files = files}
end

-- "Map by Santiago Reyes - ..." on his painted maps, else nil.
function dungeons.Credit(mapID)
    local _, _, entry = split(mapID)
    return entry and entry.painted and CREDIT or nil
end

-- "Shadowfang Keep - Floor 3"
function dungeons.Title(mapID)
    local instanceID, floor, entry = split(mapID)
    if not entry then return nil end
    local hereID, hereName = instanceHere()
    local name = (hereID == instanceID and type(hereName) == "string" and hereName ~= "" and hereName)
        or entry.names[1]
    if #entry.floors < 2 then return name end
    return name .. " - " .. entry.floors[floor][1]
end

-- For the zone menu: {{floor, label, chosen}, ...} while in a dungeon with
-- more than one floor.
function dungeons.Floors()
    local current = dungeons.Current()
    local instanceID, floor, entry = split(current)
    local list = {}
    if not entry or #entry.floors < 2 then return list end
    for i, f in ipairs(entry.floors) do list[#list + 1] = {i, f[1], i == floor} end
    return list, instanceID
end

function dungeons.SetFloor(floor)
    local instanceID = instanceHere()
    local entry = instanceID and WalkMapDungeonMapData[instanceID]
    if not entry or not entry.floors[floor] then return false end
    floorChosen[instanceID] = floor
    return true
end

function dungeons.Status()
    local instanceID, name = instanceHere()
    if not instanceID then return "not in a mapped dungeon" end
    return ("%s (instance %d), %d floors, showing %s"):format(tostring(name), instanceID,
        #WalkMapDungeonMapData[instanceID].floors,
        gameMapWorks() and "the game's map" or ("floor " .. (floorChosen[instanceID] or 1)))
end
