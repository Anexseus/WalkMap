-- Low-level quests (Settings > Quests on the map): gray quests at quest
-- givers are hidden, shown when their chain goes on to your level, or all.
local function givers(Mock, lowQuests)
    local env = Mock.new({playerMap = 1436, level = 30})
    env.UnitLevel = function() return 30 end
    env.loadAddon({welcomeSeen = true, newsSeen = "1.14.20"}, {welcomeSeen = true, lowQuests = lowQuests})
    env.fire("PLAYER_LOGIN")
    env.fire("PLAYER_ENTERING_WORLD")
    env.WalkMapData.quests = {
        [601] = {0, 12, 0, 0, 0, name = "Chain Start"},
        [602] = {0, 20, 0, 0, 0, name = "Chain Middle"},
        [603] = {0, 32, 0, 0, 0, name = "Chain End"},
        [611] = {0, 10, 0, 0, 0, name = "Lonely Errand"},
        [621] = {0, 30, 0, 0, 0, name = "Current Work"},
    }
    -- 602 needs 601, 603 needs 602.
    env.WalkMapData.prereqs = {[602] = {{601}, {}}, [603] = {{}, {602}}}
    env.WalkMapData.givers = {[1436] = {
        {10, 10, "Chain Giver", nil, {601}},
        {20, 20, "Errand Giver", nil, {611}},
        {30, 30, "Busy Giver", nil, {621}},
    }}
    env.WalkMapExtras.Refresh(1436)
    local _, pins = env.WalkMapExtras.MiniMapPins()
    local byName = {}
    for _, pin in ipairs(pins) do
        if pin.pinName then byName[pin.pinName] = pin end
    end
    return env, byName
end

return {
    {"Off: gray quests stay hidden", function(Mock)
        local _, pins = givers(Mock, nil)
        Mock.ok(pins["Busy Giver"], "a quest at your level")
        Mock.ok(not pins["Chain Giver"], "gray chain start hidden")
        Mock.ok(not pins["Errand Giver"], "gray errand hidden")
    end},
    {"Quest chains: a gray start shows when the chain reaches your level", function(Mock)
        local env, pins = givers(Mock, "chains")
        Mock.eq(env.WalkMapExtras.ChainTop(601), 32, "chain followed to its end")
        Mock.ok(pins["Chain Giver"], "chain start shown")
        Mock.ok(tostring(pins["Chain Giver"].detail):find("chain to level 32", 1, true), "tooltip says where it goes")
        Mock.ok(not pins["Errand Giver"], "a gray quest without a chain stays hidden")
    end},
    {"All: every gray quest shows", function(Mock)
        local _, pins = givers(Mock, "all")
        Mock.ok(pins["Chain Giver"], "chain start")
        Mock.ok(pins["Errand Giver"], "gray errand")
    end},
}
