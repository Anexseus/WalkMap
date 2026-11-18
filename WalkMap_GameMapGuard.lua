-- Works around a game bug that can leave the controller without UI control.
--
-- The game's quest log (QuestMapFrame) handles QUEST_LOG_UPDATE even while
-- the game's map is closed. In controller mode, if the button the controller
-- was on has just disappeared (for example a mail item you took) and the
-- game's quest list is empty (it is only filled while its map is open), it
-- focuses the closed map: Blizzard_GamepadSoftCursor/SoftCursor.lua:174
-- "attempt to perform arithmetic on local 'inX'". The error comes after the
-- game has suspended its controller cursor, so UI navigation stops until
-- /reload. Seen after buying a quest item and taking mail.
--
-- WalkMap stops the game's quest log from listening to those two events
-- while the game's map is closed, and turns them back on as soon as the map
-- opens. Only the registration changes: WalkMap never calls the game's quest
-- log code itself. The game rebuilds its quest list when its map opens.
local guard = {}
WalkMapGameMapGuard = guard

local EVENTS = {"QUEST_LOG_UPDATE", "UNIT_QUEST_LOG_CHANGED"}
local paused, hooked, pauses, state = false, false, 0, "waiting for the game's map"

local function gamepadUI()
    if InputUtil and type(InputUtil.IsGamepadUIEnabled) == "function" then
        local ok, enabled = pcall(InputUtil.IsGamepadUIEnabled)
        if ok then return enabled == true end
    end
    return false
end

local function pause()
    if paused or not QuestMapFrame or not gamepadUI() then return end
    for _, event in ipairs(EVENTS) do pcall(QuestMapFrame.UnregisterEvent, QuestMapFrame, event) end
    paused, pauses = true, pauses + 1
end

local function resume()
    if not paused or not QuestMapFrame then return end
    for _, event in ipairs(EVENTS) do pcall(QuestMapFrame.RegisterEvent, QuestMapFrame, event) end
    paused = false
end

local function attach()
    if hooked or not (WorldMapFrame and QuestMapFrame and WorldMapFrame.HookScript) then return end
    hooked = true
    state = "active"
    WorldMapFrame:HookScript("OnShow", resume)
    WorldMapFrame:HookScript("OnHide", pause)
    if not WorldMapFrame:IsShown() then pause() end
end

function guard.Paused() return paused end

function guard.Status()
    if not hooked then return state end
    if not gamepadUI() and not paused then return "not needed (controller UI off)" end
    return (paused and "game quest log paused while its map is closed" or "game quest log listening")
        .. "; paused " .. pauses .. " time(s)"
end

local events = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ADDON_LOADED"}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function()
    attach()
    -- The controller UI may have been switched on since the map last closed.
    if hooked and WorldMapFrame and not WorldMapFrame:IsShown() then pause() end
end)
attach()
