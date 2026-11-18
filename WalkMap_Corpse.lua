-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- WalkMap corpse marker: while you are dead or a ghost, a skull shows where
-- your corpse is on WalkMap and its minimaps, and the badge points to it.
-- It goes away when you are alive again. Read-only: it only reads the
-- player's position and the game's corpse position.
WalkMapCorpse = WalkMapCorpse or {}
local corpse = WalkMapCorpse
if not WalkMapExtras then return end

corpse.ART = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"

local function isDead()
    return UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") and true or false
end

-- Where you died, saved per character so it survives /reload as a ghost.
local function recordDeath()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return end
    local okMap, mapID = pcall(C_Map.GetBestMapForUnit, "player")
    if not okMap or not mapID then return end
    local okPos, position = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
    if not okPos or not position then return end
    local x, y = position:GetXY()
    if x and y and (x > 0 or y > 0) then
        WalkMapExtras.SetCorpse({mapID = mapID, x = x, y = y})
    end
end

-- Corpse position on a map (0-1), or nil. The game's own corpse position
-- is used when it has one for that map (works on zone and continent maps);
-- otherwise the saved death spot when it is on that map.
function corpse.Position(mapID)
    if not mapID or not isDead() then return nil end
    if C_DeathInfo and C_DeathInfo.GetCorpseMapPosition then
        local ok, position = pcall(C_DeathInfo.GetCorpseMapPosition, mapID)
        if ok and position and position.GetXY then
            local x, y = position:GetXY()
            if x and y and (x > 0 or y > 0) then return x, y end
        end
    end
    local saved = WalkMapExtras.Corpse()
    if saved and saved.mapID == mapID then return saved.x, saved.y end
end

function corpse.Active()
    return isDead()
end

local events = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "PLAYER_ENTERING_WORLD"}) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_DEAD" then
        recordDeath()
    elseif not isDead() then
        -- Alive again (corpse recovered, resurrected or spirit healer).
        WalkMapExtras.SetCorpse(nil)
    end
    if corpse.Changed then corpse.Changed() end
end)

function corpse.Status()
    local saved = WalkMapExtras.Corpse()
    return (isDead() and "dead/ghost" or "alive") .. (saved and string.format("; died on map %s at %.1f, %.1f",
        tostring(saved.mapID), (saved.x or 0) * 100, (saved.y or 0) * 100) or "")
end
