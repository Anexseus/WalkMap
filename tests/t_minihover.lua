-- WalkMap_MiniHover.lua: tooltips for minimap markers.
local function setup(Mock)
    local env = Mock.new()
    env.load("WalkMap_MiniHover.lua")
    local frame = env.CreateFrame("Frame", nil, env.UIParent)
    local pools = {giver = {}, quest = {}}
    local function marker(kind, x, y, pin)
        local texture = frame:CreateTexture()
        texture:SetSize(12, 12)
        texture.__left, texture.__top = x - 6, y + 6 -- centred on x, y
        texture.walkmapPin, texture.walkmapKind = pin, kind
        pools[kind][#pools[kind] + 1] = texture
        return texture
    end
    env.WalkMapMiniHover.Watch(frame, pools)
    return env, env.WalkMapMiniHover, pools, marker, frame
end

return {
    {"Describe: givers, places, quests, objectives", function(Mock)
        local _, hover = setup(Mock)
        local title, lines = hover.Describe({pinName = "Gryan Stoutmantle", detail = "[12] The People's Militia"}, "giver")
        Mock.eq(title, "Gryan Stoutmantle", "giver name")
        Mock.eq(lines[1][1], "[12] The People's Militia", "the quests offered")
        title, lines = hover.Describe({pinName = "Innkeeper Heather", detail = ""}, "service")
        Mock.eq(title, "Innkeeper Heather", "place name")
        Mock.eq(#lines, 0, "no empty detail line")
        title, lines = hover.Describe({questTitle = "Bloom of the Heavens", ready = true}, "quest")
        Mock.eq(title, "Bloom of the Heavens", "quest")
        Mock.eq(lines[1][1], "Ready to turn in", "ready")
        title, lines = hover.Describe({questTitle = "x", ready = true, turnInName = "Nailed Plank"}, "quest")
        Mock.eq(lines[1][1], "Ready to turn in: Nailed Plank", "ready, with the place")
        title, lines = hover.Describe({entries = {
            {objectiveName = "Cursed Sailor", questTitle = "The Cursed Crew"},
            {objectiveName = "Cursed Marine", questTitle = "The Cursed Crew"}}}, "objective")
        Mock.eq(title, "Cursed Sailor", "first objective")
        Mock.eq(lines[1][1], "The Cursed Crew", "its quest")
        Mock.eq(lines[2][1], "Cursed Marine  -  The Cursed Crew", "the second objective in the same spot")
        Mock.eq(hover.Describe({}, "party"), nil, "nothing to say: no tooltip")
        Mock.eq(hover.Describe(nil, "giver"), nil, "no pin")
    end},
    {"Find: the nearest shown marker under the mouse", function(Mock)
        local _, hover, pools, marker = setup(Mock)
        local a = marker("giver", 100, 100, {pinName = "A"})
        local b = marker("quest", 110, 100, {questTitle = "B"})
        Mock.eq(hover.Find(pools, 101, 100), a, "on A")
        Mock.eq(hover.Find(pools, 109, 101), b, "on B")
        Mock.eq(hover.Find(pools, 104, 100), a, "between: the nearer one")
        Mock.eq(hover.Find(pools, 140, 100), nil, "nothing there")
        b:Hide()
        Mock.eq(hover.Find(pools, 109, 101), nil, "hidden markers do not count")
    end},
    {"the tooltip follows the mouse, not a resting pointer", function(Mock)
        local env, _, _, marker = setup(Mock)
        local a = marker("giver", 100, 100, {pinName = "Gryan Stoutmantle", detail = "[12] Militia"})
        marker("quest", 300, 100, {questTitle = "Bloom of the Heavens", ready = true})
        -- The pointer already rests on the marker (hidden, controller play).
        env.__cursor = {100, 100}
        env.tick(1, 10)
        Mock.ok(not env.WalkMapMiniTooltip or not env.WalkMapMiniTooltip:IsShown(), "a resting pointer shows nothing")
        -- The player moves the mouse onto it.
        env.__cursor = {101, 101}
        env.tick(0.3, 3)
        local tip = env.WalkMapMiniTooltip
        Mock.ok(tip, "WalkMap's own tooltip frame, not the game's shared one")
        Mock.eq(env.GameTooltip:IsShown(), false, "the game's tooltip is left alone")
        Mock.eq(tip:IsShown(), true, "moving the mouse onto a marker shows its tooltip")
        Mock.eq(tip:GetText(), "Gryan Stoutmantle", "with the marker's name")
        env.tick(5, 50)
        Mock.eq(tip:IsShown(), true, "it stays while the mouse is on the marker")
        tip:Hide() -- something else closes it
        env.tick(0.3, 3)
        Mock.eq(tip:IsShown(), true, "it comes back while the mouse is still on the marker")
        Mock.ok(env.WalkMapMiniHover.Status():find("tooltips 2", 1, true), "the debug status counts it")
        env.__cursor = {300, 100}
        env.tick(0.3, 3)
        Mock.eq(tip:GetText(), "Bloom of the Heavens", "the next marker replaces it")
        env.__cursor = {500, 500}
        env.tick(0.3, 3)
        Mock.eq(tip:IsShown(), false, "leaving the markers hides it")
    end},
    {"markers of a hidden minimap are ignored", function(Mock)
        local env, _, _, marker, frame = setup(Mock)
        marker("giver", 100, 100, {pinName = "A"})
        frame:Hide()
        env.__cursor = {90, 100}
        env.tick(0.2, 2)
        env.__cursor = {100, 100}
        env.tick(0.3, 3)
        Mock.ok(not env.WalkMapMiniTooltip or not env.WalkMapMiniTooltip:IsShown(), "no tooltip")
    end},
}
