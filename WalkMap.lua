-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- Resizable passive zone map.
-- Keeps the map aspect ratio while resizing.

local DEFAULT_WIDTH = 620
local UI_LAYOUT = WalkMapUI.MapLayout
local HORIZONTAL_PADDING = 20
local VERTICAL_PADDING = UI_LAYOUT.mapTop + UI_LAYOUT.footerHeight
local DEFAULT_HEIGHT = 386 + VERTICAL_PADDING

local MIN_MAP_WIDTH = 320
local MAX_MAP_WIDTH = 1050
local settings = WalkMapCharacterSettings
local saveLayout


-- =========================================================
-- Main frame
-- =========================================================

-- Protected only while the game's gamepad UI is on (WalkMap_Combat.lua).
local frame = CreateFrame(
    "Frame",
    "WalkMapOverlay",
    UIParent,
    (not WalkMapCombat.Free()) and "SecureHandlerBaseTemplate" or nil
)

frame:SetSize(
    DEFAULT_WIDTH,
    DEFAULT_HEIGHT
)

frame:SetPoint(
    "LEFT",
    UIParent,
    "LEFT",
    20,
    0
)

frame:SetFrameStrata("HIGH")
frame:SetClampedToScreen(true)
frame:SetMovable(true)

frame:EnableMouse(false)
frame:EnableKeyboard(false)

if frame.EnableGamePadButton then
    frame:EnableGamePadButton(false)
end

if frame.EnableGamePadStick then
    frame:EnableGamePadStick(false)
end

frame:Hide()


-- =========================================================
-- Background
-- =========================================================

local background =
    frame:CreateTexture(
        nil,
        "BACKGROUND"
    )

background:SetPoint("TOPLEFT", frame, "TOPLEFT", 7, -UI_LAYOUT.mapTop + 1)
background:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -7, UI_LAYOUT.footerHeight - 2)

background:SetColorTexture(
    0,
    0,
    0,
    0.82
)

-- Decorative game templates stay separate from the map and its controls.
-- Clear view can hide the whole skin without hiding markers or buttons.
local frameSkin = {WalkMapUI.Window(frame, UI_LAYOUT)}


-- =========================================================
-- Title
-- =========================================================

local title =
    frame:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormal"
    )

title:SetPoint("TOPLEFT", frame, "TOPLEFT", 110, -7)
title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -125, -7)
title:SetHeight(14)
title:SetJustifyH("CENTER")
title:SetWordWrap(false)
local mapPickerButton = CreateFrame("Button", nil, frame)
mapPickerButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 110, -4)
mapPickerButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -125, -4)
mapPickerButton:SetHeight(20)
mapPickerButton:EnableMouse(true)
title:ClearAllPoints()
title:SetPoint("LEFT", mapPickerButton, "LEFT", 2, 0)
title:SetPoint("RIGHT", mapPickerButton, "RIGHT", -70, 0)
local mapArrow = mapPickerButton:CreateTexture(nil, "ARTWORK")
mapArrow:SetSize(18, 18)
mapArrow:SetPoint("RIGHT", -1, 0)
mapArrow:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
local mapPickerHint = mapPickerButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
mapPickerHint:SetPoint("RIGHT", mapArrow, "LEFT", -1, 0)
mapPickerHint:SetText("Zones")
mapPickerHint:SetTextColor(1, 0.82, 0.3)
mapPickerButton:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
mapPickerButton:GetHighlightTexture():SetAlpha(0.3)
mapPickerButton:SetScript("OnClick", function() WalkMapExtras.OpenMapMenu(mapPickerButton) end)
WalkMapCombat.AllowInCombat(mapPickerButton)
-- When the map opens with the controller, focus lands on the first button
-- (often this title). Its tooltip should not pop up just from opening the
-- map: skip it for a moment after opening unless the mouse is really there.
-- Set in the map's OnShow script further down (a HookScript here would be
-- dropped by that later SetScript).
local mapOpenedAt = 0
function WalkMapJustOpened(button)
    if not (GetTime and GetTime() - mapOpenedAt < 1.5) then return false end
    -- With the controller, the hidden mouse pointer can rest on the title,
    -- so the controller's focus decides, not IsMouseOver.
    local pad = WalkMapNativeController and WalkMapNativeController.PadFocused
        and WalkMapNativeController.PadFocused()
    return pad or not (button.IsMouseOver and button:IsMouseOver())
end
mapPickerButton:SetScript("OnEnter", function(self)
    if WalkMapJustOpened(self) then return end
    if GameTooltip then
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Choose zone")
        GameTooltip:AddLine("Browse zones by region. Green marks your current zone; Follow returns to it.", 1, 1, 1, true)
        GameTooltip:Show()
    end
end)
mapPickerButton:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)


-- =========================================================
-- Drag area
-- =========================================================

local titleBar =
    CreateFrame(
        "Frame",
        nil,
        frame
    )

titleBar:SetPoint(
    "TOPLEFT",
    frame,
    "TOPLEFT",
    110,
    0
)

titleBar:SetPoint(
    "TOPRIGHT",
    frame,
    "TOPRIGHT",
    -30,
    0
)

titleBar:SetHeight(UI_LAYOUT.headerHeight)
titleBar:EnableMouse(true)
mapPickerButton:SetFrameLevel(titleBar:GetFrameLevel() + 2)


titleBar:SetScript(
    "OnMouseDown",
    function(_, button)

        if button == "LeftButton" and not WalkMapCombat.FrameLocked() then
            frame:StartMoving()
        end

    end
)


titleBar:SetScript(
    "OnMouseUp",
    function()

        if not WalkMapCombat.FrameLocked() then frame:StopMovingOrSizing() end
        if saveLayout then saveLayout() end

    end
)

-- The zone title fills most of the title bar, so it moves the map too when
-- dragged (a plain click still opens the zone picker), and so does the
-- metal border of the newer looks.
local function startMove()
    if not WalkMapCombat.FrameLocked() then frame:StartMoving() end
end
local function stopMove()
    if not WalkMapCombat.FrameLocked() then frame:StopMovingOrSizing() end
    if saveLayout then saveLayout() end
end
mapPickerButton:RegisterForDrag("LeftButton")
mapPickerButton:SetScript("OnDragStart", startMove)
mapPickerButton:SetScript("OnDragStop", stopMove)
WalkMapUI.DragEdges(frameSkin[1], startMove, stopMove)


-- =========================================================
-- Close button
-- =========================================================

local closeButton =
    CreateFrame(
        "Button",
        nil,
        frame,
        "SecureHandlerClickTemplate"
    )

closeButton:SetSize(
    24,
    24
)

-- The close art sits low inside its texture. Lift the button so the visible
-- X is centred on the DB badge and clear of the header's bottom edge.
closeButton:SetPoint(
    "TOPRIGHT",
    frame,
    "TOPRIGHT",
    -5,
    2
)

closeButton:EnableMouse(true)
WalkMapUI.CloseButton(closeButton)


closeButton:HookScript(
    "OnClick",
    function()

        if not WalkMapCombat.FrameLocked() then WalkMapNativeController.SetVisible(frame, false) end

    end
)


-- =========================================================
-- Canvas
-- =========================================================

local viewport = CreateFrame("Frame", nil, frame)
viewport:SetPoint("TOP", frame, "TOP", 0, -UI_LAYOUT.mapTop)
viewport:SetSize(DEFAULT_WIDTH - HORIZONTAL_PADDING,
    DEFAULT_HEIGHT - VERTICAL_PADDING)
if viewport.SetClipsChildren then viewport:SetClipsChildren(true) end
viewport:EnableMouse(true)

local canvas =
    CreateFrame(
        "Frame",
        nil,
        viewport
    )

canvas:SetPoint(
    "TOPLEFT",
    viewport,
    "TOPLEFT",
    0,
    0
)

canvas:SetSize(
    DEFAULT_WIDTH - HORIZONTAL_PADDING,
    DEFAULT_HEIGHT - VERTICAL_PADDING
)

canvas:EnableMouse(false)


-- =========================================================
-- Status
-- =========================================================

local status =
    frame:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlightSmall"
    )

status:SetPoint(
    "BOTTOM",
    0,
    8
)


-- =========================================================
-- Resize grip
-- =========================================================

local resizeGrip =
    CreateFrame(
        "Button",
        nil,
        frame
    )

resizeGrip:SetSize(
    26,
    26
)

resizeGrip:SetPoint(
    "BOTTOMRIGHT",
    frame,
    "BOTTOMRIGHT",
    -2,
    2
)

resizeGrip:EnableMouse(true)

-- Use the same size-grab icon as the game's chat windows, tinted to match
-- WalkMap's bronze frame instead of drawing diagonal white lines.
resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight", "ADD")
resizeGrip:GetNormalTexture():SetVertexColor(0.9, 0.72, 0.42)
resizeGrip:GetPushedTexture():SetVertexColor(0.9, 0.72, 0.42)


-- =========================================================
-- Player layer
-- =========================================================

local playerLayer =
    CreateFrame(
        "Frame",
        nil,
        canvas
    )

playerLayer:SetAllPoints(canvas)

-- The player arrow stays above every marker, turn-ins (+7) included.
playerLayer:SetFrameLevel(
    canvas:GetFrameLevel() + 8
)

playerLayer:EnableMouse(false)


local playerDot =
    playerLayer:CreateTexture(
        nil,
        "OVERLAY",
        nil,
        7
    )

playerDot:SetSize(
    32,
    32
)

playerDot:SetTexture(
    "Interface\\Minimap\\MinimapArrow"
)

playerDot:Hide()

-- A gold halo with a dark core keeps the arrow findable among dense quest
-- icons. It lives on the player layer, above objective pins, and follows the
-- arrow's own Show/Hide so every existing caller keeps working unchanged.
do
local playerHaloMask = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local playerHalo = playerLayer:CreateTexture(nil, "ARTWORK", nil, 1)
playerHalo:SetTexture(playerHaloMask)
playerHalo:SetVertexColor(1, 0.82, 0.25, 0.75)
playerHalo:SetSize(30, 30)
playerHalo:SetPoint("CENTER", playerDot, "CENTER")
local playerCore = playerLayer:CreateTexture(nil, "ARTWORK", nil, 2)
playerCore:SetTexture(playerHaloMask)
playerCore:SetVertexColor(0.04, 0.03, 0.02, 0.3)
playerCore:SetSize(24, 24)
playerCore:SetPoint("CENTER", playerDot, "CENTER")
playerHalo:Hide()
playerCore:Hide()
local playerPulse = playerHalo.CreateAnimationGroup and playerHalo:CreateAnimationGroup()
if playerPulse then
    local fade = playerPulse:CreateAnimation("Alpha")
    if fade then
        fade:SetFromAlpha(1)
        fade:SetToAlpha(0.35)
        fade:SetDuration(0.9)
        fade:SetSmoothing("IN_OUT")
    end
    playerPulse:SetLooping("BOUNCE")
end
hooksecurefunc(playerDot, "Show", function()
    -- Settings > Map & minimap > Player marker halo. The arrow is shown on
    -- every position update, so a changed setting applies straight away.
    if WalkMapExtras.PlayerHalo and not WalkMapExtras.PlayerHalo() then
        if playerPulse and playerPulse:IsPlaying() then playerPulse:Stop() end
        playerHalo:Hide()
        playerCore:Hide()
        return
    end
    playerHalo:Show()
    playerCore:Show()
    if playerPulse and not playerPulse:IsPlaying() then playerPulse:Play() end
end)
hooksecurefunc(playerDot, "Hide", function()
    if playerPulse then playerPulse:Stop() end
    playerHalo:Hide()
    playerCore:Hide()
end)
end


-- =========================================================
-- Party
-- =========================================================

local partyLayer =
    CreateFrame(
        "Frame",
        nil,
        canvas
    )

partyLayer:SetAllPoints(canvas)

partyLayer:SetFrameLevel(
    canvas:GetFrameLevel() + 5
)

partyLayer:EnableMouse(false)

local partyPins = {}


-- =========================================================
-- Map state
-- =========================================================

local textures = {}

local currentMap = nil
local currentFiles = nil
local updateZoomLabels
local resizing = false

local elapsed = 0

local mapScale = 1
local zoomStops = {1, 1.5, 2, 3, 4}
local zoomIndex = type(settings.zoomIndex) == "number"
    and settings.zoomIndex >= 1 and settings.zoomIndex <= #zoomStops
    and math.floor(settings.zoomIndex) == settings.zoomIndex
    and settings.zoomIndex or 1
local zoomOffsetX, zoomOffsetY = nil, nil

if type(settings.mapX) == "number" and type(settings.mapY) == "number"
    and math.abs(settings.mapX) < 10000 and math.abs(settings.mapY) < 10000 then
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", settings.mapX, settings.mapY)
end

saveLayout = function()
    settings.zoomIndex = zoomIndex
    if currentFiles and viewport and viewport:GetWidth() >= MIN_MAP_WIDTH then
        settings.mapWidth = viewport:GetWidth()
    end
    if frame.GetCenter and UIParent.GetCenter then
        local x, y = frame:GetCenter()
        local parentX, parentY = UIParent:GetCenter()
        if type(x) == "number" and type(y) == "number"
            and type(parentX) == "number" and type(parentY) == "number" then
            settings.mapX, settings.mapY = x - parentX, y - parentY
        end
    end
end

local artWidth = 0
local artHeight = 0

local mapTileWidth = 256
local mapTileHeight = 256


-- =========================================================
-- Exploration
-- =========================================================

local exploredTextures = {}
-- Unexplored areas (Settings > Map > Unexplored areas): the zone's overlay
-- pieces the player has not found yet, drawn dimmed in red. The full piece
-- list per map art comes from OpenMap's data (WalkMap_RevealData.lua, MIT);
-- the game only lists the explored ones. Main map only.
local unexploredTextures = {}
local mainCanvas = canvas

local explorationTileWidth = 256
local explorationTileHeight = 256

local explorationRefreshAt = 0
local explorationWarningShown = false
local explorationTileCount = 0
local appliedClearView = nil
local appliedTileCount = nil

local function applyMapAppearance()
    local clearView = WalkMapExtras.ClearView()
    if appliedClearView == clearView and appliedTileCount == explorationTileCount then
        return
    end
    appliedClearView = clearView
    appliedTileCount = explorationTileCount
    background:SetColorTexture(0, 0, 0, clearView and 0.04 or 0.82)
    for _, piece in ipairs(frameSkin) do
        piece:SetAlpha(clearView and 0 or piece.walkmapNormalAlpha or 1)
    end
    -- Explored-zone textures restore detail inside the zone. Base tiles also
    -- contain neighboring zones, so fade them only when overlays exist.
    local baseAlpha = clearView and explorationTileCount > 0 and 0.09 or 1
    for _, texture in ipairs(textures) do texture:SetAlpha(baseAlpha) end
    for _, texture in ipairs(exploredTextures) do texture:SetAlpha(1) end
    for _, texture in ipairs(unexploredTextures) do texture:SetAlpha(clearView and 0.3 or 0.55) end
end


-- =========================================================
-- Quests
-- =========================================================

local questPins = {}
local objectivePins = {}
-- The live-minimap scene swaps objectivePins temporarily; patrol lines are
-- drawn only for this, the large map's own pool.
local mainObjectivePins = objectivePins
-- Minimap views use unmerged coordinates. The large map merges pins using
-- its own pixel size, which changes with zoom and must not affect minimaps.
local miniObjectivePins = {}

local questRefreshAt = 0
local questSummary = ""

local questWarningShown = false


-- =========================================================
-- Helpers
-- =========================================================

-- Defined with the waypoint code; the map's Alt-click handler comes earlier.
local setWaypoint

local function say(message)

    print(
        "|cff80ff80WalkMap:|r "
        .. message
    )

end

