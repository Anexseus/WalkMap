-- Linking a quest in chat (WalkMap_QuestInfo.lua). WalkMap must never open
-- or focus the chat line itself; it only inserts into a focused chat line.
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
    local chat = {inserted = {}, forbidden = 0, focused = false, hooks = {}}
    local box = {}
    function box:HasFocus() return chat.focused end
    function box:Insert(text) chat.inserted[#chat.inserted + 1] = text end
    function box:SetFocus() chat.forbidden = chat.forbidden + 1 end
    function box:HookScript(script, fn) if script == "OnEditFocusGained" then chat.hooks[#chat.hooks + 1] = fn end end
    env.NUM_CHAT_WINDOWS = 1
    env.ChatFrame1EditBox = box
    -- The player opens the chat line (Enter, or the controller).
    function chat.open()
        chat.focused = true
        env.ACTIVE_CHAT_EDIT_BOX = box
        for _, fn in ipairs(chat.hooks) do fn(box) end
    end
    env.ChatEdit_InsertLink = function() chat.forbidden = chat.forbidden + 1 end
    env.ChatFrame_OpenChat = function() chat.forbidden = chat.forbidden + 1 end
    env.ChatFrameUtil = {OpenChat = env.ChatFrame_OpenChat, InsertLink = env.ChatEdit_InsertLink,
        ActivateChat = env.ChatFrame_OpenChat}
    return env, chat
end

local function rowsOf(env)
    env.WalkMapQuestLog.Open()
    env.tick(1, 10)
    local rows = {}
    for _, child in ipairs(env.WalkMapQuestLog.Panel().__children) do
        if child.__kind == "Button" and child.questID and child:IsShown() then rows[child.questID] = child end
    end
    return rows
end

return {
    {"Link: the game's link when it has one, else the title", function(Mock)
        local env = start(Mock)
        local text, real = env.WalkMapQuestInfo.Link(101)
        Mock.eq(text, "[Westfall Stew]", "plain title without GetQuestLink")
        Mock.eq(real, false, "marked as plain text")
        env.GetQuestLink = function(id) return "|cffffff00|Hquest:" .. id .. ":13|h[Westfall Stew]|h|r" end
        text, real = env.WalkMapQuestInfo.Link(101)
        Mock.ok(text:find("|Hquest:101:13|h", 1, true), "game link used")
        Mock.eq(real, true, "marked as game link")
        env.GetQuestLink = function() error("boom") end
        Mock.eq(env.WalkMapQuestInfo.Link(101), "[Westfall Stew]", "an error falls back to the title")
        env.GetQuestLink = function() return nil end
        Mock.eq(env.WalkMapQuestInfo.Link(101), "[Westfall Stew]", "nil falls back to the title")
    end},
    {"Link: a focused chat line gets it at once", function(Mock)
        local env, chat = start(Mock)
        chat.open()
        Mock.eq(env.WalkMapQuestInfo.LinkToChat(102), true, "linked now")
        Mock.eq(chat.inserted[1], "[Poor Old Blanchy]", "inserted into the focused chat line")
        Mock.eq(env.WalkMapQuestInfo.PendingLink(), false, "nothing waiting")
        Mock.eq(chat.forbidden, 0, "WalkMap never opens or focuses chat itself")
    end},
    {"Link: with chat closed it waits until the player opens chat", function(Mock)
        local env, chat = start(Mock)
        Mock.eq(env.WalkMapQuestInfo.LinkToChat(101), false, "not linked yet")
        Mock.eq(#chat.inserted, 0, "nothing inserted with chat closed")
        Mock.eq(env.WalkMapQuestInfo.PendingLink(), true, "waiting for chat")
        Mock.ok(env.__printed[#env.__printed]:find("open the chat line", 1, true), "the player is told")
        chat.open()
        env.tick(0.1, 2)
        Mock.eq(chat.inserted[1], "[Westfall Stew]", "inserted when the player opened chat")
        Mock.eq(env.WalkMapQuestInfo.PendingLink(), false, "used once")
        chat.open()
        env.tick(0.1, 2)
        Mock.eq(#chat.inserted, 1, "not inserted a second time")
        Mock.eq(chat.forbidden, 0, "WalkMap never opens or focuses chat itself")
    end},
    {"Link: a waiting quest is dropped after 30 seconds", function(Mock)
        local env, chat = start(Mock)
        env.WalkMapQuestInfo.LinkToChat(101)
        env.tick(31, 31)
        Mock.eq(env.WalkMapQuestInfo.PendingLink(), false, "expired")
        chat.open()
        env.tick(0.1, 2)
        Mock.eq(#chat.inserted, 0, "nothing inserted after it expired")
    end},
    {"Quest log: Shift-click links and keeps the selection", function(Mock)
        local env, chat = start(Mock)
        local rows = rowsOf(env)
        rows[101]:GetScript("OnClick")(rows[101])
        Mock.eq(env.WalkMapQuestLog.SelectedID(), 101, "plain click selects")
        chat.open()
        Mock.eq(#chat.inserted, 0, "plain click does not link")
        env.IsShiftKeyDown = function() return true end
        rows[102]:GetScript("OnClick")(rows[102])
        Mock.eq(chat.inserted[1], "[Poor Old Blanchy]", "Shift-click links the clicked quest")
        Mock.eq(env.WalkMapQuestLog.SelectedID(), 101, "selection unchanged")
    end},
    {"Quest log: the Link button links the selected quest", function(Mock)
        local env, chat = start(Mock)
        local rows = rowsOf(env)
        rows[102]:GetScript("OnClick")(rows[102])
        local link, abandon
        for _, child in ipairs(env.WalkMapQuestLog.Panel().__children) do
            local text = child.label and child.label.GetText and child.label:GetText()
            if text == "Link" then link = child end
            if text == "Abandon" then abandon = child end
        end
        Mock.ok(link and link:IsShown(), "Link button shown for the selected quest")
        Mock.ok(abandon and abandon:IsShown(), "Abandon still there")
        link:GetScript("OnClick")(link)
        Mock.eq(#chat.inserted, 0, "chat closed: nothing inserted yet")
        chat.open()
        env.tick(0.1, 2)
        Mock.eq(chat.inserted[1], "[Poor Old Blanchy]", "the selected quest is put in when chat opens")
        Mock.eq(env.WalkMapQuestLog.SelectedID(), 102, "selection unchanged")
        Mock.eq(chat.forbidden, 0, "WalkMap never opens or focuses chat itself")
    end},
    {"Quest log: Untrack removes the quest from WalkMap's tracker, Track brings it back", function(Mock)
        local env = start(Mock)
        local rows = rowsOf(env)
        rows[102]:GetScript("OnClick")(rows[102])
        local track
        for _, child in ipairs(env.WalkMapQuestLog.Panel().__children) do
            local text = child.label and child.label.GetText and child.label:GetText()
            if text == "Untrack" or text == "Track" then track = child end
        end
        Mock.ok(track, "Track button")
        Mock.eq(track.label:GetText(), "Untrack", "a listed quest offers Untrack")
        track:GetScript("OnClick")(track)
        Mock.eq(env.WalkMapExtras.TrackerHidden(102), true, "quest removed from the tracker")
        Mock.eq(track.label:GetText(), "Track", "button now offers Track")
        env.tick(1, 5)
        for _, child in ipairs(env.WalkMapZoneTracker.__children) do
            if child.__kind == "Button" and child.questID == 102 then
                Mock.ok(not child.__shown, "quest 102 is not in the tracker")
            end
        end
        track:GetScript("OnClick")(track)
        Mock.eq(env.WalkMapExtras.TrackerHidden(102), false, "Track brings it back")
        Mock.eq(track.label:GetText(), "Untrack", "button offers Untrack again")
    end},
    {"Quest log: B from the buttons goes back to the list after Abandon", function(Mock)
        local env = start(Mock)
        local rows = rowsOf(env)
        rows[102]:GetScript("OnClick")(rows[102])
        local panel = env.WalkMapQuestLog.Panel()
        local abandon
        for _, child in ipairs(panel.__children) do
            local text = child.label and child.label.GetText and child.label:GetText()
            if text == "Abandon" then abandon = child end
        end
        Mock.ok(abandon, "Abandon button")
        local focused
        env.WalkMapNativeController.IsSelecting = function(frame) return frame == abandon end
        env.WalkMapNativeController.FocusButton = function(_, button) focused = button end
        -- The list moved under a resting mouse pointer: a row reported "list".
        panel.walkmapFocusArea = "list"
        panel.walkmapSelectedRow = nil
        Mock.eq(panel.walkmapOnBack(), true, "B is handled although the remembered area says list")
        Mock.ok(focused and focused.questID, "focus goes to a quest row")
        env.WalkMapNativeController.IsSelecting = function() return false end
        focused = nil
        Mock.eq(panel.walkmapOnBack(), false, "B on the list itself is left to close the log")
        Mock.eq(focused, nil, "and moves nothing")
    end},
    {"Tracker: Shift-click links instead of opening, also in combat", function(Mock)
        local env, chat = start(Mock)
        local opened = {}
        env.WalkMapQuestLog.OpenQuest = function(id) opened[#opened + 1] = id end
        local block
        for _, child in ipairs(env.WalkMapZoneTracker.__children) do
            if child.__kind == "Button" and child.questID == 101 then block = child end
        end
        Mock.ok(block, "tracker block for quest 101")
        block:GetScript("OnClick")(block)
        Mock.eq(opened[1], 101, "plain click opens the quest")
        env.IsShiftKeyDown = function() return true end
        env.__combat = true
        chat.open()
        block:GetScript("OnClick")(block)
        Mock.eq(#opened, 1, "Shift-click does not open the quest log")
        Mock.eq(chat.inserted[1], "[Westfall Stew]", "Shift-click links, in combat too")
    end},
}
