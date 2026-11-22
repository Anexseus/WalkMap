-- WalkMap_QuestLog.lua: which quest the list selects for mouse and controller.
local function open(Mock)
    local env = Mock.new({playerMap = 1436, quests = {
        {header = "Westfall"},
        {id = 101, title = "Westfall Stew", level = 13},
        {id = 102, title = "Poor Old Blanchy", level = 12},
        {id = 103, title = "The Killing Fields", level = 12},
    }})
    env.loadAddon()
    env.fire("PLAYER_LOGIN")
    env.fire("PLAYER_ENTERING_WORLD")
    env.tick(1, 10)
    env.WalkMapQuestLog.Open()
    env.tick(1, 10)
    local log = env.WalkMapQuestLog
    Mock.ok(log.IsOpen(), "quest log open")
    local rows = {}
    for _, child in ipairs(log.Panel().__children) do
        if child.__kind == "Button" and child.questID and child:IsShown() then rows[child.questID] = child end
    end
    Mock.ok(rows[101] and rows[102] and rows[103], "three quest rows")
    env.__padFocused = true
    env.WalkMapNativeController.PadFocused = function() return env.__padFocused end
    local x = 0
    -- Move the mouse onto a row (the pointer really moved) and enter it.
    local function mouseEnter(row)
        for _, other in pairs(rows) do other.__mouseOver = false end
        x = x + 10
        env.__cursor = {x, 300}
        row.__mouseOver = true
        row:GetScript("OnEnter")(row)
    end
    return env, log, rows, mouseEnter
end

