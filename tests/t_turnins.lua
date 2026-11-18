-- WalkMap_TurnIns.lua: "?" markers for ready quests the game puts none on.
local function setup(Mock, ready)
    local env = Mock.new({playerMap = 1413, quests = {
        {header = "Westfall"},
        {id = 79008, title = "... and that note you found", level = 22},
        {id = 12, title = "The People's Militia", level = 12},
        {id = 7, title = "Not Ready", level = 10},
    }})
    local places = {
        [79008] = {[1413] = {{46.36, 73.9, "Nailed Plank"}}},
        [12] = {[1436] = {{56.3, 47.5, "Gryan Stoutmantle"}}},
        [7] = {[1413] = {{10, 10, "Someone"}}},
    }
    env.WalkMapLiveDB = {TurnIn = function(id) return places[id] end}
    env.load("WalkMap_TurnIns.lua")
    return env, function(id) return ready[id] == true end
end

return {
    {"a ready quest the game does not mark gets a marker at its hand-in place", function(Mock)
        local env, isReady = setup(Mock, {[79008] = true, [12] = true})
        local game = {{questID = 500, x = 0.2, y = 0.2}}
        local list = env.WalkMapTurnIns.Add(1413, game, isReady)
        Mock.eq(#list, 2, "one marker added")
        Mock.eq(list[1], game[1], "the game's own entry comes first, untouched")
        Mock.eq(list[2].questID, 79008, "quest")
        Mock.eq(string.format("%.4f", list[2].x), "0.4636", "x as a map fraction")
        Mock.eq(string.format("%.4f", list[2].y), "0.7390", "y as a map fraction")
        Mock.eq(list[2].walkmapTurnIn, "Nailed Plank", "name for the tooltip")
        Mock.eq(#game, 1, "the game's list itself is not changed")
    end},
    {"only on the map where the hand-in is", function(Mock)
        local env, isReady = setup(Mock, {[79008] = true, [12] = true})
        local westfall = env.WalkMapTurnIns.Add(1436, {}, isReady)
        Mock.eq(#westfall, 1, "one marker in Westfall")
        Mock.eq(westfall[1].questID, 12, "the militia quest")
        Mock.eq(#env.WalkMapTurnIns.Add(1431, {}, isReady), 0, "none in Duskwood")
    end},
    {"quests that are not ready, or that the game already marks, are left alone", function(Mock)
        local env, isReady = setup(Mock, {[79008] = true})
        local game = {{questID = 79008, x = 0.5, y = 0.5}}
        Mock.eq(env.WalkMapTurnIns.Add(1413, game, isReady), game, "game marks it: same list back")
        local none = {}
        local _, notReady = setup(Mock, {})
        Mock.eq(env.WalkMapTurnIns.Add(1413, none, notReady), none, "nothing ready: same list back")
    end},
    {"Unlocated: QuestieDB loaded, but no objective places for the quest on this map", function(Mock)
        local env = setup(Mock, {})
        local state = "ready"
        env.WalkMapLiveDB.State = function() return state end
        env.WalkMapLiveDB.Objective = function(id)
            if id == 12 then return {{"Battered Chest"}, {[1436] = {{30, 30, 1, 2}}}} end
        end
        local unlocated = env.WalkMapTurnIns.Unlocated
        Mock.eq(unlocated(98071, 1424), true, "no QuestieDB objectives at all")
        Mock.eq(unlocated(12, 1436), false, "QuestieDB has places on this map")
        Mock.eq(unlocated(12, 1424), true, "places only on another map")
        state = "loading"
        Mock.eq(unlocated(98071, 1424), false, "QuestieDB not ready: the Quest icons setting decides")
        env.WalkMapLiveDB = nil
        Mock.eq(unlocated(98071, 1424), false, "no QuestieDB")
    end},
    {"without QuestieDB nothing is added", function(Mock)
        local env, isReady = setup(Mock, {[79008] = true})
        env.WalkMapLiveDB = nil
        local game = {}
        Mock.eq(env.WalkMapTurnIns.Add(1413, game, isReady), game, "same list back")
    end},
}
