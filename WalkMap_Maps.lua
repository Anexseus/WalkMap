-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- Browse client-provided zone art without changing the game's world map.
WalkMapMaps = {}
local maps = WalkMapMaps
local settings = WalkMapCharacterSettings
local lastPlayerZone, catalogue, catalogueAt, changed

local function info(id)
    if not id or not C_Map or not C_Map.GetMapInfo then return end
    local ok, result = pcall(C_Map.GetMapInfo, id)
    return ok and result or nil
end

local function hasArt(id)
    if not C_Map or not C_Map.GetMapArtLayers or not C_Map.GetMapArtLayerTextures then return false end
    local ok, layers = pcall(C_Map.GetMapArtLayers, id)
    if not ok or not layers or not layers[1] then return false end
    local ready, files = pcall(C_Map.GetMapArtLayerTextures, id, 1)
    return ready and files and #files > 0 or false
end

local function playerPosition(id)
    if not C_Map.GetPlayerMapPosition then return false end
    local ok, position = pcall(C_Map.GetPlayerMapPosition, id, "player")
    if not ok or not position then return false end
    local valid, x, y = pcall(position.GetXY, position)
    return valid and type(x) == "number" and type(y) == "number"
        and x >= 0 and x <= 1 and y >= 0 and y <= 1
end

function maps.CurrentZone()
    if not C_Map or not C_Map.GetBestMapForUnit then return lastPlayerZone end
    local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
    if not ok or not id then return lastPlayerZone end
    local candidate, kinds = info(id), Enum and Enum.UIMapType
    local broad = candidate and kinds and (candidate.mapType == kinds.Continent or candidate.mapType == kinds.World)
    if lastPlayerZone and id ~= lastPlayerZone and playerPosition(lastPlayerZone)
        and (broad or not playerPosition(id) or not hasArt(id)) then return lastPlayerZone end
    lastPlayerZone = id
    return id
end

function maps.Selected() return type(settings.browsedMapID) == "number" and settings.browsedMapID or nil end

function maps.Choose(id)
    if id and not hasArt(id) then return false end
    settings.browsedMapID = id
    if changed then changed() end
    return true
end

function maps.Init(callback) changed = callback end

local function regionFor(id)
    local current, visited = info(id), {}
    local continent = Enum and Enum.UIMapType and Enum.UIMapType.Continent
    for _ = 1, 12 do
        if not current or visited[current.mapID] then break end
        visited[current.mapID] = true
        if current.mapID == 1414 or current.mapID == 1415
            or (continent and current.mapType == continent) then return current end
        current = info(current.parentMapID)
    end
    return {mapID = 0, name = "Other regions"}
end

