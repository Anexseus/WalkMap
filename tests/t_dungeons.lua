-- Classic dungeons: the client has no map of them, so WalkMap draws its own
-- floors (WalkMap_Dungeons.lua) and the zone menu picks the floor.
local function inDeadmines(Mock)
    local env = Mock.new({playerMap = 1436})
    env.IsInInstance = function() return true, "party" end
    env.GetInstanceInfo = function() return "The Deadmines", "party", 1, "Normal", 5, 0, false, 36 end
    env.loadAddon({welcomeSeen = true, newsSeen = "1.14.19"}, {welcomeSeen = true})
    env.fire("PLAYER_LOGIN")
    env.fire("PLAYER_ENTERING_WORLD")
    -- In the instance the game gives no position (and Westfall has none either).
    env.C_Map.GetPlayerMapPosition = function() return nil end
    env.WalkMap_Toggle()
    env.tick(0.2, 10)
    return env
end

local function tileFiles(env)
    local files = {}
    for _, region in ipairs(env.WalkMapCore.canvas.__children or {}) do
        local texture = region.walkmapFile
        if type(texture) == "string" and texture:find("Maps\\Dungeons\\", 1, true) then
            files[#files + 1] = texture
        end
    end
    return files
end

return {
    {"Inside The Deadmines the map shows its first floor, not Westfall", function(Mock)
        local env = inDeadmines(Mock)
        Mock.eq(env.WalkMapCore.CurrentMap(), 2000000 + 36 * 100 + 1, "our Deadmines map, floor 1")
        Mock.eq(env.WalkMapDungeons.Title(env.WalkMapCore.CurrentMap()), "The Deadmines - Floor 1", "title")
        local files = tileFiles(env)
        Mock.ok(#files >= 6, "Blizzard's tiles drawn")
        Mock.ok(table.concat(files, " "):find("TheDeadmines1_1", 1, true), "first tile")
        Mock.ok(env.WalkMapCore.status:GetText():find("The Deadmines", 1, true), "status names the dungeon")
    end},
    {"The zone menu lists the floors; picking one shows it", function(Mock)
        local env = inDeadmines(Mock)
        local floors = env.WalkMapDungeons.Floors()
        Mock.eq(#floors, 2, "two floors")
        Mock.eq(floors[1][3], true, "floor 1 chosen")
        Mock.eq(env.WalkMapDungeons.SetFloor(2), true, "floor 2")
        env.tick(0.2, 5)
        Mock.eq(env.WalkMapCore.CurrentMap(), 2000000 + 36 * 100 + 2, "floor 2 drawn")
        Mock.ok(table.concat(tileFiles(env), " "):find("TheDeadmines2_2", 1, true), "floor 2 tiles")
        Mock.eq(env.WalkMapDungeons.SetFloor(9), false, "no floor 9")
        -- From the zone menu: its floor rows, and a click on one.
        env.WalkMapExtras.OpenMapMenu(env.WalkMapCore.mapPickerButton)
        local rowFor
        local function search(frame, depth)
            if depth > 6 or rowFor then return end
            for _, row in ipairs(frame.rows or {}) do
                if row:IsShown() and row.label and row.label:GetText() == "Floor 1" then rowFor = row end
            end
            for _, child in ipairs(frame.__children or {}) do search(child, depth + 1) end
        end
        search(env.UIParent, 0)
        Mock.ok(rowFor, "Floor 1 in the zone menu")
        rowFor:GetScript("OnClick")(rowFor, "LeftButton")
        env.tick(0.2, 5)
        Mock.eq(env.WalkMapCore.CurrentMap(), 2000000 + 36 * 100 + 1, "back on floor 1 from the menu")
    end},
    {"Every tile the data names is shipped, and outside dungeons nothing changes", function(Mock)
        local env = Mock.new({playerMap = 1436})
        env.loadAddon({welcomeSeen = true, newsSeen = "1.14.19"}, {welcomeSeen = true})
        local missing = {}
        for id, entry in pairs(env.WalkMapDungeonMapData) do
            for _, floor in ipairs(entry.floors) do
                Mock.eq(#floor[2], entry.painted and 1 or 12, "tiles a floor in " .. id)
                for _, tile in ipairs(floor[2]) do
                    if type(tile) == "string" then
                        local file = io.open("Maps/Dungeons/" .. (entry.painted and "Painted/" or "") .. tile .. ".blp", "rb")
                        if file then file:close() else missing[#missing + 1] = tile end
                    end
                end
            end
        end
        Mock.eq(table.concat(missing, ", "), "", "no tile missing")
        Mock.eq(env.WalkMapDungeons.Current(), nil, "not in a dungeon: no dungeon map")
    end},
    {"A dungeon with no map (Alcaz Prison): the zone outside, not a black map", function(Mock)
        local env = Mock.new({playerMap = 1436})
        env.loadAddon({welcomeSeen = true, newsSeen = "1.14.19"}, {welcomeSeen = true})
        env.fire("PLAYER_LOGIN")
        env.fire("PLAYER_ENTERING_WORLD")
        env.WalkMap_Toggle()
        env.tick(0.2, 10)
        Mock.eq(env.WalkMapCore.CurrentMap(), 1436, "outside in Westfall")
        -- Into the dungeon: the game's map for it has no position.
        env.IsInInstance = function() return true, "party" end
        env.GetInstanceInfo = function() return "Alcaz Prison", "party", 1, "Normal", 5, 0, false, 9999 end
        env.C_Map.GetBestMapForUnit = function() return 9998 end
        -- The game lists art for it, but nothing to draw (the black map).
        local layers = env.C_Map.GetMapArtLayers
        env.C_Map.GetMapArtLayers = function(id)
            if id == 9998 then return {{layerWidth = 1002, layerHeight = 668, tileWidth = 256, tileHeight = 256}} end
            return layers(id)
        end
        env.C_Map.GetPlayerMapPosition = function() return nil end
        env.tick(0.2, 10)
        Mock.eq(env.WalkMapDungeons.Fallback(), 1436, "the zone you came from")
        Mock.eq(env.WalkMapCore.CurrentMap(), 1436, "the map stays on the zone outside")
        Mock.ok(env.WalkMapCore.status:GetText():find("Alcaz Prison", 1, true), "status names the dungeon")
    end},
    {"Forever's new dungeons: Santiago Reyes' painted maps, with his credit and link", function(Mock)
        local env = Mock.new({playerMap = 1436})
        env.IsInInstance = function() return true, "party" end
        env.GetInstanceInfo = function() return "Excavation Site: Wetlands", "party", 1, "Normal", 5, 0, false, 2984 end
        env.loadAddon({welcomeSeen = true, newsSeen = "1.14.19"}, {welcomeSeen = true})
        env.fire("PLAYER_LOGIN")
        env.fire("PLAYER_ENTERING_WORLD")
        env.C_Map.GetPlayerMapPosition = function() return nil end
        env.WalkMap_Toggle()
        env.tick(0.2, 10)
        local map = env.WalkMapCore.CurrentMap()
        Mock.eq(env.WalkMapDungeons.Title(map), "Excavation Site: Wetlands", "title")
        local art = env.WalkMapDungeons.Art(map)
        Mock.eq(#art.files, 1, "one picture")
        Mock.ok(art.files[1]:find("Painted\\ExcavationSiteWetlands", 1, true), "the painted map")
        Mock.ok(math.abs(art.layer.layerHeight / art.layer.tileHeight - 683 / 1024) < 0.001, "whole map, uncropped")
        local status = env.WalkMapCore.status:GetText()
        Mock.ok(status:find("Santiago Reyes", 1, true) and status:find("patreon.com/c/SantiagoReyesMaps", 1, true),
            "credit and support link: " .. tostring(status))
        local file = io.open("Maps/Dungeons/Painted/ExcavationSiteWetlands.blp", "rb")
        Mock.ok(file, "shipped") if file then file:close() end
    end},
    {"Dungeon maps can be chosen from the zone menu, floors and all", function(Mock)
        local env = Mock.new({playerMap = 1436})
        env.loadAddon({welcomeSeen = true, newsSeen = "1.14.19"}, {welcomeSeen = true})
        env.fire("PLAYER_LOGIN")
        env.WalkMap_Toggle()
        env.tick(0.2, 10)
        local d = env.WalkMapDungeons
        env.WalkMapExtras.OpenMapMenu(env.WalkMapCore.mapPickerButton)
        local section
        local function search(frame, depth)
            if depth > 6 or section then return end
            for _, row in ipairs(frame.rows or {}) do
                local text = row:IsShown() and row.label and row.label:GetText()
                if text and text:find("Dungeon maps", 1, true) then section = row end
            end
            for _, child in ipairs(frame.__children or {}) do search(child, depth + 1) end
        end
        search(env.UIParent, 0)
        Mock.ok(section, "a Dungeon maps section in the zone menu")
        env.WalkMapExtras.CloseMenus()
        local list = d.List()
        Mock.ok(#list >= 20, "classic and painted dungeons listed: " .. #list)
        local deadmines
        for _, entry in ipairs(list) do if entry[2] == "The Deadmines" then deadmines = entry end end
        Mock.ok(deadmines and deadmines[1] == 2003601 and deadmines[3] == 2, "Deadmines, floor 1 of 2")
        Mock.eq(env.WalkMapMaps.Choose(deadmines[1]), true, "chosen outside the dungeon")
        env.tick(0.5, 2)
        Mock.eq(env.WalkMapCore.CurrentMap(), 2003601, "the map shows it")
        Mock.eq(#d.Floors(), 2, "its floors are offered")
        d.ChooseFloor(2)
        env.tick(0.5, 2)
        Mock.eq(env.WalkMapCore.CurrentMap(), 2003602, "floor 2")
        Mock.ok(tostring(env.WalkMapMaps.Name(2003602)):find("Deadmines", 1, true), "named by the dungeon")
        env.WalkMapMaps.Choose(nil)
        env.tick(0.5, 2)
        Mock.eq(env.WalkMapCore.CurrentMap(), 1436, "back to Westfall")
    end},
}
