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
    env.loadAddon({welcomeSeen = true, newsSeen = "1.14.7"}, chars)
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
        env.WalkMapFriends.Scan()
        openMap(env)
        env.WalkMapFriends.Refresh(1436)
        local pins = env.WalkMapFriends.Pins()
        local shown
        for _, p in ipairs(pins) do if p:IsShown() then shown = p end end
        Mock.ok(shown, "a zone badge on Westfall")
        Mock.eq(shown.lines[1].text, "Westfall (1)", "one online guild member here (not you, not offline)")
        Mock.eq(shown.lines[2].text, "Anna  18", "name and level")
        Mock.eq(shown.lines[2].right, "Guild", "tagged Guild")
        local point, relative = shown:GetPoint(1)
        Mock.eq(point, "TOPRIGHT", "the zone you look at: badge in the map's top-right corner")
        Mock.eq(relative, env.WalkMapCore.viewport, "on the map window, not on the map art")
        env.WalkMapCharacterSettings.guildOnMap = false
        env.WalkMapFriends.Refresh(1436)
        local any = false
        for _, p in ipairs(env.WalkMapFriends.Pins()) do if p:IsShown() then any = true end end
        Mock.eq(any, false, "Guild on the map off: no badge")
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
}
