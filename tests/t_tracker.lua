-- WalkMap_Tracker.lua: which quests the tracker lists for each scope, in
-- which order, and the "Nearby: <zone>" group.
local QUESTS = {
    {header = "Westfall"},
    {id = 101, title = "Westfall Stew", level = 13},
    {id = 102, title = "Poor Old Blanchy", level = 12},
    {header = "Redridge Mountains"},
    {id = 301, title = "Elmore's Task", level = 16},
    {header = "Duskwood"},
    {id = 201, title = "Gather Rot Blossoms", level = 24},
    {id = 202, title = "The Night Watch", level = 24},
    {id = 203, title = "Deep in Duskwood", level = 28},
}

local function setup(Mock, scope, extra, before)
    local quests = {}
    for i, row in ipairs(QUESTS) do
        quests[i] = {}
        for key, value in pairs(row) do quests[i][key] = value end
    end
    local env = Mock.new({playerMap = 1436, quests = quests,
        -- The game lists everything inside Westfall's map rectangle, which
        -- reaches into western Duskwood.
        onMap = {[1436] = {101, 102, 201, 202}},
        distance = {[101] = 300, [102] = 100, [201] = 800, [202] = 500, [203] = 2500}})
    env.WalkMapCharacterSettings = {}
    env.load("WalkMap_Data.lua")
    env.load("WalkMap_Maps.lua")
    local options = {font = 1, background = true, backgroundAlpha = 0.3, max = 12, width = 250,
        objectives = false, scope = scope, hideGame = false, frame = true}
    for key, value in pairs(extra or {}) do options[key] = value end
    env.__options = options
    local position = {}
    env.WalkMapExtras = {
        TrackerOptions = function() return options end,
        TrackerSettings = function() return position end,
        ZoneTracker = function() return true end,
        QuestFocus = function() return env.__focus end,
    }
    env.WalkMapUI = {
        Accent = function() return 1, 0.8, 0.3 end,
        Look = function() return "classic" end,
        ApplyMaterial = function() return false end,
    }
    env.WalkMapQuestInfo = {
        Color = function() return 1, 0.82, 0 end,
        Tag = function() return nil end,
        XPText = function() return "" end,
        Distance = function(id) return env.__distance[id] end,
    }
    env.WalkMapLiveDB = {Objective = function() return nil end}
    if before then before(env) end
    env.load("WalkMap_Tracker.lua")
    env.tick(1, 5)
    return env
end