-- A quest log long enough for several pages.
local function openLong(Mock)
    local quests = {{header = "Westfall"}}
    for i = 1, 70 do quests[#quests + 1] = {id = 1000 + i, title = "Quest " .. i, level = 10} end
    local env = Mock.new({playerMap = 1436, quests = quests})
    env.loadAddon()
    env.fire("PLAYER_LOGIN")
    env.fire("PLAYER_ENTERING_WORLD")
    env.tick(1, 10)
    env.WalkMapQuestLog.Open()
    env.tick(1, 10)
    local focused = {}
    env.WalkMapNativeController.FocusButton = function(_, button) focused[#focused + 1] = button end
    return env, env.WalkMapQuestLog, focused
end

return {
    {"Redirect: a block while closing the game's window is counted, not a native failure", function(Mock)
        local env = Mock.new({playerMap = 1436, quests = {{header = "Westfall"}, {id = 101, title = "Westfall Stew", level = 13}}})
        env.loadAddon()
        env.WorldMapFrame = env.CreateFrame("Frame", "WorldMapFrame", env.UIParent)
        env.WorldMapFrame:Hide()
        env.fire("PLAYER_LOGIN")
        env.fire("PLAYER_ENTERING_WORLD")
        env.tick(1, 10)
        env.WalkMapExtras.UseGameMapKeys = function() return true end
        local during
        env.HideUIPanel = function(frame)
            during = env.WalkMapQuestLog.Intercepting()
            env.fire("ADDON_ACTION_FORBIDDEN", "WalkMap", "SetPreferredGamepadInteractTarget()")
            frame:Hide()
        end
        Mock.eq(env.WalkMapQuestLog.Intercepting(), false, "not closing anything at rest")
        env.WorldMapFrame:Show()
        env.tick(1, 10)
        Mock.eq(during, true, "flag set while the game's window is being closed")
        Mock.eq(env.WalkMapQuestLog.Intercepting(), false, "flag cleared afterwards")
        Mock.ok(not env.WorldMapFrame:IsShown(), "game map closed")
        Mock.ok(env.WalkMapQuestLog.InterceptStatus():find("blocked while closing 1 time", 1, true),
            "the block is counted: " .. env.WalkMapQuestLog.InterceptStatus())
    end},
    {"In combat, Quest & Maps with WalkMap open closes WalkMap (the game's map is not hidden behind)", function(Mock)
        local env = Mock.new({playerMap = 1436, quests = {{header = "Westfall"}, {id = 101, title = "Westfall Stew", level = 13}}})
        env.loadAddon()
        env.WorldMapFrame = env.CreateFrame("Frame", "WorldMapFrame", env.UIParent)
        env.WorldMapFrame:Hide()
        env.fire("PLAYER_LOGIN")
        env.fire("PLAYER_ENTERING_WORLD")
        env.tick(1, 10)
        env.WalkMapExtras.UseGameMapKeys = function() return true end
        env.WalkMap_Toggle()
        env.tick(0.2, 5)
        Mock.ok(env.WalkMapCore.frame:IsShown(), "WalkMap open")
        env.__combat = true
        local hidden = false
        env.HideUIPanel = function() hidden = true end
        env.WorldMapFrame:Show()
        env.tick(1, 10)
        Mock.ok(not env.WalkMapCore.frame:IsShown(), "WalkMap closed")
        Mock.eq(hidden, false, "the game's map is left alone in combat")
        env.__combat = false
    end},
    {"Inside a dungeon with DungeonJournal: M and the wheel open the game's map (optional)", function(Mock)
        local env = Mock.new({playerMap = 1436, quests = {{header = "Westfall"}, {id = 101, title = "Westfall Stew", level = 13}}})
        local overrides = {}
        env.GetBindingKey = function(action) if action == "TOGGLEWORLDMAP" then return "M" end end
        env.SetOverrideBindingClick = function(_, _, key, target) overrides[key] = target end
        env.ClearOverrideBindings = function() for k in pairs(overrides) do overrides[k] = nil end end
        env.C_AddOns = {IsAddOnLoaded = function(name) return name == "ForeverDungeonJournal" end}
        local inside = false
        env.IsInInstance = function() return inside, inside and "party" or "none" end
        env.loadAddon()
        env.WorldMapFrame = env.CreateFrame("Frame", "WorldMapFrame", env.UIParent)
        env.WorldMapFrame:Hide()
        env.fire("PLAYER_LOGIN")
        env.fire("PLAYER_ENTERING_WORLD")
        env.WalkMapExtras.UseGameMapKeys = function() return true end
        env.tick(1, 3)
        Mock.eq(overrides.M, "WalkMapKeyboardToggle", "outside: M opens WalkMap")
        inside = true
        env.tick(1, 3)
        Mock.eq(overrides.M, nil, "inside: M is the game's again")
        local hidden = false
        env.HideUIPanel = function() hidden = true end
        env.WorldMapFrame:Show()
        env.tick(1, 5)
        Mock.eq(hidden, false, "the wheel's game map stays open (DungeonJournal draws there)")
        Mock.eq(env.WalkMapExtras.DungeonMapAddon(), "DungeonJournal", "named in Settings/debug")
        -- Turned off: WalkMap again, also inside.
        env.WalkMapCharacterSettings.dungeonMapHandoff = false
        env.tick(1, 3)
        Mock.eq(overrides.M, "WalkMapKeyboardToggle", "setting off: M opens WalkMap inside too")
    end},
    {"Wheel closes WalkMap in combat (optional): the map button is held, the wheel's press closes WalkMap", function(Mock)
        local env = Mock.new({playerMap = 1436, quests = {{header = "Westfall"}, {id = 101, title = "Westfall Stew", level = 13}}})
        local enabled = true
        env.QuestLogMicroButton = env.CreateFrame("Button", "QuestLogMicroButton", env.UIParent)
        env.QuestLogMicroButton.IsEnabled = function() return enabled end
        env.QuestLogMicroButton.Enable = function() enabled = true end
        env.QuestLogMicroButton.Disable = function() enabled = false end
        env.RADIAL_ERROR_FALLBACK = "You can't do that right now."
        local cleared = 0
        env.UIErrorsFrame = env.CreateFrame("Frame", "UIErrorsFrame", env.UIParent)
        env.UIErrorsFrame.Clear = function() cleared = cleared + 1 end
        env.loadAddon({welcomeSeen = true, newsSeen = "1.14.11"}, {welcomeSeen = true, wheelClosesInCombat = true})
        env.fire("PLAYER_LOGIN")
        env.fire("PLAYER_ENTERING_WORLD")
        env.WalkMap_Toggle()
        env.tick(0.2, 5)
        Mock.eq(enabled, true, "out of combat the button is left alone")
        env.__combat = true
        env.fire("PLAYER_REGEN_DISABLED")
        env.tick(0.2, 3)
        Mock.eq(enabled, false, "WalkMap open in combat: button held")
        -- The wheel's press on the disabled map entry prints its red line.
        env.WalkMapWheelClose.OnError("You can't do that right now.")
        env.tick(0.2, 3)
        Mock.ok(not env.WalkMapCore.frame:IsShown(), "WalkMap closed")
        Mock.eq(cleared, 1, "the red line cleared")
        Mock.eq(enabled, true, "button back as WalkMap closed")
        -- Other red lines do nothing.
        env.WalkMap_Toggle()
        env.tick(0.2, 3)
        env.WalkMapWheelClose.OnError("Not enough rage")
        Mock.ok(env.WalkMapCore.frame:IsShown(), "another error leaves WalkMap open")
        env.__combat = false
        env.fire("PLAYER_REGEN_ENABLED")
        env.tick(0.2, 3)
        Mock.eq(enabled, true, "after combat the button is back")
    end},
    {"Wheel closes WalkMap in combat is off by default: the button is never touched", function(Mock)
        local env = Mock.new({playerMap = 1436})
        local touched = false
        env.QuestLogMicroButton = env.CreateFrame("Button", "QuestLogMicroButton", env.UIParent)
        env.QuestLogMicroButton.IsEnabled = function() return true end
        env.QuestLogMicroButton.Disable = function() touched = true end
        env.QuestLogMicroButton.Enable = function() touched = true end
        env.loadAddon({welcomeSeen = true, newsSeen = "1.14.11"}, {welcomeSeen = true})
        env.fire("PLAYER_LOGIN")
        env.WalkMap_Toggle()
        env.__combat = true
        env.fire("PLAYER_REGEN_DISABLED")
        env.tick(0.2, 5)
        Mock.eq(touched, false, "not touched")
        env.__combat = false
    end},
    {"Left/Right paging: moves a page and keeps the row", function(Mock)
        local env, log, focused = openLong(Mock)
        local page, pages = log.PageNumber()
        Mock.eq(page, 1, "starts on page 1")
        Mock.ok(pages >= 3, "several pages")
        Mock.eq(log.Panel().walkmapPages, pages, "the controller code can see the page count")
        Mock.eq(log.Page(-1, true, 4), false, "no page before the first")
        Mock.eq(log.Page(1, true, 4), true, "Right: next page")
        Mock.eq((log.PageNumber()), 2, "page 2")
        Mock.eq(focused[#focused], log.Panel().walkmapListItems[4], "focus stays on row 4")
        Mock.eq(log.Page(-1, true, 2), true, "Left: previous page")
        Mock.eq((log.PageNumber()), 1, "page 1 again")
        Mock.eq(focused[#focused], log.Panel().walkmapListItems[2], "focus on row 2")
        for _ = 1, pages do log.Page(1, true, 999) end
        Mock.eq((log.PageNumber()), pages, "stops on the last page")
        local list = log.Panel().walkmapListItems
        Mock.eq(focused[#focused], list[#list], "a row number past the end lands on the last row")
        Mock.eq(log.Page(1, true, 1), false, "no page after the last")
        -- The controller's Left/Right loop round.
        Mock.eq(log.Page(1, true, 3, true), true, "Right on the last page")
        Mock.eq((log.PageNumber()), 1, "loops to the first page")
        Mock.eq(focused[#focused], log.Panel().walkmapListItems[3], "same row")
        Mock.eq(log.Page(-1, true, 3, true), true, "Left on the first page")
        Mock.eq((log.PageNumber()), pages, "loops to the last page")
    end},
    {"a single page does not loop", function(Mock)
        local env, log = open(Mock)
        local _, pages = log.PageNumber()
        Mock.eq(pages, 1, "one page")
        Mock.eq(log.Page(1, true, 1, true), false, "Right does nothing")
        Mock.eq(log.Page(-1, true, 1, true), false, "Left does nothing")
    end},
    {"mouse: the clicked quest stays selected while the mouse passes other rows", function(Mock)
        local env, log, rows, mouseEnter = open(Mock)
        mouseEnter(rows[101])
        rows[101]:Click()
        Mock.eq(log.SelectedID(), 101, "clicked quest selected")
        -- On the way down to the action buttons the mouse crosses two rows.
        env.tick(0.1)
        mouseEnter(rows[102])
        env.tick(0.1)
        mouseEnter(rows[103])
        Mock.eq(log.SelectedID(), 101, "hovering with controller focus on does not select")
        rows[103]:GetScript("OnLeave")(rows[103])
        Mock.eq(log.SelectedID(), 101, "still the clicked quest")
    end},
    {"controller: focus moving to a row selects it, even with the pointer resting there", function(Mock)
        local env, log, rows, mouseEnter = open(Mock)
        mouseEnter(rows[101])
        rows[101]:Click()
        env.tick(3, 30) -- the mouse rests
        -- The controller's focus arrives on the row under the hidden pointer...
        rows[101].__mouseOver = false
        rows[102].__mouseOver = true
        rows[102]:GetScript("OnEnter")(rows[102])
        Mock.eq(log.SelectedID(), 102, "row under a resting pointer")
        -- ...and on a row away from it.
        rows[102].__mouseOver = false
        rows[103]:GetScript("OnEnter")(rows[103])
        Mock.eq(log.SelectedID(), 103, "row away from the pointer")
    end},
    {"mouse without controller focus: hover previews, click selects", function(Mock)
        local env, log, rows, mouseEnter = open(Mock)
        env.__padFocused = false
        mouseEnter(rows[101])
        rows[101]:Click()
        mouseEnter(rows[102])
        Mock.eq(log.SelectedID(), 101, "hover only previews")
        rows[102]:Click()
        Mock.eq(log.SelectedID(), 102, "click selects")
    end},
    {"Larger font (handheld at 720p): button labels shrink to stay inside", function(Mock)
        local env, log = open(Mock)
        env.__fontScale = 1.6
        log.Refresh()
        local checked = 0
        for _, child in ipairs(log.Panel().__children) do
            if child.__kind == "Button" and child.label and child.walkmapFit and child:IsShown() then
                local text = tostring(child.label:GetText() or "")
                if text ~= "" then
                    checked = checked + 1
                    Mock.ok(child.label:GetStringWidth() <= child:GetWidth() - 6,
                        "\"" .. text .. "\" fits its button")
                end
            end
        end
        Mock.ok(checked >= 4, "the action buttons and the zone filter were checked")
        -- Zone headers stay inside the list too, even a long one.
        env.__quests[1].title = "Excavation Site: Wetlands"
        env.__quests[1].isCollapsed = true
        log.Refresh()
        local headers = 0
        for _, child in ipairs(log.Panel().__children) do
            if child.text and child.count and child.arrow and child:IsShown() then
                headers = headers + 1
                local width = child.text:GetWidth() or 0
                if width <= 0 then width = child.text:GetStringWidth() end
                Mock.ok(width <= log.Panel():GetWidth() - 24 - 30, "header inside the list")
            end
        end
        Mock.ok(headers >= 1, "a header was checked")
        env.__fontScale = 1
        log.Refresh()
        for _, child in ipairs(log.Panel().__children) do
            if child.__kind == "Button" and child.label and child.walkmapFit and child.label.walkmapFont then
                Mock.eq(select(2, child.label:GetFont()), child.label.walkmapFont[2], "back to full size when it fits")
            end
        end
    end},
}