local function buildCatalogue()
    local zones, roots, visited = {}, {[947] = true, [1414] = true, [1415] = true}, {}
    local player = maps.CurrentZone()
    local current = info(player)
    for _ = 1, 12 do
        if not current or visited[current.mapID] then break end
        visited[current.mapID] = true
        roots[current.mapID] = true
        current = info(current.parentMapID)
    end
    local types = Enum and Enum.UIMapType
    local function offer(id)
        local entry = info(id)
        if not entry or not entry.name or zones[id] then return end
        if types and (entry.mapType == types.World or entry.mapType == types.Continent
            or entry.mapType == types.Cosmic) then return end
        -- Dungeons have their own groups; keep only the one you stand in here.
        if types and entry.mapType == types.Dungeon and id ~= player then return end
        if hasArt(id) then zones[id] = entry end
    end
    if C_Map and C_Map.GetMapChildrenInfo then
        for root in pairs(roots) do
            local ok, children = pcall(C_Map.GetMapChildrenInfo, root, types and types.Zone or nil, true)
            if ok and type(children) == "table" then
                for _, child in ipairs(children) do offer(child.mapID) end
            end
        end
    end
    for _, source in ipairs({"services", "givers", "resources"}) do
        for id in pairs(WalkMapData and WalkMapData[source] or {}) do offer(id) end
    end
    offer(player);offer(maps.Selected())
    local byRegion = {}
    for id, entry in pairs(zones) do
        local parent = regionFor(id)
        local group = byRegion[parent.mapID]
        if not group then group = {name = parent.name, zones = {}};byRegion[parent.mapID] = group end
        group.zones[#group.zones + 1] = {id, entry.name}
    end
    local result = {}
    for _, group in pairs(byRegion) do
        table.sort(group.zones, function(a, b) return a[2] < b[2] end)
        result[#result + 1] = group
    end
    table.sort(result, function(a, b) return a.name < b.name end)

    -- World and continents first: Azeroth plus every continent with art.
    local world = {name = "World", zones = {}, broad = true}
    local seenBroad = {}
    local function offerBroad(id)
        local entry = info(id)
        if entry and entry.name and not seenBroad[id] and hasArt(id) then
            seenBroad[id] = true
            world.zones[#world.zones + 1] = {id, entry.name}
        end
    end
    offerBroad(947)
    if C_Map and C_Map.GetMapChildrenInfo and types then
        local ok, children = pcall(C_Map.GetMapChildrenInfo, 947, types.Continent, false)
        if ok and type(children) == "table" then
            for _, child in ipairs(children) do offerBroad(child.mapID) end
        end
    end
    offerBroad(1415);offerBroad(1414)
    table.sort(world.zones, function(a, b)
        if a[1] == 947 or b[1] == 947 then return a[1] == 947 end
        return a[2] < b[2]
    end)
    if #world.zones > 0 then table.insert(result, 1, world) end

    -- Dungeons, grouped by continent. Floors of one dungeon get their names.
    if C_Map and C_Map.GetMapChildrenInfo and types and types.Dungeon then
        local seenDungeon = {}
        for _, continentID in ipairs({1415, 1414}) do
            local continentInfo = info(continentID)
            local group = {name = "Dungeons: " .. (continentInfo and continentInfo.name or tostring(continentID)), zones = {}}
            local ok, children = pcall(C_Map.GetMapChildrenInfo, continentID, types.Dungeon, true)
            if ok and type(children) == "table" then
                for _, child in ipairs(children) do
                    local id = child.mapID
                    if id and not seenDungeon[id] and hasArt(id) then
                        seenDungeon[id] = true
                        local name = child.name or (info(id) or {}).name or tostring(id)
                        if C_Map.GetMapGroupID and C_Map.GetMapGroupMembersInfo then
                            local okGroup, groupID = pcall(C_Map.GetMapGroupID, id)
                            local okMembers, members = okGroup and groupID
                                and pcall(C_Map.GetMapGroupMembersInfo, groupID)
                            if okMembers and type(members) == "table" and #members > 1 then
                                for _, member in ipairs(members) do
                                    if member.mapID == id and member.name and member.name ~= "" then
                                        name = name .. ": " .. member.name
                                    end
                                end
                            end
                        end
                        group.zones[#group.zones + 1] = {id, name}
                    end
                end
            end
            table.sort(group.zones, function(a, b) return a[2] < b[2] end)
            if #group.zones > 0 then result[#result + 1] = group end
        end
    end
    return result
end

-- World and continent maps: the player's position is valid on them too.
function maps.IsBroad(id)
    local entry = info(id)
    local types = Enum and Enum.UIMapType
    return entry and types and (entry.mapType == types.World or entry.mapType == types.Continent) or false
end

function maps.MenuGroups()
    local now = GetTime and GetTime() or 0
    if not catalogue or not catalogueAt or now - catalogueAt > 30 then
        catalogue, catalogueAt = buildCatalogue(), now
    end
    local groups = {}
    -- Existing WalkMap menus have two levels. Split large continents into
    -- bounded pages rather than putting a tall zone list outside the screen.
    for _, region in ipairs(catalogue) do
        local pages = math.ceil(#region.zones / 16)
        for page = 1, pages do
            local zones = {}
            for i = (page - 1) * 16 + 1, math.min(page * 16, #region.zones) do zones[#zones + 1] = region.zones[i] end
            -- name keeps the old "(1/2)" form for debug output; menus show
            -- region plus the page's first-last initials, e.g. "A - L".
            local range
            if pages > 1 and #zones > 0 then
                local first = tostring(zones[1][2] or ""):sub(1, 1):upper()
                local last = tostring(zones[#zones][2] or ""):sub(1, 1):upper()
                range = first == last and first or (first .. " - " .. last)
            end
            groups[#groups + 1] = {name = region.name .. (pages > 1 and (" (" .. page .. "/" .. pages .. ")") or ""),
                region = region.name, range = range, zones = zones}
        end
    end
    return groups
end

-- Zone map ID for a zone name (as quest-log headers use), from the catalogue.
-- nil when the name is not a zone (e.g. class or profession headers).
-- Dungeon headers are left out: their quests may still show in the zone
-- around the entrance, as before.
local byName, byNameFrom
function maps.IdByName(name)
    if type(name) ~= "string" or name == "" then return nil end
    maps.MenuGroups()
    if byNameFrom ~= catalogue then
        byName, byNameFrom = {}, catalogue
        for _, region in ipairs(catalogue or {}) do
            local regionName = tostring(region.name or "")
            if regionName ~= "World" and regionName:sub(1, 9) ~= "Dungeons:" then
                for _, zone in ipairs(region.zones or {}) do
                    if zone[2] and not byName[zone[2]] then byName[zone[2]] = zone[1] end
                end
            end
        end
    end
    return byName[name]
end

-- Does a quest belong on this map? The game's GetQuestsOnMap also lists
-- quests whose objectives fall inside the map's rectangle, which for zone
-- maps covers parts of the neighbours (Westfall's map shows western
-- Duskwood). So when the quest-log header names another zone, the game's
-- list does not count, and QuestieDB points count only when the quest has
-- none in its own zone.
function maps.QuestHere(mapID, header, onMap, data)
    if not mapID then return false end
    local points = data and data[2]
    local headerID = header and maps.IdByName(header)
    if headerID and headerID ~= mapID then
        if not (points and points[mapID] ~= nil) then return false end
        return points[headerID] == nil
    end
    return onMap == true or (points and points[mapID] ~= nil) or false
end

-- Quests filed under a neighbouring zone that the game (or QuestieDB) also
-- places on this map, e.g. Duskwood quests around Raven Hill while you are
-- in Westfall. QuestHere keeps them out of this zone's own list; the tracker
-- can show them in a "Nearby" group of their own.
function maps.QuestNearby(mapID, header, onMap, data)
    if not mapID then return false end
    local headerID = header and maps.IdByName(header)
    if not headerID or headerID == mapID then return false end
    if maps.QuestHere(mapID, header, onMap, data) then return false end
    local points = data and data[2]
    return onMap == true or (points and points[mapID] ~= nil) or false
end

-- One level up: the continent for a zone, the world for a continent. nil at
-- the top, or when nothing above this map has artwork.
function maps.Parent(id)
    local entry, visited = info(id), {}
    local types = Enum and Enum.UIMapType
    for _ = 1, 6 do
        if not entry or visited[entry.mapID] then return nil end
        visited[entry.mapID] = true
        local parent = info(entry.parentMapID)
        if not parent or not parent.mapID or parent.mapID == 0 then return nil end
        if types and parent.mapType == types.Cosmic then return nil end
        if hasArt(parent.mapID) then return parent.mapID, parent.name end
        entry = parent
    end
    return nil
end

-- Level ranges of the open-world zones, by zone map ID (the classic world
-- that Forever uses). Cities and zones without a range are left out.
local ZONE_LEVELS = {
    [1411] = {1, 10}, [1412] = {1, 10}, [1413] = {10, 25}, [1416] = {30, 40},
    [1417] = {30, 40}, [1418] = {35, 45}, [1419] = {45, 55}, [1420] = {1, 10},
    [1421] = {10, 20}, [1422] = {51, 58}, [1423] = {53, 60}, [1424] = {20, 30},
    [1425] = {40, 50}, [1426] = {1, 10}, [1427] = {43, 50}, [1428] = {50, 58},
    [1429] = {1, 10}, [1430] = {55, 60}, [1431] = {18, 30}, [1432] = {10, 20},
    [1433] = {15, 25}, [1434] = {30, 45}, [1435] = {35, 45}, [1436] = {10, 20},
    [1437] = {20, 30}, [1438] = {1, 10}, [1439] = {10, 20}, [1440] = {18, 30},
    [1441] = {25, 35}, [1442] = {15, 27}, [1443] = {30, 40}, [1444] = {40, 50},
    [1445] = {35, 45}, [1446] = {40, 50}, [1447] = {45, 55}, [1448] = {48, 55},
    [1449] = {48, 55}, [1451] = {55, 60}, [1452] = {53, 60},
    -- New in Forever (map IDs as QuestieDB's Forever zone table lists them):
    -- Mount Hyjal, Zephras Isle, Riverglades, Shen'dralas.
    [2482] = {55, 60}, [2521] = {1, 12}, [2548] = {35, 45}, [2652] = {35, 45},
}

-- Lowest and highest level a zone is meant for, or nil when unknown. The
-- table above comes first; the client's own figures cover other maps.
function maps.LevelRange(id)
    local known = id and ZONE_LEVELS[id]
    if known then return known[1], known[2] end
    if id and C_Map and C_Map.GetMapLevels then
        local ok, low, high = pcall(C_Map.GetMapLevels, id)
        if ok and type(low) == "number" and type(high) == "number" and low > 0 and high >= low then
            return low, high
        end
    end
    -- Zones new in Forever: by name (WalkMapExtras' list).
    if id and WalkMapExtras and WalkMapExtras.ZoneLevelRange and maps.Name then
        local ok, name = pcall(maps.Name, id)
        if ok then
            local low, high = WalkMapExtras.ZoneLevelRange(name)
            if low then return low, high end
        end
    end
    return nil
end

-- Colour for a zone's level range at a player level: red when the zone is
-- well above you, orange just above, yellow when you fit, green just below
-- and grey when you have outgrown it.
function maps.LevelColor(low, high, level)
    if not (low and high and level) then return 1, 0.82, 0 end
    if level < low then
        if low - level >= 5 then return 1, 0.25, 0.2 end
        return 1, 0.55, 0.2
    end
    if level <= high then return 1, 0.9, 0.2 end
    if level - high <= 5 then return 0.35, 0.85, 0.35 end
    return 0.62, 0.62, 0.62
end

-- "Duskwood |cff..(18-30)|r" for labels; just the name without a range.
function maps.NameWithLevels(id, name)
    name = name or maps.Name(id)
    local low, high = maps.LevelRange(id)
    if not low then return name end
    local level = UnitLevel and UnitLevel("player") or nil
    local r, g, b = maps.LevelColor(low, high, type(level) == "number" and level > 0 and level or nil)
    return string.format("%s |cff%02x%02x%02x(%d-%d)|r", name,
        math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5), low, high)
end

function maps.Name(id)
    local entry = info(id)
    return entry and entry.name or tostring(id or "Current zone")
end
