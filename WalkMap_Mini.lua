-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- Optional preview over the stock minimap. Never hide or reparent Blizzard UI.
-- This is deliberately passive: original minimap clicks and gamepad focus remain intact.
local source = WalkMapMiniSource
if not source or not WalkMapExtras then return end
local borderPadding = 32
local zoomScales = {1.6, 2.2, 2.8, 3.6, 4.5, 5.5}

local mini = CreateFrame("Frame", "WalkMapMiniPreview", UIParent)
mini:EnableMouse(false)
mini:EnableKeyboard(false)
mini:SetClampedToScreen(true)
-- The game can render its own minimap POIs above HIGH. Keep the opaque
-- preview in front so its Areas filter is the one the player actually sees.
mini:SetFrameStrata("DIALOG")
if mini.EnableGamePadButton then mini:EnableGamePadButton(false) end
if mini.EnableGamePadStick then mini:EnableGamePadStick(false) end
mini:Hide()

local background = mini:CreateTexture(nil, "BACKGROUND")
background:SetAllPoints(mini)
background:SetColorTexture(0.055, 0.055, 0.055, 1)
local edge = mini:CreateTexture(nil, "BORDER")
edge:SetPoint("TOPLEFT", mini, "TOPLEFT", 0, 0)
edge:SetPoint("BOTTOMRIGHT", mini, "BOTTOMRIGHT", 0, 0)
edge:SetColorTexture(0.58, 0.57, 0.54, 0.5)

-- Newer looks: the material behind, and the metal frame around the preview.
if WalkMapUI and WalkMapUI.FrameBorder(mini, 4, 12) then
    edge:Hide()
    WalkMapUI.ApplyMaterial(background, 1, 0.5)
end
local clip = CreateFrame("Frame", nil, mini)
clip:SetPoint("TOPLEFT", mini, "TOPLEFT", 2, -2)
clip:SetPoint("BOTTOMRIGHT", mini, "BOTTOMRIGHT", -2, 22)
clip:EnableMouse(false)
if not clip.SetClipsChildren then
    -- The zone art would spill over the UI on clients without child clipping.
    return
end
clip:SetClipsChildren(true)
local coordinates = CreateFrame("Frame", nil, mini)
coordinates:SetPoint("BOTTOMLEFT", mini, "BOTTOMLEFT", 2, 2)
coordinates:SetPoint("BOTTOMRIGHT", mini, "BOTTOMRIGHT", -2, 2)
coordinates:SetHeight(18)
coordinates:EnableMouse(false)
local coordinatesBG = coordinates:CreateTexture(nil, "BACKGROUND")
coordinatesBG:SetAllPoints(coordinates)
coordinatesBG:SetColorTexture(0.055, 0.055, 0.055, 0.96)
if WalkMapUI then WalkMapUI.ApplyMaterial(coordinatesBG, 1, 0.55) end
local coordinatesText = coordinates:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
coordinatesText:SetPoint("CENTER", coordinates, "CENTER", 0, 0)
coordinatesText:SetTextColor(1, 0.87, 0.58)
coordinatesText:SetText("--.-, --.-")
local canvas = CreateFrame("Frame", nil, clip)
canvas:EnableMouse(false)
local markerLayer = CreateFrame("Frame", nil, canvas)
markerLayer:SetAllPoints(canvas)
markerLayer:SetFrameLevel(canvas:GetFrameLevel() + 3)
markerLayer:EnableMouse(false)

local tileCopies, exploredCopies, markerCopies, areaCopies = {}, {}, {}, {}
local player = markerLayer:CreateTexture(nil, "OVERLAY", nil, 7)
player:SetTexture("Interface\\Minimap\\MinimapArrow")
player:SetSize(24, 24)
player:Hide()
local activeMap, lastWidth, lastHeight, areaKey, lastError
local miniState = "not refreshed"
local function setMiniState(value)
    if miniState == value then return end
    miniState = value
    WalkMapExtras.DebugEvent("Mini state: " .. value)
