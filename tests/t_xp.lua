-- WalkMap_QuestInfo.lua: quest experience at the player's level.
local function setup(Mock, level)
    local env = Mock.new({level = level})
    -- [questID] = {questLevel, baseXP}, as QuestieDB ships it.
    local db = {[1] = {20, 390}, [2] = {13, 390}, [3] = {5, 110}, [4] = {-1, 500}, [5] = {22, 975}}
    env.LibQuestieDB = {Support = {Get = function(name) if name == "QuestXP" then return {db = db} end end}}
    env.__showXP = true
    env.WalkMapExtras = {ShowQuestXP = function() return env.__showXP end, Invalidate = function() end}
    env.load("WalkMap_QuestInfo.lua")
    return env, env.WalkMapQuestInfo
end

return {
    {"full XP at the quest's level", function(Mock)
        local _, info = setup(Mock, 20)
        Mock.eq(info.XP(1), 390, "same level")
        Mock.eq(info.XP(5), 975, "quest above the player")
    end},
    {"less XP for quests below the player, rounded like the game", function(Mock)
        local _, info = setup(Mock, 20)
        Mock.eq(info.XP(2), 230, "7 levels below: 234 rounds to 230")
        Mock.eq(info.XP(3), 10, "far below: a tenth, 11 rounds to 10")
    end},
    {"unknown cases give nil", function(Mock)
        local env, info = setup(Mock, 20)
        Mock.eq(info.XP(4), nil, "quest level -1")
        Mock.eq(info.XP(999), nil, "quest not in the table")
        Mock.eq(info.XP("1"), nil, "not a quest ID")
        env.__level = 60
        Mock.eq(info.XP(1), nil, "max level")
        env.__level = 20
        env.LibQuestieDB = nil
        Mock.eq(info.XP(1), nil, "QuestieDB missing")
    end},
    {"XPText respects the Quest XP setting", function(Mock)
        local env, info = setup(Mock, 20)
        Mock.eq(info.XPText(1), "|cff8fb8ff390 XP|r", "shown")
        env.__showXP = false
        Mock.eq(info.XPText(1), "", "setting off")
        Mock.eq(info.XP(1), 390, "XP() itself still works")
    end},
}
