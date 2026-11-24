-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- Map levels: world -> continent -> zone and back up.
--   Down: click a continent or zone (controller: A in map control).
--   Up:   the button with the gold arrow in the map's top-left corner,
--         right-click on the world or a continent, or LB in map control when
--         the map is already zoomed all the way out.
-- What a click opens is outlined with the game's own zone highlight, and the
-- label under the mouse (and the map-control crosshair) names it, with the
-- zone's level range.
-- Split from WalkMap.lua in 1.11; loads right after it.
WalkMapLevels = {}
local levels = WalkMapLevels
local core = WalkMapCore
if not core then return end
local viewport, canvas = core.viewport, core.canvas
local maps = WalkMapMaps

-- The zone (or continent) under a point on a broad map. The map's own mouse
-- and controller handlers in WalkMap.lua call these through viewport.
viewport.walkmapChildAt = function(x, y)
    local currentMap = core.CurrentMap()
    if not currentMap or not x or not y or x < 0 or x > 1 or y < 0 or y > 1 then return nil end
    if not (maps and maps.IsBroad and maps.IsBroad(currentMap)) then return nil end
    if not (C_Map and C_Map.GetMapInfoAtPosition) then return nil end
    local ok, child = pcall(C_Map.GetMapInfoAtPosition, currentMap, x, y)
    if not ok or type(child) ~= "table" or not child.mapID or child.mapID == currentMap then return nil end
    return child
end
viewport.walkmapDrill = function(x, y)
    local child = viewport.walkmapChildAt(x, y)
    if not child then return false end
    if WalkMapExtras.Follow() then WalkMapExtras.StopFollow() end
    return maps.Choose(child.mapID) and true or false
end
viewport.walkmapCursor = function()
    local cx, cy = GetCursorPosition()
    local scale = canvas:GetEffectiveScale()
    local left, top = canvas:GetLeft(), canvas:GetTop()
    local w, h = canvas:GetWidth(), canvas:GetHeight()
    if not left or not top or not w or w <= 0 or not h or h <= 0 then return nil end
    return (cx / scale - left) / w, (top - cy / scale) / h
end
-- Name plus level range ("Duskwood (18-30)", coloured for your level).
viewport.walkmapChildText = function(child)
    if not child then return "" end
    if maps and maps.NameWithLevels then return maps.NameWithLevels(child.mapID, child.name or "") end
    return child.name or ""
end

-- The map one level up from the one shown, cached per map.
local parentFor, parentID, parentName
local function parent()
    local currentMap = core.CurrentMap()
    if currentMap ~= parentFor then
        parentFor, parentID, parentName = currentMap, nil, nil
        if currentMap and maps and maps.Parent then parentID, parentName = maps.Parent(currentMap) end
    end
    return parentID, parentName
end

function levels.Up()
    local id = parent()
    if not id then return false end
    if WalkMapExtras.Follow() then WalkMapExtras.StopFollow() end
    return maps.Choose(id) and true or false
end
viewport.walkmapUp = levels.Up

-- Controller: LB (zoom out) in map control goes up a level when the map is
-- already zoomed all the way out. A pause is required first, so tapping LB
-- quickly to zoom out does not also leave the zone. Returns true when it
-- handled the press.
local lastZoomOutAt = 0
viewport.walkmapZoomUp = function(direction)
    if not direction or direction >= 0 then return false end
    local now = GetTime and GetTime() or 0
    local rested = now - lastZoomOutAt > 0.6
    lastZoomOutAt = now
    if core.ZoomIndex() ~= 1 or not rested then return false end
    return levels.Up()
end

-- Corner button: a gold arrow (the same art as the menus' submenu arrows,
-- mirrored to point back) and the name of the map above. Hidden at the top
-- level, and when turned off in the map's Buttons menu.
local upButton = CreateFrame("Button", nil, viewport)
upButton:SetFrameLevel(viewport:GetFrameLevel() + 32)
upButton:SetSize(120, 19)
upButton:SetPoint("TOPLEFT", viewport, "TOPLEFT", 6, -26)
upButton:EnableMouse(true)
upButton:RegisterForClicks("LeftButtonUp")
if WalkMapExtras.StyleButton then pcall(WalkMapExtras.StyleButton, upButton) end
local upLabel = upButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
upLabel:SetWordWrap(false)
local upArrow = upButton:CreateTexture(nil, "ARTWORK")
upArrow:SetSize(14, 14)
upArrow:SetPoint("LEFT", upButton, "LEFT", 5, 0)
if upArrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow") == false then
    -- Text fallback only if the client lacks the dropdown arrow art.
    upArrow:Hide()
    upArrow = nil
    upLabel:SetPoint("CENTER")
else
    upArrow:SetTexCoord(1, 0, 0, 1)
    upArrow:SetVertexColor(1, 0.85, 0.35)
    upLabel:SetPoint("LEFT", upArrow, "RIGHT", 2, 0)
end
levels.ButtonLabel = upLabel
upButton:Hide()
upButton:SetScript("OnClick", function() levels.Up() end)
upButton:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    local _, name = parent()
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:SetText(WalkMapL("Open " .. tostring(name or "the map above")))
    GameTooltip:AddLine(WalkMapL("Right-click on a continent or the world map does the same. "
        .. "Controller: LB in map control when zoomed all the way out."), 0.8, 0.8, 0.8, true)
    GameTooltip:AddLine(WalkMapL("Hide this button under Buttons."), 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end)
upButton:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
levels.Button = upButton

local function hiddenByUser()
    local saved = type(WalkMapCharacterSettings) == "table" and WalkMapCharacterSettings.hiddenButtons
    return type(saved) == "table" and saved.up == true
