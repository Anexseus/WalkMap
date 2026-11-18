-- WalkMap_Levels.lua: click into the map, go back up, the corner button.
local function setup(Mock, options)
    local env = Mock.new(options)
    env.WalkMapCharacterSettings = {}
    env.load("WalkMap_Data.lua")
    env.load("WalkMap_Maps.lua")
    local state = {zoom = 1, following = true, stopped = 0}
    local viewport = env.CreateFrame("Frame", nil, env.UIParent)
    viewport:SetSize(600, 400)
    local canvas = env.CreateFrame("Frame", nil, viewport)
    canvas:SetSize(600, 400)
    local crosshair = env.CreateFrame("Frame", nil, viewport)
    crosshair:Hide()
    crosshair.ViewCenter = function() return 0.25, 0.25 end
    env.WalkMapNativeController = {PadFocused = function() return state.padFocused == true end}
    env.WalkMapCore = {viewport = viewport, canvas = canvas, crosshair = crosshair,
        CurrentMap = function() return env.WalkMapMaps.Selected() or env.__playerMap end,
        ZoomIndex = function() return state.zoom end}
    env.WalkMapExtras = {
        Follow = function() return state.following end,
        StopFollow = function() state.following = false state.stopped = state.stopped + 1 end,
        StyleButton = function() end,
    }
    env.load("WalkMap_Levels.lua")
    return env, viewport, state
end

