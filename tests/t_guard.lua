-- WalkMap_GameMapGuard.lua: the game's quest log stops listening to quest
-- log updates while the game's map is closed, in controller mode only.
local function start(Mock, gamepad)
    local env = Mock.new({playerMap = 1436, quests = {{header = "Westfall"}, {id = 101, title = "Westfall Stew", level = 13}}})
    env.InputUtil = {IsGamepadUIEnabled = function() return env.__gamepad end}
    env.__gamepad = gamepad
    env.WorldMapFrame = env.CreateFrame("Frame", "WorldMapFrame", env.UIParent)
    env.QuestMapFrame = env.CreateFrame("Frame", "QuestMapFrame", env.WorldMapFrame)
    env.QuestMapFrame:RegisterEvent("QUEST_LOG_UPDATE")
    env.QuestMapFrame:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
    env.QuestMapFrame:RegisterEvent("QUEST_ACCEPTED")
    env.WorldMapFrame:Hide()
    env.loadAddon()
    env.fire("PLAYER_LOGIN")
    env.fire("PLAYER_ENTERING_WORLD")
    env.tick(1, 5)
    return env
end

return {
    {"Controller UI: paused while the game's map is closed, back when it opens", function(Mock)
        local env = start(Mock, true)
        local q = env.QuestMapFrame
        Mock.eq(q:IsEventRegistered("QUEST_LOG_UPDATE"), false, "QUEST_LOG_UPDATE paused")
        Mock.eq(q:IsEventRegistered("UNIT_QUEST_LOG_CHANGED"), false, "UNIT_QUEST_LOG_CHANGED paused")
        Mock.eq(q:IsEventRegistered("QUEST_ACCEPTED"), true, "other events untouched")
        env.WorldMapFrame:Show()
        Mock.eq(q:IsEventRegistered("QUEST_LOG_UPDATE"), true, "listening while the map is open")
        Mock.eq(q:IsEventRegistered("UNIT_QUEST_LOG_CHANGED"), true, "both events back")
        env.WorldMapFrame:Hide()
        Mock.eq(q:IsEventRegistered("QUEST_LOG_UPDATE"), false, "paused again when the map closes")
        Mock.ok(env.WalkMapGameMapGuard.Status():find("paused 2 time", 1, true), env.WalkMapGameMapGuard.Status())
    end},
    {"Mouse and keyboard: the game's quest log is left alone", function(Mock)
        local env = start(Mock, false)
        Mock.eq(env.QuestMapFrame:IsEventRegistered("QUEST_LOG_UPDATE"), true, "not paused without the controller UI")
        env.__gamepad = true
        env.fire("PLAYER_ENTERING_WORLD")
        Mock.eq(env.QuestMapFrame:IsEventRegistered("QUEST_LOG_UPDATE"), false, "paused once the controller UI is on")
    end},
}
