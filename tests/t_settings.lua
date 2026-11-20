-- Settings window: merged rows, fewer categories and scrolling.
local function start(Mock)
    local env = Mock.new({playerMap = 1436, quests = {{header = "Westfall"}, {id = 101, title = "Westfall Stew", level = 13}}})
    env.loadAddon()
    env.fire("PLAYER_LOGIN")
    env.fire("PLAYER_ENTERING_WORLD")
    env.tick(1, 5)
    env.WalkMap_Toggle()
    env.tick(1, 5)
    return env, env.WalkMapExtras.SettingsPanel()
end

local function page(env, title)
    Mock_ok = env.WalkMapExtras.ShowSettingsPage(title)
    local panel = env.WalkMapExtras.SettingsPanel()
    local labels = {}
    for _, row in ipairs(panel.options) do
        if row:IsShown() then labels[#labels + 1] = row.label:GetText() end
    end
    return labels
end

local function rowStarting(panel, text)
    for _, row in ipairs(panel.options) do
        local label = row.label:GetText() or ""
        if row:IsShown() and label:sub(1, #text) == text then return row end
    end
end

local function click(row) row:GetScript("OnClick")(row) end

return {
    {"What's new 1.14.8: friends, guild and sharing can be turned on right there", function(Mock)
        local env, panel = start(Mock)
        local s = env.WalkMapCharacterSettings
        local labels = page(env, "What's new in WalkMap 1.14.8")
        Mock.eq(#labels, 7, "seven rows")
        Mock.ok(labels[1]:find("See friends on the map", 1, true), "friends first")
        Mock.ok(labels[3]:find("Share where you are", 1, true), "sharing")
        Mock.ok(labels[7]:find("Found a bug", 1, true), "bug report row last")
        Mock.eq(s.shareLocation, false, "sharing off by default")
        local row = panel.options[3]
        row:GetScript("OnClick")(row, "LeftButton")
        Mock.eq(s.shareLocation, true, "turned on from What's new")
    end},
    {"Players who saw 1.14's news get 1.14.8's on the next map open", function(Mock)
        local env = Mock.new({playerMap = 1436, quests = {{header = "Westfall"}, {id = 101, title = "Westfall Stew", level = 13}}})
        env.loadAddon({welcomeSeen = true, newsSeen = "1.14"}, {})
        env.fire("PLAYER_LOGIN")
        env.fire("PLAYER_ENTERING_WORLD")
        env.tick(1, 5)
        env.WalkMap_Toggle()
        env.tick(1, 5)
        Mock.eq(env.WalkMapSettings.newsSeen, "1.14.8", "What's new shown and marked seen")
        local panel = env.WalkMapExtras.SettingsPanel()
        Mock.ok(panel:IsShown(), "settings window open on What's new")
    end},
    {"Tracker place and size per interface, both starting from the old one", function(Mock)
        local env = Mock.new({playerMap = 1436, quests = {{header = "Westfall"}, {id = 101, title = "Westfall Stew", level = 13}}})
        env.loadAddon({welcomeSeen = true, newsSeen = "1.14.8"},
            {zoneTrackerPos = {point = "TOPRIGHT", x = -10, y = -200, h = 300}})
        local x = env.WalkMapExtras
        Mock.eq(x.TrackerInterface(), "mouse", "mouse and keyboard interface")
        Mock.eq(x.TrackerSettings().h, 300, "starts from the saved height")
        x.TrackerSettings().h = 180
        x.SetTrackerWidth(333)
        Mock.eq(x.TrackerOptions().width, 333, "dragged width used")
        env.InputUtil = {IsGamepadUIEnabled = function() return true end}
        Mock.eq(x.TrackerInterface(), "gamepad", "gamepad interface")
        Mock.eq(x.TrackerSettings().h, 300, "gamepad layout keeps its own height")
        Mock.eq(x.TrackerOptions().width, env.WalkMapCharacterSettings.trackerWidth, "and the Width setting")
        env.InputUtil = nil
        Mock.eq(x.TrackerSettings().h, 180, "mouse layout unchanged")
    end},
    {"Categories: nine pages, merged ones gone", function(Mock)
        local env, panel = start(Mock)
        local names = {}
        for _, row in ipairs(panel.categories) do names[#names + 1] = row.label:GetText() end
        Mock.eq(table.concat(names, ", "), "Quests on the map, Giver level, Map, Minimap, Look, Quest tracker, Profiles, Controller & help, Bags & vendors", "category list")
        local giver = page(env, "Giver level")
        Mock.eq(giver[1], "Automatic", "giver level rows still built")
        Mock.eq(#giver, 7, "Automatic plus six ranges")
    end},
    {"Quests on the map: cycles and one restore button", function(Mock)
        local env, panel = start(Mock)
        page(env, "Quests on the map")
        local s = env.WalkMapCharacterSettings
        s.objectiveIcons, s.focusObjectiveIcons = true, false
        env.WalkMapExtras.ShowSettingsPage("Quests on the map")
        local icons = rowStarting(panel, "Quest icons")
        Mock.eq(icons.label:GetText(), "Quest icons: All quests", "icons row shows its value")
        click(icons)
        Mock.eq(s.focusObjectiveIcons, true, "then focused quest")
        click(rowStarting(panel, "Quest icons"))
        Mock.eq(s.objectiveIcons, false, "then off")
        local commands = {}
        env.WalkMapExtras.Command = function(what, action) commands[#commands + 1] = what .. " " .. action end
        click(rowStarting(panel, "Restore hidden markers"))
        Mock.eq(table.concat(commands, ", "), "givers reset, markers reset", "one button restores both")
    end},
    {"Map: fade is one row, Keep arrow only while fading", function(Mock)
        local env, panel = start(Mock)
        local s = env.WalkMapCharacterSettings
        s.fadeWhileMoving = false
        page(env, "Map")
        Mock.eq(rowStarting(panel, "Fade while moving").label:GetText(), "Fade while moving: Off", "off")
        Mock.ok(not rowStarting(panel, "Keep player arrow"), "no arrow row while fading is off")
        local seen = {}
        for _ = 1, 5 do
            click(rowStarting(panel, "Fade while moving"))
            seen[#seen + 1] = s.fadeWhileMoving and string.format("%.2f", s.fadeAlpha) or "off"
        end
        Mock.eq(table.concat(seen, " "), "0.20 0.35 0.50 0.70 off", "cycles through strengths, then off")
        click(rowStarting(panel, "Fade while moving"))
        Mock.ok(rowStarting(panel, "Keep player arrow"), "arrow row back while fading")
    end},
    {"Minimap: type cycle and rows for the minimap in use", function(Mock)
        local env, panel = start(Mock)
        local s = env.WalkMapCharacterSettings
        s.miniMap, s.nativeIcons = false, false
        local labels = page(env, "Minimap")
        Mock.eq(table.concat(labels, " | "), "WalkMap minimap: Off | Game minimap icons", "off: no marker rows")
        click(rowStarting(panel, "WalkMap minimap"))
        Mock.eq(s.miniMap, true, "zone artwork on")
        Mock.eq(s.miniTerrain, "zone", "zone artwork")
        labels = page(env, "Minimap")
        Mock.eq(#labels, 5, "type, focus waypoint and three marker rows")
        Mock.ok(not rowStarting(panel, "Game minimap icons"), "game icons row hidden while WalkMap's minimap is on")
        click(rowStarting(panel, "WalkMap minimap"))
        Mock.eq(s.miniTerrain, "game", "then game terrain")
        click(rowStarting(panel, "WalkMap minimap"))
        Mock.eq(s.miniMap, false, "then off")
        s.nativeIcons = true
        labels = page(env, "Minimap")
        Mock.eq(#labels, 6, "game icons on: focus waypoint and its three marker rows")
        click(rowStarting(panel, "Marker size"))
        Mock.ok(s.nativeIconScale ~= nil, "marker rows change the game minimap's values")
    end},
    {"Controller & help and Bags: merged cycles", function(Mock)
        local env, panel = start(Mock)
        local s = env.WalkMapCharacterSettings
        s.useGameMapKeys, s.wheelOpensQuestLog = false, true
        page(env, "Controller & help")
        local seen = {}
        for _ = 1, 3 do
            click(rowStarting(panel, "Map key and wheel open"))
            seen[#seen + 1] = rowStarting(panel, "Map key and wheel open").label:GetText():match(": (.*)$")
        end
        Mock.eq(table.concat(seen, " / "), "WalkMap / WalkMap + quest log / Game map", "map key cycle")
        Mock.ok(rowStarting(panel, "How you play"), "How you play is also under Controller & help")
        click(rowStarting(panel, "How you play"))
        Mock.ok(s.playStyle ~= nil, "and can be changed there")
        s.autoSellJunk, s.vendorMessages = false, true
        page(env, "Bags & vendors")
        seen = {}
        for _ = 1, 3 do
            click(rowStarting(panel, "Auto-sell junk"))
            seen[#seen + 1] = rowStarting(panel, "Auto-sell junk").label:GetText():match(": (.*)$")
        end
        Mock.eq(table.concat(seen, " / "), "On / On, quietly / Off", "auto-sell cycle")
        Mock.eq(s.vendorMessages, true, "messages back on for next time")
    end},
    {"Scrolling: mouse wheel and controller edges", function(Mock)
        local env, panel = start(Mock)
        local labels = page(env, "Quest tracker")
        Mock.eq(#labels, 8, "eight rows fit")
        Mock.eq(panel.more:GetText(), "1 more below (scroll)", "says there is more")
        local edges = panel.walkmapScrollEdges
        Mock.eq(edges.down, true, "the last row can scroll down")
        Mock.eq(panel.walkmapScroll(edges.first, "down"), false, "Down on another row does not scroll")
        Mock.eq(panel.walkmapScroll(edges.last, "down"), true, "controller Down scrolls")
        Mock.ok(rowStarting(panel, "Tell group about quest progress"), "last setting now shown")
        Mock.eq(panel.more:GetText(), "1 more above (scroll)", "says there is more above")
        Mock.eq(panel.walkmapScroll(panel.walkmapScrollEdges.last, "down"), false, "nothing more below")
        Mock.eq(panel.walkmapScrollEdges.up, true, "the first row can scroll up")
        panel:GetScript("OnMouseWheel")(panel, 1)
        Mock.eq(panel.scroll, 0, "mouse wheel scrolls back up")
        page(env, "Look")
        Mock.eq(panel.more:GetText(), "", "short page: no scroll hint")
        Mock.eq(panel.walkmapScroll(panel.walkmapScrollEdges.last, "down"), false, "short page does not scroll")
    end},
    {"Apply rows have a real button that does the same as the row", function(Mock)
        local env, panel = start(Mock)
        page(env, "Look")
        local row = rowStarting(panel, "Use the chosen look")
        Mock.ok(row and row.walkmapActionButton and row.walkmapActionButton:IsShown(), "Look: button shown")
        Mock.eq(row.walkmapActionButton.text:GetText(), "In use", "nothing to apply yet")
        env.WalkMapCharacterSettings.look = env.WalkMapUI.Look() == "wood" and "stone" or "wood"
        env.WalkMapExtras.ShowSettingsPage("Look")
        Mock.eq(row.walkmapActionButton.text:GetText(), "Apply now", "another look chosen")
        local reloads = 0
        env.C_UI = {Reload = function() reloads = reloads + 1 end}
        row.walkmapActionButton:GetScript("OnClick")(row.walkmapActionButton)
        Mock.eq(reloads, 1, "the button applies the look")
        local window = rowStarting(panel, "Window look")
        Mock.ok(not (window.walkmapActionButton and window.walkmapActionButton:IsShown()), "other rows have no button")
        env.WalkMapExtras.ShowSettingsPage("Welcome to WalkMap")
        local recommended = rowStarting(panel, "|cffffd24aUse recommended settings")
        Mock.ok(recommended and recommended.walkmapActionButton:IsShown(), "welcome page: button shown")
        Mock.ok(({Apply = true, Applied = true})[recommended.walkmapActionButton.text:GetText()], "Apply or Applied")
    end},
    {"Recommended settings: the authors' setup, quest choices left alone", function(Mock)
        local env, panel = start(Mock)
        local s = env.WalkMapCharacterSettings
        s.rightClickUp, s.controllerHints, s.miniTerrain = false, false, "zone"
        s.trackerHidden = {[101] = true}
        s.hiddenGivers = {["npc:1"] = true}
        s.look = "wood"
        env.WalkMapExtras.ShowSettingsPage("Welcome to WalkMap")
        local row = rowStarting(panel, "|cffffd24aUse recommended settings")
        Mock.eq(row.walkmapActionButton.text:GetText(), "Apply", "not in use yet")
        Mock.eq(rowStarting(panel, "How you play").label:GetText(), "How you play: Mouse and keyboard",
            "no gamepad: mouse and keyboard until chosen")
        click(row)
        Mock.eq(s.rightClickUp, true, "right-click goes a level up")
        Mock.eq(s.miniTerrain, "game", "game terrain minimap")
        Mock.eq(s.controllerMode, false, "mouse and keyboard: Pad focus off")
        Mock.eq(s.controllerHints, false, "mouse and keyboard: no button hints")
        Mock.ok(not (s.hiddenButtons and s.hiddenButtons.close), "mouse and keyboard: close X stays")
        click(rowStarting(panel, "How you play"))
        Mock.eq(s.playStyle, "controller", "then controller")
        Mock.eq(s.controllerMode, true, "controller: Pad focus on")
        Mock.eq(s.controllerHints, true, "controller: button hints on")
        Mock.eq(s.hiddenButtons and s.hiddenButtons.close, true, "controller: close X hidden")
        click(rowStarting(panel, "How you play"))
        Mock.eq(s.playStyle, "both", "then both")
        Mock.eq(s.controllerMode, true, "both: Pad focus on")
        Mock.ok(not s.hiddenButtons.close, "both: close X back for the mouse")
        Mock.eq(s.trackerHidden[101], true, "untracked quests left alone")
        Mock.eq(s.hiddenGivers["npc:1"], true, "hidden givers left alone")
        Mock.eq(s.look, "wood", "the chosen look left alone")
        env.WalkMapExtras.ShowSettingsPage("Welcome to WalkMap")
        Mock.eq(row.walkmapActionButton.text:GetText(), "Applied", "now in use")
    end},
    {"Welcome page: Select keeps the map released, for controller players", function(Mock)
        local env, panel = start(Mock)
        local s = env.WalkMapCharacterSettings
        s.playStyle = "mouse"
        env.WalkMapExtras.ShowSettingsPage("Welcome to WalkMap")
        local function find()
            for _ = 1, 3 do
                local row = rowStarting(panel, "Select keeps the map released")
                if row then return row end
                panel.walkmapScrollBy(1)
            end
        end
        Mock.ok(not find(), "hidden for mouse and keyboard")
        s.playStyle = "controller"
        env.WalkMapExtras.ShowSettingsPage("Welcome to WalkMap")
        local row = find()
        Mock.ok(row, "shown for controller players (the page scrolls)")
        Mock.eq(s.selectKeepsReleased, nil, "off by default")
        click(row)
        Mock.eq(s.selectKeepsReleased, true, "can be turned on from the welcome page")
    end},
    {"How you play: guessed from the game's gamepad setting until chosen", function(Mock)
        local env = start(Mock)
        env.GetCVar = function(name) if name == "GamePadEnable" then return "1" end end
        Mock.eq(env.WalkMapExtras.PlayStyle(), "both", "gamepad on: both")
        env.GetCVar = function() return "0" end
        Mock.eq(env.WalkMapExtras.PlayStyle(), "mouse", "gamepad off: mouse and keyboard")
        env.WalkMapCharacterSettings.playStyle = "controller"
        Mock.eq(env.WalkMapExtras.PlayStyle(), "controller", "a choice wins")
        Mock.eq(env.WalkMapCharacterSettings.controllerMode, false, "Pad focus starts off")
    end},
    {"New players start in Leather; earlier players keep their look", function(Mock)
        local env = Mock.new({playerMap = 1436})
        env.loadAddon(nil, false)
        Mock.eq(env.WalkMapUI.Look(), "leather", "brand-new install: Leather and bronze")
        Mock.eq(env.WalkMapCharacterSettings.look, "leather", "saved as the character's look")
        env = Mock.new({playerMap = 1436})
        env.loadAddon({welcomeSeen = true}, false)
        Mock.eq(env.WalkMapUI.Look(), "classic", "used WalkMap before, never chose: Classic as before")
        env = Mock.new({playerMap = 1436})
        env.loadAddon({welcomeSeen = true, look = "stone"}, false)
        Mock.eq(env.WalkMapUI.Look(), "stone", "a chosen look is kept")
    end},
    {"Navigation: Up/Down stay on the edge rows of a list that can scroll", function(Mock)
        local env = Mock.new({playerMap = 1436})
        env.loadAddon()
        local function button(x, y)
            return {IsShown = function() return true end, IsVisible = function() return true end,
                GetCenter = function() return x, y end}
        end
        local panel = {categories = {button(10, 100), button(10, 80)},
            options = {button(200, 100), button(200, 80), button(200, 60)}}
        panel.walkmapScrollEdges = {first = panel.options[1], last = panel.options[3], up = true, down = true}
        local routes = env.WalkMapNavigation.Settings(panel)
        Mock.eq(routes[panel.options[3]].down, panel.options[3], "Down on the last row stays")
        Mock.eq(routes[panel.options[1]].up, panel.options[1], "Up on the first row stays")
        Mock.eq(routes[panel.options[2]].down, panel.options[3], "rows in between move as usual")
        panel.walkmapScrollEdges = {first = panel.options[1], last = panel.options[3], up = false, down = false}
        routes = env.WalkMapNavigation.Settings(panel)
        Mock.ok(routes[panel.options[3]].down ~= panel.options[3], "nothing to scroll: Down leaves the list")
    end},
    {"Scroll bar only on pages that scroll, thumb follows the scroll", function(Mock)
        local env, panel = start(Mock)
        page(env, "Map")
        local bar = panel.scrollBar
        Mock.ok(bar:IsShown(), "Map has more rows than fit: scroll bar")
        local before = select(5, bar.thumb:GetPoint(1))
        panel.walkmapScrollBy(1)
        local after = select(5, bar.thumb:GetPoint(1))
        Mock.ok(after < before, "thumb moved down")
        bar.down:GetScript("OnClick")(bar.down)
        page(env, "Look")
        Mock.eq(bar:IsShown(), false, "a short page: no scroll bar")
    end},
}