end
source.MiniStatus = function()
    if miniState == "game terrain" then return miniState, nil end
    return miniState, activeMap
end
local miniViewW, miniViewH

local function snap(value)
    local scale = mini:GetEffectiveScale()
    if type(scale) ~= "number" or scale <= 0 then return value end
    return math.floor(value * scale + 0.5) / scale
end

local function moveMiniPlayer(x, y, visible)
    if not miniViewW or not miniViewH then return 0, 0 end
    local cw, ch = canvas:GetWidth(), canvas:GetHeight()
    x, y = x or 0.5, y or 0.5
    local offsetX = cw > miniViewW and math.max(miniViewW - cw,
        math.min(0, miniViewW / 2 - x * cw)) or (miniViewW - cw) / 2
    local offsetY = ch > miniViewH and math.max(0,
        math.min(ch - miniViewH, y * ch - miniViewH / 2)) or (ch - miniViewH) / 2
    offsetX, offsetY = snap(offsetX), snap(offsetY)
    if canvas.offsetX ~= offsetX or canvas.offsetY ~= offsetY then
        canvas:ClearAllPoints()
        canvas:SetPoint("TOPLEFT", clip, "TOPLEFT", offsetX, offsetY)
        canvas.offsetX, canvas.offsetY = offsetX, offsetY
    end
    if visible then
        coordinatesText:SetText(string.format("%.1f, %.1f", x * 100, y * 100))
        local px, py = snap(x * cw), snap(y * ch)
        if player.px ~= px or player.py ~= py then
            player:ClearAllPoints()
            player:SetPoint("CENTER", canvas, "TOPLEFT", px, -py)
            player.px, player.py = px, py
        end
        player:SetRotation(GetPlayerFacing and GetPlayerFacing() or 0)
        player:Show()
    else
        coordinatesText:SetText("--.-, --.-")
        player:Hide()
    end
    return offsetX, offsetY
end

local function copyArt(pool, originals, width, height, artW, artH, exploration)
    for index, original in ipairs(originals) do
        local copy = pool[index]
        local file = original:IsShown() and original:GetTexture()
        if file then
            if not copy then
                copy = canvas:CreateTexture(nil, "ARTWORK", nil,
                    exploration and 1 or 0)
                pool[index] = copy
            end
            local x, y, w, h
            if exploration then
                x, y = original.artX, original.artY
                w, h = original.artWidth, original.artHeight
            else
                local columns = math.ceil(artW / width)
                x = ((index - 1) % columns) * width
                y = math.floor((index - 1) / columns) * height
                w, h = math.min(width, artW - x), math.min(height, artH - y)
            end
            if x and y and w and h and w > 0 and h > 0 then
                local px, py = x / artW * canvas:GetWidth(),
                    -y / artH * canvas:GetHeight()
                local pw, ph = w / artW * canvas:GetWidth(),
                    h / artH * canvas:GetHeight()
                local geometryChanged = copy.px ~= px or copy.py ~= py
                    or copy.pw ~= pw or copy.ph ~= ph
                if geometryChanged then
                    copy:ClearAllPoints()
                    copy:SetPoint("TOPLEFT", canvas, "TOPLEFT", px, py)
                    copy:SetSize(pw, ph)
                    copy.px, copy.py, copy.pw, copy.ph = px, py, pw, ph
                end
                local fileChanged = copy.sourceFile ~= file
                if fileChanged then
                    copy:SetTexture(file)
                    copy.sourceFile = file
                end
                if fileChanged or geometryChanged then
                    if exploration then
                        copy:SetTexCoord(original:GetTexCoord())
                    else
                        copy:SetTexCoord(0, w / width, 0, h / height)
                    end
                end
                local alpha = original:GetAlpha()
                if copy.sourceAlpha ~= alpha then
                    copy:SetAlpha(alpha)
                    copy.sourceAlpha = alpha
                end
                if not copy:IsShown() then copy:Show() end
            end
        elseif copy and copy:IsShown() then
            copy:Hide()
        end
    end
    -- Copies are created only for visible tiles, so this table can have gaps.
    for index, copy in pairs(pool) do
        if not originals[index] and copy:IsShown() then copy:Hide() end
    end