-- Click on a quest's marker: focus that quest. Clicking the focused quest's
-- marker again turns focus off; a marker shared by several quests steps
-- through them and then turns focus off. Kept on the viewport table
-- (WalkMap.lua is near Lua's limit of 200 locals).
function viewport.walkmapFocusClick(ids)
    local list, seen = {}, {}
    for _, id in ipairs(ids or {}) do
        if type(id) == "number" and not seen[id] then
            seen[id] = true
            list[#list + 1] = id
        end
    end
    if #list == 0 then return false end
    local current = WalkMapExtras.QuestFocus()
    local nextID = list[1]
    for i, id in ipairs(list) do
        if id == current then nextID = list[i + 1] break end
    end
    WalkMapExtras.SetQuestFocus(nextID)
    if nextID then
        say("Quest focus: " .. (WalkMapQuestInfo and WalkMapQuestInfo.Title(nextID) or ("Quest " .. nextID))
            .. ". Click its marker again to show all quests.")
    else
        say("Quest focus off: all quests shown.")
    end
    return true
end

-- Mouse on a quest or objective marker. Middle-click or Alt-click: waypoint
-- at the marker. Plain left-click: focus. Returns true when it used the click.
function viewport.walkmapMarkerClick(pin, button, ids, label)
    local alt = IsAltKeyDown and IsAltKeyDown()
    local shift = IsShiftKeyDown and IsShiftKeyDown()
    if button == "MiddleButton" or (button == "LeftButton" and alt) then
        local mapID = WalkMapCore and WalkMapCore.CurrentMap()
        if mapID and pin.mapPercentX and pin.mapPercentY and WalkMapWaypoint then
            WalkMapWaypoint.Set(mapID, pin.mapPercentX, pin.mapPercentY, label or "Marker")
        end
        return true
    end
    if button == "LeftButton" and not shift then
        if GameTooltip then GameTooltip:Hide() end
        return viewport.walkmapFocusClick(ids)
    end
    return false
end


local function trackedQuestID()

    -- Only WalkMap's own quest focus counts; the game's tracked quest is
    -- ignored (4.80).
    local focus = WalkMapExtras.QuestFocus and WalkMapExtras.QuestFocus()
    return focus or 0

end


local function circle(
    parent,
    size,
    layer,
    r,
    g,
    b,
    alpha,
    x,
    y
)

    local texture =
        parent:CreateTexture(
            nil,
            layer
        )

    texture:SetSize(
        size,
        size
    )

    texture:SetPoint(
        "CENTER",
        x or 0,
        y or 0
    )

    texture:SetTexture(
        "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
    )

    texture:SetVertexColor(
        r,
        g,
        b,
        alpha or 1
    )

    return texture

end


-- =========================================================
-- Quest areas
-- =========================================================

local questAreas = {}
local questAreasUnavailable = false


local function clearQuestAreas()

    for _, blob in ipairs(questAreas) do
        blob:Hide()
        if blob.DrawNone then
            pcall(blob.DrawNone, blob)
        end
    end

end


local function refreshQuestAreas(
    mapID,
    activeQuestID,
    quests
)

    if WalkMapExtras.AreaMode() == "off" then
        clearQuestAreas()
        return
    end

    if questAreasUnavailable then
        return
    end


    local ok, message =
        pcall(
            function()

                local ids = {}
                local seen = {}
                local all = WalkMapExtras.AreaMode() == "all"
                if all then
                    for _, quest in ipairs(quests) do
                        local id = quest.questID
                        if type(id) == "number" and id > 0 and id ~= activeQuestID and not seen[id] and #ids < 24 then
                            seen[id] = true
                            ids[#ids + 1] = id
                        end
                    end
                end
                if activeQuestID > 0 then
                    ids[#ids + 1] = activeQuestID
                end
                for index, id in ipairs(ids) do
                    local blob = questAreas[index]
                    if not blob then
                        blob = CreateFrame("QuestPOIFrame", nil, canvas)
                        blob:SetAllPoints(canvas)
                        blob:SetFrameLevel(canvas:GetFrameLevel() + 1)
                        blob:EnableMouse(false)
                        blob:EnableKeyboard(false)
                        if blob.EnableGamePadButton then blob:EnableGamePadButton(false) end
                        if blob.EnableGamePadStick then blob:EnableGamePadStick(false) end
                        blob:SetFillTexture("Interface\\WorldMap\\UI-QuestBlob-Inside")
                        blob:SetBorderTexture("Interface\\WorldMap\\UI-QuestBlob-Outside")
                        blob:SetBorderScalar(1)
                        questAreas[index] = blob
                    end
                    -- During a resize the previously drawn blob is scaled.
                    -- Restore its normal anchors before rebuilding it at the
                    -- canvas's new size on mouse release.
                    blob:SetScale(1)
                    blob:ClearAllPoints()
                    blob:SetAllPoints(canvas)
                    blob:DrawNone()
                    blob:SetMapID(mapID)
                    local focused = id == activeQuestID
                    blob:SetFillAlpha(focused and 115 or 60)
                    blob:SetBorderAlpha(focused and 215 or 110)
                    blob:DrawBlob(id, true)
                    blob.walkmapQuestID = id
                    blob.walkmapFocused = focused
                    blob.baseWidth, blob.baseHeight =
                        canvas:GetWidth(), canvas:GetHeight()
                    blob:Show()
                end
                for index = #ids + 1, #questAreas do
                    questAreas[index]:Hide()
                    questAreas[index]:DrawNone()
                end

            end
        )


    if not ok then

        clearQuestAreas()

        questAreasUnavailable =
            true

        say(
            "Quest areas are not supported as expected in this client: "
            .. tostring(message)
        )

    end

end


-- =========================================================
-- Exploration
-- =========================================================

local function clearExploration()

    explorationTileCount = 0
    appliedTileCount = nil

    if canvas == mainCanvas then
        for _, texture in ipairs(unexploredTextures) do texture:Hide() end
    end

    for _, texture
        in ipairs(exploredTextures)
    do

        texture:Hide()

    end

end


local function paddedSize(pixels)

    local result = 16

    while result < pixels do

        result =
            result * 2

    end

    return result

end


local function refreshExploration(
    mapID
)

    clearExploration()


    if not C_MapExplorationInfo
        or not C_MapExplorationInfo.GetExploredMapTextures
    then

        return

    end


    local overlays =
        C_MapExplorationInfo.GetExploredMapTextures(
            mapID
        )
        or {}


    local index, unexploredIndex = 0, 0

    -- The pieces not in the game's explored list, from the full list.
    local all = {}
    for _, overlay in ipairs(overlays) do all[#all + 1] = overlay end
    if canvas == mainCanvas and WalkMapExtras.Unexplored and WalkMapExtras.Unexplored()
        and WalkMapRevealData and C_Map.GetMapArtID then
        local okArt, artID = pcall(C_Map.GetMapArtID, mapID)
        local pieces = okArt and WalkMapRevealData[artID]
        if type(pieces) == "table" then
            local explored = {}
            for _, overlay in ipairs(overlays) do
                explored[tostring(overlay.textureWidth) .. ":" .. tostring(overlay.textureHeight)
                    .. ":" .. tostring(overlay.offsetX) .. ":" .. tostring(overlay.offsetY)] = true
            end
            for key, files in pairs(pieces) do
                if not explored[key] then
                    local w, h, x, y = key:match("^(%d+):(%d+):(%d+):(%d+)$")
                    local ids = {}
                    for id in tostring(files):gmatch("%d+") do ids[#ids + 1] = tonumber(id) end
                    if w and #ids > 0 then
                        all[#all + 1] = {textureWidth = tonumber(w), textureHeight = tonumber(h),
                            offsetX = tonumber(x), offsetY = tonumber(y), fileDataIDs = ids,
                            walkmapUnexplored = true}
                    end
                end
            end
        end
    end


    for _, overlay
        in ipairs(all)
    do

        local w =
            overlay.textureWidth

        local h =
            overlay.textureHeight

        local ox =
            overlay.offsetX

        local oy =
            overlay.offsetY


        if w
            and h
            and ox
            and oy
            and w > 0
            and h > 0
            and overlay.fileDataIDs
            and not overlay.isShownByMouseOver
        then

            local tw =
                explorationTileWidth

            local th =
                explorationTileHeight


            local columns =
                math.ceil(
                    w / tw
                )

            local rows =
                math.ceil(
                    h / th
                )


            for row = 0, rows - 1 do

                for col = 0, columns - 1 do

                    local file =
                        overlay.fileDataIDs[
                            row
                            * columns
                            + col
                            + 1
                        ]


                    local pw =
                        math.min(
                            tw,
                            w - col * tw
                        )

                    local ph =
                        math.min(
                            th,
                            h - row * th
                        )


                    local x =
                        ox
                        + col * tw

                    local y =
                        oy
                        + row * th


                    local left =
                        math.max(
                            0,
                            x
                        )

                    local top =
                        math.max(
                            0,
                            y
                        )

                    local right =
                        math.min(
                            artWidth,
                            x + pw
                        )

                    local bottom =
                        math.min(
                            artHeight,
                            y + ph
                        )


                    if file
                        and right > left
                        and bottom > top
                    then

                        local pool, slot = exploredTextures, nil
                        if overlay.walkmapUnexplored then
                            unexploredIndex = unexploredIndex + 1
                            pool, slot = unexploredTextures, unexploredIndex
                        else
                            index = index + 1
                            slot = index
                        end


                        local texture =
                            pool[slot]


                        if not texture then

                            texture =
                                canvas:CreateTexture(
                                    nil,
                                    "ARTWORK",
                                    nil,
                                    1
                                )

                            pool[slot] =
                                texture

                        end

                        if overlay.walkmapUnexplored then
                            texture:SetDesaturated(true)
                            texture:SetVertexColor(1, 0.45, 0.4)
                            texture:SetAlpha(WalkMapExtras.ClearView() and 0.3 or 0.55)
                        end


                        texture:ClearAllPoints()

                        texture.artX, texture.artY = left, top
                        texture.artWidth, texture.artHeight = right - left, bottom - top


                        texture:SetPoint(
                            "TOPLEFT",
                            left * mapScale,
                            -top * mapScale
                        )


                        texture:SetSize(
                            (right - left)
                            * mapScale,

                            (bottom - top)
                            * mapScale
                        )


                        texture:SetTexture(
                            file
                        )


                        texture:SetDrawLayer(
                            "ARTWORK",
                            overlay.isDrawOnTopLayer
                                and 2
                                or 1
                        )


                        local fw =
                            paddedSize(pw)

                        local fh =
                            paddedSize(ph)


                        texture:SetTexCoord(
                            (left - x) / fw,
                            (right - x) / fw,
                            (top - y) / fh,
                            (bottom - y) / fh
                        )


                        texture:Show()

                    end

                end

            end

        end

    end

    explorationTileCount = index
    appliedTileCount = nil

end


local function safeRefreshExploration(
    mapID
)

    local ok, message =
        pcall(
            refreshExploration,
            mapID
        )


    if not ok then

        clearExploration()


        if not explorationWarningShown then

            say(
                "Map details: "
                .. tostring(message)
            )

            explorationWarningShown =
                true

        end

    end

end


-- =========================================================
-- Quest ready check
-- =========================================================

local function isQuestReady(
    questID
)

    if not questID then
        return false
    end


    if C_QuestLog
        and C_QuestLog.ReadyForTurnIn
    then

        local ok, ready =
            pcall(
                C_QuestLog.ReadyForTurnIn,
                questID
            )


        if ok then

            return
                ready
                and true
                or false

        end

    end


    return false

end


-- =========================================================
-- Quests
-- =========================================================

-- Patrol routes (QuestieDB NPC waypoints) for the focused quest's NPCs.
local hidePatrols, drawPatrols
do
local patrolLayer = CreateFrame("Frame", nil, canvas)
patrolLayer:SetAllPoints(canvas)
patrolLayer:SetFrameLevel(canvas:GetFrameLevel() + 3)
patrolLayer:EnableMouse(false)
local patrolLines, patrolDots = {}, {}
hidePatrols = function()
    for _, line in ipairs(patrolLines) do line:Hide() end
    for _, dot in ipairs(patrolDots) do dot:Hide() end
end
drawPatrols = function(mapID, questID)
    hidePatrols()
    if type(questID) ~= "number" or questID <= 0 or not WalkMapLiveDB then return end
    local data = WalkMapLiveDB.Objective(questID)
    local paths = data and data[3] and data[3][mapID]
    if not paths then return end
    local w, h = canvas:GetWidth(), canvas:GetHeight()
    local lineCount, dotCount = 0, 0
    local canLine = patrolLayer.CreateLine ~= nil
    for _, path in ipairs(paths) do
        for i = 1, #path do
            local a, b = path[i], path[i + 1]
            if canLine and b then
                lineCount = lineCount + 1
                local line = patrolLines[lineCount]
                if not line then
                    line = patrolLayer:CreateLine(nil, "ARTWORK")
                    line:SetThickness(2)
                    line:SetColorTexture(1, 0.55, 0.45, 0.7)
                    patrolLines[lineCount] = line
                end
                line:SetStartPoint("TOPLEFT", canvas, a[1] * w / 100, -a[2] * h / 100)
                line:SetEndPoint("TOPLEFT", canvas, b[1] * w / 100, -b[2] * h / 100)
                line:Show()
            elseif not canLine and i % 2 == 1 then
                -- Without line widgets, mark every other point with a dot.
                dotCount = dotCount + 1
                local dot = patrolDots[dotCount]
                if not dot then
                    dot = patrolLayer:CreateTexture(nil, "ARTWORK")
                    dot:SetSize(4, 4)
                    dot:SetColorTexture(1, 0.55, 0.45, 0.7)
                    patrolDots[dotCount] = dot
                end
                dot:ClearAllPoints()
                dot:SetPoint("CENTER", canvas, "TOPLEFT", a[1] * w / 100, -a[2] * h / 100)
                dot:Show()
            end
            if lineCount >= 600 or dotCount >= 300 then return end
        end
    end
end
end

-- Rank labels from QuestieDB: 1 elite, 2 rare elite, 3 boss, 4 rare.
local RANK_LABELS = {[1] = "Elite", [2] = "Rare elite", [3] = "Boss", [4] = "Rare"}
local function rankColor(rank)
    if rank == 2 or rank == 4 then return 0.82, 0.86, 0.95 end -- silver: rare
    return 1, 0.8, 0.25 -- gold: elite and boss
end

local function clearQuests()

    for _, pin
        in ipairs(questPins)
    do

        pin:Hide()
        pin.miniVisible = false

    end

    for _, pin in ipairs(objectivePins) do pin:Hide() end
    if objectivePins == mainObjectivePins then hidePatrols() end
    miniObjectivePins = {}


    clearQuestAreas()

end

local objectiveArt = {
    "Interface\\AddOns\\WalkMap\\Icons\\slay_mono.tga",
    "Interface\\AddOns\\WalkMap\\Icons\\object_mono.tga",
    "Interface\\AddOns\\WalkMap\\Icons\\loot_mono.tga",
    "Interface\\AddOns\\WalkMap\\Icons\\node.tga",
}
-- One distinct tint per objective kind so slay, object and loot spots can be
-- told apart without hovering. The mono icons keep their black ring/glyph.
local objectiveColors = {
    {1, 0.45, 0.38},   -- 1: slay
    {0.45, 0.8, 1},    -- 2: object/interact
    {0.55, 0.95, 0.45}, -- 3: loot
    {1, 0.86, 0.3},    -- 4: other
}
local function objectiveColor(kind)
    local color = objectiveColors[kind] or objectiveColors[4]
    return color[1], color[2], color[3]
end
-- Screen-space merge radius for large-map objective icons. Pins are 19-23 px,
-- so the zoomed-out radius stops icons overlapping without merging over a
-- wide area. Zooming in separates spawn points again; minimaps stay per-point.
local function objectiveMergeRadius()
    if zoomIndex == 1 then return 22 end
    if zoomIndex == 2 then return 19 end
    return 16
end

local function objectiveProgress(objectives, label, index, kind)
    if type(objectives) ~= "table" then return nil end
    local found
    if type(label) == "string" and label ~= "" then
        local lower = label:lower()
        for _, objective in ipairs(objectives) do
            if type(objective.text) == "string"
                and objective.text:lower():find(lower, 1, true) then
                found = objective
                break
            end
        end
    end
    if not found then
        local candidate = objectives[index]
        local validType = kind == 1 and "monster" or kind == 3 and "item"
        if candidate and (not validType or candidate.type == validType) then
            found = candidate
        end
    end
    if not found then return nil, false end
    local done, needed = found.numFulfilled, found.numRequired
    if type(done) == "number" and type(needed) == "number" and needed > 0 then
        return string.format("%d/%d", done, needed), found.finished == true
    end
    return nil, found.finished == true
end

local function addObjectiveTooltip(entry)
    local label = entry.objectiveName or "Objective"
    if entry.dropSource then label = label .. " (" .. entry.dropSource .. ")" end
    if entry.progress then label = label .. "  " .. entry.progress end
    GameTooltip:AddLine(label, 1, 0.9, 0.65)
    local levels = type(entry.levels) == "table" and entry.levels or nil
    if levels or RANK_LABELS[entry.rank] then
        -- "Level 15-16", coloured like quest difficulty for your level.
        local text = levels and ("Level " .. levels[1]
            .. (levels[2] ~= levels[1] and ("-" .. levels[2]) or "")) or nil
        if RANK_LABELS[entry.rank] then
            text = text and (text .. "  " .. RANK_LABELS[entry.rank]) or RANK_LABELS[entry.rank]
        end
        local r, g, b = 0.85, 0.85, 0.85
        if levels and GetQuestDifficultyColor then
            local ok, color = pcall(GetQuestDifficultyColor, levels[2])
            if ok and type(color) == "table" and color.r then r, g, b = color.r, color.g, color.b end
        elseif RANK_LABELS[entry.rank] then
            r, g, b = rankColor(entry.rank)
        end
        GameTooltip:AddLine(text, r, g, b)
    end
    if type(entry.dropRate) == "number" then
        GameTooltip:AddLine("Estimated drop rate: "
            .. string.format("%g%%", entry.dropRate), 0.6, 0.9, 0.6)
        return true
    end
    return false
end

local function refreshObjectivePins(mapID, mapQuests, activeQuestID)
    if not WalkMapExtras.ObjectiveIcons() or not WalkMapObjectives then return end

    local focusedOnly = WalkMapExtras.FocusObjectiveIcons()
    if focusedOnly and (type(activeQuestID) ~= "number" or activeQuestID <= 0) then
        return
    end

    local questIDs = {}
    if C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
        local length = C_QuestLog.GetNumQuestLogEntries() or 0
        for index = 1, math.min(length, 100) do
            local info = C_QuestLog.GetInfo(index)
            if info and not info.isHeader and type(info.questID) == "number"
                and not WalkMapExtras.HiddenOnMap(info.questID) then
                questIDs[info.questID] = true
            end
        end
    else
        for _, quest in ipairs(mapQuests) do
            if quest.questID then questIDs[quest.questID] = true end
        end
    end
    if focusedOnly then
        local inLog = questIDs[activeQuestID]
        questIDs = inLog and {[activeQuestID] = true} or {}
    end

    local ordered = {}
    for questID in pairs(questIDs) do ordered[#ordered + 1] = questID end
    table.sort(ordered, function(a, b)
        if a == activeQuestID then return true end
        if b == activeQuestID then return false end
        return a < b
    end)

    local groups = {}
    local shownPoints = 0
    local mergeRadius = objectiveMergeRadius()
    for _, questID in ipairs(ordered) do
        local questData = WalkMapLiveDB and WalkMapLiveDB.Objective(questID)
            or WalkMapObjectives[questID]
        local points = questData and questData[2][mapID]
        if points and not isQuestReady(questID) then
            local objectives
            if C_QuestLog.GetQuestObjectives then
                local ok, progress = pcall(C_QuestLog.GetQuestObjectives, questID)
                if ok and type(progress) == "table" then
                    objectives = progress
                end
            end
            for _, point in ipairs(points) do
                if shownPoints >= 350 then break end
                local label = questData[1][point[3]]
                local markerKey = WalkMapExtras.MarkerKey("objective", mapID,
                    tostring(questID) .. ":" .. tostring(point[3]) .. ":"
                    .. tostring(point[4]) .. ":" .. tostring(point[6] or ""),
                    point[1], point[2])
                local progress, finished = objectiveProgress(
                    objectives, label, point[3], point[4])
                if not finished and not WalkMapExtras.MarkerHidden(markerKey) then
                    shownPoints = shownPoints + 1
                    miniObjectivePins[#miniObjectivePins + 1] = {
                        questID = questID,
                        mapPercentX = point[1] / 100,
                        mapPercentY = point[2] / 100,
                        miniArt = objectiveArt[point[4]] or objectiveArt[4],
                        miniColor = objectiveColors[point[4]] or objectiveColors[4],
                        miniVisible = true,
                        hiddenKey = markerKey,
                        objectiveName = label,
                    }
                    local x = point[1] * canvas:GetWidth() / 100
                    local y = point[2] * canvas:GetHeight() / 100
                    local group
                    -- Compare against each group's first point, not its
                    -- moving centre, so a group can never chain wider.
                    for _, nearby in ipairs(groups) do
                        local dx, dy = nearby.x - x, nearby.y - y
                        if dx * dx + dy * dy <= mergeRadius * mergeRadius then
                            group = nearby
                            break
                        end
                    end
                    if not group then
                        group = {x = x, y = y, sumX = 0, sumY = 0, points = 0, entries = {}}
                        groups[#groups + 1] = group
                    end
                    group.sumX, group.sumY = group.sumX + x, group.sumY + y
                    group.points = group.points + 1
                    local rate = type(point[5]) == "number" and point[5] or nil
                    local repeated = false
                    for _, entry in ipairs(group.entries) do
                        if entry.questID == questID and entry.index == point[3]
                            and entry.dropRate == rate
                            and entry.dropSource == point[6] then
                            repeated = true
                            break
                        end
                    end
                    if not repeated then
                        group.entries[#group.entries + 1] = {
                            questID = questID, index = point[3], kind = point[4],
                            questTitle = C_QuestLog.GetTitleForQuestID
                                and C_QuestLog.GetTitleForQuestID(questID)
                                or "Quest " .. questID,
                            objectiveName = label, progress = progress,
                            dropRate = rate, dropSource = point[6],
                            active = questID == activeQuestID,
                            hiddenKey = markerKey,
                            rank = point[7], levels = point[8],
                        }
                    end
                end
            end
        end
    end

    for index, group in ipairs(groups) do
        local pin = objectivePins[index]
        if not pin then
            pin = CreateFrame("Frame", nil, canvas)
            pin:SetFrameLevel(canvas:GetFrameLevel() + 4)
            pin:EnableMouse(true)
            pin.icon = pin:CreateTexture(nil, "ARTWORK")
            pin.icon:SetAllPoints(pin)
            -- Gold (elite/boss) or silver (rare) rim from the NPC's rank.
            pin.rim = pin:CreateTexture(nil, "BORDER")
            pin.rim:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
            pin.rim:SetPoint("TOPLEFT", pin, "TOPLEFT", -3, 3)
            pin.rim:SetPoint("BOTTOMRIGHT", pin, "BOTTOMRIGHT", 3, -3)
            pin.rim:Hide()
            -- Dark disc behind the count so it stays readable on any map art.
            pin.badgeBack = pin:CreateTexture(nil, "OVERLAY", nil, 1)
            pin.badgeBack:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
            pin.badgeBack:SetVertexColor(0.05, 0.04, 0.03, 0.9)
            pin.badgeBack:SetSize(13, 13)
            pin.badgeBack:SetPoint("CENTER", pin, "TOPRIGHT", -1, -1)
            pin.badge = pin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            pin.badge:SetDrawLayer("OVERLAY", 2)
            pin.badge:SetPoint("CENTER", pin.badgeBack, "CENTER", 0.5, 0)
            pin.badge:SetTextColor(1, 0.95, 0.8)
            pin.badge:SetShadowColor(0, 0, 0, 1)
            pin.badge:SetShadowOffset(1, -1)
            pin:SetScript("OnEnter", function(self)
                if not GameTooltip then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local entries = self.entries
                if #entries == 1 then
                    GameTooltip:SetText(entries[1].questTitle or "Quest")
                    if addObjectiveTooltip(entries[1]) then
                        GameTooltip:AddLine("QuestieDB estimate; may differ in-game.", 0.7, 0.7, 0.7)
                    end
                    -- Called directly: "a and f()" would keep only f's first result.
                    local nextID, nextName
                    if WalkMapLiveDB and WalkMapLiveDB.NextQuest then
                        nextID, nextName = WalkMapLiveDB.NextQuest(entries[1].questID)
                    end
                    if nextID then
                        GameTooltip:AddLine("Next in chain: " .. tostring(nextName or ("Quest " .. nextID)), 0.6, 0.85, 1)
                    end
                else
                    GameTooltip:SetText(#entries .. " quest objectives")
                    local hasRate = false
                    for n = 1, math.min(#entries, 10) do
                        local entry = entries[n]
                        GameTooltip:AddLine(entry.questTitle or "Quest",
                            entry.active and 0.4 or 1, entry.active and 0.9 or 0.82, 1)
                        if addObjectiveTooltip(entry) then hasRate = true end
                    end
                    if #entries > 10 then
                        GameTooltip:AddLine("+ " .. (#entries - 10) .. " more objectives", 0.7, 0.7, 0.7)
                    end
                    if hasRate then
                        GameTooltip:AddLine("QuestieDB estimates; may differ in-game.", 0.7, 0.7, 0.7)
                    end
                end
                GameTooltip:AddLine(#entries == 1 and "Click to focus this quest"
                    or "Click to focus these quests in turn", 0.7, 0.8, 1)
                GameTooltip:AddLine("Right-click or Shift-click to hide this location", 0.7, 0.8, 1)
                GameTooltip:Show()
            end)
            pin:SetScript("OnLeave", function()
                if GameTooltip then GameTooltip:Hide() end
            end)
            pin:SetScript("OnMouseDown", function(self, button)
                local hideClick = button == "RightButton"
                    or (button == "LeftButton" and IsShiftKeyDown and IsShiftKeyDown())
                if not hideClick then
                    local ids = {}
                    for _, item in ipairs(self.entries or {}) do ids[#ids + 1] = item.questID end
                    viewport.walkmapMarkerClick(self, button, ids,
                        self.entries and self.entries[1] and self.entries[1].questTitle)
                    return
                end
                local keys = {}
                for _, item in ipairs(self.entries or {}) do
                    if item.hiddenKey then keys[#keys + 1] = item.hiddenKey end
                end
                if GameTooltip then GameTooltip:Hide() end
                self:Hide()
                WalkMapExtras.HideMarkers(keys)
            end)
            objectivePins[index] = pin
        end
        local entry = group.entries[1]
        pin:SetSize(#group.entries > 1 and 23 or 19, #group.entries > 1 and 23 or 19)
        pin:ClearAllPoints()
        -- Place merged pins at the average of their points.
        local gx, gy = group.x, group.y
        if group.points and group.points > 1 then
            gx, gy = group.sumX / group.points, group.sumY / group.points
        end
        pin:SetPoint("CENTER", canvas, "TOPLEFT", gx, -gy)
        pin.mapPercentX = gx / canvas:GetWidth()
        pin.mapPercentY = gy / canvas:GetHeight()
        pin.icon:SetTexture(objectiveArt[entry.kind] or objectiveArt[4])
        pin.icon:SetVertexColor(objectiveColor(entry.kind))
        local bestRank
        for _, item in ipairs(group.entries) do
            -- Prefer elite/boss over rare when a group mixes them.
            if RANK_LABELS[item.rank] and (not bestRank or item.rank == 1 or item.rank == 3) then
                bestRank = item.rank
            end
        end
        if bestRank then
            local r, g, b = rankColor(bestRank)
            pin.rim:SetVertexColor(r, g, b, 1)
            pin.rim:Show()
        else
            pin.rim:Hide()
        end
        pin.icon:SetAlpha(entry.active and 1 or 0.8)
        pin.entries = group.entries
        -- Keep these for consumers that inspect a single quest icon.
        pin.questTitle, pin.objectiveName = entry.questTitle, entry.objectiveName
        pin.dropRate = entry.dropRate
        if #group.entries > 1 then
            local count = #group.entries
            pin.badge:SetText(tostring(count))
            pin.badgeBack:SetSize(count >= 10 and 17 or 13, 13)
            pin.badge:Show()
            pin.badgeBack:Show()
        else
            pin.badge:Hide()
            pin.badgeBack:Hide()
        end
        pin:Show()
    end
    if objectivePins == mainObjectivePins then drawPatrols(mapID, activeQuestID) end
end


local function refreshQuests(
    mapID
)

    clearQuests()


    if not C_QuestLog
        or not C_QuestLog.GetQuestsOnMap
    then

        questSummary =
            "Quest API unavailable in this client"

        return

    end


    local quests =
        WalkMapExtras.WithoutHidden(C_QuestLog.GetQuestsOnMap(
            mapID
        )
        or {})


    local activeQuestID =
        trackedQuestID()


    refreshQuestAreas(
        mapID,
        activeQuestID,
        quests
    )

    refreshObjectivePins(mapID, quests, activeQuestID)
    -- Ready quests the game puts no marker on (handed in at an object, for
    -- example) get their "?" from QuestieDB (WalkMap_TurnIns.lua).
    if WalkMapTurnIns then
        quests = WalkMapExtras.WithoutHidden(WalkMapTurnIns.Add(mapID, quests, isQuestReady))
    end


    local count = 0
    local areaMode = WalkMapExtras.AreaMode()


    for _, quest
        in ipairs(quests)
    do

        local x =
            quest.x

        local y =
            quest.y


        if type(x) == "number"
            and type(y) == "number"
            and x >= 0
            and x <= 1
            and y >= 0
            and y <= 1
            and (areaMode == "all" or
                (areaMode == "focus" and quest.questID == activeQuestID
                    and type(activeQuestID) == "number" and activeQuestID > 0)
                -- Turn-in markers stay even when areas are hidden or focused.
                or isQuestReady(quest.questID)
                -- So does the game's marker for a quest QuestieDB has no
                -- objective locations for: nothing else shows where to go.
                or (WalkMapTurnIns and WalkMapTurnIns.Unlocated(quest.questID, mapID)))
        then

            count =
                count + 1


            local pin =
                questPins[count]


            if not pin then

                pin =
                    CreateFrame(
                        "Frame",
                        nil,
                        canvas
                    )


                pin:SetFrameLevel(
                    canvas:GetFrameLevel()
                    + 4
                )


                pin:SetSize(
                    24,
                    24
                )


                pin:EnableMouse(false)


                pin.shadow =
                    circle(
                        pin,
                        22,
                        "BACKGROUND",
                        0,
                        0,
                        0,
                        0.55,
                        1,
                        -2
                    )


                pin.ring =
                    circle(
                        pin,
                        19,
                        "BORDER",
                        1,
                        0.76,
                        0.25
                    )


                pin.icon =
                    circle(
                        pin,
                        14,
                        "ARTWORK",
                        0.07,
                        0.16,
                        0.24
                    )

                pin.symbol = pin:CreateTexture(nil, "OVERLAY", nil, 1)
                pin.symbol:SetPoint("CENTER")


                pin.number =
                    pin:CreateFontString(
                        nil,
                        "OVERLAY",
                        "GameFontNormalSmall"
                    )


                pin.number:SetPoint(
                    "CENTER"
                )


                pin.number:SetShadowColor(
                    0,
                    0,
                    0,
                    1
                )


                pin.number:SetShadowOffset(
                    1,
                    -1
                )


                pin.label =
                    pin:CreateFontString(
                        nil,
                        "OVERLAY",
                        "GameFontHighlightSmall"
                    )


                pin.label:SetWidth(150)
                pin.label:SetWordWrap(false)


                pin.label:SetTextColor(
                    1,
                    0.94,
                    0.8
                )


                pin.label:SetShadowColor(
                    0,
                    0,
                    0,
                    1
                )


                pin.label:SetShadowOffset(
                    1,
                    -1
                )


                questPins[count] =
                    pin

            end


            pin:ClearAllPoints()


            pin:SetPoint(
                "CENTER",
                canvas,
                "TOPLEFT",
                x * canvas:GetWidth(),
                -y * canvas:GetHeight()
            )

            pin.mapX, pin.mapY = x * canvas:GetWidth(), y * canvas:GetHeight()
            pin.mapPercentX, pin.mapPercentY = x, y
            pin.miniVisible = true
            pin.questID = quest.questID
            pin.turnInName = quest.walkmapTurnIn


            local ready =
                isQuestReady(
                    quest.questID
                )


            local active =
                quest.questID
                == activeQuestID


            if ready then

                -- Yellow quest turn-in marker.

                pin.symbol:Hide()
                pin.ring:SetAlpha(1)
                pin.icon:SetAlpha(0)

                pin.ring:SetVertexColor(
                    1,
                    0.82,
                    0
                )


                pin.icon:SetVertexColor(
                    1,
                    0.82,
                    0
                )


                pin.ring:SetSize(
                    19,
                    19
                )


                pin.icon:SetSize(
                    15,
                    15
                )


                pin.number:SetText("")

                -- Built-in quest turn-in artwork, without a bundled Questie asset.
                pin.symbol:SetTexture("Interface\\GossipFrame\\ActiveQuestIcon")
                pin.symbol:SetSize(19, 19)
                pin.symbol:SetVertexColor(1, 1, 1)
                pin.symbol:Show()
                pin.ring:SetAlpha(0)


                pin.number:SetTextColor(
                    0,
                    0,
                    0
                )

            else

                -- Use the nearest known objective type for the game's quest
                -- position. Some beta quests have no known coordinates; a
                -- neutral Questie-style marker covers those without guessing.
                local kind = 4
                local entry = WalkMapLiveDB and WalkMapLiveDB.Objective(quest.questID)
                    or WalkMapObjectives and WalkMapObjectives[quest.questID]
                local locations = entry and entry[2][mapID]
                if locations then
                    local closest
                    for _, location in ipairs(locations) do
                        local distance = (location[1] / 100 - x) ^ 2
                            + (location[2] / 100 - y) ^ 2
                        if not closest or distance < closest then
                            closest = distance
                            kind = location[4]
                        end
                    end
                end
                pin.symbol:SetTexture(objectiveArt[kind] or objectiveArt[4])
                pin.symbol:SetSize(active and 24 or 19, active and 24 or 19)
                pin.symbol:SetVertexColor(active and 0.4 or 1,
                    active and 0.85 or 0.78, active and 1 or 0.24)
                pin.symbol:Show()
                pin.ring:SetAlpha(0)
                pin.icon:SetAlpha(0)

                pin.ring:SetVertexColor(
                    active and 0.3 or 1,
                    active and 0.85 or 0.76,
                    active and 1 or 0.25
                )


                pin.icon:SetVertexColor(
                    0.07,
                    0.16,
                    0.24
                )


                pin.ring:SetSize(
                    active and 23 or 19,
                    active and 23 or 19
                )


                pin.icon:SetSize(
                    active and 18 or 14,
                    active and 18 or 14
                )


                pin.number:SetText(
                    ""
                )


                pin.number:SetTextColor(
                    1,
                    0.94,
                    0.76
                )

            end


            local name =
                C_QuestLog.GetTitleForQuestID
                and
                C_QuestLog.GetTitleForQuestID(
                    quest.questID
                )


            pin.label:SetText(
                name
                or
                (
                    "Quest "
                    .. tostring(
                        quest.questID
                    )
                )
            )

            pin.questTitle = name or "Quest " .. tostring(quest.questID)
            pin.ready, pin.active = ready, active
            -- Turn-in markers sit above every other marker (below the arrow).
            pin:SetFrameLevel(canvas:GetFrameLevel() + (ready and 7 or 4))
            if WalkMapExtras.ShowQuestNames() then
                pin.label:Show()
            else
                pin.label:Hide()
            end


            pin.label:ClearAllPoints()


            if x > 0.65 then

                pin.label:SetPoint(
                    "RIGHT",
                    pin,
                    "LEFT",
                    -3,
                    0
                )


                pin.label:SetJustifyH(
                    "RIGHT"
                )

            else

                pin.label:SetPoint(
                    "LEFT",
                    pin,
                    "RIGHT",
                    3,
                    0
                )


                pin.label:SetJustifyH(
                    "LEFT"
                )

            end


            pin:Show()

        end

    end

    local consumed = {}
    for i = 1, count do
        if not consumed[i] then
            local group = {questPins[i]}
            consumed[i] = true
            for j = i + 1, count do
                if not consumed[j] then
                    local other = questPins[j]
                    local dx = questPins[i].mapX - other.mapX
                    local dy = questPins[i].mapY - other.mapY
                    if dx * dx + dy * dy <= 16 * 16 then
                        group[#group + 1] = other
                        consumed[j] = true
                    end
                end
            end
            local lead = group[1]
            for _, pin in ipairs(group) do
                if (pin.ready and not lead.ready)
                    or (pin.active and not lead.ready and not lead.active) then
                    lead = pin
                end
            end
            local entries, known = {}, {}
            -- The game can list the same quest twice at almost the same spot.
            -- The large map merges them; the minimaps zoom further in and would
            -- show both ("??"), so only one pin per quest stays minimap-visible.
            local onMini = {}
            if lead.questID then onMini[lead.questID] = true end
            for _, pin in ipairs(group) do
                local key = pin.questID or pin.questTitle
                if not known[key] then
                    known[key] = true
                    entries[#entries + 1] = {title = pin.questTitle, id = pin.questID,
                        ready = pin.ready, active = pin.active}
                end
                if pin ~= lead then
                    pin:Hide()
                    if pin.questID and onMini[pin.questID] then
                        pin.miniVisible = false
                    elseif pin.questID then
                        onMini[pin.questID] = true
                    end
                end
            end
            if #entries > 1 then
                if not rawget(lead, "groupBadge") then
                    lead.groupBadge = lead:CreateFontString(
                        nil, "OVERLAY", "GameFontNormalSmall")
                    lead.groupBadge:SetPoint("TOPRIGHT", lead, "TOPRIGHT", 3, 3)
                    lead.groupBadge:SetTextColor(1, 1, 1)
                    lead.groupBadge:SetShadowColor(0, 0, 0, 1)
                    lead.groupBadge:SetShadowOffset(1, -1)
                end
                lead.groupBadge:SetText(tostring(#entries))
                lead.groupBadge:Show()
                lead.label:SetText(#entries .. " quests")
                lead.groupEntries = entries
                lead:EnableMouse(true)
                lead:SetScript("OnEnter", function(self)
                    if not GameTooltip then return end
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(#self.groupEntries .. " quests")
                    for _, entry in ipairs(self.groupEntries) do
                        GameTooltip:AddLine(entry.title ..
                            (entry.ready and " (ready to turn in)" or ""),
                            entry.active and 0.4 or 1, entry.active and 0.9 or 0.82, 1)
                end
                GameTooltip:AddLine("Click to focus these quests in turn", 0.7, 0.8, 1)
                GameTooltip:Show()
                end)
                lead:SetScript("OnLeave", function()
                    if GameTooltip then GameTooltip:Hide() end
                end)
            else
                lead.groupEntries = nil
                if rawget(lead, "groupBadge") then lead.groupBadge:Hide() end
                if WalkMapExtras.ShowQuestNames() then
                    lead:EnableMouse(false)
                    lead:SetScript("OnEnter", nil)
                    lead:SetScript("OnLeave", nil)
                else
                    lead:EnableMouse(true)
                    lead:SetScript("OnEnter", function(self)
                        if not GameTooltip then return end
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetText(self.questTitle or "Quest")
                        if self.ready then
                            GameTooltip:AddLine("Ready to turn in" .. (self.turnInName
                                and (": " .. self.turnInName) or ""), 1, 0.85, 0.2)
                        end
                        GameTooltip:AddLine("Click to focus this quest", 0.7, 0.8, 1)
                        GameTooltip:Show()
                    end)
                    lead:SetScript("OnLeave", function()
                        if GameTooltip then GameTooltip:Hide() end
                    end)
                end
            end
            -- Click: focus the quest (or step through the quests) at this
            -- marker. Middle-click or Alt-click: waypoint at the marker.
            lead:EnableMouse(true)
            lead:SetScript("OnMouseDown", function(self, button)
                local ids = {}
                if self.groupEntries then
                    for _, entry in ipairs(self.groupEntries) do ids[#ids + 1] = entry.id end
                else
                    ids[1] = self.questID
                end
                viewport.walkmapMarkerClick(self, button, ids, self.questTitle)
            end)
        end
    end


    questSummary =
        count
        .. " quest markers"

end


local function safeRefreshQuests(
    mapID
)

    local ok, message =
        pcall(
            refreshQuests,
            mapID
        )


    if not ok then

        clearQuests()

        questSummary =
            "Could not read quest data"


        if not questWarningShown then

            say(
                "Quest markers: "
                .. tostring(message)
            )

            questWarningShown =
                true

        end

    end

end


-- =========================================================
-- Party
-- =========================================================

local function hidePartyMembers()

    for _, pin
        in ipairs(partyPins)
    do

        pin:Hide()

    end

end


local function createPartyPin(
    index
)

    local pin =
        CreateFrame(
            "Frame",
            nil,
            partyLayer
        )


    pin:SetSize(
        22,
        22
    )


    pin:EnableMouse(false)


    pin.shadow =
        circle(
            pin,
            16,
            "BACKGROUND",
            0,
            0,
            0,
            0.7,
            1,
            -1
        )


    pin.dot =
        circle(
            pin,
            12,
            "ARTWORK",
            0.20,
            0.60,
            1.00,
            1
        )


    pin.name =
        pin:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontHighlightSmall"
        )


    pin.name:SetPoint(
        "TOP",
        pin,
        "BOTTOM",
        0,
        -2
    )


    pin.name:SetTextColor(
        0.65,
        0.85,
        1
    )


    pin.name:SetShadowColor(
        0,
        0,
        0,
        1
    )


    pin.name:SetShadowOffset(
        1,
        -1
    )


    partyPins[index] =
        pin


    return pin

end


local function updatePartyMembers(
    mapID
)

    for i = 1, 4 do

        local unit =
            "party"
            .. i


        local pin =
            partyPins[i]


        if UnitExists(unit) then

            local position =
                C_Map.GetPlayerMapPosition(
                    mapID,
                    unit
                )


            if position then

                local x, y =
                    position:GetXY()


                if x
                    and y
                    and (
                        x > 0
                        or y > 0
                    )
                then

                    if not pin then

                        pin =
                            createPartyPin(
                                i
                            )

                    end


                    pin:ClearAllPoints()


                    pin:SetPoint(
                        "CENTER",
                        canvas,
                        "TOPLEFT",
                        x * canvas:GetWidth(),
                        -y * canvas:GetHeight()
                    )

                    pin.mapPercentX, pin.mapPercentY = x, y


                    local name =
                        UnitName(unit)


                    pin.name:SetText(
                        name
                        or
                        (
                            "Party "
                            .. i
                        )
                    )


                    pin:Show()

                elseif pin then

                    pin:Hide()

                end


            elseif pin then

                pin:Hide()

            end


        elseif pin then

            pin:Hide()

        end

    end

end


-- =========================================================
-- Clear map
-- =========================================================

local function clearMap()

    for _, texture
        in ipairs(textures)
    do

        texture:Hide()

    end


    playerDot:Hide()

    hidePartyMembers()
    if WalkMapFriends then pcall(WalkMapFriends.Hide) end

    clearExploration()

    explorationRefreshAt =
        0


    clearQuests()

    WalkMapExtras.Hide()

    questRefreshAt =
        0

end


-- =========================================================
-- Map layout
-- =========================================================

local function repositionCachedPins()
    local width, height = canvas:GetWidth(), canvas:GetHeight()
    for _, pool in ipairs({questPins, objectivePins, partyPins}) do
        for _, pin in ipairs(pool) do
            if pin:IsShown() and pin.mapPercentX and pin.mapPercentY then
                pin:ClearAllPoints()
                pin:SetPoint("CENTER", canvas, "TOPLEFT",
                    pin.mapPercentX * width, -pin.mapPercentY * height)
                if pool == questPins then
                    pin.mapX, pin.mapY = pin.mapPercentX * width, pin.mapPercentY * height
                end
            end
        end
    end
    if playerDot:IsShown() and playerDot.mapPercentX then
        playerDot:ClearAllPoints()
        playerDot:SetPoint("CENTER", canvas, "TOPLEFT",
            playerDot.mapPercentX * width, -playerDot.mapPercentY * height)
        playerDot.anchorX, playerDot.anchorY = nil, nil
    end
    WalkMapExtras.RepositionPins()
    if WalkMapFriends then pcall(WalkMapFriends.Reposition) end
end

local combatLayoutPending
local function layoutMap(
    requestedMapWidth, duringResize, geometryOnly
)

    if not currentFiles
        or artWidth <= 0
        or artHeight <= 0
    then

        return

    end


    local mapWidth =
        requestedMapWidth
        or viewport:GetWidth()


    mapWidth =
        math.max(
            MIN_MAP_WIDTH,
            math.min(
                MAX_MAP_WIDTH,
                mapWidth
            )
        )

    if duringResize and math.abs(mapWidth - viewport:GetWidth()) < 0.5 then
        return
    end


    local aspect =
        artWidth
        / artHeight


    local mapHeight =
        mapWidth
        / aspect


    local oldWidth, oldHeight = canvas:GetWidth(), canvas:GetHeight()
    local oldViewWidth, oldViewHeight = viewport:GetWidth(), viewport:GetHeight()
    local centerX, centerY
    if zoomOffsetX and oldWidth > 0 and oldHeight > 0 then
        centerX = (oldViewWidth / 2 - zoomOffsetX) / oldWidth
        centerY = (oldViewHeight / 2 + zoomOffsetY) / oldHeight
    end
    local zoom = zoomStops[zoomIndex]
    mapScale = mapWidth * zoom / artWidth


    -- Frame always wraps the map exactly.

    if WalkMapCombat.FrameLocked() then
        combatLayoutPending = true
    else
        frame:SetSize(
            mapWidth + HORIZONTAL_PADDING,
            mapHeight + VERTICAL_PADDING
        )
        combatLayoutPending = false
    end


    viewport:SetSize(mapWidth, mapHeight)
    canvas:SetSize(mapWidth * zoom, mapHeight * zoom)
    zoomOffsetX = mapWidth / 2 - (centerX or 0.5) * canvas:GetWidth()
    zoomOffsetY = (centerY or 0.5) * canvas:GetHeight() - mapHeight / 2
    zoomOffsetX = math.max(mapWidth - canvas:GetWidth(), math.min(0, zoomOffsetX))
    zoomOffsetY = math.max(0, math.min(canvas:GetHeight() - mapHeight, zoomOffsetY))
    canvas:ClearAllPoints()
    canvas:SetPoint("TOPLEFT", viewport, "TOPLEFT", zoomOffsetX, zoomOffsetY)

    -- QuestPOIFrame caches its drawn blob in pixel coordinates. Scale the
    -- cached shapes as the canvas changes, then redraw once after release.
    for _, blob in ipairs(questAreas) do
        if blob:IsShown() and blob.baseWidth and blob.baseWidth > 0 then
            blob:ClearAllPoints()
            blob:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, 0)
            blob:SetSize(blob.baseWidth, blob.baseHeight)
            blob:SetScale(canvas:GetWidth() / blob.baseWidth)
        end
    end

    -- Geometry changes must move every layer in the same UI update. Waiting
    -- for the periodic exploration/quest refresh leaves old-scale art visible.
    repositionCachedPins()
    for _, texture in ipairs(unexploredTextures) do
        if texture:IsShown() and texture.artX then
            texture:ClearAllPoints()
            texture:SetPoint("TOPLEFT", texture.artX * mapScale, -texture.artY * mapScale)
            texture:SetSize(texture.artWidth * mapScale, texture.artHeight * mapScale)
        end
    end
    for _, texture in ipairs(exploredTextures) do
        if texture:IsShown() and texture.artX then
            texture:ClearAllPoints()
            texture:SetPoint("TOPLEFT", texture.artX * mapScale,
                -texture.artY * mapScale)
            texture:SetSize(texture.artWidth * mapScale,
                texture.artHeight * mapScale)
        end
    end

    WalkMapExtras.Resize()
    if updateZoomLabels then updateZoomLabels() end


    local columns =
        math.ceil(
            artWidth
            / mapTileWidth
        )


    for i, file
        in ipairs(currentFiles)
    do

        local x =
            (
                (i - 1)
                % columns
            )
            * mapTileWidth


        local y =
            math.floor(
                (i - 1)
                / columns
            )
            * mapTileHeight


        local tileW =
            math.min(
                mapTileWidth,
                artWidth - x
            )


        local tileH =
            math.min(
                mapTileHeight,
                artHeight - y
            )


        if tileW > 0
            and tileH > 0
        then

            local texture =
                textures[i]


            if not texture then

                texture =
                    canvas:CreateTexture(
                        nil,
                        "ARTWORK"
                    )

                textures[i] =
                    texture

            end


            texture:ClearAllPoints()


            texture:SetPoint(
                "TOPLEFT",
                x * mapScale,
                -y * mapScale
            )


            texture:SetSize(
                tileW * mapScale,
                tileH * mapScale
            )


            local fileChanged = texture.walkmapFile ~= file
            if fileChanged then
                texture:SetTexture(file)
                texture.walkmapFile = file
            end
            if fileChanged or texture.walkmapTileW ~= tileW or texture.walkmapTileH ~= tileH
                or texture.walkmapTextureW ~= mapTileWidth
                or texture.walkmapTextureH ~= mapTileHeight then
                texture:SetTexCoord(0, tileW / mapTileWidth,
                    0, tileH / mapTileHeight)
                texture.walkmapTileW, texture.walkmapTileH = tileW, tileH
                texture.walkmapTextureW, texture.walkmapTextureH = mapTileWidth, mapTileHeight
            end


            texture:SetAlpha(WalkMapExtras.ClearView()
                and explorationTileCount > 0 and 0.09 or 1)
            texture:Show()

        end

    end


    if not duringResize then
        -- Zoom changes geometry, not explored-area data. Avoid hiding and
        -- reloading exploration tiles just because the zoom level changed.
        if not geometryOnly then explorationRefreshAt = 0 end
        questRefreshAt = 0
        WalkMapExtras.Invalidate()
    end

    applyMapAppearance()

end


local function zoomMap(direction, cursorX, cursorY)
    if not currentFiles then return end
    local oldZoom = zoomStops[zoomIndex]
    zoomIndex = math.max(1, math.min(#zoomStops, zoomIndex + direction))
    local newZoom = zoomStops[zoomIndex]
    if oldZoom == newZoom then return end

    local viewW, viewH = viewport:GetWidth(), viewport:GetHeight()
    cursorX = cursorX or viewW / 2
    cursorY = cursorY or viewH / 2
    local factor = newZoom / oldZoom
    local originalX, originalY = zoomOffsetX, zoomOffsetY
    layoutMap(viewW, false, true)
    zoomOffsetX = math.max(viewW - canvas:GetWidth(),
        math.min(0, cursorX - (cursorX - originalX) * factor))
    zoomOffsetY = math.max(0, math.min(canvas:GetHeight() - viewH,
        (cursorY + originalY) * factor - cursorY))
    canvas:ClearAllPoints()
    canvas:SetPoint("TOPLEFT", viewport, "TOPLEFT", zoomOffsetX, zoomOffsetY)
    -- Follow mode must not first show a cursor-centered zoom and then jump
    -- back to the player on the next periodic update.
    if WalkMapExtras.Follow() and WalkMapMiniSource
        and WalkMapMiniSource.UpdatePlayerPosition then
        local ok, message = pcall(WalkMapMiniSource.UpdatePlayerPosition)
        if not ok then WalkMapExtras.DebugEvent("Zoom follow: " .. tostring(message)) end
    end
    saveLayout()
end

local function zoomAroundPointer(direction)
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    local left, top = viewport:GetLeft(), viewport:GetTop()
    if left and top then
        local relativeX, relativeY = x / scale - left, top - y / scale
        if relativeX >= 0 and relativeX <= viewport:GetWidth()
            and relativeY >= 0 and relativeY <= viewport:GetHeight() then
            zoomMap(direction, relativeX, relativeY)
            return
        end
    end
    zoomMap(direction)
end

viewport:EnableMouseWheel(true)
viewport:SetScript("OnMouseWheel", function(_, delta)
    zoomAroundPointer(delta > 0 and 1 or -1)
end)

-- Small, always visible status for the separate QuestieDB addon.
local dbBadge = CreateFrame("Button", nil, frame)
dbBadge:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -36, -2)
dbBadge:SetSize(79, 18)
dbBadge:SetFrameLevel(titleBar:GetFrameLevel() + 3)
dbBadge:EnableMouse(true)
WalkMapExtras.StyleButton(dbBadge)
local dbLabel = dbBadge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
dbLabel:SetPoint("CENTER")
dbLabel:SetText("DB: ...")
-- The title's zone chooser ends where the badge begins, so it gains the room
-- the compact Ready badge frees up.
mapPickerButton:ClearAllPoints()
mapPickerButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 110, -4)
mapPickerButton:SetPoint("TOPRIGHT", dbBadge, "TOPLEFT", -6, -2) -- badge sits 2 px higher
local lastDBPhase, lastDBProgress
local function setDBBadgeWidth(width)
    if math.abs((dbBadge:GetWidth() or 0) - width) < 0.5 then return end
    dbBadge:SetSize(width, 18)
    -- Native D-pad routes are built from button positions.
    if WalkMapNativeController and WalkMapNativeController.RequestRefresh
        and not (InCombatLockdown and InCombatLockdown()) then
        WalkMapNativeController.RequestRefresh()
    end
end
local function updateDBBadge()
    local phase, progress
    if WalkMapLiveDB and WalkMapLiveDB.State then
        phase, progress = WalkMapLiveDB.State()
    end
    phase = phase or "error"
    if phase == lastDBPhase and progress == lastDBProgress then return end
    lastDBPhase, lastDBProgress = phase, progress
    if phase == "ready" then
        -- Compact when all is well; hover still shows full QuestieDB status.
        dbLabel:SetText("DB")
        dbLabel:SetTextColor(0.4, 1, 0.5)
        setDBBadgeWidth(36)
    elseif phase == "loading" then
        dbLabel:SetText("DB: " .. tostring(progress or 0) .. "%")
        dbLabel:SetTextColor(1, 0.82, 0.35)
        setDBBadgeWidth(79)
    elseif phase == "waiting" then
        dbLabel:SetText("DB: Wait")
        dbLabel:SetTextColor(1, 0.82, 0.35)
        setDBBadgeWidth(79)
    else
        dbLabel:SetText("DB: Error")
        dbLabel:SetTextColor(1, 0.45, 0.45)
        setDBBadgeWidth(79)
    end
end
dbBadge:SetScript("OnUpdate", updateDBBadge)
dbBadge:SetScript("OnEnter", function(self)
    if WalkMapJustOpened(self) then return end
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText("QuestieDB")
    GameTooltip:AddLine(WalkMapLiveDB and WalkMapLiveDB.Status()
        or "QuestieDB integration unavailable", 1, 0.85, 0.55, true)
    GameTooltip:AddLine("Click to repeat the status in chat.", 0.7, 0.8, 1)
    GameTooltip:Show()
end)
dbBadge:SetScript("OnLeave", function()
    if GameTooltip then GameTooltip:Hide() end
end)
WalkMapCombat.AllowInCombat(dbBadge)
dbBadge:SetScript("OnClick", function()
    say(WalkMapLiveDB and WalkMapLiveDB.Status()
        or "QuestieDB integration unavailable")
end)

local panning, lastPanX, lastPanY
viewport:SetScript("OnMouseDown", function(_, button)
    -- Right-click on the world or a continent: one map level up
    -- (WalkMap_Levels.lua). Alt-click still sets a waypoint there.
    -- With "Right-click goes a map level up" on, it does so on zone maps too.
    if button == "RightButton" and currentMap and viewport.walkmapUp
        and (WalkMapMaps.IsBroad(currentMap) or WalkMapExtras.RightClickUp())
        and viewport.walkmapUp() then return end
    -- Right-click on the map (not on a marker), middle-click or Alt-click:
    -- waypoint at the cursor. Right-clicking a marker still hides that marker.
    if ((button == "LeftButton" and IsAltKeyDown and IsAltKeyDown()) or button == "RightButton"
        or button == "MiddleButton") and currentMap then
        local cx, cy = GetCursorPosition()
        local scale = canvas:GetEffectiveScale()
        local left, top = canvas:GetLeft(), canvas:GetTop()
        local w, h = canvas:GetWidth(), canvas:GetHeight()
        if left and top and w > 0 and h > 0 then
            local x, y = (cx / scale - left) / w, (top - cy / scale) / h
            if x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                setWaypoint(currentMap, x, y, "Map point")
            end
        end
        return
    end
    if button ~= "LeftButton" then return end
    lastPanX, lastPanY = GetCursorPosition()
    viewport.walkmapDownX, viewport.walkmapDownY = lastPanX, lastPanY
    if zoomIndex == 1 then return end
    panning = true
end)
viewport:SetScript("OnMouseUp", function(_, button)
    panning = false
    -- A plain left-click (no drag) on the world or a continent opens the
    -- continent or zone under the cursor.
    local downX, downY = viewport.walkmapDownX, viewport.walkmapDownY
    viewport.walkmapDownX, viewport.walkmapDownY = nil, nil
    if button ~= "LeftButton" or not downX then return end
    local cx, cy = GetCursorPosition()
    local moved = math.abs(cx - downX) + math.abs(cy - downY)
    if moved > 8 * (UIParent:GetEffectiveScale() or 1) then return end
    viewport.walkmapDrill(viewport.walkmapCursor())
end)
viewport:SetScript("OnHide", function() panning = false end)
viewport:SetScript("OnUpdate", function()
    if not panning then return end
    if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
        panning = false
        return
    end
    local x, y = GetCursorPosition()
    if (x ~= lastPanX or y ~= lastPanY) and WalkMapExtras.Follow() then
        WalkMapExtras.StopFollow()
    end
    local scale = UIParent:GetEffectiveScale()
    zoomOffsetX = math.max(viewport:GetWidth() - canvas:GetWidth(),
        math.min(0, zoomOffsetX + (x - lastPanX) / scale))
    zoomOffsetY = math.max(0, math.min(canvas:GetHeight() - viewport:GetHeight(),
        zoomOffsetY + (y - lastPanY) / scale))
    lastPanX, lastPanY = x, y
    canvas:ClearAllPoints()
    canvas:SetPoint("TOPLEFT", viewport, "TOPLEFT", zoomOffsetX, zoomOffsetY)
end)

local function makeZoomButton(label, right, tooltip, detail, tint)
    local button = CreateFrame("Button", nil, frame)
    button:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", right, UI_LAYOUT.footerButtonBottom)
    button:SetSize(25, 20)
    button:EnableMouse(true)
    WalkMapExtras.StyleButton(button)
    local textLabel = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    textLabel:SetPoint("CENTER")
    textLabel:SetText(label)
    if tint then textLabel:SetTextColor(tint[1], tint[2], tint[3]) end
    button.walkmapLabel = textLabel
    -- Hover and native controller focus both show what the button zooms.
    button:HookScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(tooltip)
        if detail then GameTooltip:AddLine(detail, 0.8, 0.8, 0.8, true) end
        GameTooltip:Show()
    end)
    button:HookScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    return button
end
-- Minimap zoom uses the same blue-green as the active "WalkMap mini" state
-- so the two pairs read as separate groups.
local miniZoomInButton = makeZoomButton("M+", -65, "Zoom minimap in",
    "Zooms WalkMap mini, not the large map.", {0.45, 0.9, 0.85})
local miniZoomOutButton = makeZoomButton("M-", -37, "Zoom minimap out",
    "Zooms WalkMap mini, not the large map.", {0.45, 0.9, 0.85})
local centerButton, resumeButton
-- The large map zooms with LB/RB in map control or the mouse wheel, so the
-- footer keeps only the minimap's M+ / M- buttons.
updateZoomLabels = function()
    local mini = WalkMapExtras.MiniMap()
    local compact = mini and frame:GetWidth() < 480
    for button, offset in pairs({
        [miniZoomInButton] = compact and -57 or -65,
        [miniZoomOutButton] = compact and -29 or -37}) do
        button:ClearAllPoints()
        button:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", offset, UI_LAYOUT.footerButtonBottom)
    end
    miniZoomInButton:SetShown(mini)
    miniZoomOutButton:SetShown(mini)
    if centerButton then
        centerButton:ClearAllPoints()
        centerButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT",
            mini and (compact and -86 or -94) or -37, UI_LAYOUT.footerButtonBottom)
        centerButton:SetSize(compact and 44 or 53, 20)
    end
    local _, view, _, _, _, questButton = WalkMapExtras.ControllerControls()
    if view then view:SetSize(compact and 64 or 86, 19) end
    local width = frame:GetWidth()
    if questButton then questButton:SetSize(width < 480 and 84 or 112, 19) end
    -- At the narrowest sizes the player coordinates would overlap Quests.
    status:SetAlpha((width < 420 or status.walkmapHidden) and 0 or 1)
end
local function clickMiniZoom(direction)
    if WalkMapExtras.MiniMap() then
        if WalkMapExtras.MiniTerrain() == "game" then
            -- Live terrain belongs to the game's Minimap widget. Its zoom
            -- range is controlled by the client, not our zone-art scale.
            local original = _G.Minimap
            if original and original.GetZoom and original.SetZoom then
                local levels = original.GetZoomLevels
                    and original:GetZoomLevels() or 6
                local current = original:GetZoom()
                if type(levels) == "number" and levels > 0
                    and type(current) == "number" then
                    local target = math.max(0, math.min(levels - 1,
                        current + direction))
                    if target ~= current then
                        local ok, message = pcall(original.SetZoom, original, target)
                        if not ok then
                            WalkMapExtras.DebugEvent("Game mini zoom: " .. tostring(message))
                        end
                    end
                end
            end
        else
            WalkMapExtras.AdjustMiniZoom(direction)
        end
    end
end
miniZoomInButton:SetScript("OnClick", function() clickMiniZoom(1) end)
miniZoomOutButton:SetScript("OnClick", function() clickMiniZoom(-1) end)
updateZoomLabels()

centerButton = CreateFrame("Button", nil, frame)
centerButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -37, UI_LAYOUT.footerButtonBottom)
centerButton:SetSize(53, 20)
centerButton:EnableMouse(true)
WalkMapExtras.StyleButton(centerButton)
local centerLabel = centerButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
centerLabel:SetPoint("CENTER")
centerLabel:SetText("Player")
-- The footer no longer shows Player: Follow brings the map back to you, and
-- the zone title's menu has Current zone. The button stays as a hidden
-- action for the controller's map control (Center) and keeps the footer's
-- right-hand slot, where Quests now sits.
centerButton:SetAlpha(0)
centerButton:EnableMouse(false)
centerButton:SetScript("OnShow", function(self) self:Hide() end)
centerButton:Hide()
centerButton:SetScript("OnClick", function()
    WalkMapExtras.ResumeFollow()
    if WalkMapMaps.Selected() then WalkMapMaps.Choose(nil) end
    if not currentMap then return end
    local position = C_Map.GetPlayerMapPosition(currentMap, "player")
    local x, y = 0.5, 0.5
    if position then x, y = position:GetXY() end
    zoomOffsetX = math.max(viewport:GetWidth() - canvas:GetWidth(),
        math.min(0, viewport:GetWidth() / 2 - x * canvas:GetWidth()))
    zoomOffsetY = math.max(0, math.min(canvas:GetHeight() - viewport:GetHeight(),
        y * canvas:GetHeight() - viewport:GetHeight() / 2))
    canvas:ClearAllPoints()
    canvas:SetPoint("TOPLEFT", viewport, "TOPLEFT", zoomOffsetX, zoomOffsetY)
end)

-- =========================================================
-- Custom ratio-locked resizing
-- =========================================================

local resizeStartCursorX = 0
local resizeStartCursorY = 0

local resizeStartWidth = 0
local resizeStartHeight = 0


resizeGrip:SetScript(
    "OnMouseDown",
    function(_, button)

        if WalkMapCombat.FrameLocked() then return end
        if button ~= "LeftButton" then
            return
        end


        if not currentFiles
            or artWidth <= 0
            or artHeight <= 0
        then

            return

        end


        resizing =
            true


        local scale =
            UIParent:GetEffectiveScale()


        local x, y =
            GetCursorPosition()


        resizeStartCursorX =
            x / scale


        resizeStartCursorY =
            y / scale


        resizeStartWidth =
            viewport:GetWidth()


        resizeStartHeight =
            viewport:GetHeight()

    end
)


resizeGrip:SetScript(
    "OnMouseUp",
    function()
        if resizing then
            questRefreshAt = 0
            explorationRefreshAt = 0
            WalkMapExtras.Invalidate()
            elapsed = 0.1
        end
        resizing = false
        saveLayout()

    end
)


resizeGrip:SetScript(
    "OnHide",
    function()
        if resizing then
            questRefreshAt = 0
            explorationRefreshAt = 0
            WalkMapExtras.Invalidate()
        end
        resizing = false

    end
)


resizeGrip:SetScript(
    "OnUpdate",
    function()

        if WalkMapCombat.FrameLocked() then resizing = false; return end
        if not resizing then
            return
        end


        if not currentFiles
            or artWidth <= 0
            or artHeight <= 0
        then

            resizing =
                false

            return

        end


        local scale =
            UIParent:GetEffectiveScale()


        local cursorX, cursorY =
            GetCursorPosition()


        cursorX =
            cursorX / scale


        cursorY =
            cursorY / scale


        -- Moving right makes width larger.

        local deltaX =
            cursorX
            - resizeStartCursorX


        -- Screen Y increases upwards, so dragging down
        -- produces the opposite sign.

        local deltaY =
            resizeStartCursorY
            - cursorY


        local aspect =
            artWidth
            / artHeight


        local widthFromX =
            resizeStartWidth
            + deltaX


        local heightFromY =
            resizeStartHeight
            + deltaY


        local widthFromY =
            heightFromY
            * aspect


        local changeFromX =
            math.abs(
                widthFromX
                - resizeStartWidth
            )


        local changeFromY =
            math.abs(
                widthFromY
                - resizeStartWidth
            )


        local requestedWidth


        if changeFromY > changeFromX then

            requestedWidth =
                widthFromY

        else

            requestedWidth =
                widthFromX

        end


        layoutMap(
            requestedWidth, true
        )

    end
)


-- =========================================================
-- Draw map
-- =========================================================

local function drawMap(
    mapID
)

    clearMap()


    currentMap =
        nil

    currentFiles =
        nil


    local layers =
        C_Map.GetMapArtLayers(
            mapID
        )


    local layer =
        layers
        and layers[1]


    if not layer then

        status:SetText(
            "No map art for this zone yet."
        )

        return

    end


    local files =
        C_Map.GetMapArtLayerTextures(
            mapID,
            1
        )


    if not files
        or #files == 0
    then

        status:SetText(
            "Waiting for map art..."
        )

        return

    end


    local lw =
        layer.layerWidth

    local lh =
        layer.layerHeight

    local tw =
        layer.tileWidth

    local th =
        layer.tileHeight


    if not lw
        or not lh
        or not tw
        or not th
        or lw <= 0
        or lh <= 0
        or tw <= 0
        or th <= 0
    then

        error(
            "Unknown map format in this client (map "
            .. mapID
            .. ")."
        )

    end


    artWidth =
        lw

    artHeight =
        lh


    mapTileWidth =
        tw

    mapTileHeight =
        th


    explorationTileWidth =
        tw

    explorationTileHeight =
        th


    currentFiles =
        files

    currentMap =
        mapID

    zoomOffsetX, zoomOffsetY = nil, nil


    -- Use current map width when changing zones,
    -- but force the new map's correct aspect ratio.

    local wantedWidth = type(settings.mapWidth) == "number"
        and settings.mapWidth >= MIN_MAP_WIDTH and settings.mapWidth <= MAX_MAP_WIDTH
        and settings.mapWidth or viewport:GetWidth()


    if not wantedWidth
        or wantedWidth <= 0
    then

        wantedWidth =
            DEFAULT_WIDTH
            - HORIZONTAL_PADDING

    end


    layoutMap(
        wantedWidth
    )


    local info =
        C_Map.GetMapInfo(
            mapID
        )


    local zoneName = info and info.name or tostring(mapID)
    title:SetText(
        "WalkMap - " .. zoneName
        .. (WalkMapExtras.ZoneLevelText and WalkMapExtras.ZoneLevelText(zoneName) or "")
    )

end


-- =========================================================
-- Update
-- =========================================================

local function snapMapPixel(value)
    local scale = viewport:GetEffectiveScale()
    if type(scale) ~= "number" or scale <= 0 then return value end
    return math.floor(value * scale + 0.5) / scale
end

local positionBoundsMap, positionWorldX, positionWorldY
local positionWorldDX, positionWorldDY, positionInstance
local positionBoundsRetryAt = 0

local function readPlayerPosition(mapID)
    local position = C_Map.GetPlayerMapPosition(mapID, "player")
    if not position then return nil end
    local mapX, mapY = position:GetXY()
    if not mapX or not mapY or not UnitPosition
        or not C_Map.GetWorldPosFromMapPos then return mapX, mapY end

    -- Zone coordinates can arrive in coarse steps. World coordinates, when
    -- provided by the client, update at the player's actual movement rate.
    -- Keep zone coordinates as a fallback for beta zones without a world map.
    local ok, preciseX, preciseY = pcall(function()
        if positionBoundsMap ~= mapID
            or (not positionInstance and GetTime() >= positionBoundsRetryAt) then
            positionBoundsMap = mapID
            positionInstance = nil
            positionBoundsRetryAt = GetTime() + 2
            local a = CreateVector2D and CreateVector2D(0, 0) or {x=0,y=0}
            local b = CreateVector2D and CreateVector2D(1, 1) or {x=1,y=1}
            local idA, top = C_Map.GetWorldPosFromMapPos(mapID, a)
            local idB, bottom = C_Map.GetWorldPosFromMapPos(mapID, b)
            if idA and idA == idB and top and bottom then
                local ax, ay, bx, by
                if top.GetXY then ax, ay = top:GetXY() else ax, ay = top.x, top.y end
                if bottom.GetXY then bx, by = bottom:GetXY()
                else bx, by = bottom.x, bottom.y end
                if ax and ay and bx and by and ax ~= bx and ay ~= by then
                    positionInstance = idA
                    positionWorldX, positionWorldY = ax, ay
                    positionWorldDX, positionWorldDY = bx-ax, by-ay
                end
            end
        end
        if not positionInstance then return nil end
        local worldX, worldY, _, instance = UnitPosition("player")
        if not worldX or not worldY or instance ~= positionInstance then return nil end
        local x = (worldY - positionWorldY) / positionWorldDY
        local y = (worldX - positionWorldX) / positionWorldDX
        if math.abs(x - mapX) > 0.03 or math.abs(y - mapY) > 0.03 then
            return nil
        end
        return x, y
    end)
    if ok and preciseX and preciseY then return preciseX, preciseY end
    return mapX, mapY
end

local nearestBadge = CreateFrame("Frame", nil, frame)
nearestBadge:SetSize(325, 23)
nearestBadge:SetPoint("BOTTOMLEFT", viewport, "BOTTOMLEFT", 7, 7)
nearestBadge:EnableMouse(false)
local nearestBackground = nearestBadge:CreateTexture(nil, "BACKGROUND")
nearestBackground:SetAllPoints(nearestBadge)
nearestBackground:SetColorTexture(0.07, 0.05, 0.03, 0.88)
local nearestText = nearestBadge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
nearestText:SetPoint("LEFT", nearestBadge, "LEFT", 6, 0)
nearestText:SetWidth(312)
nearestText:SetJustifyH("LEFT")
nearestBadge:Hide()
local nextNearestAt, nearestQuest, nearestZone = 0, nil, nil

-- =========================================================
-- Waypoint: one saved target per character. Set it from a selected marker
-- in map control (A) or Alt-click on the map; right-click the star to clear.
-- =========================================================
local WAYPOINT_ART = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"
local waypointPin = CreateFrame("Frame", nil, canvas)
local miniWaypoints
waypointPin:SetSize(22, 22)
waypointPin:SetFrameLevel(canvas:GetFrameLevel() + 5)
waypointPin:EnableMouse(true)
waypointPin.icon = waypointPin:CreateTexture(nil, "OVERLAY")
waypointPin.icon:SetAllPoints(waypointPin)
waypointPin.icon:SetTexture(WAYPOINT_ART)
waypointPin.walkmapWaypoint = true
waypointPin:Hide()

local function positionWaypoint()
    local waypoint = WalkMapExtras.Waypoint()
    if not waypoint or waypoint.mapID ~= currentMap or not currentFiles then
        waypointPin:Hide()
        return
    end
    local px, py = waypoint.x * canvas:GetWidth(), -waypoint.y * canvas:GetHeight()
    if waypointPin.px ~= px or waypointPin.py ~= py then
        waypointPin:ClearAllPoints()
        waypointPin:SetPoint("CENTER", canvas, "TOPLEFT", px, py)
        waypointPin.px, waypointPin.py = px, py
    end
    waypointPin.mapPercentX, waypointPin.mapPercentY = waypoint.x, waypoint.y
    waypointPin.pinName = waypoint.label
    waypointPin:Show()
end

setWaypoint = function(mapID, x, y, label)
    if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then return end
    WalkMapExtras.SetWaypoint({mapID = mapID, x = x, y = y,
        label = tostring(label or "Waypoint"):sub(1, 40)})
    waypointPin.px = nil
    positionWaypoint()
    say(string.format("Waypoint set: %s (%.1f, %.1f). Right-click the star (or A on it in map control) to clear it.",
        tostring(label or "Waypoint"), x * 100, y * 100))
end

-- Other WalkMap files (turn-in waypoint) set the waypoint through this.
WalkMapWaypoint = {Set = function(mapID, x, y, label) setWaypoint(mapID, x, y, label) end}

local function clearWaypoint(message)
    if not WalkMapExtras.Waypoint() then return end
    WalkMapExtras.SetWaypoint(nil)
    waypointPin:Hide()
    nearestBadge:Hide()
    nextNearestAt = 0
    if message then say(message) end
end

-- The quests a quest or objective marker stands for (nil for other pins).
function viewport.walkmapPinQuests(pin)
    if not pin then return nil end
    local ids = {}
    for _, item in ipairs(pin.entries or {}) do ids[#ids + 1] = item.questID end
    for _, entry in ipairs(pin.groupEntries or {}) do ids[#ids + 1] = entry.id end
    if #ids == 0 and type(pin.questID) == "number" then ids[1] = pin.questID end
    return #ids > 0 and ids or nil
end

-- A in map control: on the waypoint's star (within its size) A clears it;
-- on a quest marker (the one the cross shows the tooltip of) A focuses that
-- quest, as a click would; anywhere else it sets a waypoint.
local function padWaypointAt(x, y)
    local waypoint = WalkMapExtras.Waypoint()
    if waypoint and waypoint.mapID == currentMap then
        local dx = (x - waypoint.x) * canvas:GetWidth()
        local dy = (y - waypoint.y) * canvas:GetHeight()
        if dx * dx + dy * dy <= 16 * 16 then
            clearWaypoint("Waypoint cleared.")
            return
        end
    end
    -- (the cross is declared further down; WalkMapCore.crosshair is it)
    local cross = WalkMapCore and WalkMapCore.crosshair
    local hover = cross and cross.walkmapHoverPin and cross.walkmapHoverPin()
    local quests = viewport.walkmapPinQuests(hover)
    if quests then
        if GameTooltip then GameTooltip:Hide() end
        viewport.walkmapFocusClick(quests)
        return
    end
    setWaypoint(currentMap, x, y, "Map point")
end
WalkMapWaypoint.PadAt = function(x, y) padWaypointAt(x, y) end

waypointPin:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Waypoint")
    GameTooltip:AddLine(tostring(self.pinName or ""), 1, 0.9, 0.65)
    GameTooltip:AddLine("Right-click to clear. In map control: Y to select, A to clear.", 0.7, 0.8, 1, true)
    GameTooltip:Show()
end)
waypointPin:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
waypointPin:SetScript("OnMouseDown", function(_, button)
    if button == "RightButton" then
        if GameTooltip then GameTooltip:Hide() end
        clearWaypoint("Waypoint cleared.")
    end
end)

-- Focus waypoint: while a quest is focused, a purple diamond on the minimaps
-- marks where to go for it - the nearest unfinished objective, or the
-- turn-in once it is ready. It is separate from the star waypoint, stays on
-- the minimap's edge when out of range, and is gone when the focus is.
-- Settings > Minimap > Focus waypoint (on by default).
local FOCUS_ART = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3"
local focusCache = {}
local function focusTarget(mapID)
    local questID = trackedQuestID()
    if type(mapID) ~= "number" or type(questID) ~= "number" or questID <= 0
        or not (WalkMapExtras.FocusWaypoint and WalkMapExtras.FocusWaypoint()) then
        return nil
    end
    local now = GetTime and GetTime() or 0
    if focusCache.quest == questID and focusCache.map == mapID and now < (focusCache.expires or 0) then
        return focusCache.x, focusCache.y, focusCache.label, focusCache.detail
    end
    -- Candidates in 0-1 map coordinates: {x, y, detail}.
    local candidates = {}
    local ready = isQuestReady(questID)
    if ready then
        local spots = WalkMapLiveDB and WalkMapLiveDB.TurnIn and WalkMapLiveDB.TurnIn(questID)
        for _, point in ipairs(type(spots) == "table" and spots[mapID] or {}) do
            candidates[#candidates + 1] = {point[1] / 100, point[2] / 100, "Turn in" .. (point[3] and (": " .. tostring(point[3])) or "")}
        end
    else
        local questData = WalkMapLiveDB and WalkMapLiveDB.Objective(questID)
            or (WalkMapObjectives and WalkMapObjectives[questID])
        local points = questData and questData[2] and questData[2][mapID]
        if points then
            local objectives
            if C_QuestLog.GetQuestObjectives then
                local ok, progress = pcall(C_QuestLog.GetQuestObjectives, questID)
                if ok and type(progress) == "table" then objectives = progress end
            end
            for _, point in ipairs(points) do
                local label = questData[1] and questData[1][point[3]]
                local _, finished = objectiveProgress(objectives, label, point[3], point[4])
                if not finished then
                    candidates[#candidates + 1] = {point[1] / 100, point[2] / 100, label}
                end
            end
        end
    end
    -- No database location here: the game's own quest marker on this map,
    -- then the game's next waypoint for the quest.
    if #candidates == 0 and C_QuestLog.GetQuestsOnMap then
        local ok, quests = pcall(C_QuestLog.GetQuestsOnMap, mapID)
        for _, quest in ipairs(ok and type(quests) == "table" and quests or {}) do
            if quest.questID == questID and type(quest.x) == "number" and type(quest.y) == "number" then
                candidates[#candidates + 1] = {quest.x, quest.y, ready and "Turn in" or nil}
            end
        end
    end
    if #candidates == 0 and WalkMapQuestInfo and WalkMapQuestInfo.NextWaypoint then
        local nextMap, x, y = WalkMapQuestInfo.NextWaypoint(questID)
        if nextMap == mapID then candidates[1] = {x, y, ready and "Turn in" or nil} end
    end
    local best
    local px, py
    local ok, position = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
    if ok and position then
        local valid, x, y = pcall(position.GetXY, position)
        if valid and type(x) == "number" and type(y) == "number" then px, py = x, y end
    end
    local bestDistance
    for _, candidate in ipairs(candidates) do
        local distance = px and ((candidate[1] - px) ^ 2 + (candidate[2] - py) ^ 2) or 0
        if not bestDistance or distance < bestDistance then best, bestDistance = candidate, distance end
    end
    local title = C_QuestLog.GetTitleForQuestID and select(2, pcall(C_QuestLog.GetTitleForQuestID, questID))
    if type(title) ~= "string" or title == "" then title = "Quest " .. questID end
    focusCache.quest, focusCache.map, focusCache.expires = questID, mapID, now + 1
    if best then
        focusCache.x, focusCache.y = best[1], best[2]
        focusCache.label = "Focus: " .. title
        focusCache.detail = best[3] and tostring(best[3]) or nil
    else
        focusCache.x, focusCache.y, focusCache.label, focusCache.detail = nil, nil, nil, nil
    end
    return focusCache.x, focusCache.y, focusCache.label, focusCache.detail
end
WalkMapFocusWaypoint = {Target = focusTarget, Reset = function() focusCache.expires = 0 end}

-- Minimaps draw the waypoint for the zone they show (the live player zone).
do
local waypointMini = {walkmapWaypoint = true, miniArt = WAYPOINT_ART, miniVisible = true}
local corpseMini = {walkmapCorpse = true, miniVisible = true}
local focusMini = {walkmapFocusWaypoint = true, miniArt = FOCUS_ART, miniVisible = true}
miniWaypoints = function(mapID)
    local list = {}
    local fx, fy, label, detail = focusTarget(mapID)
    if fx and fy then
        focusMini.mapPercentX, focusMini.mapPercentY, focusMini.pinName = fx, fy, label
        focusMini.detail = detail
        list[#list + 1] = focusMini
    end
    local waypoint = WalkMapExtras.Waypoint()
    if waypoint and waypoint.mapID == mapID then
        waypointMini.mapPercentX, waypointMini.mapPercentY = waypoint.x, waypoint.y
        list[#list + 1] = waypointMini
    end
    -- Your corpse while dead or a ghost (skull, kept at the minimap edge).
    local cx, cy
    if WalkMapCorpse and WalkMapCorpse.Position then cx, cy = WalkMapCorpse.Position(mapID) end
    if cx and cy then
        corpseMini.miniArt = WalkMapCorpse.ART
        corpseMini.mapPercentX, corpseMini.mapPercentY = cx, cy
        list[#list + 1] = corpseMini
    end
    return list
end
end

-- Corpse pin on the big map (all maps the game can place it on).
do
local corpsePin = CreateFrame("Frame", nil, canvas)
corpsePin:SetSize(22, 22)
corpsePin:SetFrameLevel(canvas:GetFrameLevel() + 6)
corpsePin:EnableMouse(true)
corpsePin.icon = corpsePin:CreateTexture(nil, "OVERLAY")
corpsePin.icon:SetAllPoints(corpsePin)
corpsePin.icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
corpsePin:Hide()
corpsePin:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Your corpse")
    GameTooltip:AddLine("Shown until you are alive again.", 0.7, 0.8, 1, true)
    GameTooltip:Show()
end)
corpsePin:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
-- WalkMap_Corpse.lua loads after this file and fills in the same table.
WalkMapCorpse = WalkMapCorpse or {}
do
    WalkMapCorpse.PositionPin = function()
        local x, y
        if currentMap and currentFiles and WalkMapCorpse.Position then
            x, y = WalkMapCorpse.Position(currentMap)
        end
        if not x or not y then corpsePin:Hide() return end
        corpsePin:ClearAllPoints()
        corpsePin:SetPoint("CENTER", canvas, "TOPLEFT", x * canvas:GetWidth(), -y * canvas:GetHeight())
        corpsePin.mapPercentX, corpsePin.mapPercentY = x, y
        corpsePin:Show()
    end
end
end

local showWaypointDirection
do
-- Distance in yards when the client can convert map to world positions.
local function worldDistance(mapID, x1, y1, x2, y2)
    if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
    local ok, distance = pcall(function()
        local _, a = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x1, y1))
        local _, b = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x2, y2))
        if not a or not b then return nil end
        local ax, ay = a:GetXY()
        local bx, by = b:GetXY()
        return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
    end)
    return ok and distance or nil
end

local function compassDirection(dx, dy)
    local northSouth = dy < -0.01 and "N" or dy > 0.01 and "S" or ""
    local eastWest = dx > 0.01 and "E" or dx < -0.01 and "W" or ""
    local direction = northSouth .. eastWest
    return direction ~= "" and direction or "here"
end

-- Returns true when the badge now shows the corpse or the waypoint.
showWaypointDirection = function(mapID, x, y)
    -- While dead or a ghost the badge points to your corpse first.
    local cx, cy
    if WalkMapCorpse and WalkMapCorpse.Position and frame:IsShown() and x and y then
        cx, cy = WalkMapCorpse.Position(mapID)
    end
    if cx and cy then
        local dx, dy = cx - x, cy - y
        local yards = worldDistance(mapID, x, y, cx, cy)
        local distance = yards and string.format("%.0f yd", yards)
            or string.format("~%.0f%% map width", math.sqrt(dx * dx + dy * dy) * 100)
        nearestText:SetText(string.format("|cffff6666Corpse:|r  %s  %s", compassDirection(dx, dy), distance))
        nearestBadge:Show()
        return true
    end
    local waypoint = WalkMapExtras.Waypoint()
    if not frame:IsShown() or not waypoint or waypoint.mapID ~= mapID or not x or not y then
        return false
    end
    local dx, dy = waypoint.x - x, waypoint.y - y
    local yards = worldDistance(mapID, x, y, waypoint.x, waypoint.y)
    if (yards and yards < 8) or (not yards and dx * dx + dy * dy < 0.004 ^ 2) then
        clearWaypoint("Waypoint reached.")
        return false
    end
    local distance = yards and string.format("%.0f yd", yards)
        or string.format("~%.0f%% map width", math.sqrt(dx * dx + dy * dy) * 100)
    nearestText:SetText(string.format("|cffffd24dWaypoint:|r %s  %s  %s",
        tostring(waypoint.label or ""):sub(1, 24), compassDirection(dx, dy), distance))
    nearestBadge:Show()
    return true
end
end

-- Quest log > Show on map: a pulsing gold ring around every marker of that
-- quest on the large map (QuestieDB icons and the game's quest markers,
-- including the turn-in), until the log closes or another quest is chosen.
do
WalkMapPinHighlight = {}
local highlight = WalkMapPinHighlight
local highlightID, phase = nil, 0
local RING = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local driver = CreateFrame("Frame", nil, frame)
driver:Hide()
local function relevant(pin)
    if pin.questID == highlightID then return true end
    for _, entry in ipairs(pin.entries or {}) do
        if entry.questID == highlightID then return true end
    end
    return false
end
local function paint(alpha)
    for _, pool in ipairs({questPins, mainObjectivePins}) do
        for _, pin in ipairs(pool) do
            local ring = rawget(pin, "walkmapPulse")
            if highlightID and pin:IsShown() and relevant(pin) then
                if not ring then
                    ring = pin:CreateTexture(nil, "BACKGROUND", nil, -7)
                    ring:SetTexture(RING)
                    ring:SetPoint("CENTER", pin, "CENTER")
                    ring:SetVertexColor(1, 0.85, 0.25)
                    pin.walkmapPulse = ring
                end
                local size = math.max(pin:GetWidth() or 0, 14) * (1.9 + 0.25 * alpha)
                ring:SetSize(size, size)
                ring:SetAlpha(0.25 + 0.6 * alpha)
                ring:Show()
            elseif ring then
                ring:Hide()
            end
        end
    end
end
function highlight.Clear()
    if not highlightID then return end
    highlightID = nil
    paint(0)
    driver:Hide()
end
function highlight.Set(questID)
    if type(questID) ~= "number" then return highlight.Clear() end
    highlightID, phase = questID, 0
    driver:Show()
end
function highlight.Active() return highlightID end
driver:SetScript("OnUpdate", function(_, elapsed)
    local log = WalkMapQuestLog
    -- Ends when the log closes or another quest is selected there.
    if not frame:IsShown() or not (log and log.IsOpen and log.IsOpen())
        or (log.SelectedID and log.SelectedID() ~= highlightID) then
        highlight.Clear()
        return
    end
    phase = phase + elapsed * 4
    paint((math.sin(phase) + 1) / 2)
end)
end


-- Map control crosshair with the coordinates under it.
local crosshair
do
crosshair = CreateFrame("Frame", nil, viewport)
crosshair:SetAllPoints(viewport)
crosshair:SetFrameLevel(viewport:GetFrameLevel() + 30)
crosshair:EnableMouse(false)
-- The cross itself sits on a 1 px mark that can leave the middle of the
-- view: when the map cannot scroll any further (zoomed all the way out, or
-- at an edge), the D-pad moves the cross instead of the map.
local mark = CreateFrame("Frame", nil, crosshair)
mark:SetSize(1, 1)
mark:SetPoint("CENTER", crosshair, "CENTER", 0, 0)
crosshair.walkmapX, crosshair.walkmapY = 0, 0
-- Offset from the middle of the view in pixels: right and up are positive.
crosshair.walkmapPlace = function(x, y)
    local limitX = math.max(0, viewport:GetWidth() / 2 - 10)
    local limitY = math.max(0, viewport:GetHeight() / 2 - 10)
    x = math.max(-limitX, math.min(limitX, x or 0))
    y = math.max(-limitY, math.min(limitY, y or 0))
    crosshair.walkmapX, crosshair.walkmapY = x, y
    mark:ClearAllPoints()
    mark:SetPoint("CENTER", crosshair, "CENTER", x, y)
end
for _, size in ipairs({{14, 2}, {2, 14}}) do
    local shade = crosshair:CreateTexture(nil, "OVERLAY", nil, 1)
    shade:SetSize(size[1] + 2, size[2] + 2)
    shade:SetPoint("CENTER", mark, "CENTER")
    shade:SetColorTexture(0, 0, 0, 0.6)
    local line = crosshair:CreateTexture(nil, "OVERLAY", nil, 2)
    line:SetSize(size[1], size[2])
    line:SetPoint("CENTER", mark, "CENTER")
    line:SetColorTexture(1, 0.85, 0.3, 0.95)
end
local crosshairText = crosshair:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
crosshairText:SetPoint("TOP", mark, "CENTER", 0, -11)
crosshairText:SetTextColor(1, 0.85, 0.35)
crosshairText:SetShadowColor(0, 0, 0, 1)
crosshairText:SetShadowOffset(1, -1)
crosshair:Hide()
-- The map position under the cross (0-1 across and down the map).
local function viewCenter()
    local cw, ch = canvas:GetWidth(), canvas:GetHeight()
    if not cw or cw <= 0 or not ch or ch <= 0 then return nil end
    local ox, oy = crosshair.walkmapX or 0, crosshair.walkmapY or 0
    if zoomOffsetX and zoomOffsetY then
        return (-zoomOffsetX + viewport:GetWidth() / 2 + ox) / cw,
            (zoomOffsetY + viewport:GetHeight() / 2 - oy) / ch
    end
    -- Not zoomed: read it off the frames.
    local vx, vy = viewport:GetCenter()
    local left, top = canvas:GetLeft(), canvas:GetTop()
    if not vx or not vy or not left or not top then return nil end
    return (vx + ox - left) / cw, (top - (vy + oy)) / ch
end
-- Map control's A uses the crosshair position for a waypoint.
crosshair.ViewCenter = viewCenter

-- What the cross is over shows its tooltip, as the mouse would: the marker
-- under the cross (closest to its middle) gets OnEnter, and OnLeave when the
-- cross moves off. Not while Y steps through markers (that shows its own).
-- crosshair.walkmapHoverPins and walkmapBrowsing are set further down.
local hoverPin, hoverAt = nil, 0
local function leaveHover()
    if not hoverPin then return end
    local leave = hoverPin:GetScript("OnLeave")
    hoverPin = nil
    if leave then pcall(leave) end
end
crosshair.walkmapLeaveHover = leaveHover
crosshair:HookScript("OnHide", leaveHover)
local function updateHover(elapsed)
    hoverAt = hoverAt - (elapsed or 0)
    if hoverAt > 0 then return end
    hoverAt = 0.1
    if crosshair.walkmapBrowsing and crosshair.walkmapBrowsing() then
        hoverPin = nil
        return
    end
    local mx, my = mark:GetCenter()
    local found, best
    if mx and crosshair.walkmapHoverPins then
        for _, pin in ipairs(crosshair.walkmapHoverPins()) do
            local left, right = pin:GetLeft(), pin:GetRight()
            local top, bottom = pin:GetTop(), pin:GetBottom()
            if left and top and mx >= left - 3 and mx <= right + 3 and my <= top + 3 and my >= bottom - 3 then
                local cx, cy = pin:GetCenter()
                local d = (cx - mx) ^ 2 + (cy - my) ^ 2
                if not best or d < best then found, best = pin, d end
            end
        end
    end
    if found == hoverPin then return end
    leaveHover()
    if found then
        hoverPin = found
        local enter = found:GetScript("OnEnter")
        if enter then pcall(enter, found) end
    end
end
crosshair.walkmapHoverPin = function() return hoverPin end

crosshair:SetScript("OnUpdate", function(_, elapsed)
    -- Carry out queued D-pad movement a little each frame (see walkmapGlide).
    if crosshair.walkmapGlide then crosshair.walkmapGlide(elapsed) end
    updateHover(elapsed)
    local x, y = viewCenter()
    if not x then return end
    local child = viewport.walkmapChildAt(x, y)
    if child and child.name then
        -- Just the name: the hint line at the top already says what A does.
        crosshairText:SetText(viewport.walkmapChildText(child))
    else
        crosshairText:SetText(string.format("%.1f, %.1f", x * 100, y * 100))
    end
end)
end

local function updateNearestObjective(mapID, x, y)
    if showWaypointDirection(mapID, x, y) then return end
    if not frame:IsShown() or not WalkMapExtras.NearestObjective()
        or not x or not y or artWidth <= 0 or artHeight <= 0 then
        nearestBadge:Hide()
        return
    end
    local questID = trackedQuestID()
    if type(questID) ~= "number" or questID <= 0 then
        nearestBadge:Hide()
        return
    end
    local now = GetTime()
    if now < nextNearestAt and questID == nearestQuest and mapID == nearestZone then
        return
    end
    nextNearestAt, nearestQuest, nearestZone = now + 0.5, questID, mapID
    local candidates = {}
    if WalkMapExtras.ObjectiveIcons() then
        for _, pin in ipairs(miniObjectivePins) do
            if pin.questID == questID then
                candidates[#candidates + 1] = {pin.mapPercentX,
                    pin.mapPercentY, pin.objectiveName}
            end
        end
    else
        -- Allow the navigator without drawing quest icons.
        local data = WalkMapLiveDB and WalkMapLiveDB.Objective(questID)
            or WalkMapObjectives and WalkMapObjectives[questID]
        local points = data and data[2] and data[2][mapID]
        local objectives
        if points and C_QuestLog and C_QuestLog.GetQuestObjectives then
            local ok, result = pcall(C_QuestLog.GetQuestObjectives, questID)
            if ok then objectives = result end
        end
        if points and not isQuestReady(questID) then
            for _, point in ipairs(points) do
                if type(point[1]) == "number" and type(point[2]) == "number" then
                    local label = data[1] and data[1][point[3]]
                    local _, finished = objectiveProgress(objectives, label,
                        point[3], point[4])
                    local key = WalkMapExtras.MarkerKey("objective", mapID,
                        tostring(questID) .. ":" .. tostring(point[3]) .. ":"
                        .. tostring(point[4]) .. ":" .. tostring(point[6] or ""),
                        point[1], point[2])
                    if not finished and not WalkMapExtras.MarkerHidden(key) then
                        candidates[#candidates + 1] = {point[1] / 100,
                            point[2] / 100, label}
                    end
                end
            end
        end
    end
    local nearest, bestDistance
    for _, candidate in ipairs(candidates) do
        local dx, dy = candidate[1] - x, candidate[2] - y
        local dist = dx * dx + dy * dy * (artHeight / artWidth) ^ 2
        if not bestDistance or dist < bestDistance then
            bestDistance, nearest = dist, candidate
        end
    end
    if not nearest then
        nearestText:SetText("Focused quest: no known location in this zone")
    else
        local dx, dy = nearest[1] - x, nearest[2] - y
        local northSouth = dy < -0.025 and "N" or dy > 0.025 and "S" or ""
        local eastWest = dx > 0.025 and "E" or dx < -0.025 and "W" or ""
        local direction = northSouth .. eastWest
        if direction == "" then direction = "nearby" end
        local name = tostring(nearest[3] or "objective"):sub(1, 27)
        nearestText:SetText(string.format("Nearest known: %s  %s  ~%.0f%% map width",
            name, direction, math.sqrt(bestDistance) * 100))
    end
    nearestBadge:Show()
end

local function updatePlayerPosition(mapID)
    positionWaypoint()
    if WalkMapCorpse and WalkMapCorpse.PositionPin then WalkMapCorpse.PositionPin() end
    local x, y
    if not WalkMapMaps.Selected() or mapID == WalkMapMaps.CurrentZone()
        or (WalkMapMaps.IsBroad and WalkMapMaps.IsBroad(mapID)) then x, y = readPlayerPosition(mapID) end

    if x and y then

        local following = WalkMapExtras.Follow() and zoomIndex > 1
        if following then
            local nextX = math.max(viewport:GetWidth() - canvas:GetWidth(),
                math.min(0, snapMapPixel(viewport:GetWidth() / 2 - x * canvas:GetWidth())))
            local nextY = math.max(0, math.min(canvas:GetHeight() - viewport:GetHeight(),
                snapMapPixel(y * canvas:GetHeight() - viewport:GetHeight() / 2)))
            if nextX ~= zoomOffsetX or nextY ~= zoomOffsetY then
                zoomOffsetX, zoomOffsetY = nextX, nextY
                canvas:ClearAllPoints()
                canvas:SetPoint("TOPLEFT", viewport, "TOPLEFT", nextX, nextY)
            end
        end

        local dotX, dotY = x * canvas:GetWidth(), -y * canvas:GetHeight()
        if following then
            dotX, dotY = snapMapPixel(dotX), snapMapPixel(dotY)
        end
        if dotX ~= playerDot.anchorX or dotY ~= playerDot.anchorY then
            playerDot:ClearAllPoints()
            playerDot:SetPoint("CENTER", canvas, "TOPLEFT", dotX, dotY)
            playerDot.anchorX, playerDot.anchorY = dotX, dotY
        end
        playerDot.mapPercentX, playerDot.mapPercentY = x, y


        local facing =
            GetPlayerFacing
            and GetPlayerFacing()


        playerDot:SetRotation(
            facing or 0
        )


        playerDot:Show()


        status:SetText(
            string.format(
                "%.1f, %.1f",
                x * 100,
                y * 100
            )
        )

        local nearestOK, nearestError = pcall(updateNearestObjective, mapID, x, y)
        if not nearestOK then
            nearestBadge:Hide()
            WalkMapExtras.DebugEvent("Nearest objective: " .. tostring(nearestError))
        end


    else

        playerDot:Hide()


        status:SetText(
            "Position unavailable."
        )

        nearestBadge:Hide()

    end

end

local function playerIsOnMap(mapID)
    if not mapID then return false end
    local ok, position = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
    if not ok or not position then return false end
    local valid, x, y = pcall(position.GetXY, position)
    return valid and type(x) == "number" and type(y) == "number"
        and x >= 0 and x <= 1 and y >= 0 and y <= 1
end

local function mapHasArt(mapID)
    if not mapID then return false end
    local ok, layers = pcall(C_Map.GetMapArtLayers, mapID)
    if not ok or not layers or not layers[1] then return false end
    local filesOK, files = pcall(C_Map.GetMapArtLayerTextures, mapID, 1)
    return filesOK and files and #files > 0
end

local observedMap, observedFocus
local function update()

    local mapID = WalkMapMaps.CurrentZone()

    local focused = trackedQuestID()
    if focused ~= observedFocus then
        WalkMapExtras.DebugEvent("Focus quest " .. tostring(observedFocus or 0)
            .. " -> " .. tostring(focused or 0))
        observedFocus = focused
    end
    if mapID ~= observedMap then
        WalkMapExtras.DebugEvent("Game zone " .. tostring(observedMap or "none")
            .. " -> " .. tostring(mapID or "none"))
        observedMap = mapID
    end

    -- Supertracking can briefly point this beta's best-map lookup at a map
    -- without local player coordinates or artwork. Keep the current zone map
    -- while the player is still there, independent of the focused quest.
    if not WalkMapMaps.Selected() and mapID ~= currentMap and currentMap and playerIsOnMap(currentMap)
        and (not playerIsOnMap(mapID) or not mapHasArt(mapID)) then
        WalkMapExtras.DebugEvent("Using zone " .. currentMap
            .. " while game zone " .. tostring(mapID or "none") .. " lacks local art")
        mapID = currentMap
    end
    mapID = WalkMapMaps.Selected() or mapID


    if not mapID then

        clearMap()
        nearestBadge:Hide()

        currentMap =
            nil


        title:SetText(
            "WalkMap"
        )


        status:SetText(
            "No map data here."
        )

        return

    end


    if mapID ~= currentMap then

        drawMap(
            mapID
        )

    end


    if not currentMap then
        nearestBadge:Hide()
        return
    end


    if not resizing and GetTime()
        >= explorationRefreshAt
    then

        safeRefreshExploration(
            mapID
        )

        explorationRefreshAt =
            GetTime()
            + 5

    end


    if not resizing and GetTime()
        >= questRefreshAt
    then

        safeRefreshQuests(
            mapID
        )

        questRefreshAt =
            GetTime()
            + 2

    end

    applyMapAppearance()

    if not resizing then
        local placesOK, placesError = pcall(WalkMapExtras.Refresh, mapID)
        if not placesOK then
            WalkMapExtras.DebugEvent("Place refresh: " .. tostring(placesError))
        end
    end


    local partyOK, partyError = pcall(updatePartyMembers, mapID)
    if not partyOK then
        hidePartyMembers()
        WalkMapExtras.DebugEvent("Party update: " .. tostring(partyError))
    end

    if WalkMapFriends and not resizing then
        local friendsOK, friendsError = pcall(WalkMapFriends.Refresh, mapID)
        if not friendsOK then
            pcall(WalkMapFriends.Hide)
            WalkMapExtras.DebugEvent("Friends update: " .. tostring(friendsError))
        end
    end

    local positionOK, positionError = pcall(updatePlayerPosition, mapID)
    if not positionOK then
        playerDot:Hide()
        nearestBadge:Hide()
        WalkMapExtras.DebugEvent("Player position: " .. tostring(positionError))
    end

end


local lastUpdateError, lastUpdateErrorAt
local function safeUpdate()

    local ok, message =
        pcall(
            update
        )


    if not ok then

        WalkMapExtras.DebugEvent("Zone update error: " .. tostring(message))

        local now = GetTime and GetTime() or 0
        if message ~= lastUpdateError or not lastUpdateErrorAt
            or now - lastUpdateErrorAt > 10 then
            say("Map update error: " .. tostring(message)
                .. " (see /walkmap debug)")
            lastUpdateError, lastUpdateErrorAt = message, now
        end

    end

    return ok

end

-- A read-only snapshot for the optional, unprotected minimap preview.
-- It shares the full map's filtering and avoids a second quest database pass.
local liveMini
local function liveMiniScene()
    local id = WalkMapMaps.CurrentZone()
    if not WalkMapMaps.Selected() or id == currentMap then return end
    if not liveMini then
        local hidden = CreateFrame("Frame", nil, UIParent)
        hidden:EnableMouse(false)
        hidden:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
        hidden:Hide()
        liveMini = {canvas = hidden, tiles = {}, explored = {}, quests = {}, objectives = {},
            miniObjectives = {}, areas = {}, party = {}, empty = {}, nextAt = 0}
        liveMini.partyLayer = CreateFrame("Frame", nil, hidden)
        liveMini.partyLayer:SetAllPoints(hidden)
        liveMini.dot = CreateFrame("Frame", nil, hidden)
    end
    local scene, now = liveMini, GetTime()
    if scene.map ~= id or not scene.files then
        local layers = id and C_Map.GetMapArtLayers(id)
        local layer = layers and layers[1]
        local files = layer and C_Map.GetMapArtLayerTextures(id, 1)
        if not layer or not files or #files == 0
            or type(layer.layerWidth) ~= "number" or layer.layerWidth <= 0
            or type(layer.layerHeight) ~= "number" or layer.layerHeight <= 0
            or type(layer.tileWidth) ~= "number" or layer.tileWidth <= 0
            or type(layer.tileHeight) ~= "number" or layer.tileHeight <= 0 then
            scene.map, scene.files = id, nil;return scene
        end
        scene.map, scene.files, scene.w, scene.h = id, files, layer.layerWidth, layer.layerHeight
        scene.tw, scene.th = layer.tileWidth, layer.tileHeight
        scene.canvas:SetSize(scene.w, scene.h)
        scene.nextAt = 0
        scene.exploreAt = 0
        local columns = math.ceil(scene.w / scene.tw)
        for i, file in ipairs(files) do
            local texture = scene.tiles[i]
            if not texture then texture = scene.canvas:CreateTexture(nil, "ARTWORK");scene.tiles[i] = texture end
            texture:SetTexture(file)
            texture:SetPoint("TOPLEFT", (i - 1) % columns * scene.tw, -math.floor((i - 1) / columns) * scene.th)
            texture:Show()
        end
        for i = #files + 1, #scene.tiles do scene.tiles[i]:Hide() end
    end
    if now >= scene.nextAt or scene.focus ~= trackedQuestID() or scene.revision ~= WalkMapExtras.Revision() then
        -- Only these rendering pools and geometry belong to the hidden live
        -- scene. Restore every reference even if a helper raises an error.
        local old = {canvas = canvas, w = artWidth, h = artHeight, scale = mapScale,
            ew = explorationTileWidth, eh = explorationTileHeight, explored = exploredTextures,
            count = explorationTileCount, applied = appliedTileCount, ewarn = explorationWarningShown,
            quests = questPins, objectives = objectivePins, mini = miniObjectivePins, areas = questAreas,
            unavailable = questAreasUnavailable, summary = questSummary, qwarn = questWarningShown,
            party = partyPins, partyLayer = partyLayer}
        canvas, artWidth, artHeight, mapScale = scene.canvas, scene.w, scene.h, 1
        explorationTileWidth, explorationTileHeight, exploredTextures = scene.tw, scene.th, scene.explored
        explorationTileCount = scene.explorationCount or 0
        questPins, objectivePins, miniObjectivePins, questAreas = scene.quests, scene.objectives, scene.miniObjectives, scene.areas
        questAreasUnavailable, questWarningShown, explorationWarningShown = scene.unavailable, scene.qwarn, scene.ewarn
        partyPins, partyLayer = scene.party, scene.partyLayer
        local ok, message = pcall(function()
            if not scene.exploreAt or now >= scene.exploreAt then
                safeRefreshExploration(id)
                scene.explorationCount, scene.exploreAt = explorationTileCount, now + 5
            end
            safeRefreshQuests(id)
            updatePartyMembers(id)
            local alpha = WalkMapExtras.ClearView() and explorationTileCount > 0 and 0.09 or 1
            for _, texture in ipairs(scene.tiles) do texture:SetAlpha(alpha) end
            for _, texture in ipairs(scene.explored) do texture:SetAlpha(1) end
        end)
        scene.unavailable, scene.qwarn, scene.ewarn = questAreasUnavailable, questWarningShown, explorationWarningShown
        canvas, artWidth, artHeight, mapScale = old.canvas, old.w, old.h, old.scale
        explorationTileWidth, explorationTileHeight, exploredTextures = old.ew, old.eh, old.explored
        explorationTileCount, appliedTileCount, explorationWarningShown = old.count, old.applied, old.ewarn
        questPins, objectivePins, miniObjectivePins, questAreas = old.quests, old.objectives, old.mini, old.areas
        questAreasUnavailable, questSummary, questWarningShown = old.unavailable, old.summary, old.qwarn
        partyPins, partyLayer = old.party, old.partyLayer
        if not ok then WalkMapExtras.DebugEvent("Live minimap scene: " .. tostring(message)) end
        scene.nextAt, scene.focus, scene.revision = now + 2, trackedQuestID(), WalkMapExtras.Revision()
    end
    local x, y = readPlayerPosition(id)
    scene.dot.mapPercentX, scene.dot.mapPercentY = x, y
    if x and y then scene.dot:Show() else scene.dot:Hide() end
    return scene
end

WalkMapMiniSource = {
    Refresh = safeUpdate,
    Snapshot = function()
        local scene = liveMiniScene()
        if scene then
            if not scene.files then return scene.map, nil, 0, 0, nil, nil,
                scene.empty, scene.empty, scene.empty, scene.empty, scene.empty, scene.empty, scene.dot end
            return scene.map, scene.files, scene.w or 0, scene.h or 0, scene.tw, scene.th,
                scene.tiles, scene.explored, scene.quests, scene.objectives, scene.party, scene.areas, scene.dot
        end
        return currentMap, currentFiles, artWidth, artHeight,
            mapTileWidth, mapTileHeight, textures, exploredTextures,
            questPins, objectivePins, partyPins, questAreas, playerDot
    end,
    FocusedQuestID = trackedQuestID,
    MiniWaypoints = function()
        local scene = liveMiniScene()
        return miniWaypoints(scene and scene.map or currentMap)
    end,
    MiniPins = function()
        local scene = liveMiniScene()
        if scene then
            if not scene.files then return scene.empty, scene.empty end
            return scene.quests, scene.miniObjectives
        end
        return questPins, miniObjectivePins
    end,
    MiniServices = function()
        local scene = liveMiniScene()
        if scene then
            if not scene.files then return scene.empty, scene.empty, scene.empty end
            return WalkMapExtras.RefreshMini(scene.map, scene.canvas)
        end
        return WalkMapExtras.MiniMapPins()
    end,
    IsFullMapShown = function() return frame:IsShown() end,
    UpdatePlayerPosition = function()
        if liveMiniScene() then return end
        if currentMap then updatePlayerPosition(currentMap) end
    end,
    ReadPlayerPosition = readPlayerPosition,
}
WalkMapMaps.Init(function()
    currentMap, currentFiles = nil, nil
    questRefreshAt, explorationRefreshAt, elapsed = 0, 0, 0.1
    if frame:IsShown() then safeUpdate() end
end)

local updatePadMode
WalkMapExtras.Init(frame, canvas, function()
    questRefreshAt = 0
    updateZoomLabels()
    if updatePadMode then updatePadMode() end
    if frame:IsShown() then safeUpdate() end
end)

-- An opt-in navigation layer for WalkMap's own unprotected controls. Do not
-- alter the beta's protected frame focus or global gamepad bindings.
local padHint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
padHint:SetPoint("BOTTOM", frame, "BOTTOM", 0, 8)
padHint:SetText("D-pad: navigate   A: choose   X: pan   Y: pins   Select: skills")
padHint:SetTextColor(1, 0.82, 0.35)
padHint:Hide()

resumeButton = CreateFrame("Button", nil, frame)
resumeButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, UI_LAYOUT.footerButtonBottom)
resumeButton:SetSize(175, 19)
resumeButton:EnableMouse(true)
WalkMapExtras.StyleButton(resumeButton)
local resumeLabel = resumeButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
resumeLabel:SetPoint("CENTER")
resumeLabel:SetText("Resume controller navigation")
resumeButton:Hide()

local focusTarget, focusIndex, lastPadButton
local padSuspended, padPanning = false, false
local function markFocus(target)
    if focusTarget and focusTarget.walkmapFocusArt then
        for _, edge in ipairs(focusTarget.walkmapFocusArt) do edge:Hide() end
    end
    focusTarget = target
    if not target then return end
    if not target.walkmapFocusArt then
        target.walkmapFocusArt = {}
        for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
            local edge = target:CreateTexture(nil, "OVERLAY")
            if side == "TOP" or side == "BOTTOM" then
                edge:SetPoint(side .. "LEFT", target, side .. "LEFT", 0, 0)
                edge:SetPoint(side .. "RIGHT", target, side .. "RIGHT", 0, 0)
                edge:SetHeight(2)
            else
                edge:SetPoint("TOP" .. side, target, "TOP" .. side, 0, 0)
                edge:SetPoint("BOTTOM" .. side, target, "BOTTOM" .. side, 0, 0)
                edge:SetWidth(2)
            end
            edge:SetColorTexture(1, 0.85, 0.35, 1)
            target.walkmapFocusArt[#target.walkmapFocusArt + 1] = edge
        end
    end
    for _, edge in ipairs(target.walkmapFocusArt) do edge:Show() end
end

local padToggle, padCheck
local function navigationRows()
    local top, view, _, _, _, questButton = WalkMapExtras.ControllerControls()
    if not top then return {} end
    return {{padToggle, mapPickerButton, dbBadge, closeButton},
        (function()
            local row = {top[1], top[2], top[3], top[4]}
            local social = WalkMapFriends and WalkMapFriends.Tab and WalkMapFriends.Tab()
            if social then row[#row + 1] = social end
            local log = WalkMapQuestLog and WalkMapQuestLog.Tab and WalkMapQuestLog.Tab()
            if log then row[#row + 1] = log end
            return row
        end)(),
        WalkMapSimpleButton and {view, WalkMapSimpleButton, questButton, resumeButton, centerButton,
            miniZoomInButton, miniZoomOutButton}
            or {view, questButton, resumeButton, centerButton, miniZoomInButton, miniZoomOutButton}}
end

local function padTargets()
    local targets = {}
    for _, row in ipairs(navigationRows()) do
        for _, target in ipairs(row) do
            if target:IsShown() then targets[#targets + 1] = target end
        end
    end
    return targets
end

local function padMenu()
    local _, _, menu, submenu, settingsPanel = WalkMapExtras.ControllerControls()
    if settingsPanel and settingsPanel:IsShown() then
        return settingsPanel, submenu
    end
    if menu and menu:IsShown() then return menu, submenu end
end

-- Browse visible map markers with Y, without creating focus textures for
-- every pin. The one outline follows the currently selected marker.
local padPinMode, padPinIndex, selectedPin = false, 0, nil
local pinOutline = CreateFrame("Frame", nil, canvas)
pinOutline:SetFrameLevel(canvas:GetFrameLevel() + 6)
pinOutline:EnableMouse(false)
for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
    local border = pinOutline:CreateTexture(nil, "OVERLAY")
    border:SetColorTexture(1, 0.85, 0.25, 1)
    if side == "TOP" or side == "BOTTOM" then
        border:SetPoint(side .. "LEFT", pinOutline, side .. "LEFT", 0, 0)
        border:SetPoint(side .. "RIGHT", pinOutline, side .. "RIGHT", 0, 0)
        border:SetHeight(2)
    else
        border:SetPoint("TOP" .. side, pinOutline, "TOP" .. side, 0, 0)
        border:SetPoint("BOTTOM" .. side, pinOutline, "BOTTOM" .. side, 0, 0)
        border:SetWidth(2)
    end
end
pinOutline:Hide()

local function closePinDetails()
    if selectedPin then
        local leave = selectedPin:GetScript("OnLeave")
        if leave then pcall(leave, selectedPin) end
    end
    if GameTooltip then GameTooltip:Hide() end
end

local markerCycle, markerIndex = nil, 0
local function clearMarkerSelection()
    closePinDetails()
    markerCycle, markerIndex, selectedPin = nil, 0, nil
    pinOutline:Hide()
    if WalkMapNativeController and WalkMapNativeController.SetPanHint then
        WalkMapNativeController.SetPanHint(nil)
    end
end

local function exitPinMode()
    closePinDetails()
    selectedPin, padPinIndex, padPinMode = nil, 0, false
    pinOutline:Hide()
    padHint:SetText("D-pad: navigate   A: choose   X: pan   Y: pins   Select: skills")
    if not padSuspended and not (WalkMapNativeController
        and WalkMapNativeController.OwnsInput()) then
        markFocus(padTargets()[focusIndex or 1])
    end
end

local visiblePins
crosshair.walkmapBrowsing = function() return markerCycle ~= nil end
crosshair.walkmapHoverPins = function() return visiblePins and visiblePins() or {} end
visiblePins = function()
    local list = {}
    local left, right, top, bottom = viewport:GetLeft(), viewport:GetRight(),
        viewport:GetTop(), viewport:GetBottom()
    if not left or not right or not top or not bottom then return list end
    local services, givers, resources, rares = WalkMapExtras.MiniMapPins()
    local social = WalkMapFriends and WalkMapFriends.Pins and WalkMapFriends.Pins() or {}
    for _, pool in ipairs({{waypointPin}, objectivePins, questPins, services, givers, resources,
        rares or {}, social}) do
        for _, pin in ipairs(pool) do
            if pin:IsShown() then
                local x, y = pin:GetCenter()
                if x and y and x >= left and x <= right
                    and y >= bottom and y <= top then
                    list[#list + 1] = pin
                end
            end
        end
    end
    table.sort(list, function(a, b)
        local ax, ay = a:GetCenter()
        local bx, by = b:GetCenter()
        local rowA, rowB = math.floor(ay / 12), math.floor(by / 12)
        if rowA ~= rowB then return rowA > rowB end
        return ax < bx
    end)
    return list
end

local function selectPadPin(direction)
    local list = visiblePins()
    if #list == 0 then exitPinMode() return false end
    local previousIndex = 0
    for index, pin in ipairs(list) do
        if pin == selectedPin then previousIndex = index break end
    end
    closePinDetails()
    padPinIndex = (previousIndex - 1 + direction + #list) % #list + 1
    selectedPin = list[padPinIndex]
    markFocus(nil)
    pinOutline:ClearAllPoints()
    pinOutline:SetPoint("TOPLEFT", selectedPin, "TOPLEFT", -2, 2)
    pinOutline:SetPoint("BOTTOMRIGHT", selectedPin, "BOTTOMRIGHT", 2, -2)
    pinOutline:Show()
    padHint:SetText("Pin " .. padPinIndex .. "/" .. #list
        .. "   D-pad: next   A: details   X: hide   B/Y: back")
    return true
end

local function padMoveBase(button)
    local targets = padTargets()
    if #targets == 0 then return end
    local direction = ({PADDLEFT = "left", PADDRIGHT = "right", PADDUP = "up", PADDDOWN = "down"})[button]
    local target = WalkMapNavigation.Step(navigationRows(), focusTarget or targets[1], direction)
    for i, item in ipairs(targets) do if item == target then focusIndex = i break end end
    markFocus(target)
end

local function padMoveRow(delta)
    local menu, submenu = padMenu()
    if not menu then return false end
    local panel = submenu:IsShown() and submenu or menu
    if panel.categories and panel.options then
        local route = WalkMapNavigation.Settings(panel)[focusTarget]
        local nextTarget = route and route[delta > 0 and "down" or "up"]
        -- At the first/last row of a list that can scroll: scroll instead.
        if nextTarget == focusTarget and panel.walkmapScroll then
            panel.walkmapScroll(focusTarget, delta > 0 and "down" or "up")
            markFocus(focusTarget)
        elseif nextTarget and nextTarget ~= true then markFocus(nextTarget) end
        return true
    end
    local rows = {}
    local candidates = panel.rows
    for _, row in ipairs(candidates) do
        if row:IsShown() then rows[#rows + 1] = row end
    end
    if #rows == 0 then return true end
    local current = 0
    for i, row in ipairs(rows) do
        if row == focusTarget then current = i break end
    end
    local nextRow = current == 0 and (delta > 0 and 1 or #rows)
        or math.max(1, math.min(#rows, current + delta))
    markFocus(rows[nextRow])
    return true
end

local function padActivate(target)
    if not target then return end
    local click = target:GetScript("OnClick")
    if click then click(target, "LeftButton") end
    if not WalkMapExtras.ControllerMode() then return end
    local menu, submenu = padMenu()
    if menu then
        if submenu:IsShown() then
            if target == submenu.parentRow then markFocus(submenu.rows[1]) end
        elseif target ~= menu.from then
            if target == focusTarget then markFocus(target) end
        else
            markFocus(menu.rows[1])
        end
    else
        markFocus(padTargets()[focusIndex or 1])
    end
end

-- Map control's D-pad. dx/dy say which way the map slides (+1, 0, -1), as
-- before: dx = 1 slides the map right, so the cross travels left over it.
-- The map scrolls while it can. Where it cannot (zoomed all the way out, or
-- at an edge) the cross moves across the view instead, and it returns to
-- the middle before the map starts scrolling the other way.
local function padPan(dx, dy)
    local viewW, viewH = viewport:GetWidth(), viewport:GetHeight()
    local ox, oy = crosshair.walkmapX or 0, crosshair.walkmapY or 0
    -- How far the cross should travel over the map, in view pixels
    -- (right and up positive), at the cross's finer step.
    local wantX, wantY = -dx * viewW * 0.07, dy * -viewH * 0.07
    local function towardCentre(offset, want)
        -- A cross that is off-centre comes back first.
        if offset ~= 0 and want ~= 0 and (offset > 0) ~= (want > 0) then
            local back = math.min(math.abs(offset), math.abs(want)) * (want > 0 and 1 or -1)
            return offset + back, want - back
        end
        return offset, want
    end
    ox, wantX = towardCentre(ox, wantX)
    oy, wantY = towardCentre(oy, wantY)
    if zoomIndex ~= 1 and zoomOffsetX and zoomOffsetY then
        WalkMapExtras.StopFollow()
        -- The rest scrolls the map, at the map's own coarser step.
        local scale = 0.13 / 0.07
        local nextX = math.max(viewW - canvas:GetWidth(), math.min(0, zoomOffsetX - wantX * scale))
        local nextY = math.max(0, math.min(canvas:GetHeight() - viewH, zoomOffsetY - wantY * scale))
        wantX = wantX - (zoomOffsetX - nextX) / scale
        wantY = wantY - (zoomOffsetY - nextY) / scale
        if nextX ~= zoomOffsetX or nextY ~= zoomOffsetY then
            zoomOffsetX, zoomOffsetY = nextX, nextY
            canvas:ClearAllPoints()
            canvas:SetPoint("TOPLEFT", viewport, "TOPLEFT", zoomOffsetX, zoomOffsetY)
        end
    end
    -- What the map could not scroll moves the cross.
    crosshair.walkmapPlace(ox + wantX, oy + wantY)
end

-- Smooth, precise map control. A D-pad press reaches us as one event when
-- it goes down, and then as repeats a few times a second while it is held
-- (uneven, with a longer wait before the first repeat). Moving one step per
-- event made the map jerk. Instead:
--   * a press nudges the cross a tiny bit (about 2 px): tap for precision;
--   * while the direction is held, the cross's OnUpdate moves it every
--     frame, slowly at first and then faster.
-- "Held" comes from the controller itself when the client lets us read it
-- (C_GamePad): which button belongs to a direction is learned from the first
-- press, by looking at what is down when the event arrives. Without that,
-- held means "repeats keep arriving", which starts later and stops a moment
-- after release.
do
    local NUDGE = 0.03                   -- of a padPan step, per press
    local SLOW, FAST = 1.2, 9            -- steps per second
    local SLOW_FOR, FAST_AT = 0.3, 1.5   -- seconds held
    local keys = {}                      -- per direction: dx, dy, last, count, held, button
    local function now() return GetTime and GetTime() or 0 end
    local function buttonsDown()
        local pad = C_GamePad
        if not (pad and pad.GetActiveDeviceID and pad.GetDeviceMappedState) then return nil end
        local ok, id = pcall(pad.GetActiveDeviceID)
        if not ok or id == nil then return nil end
        local ok2, state = pcall(pad.GetDeviceMappedState, id)
        if ok2 and type(state) == "table" and type(state.buttons) == "table" then return state.buttons end
        return nil
    end
    local function reset()
        for _, key in pairs(keys) do key.last, key.count, key.held = -100, 0, 0 end
    end
    crosshair.walkmapStop = reset
    -- A D-pad event from map control: dx/dy as padPan takes them.
    crosshair.walkmapQueue = function(dx, dy)
        dx, dy = dx or 0, dy or 0
        local name = dx .. "," .. dy
        local key = keys[name]
        if not key then
            key = {dx = dx, dy = dy, last = -100, count = 0, held = 0}
            keys[name] = key
        end
        local time = now()
        if time - key.last > 0.9 then key.count = 0 end
        key.count, key.last = key.count + 1, time
        -- Learn which controller button this direction is: the one button
        -- that is down right now.
        if not key.button then
            local down, found, several = buttonsDown(), nil, false
            for index, pressed in pairs(down or {}) do
                if pressed == true then
                    if found then several = true end
                    found = index
                end
            end
            if found and not several then key.button = found end
        end
        -- A fresh press: the precise nudge.
        if key.held == 0 then padPan(dx * NUDGE, dy * NUDGE) end
    end
    crosshair.walkmapGlide = function(elapsed)
        elapsed = math.max(0, math.min(0.1, elapsed or 0))
        local time, down = now(), nil
        local moveX, moveY = 0, 0
        for _, key in pairs(keys) do
            local since, strength = time - key.last, 0
            if key.button then
                -- Read from the controller; the repeats only prove it is
                -- still this direction (they stop when it is released).
                down = down or buttonsDown() or {}
                if down[key.button] == true and since < 2 then strength = 1 end
            elseif key.count >= 2 and since < 0.45 then
                -- No controller state: glide between repeats, easing out
                -- when they stop coming.
                strength = since < 0.3 and 1 or (0.45 - since) / 0.15
                if key.held == 0 then key.held = SLOW_FOR end
            end
            if strength > 0 then
                key.held = key.held + elapsed
                local speed = SLOW
                if key.held > SLOW_FOR then
                    speed = SLOW + (FAST - SLOW) * math.min(1, (key.held - SLOW_FOR) / (FAST_AT - SLOW_FOR))
                end
                moveX = moveX + key.dx * speed * strength * elapsed
                moveY = moveY + key.dy * speed * strength * elapsed
            else
                key.held = 0
            end
        end
        if moveX ~= 0 or moveY ~= 0 then padPan(moveX, moveY) end
    end
end

updatePadMode = function()
    -- The combat transition already released native and raw controller input.
    -- Keep protected input APIs out of the persistent frame's OnHide callbacks.
    if WalkMapCombat.Passive() or WalkMapCombat.Locked() then return end
    local controllerMode = WalkMapExtras.ControllerMode()
    if padToggle then
        local checked = controllerMode
        padToggle:SetChecked(checked)
        if checked then padCheck:Show() else padCheck:Hide() end
    end
    local enabled = frame:IsShown() and controllerMode
    local nativeActive = WalkMapNativeController and WalkMapNativeController.Update()
    -- Native map released by Select: it is out of the game's window list
    -- until Select takes it back, so the custom fallback must stay paused.
    if enabled and not nativeActive and WalkMapExtras.MapReleased() and WalkMapNativeController
        and WalkMapNativeController.UsesNativeNavigation() then
        padSuspended = true
    end
    if frame.EnableGamePadButton then
        frame:EnableGamePadButton(enabled and not nativeActive and not padSuspended)
    end
    if enabled and nativeActive then
        -- Native View/Select focus belongs to the game, not the custom pause flag.
        -- X now enters direct map control, so the native footer no longer
        -- needs a Controls button; keep the coordinates in their usual place.
        padSuspended = false
        status:Show()
        padHint:Hide()
        markFocus(nil)
        resumeButton:Hide()
        updateZoomLabels()
        return
    end
    resumeButton:ClearAllPoints()
    resumeButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, UI_LAYOUT.footerButtonBottom)
    resumeButton:SetSize(175, 19)
    resumeLabel:SetText("Resume controller navigation")
    if enabled then
        status:Hide()
        if padSuspended and WalkMapExtras.MapReleased() then
            -- "Select keeps the map released": Select takes the map back,
            -- so no Resume button; the footer shows the coordinates.
            padHint:Hide()
            resumeButton:Hide()
            status:Show()
            markFocus(nil)
        elseif padSuspended then
            padHint:Hide()
            resumeButton:Show()
            markFocus(nil)
        else
            resumeButton:Hide()
            padHint:Show()
            if not padPanning and not padPinMode then
                padHint:SetText("D-pad: navigate   A: choose   X: pan   Y: pins   Select: skills")
            end
            if not padPinMode and (not focusTarget or not focusTarget:IsShown()) then
                focusIndex = focusIndex or 1
                markFocus(padTargets()[focusIndex])
            end
        end
    else
        padHint:Hide()
        resumeButton:Hide()
        status:Show()
        markFocus(nil)
        padSuspended, padPanning = false, false
    end
end

resumeButton:SetScript("OnClick", function()
    -- Only the custom fallback shows this button now ("Resume controller
    -- navigation"); native mode hides it.
    padSuspended = false
    WalkMapExtras.SetMapReleased(false)
    updatePadMode()
end)
-- Keep the persistent controller choice visible without opening View options.
padToggle = CreateFrame("CheckButton", nil, frame)
padToggle:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -5)
padToggle:SetSize(94, 18)
padToggle:SetFrameLevel(titleBar:GetFrameLevel() + 3)
padToggle:EnableMouse(true)
padToggle.walkmapPadToggle = true
if padToggle.EnableGamePadButton then padToggle:EnableGamePadButton(false) end
local padBox = padToggle:CreateTexture(nil, "ARTWORK")
padBox:SetPoint("LEFT", padToggle, "LEFT", 0, 0)
padBox:SetSize(18, 18)
padBox:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
padCheck = padToggle:CreateTexture(nil, "OVERLAY")
padCheck:SetAllPoints(padBox)
padCheck:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
local padLabel = padToggle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
padLabel:SetPoint("LEFT", padBox, "RIGHT", 2, 0)
padLabel:SetText("Pad focus")
padToggle:SetScript("OnClick", function()
    if GameTooltip and GameTooltip.GetOwner
        and GameTooltip:GetOwner() == padToggle then GameTooltip:Hide() end
    WalkMapExtras.Command("pad", WalkMapExtras.ControllerMode() and "off" or "on")
end)
updatePadMode()
frame:SetScript("OnShow", function()
    mapOpenedAt = GetTime and GetTime() or 0
    -- "Select keeps the map released": stay paused if Select released it.
    padSuspended = WalkMapExtras.MapReleased()
    updatePadMode()
    -- After an update, the first map open shows What's new once.
    if WalkMapExtras.MapOpened then WalkMapExtras.MapOpened() end
end)
frame:SetScript("OnHide", function()
    if GameTooltip and GameTooltip.GetOwner
        and GameTooltip:GetOwner() == padToggle then GameTooltip:Hide() end
    WalkMapExtras.CloseMenus()
    if padPinMode then exitPinMode() end
    updatePadMode()
    -- Closing the map forgets the zone you browsed to, so the next time it
    -- opens it shows where you are (and Follow centres on you again).
    if WalkMapExtras.ResumeFollow then WalkMapExtras.ResumeFollow() end
    if WalkMapMaps.Selected() then WalkMapMaps.Choose(nil) end
end)
local lastFocusToggleAt
function WalkMap_ToggleControllerFocus()
    if not frame:IsShown() then return end
    -- One gamepad press can reach both the binding and OnGamePadButtonDown.
    local now = GetTime and GetTime()
    if now and lastFocusToggleAt and now >= lastFocusToggleAt
        and now - lastFocusToggleAt < 0.15 then return end
    lastFocusToggleAt = now
    if padPinMode then exitPinMode() end
    padSuspended = false
    padPanning = false
    WalkMapExtras.CloseMenus()
    WalkMapExtras.Command("pad", WalkMapExtras.ControllerMode() and "off" or "on")
    updatePadMode()
end
frame:SetScript("OnGamePadButtonDown", function(_, button)
    if WalkMapCombat.Passive() or WalkMapCombat.Locked() then return end
    if WalkMapNativeController and WalkMapNativeController.OwnsInput() then return end
    if not frame:IsShown() or not WalkMapExtras.ControllerMode() then return end
    if WalkMapNativeController and WalkMapNativeController.UsesNativeNavigation() then
        -- The native API can become ready after this custom handler was enabled.
        -- Try the handover before letting a legacy Select press pause anything.
        updatePadMode()
        if WalkMapNativeController.OwnsInput() then return end
    end
    lastPadButton = button
    if button == "PADSOCIAL" or button == "PADBACK" then
        if padPinMode then exitPinMode() end
        padSuspended = not padSuspended
        WalkMapExtras.SetMapReleased(padSuspended)
        padPanning = false
        WalkMapExtras.CloseMenus()
        updatePadMode()
        return
    end
    if padSuspended then return end
    local menu, submenu = padMenu()
    if button == "PAD4" and not menu then
        if padPinMode then exitPinMode()
        else
            padPinMode = true
            padPanning = false
            selectedPin = nil
            if not selectPadPin(1) then say("No visible markers to inspect.") end
        end
        return
    end
    if padPinMode then
        if button == "PAD2" then exitPinMode()
        elseif button == "PAD1" then
            local enter = selectedPin and selectedPin:GetScript("OnEnter")
            if enter then pcall(enter, selectedPin) end
        elseif button == "PAD3" then
            local hide = selectedPin and selectedPin:GetScript("OnMouseDown")
            if hide then
                pcall(hide, selectedPin, "RightButton")
                selectedPin = nil
                selectPadPin(1)
            end
        elseif button == "PADDLEFT" or button == "PADDUP" then selectPadPin(-1)
        elseif button == "PADDRIGHT" or button == "PADDDOWN" then selectPadPin(1)
        elseif button == "PADLSHOULDER" or button == "PADRSHOULDER" then
            exitPinMode()
            zoomMap(button == "PADLSHOULDER" and -1 or 1)
        end
        return
    end
    if button == "PADLSHOULDER" then
        -- Map control, already zoomed all the way out: one map level up.
        if not (padPanning and viewport.walkmapZoomUp and viewport.walkmapZoomUp(-1)) then zoomMap(-1) end
        return
    end
    if button == "PADRSHOULDER" then zoomMap(1) return end
    if button == "PAD3" and not menu then
        padPanning = not padPanning
        if padPanning then
            padHint:SetText("D-pad: pan    A: open/waypoint    B: back    Select: skills")
            markFocus(viewport)
        else
            padHint:SetText("D-pad: navigate   A: choose   X: pan   Y: pins   Select: skills")
            markFocus(padTargets()[focusIndex or 1])
        end
        return
    end
    if button == "PAD2" then
        if menu and submenu:IsShown() then
            submenu:Hide()
            markFocus(submenu.parentRow)
        elseif menu then
            menu:Hide()
            markFocus(menu.from)
        elseif padPanning then
            padPanning = false
            WalkMapExtras.ResumeFollow()
            padHint:SetText("D-pad: navigate   A: choose   X: pan   Y: pins   Select: skills")
            markFocus(padTargets()[focusIndex or 1])
        else
            frame:Hide()
        end
        return
    end
    if button == "PAD1" then
        if padPanning then
            -- Waypoint at the crosshair, like native map control.
            local x, y = crosshair.ViewCenter()
            if viewport.walkmapDrill(x, y) then
                crosshair.walkmapPlace(0, 0)
                return
            end
            if currentMap and x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                padWaypointAt(x, y)
            end
        else padActivate(focusTarget) end
        return
    end
    if button == "PADDUP" or button == "PADDDOWN" then
        local direction = button == "PADDUP" and -1 or 1
        if menu then padMoveRow(direction)
        elseif padPanning then padPan(0, direction)
        else padMoveBase(button) end
    elseif button == "PADDLEFT" or button == "PADDRIGHT" then
        local direction = button == "PADDLEFT" and -1 or 1
        if menu and menu.categories then
            local route = WalkMapNavigation.Settings(menu)[focusTarget]
            local nextTarget = route and route[direction < 0 and "left" or "right"]
            if nextTarget and nextTarget ~= true then markFocus(nextTarget) end
        elseif menu and submenu:IsShown() and direction < 0 then
            submenu:Hide()
            markFocus(submenu.parentRow)
        elseif menu and direction > 0 and focusTarget
            and focusTarget.walkmapOpensSubmenu then
            padActivate(focusTarget)
        elseif menu and direction < 0 then
            menu:Hide()
            markFocus(menu.from)
        elseif menu then return
        elseif padPanning then padPan(-direction, 0)
        else padMoveBase(button) end
    end
end)

-- The native backend only registers this standalone window and its popups.
-- WALKMAP_TOGGLE remains independent from the game's normal map binding.
WalkMapNativeController.Init(frame, {
    NavigationRows = navigationRows,
    Viewport = viewport,
    Changed = function() if updatePadMode then updatePadMode() end end,
    -- Map control's LB/RB. LB when already zoomed all the way out goes one
    -- map level up (WalkMap_Levels.lua).
    Zoom = function(direction)
        if viewport.walkmapZoomUp and viewport.walkmapZoomUp(direction) then
            crosshair.walkmapPlace(0, 0)
            return
        end
        zoomMap(direction)
    end,
    Center = function()
        local click = centerButton:GetScript("OnClick")
        if click then click(centerButton, "LeftButton") end
    end,
    Pan = function(dx, dy)
        if markerCycle then clearMarkerSelection() end
        -- A nudge now; the cross's OnUpdate keeps it moving while held.
        crosshair.walkmapQueue(dx, dy)
    end,
    -- Map control: Y steps through the markers around the cross, nearest
    -- first: only those within a circle of a fifth of the view (at least
    -- 60 px) around it, at most 12. Move the cross to browse elsewhere.
    NextMarker = function()
        if not markerCycle then
            local all = visiblePins()
            local cx, cy = viewport:GetCenter()
            -- Nearest the cross, which may have left the middle of the view.
            if cx then cx, cy = cx + (crosshair.walkmapX or 0), cy + (crosshair.walkmapY or 0) end
            local list = {}
            if cx then
                local radius = math.max(60, math.min(viewport:GetWidth(), viewport:GetHeight()) * 0.2)
                for _, pin in ipairs(all) do
                    local px, py = pin:GetCenter()
                    if px and (px - cx) ^ 2 + (py - cy) ^ 2 <= radius * radius then list[#list + 1] = pin end
                end
            end
            if #list == 0 or not cx then
                if WalkMapNativeController.SetPanHint then
                    WalkMapNativeController.SetPanHint((#all == 0 and "No markers in view"
                        or "No markers near the cross - move closer") .. "   D-pad: pan   X/B: back")
                end
                return
            end
            table.sort(list, function(a, b)
                local ax, ay = a:GetCenter()
                local bx, by = b:GetCenter()
                return (ax - cx) ^ 2 + (ay - cy) ^ 2 < (bx - cx) ^ 2 + (by - cy) ^ 2
            end)
            for i = #list, 13, -1 do list[i] = nil end
            markerCycle, markerIndex = list, 0
        end
        closePinDetails()
        markerIndex = markerIndex % #markerCycle + 1
        selectedPin = markerCycle[markerIndex]
        pinOutline:ClearAllPoints()
        pinOutline:SetPoint("TOPLEFT", selectedPin, "TOPLEFT", -2, 2)
        pinOutline:SetPoint("BOTTOMRIGHT", selectedPin, "BOTTOMRIGHT", 2, -2)
        pinOutline:Show()
        local enter = selectedPin:GetScript("OnEnter")
        if enter then pcall(enter, selectedPin) end
        if WalkMapNativeController.SetPanHint then
            WalkMapNativeController.SetPanHint("Marker " .. markerIndex .. "/" .. #markerCycle
                .. "   Y: next   A: " .. (selectedPin.walkmapWaypoint and "clear waypoint"
                    or viewport.walkmapPinQuests(selectedPin) and "focus quest" or "set waypoint")
                .. "   D-pad: pan   X/B: back")
        end
    end,
    -- A in map control: waypoint for the selected marker, else centre.
    PanActivate = function()
        if markerCycle and selectedPin then
            local pin = selectedPin
            if pin.walkmapWaypoint then
                clearWaypoint("Waypoint cleared.")
            elseif viewport.walkmapPinQuests(pin) then
                viewport.walkmapFocusClick(viewport.walkmapPinQuests(pin))
            elseif pin.mapPercentX and pin.mapPercentY and currentMap then
                setWaypoint(currentMap, pin.mapPercentX, pin.mapPercentY,
                    pin.questTitle or pin.pinName or pin.objectiveName or "Marker")
            end
            clearMarkerSelection()
            return
        end
        -- No marker selected: on the world or a continent, open what is
        -- under the crosshair; elsewhere a waypoint at the crosshair.
        local x, y = crosshair.ViewCenter()
        if viewport.walkmapDrill(x, y) then
            -- A new map: the cross starts in the middle again.
            crosshair.walkmapPlace(0, 0)
            return
        end
        if currentMap and x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
            padWaypointAt(x, y)
        end
    end,
    PanMode = function(active)
        crosshair.walkmapStop()
        crosshair.walkmapPlace(0, 0)
        crosshair:SetShown(active == true)
        if not active and markerCycle then clearMarkerSelection() end
        -- Leaving map control: Follow picks up again if it was on.
        if not active then WalkMapExtras.ResumeFollow() end
    end,
    Pin = function(direction)
        padPinMode, padPanning = true, false
        if not selectPadPin(direction) then say("No visible markers to inspect.") end
    end,
    Details = function()
        if not selectedPin and not selectPadPin(1) then return end
        local enter = selectedPin and selectedPin:GetScript("OnEnter")
        if enter then pcall(enter, selectedPin) end
    end,
    HidePin = function()
        local hide = selectedPin and selectedPin:GetScript("OnMouseDown")
        if hide then
            pcall(hide, selectedPin, "RightButton")
            selectedPin = nil
            selectPadPin(1)
        end
    end,
    ClosePins = exitPinMode,
}, {
    {frame = canvas}, {frame = viewport, container = true},
    {frame = titleBar}, {frame = resizeGrip},
}, padTargets()[1], (WalkMapExtras.ControllerControls())[4]) -- leaving pan mode returns to Follow
updatePadMode()

WalkMapMiniSource.ControllerPaused = function() return padSuspended end


-- =========================================================
-- Toggle
-- =========================================================

function WalkMap_Toggle()

    if frame:IsShown() then

        WalkMapNativeController.SetVisible(frame, false)

        return

    end


    for _, name
        in ipairs({
            "GetBestMapForUnit",
            "GetMapArtLayers",
            "GetMapArtLayerTextures",
            "GetMapInfo",
            "GetPlayerMapPosition",
        })
    do

        if not C_Map
            or type(
                C_Map[name]
            )
            ~= "function"
        then

            say(
                "This client does not provide C_Map."
                .. name
            )

            return

        end

    end


    currentMap =
        nil

    currentFiles =
        nil

    elapsed =
        0


    if not WalkMapNativeController.SetVisible(frame, true) then return end

    safeUpdate()

end


-- =========================================================
-- Update loop
-- =========================================================

frame:SetScript(
    "OnUpdate",
    function(
        _,
        delta
    )

        if combatLayoutPending and not WalkMapCombat.FrameLocked() then layoutMap() end
        -- Only the player and camera move every rendered frame.
        -- Quest data, art, and service scans retain their 0.1s cadence.
        if currentMap and WalkMapExtras.Follow() and zoomIndex > 1 then
            pcall(updatePlayerPosition, currentMap)
        end

        elapsed =
            elapsed
            + delta


        if elapsed >= 0.1 then

            elapsed =
                0

            safeUpdate()

        end

    end
)


-- =========================================================
-- Events
-- =========================================================

frame:RegisterEvent(
    "QUEST_LOG_UPDATE"
)

frame:RegisterEvent(
    "QUEST_POI_UPDATE"
)

frame:RegisterEvent(
    "MAP_EXPLORATION_UPDATED"
)

frame:RegisterEvent(
    "SUPER_TRACKING_CHANGED"
)

frame:RegisterEvent(
    "GROUP_ROSTER_UPDATE"
)

frame:RegisterEvent(
    "QUEST_TURNED_IN"
)

frame:RegisterEvent(
    "QUEST_WATCH_UPDATE"
)
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("SKILL_LINES_CHANGED")
frame:RegisterEvent("SPELLS_CHANGED")
frame:RegisterEvent("UPDATE_FACTION")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")


frame:SetScript(
    "OnEvent",
    function(
        _,
        event
    )

        if event == "PLAYER_REGEN_ENABLED" then
            if combatLayoutPending and not WalkMapCombat.FrameLocked() then layoutMap() end
        elseif event == "PLAYER_LOGOUT" then
            saveLayout()
        elseif event == "PLAYER_LEVEL_UP" then
            WalkMapExtras.DebugEvent("Level up: "
                .. tostring(UnitLevel and UnitLevel("player") or "unknown"))
            questRefreshAt = 0
            WalkMapExtras.Invalidate()
        elseif event
            == "MAP_EXPLORATION_UPDATED"
        then

            explorationRefreshAt =
                0


        elseif event
            == "GROUP_ROSTER_UPDATE"
        then

            hidePartyMembers()


        else

            questRefreshAt =
                0

            WalkMapExtras.Invalidate()

        end

    end
)


-- =========================================================
-- Shared with the files split from this one (WalkMap_Levels.lua,
-- WalkMap_Fade.lua, WalkMap_Commands.lua, WalkMap_ButtonsMenu.lua). They load
-- right after this file. New self-contained pieces belong in their own file
-- and reach the map through this table: the main chunk here is close to
-- Lua's limit of 200 locals.
-- =========================================================
WalkMapCore = {
    resumeButton = resumeButton,
    frame = frame, viewport = viewport, canvas = canvas, status = status,
    closeButton = closeButton, mapPickerButton = mapPickerButton, dbBadge = dbBadge,
    miniZoomInButton = miniZoomInButton, miniZoomOutButton = miniZoomOutButton,
    centerButton = centerButton, padToggle = padToggle, playerLayer = playerLayer,
    crosshair = crosshair,
    Say = say,
    CurrentMap = function() return currentMap end,
    ZoomIndex = function() return zoomIndex end,
    UpdateZoomLabels = function() updateZoomLabels() end,
    UpdatePadMode = function() if updatePadMode then updatePadMode() end end,
    -- Quest data changed: redraw now when the map is open.
    RefreshQuests = function()
        questRefreshAt = 0
        if frame:IsShown() then safeUpdate() end
    end,
    UnexploredShown = function()
        local n = 0
        for _, texture in ipairs(unexploredTextures) do if texture:IsShown() then n = n + 1 end end
        return n
    end,
    RefreshExploration = function()
        explorationRefreshAt = 0
        if frame:IsShown() then safeUpdate() end
    end,
    PadState = function() return padSuspended, padPanning, lastPadButton end,
    -- Map control's D-pad step (see padPan) and the zoom buttons' step.
    PadPan = function(dx, dy) padPan(dx, dy) end,
    Zoom = function(direction) zoomMap(direction) end,
    SetPadSuspended = function(value)
        padSuspended, padPanning = value == true, false
        updatePadMode()
    end,
}
