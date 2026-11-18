-- The newer looks put a square metal frame around the game-terrain minimap.
-- It must not stay around the round game minimap.
local function start(Mock, mini)
    local env = Mock.new({playerMap = 1436, quests = {{header = "Westfall"}, {id = 101, title = "Westfall Stew", level = 13}}})
    env.loadAddon({welcomeSeen = true}, {look = "leather", miniMap = mini, miniTerrain = "game", nativeIcons = true})
    env.fire("PLAYER_LOGIN")
    env.fire("PLAYER_ENTERING_WORLD")
    env.tick(1, 10)
    return env
end

return {
    {"Round game minimap: no square frame after login", function(Mock)
        local env = start(Mock, false)
        Mock.eq(env.WalkMapUI.Look(), "leather", "a look with a metal frame")
        Mock.ok(env.WalkMapMiniSource.walkmapLiveFrame, "the frame exists")
        Mock.eq(env.WalkMapMiniSource.LiveFrameShown(), false, "not shown around the round minimap")
    end},
    {"Game terrain turned off: the square frame goes", function(Mock)
        -- The fake client does not pass parent visibility to children the
        -- way the game does, so it cannot show the frame itself; it can check
        -- that leaving game terrain hides it.
        local env = start(Mock, true)
        Mock.ok(env.WalkMapMiniSource.LiveMiniStatus():find("square", 1, true), "square game terrain applied")
        env.WalkMapMiniSource.walkmapLiveFrame:Show()
        env.WalkMapCharacterSettings.miniMap = false
        env.WalkMapExtras.Invalidate()
        env.tick(1, 10)
        Mock.eq(env.WalkMapMiniSource.LiveMiniStatus(), "not applied", "round game minimap again")
        Mock.eq(env.WalkMapMiniSource.LiveFrameShown(), false, "frame gone")
    end},
}
