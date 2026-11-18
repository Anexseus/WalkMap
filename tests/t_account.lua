-- Account settings (Settings > Profiles): save on one character, load on
-- another, and let new characters start from them.
local function start(Mock, account, character)
    local env = Mock.new({playerMap = 1436, quests = {{header = "Westfall"}, {id = 101, title = "Westfall Stew", level = 13}}})
    env.GetRealmName = function() return "Forever" end
    env.loadAddon(account, character)
    env.fire("PLAYER_LOGIN")
    env.fire("PLAYER_ENTERING_WORLD")
    env.tick(1, 5)
    return env
end

return {
    {"Save keeps settings, not the character's own state", function(Mock)
        local env = start(Mock)
        local s = env.WalkMapCharacterSettings
        s.trackerMax, s.rightClickUp, s.placeFilters = 15, true, {inn = true}
        s.waypoint = {mapID = 1436, x = 0.5, y = 0.5}
        s.questFocusID, s.trackerHidden, s.hiddenGivers = 101, {[101] = true}, {["npc:1"] = true}
        Mock.eq(env.WalkMapExtras.HasAccountSettings(), false, "nothing saved at first")
        env.WalkMapExtras.SaveAccountSettings()
        local saved = env.WalkMapSettings.accountSettings
        Mock.eq(saved.trackerMax, 15, "a setting is saved")
        Mock.eq(saved.rightClickUp, true, "another setting is saved")
        Mock.eq(saved.placeFilters.inn, true, "tables are saved")
        Mock.ok(saved.placeFilters ~= s.placeFilters, "as a copy")
        Mock.eq(saved.waypoint, nil, "waypoint not saved")
        Mock.eq(saved.questFocusID, nil, "quest focus not saved")
        Mock.eq(saved.trackerHidden, nil, "removed tracker quests not saved")
        Mock.eq(saved.hiddenGivers, nil, "hidden givers not saved")
        Mock.eq(env.WalkMapSettings.accountSettingsFrom, "Tester-Forever", "remembers which character")
    end},
    {"Load replaces settings and keeps the character's own state", function(Mock)
        local account = {accountSettings = {trackerMax = 15, rightClickUp = true, placeFilters = {inn = true}},
            accountSettingsFrom = "Main-Forever"}
        local env = start(Mock, account, {trackerMax = 5, follow = false, waypoint = {mapID = 1436, x = 0.2, y = 0.2},
            questFocusID = 101, questSolo = true})
        local reloaded = 0
        env.C_UI = {Reload = function() reloaded = reloaded + 1 end}
        Mock.eq(env.WalkMapExtras.LoadAccountSettings(), true, "loaded")
        local s = env.WalkMapCharacterSettings
        Mock.eq(s.trackerMax, 15, "setting from the account")
        Mock.eq(s.rightClickUp, true, "another setting from the account")
        Mock.eq(s.follow, nil, "a setting the account copy lacks goes back to its default")
        Mock.eq(s.waypoint.x, 0.2, "own waypoint kept")
        Mock.eq(s.questFocusID, 101, "own quest focus kept")
        s.placeFilters.bank = true
        Mock.eq(account.accountSettings.placeFilters.bank, nil, "the account copy is not changed afterwards")
    end},
    {"New characters start from account settings only when chosen", function(Mock)
        local account = {accountSettings = {trackerMax = 15, rightClickUp = true}}
        local env = start(Mock, account, false)
        Mock.ok(env.WalkMapCharacterSettings.trackerMax ~= 15, "off: a new character starts with the defaults")
        account = {accountSettings = {trackerMax = 15, rightClickUp = true}, accountForNew = true}
        env = start(Mock, account, false)
        Mock.eq(env.WalkMapCharacterSettings.trackerMax, 15, "on: a new character gets the account settings")
        Mock.eq(env.WalkMapCharacterSettings.rightClickUp, true, "all of them")
        Mock.eq(env.WalkMapCharacterSettings.fromAccountSettings, true, "marked for the debug report")
        env = start(Mock, account, {trackerMax = 8})
        Mock.eq(env.WalkMapCharacterSettings.trackerMax, 8, "an existing character keeps its own settings")
    end},
}
