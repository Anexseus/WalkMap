-- Mouse on the large map: click a marker to focus its quest, middle-click
-- for a waypoint, and the "Right-click goes a map level up" setting.
local function start(Mock)
    local env = Mock.new({playerMap = 1436, quests = {
        {header = "Westfall"},
        {id = 101, title = "Westfall Stew", level = 13},
        {id = 102, title = "Poor Old Blanchy", level = 12},
    }})
    env.loadAddon()
    env.fire("PLAYER_LOGIN")
    env.fire("PLAYER_ENTERING_WORLD")
    env.tick(1, 10)
    env.WalkMap_Toggle()
    env.tick(1, 10)
    return env, env.WalkMapCore.viewport
end

local function click(viewport, button, x, y, env)
    local canvas = env.WalkMapCore.canvas
    canvas.__left, canvas.__top = 0, canvas:GetHeight()
    env.__cursor = {x * canvas:GetWidth(), (1 - y) * canvas:GetHeight()}
    viewport:GetScript("OnMouseDown")(viewport, button)
    local up = viewport:GetScript("OnMouseUp")
    if up then up(viewport, button) end
end

return {
    {"Marker click: focus the quest, click again to show all", function(Mock)
        local env, viewport = start(Mock)
        Mock.eq(env.WalkMapExtras.QuestFocus(), nil, "no focus at first")
        Mock.eq(viewport.walkmapFocusClick({101}), true, "click used")
        Mock.eq(env.WalkMapExtras.QuestFocus(), 101, "quest focused")
        Mock.ok(env.__printed[#env.__printed]:find("Westfall Stew", 1, true), "the player is told which quest")
        viewport.walkmapFocusClick({101})
        Mock.eq(env.WalkMapExtras.QuestFocus(), nil, "second click turns focus off")
        Mock.eq(viewport.walkmapFocusClick({}), false, "a marker without quests does nothing")
    end},
    {"Marker click: a shared marker steps through its quests", function(Mock)
        local env, viewport = start(Mock)
        viewport.walkmapFocusClick({101, 102, 101})
        Mock.eq(env.WalkMapExtras.QuestFocus(), 101, "first quest")
        viewport.walkmapFocusClick({101, 102, 101})
        Mock.eq(env.WalkMapExtras.QuestFocus(), 102, "second quest")
        viewport.walkmapFocusClick({101, 102, 101})
        Mock.eq(env.WalkMapExtras.QuestFocus(), nil, "then all quests again")
        env.WalkMapExtras.SetQuestFocus(102)
        viewport.walkmapFocusClick({101})
        Mock.eq(env.WalkMapExtras.QuestFocus(), 101, "another quest's marker moves the focus")
    end},
    {"Marker click: buttons and modifiers", function(Mock)
        local env, viewport = start(Mock)
        local pin = {mapPercentX = 0.25, mapPercentY = 0.75}
        Mock.eq(viewport.walkmapMarkerClick(pin, "MiddleButton", {101}, "Westfall Stew"), true, "middle-click used")
        local waypoint = env.WalkMapExtras.Waypoint()
        Mock.ok(waypoint and math.abs(waypoint.x - 0.25) < 1e-6 and math.abs(waypoint.y - 0.75) < 1e-6,
            "waypoint at the marker")
        Mock.eq(waypoint.label, "Westfall Stew", "waypoint named after the quest")
        Mock.eq(env.WalkMapExtras.QuestFocus(), nil, "middle-click does not focus")
        env.IsShiftKeyDown = function() return true end
        Mock.eq(viewport.walkmapMarkerClick(pin, "LeftButton", {101}), false, "Shift-click is left to hide the marker")
        env.IsShiftKeyDown = function() return false end
        Mock.eq(viewport.walkmapMarkerClick(pin, "RightButton", {101}), false, "right-click is not a focus click")
        Mock.eq(env.WalkMapExtras.QuestFocus(), nil, "still no focus")
        viewport.walkmapMarkerClick(pin, "LeftButton", {101})
        Mock.eq(env.WalkMapExtras.QuestFocus(), 101, "plain left-click focuses")
    end},
    {"Quest markers on the map take the click", function(Mock)
        local env = Mock.new({playerMap = 1436, quests = {
            {header = "Westfall"},
            {id = 101, title = "Westfall Stew", level = 13},
            {id = 102, title = "Poor Old Blanchy", level = 12},
        }, onMap = {[1436] = {101, 102}}})
        env.loadAddon()
        env.fire("PLAYER_LOGIN")
        env.fire("PLAYER_ENTERING_WORLD")
        env.tick(1, 10)
        env.WalkMapCharacterSettings.areas = "all"
        env.WalkMap_Toggle()
        env.tick(1, 10)
        env.WalkMapCore.RefreshQuests()
        local marker
        for _, child in ipairs(env.WalkMapCore.canvas.__children) do
            if child.questID and child:IsShown() and child:GetScript("OnMouseDown") then marker = child end
        end
        Mock.ok(marker, "a shown quest marker with a click handler")
        marker:GetScript("OnMouseDown")(marker, "LeftButton")
        Mock.eq(env.WalkMapExtras.QuestFocus(), 101, "click focuses the first quest at the marker")
    end},
    {"Map: closing it forgets the browsed zone", function(Mock)
        local env = start(Mock)
        Mock.eq(env.WalkMapMaps.Choose(1415), true, "browse to the continent")
        Mock.eq(env.WalkMapCore.CurrentMap(), 1415, "continent shown")
        env.WalkMap_Toggle()
        env.tick(1, 5)
        Mock.ok(not env.WalkMapCore.frame:IsShown(), "map closed")
        Mock.eq(env.WalkMapMaps.Selected(), nil, "browsed zone forgotten")
        env.WalkMap_Toggle()
        env.tick(1, 5)
        Mock.ok(env.WalkMapCore.frame:IsShown(), "map open again")
        Mock.eq(env.WalkMapCore.CurrentMap(), 1436, "it shows the player's zone")
    end},
    {"Untracked quests leave the map; the focused quest stays", function(Mock)
        local env = Mock.new({playerMap = 1436, quests = {
            {header = "Westfall"},
            {id = 101, title = "Westfall Stew", level = 13},
            {id = 102, title = "Poor Old Blanchy", level = 12},
        }, onMap = {[1436] = {101, 102}}})
        env.loadAddon()
        env.fire("PLAYER_LOGIN")
        env.fire("PLAYER_ENTERING_WORLD")
        env.tick(1, 10)
        env.WalkMapCharacterSettings.areas = "all"
        env.WalkMap_Toggle()
        env.tick(1, 10)
        local function shownIDs()
            env.WalkMapCore.RefreshQuests()
            local ids = {}
            for _, child in ipairs(env.WalkMapCore.canvas.__children) do
                if rawget(child, "questID") and child:IsShown() then
                    ids[child.questID] = true
                    for _, entry in ipairs(rawget(child, "groupEntries") or {}) do
                        if entry.id then ids[entry.id] = true end
                    end
                end
            end
            return ids
        end
        local ids = shownIDs()
        Mock.ok(ids[101] and ids[102], "both quests on the map at first")
        env.WalkMapExtras.SetTrackerHidden(102, true)
        ids = shownIDs()
        Mock.ok(ids[101] and not ids[102], "untracked quest gone from the map")
        Mock.eq(env.WalkMapExtras.HiddenOnMap(102), true, "reported as hidden")
        env.WalkMapExtras.SetQuestFocus(102)
        ids = shownIDs()
        Mock.ok(ids[102], "focused quest shown although untracked")
        env.WalkMapExtras.SetQuestFocus(nil)
        env.WalkMapExtras.SetTrackerHidden(102, false)
        ids = shownIDs()
        Mock.ok(ids[101] and ids[102], "Track brings it back")
        env.WalkMapExtras.SetTrackerHidden(102, true)
        env.WalkMapCharacterSettings.zoneTracker = false
        Mock.eq(env.WalkMapExtras.HiddenOnMap(102), false, "WalkMap's tracker off: nothing hidden")
    end},
    {"Map: middle-click sets a waypoint", function(Mock)
        local env, viewport = start(Mock)
        click(viewport, "MiddleButton", 0.4, 0.6, env)
        local waypoint = env.WalkMapExtras.Waypoint()
        Mock.ok(waypoint and math.abs(waypoint.x - 0.4) < 0.01 and math.abs(waypoint.y - 0.6) < 0.01,
            "waypoint under the cursor")
        Mock.eq(env.WalkMapCore.CurrentMap(), 1436, "still on the zone map")
    end},
    {"Map: right-click on a zone follows the setting", function(Mock)
        local env, viewport = start(Mock)
        Mock.eq(env.WalkMapExtras.RightClickUp(), false, "off by default")
        click(viewport, "RightButton", 0.3, 0.3, env)
        Mock.ok(env.WalkMapExtras.Waypoint(), "off: right-click sets a waypoint")
        Mock.eq(env.WalkMapCore.CurrentMap(), 1436, "off: map unchanged")
        env.WalkMapExtras.SetWaypoint(nil)
        env.WalkMapCharacterSettings.rightClickUp = true
        Mock.eq(env.WalkMapExtras.RightClickUp(), true, "setting on")
        click(viewport, "RightButton", 0.3, 0.3, env)
        Mock.eq(env.WalkMapExtras.Waypoint(), nil, "on: no waypoint")
        Mock.eq(env.WalkMapCore.CurrentMap(), 1415, "on: the continent opens")
        click(viewport, "MiddleButton", 0.3, 0.3, env)
        Mock.ok(env.WalkMapExtras.Waypoint(), "on: middle-click still sets a waypoint")
    end},
}
