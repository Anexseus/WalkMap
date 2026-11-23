-- WalkMap's wheel in combat (WalkMap_CombatWheel.lua) and "Game map in
-- dungeons". The secure side only runs in the game; here: the aim sums,
-- the settings and the hand-off.
local function boot(Mock)
    local env = Mock.new({playerMap = 1436})
    env.loadAddon({welcomeSeen = true, newsSeen = "1.14.11"}, {welcomeSeen = true})
    env.fire("PLAYER_LOGIN")
    env.tick(0.5, 2)
    return env
end

return {
    {"the stick picks the same entry as the game's wheel", function(Mock)
        local env = boot(Mock)
        local aimed = env.WalkMapCombatWheel.Aimed
        Mock.eq(aimed(0, 0), nil, "middle: nothing")
        Mock.eq(aimed(0.3, 0.3), nil, "inside the dead zone: nothing")
        Mock.eq(aimed(1, 0), 1, "east: Bags")
        Mock.eq(aimed(0.7, 0.7), 2, "north-east: Professions")
        Mock.eq(aimed(0, 1), 3, "north: Character")
        Mock.eq(aimed(-0.7, 0.7), 4, "north-west: Talents")
        Mock.eq(aimed(-1, 0), 5, "west: Quest & Maps")
        Mock.eq(aimed(-0.7, -0.7), 6, "south-west: Chat")
        Mock.eq(aimed(0, -1), 7, "south: Game Menu")
        Mock.eq(aimed(0.7, -0.7), 8, "south-east: Spellbook")
        Mock.eq(aimed(1, -0.35), 1, "just below east is still Bags")
        Mock.eq(aimed(1, -0.45), 8, "further down is Spellbook")
    end},
    {"setting on by default; the debug report has a line", function(Mock)
        local env = boot(Mock)
        Mock.eq(env.WalkMapExtras.CombatWheel(), true, "on by default")
        env.WalkMapCharacterSettings.combatWheel = false
        Mock.eq(env.WalkMapExtras.CombatWheel(), false, "can be turned off")
        local report = env.WalkMapExtras.DebugReport()
        if type(report) == "table" then report = table.concat(report, "\n") end
        Mock.ok(tostring(report):find("WalkMap's combat wheel", 1, true), "debug line")
    end},
    {"Game map in dungeons: Auto, Always, Off", function(Mock)
        local env = boot(Mock)
        local x = env.WalkMapExtras
        env.IsInInstance = function() return true, "party" end
        Mock.eq(x.DungeonMapMode(), "auto", "Auto by default")
        Mock.eq(x.HandOffDungeonMap(), false, "Auto without a known addon: WalkMap")
        env.WalkMapCharacterSettings.dungeonMapAlways = true
        Mock.eq(x.DungeonMapMode(), "always", "Always")
        Mock.eq(x.HandOffDungeonMap(), true, "Always: the game's map in a dungeon")
        env.IsInInstance = function() return false, "none" end
        Mock.eq(x.HandOffDungeonMap(), false, "never outside dungeons")
        env.IsInInstance = function() return true, "party" end
        env.WalkMapCharacterSettings.dungeonMapHandoff = false
        Mock.eq(x.DungeonMapMode(), "off", "Off")
        Mock.eq(x.HandOffDungeonMap(), false, "Off: WalkMap")
    end},
}
