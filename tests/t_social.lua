-- Unexplored areas (WalkMap.lua + WalkMap_RevealData.lua) and friends and
-- guild on the map (WalkMap_Friends.lua, OpenMap's message format).
local EXPLORED = {textureWidth = 128, textureHeight = 110, offsetX = 464, offsetY = 33, fileDataIDs = {271427}}

local function start(Mock, character, setup)
    local env = Mock.new({playerMap = 1436})
    env.C_Map.GetMapArtID = function(id) return id == 1436 and 1194 or nil end
    env.C_MapExplorationInfo = {GetExploredMapTextures = function(id)
        return id == 1436 and {EXPLORED} or {}
    end}
    env.GetNormalizedRealmName = function() return "TestRealm" end
    env.UnitName = function() return "Me" end
    env.UnitClass = function() return "Mage", "MAGE" end
    env.UnitLevel = function() return 20 end
    env.UnitFactionGroup = function() return "Alliance" end
    env.IsInInstance = function() return env.__instance or false end
    env.IsInGroup = function() return false end
    env.__sent = {}
    env.C_ChatInfo = {SendAddonMessage = function(prefix, text, channel, target)
        env.__sent[#env.__sent + 1] = {prefix = prefix, text = text, channel = channel, target = target}
    end, RegisterAddonMessagePrefix = function() return true end}
    if setup then setup(env) end
    local chars = {welcomeSeen = true}
    for k, v in pairs(character or {}) do chars[k] = v end
    env.loadAddon({welcomeSeen = true, newsSeen = "1.14.8"}, chars)
    env.fire("PLAYER_LOGIN")
    env.fire("PLAYER_ENTERING_WORLD")
    env.tick(1, 5)
    return env
end

local function openMap(env)
    env.WalkMap_Toggle()
    env.tick(1, 10)
end

local function guild(env, members)
    env.IsInGuild = function() return true end
    env.GetNumGuildMembers = function() return #members end
    env.GetGuildRosterInfo = function(i)
        local m = members[i]
        -- name, rank, rankIndex, level, class(local), zone, note, officernote, online, status, classFile
        return m[1], "", 0, m[2], m[3], m[4], "", "", m[5], 0, m[3]
    end
end

return {
    {"Unexplored areas: the pieces the game does not list, only when turned on", function(Mock)
        local env = start(Mock, {unexplored = true})
        openMap(env)
        -- Art 1194 has 11 pieces (one of them two tiles wide); one is explored.
        Mock.eq(env.WalkMapCore.UnexploredShown(), 11, "ten unexplored pieces, eleven tiles")
        env.WalkMapExtras.SettingsRowValue = nil
        env.WalkMapCharacterSettings.unexplored = false
        env.WalkMapCore.RefreshExploration()
        env.tick(1, 10)
        Mock.eq(env.WalkMapCore.UnexploredShown(), 0, "off: none")
    end},
    {"Unexplored areas are off by default", function(Mock)
        local env = start(Mock)
        openMap(env)
        Mock.eq(env.WalkMapCore.UnexploredShown(), 0, "nothing extra drawn")
    end},
    {"Guild by zone: a badge on Westfall with who is there", function(Mock)
        local env = start(Mock, nil, function(env)
            guild(env, {{"Anna-TestRealm", 18, "PRIEST", "Westfall", true},
                {"Bo-TestRealm", 30, "WARRIOR", "Duskwood", true},
                {"Cid-TestRealm", 12, "MAGE", "Westfall", false},
                {"Me-TestRealm", 20, "MAGE", "Westfall", true}})
        end)
        env.C_Map.GetMapRectOnMap = function(zone, on)
            if zone == 1436 and on == 1415 then return 0.2, 0.4, 0.5, 0.7 end
        end
        env.WalkMapFriends.Scan()
        openMap(env)
        env.WalkMapFriends.Refresh(1436)
        -- The zone you look at: no badge on the map; the toolbar button lists them.
        for _, p in ipairs(env.WalkMapFriends.Pins()) do
            Mock.ok(not p:IsShown(), "no badge in the middle of Westfall")
        end
        local tab = env.WalkMapFriends.Tab()
        Mock.ok(tab and tab:IsShown(), "friends button on the toolbar")
        local point, _, _, x = tab:GetPoint(1)
        Mock.eq(point, "TOPRIGHT", "at the toolbar's end")
        Mock.eq(x, -38, "left of the quest log button")
        local lines = tab.walkmapLines()
        Mock.eq(lines[1].text, "Westfall (1)", "one online guild member here (not you, not offline)")
        Mock.eq(lines[2].text, "Anna  18", "name and level")
        Mock.eq(lines[2].right, "Guild", "tagged Guild")
        Mock.eq(tab.count:GetText(), 1, "count on the button")
        -- Click: a list of who is here; picking one invites them.
        local invited
        env.C_PartyInfo = {InviteUnit = function(name) invited = name end}
        local options = env.WalkMapFriends.InviteOptions()
        Mock.eq(#options, 1, "Anna to invite")
        Mock.ok(options[1][2]:find("Invite", 1, true) and options[1][2]:find("Anna", 1, true), "row says Invite Anna")
        Mock.eq(options[1][3], "Guild", "tagged")
        options[1].run()
        Mock.eq(invited, "Anna-TestRealm", "invited")
        -- On the continent: a badge where Westfall is.
        env.WalkMapFriends.Refresh(1415)
        local badge
        for _, p in ipairs(env.WalkMapFriends.Pins()) do if p:IsShown() then badge = p end end
        Mock.ok(badge, "badge on the continent map")
        Mock.ok(math.abs(badge.mapPercentX - 0.3) < 1e-9, "in the middle of Westfall")
        Mock.eq(badge.lines[1].text, "Westfall (1)", "who is there")
        -- Off: no button, no badge.
        env.WalkMapCharacterSettings.guildOnMap = false
        env.WalkMapCharacterSettings.friendsOnMap = false
        env.WalkMapFriends.SettingChanged("guildOnMap")
        local any = false
        for _, p in ipairs(env.WalkMapFriends.Pins()) do if p:IsShown() then any = true end end
        Mock.eq(any, false, "no badge")
        Mock.eq(tab:IsShown(), false, "no button")
    end},
    {"Sharing is off by default: nothing sent, nobody's dot shown", function(Mock)
        local env = start(Mock, nil, function(env) guild(env, {}) end)
        env.WalkMapFriends.Tick()
        env.tick(2, 10)
        Mock.eq(#env.__sent, 0, "nothing sent")
        env.WalkMapFriends.Heard("Anna-TestRealm", "L1\t1436\t0.3\t0.4\tPRIEST\t18", true)
        openMap(env)
        env.WalkMapFriends.Refresh(1436)
        for _, p in ipairs(env.WalkMapFriends.Pins()) do
            Mock.ok(not (p:IsShown() and p.pinName == "Anna"), "no dot without sharing")
        end
    end},
    {"Share where you are: OpenMap's L1 to the guild, dots back, L0 in an instance", function(Mock)
        local env = start(Mock, {shareLocation = true}, function(env) guild(env, {}) end)
        env.WalkMapFriends.Tick()
        env.tick(2, 10)
        local first = env.__sent[1]
        Mock.ok(first, "sent")
        Mock.eq(first.prefix, "OpenMapLoc", "OpenMap's prefix")
        Mock.eq(first.channel, "GUILD", "to the guild")
        Mock.eq(first.text, "L1\t1436\t0.5000\t0.5000\tMAGE\t20", "OpenMap's place message")
        -- An OpenMap user in the guild shares theirs.
        env.fire("CHAT_MSG_ADDON", "OpenMapLoc", "L1\t1436\t0.3000\t0.4000\tPRIEST\t18", "GUILD", "Anna-TestRealm")
        openMap(env)
        env.WalkMapFriends.Refresh(1436)
        local dot
        for _, p in ipairs(env.WalkMapFriends.Pins()) do if p:IsShown() and p.pinName == "Anna" then dot = p end end
        Mock.ok(dot, "Anna's dot")
        Mock.eq(dot.mapPercentX, 0.3, "x") Mock.eq(dot.mapPercentY, 0.4, "y")
        -- Into a dungeon: stop, and say so.
        env.__instance = true
        env.WalkMapFriends.Tick()
        env.tick(2, 10)
        Mock.eq(env.__sent[#env.__sent].text, "L0", "stopped sharing")
        -- They stop: their dot goes.
        env.fire("CHAT_MSG_ADDON", "OpenMapLoc", "L0", "GUILD", "Anna-TestRealm")
        env.WalkMapFriends.Refresh(1436)
        for _, p in ipairs(env.WalkMapFriends.Pins()) do
            Mock.ok(not (p:IsShown() and p.pinName == "Anna"), "dot gone after L0")
        end
    end},
    {"Turning sharing off says L0 and stops sending", function(Mock)
        local env = start(Mock, {shareLocation = true}, function(env) guild(env, {}) end)
        env.WalkMapFriends.Tick()
        env.tick(2, 10)
        local count = #env.__sent
        env.WalkMapCharacterSettings.shareLocation = false
        env.WalkMapFriends.SettingChanged("shareLocation")
        env.tick(2, 10)
        Mock.eq(env.__sent[#env.__sent].text, "L0", "told them")
        local after = #env.__sent
        env.WalkMapFriends.Tick()
        env.tick(2, 10)
        Mock.eq(#env.__sent, after, "nothing more")
        Mock.ok(after > count, "L0 was sent")
    end},
    {"A in map control on the waypoint clears it; elsewhere sets it", function(Mock)
        local env = start(Mock)
        openMap(env)
        env.WalkMapWaypoint.PadAt(0.5, 0.5)
        local waypoint = env.WalkMapExtras.Waypoint()
        Mock.ok(waypoint and waypoint.x == 0.5, "set")
        env.WalkMapWaypoint.PadAt(0.5005, 0.5005)
        Mock.eq(env.WalkMapExtras.Waypoint(), nil, "A on the star clears it")
        env.WalkMapWaypoint.PadAt(0.5, 0.5)
        env.WalkMapWaypoint.PadAt(0.8, 0.2)
        Mock.eq(env.WalkMapExtras.Waypoint().x, 0.8, "A elsewhere moves it")
    end},
    {"Friend and guild member at once: one dot, one line, shown as Friend", function(Mock)
        local env = start(Mock, {shareLocation = true}, function(env)
            guild(env, {{"Anna-TestRealm", 18, "PRIEST", "Westfall", true}})
            env.C_FriendList = {GetNumFriends = function() return 1 end,
                GetFriendInfoByIndex = function() return {name = "Anna", connected = true, level = 18,
                    area = "Westfall", className = "Priest"} end}
        end)
        env.WalkMapFriends.Scan()
        openMap(env)
        -- Her place arrives twice: through the guild and as a whisper.
        env.fire("CHAT_MSG_ADDON", "OpenMapLoc", "L1\t1436\t0.3000\t0.4000\tPRIEST\t18", "GUILD", "Anna-TestRealm")
        env.fire("CHAT_MSG_ADDON", "OpenMapLoc", "L1\t1436\t0.3100\t0.4000\tPRIEST\t18", "WHISPER", "Anna")
        env.WalkMapFriends.Refresh(1436)
        local dots = 0
        local dot
        for _, p in ipairs(env.WalkMapFriends.Pins()) do
            if p:IsShown() and p.pinName == "Anna" then dots = dots + 1 dot = p end
        end
        Mock.eq(dots, 1, "one dot")
        Mock.eq(dot.lines[#dot.lines].text, "Friend", "shown as Friend")
        -- Not sharing herself: listed once on the toolbar button, as Friend.
        env.fire("CHAT_MSG_ADDON", "OpenMapLoc", "L0", "GUILD", "Anna-TestRealm")
        env.WalkMapFriends.Refresh(1436)
        local lines = env.WalkMapFriends.Tab().walkmapLines()
        Mock.eq(#lines, 3, "title, one line for her, the invite hint")
        Mock.eq(lines[2].right, "Friend", "Friend before Guild")
    end},
    {"A on a quest marker focuses the quest instead of setting a waypoint", function(Mock)
        local env = start(Mock)
        openMap(env)
        local cross = env.WalkMapCore.crosshair
        local marker = {questID = 101, GetScript = function() return nil end}
        cross.walkmapHoverPin = function() return marker end
        env.WalkMapWaypoint.PadAt(0.3, 0.3)
        Mock.eq(env.WalkMapExtras.QuestFocus(), 101, "quest focused")
        Mock.eq(env.WalkMapExtras.Waypoint(), nil, "no waypoint")
        cross.walkmapHoverPin = function() return nil end
        env.WalkMapWaypoint.PadAt(0.3, 0.3)
        Mock.ok(env.WalkMapExtras.Waypoint(), "off a marker: waypoint as before")
    end},
    {"Layers: same or other layer only when both sides know it", function(Mock)
        local env = start(Mock, {shareLocation = true}, function(env) guild(env, {}) end)
        local function dotLines()
            env.WalkMapFriends.Refresh(1436)
            for _, p in ipairs(env.WalkMapFriends.Pins()) do
                if p:IsShown() and p.pinName == "Anna" then return p.lines end
            end
        end
        local function has(lines, text)
            for _, line in ipairs(lines or {}) do if line.text == text then return true end end
            return false
        end
        openMap(env)
        env.fire("CHAT_MSG_ADDON", "OpenMapLoc", "L1\t1436\t0.3000\t0.4000\tPRIEST\t18", "GUILD", "Anna-TestRealm")
        env.fire("CHAT_MSG_ADDON", "OpenMapLoc", "W1\t1436\t5250", "GUILD", "Anna-TestRealm")
        Mock.eq(has(dotLines(), "Same layer as you"), false, "my layer unknown: nothing shown")
        -- Targeting a creature tells WalkMap my layer; it goes out with my place.
        env.UnitGUID = function() return "Creature-0-5250-0-1234-299-0000ABCDEF" end
        env.fire("PLAYER_TARGET_CHANGED")
        Mock.eq(env.WalkMapFriends.MyLayer(), "5250", "my layer: the creature's server part (as LayerETA)")
        env.WalkMapFriends.Tick()
        env.tick(3, 15)
        local sent = {}
        for _, m in ipairs(env.__sent) do sent[m.text] = true end
        Mock.ok(sent["W1\t1436\t5250"], "my layer sent")
        Mock.ok(has(dotLines(), "Same layer as you"), "same layer")
        env.fire("CHAT_MSG_ADDON", "OpenMapLoc", "W1\t1436\t6843", "GUILD", "Anna-TestRealm")
        Mock.ok(has(dotLines(), "Other layer than you"), "other layer")
        -- An OpenMap user sends no layer: nothing about layers is shown.
        env.fire("CHAT_MSG_ADDON", "OpenMapLoc", "L0", "GUILD", "Anna-TestRealm")
        env.fire("CHAT_MSG_ADDON", "OpenMapLoc", "L1\t1436\t0.3000\t0.4000\tPRIEST\t18", "GUILD", "Anna-TestRealm")
        local lines = dotLines()
        Mock.ok(lines, "dot back")
        Mock.eq(has(lines, "Same layer as you") or has(lines, "Other layer than you"), false, "no layer line")
        -- A player's GUID is no layer.
        env.UnitGUID = function() return "Player-5250-0ABCDEF" end
        env.fire("PLAYER_TARGET_CHANGED")
        Mock.eq(env.WalkMapFriends.MyLayer(), "5250", "unchanged by a player target")
        -- A pet carries the layer where it was made: skipped.
        env.UnitGUID = function() return "Creature-0-7777-0-1234-416-0000ABCDEF" end
        env.UnitPlayerControlled = function() return true end
        env.fire("PLAYER_TARGET_CHANGED")
        Mock.eq(env.WalkMapFriends.MyLayer(), "5250", "unchanged by a pet")
    end},
}
