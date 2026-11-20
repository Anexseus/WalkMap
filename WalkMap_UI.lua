-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- WalkMap's visual chrome. "Classic" uses artwork and templates supplied by
-- the game; the other looks (Stone, Wood, Leather) use WalkMap's own TGA files
-- in Skins/ (drawn by tools/Skins/gen_skins.py). These children only draw the
-- skin; WalkMap keeps its own input handling.
WalkMapUI = {}
local ui = WalkMapUI

-- Window look, read once at load: a change applies after a reload.
local LOOKS = {classic = "Classic", stone = "Stone and gold", wood = "Wood and parchment",
    leather = "Leather and bronze"}
ui.LookOrder = {"classic", "stone", "wood", "leather"}
-- New players start in Leather and bronze. Anyone who has used WalkMap
-- before (the welcome page was shown) keeps Classic unless they chose a look.
function ui.DefaultLook()
    local account = type(WalkMapSettings) == "table" and WalkMapSettings or nil
    if account and account.welcomeSeen then return "classic" end
    return "leather"
end
local function savedLook()
    local character = type(WalkMapCharacterSettings) == "table" and WalkMapCharacterSettings.look
    local account = type(WalkMapSettings) == "table" and WalkMapSettings.look
    local look = character or account or ui.DefaultLook()
    return LOOKS[look] and look or "classic"
end
local activeLook = savedLook()
function ui.Look() return activeLook end
function ui.LookName(look) return LOOKS[look or activeLook] or LOOKS.classic end

local SKINS = "Interface\\AddOns\\WalkMap\\Skins\\"
local function skinFile(name) return SKINS .. activeLook .. "\\" .. name end
-- Accent (frame metal) and quest-log list colours for each look.
local ACCENT = {classic = {0.86, 0.68, 0.32}, stone = {0.88, 0.7, 0.3},
    wood = {0.8, 0.6, 0.34}, leather = {0.86, 0.56, 0.34}}
local LIST = {classic = {0.05, 0.035, 0.02, 0.78}, stone = {0.03, 0.03, 0.035, 0.82},
    wood = {0.07, 0.045, 0.022, 0.82}, leather = {0.07, 0.028, 0.022, 0.82}}
function ui.Accent() local c = ACCENT[activeLook] return c[1], c[2], c[3] end
function ui.ListColor() local c = LIST[activeLook] return c[1], c[2], c[3], c[4] end

-- Nine pieces of one square texture: fixed corners, stretched edges.
local function nineSlice(frame, file, corner, size, layer)
    local c = corner
    local pieces = {}
    local function piece(l, r, t, b)
        local texture = frame:CreateTexture(nil, layer or "BORDER")
        texture:SetTexture(file)
        texture:SetTexCoord(l, r, t, b)
        pieces[#pieces + 1] = texture
        return texture
    end
    local tl = piece(0, c, 0, c); tl:SetSize(size, size); tl:SetPoint("TOPLEFT")
    local tr = piece(1 - c, 1, 0, c); tr:SetSize(size, size); tr:SetPoint("TOPRIGHT")
    local bl = piece(0, c, 1 - c, 1); bl:SetSize(size, size); bl:SetPoint("BOTTOMLEFT")
    local br = piece(1 - c, 1, 1 - c, 1); br:SetSize(size, size); br:SetPoint("BOTTOMRIGHT")
    local top = piece(c, 1 - c, 0, c); top:SetPoint("TOPLEFT", tl, "TOPRIGHT"); top:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
    local bottom = piece(c, 1 - c, 1 - c, 1); bottom:SetPoint("TOPLEFT", bl, "TOPRIGHT"); bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
    local left = piece(0, c, c, 1 - c); left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT"); left:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT")
    local right = piece(1 - c, 1, c, 1 - c); right:SetPoint("TOPLEFT", tr, "BOTTOMLEFT"); right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
    return pieces
end