end

local function pinArt(pin, kind)
    if kind == "quest" then
        if pin.miniVisible and pin.symbol then
            return pin.symbol:GetTexture(), pin.ready and 13 or 12
        end
        return "Interface\\GossipFrame\\AvailableQuestIcon", 12
    elseif kind == "objective" then
        return pin.miniArt or (pin.icon and pin.icon:GetTexture()), 12
    elseif kind == "service" or kind == "giver" or kind == "resource" then
        return pin.texture:GetTexture(), 12
    elseif kind == "party" or kind == "friend" then
        return "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", 9
    elseif kind == "waypoint" then
        return pin.miniArt, 15
    end
end

local function copyPin(pin, index, copies, kind, offsetX, offsetY,
    viewW, viewH, areaMode, focusID, focusObjectiveIcons, iconScale,
    iconRange, playerX, playerY, allowMarker)
            local x = pin.mapPercentX and pin.mapPercentX * canvas:GetWidth() + offsetX
            local y = pin.mapPercentY and pin.mapPercentY * canvas:GetHeight() - offsetY
            -- The waypoint stays on the edge of the view when it is outside.
            if kind == "waypoint" and x and y then
                x = math.max(8, math.min(viewW - 8, x))
                y = math.max(8, math.min(viewH - 8, y))
            end
            local copy = copies[index]
            local questAllowed = kind ~= "quest" or areaMode == "all"
                or (areaMode == "focus" and focusID > 0 and pin.questID == focusID)
                or rawget(pin, "ready") == true -- turn-ins always show
            local objectiveAllowed = kind ~= "objective" or not focusObjectiveIcons
                or (focusID > 0 and pin.questID == focusID)
            if questAllowed and objectiveAllowed
                and (pin.miniVisible or (pin.IsShown and pin:IsShown()))
                and x and y and x >= -14 and x <= viewW + 14
                and y >= -14 and y <= viewH + 14
                and (iconRange >= 1 or (x - playerX) ^ 2 + (y - playerY) ^ 2
                    <= (math.min(viewW, viewH) * 0.5 * iconRange) ^ 2
                    or kind == "party" or kind == "friend" or kind == "waypoint") then
                local file, size = pinArt(pin, kind)
                if file and (kind == "party" or kind == "friend" or kind == "waypoint" or allowMarker(x, y, false)) then
                    if not copy then
                        local priority = kind == "waypoint" and 6 or (kind == "party" or kind == "friend") and 5
                            or (kind == "quest" or kind == "objective") and 4
                            or kind == "giver" and 3 or 2
                        copy = markerLayer:CreateTexture(nil, "OVERLAY", nil, priority)
                        copies[index] = copy
                        copy:SetVertexColor(kind == "party" and 0.2 or 1,
                            kind == "party" and 0.6 or 1, 1, 1)
                    end
                    local px = snap(kind == "waypoint" and x - offsetX or pin.mapPercentX * canvas:GetWidth())
                    local py = snap(kind == "waypoint" and y + offsetY or pin.mapPercentY * canvas:GetHeight())
                    if copy.px ~= px or copy.py ~= py then
                        copy:ClearAllPoints()
                        copy:SetPoint("CENTER", canvas, "TOPLEFT", px, -py)
                        copy.px, copy.py = px, py
                    end
                    local displaySize = math.floor(size * iconScale + 0.5)
                    if copy.size ~= displaySize then
                        copy:SetSize(displaySize, displaySize)
                        copy.size = displaySize
                    end
                    if copy.sourceFile ~= file then
                        copy:SetTexture(file)
                        copy.sourceFile = file
                    end
                    if kind == "objective" or kind == "friend" then
                        -- Objectives: the large map's per-kind tint. Friends: class colour.
                        local color = pin.miniColor
                        if copy.tint ~= color then
                            if color then copy:SetVertexColor(color[1], color[2], color[3], 1)
                            else copy:SetVertexColor(1, 1, 1, 1) end
                            copy.tint = color
                        end
                    elseif kind == "giver" then
                        -- Red "!" for a giver with only dungeon or raid
                        -- quests, as on the large map.
                        local tint = pin.instanceOnly == true and "instance" or nil
                        if copy.tint ~= tint then
                            if tint then copy:SetVertexColor(1, 0.25, 0.25, 1)
                            else copy:SetVertexColor(1, 1, 1, 1) end
                            copy.tint = tint
                        end
                    end
                    -- Sheet icons such as class circles carry a crop.
                    -- Turn-in markers are drawn above all other minimap markers.
                    if kind == "quest" then
                        local layer = rawget(pin, "ready") == true and 6 or 4
                        if copy.walkmapLayer ~= layer then
                            copy:SetDrawLayer("OVERLAY", layer)
                            copy.walkmapLayer = layer
                        end
                    end
                    local coords = rawget(pin, "iconCoords")
                    if copy.coords ~= coords then
                        if coords then copy:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
                        else copy:SetTexCoord(0, 1, 0, 1) end
                        copy.coords = coords
                    end
                    -- For the hover tooltips (WalkMap_MiniHover.lua).
                    copy.walkmapPin, copy.walkmapKind = pin, kind
                    if not copy:IsShown() then copy:Show() end
                    if kind ~= "party" and kind ~= "friend" and kind ~= "waypoint" then allowMarker(x, y, true) end
                elseif copy and copy:IsShown() then
                    copy:Hide()
                end
            elseif copy and copy:IsShown() then
                copy:Hide()
            end