-- What the tracker shows, top to bottom: "# label" for group labels,
-- "title | distance" for quests.
local function shown(env)
    local frame = env.WalkMapZoneTracker
    local rows = {}
    for _, child in ipairs(frame.__children) do
        if child.__shown and child.__point and child.__point[1] == "TOPLEFT" and child.__point[2] == frame then
            if child.__kind == "Button" and child.title then
                local distance = child.distance:GetText() or ""
                rows[#rows + 1] = {child.__point[5], child.title:GetText()
                    .. (distance ~= "" and (" | " .. distance) or "")}
            elseif child.__kind == "FontString" and child.__point[5] ~= 0 then
                rows[#rows + 1] = {child.__point[5], "# " .. tostring(child:GetText())}
            end
        end
    end
    table.sort(rows, function(a, b) return a[1] > b[1] end)
    local texts = {}
    for i, row in ipairs(rows) do texts[i] = row[2] end
    return table.concat(texts, "\n")
end

-- The removed-quests list normally lives in WalkMap_Extras.lua.
local function withHidden(env, hidden)
    env.WalkMapExtras.TrackerHidden = function(id) return hidden[id] == true end
    env.WalkMapExtras.SetTrackerHidden = function(id, value)
        hidden[id] = value and true or nil
        env.WalkMapTracker.Refresh()
    end
    env.WalkMapExtras.PruneTrackerHidden = function(inLog)
        for id in pairs(hidden) do if not inLog[id] then hidden[id] = nil end end
    end
    env.WalkMapTracker.Refresh()
    env.tick(1, 5)
end

return {
    {"Removed quests stay out of the tracker; the focused quest stays in", function(Mock)
        local env = setup(Mock, "zone")
        local hidden = {[102] = true, [999] = true}
        withHidden(env, hidden)
        Mock.eq(shown(env), "[13] Westfall Stew | 300 yd", "removed quest not listed")
        Mock.eq(hidden[999], nil, "a removed quest that left the log is forgotten")
        Mock.eq(hidden[102], true, "a removed quest still in the log is kept")
        env.__focus = 102
        env.WalkMapTracker.Refresh()
        env.tick(1, 5)
        Mock.ok(shown(env):find("Poor Old Blanchy", 1, true), "the focused quest is listed although removed")
    end},
    {"Right-click a quest in the tracker removes it", function(Mock)
        local env = setup(Mock, "zone")
        local hidden = {}
        withHidden(env, hidden)
        local block
        for _, child in ipairs(env.WalkMapZoneTracker.__children) do
            if child.__kind == "Button" and child.questID == 102 and child.__shown then block = child end
        end
        Mock.ok(block, "tracker row for quest 102")
        block:GetScript("OnClick")(block, "RightButton")
        Mock.eq(hidden[102], true, "quest removed")
        env.tick(1, 5)
        Mock.eq(shown(env), "[13] Westfall Stew | 300 yd", "only the other quest is left")
        Mock.ok(env.__printed[#env.__printed]:find("Poor Old Blanchy", 1, true), "the player is told")
    end},
    {"This zone: only this zone's quests, nearest first", function(Mock)
        local env = setup(Mock, "zone")
        Mock.eq(shown(env), table.concat({
            "[12] Poor Old Blanchy | 100 yd",
            "[13] Westfall Stew | 300 yd",
        }, "\n"), "tracker rows")
    end},
    {"This zone + nearby: neighbours get their own group with distance", function(Mock)
        local env = setup(Mock, "nearby")
        Mock.eq(shown(env), table.concat({
            "[12] Poor Old Blanchy | 100 yd",
            "[13] Westfall Stew | 300 yd",
            "# Nearby: Duskwood",
            "[24] The Night Watch | 500 yd",
            "[24] Gather Rot Blossoms | 800 yd",
        }, "\n"), "tracker rows")
    end},
    {"All zones: nearby group first, then the rest of the log", function(Mock)
        local env = setup(Mock, "all")
        Mock.eq(shown(env), table.concat({
            "[12] Poor Old Blanchy | 100 yd",
            "[13] Westfall Stew | 300 yd",
            "# Nearby: Duskwood",
            "[24] The Night Watch | 500 yd",
            "[24] Gather Rot Blossoms | 800 yd",
            "# Redridge Mountains",
            "[16] Elmore's Task",
            "# Duskwood",
            "[28] Deep in Duskwood",
        }, "\n"), "tracker rows")
    end},
    {"The header is the zone you are in", function(Mock)
        local env = setup(Mock, "nearby")
        local header = env.WalkMapZoneTracker.__children[1]
        Mock.eq(header:GetText(), "Westfall", "header")
    end},
    {"Max quests cuts the list from the bottom", function(Mock)
        local env = setup(Mock, "nearby", {max = 3})
        Mock.eq(shown(env), table.concat({
            "[12] Poor Old Blanchy | 100 yd",
            "[13] Westfall Stew | 300 yd",
            "# Nearby: Duskwood",
            "[24] The Night Watch | 500 yd",
            "# +1 more quest",
        }, "\n"), "tracker rows")
    end},
    {"A set height lists the quests that fit and counts the rest", function(Mock)
        local env = setup(Mock, "all")
        env.WalkMapExtras.TrackerSettings().h = 60
        env.WalkMapTracker.Refresh()
        env.tick(1, 5)
        Mock.eq(shown(env), "[12] Poor Old Blanchy | 100 yd\n# +5 more quests", "one quest fits")
        Mock.ok(env.WalkMapZoneTracker:GetHeight() <= 60, "tracker stays inside its height")
        env.WalkMapExtras.TrackerSettings().h = 200
        env.WalkMapTracker.Refresh()
        env.tick(1, 5)
        Mock.ok(not shown(env):find("more quest", 1, true), "everything fits in a taller box")
    end},
    {"Without a set height the tracker stops at the bottom of the screen", function(Mock)
        local env = setup(Mock, "all")
        local pos = env.WalkMapExtras.TrackerSettings()
        pos.point, pos.x, pos.y = "TOPLEFT", 20, -1000 -- 80 px above the bottom
        env.WalkMapTracker.Refresh()
        env.tick(1, 5)
        Mock.eq(env.WalkMapTracker.lastPlaced, 2, "two quests fit above the screen bottom")
        Mock.ok(shown(env):find("# +4 more quests", 1, true), "the rest is counted")
    end},
    {"Edit Mode shows the outline; size is saved and right-click resets height", function(Mock)
        local callbacks = {}
        local env = setup(Mock, "zone", nil, function(env)
            env.EventRegistry = {RegisterCallback = function(_, event, fn) callbacks[event] = fn end}
        end)
        local widths = {}
        env.WalkMapExtras.SetTrackerWidth = function(w) widths[#widths + 1] = w end
        Mock.ok(callbacks["EditMode.Enter"] and callbacks["EditMode.Exit"], "listens to the game's Edit Mode")
        local box = env.WalkMapTracker.EditBox
        Mock.ok(not box:IsShown(), "no outline outside Edit Mode")
        callbacks["EditMode.Enter"]()
        Mock.ok(box:IsShown(), "outline in Edit Mode")
        Mock.eq(env.WalkMapTracker.CornerPoint(), "BOTTOMLEFT", "pinned right: the corner is on the free left side")
        box:GetScript("OnDragStart")(box)
        box:GetScript("OnDragStop")(box) -- the first 1.14.7 build called a nil placeCorner here
        Mock.eq(env.WalkMapTracker.CornerPoint(), "BOTTOMRIGHT", "dragged to the left side: corner moves to the right")
        env.WalkMapTracker.SaveSize(900, 30)
        local pos = env.WalkMapExtras.TrackerSettings()
        Mock.eq(pos.h, 60, "height has a minimum")
        Mock.eq(widths[1], 520, "width has a maximum")
        env.tick(1, 5)
        Mock.ok(env.WalkMapZoneTracker:GetHeight() >= 60, "the whole box shows while editing")
        box:GetScript("OnClick")(box, "RightButton")
        Mock.eq(pos.h, nil, "right-click: automatic height")
        callbacks["EditMode.Exit"]()
        Mock.ok(not box:IsShown(), "outline gone after Edit Mode")
    end},
    {"A ready nearby quest comes first in its group", function(Mock)
        local env = setup(Mock, "nearby")
        for _, row in ipairs(env.__quests) do
            if row.id == 201 then row.complete = true end -- Gather Rot Blossoms
        end
        env.fire("QUEST_LOG_UPDATE")
        env.tick(1, 5)
        Mock.ok(shown(env):find("# Nearby: Duskwood\n[24] Gather Rot Blossoms |cff80f080(ready)|r | 800 yd", 1, true),
            "ready quest leads the nearby group")
    end},
}