-- Tiled material behind a skinned window or menu.
local function tiled(frame, inset, alpha)
    local texture = frame:CreateTexture(nil, "BACKGROUND")
    if not pcall(texture.SetTexture, texture, skinFile("bg.tga"), "REPEAT", "REPEAT") then
        texture:SetTexture(skinFile("bg.tga"))
    end
    if texture.SetHorizTile then texture:SetHorizTile(true) end
    if texture.SetVertTile then texture:SetVertTile(true) end
    texture:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
    texture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
    texture:SetAlpha(alpha or 1)
    return texture
end

-- A skinned window: tiled material, a title band and the metal frame.
-- The skin reaches `outset` px beyond the window, so the metal border sits
-- around the window's content (buttons near the edges stay fully visible).
local function skinnedWindow(parent, header, frameSize, outset)
    outset = outset or 5
    local skin = CreateFrame("Frame", nil, parent)
    skin:SetPoint("TOPLEFT", parent, "TOPLEFT", -outset, outset)
    skin:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", outset, -outset)
    tiled(skin, outset, 1)
    if header then
        local band = skin:CreateTexture(nil, "BORDER")
        band:SetTexture(skinFile("header.tga"))
        band:SetPoint("TOPLEFT", skin, "TOPLEFT", outset, -outset)
        band:SetPoint("TOPRIGHT", skin, "TOPRIGHT", -outset, -outset)
        band:SetHeight(26)
    end
    -- The metal border is its own frame above the window's content, so
    -- buttons, text and the map tuck in under it instead of covering it.
    local border = CreateFrame("Frame", nil, skin)
    border:SetAllPoints(skin)
    nineSlice(border, skinFile("frame.tga"), 0.25, frameSize or 12, "ARTWORK")
    skin.walkmapBorder = border
    return skin
end

-- Above the window's buttons, map pins and hint line (about +20), below
-- WalkMap's menus and tooltips, which use higher strata.
local BORDER_LEVELS = 40
local function raiseBorder(skin, parent)
    local border = skin.walkmapBorder
    if border and border.SetFrameLevel then
        border:SetFrameLevel(parent:GetFrameLevel() + BORDER_LEVELS)
    end
end
ui.MapLayout = {headerHeight = 30, toolbarTop = 33, toolbarHeight = 23,
    mapTop = 59, footerHeight = 28, footerButtonBottom = 5, chromeAlpha = 0.88}

local function makePassive(frame, level, depth)
    if frame.SetFrameLevel then frame:SetFrameLevel(level) end
    if frame.EnableMouse then frame:EnableMouse(false) end
    if frame.EnableMouseWheel then frame:EnableMouseWheel(false) end
    if frame.EnableKeyboard then frame:EnableKeyboard(false) end
    if frame.EnableGamePadButton then frame:EnableGamePadButton(false) end
    if frame.EnableGamePadStick then frame:EnableGamePadStick(false) end
    if depth < 6 and frame.GetChildren then
        for _, child in ipairs({frame:GetChildren()}) do
            makePassive(child, level, depth + 1)
        end
    end
end

local function backdrop(parent, background, border, edgeSize)
    local ok, skin = pcall(CreateFrame, "Frame", nil, parent, "BackdropTemplate")
    if not ok then skin = CreateFrame("Frame", nil, parent) end
    skin:SetAllPoints(parent)
    if skin.SetBackdrop then
        skin:SetBackdrop({bgFile = background, edgeFile = border,
            tile = true, tileSize = 16, edgeSize = edgeSize,
            insets = {left = 4, right = 4, top = 4, bottom = 4}})
        skin:SetBackdropColor(0.075, 0.075, 0.075, 0.98)
        skin:SetBackdropBorderColor(0.72, 0.72, 0.72, 1)
    else
        local fill = skin:CreateTexture(nil, "BACKGROUND")
        fill:SetAllPoints(skin)
        fill:SetColorTexture(0.065, 0.065, 0.065, 0.98)
    end
    makePassive(skin, parent:GetFrameLevel(), 0)
    return skin