return {
    {"click opens the zone under the cursor on a continent", function(Mock)
        local env, viewport, state = setup(Mock)
        env.WalkMapMaps.Choose(1415)
        env.__childAt = function(id) if id == 1415 then return 1431 end end
        Mock.eq(viewport.walkmapChildAt(0.5, 0.5).mapID, 1431, "child under the point")
        Mock.eq(viewport.walkmapChildAt(1.5, 0.5), nil, "outside the map")
        Mock.eq(viewport.walkmapDrill(0.5, 0.5), true, "drill")
        Mock.eq(env.WalkMapMaps.Selected(), 1431, "zone opened")
        Mock.eq(state.stopped, 1, "Follow paused")
        Mock.eq(viewport.walkmapDrill(0.5, 0.5), false, "a zone map does not drill")
    end},
    {"up: zone -> continent -> world, then stops", function(Mock)
        local env, viewport = setup(Mock)
        Mock.eq(env.WalkMapLevels.Up(), true, "Westfall -> Eastern Kingdoms")
        Mock.eq(env.WalkMapMaps.Selected(), 1415, "continent")
        Mock.eq(viewport.walkmapUp(), true, "-> Azeroth")
        Mock.eq(env.WalkMapMaps.Selected(), 947, "world")
        Mock.eq(viewport.walkmapUp(), false, "nothing above the world")
        Mock.eq(env.WalkMapMaps.Selected(), 947, "still the world")
    end},
    {"LB goes up only when zoomed out and after a pause", function(Mock)
        local env, viewport, state = setup(Mock)
        env.tick(2)
        state.zoom = 3
        Mock.eq(viewport.walkmapZoomUp(-1), false, "zoomed in: plain zoom")
        state.zoom = 1
        env.tick(0.2)
        Mock.eq(viewport.walkmapZoomUp(-1), false, "quick tap after zooming out: nothing")
        env.tick(0.2)
        Mock.eq(viewport.walkmapZoomUp(-1), false, "still tapping")
        Mock.eq(env.WalkMapMaps.Selected(), nil, "map unchanged")
        env.tick(1)
        Mock.eq(viewport.walkmapZoomUp(1), false, "RB never goes up")
        Mock.eq(viewport.walkmapZoomUp(-1), true, "LB after a pause: up")
        Mock.eq(env.WalkMapMaps.Selected(), 1415, "continent")
    end},
    {"corner button names the map above", function(Mock)
        local env, _, state = setup(Mock)
        local levels = env.WalkMapLevels
        local function label() return levels.ButtonLabel:GetText() end
        levels.Refresh()
        Mock.eq(levels.Button:IsShown(), true, "shown on a zone")
        Mock.eq(label(), "Eastern Kingdoms", "label")
        env.WalkMapCore.crosshair:Show()
        levels.Refresh()
        Mock.eq(label(), "LB: Eastern Kingdoms", "map control, zoomed out")
        state.zoom = 2
        levels.Refresh()
        Mock.eq(label(), "Eastern Kingdoms", "map control, zoomed in")
        levels.Button:Click()
        levels.Refresh()
        Mock.eq(label(), "Azeroth", "after a click: continent, next is the world")
        levels.Button:Click()
        levels.Refresh()
        Mock.eq(levels.Button:IsShown(), false, "hidden on the world map")
    end},
    {"corner button can be hidden in the Buttons menu", function(Mock)
        local env = setup(Mock)
        env.WalkMapCharacterSettings.hiddenButtons = {up = true}
        env.WalkMapLevels.Refresh()
        Mock.eq(env.WalkMapLevels.Button:IsShown(), false, "hidden by choice")
        Mock.eq(env.WalkMapLevels.Up(), true, "right-click and LB still work")
    end},
    {"corner button falls back to '<' without the arrow art", function(Mock)
        local env = Mock.new()
        env.WalkMapCharacterSettings = {}
        env.load("WalkMap_Data.lua")
        env.load("WalkMap_Maps.lua")
        local viewport = env.CreateFrame("Frame", nil, env.UIParent)
        local canvas = env.CreateFrame("Frame", nil, viewport)
        env.WalkMapCore = {viewport = viewport, canvas = canvas,
            CurrentMap = function() return env.__playerMap end, ZoomIndex = function() return 1 end}
        env.WalkMapExtras = {Follow = function() return false end, StyleButton = function() end}
        local create = env.CreateFrame
        env.CreateFrame = function(...)
            local frame = create(...)
            local texture = frame.CreateTexture
            frame.CreateTexture = function(...)
                local made = texture(...)
                made.SetTexture = function() return false end
                return made
            end
            return frame
        end
        env.load("WalkMap_Levels.lua")
        env.WalkMapLevels.Refresh()
        Mock.eq(env.WalkMapLevels.ButtonLabel:GetText(), "< Eastern Kingdoms", "text arrow")
    end},
    {"hovering a zone on a continent: outline and name", function(Mock)
        local env, viewport, state = setup(Mock, {level = 20})
        local levels = env.WalkMapLevels
        env.WalkMapMaps.Choose(1415)
        -- Duskwood fills the right half of the continent in this test.
        env.__childAt = function(id, x) if id == 1415 and x >= 0.5 then return 1431 end end
        env.__highlight = function(id, x)
            if id == 1415 and x >= 0.5 then return 271557, nil, 0.8, 0.6, 0.5, 0.25, 0.5, 0.1 end
            return 0
        end
        viewport.__mouseOver = true
        env.__cursor = {450, 200} -- x = 0.75 on the 600 px wide map
        env.tick(0.2, 2)
        Mock.eq(levels.HoverLabel:IsShown(), true, "name shown")
        Mock.eq(levels.HoverLabel:GetText(), "Duskwood |cffffe633(18-30)|r", "name with levels")
        Mock.eq(levels.Outline:IsShown(), true, "outline shown")
        Mock.eq(levels.Outline:GetTexture(), 271557, "the game's highlight art")
        Mock.eq(levels.Outline:GetWidth(), 300, "outline width: half the map")
        Mock.eq(levels.Outline:GetHeight(), 100, "outline height: a quarter of the map")
        Mock.eq(levels.Outline.__point[4], 300, "outline left edge")
        Mock.eq(levels.Outline.__point[5], -40, "outline top edge")
        env.__cursor = {100, 200} -- nothing under the mouse
        env.tick(0.2, 2)
        Mock.eq(levels.HoverLabel:IsShown(), false, "name hidden off the zone")
        Mock.eq(levels.Outline:IsShown(), false, "outline hidden off the zone")
        env.__cursor = {450, 200}
        viewport.__mouseOver = false
        env.tick(0.2, 2)
        Mock.eq(levels.Outline:IsShown(), false, "hidden when the mouse leaves the map")
    end},
    {"with controller focus the hover follows the mouse only after it moved", function(Mock)
        local env, viewport, state = setup(Mock)
        local levels = env.WalkMapLevels
        env.WalkMapMaps.Choose(1415)
        env.__childAt = function() return 1431 end
        env.__highlight = function() return 1, nil, 1, 1, 0.5, 0.5, 0, 0 end
        state.padFocused = true
        viewport.__mouseOver = true
        env.__cursor = {450, 200}
        env.tick(0.2, 2)
        Mock.eq(levels.HoverLabel:IsShown(), false, "a resting pointer shows nothing")
        env.__cursor = {460, 210}
        env.tick(0.2, 2)
        Mock.eq(levels.HoverLabel:IsShown(), true, "moving the mouse shows the name")
        Mock.eq(levels.Outline:IsShown(), true, "and the outline")
        env.tick(5, 50)
        Mock.eq(levels.HoverLabel:IsShown(), false, "and it goes away once the mouse rests")
        Mock.eq(levels.Outline:IsShown(), false, "outline too")
    end},
    {"map control outlines what is under the crosshair", function(Mock)
        local env, viewport = setup(Mock)
        local levels = env.WalkMapLevels
        env.WalkMapMaps.Choose(1415)
        local asked
        env.__childAt = function() return 1431 end
        env.__highlight = function(_, x, y) asked = x .. "," .. y return 1, nil, 1, 1, 0.5, 0.5, 0, 0 end
        env.WalkMapCore.crosshair:Show()
        env.tick(0.2, 2)
        Mock.eq(asked, "0.25,0.25", "asked at the crosshair")
        Mock.eq(levels.Outline:IsShown(), true, "outline at the crosshair")
        Mock.eq(levels.HoverLabel:IsShown(), false, "no mouse label in map control")
    end},
    {"a client without highlight data shows the name only", function(Mock)
        local env, viewport = setup(Mock)
        env.WalkMapMaps.Choose(1415)
        env.C_Map.GetMapHighlightInfoAtPosition = nil
        env.__childAt = function() return 1431 end
        viewport.__mouseOver = true
        env.__cursor = {450, 200}
        env.tick(0.2, 2)
        Mock.eq(env.WalkMapLevels.HoverLabel:IsShown(), true, "name")
        Mock.eq(env.WalkMapLevels.Outline:IsShown(), false, "no outline")
    end},
    {"hover text carries the level range", function(Mock)
        local _, viewport = setup(Mock, {level = 20})
        Mock.eq(viewport.walkmapChildText({mapID = 1431, name = "Duskwood"}),
            "Duskwood |cffffe633(18-30)|r", "zone")
        Mock.eq(viewport.walkmapChildText({mapID = 1415, name = "Eastern Kingdoms"}),
            "Eastern Kingdoms", "continent")
        Mock.eq(viewport.walkmapChildText(nil), "", "nothing under the cursor")
    end},
}
