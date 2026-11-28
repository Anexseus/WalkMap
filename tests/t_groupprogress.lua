-- WalkMap_GroupProgress.lua: your quest progress to the party, theirs in
-- the tracker under the quests you share.
local function start(Mock, character)
    local env = Mock.new({playerMap = 1436, onMap = {[1436] = {101, 102}}, quests = {
        {header = "Westfall"},
        {id = 101, title = "Westfall Stew", level = 13, objectives = {
            {text = "Okra: 2/3", numFulfilled = 2, numRequired = 3, finished = false},
            {text = "Goretusk Snout: 0/3", numFulfilled = 0, numRequired = 3, finished = false},
        }},
        {id = 102, title = "Poor Old Blanchy", level = 12, objectives = {
            {text = "Handful of Oats: 8/8", numFulfilled = 8, numRequired = 8, finished = true},
        }},
    }})
    env.__party = {}
    env.IsInGroup = function() return #env.__party > 0 end
    env.IsInRaid = function() return false end
    local realName = env.UnitName
    env.UnitName = function(unit)
        local n = tostring(unit):match("^party(%d)$")
        if n then return env.__party[tonumber(n)] end
        return realName and realName(unit) or "Me"
    end
    env.UnitClass = function(unit)
        if tostring(unit):match("^party") then return "Priest", "PRIEST" end
        return "Mage", "MAGE"
    end
    env.RAID_CLASS_COLORS = {PRIEST = {r = 1, g = 1, b = 1}, MAGE = {r = 0.25, g = 0.78, b = 0.92}}
    env.__sent = {}
    env.C_ChatInfo = {SendAddonMessage = function(prefix, text, channel, target)
        env.__sent[#env.__sent + 1] = {prefix = prefix, text = text, channel = channel}
    end, RegisterAddonMessagePrefix = function() return true end}
    local chars = {welcomeSeen = true}
    for k, v in pairs(character or {}) do chars[k] = v end
    env.loadAddon({welcomeSeen = true, newsSeen = "1.14.22"}, chars)
    env.fire("PLAYER_LOGIN")
    env.fire("PLAYER_ENTERING_WORLD")
    env.tick(1, 5)
    return env
end

local function sentWith(env, kind)
    local found = {}
    for _, m in ipairs(env.__sent) do
        if m.prefix == "WalkMapQP" and m.text:sub(1, 1) == kind then found[#found + 1] = m end
    end
    return found
end

return {
    {"Alone: nothing sent; in a party: your quests go to PARTY", function(Mock)
        local env = start(Mock)
        env.tick(5, 50)
        Mock.eq(#env.__sent, 0, "nothing sent outside a party")
        env.__party = {"Anna"}
        env.fire("GROUP_ROSTER_UPDATE")
        env.tick(5, 50)
        Mock.eq(#sentWith(env, "R"), 1, "asks the newcomer for theirs")
        local p = sentWith(env, "P")
        Mock.ok(p[1], "progress sent")
        Mock.eq(p[1].channel, "PARTY", "to the party")
        Mock.eq(p[1].text, "P;101=0=2/3,0/3;102=0=8/8", "both quests, packed in one message")
        -- One step more: only that quest again.
        env.__quests[2].objectives[2] = {text = "Goretusk Snout: 1/3", numFulfilled = 1, numRequired = 3}
        env.fire("QUEST_LOG_UPDATE")
        env.tick(5, 50)
        p = sentWith(env, "P")
        Mock.eq(p[#p].text, "P;101=0=2/3,1/3", "just the change")
        -- Abandoned: said so.
        table.remove(env.__quests, 3)
        env.fire("QUEST_REMOVED")
        env.tick(5, 50)
        Mock.eq(sentWith(env, "G")[1].text, "G;102", "gone from the log")
    end},
    {"Their progress shows in the tracker under the shared quest", function(Mock)
        local env = start(Mock)
        env.__party = {"Anna"}
        env.fire("GROUP_ROSTER_UPDATE")
        env.fire("CHAT_MSG_ADDON", "WalkMapQP", "P;101=0=3/3,1/3;999=0=0/1", "PARTY", "Anna-TestRealm")
        local lines = env.WalkMapGroupProgress.Lines(101)
        Mock.eq(#lines, 1, "one line for Anna")
        Mock.ok(lines[1][1]:find("Anna", 1, true), "her name")
        Mock.ok(lines[1][1]:find("|cff80f0803/3|r, 1/3", 1, true), "her numbers, finished in green")
        Mock.eq(#env.WalkMapGroupProgress.Lines(102), 0, "not on a quest she does not have")
        env.fire("CHAT_MSG_ADDON", "WalkMapQP", "P;101=1=3/3,3/3", "PARTY", "Anna-TestRealm")
        Mock.ok(env.WalkMapGroupProgress.Lines(101)[1][1]:find("ready", 1, true), "ready to turn in")
        -- The tracker draws it, under Westfall Stew.
        env.WalkMapTracker.Refresh()
        env.tick(1, 10)
        local drawn = false
        for _, block in ipairs(env.WalkMapZoneTracker.__children) do
            if block.__shown and block.lines and block.questID == 101 then
                for _, line in ipairs(block.lines) do
                    if line.__shown and tostring(line:GetText()):find("Anna", 1, true) then drawn = true end
                end
            end
        end
        Mock.ok(drawn, "Anna's line in the tracker")
        -- Someone not in the party is ignored; leaving clears.
        env.fire("CHAT_MSG_ADDON", "WalkMapQP", "P;102=0=1/8", "PARTY", "Stranger-TestRealm")
        Mock.eq(#env.WalkMapGroupProgress.Lines(102), 0, "a stranger's message is ignored")
        env.__party = {}
        env.fire("GROUP_ROSTER_UPDATE")
        env.tick(1, 5)
        Mock.eq(#env.WalkMapGroupProgress.Lines(101), 0, "gone when the party is")
    end},
    {"Off in Settings: nothing sent, nothing shown", function(Mock)
        local env = start(Mock, {groupProgress = false})
        env.__party = {"Anna"}
        env.fire("GROUP_ROSTER_UPDATE")
        env.tick(5, 50)
        Mock.eq(#sentWith(env, "P") + #sentWith(env, "R"), 0, "nothing sent")
        env.fire("CHAT_MSG_ADDON", "WalkMapQP", "P;101=0=3/3,1/3", "PARTY", "Anna-TestRealm")
        Mock.eq(#env.WalkMapGroupProgress.Lines(101), 0, "nothing shown")
    end},
}