end

function ui.Window(parent, layout)
    local ok, skin
    if activeLook ~= "classic" then
        ok, skin = pcall(skinnedWindow, parent, true)
        if ok then
            if layout then
                skin.walkmapNormalAlpha = layout.chromeAlpha
                skin:SetAlpha(layout.chromeAlpha)
            end
            -- One level below the window, so the window's own textures and
            -- text (the quest log's parchment, list and titles) stay on top.
            makePassive(skin, math.max(0, parent:GetFrameLevel() - 1), 0)
            raiseBorder(skin, parent)
            skin:Show()
            return skin
        end
    end
    ok, skin = pcall(CreateFrame, "Frame", nil, parent, "ButtonFrameTemplate")
    if not ok then
        skin = backdrop(parent, "Interface\\FrameGeneral\\UI-Background-Marble",
            "Interface\\DialogFrame\\UI-DialogBox-Border", 24)
    else
        skin:SetAllPoints(parent)
        if ButtonFrameTemplate_HidePortrait then
            ButtonFrameTemplate_HidePortrait(skin)
        end
        if ButtonFrameTemplate_HideButtonBar then
            ButtonFrameTemplate_HideButtonBar(skin)
        end
        for _, key in ipairs({"PortraitContainer", "PortraitFrame", "Portrait",
            "portrait", "Inset", "CloseButton", "TitleText"}) do
            local object = skin[key]
            if object and object.Hide then object:Hide() end
        end
        if skin.Bg then skin.Bg:SetAlpha(0.96) end
    end
    if layout then
        -- Fade only the decorative game artwork. Controls, title and map
        -- belong to the owner and retain their normal opacity and colors.
        skin.walkmapNormalAlpha = layout.chromeAlpha
        skin:SetAlpha(layout.chromeAlpha)
    end
    makePassive(skin, parent:GetFrameLevel(), 0)
    skin:Show()
    return skin
end

function ui.Menu(parent)
    if activeLook ~= "classic" then
        local ok, skin = pcall(skinnedWindow, parent, false, 10, 4)
        if ok then
            makePassive(skin, math.max(0, parent:GetFrameLevel() - 1), 0)
            raiseBorder(skin, parent)
            skin:Show()
            return skin
        end
    end
    local skin = backdrop(parent, "Interface\\Tooltips\\UI-Tooltip-Background",
        "Interface\\Tooltips\\UI-Tooltip-Border", 16)
    -- Warm, gold-edged dropdowns that match the map window's chrome.
    if skin.SetBackdropColor then
        skin:SetBackdropColor(0.07, 0.055, 0.04, 0.97)
        skin:SetBackdropBorderColor(0.86, 0.68, 0.32, 1)
    end
    -- A faint lighter band along the top gives the panel some depth.
    local sheen = skin:CreateTexture(nil, "BORDER")
    sheen:SetPoint("TOPLEFT", skin, "TOPLEFT", 4, -4)
    sheen:SetPoint("TOPRIGHT", skin, "TOPRIGHT", -4, -4)
    sheen:SetHeight(10)
    sheen:SetColorTexture(1, 0.85, 0.55, 0.05)
    return skin
end

function ui.Inset(parent, left, top, right, bottom)
    local ok, inset
    if activeLook ~= "classic" then
        ok, inset = pcall(function()
            local frame = CreateFrame("Frame", nil, parent)
            local shade = frame:CreateTexture(nil, "BACKGROUND")
            shade:SetAllPoints(frame)
            shade:SetColorTexture(0, 0, 0, 0.35)
            nineSlice(frame, skinFile("inset.tga"), 0.125, 8, "BORDER")
            return frame
        end)
    end
    if not ok then ok, inset = pcall(CreateFrame, "Frame", nil, parent, "InsetFrameTemplate") end
    if not ok then
        inset = backdrop(parent, "Interface\\Tooltips\\UI-Tooltip-Background",
            "Interface\\Tooltips\\UI-Tooltip-Border", 12)
    end
    inset:ClearAllPoints()
    inset:SetPoint("TOPLEFT", parent, "TOPLEFT", left, -top)
    inset:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -right, bottom)
    makePassive(inset, parent:GetFrameLevel(), 0)
    inset:Show()
    return inset
