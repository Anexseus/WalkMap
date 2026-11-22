-- Classic dungeons: the client has no map of them, so WalkMap draws its own
-- floors (WalkMap_Dungeons.lua) and the zone menu picks the floor.
local function inDeadmines(Mock)
    local env = Mock.new({playerMap = 1436})
    env.IsInInstance = function() return true, "party" end
    env.GetInstanceInfo = function() return "The Deadmines", "party", 1, "Normal", 5, 0, false, 36 end
    env.loadAddon({welcomeSeen = true, newsSeen = "1.14.11"}, {welcomeSeen = true})
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
        env.loadAddon({welcomeSeen = true, newsSeen = "1.14.11"}, {welcomeSeen = true})
        local missing = {}
        for id, entry in pairs(env.WalkMapDungeonMapData) do
            for _, floor in ipairs(entry.floors) do
                Mock.eq(#floor[2], 12, "12 tiles a floor in " .. id)
                for _, tile in ipairs(floor[2]) do
                    if type(tile) == "string" then
                        local file = io.open("Maps/Dungeons/" .. tile .. ".blp", "rb")
                        if file then file:close() else missing[#missing + 1] = tile end
                    end
                end
            end
        end
        Mock.eq(table.concat(missing, ", "), "", "no tile missing")
        Mock.eq(env.WalkMapDungeons.Current(), nil, "not in a dungeon: no dungeon map")
    end},
}
