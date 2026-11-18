-- Loads the whole addon in TOC order inside the fake client and uses it a
-- little. This catches what a syntax check cannot: a file calling something
-- that is not there yet at load, a piece lost when code moves between
-- files, an error in the first seconds after login.
local function boot(Mock, account, character)
    local env = Mock.new()
    env.loadAddon(account, character)
    env.fire("ADDON_LOADED", "WalkMap")
    env.fire("PLAYER_LOGIN")
    env.fire("PLAYER_ENTERING_WORLD")
    env.tick(2, 20)
    return env
end

return {
    {"every WalkMap*.lua file is listed in the TOC, and every listed file exists", function(Mock)
        local env = Mock.new()
        local listed = {}
        for _, file in ipairs(env.tocFiles()) do
            listed[file] = true
            local handle = io.open(Mock.root .. file, "r")
            Mock.ok(handle, "TOC lists " .. file .. ", which exists")
            handle:close()
        end
        Mock.ok(listed["WalkMap.lua"] and listed["WalkMap_Levels.lua"] and listed["WalkMap_Commands.lua"]
            and listed["WalkMap_Fade.lua"] and listed["WalkMap_ButtonsMenu.lua"]
            and listed["WalkMap_TurnIns.lua"], "split files listed")
    end},
    {"the addon loads and survives login", function(Mock)
        local env = boot(Mock)
        Mock.ok(env.WalkMapCore and env.WalkMapCore.frame, "WalkMapCore")
        Mock.ok(type(env.WalkMap_Toggle) == "function", "WalkMap_Toggle")
        Mock.ok(type(env.SlashCmdList.WALKMAP) == "function", "/walkmap")
        Mock.eq(env.SLASH_WALKMAP1, "/walkmap", "slash name")
        Mock.ok(env.WalkMapLevels and env.WalkMapLevels.Button, "map levels")
        Mock.ok(env.WalkMapSimpleButton, "Buttons menu button")
        Mock.ok(env.WalkMapKeyboardToggle, "key toggle button")
    end},
    {"the debug report names the version in the TOC", function(Mock)
        local env = boot(Mock)
        local version = env.C_AddOns.GetAddOnMetadata("WalkMap", "Version")
        Mock.ok(version and version ~= "", "TOC has a version")
        local report = env.WalkMapExtras.DebugReport()
        if type(report) == "table" then report = table.concat(report, "\n") end
        Mock.ok(tostring(report):find("WalkMap " .. version .. " debug report", 1, true),
            "debug report title carries " .. version)
    end},
    {"the map opens, updates and closes", function(Mock)
        local env = boot(Mock)
        local frame = env.WalkMapCore.frame
        frame:Hide()
        env.WalkMap_Toggle()
        Mock.eq(frame:IsShown(), true, "map open")
        env.tick(2, 20)
        Mock.eq(env.WalkMapCore.CurrentMap(), 1436, "shows the player's zone")
        env.WalkMap_Toggle()
        Mock.eq(frame:IsShown(), false, "map closed")
    end},
    {"up and back down through the map levels", function(Mock)
        local env = boot(Mock)
        local core = env.WalkMapCore
        if not core.frame:IsShown() then env.WalkMap_Toggle() end
        env.tick(1, 10)
        Mock.eq(env.WalkMapLevels.Up(), true, "up from Westfall")
        env.tick(1, 10)
        Mock.eq(core.CurrentMap(), 1415, "Eastern Kingdoms shown")
        env.__childAt = function(id) if id == 1415 then return 1431 end end
        Mock.eq(core.viewport.walkmapDrill(0.5, 0.5), true, "click Duskwood")
        env.tick(1, 10)
        Mock.eq(core.CurrentMap(), 1431, "Duskwood shown")
    end},
    {"right-click: up on a continent, waypoint on a zone", function(Mock)
        local env = boot(Mock)
        local core = env.WalkMapCore
        if not core.frame:IsShown() then env.WalkMap_Toggle() end
        env.tick(1, 10)
        local down = core.viewport:GetScript("OnMouseDown")
        down(core.viewport, "RightButton")
        env.tick(1, 10)
        Mock.eq(core.CurrentMap(), 1436, "a zone map stays (right-click sets a waypoint there)")
        env.WalkMapLevels.Up()
        env.tick(1, 10)
        Mock.eq(core.CurrentMap(), 1415, "continent")
        down(core.viewport, "RightButton")
        env.tick(1, 10)
        Mock.eq(core.CurrentMap(), 947, "right-click on a continent opens the world")
        down(core.viewport, "RightButton")
        env.tick(1, 10)
        Mock.eq(core.CurrentMap(), 947, "the world map stays")
    end},
    {"Buttons menu choices are applied at login, the level-up button included", function(Mock)
        local env = boot(Mock, {}, {hiddenButtons = {up = true, coords = true, db = true}})
        local core = env.WalkMapCore
        if not core.frame:IsShown() then env.WalkMap_Toggle() end
        env.tick(1, 10)
        Mock.eq(env.WalkMapLevels.Button:IsShown(), false, "level-up button hidden")
        Mock.eq(core.dbBadge:IsShown(), false, "DB badge hidden")
        Mock.eq(core.status:GetAlpha(), 0, "coordinates hidden")
        local other = boot(Mock)
        if not other.WalkMapCore.frame:IsShown() then other.WalkMap_Toggle() end
        other.tick(1, 10)
        Mock.eq(other.WalkMapLevels.Button:IsShown(), true, "shown by default on a zone map")
    end},
    {"a ready quest handed in at an object gets its ? on the map from QuestieDB", function(Mock)
        local env = Mock.new({playerMap = 1413, quests = {
            {header = "Westfall"},
            {id = 79008, title = "... and that note you found", level = 22, complete = true},
            -- QuestieDB knows nothing about where this one goes; the game does.
            {id = 98071, title = "Brewer's Trade", level = 27, objectives = {
                {text = "Fallrook Varietal delivered: 0/1", type = "event", finished = false}}},
            -- QuestieDB has this one's objective on the map.
            {id = 901, title = "Located", level = 20, objectives = {
                {text = "Crate: 0/1", type = "object", finished = false}}},
        }, onMap = {[1413] = {98071, 901}}})
        local function entity(rows)
            return {
                GetByIndex = function(id, field) return rows[id] and rows[id][field] end,
                Exists = function(id) return rows[id] ~= nil end,
                GetAllIds = function()
                    local ids = {}
                    for id in pairs(rows) do ids[#ids + 1] = id end
                    return ids
                end,
            }
        end
        env.LibQuestieDB = {
            RequireContract = function() return true end,
            Npc = entity({[3615] = {[1] = "Devrak", [7] = {[17] = {{51.5, 30.3}}}, [10] = {900},
                [13] = "H", [14] = "Wind Rider Master", [15] = 8}}),
            Object = entity({[417072] = {[1] = "Nailed Plank", [3] = {79008}, [4] = {[17] = {{46.39, 73.82}}}},
                [5000] = {[1] = "Crate", [4] = {[17] = {{20, 20}}}}}),
            Quest = entity({[79008] = {[1] = "... and that note you found", [3] = {nil, {417072}}, [10] = {}},
                [900] = {[1] = "A Quest"}, [98071] = {[1] = "Brewer's Trade", [3] = {{3615}}},
                [901] = {[1] = "Located", [10] = {nil, {{5000}}}}}),
            Item = entity({}),
            Support = {Get = function(name)
                if name == "ZoneDB" then return {private = {uiMapIdToAreaId = "[1413] = 17, [1436] = 40,"}} end
            end},
        }
        env.loadAddon()
        env.fire("PLAYER_LOGIN")
        env.fire("PLAYER_ENTERING_WORLD")
        env.tick(3, 60)
        Mock.eq((env.WalkMapLiveDB.State()), "ready", "QuestieDB read: " .. tostring(env.WalkMapLiveDB.Status()))
        local core = env.WalkMapCore
        if not core.frame:IsShown() then env.WalkMap_Toggle() end
        env.tick(3, 30)
        Mock.eq(core.CurrentMap(), 1413, "The Barrens shown")
        local found
        for _, child in ipairs(core.canvas.__children) do
            if child.questID == 79008 and child.turnInName == "Nailed Plank" and child:IsShown() then found = child end
        end
        Mock.ok(found, "a turn-in marker for the quest is on the map")
        Mock.eq(found.ready, true, "drawn as ready to turn in")
        Mock.eq(string.format("%.4f", found.mapPercentX), "0.4639", "at the plank (x)")
        Mock.eq(string.format("%.4f", found.mapPercentY), "0.7382", "at the plank (y)")
        -- Quest icons are off by default. The game's marker still shows for
        -- the quest QuestieDB cannot place, and not for the one it can.
        local shown = {}
        for _, child in ipairs(core.canvas.__children) do
            if child.questID and child.ready ~= nil and child:IsShown() and not child.turnInName then
                shown[child.questID] = true
            end
        end
        Mock.eq(shown[98071], true, "the game's marker for Brewer's Trade is shown")
        Mock.eq(shown[901], nil, "no game marker for a quest QuestieDB places")
    end},
    {"map control: the cross moves when the map cannot scroll", function(Mock)
        local env = boot(Mock)
        local core = env.WalkMapCore
        if not core.frame:IsShown() then env.WalkMap_Toggle() end
        env.tick(1, 10)
        local cross = core.crosshair
        Mock.eq(core.ZoomIndex(), 1, "zoomed all the way out")
        local x0, y0 = cross.ViewCenter()
        Mock.eq(string.format("%.2f,%.2f", x0, y0), "0.50,0.50", "the cross starts in the middle")
        core.PadPan(-1, 0) -- D-pad right
        local x1, y1 = cross.ViewCenter()
        Mock.ok(x1 > x0 + 0.05, "right moves the cross right over the map")
        Mock.eq(string.format("%.2f", y1), "0.50", "and not up or down")
        core.PadPan(0, 1) -- D-pad down
        local _, y2 = cross.ViewCenter()
        Mock.ok(y2 > y1 + 0.05, "down moves the cross down the map")
        core.PadPan(1, 0) -- D-pad left: back to the middle column
        local x3 = cross.ViewCenter()
        Mock.eq(string.format("%.2f", x3), "0.50", "left brings it back")
        for _ = 1, 40 do core.PadPan(-1, 0) end
        local x4 = cross.ViewCenter()
        Mock.ok(x4 > 0.9 and x4 <= 1, "the cross stops at the map's edge, still on the map")
        for _ = 1, 40 do core.PadPan(0, -1) end
        local _, y5 = cross.ViewCenter()
        Mock.ok(y5 >= 0 and y5 < 0.1, "and at the top edge")
        cross.walkmapPlace(0, 0)
        local x6, y6 = cross.ViewCenter()
        Mock.eq(string.format("%.2f,%.2f", x6, y6), "0.50,0.50", "reset puts it back in the middle")
    end},
    {"map control zoomed in: the map scrolls first, the cross takes over at the edge", function(Mock)
        local env = boot(Mock)
        local core = env.WalkMapCore
        if not core.frame:IsShown() then env.WalkMap_Toggle() end
        env.tick(1, 10)
        core.Zoom(1)
        Mock.ok(core.ZoomIndex() > 1, "zoomed in")
        local cross = core.crosshair
        local last = cross.ViewCenter()
        local scrolled, crossMoved = 0, 0
        for _ = 1, 60 do
            core.PadPan(-1, 0) -- D-pad right
            local x = cross.ViewCenter()
            Mock.ok(x >= last - 1e-9, "the cross never jumps back while moving right")
            if x > last + 1e-9 then
                if cross.walkmapX == 0 then scrolled = scrolled + 1 else crossMoved = crossMoved + 1 end
            end
            last = x
        end
        Mock.ok(scrolled > 0, "the map scrolled while it could")
        Mock.ok(crossMoved > 0, "then the cross moved on towards the edge")
        Mock.ok(last > 0.9 and last <= 1, "and reached the right edge of the map")
        -- Going back: the cross returns to the middle before the map scrolls.
        local offset = cross.walkmapX
        core.PadPan(1, 0)
        Mock.ok(cross.walkmapX < offset, "left first brings the cross back")
        for _ = 1, 60 do core.PadPan(1, 0) end
        Mock.eq(cross.walkmapX < 0, true, "and it ends at the left edge")
        local left = cross.ViewCenter()
        Mock.ok(left >= 0 and left < 0.1, "on the left edge of the map")
    end},
    {"map control with a readable controller: tap nudges, hold moves until release", function(Mock)
        local env = boot(Mock)
        local core = env.WalkMapCore
        if not core.frame:IsShown() then env.WalkMap_Toggle() end
        env.tick(1, 10)
        local cross = core.crosshair
        local buttons = {}
        for i = 1, 20 do buttons[i] = false end
        env.C_GamePad = {GetActiveDeviceID = function() return 1 end,
            GetDeviceMappedState = function() return {buttons = buttons} end}
        cross:Show() -- map control on: the cross's OnUpdate runs
        local function x() return (cross.ViewCenter()) end
        local start = x()
        -- A tap on D-pad right (button 14 on this pad): down, event, up.
        buttons[14] = true
        cross.walkmapQueue(-1, 0)
        buttons[14] = false
        local tapped = x()
        Mock.ok(tapped > start and tapped - start < 0.005, "a tap moves the cross a tiny bit")
        env.tick(1, 60)
        Mock.eq(x(), tapped, "and nothing more after release")
        -- Tap again straight away: another nudge of the same size.
        buttons[14] = true cross.walkmapQueue(-1, 0) buttons[14] = false
        Mock.ok(math.abs((x() - tapped) - (tapped - start)) < 1e-9, "every tap is the same small nudge")
        env.tick(1, 60)
        -- Hold: moves every frame, slowly first, faster later, with repeats
        -- arriving unevenly as in the game.
        local before = x()
        buttons[14] = true
        cross.walkmapQueue(-1, 0)
        local positions = {x()}
        for frame = 1, 90 do
            env.tick(1 / 60)
            if frame == 36 or frame == 50 or frame == 68 or frame == 80 then cross.walkmapQueue(-1, 0) end
            positions[#positions + 1] = x()
        end
        for i = 2, #positions do Mock.ok(positions[i] > positions[i - 1], "moves on every frame while held") end
        local early = positions[11] - positions[2]
        local late = positions[#positions] - positions[#positions - 9]
        Mock.ok(late > early * 3, "it speeds up the longer the D-pad is held")
        buttons[14] = false
        env.tick(1 / 60)
        local released = x()
        env.tick(1, 60)
        Mock.eq(x(), released, "stops the moment the D-pad is released")
        Mock.ok(released > before + 0.2, "and has travelled a good way")
    end},
    {"map control without a readable controller: repeats keep it moving, then it eases out", function(Mock)
        local env = boot(Mock)
        local core = env.WalkMapCore
        if not core.frame:IsShown() then env.WalkMap_Toggle() end
        env.tick(1, 10)
        local cross = core.crosshair
        env.C_GamePad = nil
        cross:Show()
        local function y() local _, value = cross.ViewCenter() return value end
        local start = y()
        cross.walkmapQueue(0, 1) -- D-pad down
        local tapped = y()
        Mock.ok(tapped > start and tapped - start < 0.005, "a tap is a small nudge")
        env.tick(2, 120)
        Mock.eq(y(), tapped, "a single press does not keep moving")
        -- Held: the first repeat comes late, the rest a few times a second.
        cross.walkmapQueue(0, 1)
        env.tick(0.6, 36)
        cross.walkmapQueue(0, 1)
        local moving = {}
        for frame = 1, 60 do
            env.tick(1 / 60)
            if frame % 14 == 0 then cross.walkmapQueue(0, 1) end
            moving[#moving + 1] = y()
        end
        for i = 2, #moving do Mock.ok(moving[i] > moving[i - 1], "keeps moving between repeats") end
        env.tick(0.6, 36)
        local stopped = y()
        env.tick(1, 60)
        Mock.eq(y(), stopped, "stops within half a second of the last repeat")
    end},
    {"slash commands still reach their code after the split", function(Mock)
        local env = boot(Mock)
        local slash = env.SlashCmdList.WALKMAP
        local before = #env.__printed
        slash("pad status")
        Mock.ok(#env.__printed > before, "/walkmap pad status prints")
        Mock.ok(env.__printed[#env.__printed]:find("Controller navigation", 1, true), "pad status text")
        slash("db")
        Mock.ok(#env.__printed > before + 1, "/walkmap db prints")
        -- With Pad focus off the pause does not stick; the point is that
        -- the command reaches the map's own pad code without an error.
        slash("pad pause")
        slash("pad resume")
        Mock.eq((env.WalkMapCore.PadState()), false, "/walkmap pad resume")
        local frame = env.WalkMapCore.frame
        local was = frame:IsShown()
        slash("")
        Mock.eq(frame:IsShown(), not was, "/walkmap toggles the map")
    end},
    {"tracker scope: new characters and older saves get 'this zone + nearby' once", function(Mock)
        local fresh = {}
        boot(Mock, {}, fresh)
        Mock.eq(fresh.trackerScope, "nearby", "new character")
        local old = {trackerScope = "zone"}
        boot(Mock, {}, old)
        Mock.eq(old.trackerScope, "nearby", "save from before 1.11")
        local chose = {trackerScope = "zone", trackerNearbySeen = true}
        boot(Mock, {}, chose)
        Mock.eq(chose.trackerScope, "zone", "a later choice of 'this zone' is kept")
        local all = {trackerScope = "all"}
        boot(Mock, {}, all)
        Mock.eq(all.trackerScope, "all", "'all zones' is kept")
    end},
}
