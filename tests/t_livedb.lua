-- WalkMap_LiveDB.lua: what WalkMap reads from QuestieDB at login. A small
-- stand-in for LibQuestieDB with one NPC giver, one object giver (the start
-- of the sleeping bag chain) and one herb.
local function setup(Mock)
    local env = Mock.new({playerMap = 1436})
    local function entity(rows)
        return {
            GetByIndex = function(id, field) return rows[id] and rows[id][field] end,
            Exists = function(id) return rows[id] ~= nil end,
            GetAllIds = function()
                local ids = {}
                for id in pairs(rows) do ids[#ids + 1] = id end
                table.sort(ids)
                return ids
            end,
        }
    end
    env.LibQuestieDB = {
        RequireContract = function() return true end,
        Npc = entity({[234] = {[1] = "Gryan Stoutmantle", [7] = {[40] = {{56.3, 47.5}}}, [10] = {12},
            [13] = "A", [14] = "", [15] = 2},
            [523] = {[1] = "Thor", [7] = {[40] = {{56.6, 52.6}}}, [13] = "A", [14] = "Gryphon Master", [15] = 8},
            -- A rare (rank 4) and a rare elite (2), hostile; an ordinary elite (1) is not a rare.
            [573] = {[1] = "Foe Reaper 4000", [4] = 20, [5] = 20, [6] = 4, [7] = {[40] = {{44.4, 33.3}}}},
            [519] = {[1] = "Slark", [4] = 15, [5] = 16, [6] = 2, [7] = {[40] = {{40.1, 80.2}}}},
            [520] = {[1] = "Elite Guard", [4] = 20, [5] = 20, [6] = 1, [7] = {[40] = {{10, 10}}}}}),
        Object = entity({
            [415107] = {[1] = "Burned-Out Remains", [2] = {79008}, [4] = {[40] = {{37.41, 50.7}}}},
            [1617] = {[1] = "Silverleaf", [4] = {[40] = {{50, 50}}}},
            [999] = {[1] = "Old Barrel", [4] = {[40] = {{10, 10}}}},
            [998] = {[1] = "Torn Poster", [2] = {424242}, [4] = {[40] = {{20, 20}}}},
            [417072] = {[1] = "Nailed Plank", [3] = {79008}, [4] = {[17] = {{46.39, 73.82}}}},
            [415106] = {[1] = "Burned-Out Remains", [3] = {79008}, [4] = {[17] = {{46.36, 73.9}}}},
            [2843] = {[1] = "Battered Chest", [4] = {[40] = {{30, 30}, {31, 31}, {60, 60}}}},
        }),
        Quest = entity({
            [79008] = {[1] = "... and that note you found", [3] = {nil, {415106, 417072}},
                [4] = 14, [5] = 22, [10] = {}, [22] = 79192},
            -- Kill quest with known spawns, handed in to an NPC.
            [12] = {[1] = "The People's Militia", [3] = {{234}}, [4] = 9, [5] = 12,
                [10] = {nil, {{2843}}}},
            -- Objectives QuestieDB has no locations for.
            [13] = {[1] = "No Locations", [3] = {{234}}, [10] = {{{555555}}}},
            -- An item dropped by a mob QuestieDB has no drop rate for.
            [14] = {[1] = "Fangs", [3] = {{234}}, [10] = {nil, nil, {{7073}}}},
        }),
        Item = entity({[7073] = {[1] = "Broken Fang", [2] = {519}, [3] = {}}}),
        Support = {Get = function(name)
            if name == "ZoneDB" then return {private = {uiMapIdToAreaId = "return { [1436] = 40, [1413] = 17, }"}} end
        end},
    }
    env.load("WalkMap_Data.lua")
    env.load("WalkMap_LiveDB.lua")
    env.tick(2, 40)
    return env
end

return {
    {"an object that starts a quest becomes a quest giver", function(Mock)
        local env = setup(Mock)
        Mock.eq((env.WalkMapLiveDB.State()), "ready", "QuestieDB read: " .. tostring(env.WalkMapLiveDB.Status()))
        local byName = {}
        for _, entry in ipairs(env.WalkMapData.givers[1436] or {}) do byName[entry[3]] = entry end
        local remains = byName["Burned-Out Remains"]
        Mock.ok(remains, "Burned-Out Remains is a giver in Westfall")
        Mock.eq(remains[1], 37.41, "x") Mock.eq(remains[2], 50.7, "y")
        Mock.eq(remains[4], "AH", "no faction of its own")
        Mock.eq(remains[5][1], 79008, "offers the sleeping bag chain's first quest")
        Mock.eq(env.WalkMapData.quests[79008].name, "... and that note you found", "quest row read")
        Mock.eq(env.WalkMapData.quests[79008][2], 22, "quest level")
    end},
    {"NPC givers, herbs and plain objects are unchanged", function(Mock)
        local env = setup(Mock)
        local givers, names = env.WalkMapData.givers[1436], {}
        for _, entry in ipairs(givers) do names[#names + 1] = entry[3] end
        table.sort(names)
        Mock.eq(table.concat(names, ", "), "Burned-Out Remains, Gryan Stoutmantle", "givers")
        local resources = env.WalkMapData.resources[1436]
        Mock.eq(#resources, 1, "one resource node")
        Mock.eq(resources[1][3], "Silverleaf", "the herb")
    end},
    {"TurnIn: where a quest is handed in, NPCs and objects", function(Mock)
        local env = setup(Mock)
        local live = env.WalkMapLiveDB
        local chain = live.TurnIn(79008)
        Mock.ok(chain and chain[1413], "sleeping bag step 1 is handed in in The Barrens")
        Mock.eq(#chain[1413], 1, "two finishers on the same spot count once")
        Mock.eq(chain[1413][1][1], 46.36, "x") Mock.eq(chain[1413][1][2], 73.9, "y")
        Mock.eq(chain[1436], nil, "nothing in Westfall")
        local militia = live.TurnIn(12)
        Mock.eq(militia[1436][1][3], "Gryan Stoutmantle", "NPC finisher")
        Mock.eq(live.TurnIn(424242), nil, "unknown quest")
    end},
    {"a quest with no objectives gets its hand-in place as its location", function(Mock)
        local env = setup(Mock)
        local data = env.WalkMapLiveDB.Objective(79008)
        Mock.ok(data and data[2][1413], "located in The Barrens")
        Mock.eq(data[1][1], "Turn in: Burned-Out Remains", "label")
        Mock.eq(data[2][1413][1][4], 4, "drawn as a place marker")
        -- So the tracker counts it as a Barrens quest while you are there.
        env.WalkMapCharacterSettings = {}
        env.load("WalkMap_Maps.lua")
        Mock.eq(env.WalkMapMaps.QuestHere(1413, "Westfall", false, data), true, "tracked in The Barrens")
    end},
    {"no hand-in stand-in when the game lists objectives QuestieDB lacks", function(Mock)
        local env = setup(Mock)
        -- Brewer's Trade: QuestieDB knows who gives and takes it, nothing else.
        env.__quests = {{header = "Westfall"}, {id = 79008, title = "x", objectives = {
            {text = "Fallrook Varietal delivered to Dun Garok: 0/1", type = "event", finished = false},
        }}}
        Mock.eq(env.WalkMapLiveDB.Objective(79008), nil, "no stand-in location")
        Mock.ok(env.WalkMapLiveDB.TurnIn(79008), "the hand-in place itself is still known")
    end},
    {"quests with real objectives keep them", function(Mock)
        local env = setup(Mock)
        local data = env.WalkMapLiveDB.Objective(12)
        Mock.eq(data[1][1], "Battered Chest", "objective label")
        Mock.eq(#data[2][1436], 2, "objective spots (two close ones merged)")
        Mock.eq(env.WalkMapLiveDB.Objective(13), nil, "objectives without locations: still no markers")
    end},
    {"a dropped item names the mob and its level, even without a drop rate", function(Mock)
        local env = setup(Mock)
        local data = env.WalkMapLiveDB.Objective(14)
        Mock.eq(data[1][1], "Broken Fang", "objective label")
        local point = data[2][1436][1]
        Mock.eq(point[5], nil, "no drop rate known")
        Mock.eq(point[6], "Slark", "dropped by Slark")
        Mock.eq(point[8][1], 15, "his level") Mock.eq(point[8][2], 16, "level range")
    end},
    {"an object whose quest QuestieDB does not know gets no marker", function(Mock)
        local env = setup(Mock)
        for _, entry in ipairs(env.WalkMapData.givers[1436]) do
            Mock.ok(entry[3] ~= "Torn Poster", "unknown quest: no giver")
        end
    end},
    {"rare mobs and rare elites, whatever their faction, for Places > Rare mobs", function(Mock)
        local env = setup(Mock)
        local rares, byName = env.WalkMapData.rares[1436] or {}, {}
        for _, entry in ipairs(rares) do byName[entry[3]] = entry end
        Mock.eq(#rares, 2, "two rares in Westfall")
        Mock.eq(byName["Foe Reaper 4000"][4], 4, "rare")
        Mock.eq(byName["Foe Reaper 4000"][5], 20, "level")
        Mock.eq(byName["Slark"][4], 2, "rare elite")
        Mock.eq(byName["Slark"][6], 16, "max level")
        Mock.eq(byName["Elite Guard"], nil, "an ordinary elite is not listed")
    end},
}
