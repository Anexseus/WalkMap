-- WalkMap_Maps.lua: map levels, zone level ranges and which quests belong
-- to a zone.
local function setup(Mock, options)
    local env = Mock.new(options)
    env.WalkMapCharacterSettings = {}
    env.load("WalkMap_Data.lua")
    env.load("WalkMap_Maps.lua")
    return env, env.WalkMapMaps
end

return {
    {"Parent: zone -> continent -> world -> nothing", function(Mock)
        local _, maps = setup(Mock)
        local id, name = maps.Parent(1436)
        Mock.eq(id, 1415, "Westfall's parent")
        Mock.eq(name, "Eastern Kingdoms", "parent name")
        Mock.eq(maps.Parent(1415), 947, "continent's parent")
        Mock.eq(maps.Parent(947), nil, "world has no parent with art")
        Mock.eq(maps.Parent(nil), nil, "no map")
        Mock.eq(maps.Parent(99999), nil, "unknown map")
    end},
    {"Parent skips a level without artwork", function(Mock)
        local env, maps = setup(Mock)
        env.__maps[2000] = {name = "No art", type = 6, parent = 1415, art = false}
        env.__maps[2001] = {name = "Cave", type = 5, parent = 2000}
        Mock.eq(maps.Parent(2001), 1415, "nearest ancestor with art")
    end},
    {"LevelRange: table, cities, client fallback", function(Mock)
        local env, maps = setup(Mock)
        local low, high = maps.LevelRange(1431)
        Mock.eq(low, 18, "Duskwood low") Mock.eq(high, 30, "Duskwood high")
        Mock.eq(maps.LevelRange(1453), nil, "Stormwind has no range")
        env.C_Map.GetMapLevels = function(id) if id == 3000 then return 62, 64 end return 0, 0 end
        low, high = maps.LevelRange(3000)
        Mock.eq(low, 62, "client low") Mock.eq(high, 64, "client high")
        Mock.eq(maps.LevelRange(1453), nil, "client zeros ignored")
        low = maps.LevelRange(1436)
        Mock.eq(low, 10, "table wins over the client")
    end},
    {"LevelColor follows the player's level", function(Mock)
        local _, maps = setup(Mock)
        local function color(level) return table.concat({maps.LevelColor(18, 30, level)}, ",") end
        Mock.eq(color(10), "1,0.25,0.2", "far above the player: red")
        Mock.eq(color(15), "1,0.55,0.2", "just above: orange")
        Mock.eq(color(18), "1,0.9,0.2", "low end fits: yellow")
        Mock.eq(color(30), "1,0.9,0.2", "high end fits: yellow")
        Mock.eq(color(33), "0.35,0.85,0.35", "just outgrown: green")
        Mock.eq(color(40), "0.62,0.62,0.62", "long outgrown: grey")
        Mock.eq(color(nil), "1,0.82,0", "unknown level: gold")
    end},
    {"NameWithLevels", function(Mock)
        local env, maps = setup(Mock, {level = 20})
        Mock.eq(maps.NameWithLevels(1431, "Duskwood"), "Duskwood |cffffe633(18-30)|r", "in range")
        Mock.eq(maps.NameWithLevels(1453, "Stormwind City"), "Stormwind City", "no range")
        env.__level = 5
        Mock.eq(maps.NameWithLevels(1431), "Duskwood |cffff4033(18-30)|r", "name looked up, red")
    end},
    {"IdByName finds zones, not continents", function(Mock)
        local _, maps = setup(Mock)
        Mock.eq(maps.IdByName("Duskwood"), 1431, "zone")
        Mock.eq(maps.IdByName("Eastern Kingdoms"), nil, "continent")
        Mock.eq(maps.IdByName("Warrior"), nil, "class header")
    end},
    {"QuestHere and QuestNearby (Westfall next to Duskwood)", function(Mock)
        local _, maps = setup(Mock)
        local here, near = maps.QuestHere, maps.QuestNearby
        local W = 1436
        -- Filed under this zone.
        Mock.eq(here(W, "Westfall", true, nil), true, "own zone here")
        Mock.eq(near(W, "Westfall", true, nil), false, "own zone is not nearby")
        -- A Duskwood quest inside Westfall's map rectangle.
        Mock.eq(here(W, "Duskwood", true, nil), false, "neighbour not here")
        Mock.eq(near(W, "Duskwood", true, nil), true, "neighbour on the map is nearby")
        -- QuestieDB places it in both zones: still the neighbour's.
        local both = {nil, {[1431] = {}, [1436] = {}}}
        Mock.eq(here(W, "Duskwood", false, both), false, "points in both: not here")
        Mock.eq(near(W, "Duskwood", false, both), true, "points in both: nearby")
        -- QuestieDB places it only here: it counts as this zone's.
        local onlyHere = {nil, {[1436] = {}}}
        Mock.eq(here(W, "Duskwood", false, onlyHere), true, "points only here: here")
        Mock.eq(near(W, "Duskwood", false, onlyHere), false, "points only here: not nearby")
        -- Nothing places it on this map.
        Mock.eq(near(W, "Duskwood", false, {nil, {[1431] = {}}}), false, "elsewhere: not nearby")
        Mock.eq(near(W, "Duskwood", false, nil), false, "no data: not nearby")
        -- Headers that are not zones behave as before.
        Mock.eq(here(W, "Warrior", true, nil), true, "class header on map: here")
        Mock.eq(near(W, "Warrior", true, nil), false, "class header: never nearby")
        Mock.eq(near(nil, "Duskwood", true, nil), false, "no map")
    end},
}