end

local shownText
function levels.Refresh()
    local _, name = parent()
    if not name or hiddenByUser() then
        if upButton:IsShown() then upButton:Hide() end
        shownText = nil
        return
    end
    -- In map control, fully zoomed out, LB is the way up: say so.
    local inControl = core.crosshair and core.crosshair:IsShown() and core.ZoomIndex() == 1
    local text = (inControl and "LB: " or "") .. (upArrow and "" or "< ") .. name
    if text ~= shownText then
        shownText = text
        upLabel:SetText(WalkMapL(text))
        local width = upLabel.GetStringWidth and upLabel:GetStringWidth() or 100
        upButton:SetWidth(math.max(60, math.min(260, (width or 100) + (upArrow and 30 or 18))))
    end
    if not upButton:IsShown() then upButton:Show() end
end

-- Outline of what a click opens: the game's own highlight art for the
-- continent or zone under the point, drawn on the map itself so it pans and
-- zooms with it. Clients without the highlight data simply show none.
local outlineLayer = CreateFrame("Frame", nil, canvas)
outlineLayer:SetAllPoints(canvas)
outlineLayer:SetFrameLevel(canvas:GetFrameLevel() + 1)
outlineLayer:EnableMouse(false)
local outline = outlineLayer:CreateTexture(nil, "ARTWORK")
if outline.SetBlendMode then outline:SetBlendMode("ADD") end
outline:Hide()
levels.Outline = outline
local outlineArt
local function showOutline(x, y)
    local currentMap = core.CurrentMap()
    local width, height = canvas:GetWidth(), canvas:GetHeight()
    if not (currentMap and x and y and C_Map and C_Map.GetMapHighlightInfoAtPosition
        and width and width > 0 and height and height > 0) then
        outline:Hide()
        return
    end
    local ok, fileID, atlas, texX, texY, sizeX, sizeY, posX, posY =
        pcall(C_Map.GetMapHighlightInfoAtPosition, currentMap, x, y)
    local hasFile = type(fileID) == "number" and fileID > 0
    if not ok or not (hasFile or atlas) or type(sizeX) ~= "number" or type(sizeY) ~= "number"
        or type(posX) ~= "number" or type(posY) ~= "number" then
        outline:Hide()
        return
    end
    local art = atlas or fileID
    if art ~= outlineArt then
        outlineArt = art
        if atlas and outline.SetAtlas then outline:SetAtlas(atlas) else outline:SetTexture(fileID) end
    end
    outline:SetTexCoord(0, type(texX) == "number" and texX or 1, 0, type(texY) == "number" and texY or 1)
    outline:ClearAllPoints()
    outline:SetPoint("TOPLEFT", canvas, "TOPLEFT", posX * width, -posY * height)
    outline:SetSize(sizeX * width, sizeY * height)
    outline:Show()
end

-- Hover label on world/continent maps: names what a click opens. With
-- controller focus on the map the mouse pointer is usually hidden and just
-- resting somewhere, so the label and outline then only follow the mouse
-- for a few seconds after it actually moved. In map control the outline
-- follows the crosshair (which shows the name itself).
local hover = CreateFrame("Frame", nil, viewport)
hover:SetAllPoints(viewport)
hover:SetFrameLevel(viewport:GetFrameLevel() + 31)
hover:EnableMouse(false)
local label = hover:CreateFontString(nil, "OVERLAY", "GameFontNormal")
label:SetTextColor(1, 0.85, 0.35)
label:SetShadowColor(0, 0, 0, 1)
label:SetShadowOffset(1, -1)
label:Hide()
levels.HoverLabel = label
local elapsed, sinceButton = 0, 0
local lastCursorX, lastCursorY, cursorMovedAt = nil, nil, -100
viewport:HookScript("OnUpdate", function(_, delta)
    elapsed = elapsed + (delta or 0)
    if elapsed < 0.05 then return end
    sinceButton = sinceButton + elapsed
    elapsed = 0
    if sinceButton >= 0.2 then
        sinceButton = 0
        levels.Refresh()
    end
    local now = GetTime and GetTime() or 0
    local cx, cy = GetCursorPosition()
    if cx ~= lastCursorX or cy ~= lastCursorY then
        -- The first reading only records where the pointer rests.
        if lastCursorX then cursorMovedAt = now end
        lastCursorX, lastCursorY = cx, cy
    end
    -- Map control: outline what A would open at the crosshair.
    if core.crosshair and core.crosshair:IsShown() and core.crosshair.ViewCenter then
        label:Hide()
        local x, y = core.crosshair.ViewCenter()
        if viewport.walkmapChildAt(x, y) then showOutline(x, y) else outline:Hide() end
        return
    end
    local padFocused = WalkMapNativeController and WalkMapNativeController.PadFocused
        and WalkMapNativeController.PadFocused()
    local child, x, y
    if viewport:IsMouseOver() and not upButton:IsMouseOver()
        and (not padFocused or now - cursorMovedAt < 4) then
        x, y = viewport.walkmapCursor()
        child = viewport.walkmapChildAt(x, y)
    end
    if not child then
        label:Hide()
        outline:Hide()
        return
    end
    showOutline(x, y)
    local scale = hover:GetEffectiveScale()
    label:ClearAllPoints()
    label:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", cx / scale, cy / scale + 14)
    label:SetText(WalkMapL(viewport.walkmapChildText(child)))
    label:Show()
end)
viewport:HookScript("OnHide", function() label:Hide() outline:Hide() end)
viewport:HookScript("OnShow", function() sinceButton = 1 end)