end

local function rowArt(texture, atlas, alpha)
    local ok = texture.SetAtlas and pcall(texture.SetAtlas, texture, atlas)
    if not ok then
        texture:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    end
    local r, g, b = ui.Accent()
    texture:SetVertexColor(math.min(1, r * 1.15), math.min(1, g * 1.2), math.min(1, b * 1.3), alpha)
end

function ui.Row(row, category)
    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(row)
    rowArt(highlight, "auctionhouse-ui-row-highlight", 0.35)
    row.walkmapHighlight = highlight
    if category then
        local selected = row:CreateTexture(nil, "BACKGROUND")
        selected:SetAllPoints(row)
        rowArt(selected, "Options_List_Active", 0.85)
        selected:Hide()
        row.walkmapSelected = selected
    end
end

-- Grab handles on a skinned window's metal border: the four strips outside
-- the content. onDown/onUp start and stop moving the window. Classic has no
-- outside border, so nothing is added there.
function ui.DragEdges(skin, onDown, onUp)
    local border = skin and skin.walkmapBorder
    if not border then return end
    local thickness = 5 -- the outset ring only, never over the content
    local sides = {
        {"TOPLEFT", "TOPRIGHT", nil, thickness},
        {"BOTTOMLEFT", "BOTTOMRIGHT", nil, thickness},
        {"TOPLEFT", "BOTTOMLEFT", thickness, nil},
        {"TOPRIGHT", "BOTTOMRIGHT", thickness, nil},
    }
    for _, side in ipairs(sides) do
        local edge = CreateFrame("Frame", nil, border)
        edge:SetPoint(side[1], border, side[1])
        edge:SetPoint(side[2], border, side[2])
        if side[3] then edge:SetWidth(side[3]) else edge:SetHeight(side[4]) end
        edge:SetFrameLevel(border:GetFrameLevel() + 1)
        edge:EnableMouse(true)
        edge:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then onDown() end end)
        edge:SetScript("OnMouseUp", function() onUp() end)
    end
end

-- Art for WalkMap's standard buttons (used by WalkMapExtras.StyleButton):
-- texture, the cap width in texture coordinates, the cap width on screen,
-- the visible height share of the texture, and whether pressed uses a tint.
function ui.ButtonArt()
    if activeLook == "classic" then
        return "Interface\\Buttons\\UI-Panel-Button-Up", 0.09375, 10, 0.6875, false,
            {0.09375, 0.53125, 0.625}
    end
    return skinFile("button.tga"), 0.09375, 10, 1, true, {0.09375, 0.90625, 1}
end

-- Gold glow around a skinned button while the mouse or the controller is on
-- it. Classic keeps the game's flat highlight.
function ui.ButtonGlow(button)
    if activeLook == "classic" then return nil end
    local glow = {}
    local file = SKINS .. "glow.tga"
    local caps = {{0, 0.125}, {0.125, 0.875}, {0.875, 1}}
    for index, limits in ipairs(caps) do
        local piece = button:CreateTexture(nil, "OVERLAY")
        piece:SetTexture(file)
        piece:SetTexCoord(limits[1], limits[2], 0, 1)
        if index == 1 then
            piece:SetPoint("TOPLEFT", button, "TOPLEFT", -6, 6)
            piece:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", -6, -6)
            piece:SetWidth(16)
        elseif index == 2 then
            piece:SetPoint("TOPLEFT", glow[1], "TOPRIGHT")
            piece:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -10, -6)
        else
            piece:SetPoint("TOPRIGHT", button, "TOPRIGHT", 6, 6)
            piece:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 6, -6)
            piece:SetWidth(16)
        end
        piece:Hide()
        glow[index] = piece
    end
    local function show(on) for _, piece in ipairs(glow) do piece:SetShown(on) end end
    -- Hook a moment later: callers set their own OnEnter/OnLeave/OnHide
    -- scripts right after styling, and SetScript would drop earlier hooks.
    local function hook()
        button:HookScript("OnEnter", function() show(true) end)
        button:HookScript("OnLeave", function() show(false) end)
        button:HookScript("OnHide", function() show(false) end)
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, hook) else hook() end
    return glow
