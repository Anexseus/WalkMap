-- WalkMap.lua: the focus waypoint on the minimaps - where to go for the
-- focused quest, gone when nothing is focused.
local function start(Mock, complete)
    local env = Mock.new({playerMap = 1436, onMap = {[1436] = {101}}, quests = {
        {header = "Westfall"},
        {id = 101, title = "Westfall Stew", level = 13, complete = complete},
        {id = 102, title = "Poor Old Blanchy", level = 12},
    }})
    env.loadAddon()
    env.fire("PLAYER_LOGIN")
    env.fire("PLAYER_ENTERING_WORLD")
    env.tick(1, 10)
    return env
end

return {
    {"Focus a quest: a target on the minimap; unfocus: gone", function(Mock)
        local env = start(Mock)
        local target = env.WalkMapFocusWaypoint.Target
        Mock.eq(target(1436), nil, "nothing without focus")
        env.WalkMapExtras.SetQuestFocus(101)
        env.WalkMapFocusWaypoint.Reset()
        local x, y, label = target(1436)
        Mock.eq(x, 0.5, "x from the game's quest marker")
        Mock.eq(y, 0.5, "y from the game's quest marker")
        Mock.eq(label, "Focus: Westfall Stew", "tooltip names the quest")
        env.WalkMapExtras.SetQuestFocus(nil)
        Mock.eq(target(1436), nil, "gone when the focus is")
    end},
    {"Ready quest says turn in; the setting turns it off", function(Mock)
        local env = start(Mock, true)
        env.WalkMapExtras.SetQuestFocus(101)
        env.WalkMapFocusWaypoint.Reset()
        local _, _, _, detail = env.WalkMapFocusWaypoint.Target(1436)
        Mock.eq(detail, "Turn in", "ready quest points at the turn-in")
        env.WalkMapCharacterSettings.focusWaypoint = false
        env.WalkMapFocusWaypoint.Reset()
        Mock.eq(env.WalkMapFocusWaypoint.Target(1436), nil, "off in Settings")
    end},
}
