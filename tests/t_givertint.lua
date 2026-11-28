-- Quest giver "!" colours: red when everything offered is a dungeon or
-- raid quest, orange when it is all PvP, else the icon's own colours.
local function givers(Mock, tags)
    local env = Mock.new({playerMap = 1436, level = 30})
    env.UnitLevel = function() return 30 end
    env.C_QuestLog.GetQuestTagInfo = function(id)
        local tag = tags[id]
        if tag then return {tagID = tag, tagName = tag == 41 and "PvP" or "Dungeon"} end
    end
    env.loadAddon({welcomeSeen = true, newsSeen = "1.14.22"}, {welcomeSeen = true})
    env.fire("PLAYER_LOGIN")
    env.fire("PLAYER_ENTERING_WORLD")
    env.WalkMapData.quests = {
        [501] = {0, 30, 0, 0, 0, name = "Battle for the Gulch"},
        [502] = {0, 30, 0, 0, 0, name = "Into the Depths"},
        [503] = {0, 30, 0, 0, 0, name = "Lost Sheep"},
    }
    env.WalkMapData.givers = {[1436] = {
        {10, 10, "Battlemaster", nil, {501}},
        {20, 20, "Dwarf Explorer", nil, {502}},
        {30, 30, "Farmer", nil, {503, 501}},
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
    {"PvP-only givers get an orange '!', dungeon-only red, mixed none", function(Mock)
        local env, pins = givers(Mock, {[501] = 41, [502] = 81})
        Mock.eq(pins["Battlemaster"] and pins["Battlemaster"].giverTint, "pvp", "PvP only: orange")
        Mock.eq(pins["Dwarf Explorer"] and pins["Dwarf Explorer"].giverTint, "instance", "dungeon only: red")
        Mock.eq(pins["Farmer"] and pins["Farmer"].giverTint, nil, "a normal quest too: no colour")
        Mock.ok(tostring(pins["Battlemaster"].detail):find("(PvP)", 1, true), "tooltip names it PvP")
        local color = env.WalkMapUI.GiverTint("pvp")
        Mock.ok(color[1] == 1 and color[2] > 0.4 and color[2] < 0.8 and color[3] < 0.3, "orange")
    end},
}