end

-- Metal frame around any frame (the minimaps), for the newer looks only.
-- Returns the border frame, or nil with Classic.
function ui.FrameBorder(frame, outset, size, levels)
    if activeLook == "classic" then return nil end
    outset = outset or 4
    local border = CreateFrame("Frame", nil, frame)
    border:SetPoint("TOPLEFT", frame, "TOPLEFT", -outset, outset)
    border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", outset, -outset)
    border:EnableMouse(false)
    -- Only just above its own frame: a high level put the frame over the
    -- game's windows (Talents) that cover the minimap and tracker themselves.
    border:SetFrameLevel(frame:GetFrameLevel() + (levels or 1))
    nineSlice(border, skinFile("frame.tga"), 0.25, size or 12, "ARTWORK")
    return border
end

-- Fill a texture with the look's tiled material (alpha as given). Returns
-- false with Classic so the caller keeps its own colour.
function ui.ApplyMaterial(texture, alpha, shade)
    if activeLook == "classic" then return false end
    if not pcall(texture.SetTexture, texture, skinFile("bg.tga"), "REPEAT", "REPEAT") then
        texture:SetTexture(skinFile("bg.tga"))
    end
    if texture.SetHorizTile then texture:SetHorizTile(true) end
    if texture.SetVertTile then texture:SetVertTile(true) end
    shade = shade or 1
    texture:SetVertexColor(shade, shade, shade, 1)
    texture:SetAlpha(alpha or 1)
    return true
end

-- The look's title band on a texture (the tracker's zone heading).
function ui.ApplyHeader(texture)
    if activeLook == "classic" then return false end
    texture:SetTexture(skinFile("header.tga"))
    texture:SetVertexColor(1, 1, 1, 1)
    return true
end

-- Shrink a font string's font until its text fits maxWidth (and maxHeight,
-- if given), down to 7 pt; back to its own size when the text is short
-- again. Some setups (a handheld at 720p, upscaled) draw fonts larger than
-- the frames were made for.
function ui.FitText(fontString, maxWidth, maxHeight)
    if not (fontString and fontString.GetFont and fontString.SetFont) then return end
    local file, size, flags = fontString:GetFont()
    if not fontString.walkmapFont then
        if not file or not size then return end
        fontString.walkmapFont = {file, size, flags}
    end
    local base = fontString.walkmapFont
    if size ~= base[2] then fontString:SetFont(base[1], base[2], base[3]) end
    size = base[2]
    local function tooBig()
        local width = tonumber(fontString:GetStringWidth()) or 0
        local height = fontString.GetStringHeight and tonumber(fontString:GetStringHeight()) or 0
        return (maxWidth and width > maxWidth) or (maxHeight and height > maxHeight)
    end
    while tooBig() and size > 7 do
        size = size - 0.5
        fontString:SetFont(base[1], size, base[3])
    end
end