end

local function copyPins(pools, offsetX, offsetY, viewW, viewH, areaMode,
    focusID, focusObjectiveIcons, iconScale, iconRange, playerX, playerY,
    allowMarker)
    local failures = 0
    for _, entry in ipairs(pools) do
        local pool, kind = entry[1], entry[2]
        local copies = markerCopies[kind]
        if not copies then
            copies = {}
            markerCopies[kind] = copies
        end
        for index, pin in ipairs(pool) do
            local ok, message = pcall(copyPin, pin, index, copies, kind,
                offsetX, offsetY, viewW, viewH, areaMode, focusID,
                focusObjectiveIcons, iconScale, iconRange, playerX, playerY,
                allowMarker)
            if not ok then
                failures = failures + 1
                local copy = copies[index]
                if copy then pcall(copy.Hide, copy) end
                WalkMapExtras.DebugEvent("Mini " .. kind .. " pin " .. index
                    .. ": " .. tostring(message))
            end
        end
        -- Quest focus can leave sparse copy indexes. Lua's # operator is
        -- undefined for sparse tables and may land on an empty slot.
        for index, copy in pairs(copies) do
            if not pool[index] then pcall(copy.Hide, copy) end
        end
    end
    return failures
end

local function copyAreas(mapID, originals, areaMode, focusID)
    local ids, focusedIDs = {}, {}
    for _, blob in ipairs(originals) do
        if blob:IsShown() and blob.walkmapQuestID
            and (areaMode == "all" or
                (areaMode == "focus" and focusID > 0
                    and blob.walkmapQuestID == focusID)) then
            ids[#ids + 1] = blob.walkmapQuestID
            focusedIDs[#ids] = blob.walkmapFocused
        end
    end
    local signature = tostring(mapID) .. ":" .. areaMode .. ":" .. tostring(focusID)
        .. ":" .. tostring(canvas:GetWidth())
        .. ":" .. table.concat(ids, ",")
    if signature == areaKey then return end
    areaKey = signature
    for index, id in ipairs(ids) do
        local area = areaCopies[index]
        if not area then
            area = CreateFrame("QuestPOIFrame", nil, canvas)
            area:SetAllPoints(canvas)
            area:SetFrameLevel(canvas:GetFrameLevel() + 1)
            area:EnableMouse(false)
            area:EnableKeyboard(false)
            if area.EnableGamePadButton then area:EnableGamePadButton(false) end
            area:SetFillTexture("Interface\\WorldMap\\UI-QuestBlob-Inside")
            area:SetBorderTexture("Interface\\WorldMap\\UI-QuestBlob-Outside")
            area:SetBorderScalar(1)
            areaCopies[index] = area
        end
        area:DrawNone()
        area:SetMapID(mapID)
        local focused = focusedIDs[index]
        area:SetFillAlpha(focused and 115 or 60)
        area:SetBorderAlpha(focused and 215 or 110)
        area:DrawBlob(id, true)
        area:Show()
    end
    for index = #ids + 1, #areaCopies do
        areaCopies[index]:Hide()
        areaCopies[index]:DrawNone()
    end
end

local function refresh()
    local original = _G.Minimap
    if not WalkMapExtras.MiniMap()
        or WalkMapExtras.MiniTerrain() == "game"
        or not original or not original:IsShown()
        or (original.IsVisible and not original:IsVisible()) then
        setMiniState(not WalkMapExtras.MiniMap() and "disabled"
            or WalkMapExtras.MiniTerrain() == "game" and "game terrain"
            or "game minimap hidden")
        mini:Hide()
        return
    end
    local w, h = original:GetWidth(), original:GetHeight()
    if not w or not h or w < 60 or h < 60 then
        setMiniState("game minimap too small")
        mini:Hide()
        return
    end
    if mini.anchor ~= original then
        mini:ClearAllPoints()
        mini:SetPoint("CENTER", original, "CENTER", 0, 0)
        mini.anchor = original
    end
    -- Keep the passive preview in front of the stock minimap's decoration.
    local level = original:GetFrameLevel() + 2
    if mini.level ~= level then
        mini:SetFrameLevel(level)
        clip:SetFrameLevel(mini:GetFrameLevel() + 1)
        canvas:SetFrameLevel(clip:GetFrameLevel() + 1)
        markerLayer:SetFrameLevel(canvas:GetFrameLevel() + 3)
        coordinates:SetFrameLevel(markerLayer:GetFrameLevel() + 1)
        mini.level = level
    end
    if w ~= lastWidth or h ~= lastHeight then
        lastWidth, lastHeight = w, h
        mini:SetSize(w + borderPadding * 2, h + borderPadding * 2)
        areaKey = nil
    end

    -- The full window may be closed; update its data without showing it.
    local refreshFailed = not source.IsFullMapShown()
        and source.Refresh() == false
    local mapID, files, artW, artH, tileW, tileH,
        tiles, explored, quests, objectives, party, areas, dot = source.Snapshot()
    if source.MiniPins then quests, objectives = source.MiniPins() end
    if not mapID or not files or artW <= 0 or artH <= 0 then
        setMiniState("zone art unavailable")
        mini:Hide()
        return
    end
    if mapID ~= activeMap then
        activeMap = mapID
        areaKey = nil
    end
    local viewW, viewH = w + borderPadding * 2 - 4,
        h + borderPadding * 2 - 24
    local cw = viewW * zoomScales[WalkMapExtras.MiniZoom()]
    local ch = cw * artH / artW
    if canvas:GetWidth() ~= cw or canvas:GetHeight() ~= ch then
        canvas:SetSize(cw, ch)
    end
    miniViewW, miniViewH = viewW, viewH
    local offsetX, offsetY = moveMiniPlayer(dot.mapPercentX,
        dot.mapPercentY, dot:IsShown() and dot.mapPercentX ~= nil)

    copyArt(tileCopies, tiles, tileW, tileH, artW, artH, false)
    local explorationOK, explorationError = pcall(copyArt,
        exploredCopies, explored, tileW, tileH, artW, artH, true)
    if not explorationOK then
        for _, texture in pairs(exploredCopies) do texture:Hide() end
        WalkMapExtras.DebugEvent("Mini exploration: " .. tostring(explorationError))
    end
    local services, givers, resources
    if source.MiniServices then services, givers, resources = source.MiniServices()
    else services, givers, resources = WalkMapExtras.MiniMapPins() end
    local areaMode = WalkMapExtras.AreaMode()
    local focusID = source.FocusedQuestID and source.FocusedQuestID() or 0
    if type(focusID) ~= "number" then focusID = 0 end
    local waypoints = source.MiniWaypoints and source.MiniWaypoints() or {}
    local sharers = WalkMapFriends and WalkMapFriends.MiniPins and WalkMapFriends.MiniPins(mapID) or {}
    local pinPools = {{waypoints, "waypoint"}, {sharers, "friend"}, {quests, "quest"}, {objectives, "objective"},
        {givers, "giver"}, {services, "service"},
        {resources, "resource"}, {party, "party"}}
    local iconScale, iconGap, iconRange = WalkMapExtras.MiniIconStyle(false)
    local allowMarker = WalkMapExtras.MarkerGrid(iconGap)
    local px = dot.mapPercentX and dot.mapPercentX * canvas:GetWidth()
        + offsetX or viewW / 2
    local py = dot.mapPercentY and dot.mapPercentY * canvas:GetHeight()
        - offsetY or viewH / 2
    if not dot.mapPercentX or not dot.mapPercentY or not dot:IsShown() then
        iconRange = 1
    end
    local skipped = 0
    for _, entry in ipairs(pinPools) do
        local ok, result = pcall(copyPins, {entry}, offsetX, offsetY,
            viewW, viewH, areaMode, focusID, WalkMapExtras.FocusObjectiveIcons(),
            iconScale, iconRange, px, py, allowMarker)
        if not ok then
            skipped = skipped + 1
            for _, copy in pairs(markerCopies[entry[2]] or {}) do copy:Hide() end
            WalkMapExtras.DebugEvent("Mini " .. entry[2] .. " pins: " .. tostring(result))
        else
            skipped = skipped + result
        end
    end
    local ok, areaError = pcall(copyAreas, mapID, areas, areaMode, focusID)
    if not ok then
        for _, area in ipairs(areaCopies) do area:Hide() end
        areaKey = nil
        WalkMapExtras.DebugEvent("Mini areas: " .. tostring(areaError))
    end
    local detail = skipped > 0 and (skipped .. " pins skipped")
        or refreshFailed and "using last zone data"
    setMiniState(detail and ("visible; " .. detail) or "visible")
    mini:Show()
end

local driver = CreateFrame("Frame", nil, UIParent)
local elapsed = 0
driver:SetScript("OnUpdate", function(_, delta)
    if mini:IsShown() and (not WalkMapExtras.MiniMap()
        or WalkMapExtras.MiniTerrain() == "game") then
        mini:Hide()
        setMiniState(WalkMapExtras.MiniMap() and "game terrain" or "disabled")
    end
    if WalkMapExtras.MiniMap() and WalkMapExtras.MiniTerrain() == "zone"
        and mini:IsShown() and activeMap then
        -- Camera tracking is cheap and follows the rendered frame. Data and
        -- artwork still refresh at their original, slower rate below.
        pcall(function()
            if not source.IsFullMapShown() then source.UpdatePlayerPosition() end
            local x, y = source.ReadPlayerPosition(activeMap)
            if x and y then
                moveMiniPlayer(x, y, true)
            else
                moveMiniPlayer(nil, nil, false)
            end
        end)
    end
    elapsed = elapsed + delta
    local previewActive = WalkMapExtras.MiniMap()
        and WalkMapExtras.MiniTerrain() == "zone"
    if elapsed < (previewActive and 0.1 or 0.35) then return end
    elapsed = 0
    local ok, message = pcall(refresh)
    if not ok then
        setMiniState("preview error: " .. tostring(message))
        WalkMapExtras.DebugEvent("Mini preview: " .. tostring(message))
        mini:Hide()
        if message ~= lastError then
            lastError = message
            print("|cff80ff80WalkMap:|r Minimap preview unavailable: " .. tostring(message))
        end
    end
end)

-- Tooltips for these markers while the mouse is over them.
if WalkMapMiniHover then WalkMapMiniHover.Watch(mini, markerCopies) end