-- Three pieces of a vertical texture on `parent`: fixed caps (cap share of
-- the texture, capSize on screen) and a stretched middle.
local function threeSliceV(parent, file, cap, capSize, layer, coords)
    local l, r, t, b = 0, 1, 0, 1
    if coords then l, r, t, b = coords[1], coords[2], coords[3], coords[4] end
    local function y(share) return t + (b - t) * share end
    local top = parent:CreateTexture(nil, layer)
    top:SetTexture(file); top:SetTexCoord(l, r, y(0), y(cap))
    top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(capSize)
    local bottom = parent:CreateTexture(nil, layer)
    bottom:SetTexture(file); bottom:SetTexCoord(l, r, y(1 - cap), y(1))
    bottom:SetPoint("BOTTOMLEFT"); bottom:SetPoint("BOTTOMRIGHT"); bottom:SetHeight(capSize)
    local middle = parent:CreateTexture(nil, layer)
    middle:SetTexture(file); middle:SetTexCoord(l, r, y(cap), y(1 - cap))
    middle:SetPoint("TOPLEFT", top, "BOTTOMLEFT"); middle:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT")
    return {top, middle, bottom}
end

-- Scroll bar art in the window's look: the groove (bar), the thumb (a frame
-- the caller sizes and places) and the up/down arrow buttons. Classic uses
-- the game's own scroll bar knob and arrows.
function ui.ScrollBar(bar, thumb, up, down)
    if activeLook == "classic" then
        local track = bar:CreateTexture(nil, "BACKGROUND")
        track:SetAllPoints(bar)
        track:SetColorTexture(0, 0, 0, 0.45)
        threeSliceV(thumb, "Interface\\Buttons\\UI-ScrollBar-Knob", 0.35, 8, "ARTWORK",
            {0.2, 0.8, 0.125, 0.875})
        for _, pair in ipairs({{up, "Up"}, {down, "Down"}}) do
            local button, way = pair[1], pair[2]
            local base = "Interface\\Buttons\\UI-ScrollBar-Scroll" .. way .. "Button-"
            button:SetNormalTexture(base .. "Up")
            button:SetPushedTexture(base .. "Down")
            button:SetDisabledTexture(base .. "Disabled")
            button:SetHighlightTexture(base .. "Highlight", "ADD")
            for _, art in ipairs({button:GetNormalTexture(), button:GetPushedTexture(),
                button:GetDisabledTexture(), button:GetHighlightTexture()}) do
                if art then art:SetTexCoord(0.2, 0.8, 0.25, 0.75) end
            end
        end
        return
    end
    threeSliceV(bar, skinFile("scrolltrack.tga"), 0.125, 6, "BACKGROUND")
    threeSliceV(thumb, skinFile("scrollthumb.tga"), 0.125, 6, "ARTWORK")
    for _, pair in ipairs({{up, false}, {down, true}}) do
        local button, flip = pair[1], pair[2]
        local file = skinFile("scrollarrow.tga")
        button:SetNormalTexture(file)
        button:SetPushedTexture(file)
        button:SetHighlightTexture(file, "ADD")
        for _, art in ipairs({button:GetNormalTexture(), button:GetPushedTexture(), button:GetHighlightTexture()}) do
            if art and flip then art:SetTexCoord(0, 1, 1, 0) end
        end
        local pushed = button:GetPushedTexture()
        if pushed then pushed:SetVertexColor(0.7, 0.7, 0.7) end
        local lit = button:GetHighlightTexture()
        if lit then lit:SetAlpha(0.4) end
    end
end

function ui.CloseButton(button)
    if activeLook ~= "classic" then
        -- The skin's X fills its square (the game's art sits low and needs a
        -- lift), so it gets a smaller button level with the DB badge.
        local parent = button:GetParent()
        button:SetSize(18, 18)
        button:ClearAllPoints()
        button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -3)
        local file = skinFile("close.tga")
        button:SetNormalTexture(file)
        button:SetPushedTexture(file)
        local pushed = button:GetPushedTexture()
        if pushed then pushed:SetVertexColor(0.7, 0.7, 0.7) end
        button:SetHighlightTexture(file, "ADD")
        local lit = button:GetHighlightTexture()
        if lit then lit:SetAlpha(0.35) end
        return
    end
    button:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    button:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    button:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
end
