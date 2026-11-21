-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- Read-only markers over Blizzard's own minimap. Also provides WalkMap's
-- optional live-terrain view without replacing the game widget.
local source = WalkMapMiniSource
if not source or not WalkMapExtras then return end

local layer = CreateFrame("Frame", "WalkMapNativeMarkers", UIParent)
layer:EnableMouse(false)
layer:EnableKeyboard(false)
layer:SetFrameStrata("HIGH")
if layer.EnableGamePadButton then layer:EnableGamePadButton(false) end
if layer.EnableGamePadStick then layer:EnableGamePadStick(false) end
layer:Hide()
layer:SetFrameLevel(5)

-- The game draws its player arrow under this marker layer, so WalkMap draws
-- the same arrow on top (sublevel 7, above every marker) at the centre.
local topArrow = layer:CreateTexture(nil, "OVERLAY", nil, 7)
topArrow:SetTexture("Interface\\Minimap\\MinimapArrow")
topArrow:SetPoint("CENTER", layer, "CENTER")
topArrow:Hide()

local pools = {}
local boundsMap, boundsInstance, worldX0, worldY0
local mapXWorldX, mapXWorldY, mapYWorldX, mapYWorldY
local boundsRetryAt, boundsCheckedAt = 0, 0

-- The client renders live terrain inside its Minimap widget. In this mode
-- only, enlarge that widget and give it a square mask. Screen clamping keeps
-- the larger square visible while its parent and native map anchors stay intact.
local liveShape
-- Focused-quest area on the square terrain minimap. The client only offers
-- all-or-nothing alpha for its own minimap areas, so in Focused mode WalkMap
-- hides those and draws the focused quest with the game's QuestPOIFrame,
-- clipped to the square. A round minimap cannot be clipped round.
local areaClip = CreateFrame("Frame", nil, UIParent)
areaClip:SetFrameStrata("HIGH")
areaClip:SetFrameLevel(2)
areaClip:EnableMouse(false)
if areaClip.SetClipsChildren then areaClip:SetClipsChildren(true) end
areaClip:Hide()
local focusBlob, focusBlobKey
local function hideFocusArea()
    areaClip:Hide()
    if focusBlob and focusBlobKey then pcall(focusBlob.DrawNone, focusBlob) end
    focusBlobKey = nil
end
local function squareFocusMode()
    return liveShape ~= nil and WalkMapExtras.MiniMap() and WalkMapExtras.MiniTerrain() == "game"
        and WalkMapExtras.AreaMode() == "focus"
end

local nativeState = {shown = "unknown", size = "unknown", zoom = "unknown"}
local pendingTerrainRefresh
local layoutTick = 0
source.NativeDebugState = function() return nativeState end
source.NativeRefreshStatus = function()
    return nativeState.refresh or "not requested"
end
source.LiveMiniStatus = function()
    return liveShape and ("square " .. liveShape.size .. "x" .. liveShape.size
        .. (liveShape.clamped ~= nil and ", screen clamped" or "")
        .. ", restore mask: " .. liveShape.maskSource
        .. ", day/night: " .. (liveShape.dayNightState or "search pending")
        .. ", area rings: " .. (nativeState.blobRings or "not changed")
        .. ", game areas: " .. (nativeState.blobAreas or "game default")
        .. ", WalkMap focus area: " .. (nativeState.focusArea or "off"))
        or "not applied"
end
-- Is the look's square metal frame around the game minimap on screen?
source.LiveFrameShown = function()
    return source.walkmapLiveFrame ~= nil and source.walkmapLiveFrame:IsShown()
end
local squareMask = "Interface\\Buttons\\WHITE8X8"
local roundMask = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local previousRoundMask = "Interface\\AddOns\\WalkMap\\Icons\\minimap_round_mask"
local maskStates = setmetatable({}, {__mode = "k"})
local changingMask
local function validMask(value)
    return (type(value) == "string" and value ~= "")
        or (type(value) == "number" and value > 0)
end

local function restoreMask(mask)
    if mask == previousRoundMask or mask == previousRoundMask .. ".tga" then
        return roundMask
    end
    return mask
end

local function watchMask(original)
    if maskStates[original] then return end
    local state = {}
    maskStates[original] = state
    if hooksecurefunc and original.SetZoom then
        pcall(hooksecurefunc, original, "SetZoom", function(_, zoom)
            if type(zoom) == "number" then nativeState.zoom = zoom end
        end)
    end
    if hooksecurefunc and original.SetMaskTexture then
        pcall(hooksecurefunc, original, "SetMaskTexture", function(_, mask)
            if not validMask(mask) then return end
            state.current = mask
            if not changingMask then
                if liveShape and liveShape.original == original then
                    -- Reflows can echo our temporary square mask. Preserve
                    -- the previous round shape instead of saving that echo
                    -- as the mask to restore behind the native round border.
                    if mask ~= squareMask or liveShape.mask == squareMask
                        or original.__sqmBorder then
                        liveShape.mask, liveShape.maskSource = restoreMask(mask), "client/addon update"
                    end
                end
            end
        end)
    end
end

local function currentMask(original)
    if original.GetMaskTexture then
        local ok, mask = pcall(original.GetMaskTexture, original)
        if ok and validMask(mask) then
            local state = maskStates[original]
            if state then state.readMask = mask end
            return mask
        end
    end
    local state = maskStates[original]
    return state and state.current
end

source.NativeMaskStatus = function()
    local original = _G.Minimap
    if not original then return "missing" end
    -- Reports use the mask already read or observed during normal layout.
    -- Do not probe the native widget while opening the copy window.
    local state = maskStates[original]
    local mask = state and (state.current or state.readMask)
    return mask and tostring(mask) or "unknown (no observed mask)"
end

local function queueTerrainRefresh(original, reason)
    pendingTerrainRefresh = {original = original, tick = layoutTick,
        at = GetTime(), pass = 0, reason = reason}
    nativeState.refresh = "pending: " .. reason
end

local function updateTerrainRefresh()
    local job = pendingTerrainRefresh
    if not job or layoutTick <= job.tick or GetTime() < job.at then return end
    local original = job.original
    if original ~= _G.Minimap then pendingTerrainRefresh = nil return end
    if InCombatLockdown and InCombatLockdown() then return end
    if source.NativeRefreshBlocked or (original.IsForbidden and original:IsForbidden()) then
        pendingTerrainRefresh = nil
        nativeState.refresh = "unavailable: protected widget/action"
        return
    end
    if not original:IsShown() or (original.IsVisible and not original:IsVisible()) then return end
    if not original.GetZoom or not original.SetZoom then
        pendingTerrainRefresh = nil
        nativeState.refresh = "unavailable: zoom API missing"
        return
    end
    local ok, zoom = pcall(original.GetZoom, original)
    local levelsOK, levels = pcall(function()
        return original.GetZoomLevels and original:GetZoomLevels() or 6
    end)
    if not ok or type(zoom) ~= "number" or zoom < 0 or zoom ~= math.floor(zoom)
        or not levelsOK or type(levels) ~= "number" or levels < 2 or zoom >= levels then
        pendingTerrainRefresh = nil
        nativeState.refresh = "unavailable: invalid zoom state"
        return
    end
    -- Size/mask changes can leave the engine's terrain at its old rectangle
    -- until the player moves. After native anchors settle, invalidate that
    -- rectangle by briefly changing zoom and restoring it in the same call.
    -- Read zoom again for each pass so a user's intervening zoom is retained.
    local changed, message = pcall(original.SetZoom, original,
        zoom + 1 < levels and zoom + 1 or zoom - 1)
    if source.NativeRefreshBlocked then
        pendingTerrainRefresh = nil
        nativeState.refresh = "unavailable: protected zoom action"
        return
    end
    local restored, restoreMessage = pcall(original.SetZoom, original, zoom)
    nativeState.zoom = zoom
    if not changed or not restored or source.NativeRefreshBlocked then
        pendingTerrainRefresh = nil
        nativeState.refresh = "failed: " .. tostring(message or restoreMessage or "protected action")
        WalkMapExtras.DebugEvent("Game mini redraw: " .. nativeState.refresh)
        return
    end
    job.pass = job.pass + 1
    if job.pass < 2 then
        job.tick, job.at = layoutTick, GetTime() + 0.12
    else
        pendingTerrainRefresh = nil
        nativeState.refresh = "completed: " .. job.reason
    end
end

local function setMask(original, mask)
    changingMask = true
    local ok, message = pcall(original.SetMaskTexture, original, mask)
    changingMask = nil
    if not ok then error(message) end
end

-- Some clients expose SetMaskTexture but no getter. Observe later game/addon
-- changes and use the game's portrait circle for the otherwise unknown case.
if _G.Minimap then watchMask(_G.Minimap) end
local liveBorder = CreateFrame("Frame", nil, layer)
liveBorder:SetAllPoints(layer)
liveBorder:EnableMouse(false)
for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
    local edge = liveBorder:CreateTexture(nil, "OVERLAY")
    edge:SetColorTexture(0.58, 0.57, 0.54, 1)
    if side == "TOP" or side == "BOTTOM" then
        edge:SetPoint(side .. "LEFT", liveBorder, side .. "LEFT", 0, 0)
        edge:SetPoint(side .. "RIGHT", liveBorder, side .. "RIGHT", 0, 0)
        edge:SetHeight(2)
    else
        edge:SetPoint("TOP" .. side, liveBorder, "TOP" .. side, 0, 0)
        edge:SetPoint("BOTTOM" .. side, liveBorder, "BOTTOM" .. side, 0, 0)
        edge:SetWidth(2)
    end
end
-- Newer looks: a metal frame instead of the thin grey edge. The marker
-- layer is HIGH (above the minimap's own icons), which would also put the
-- frame over game windows such as Talents; so the frame lives in the game
-- minimap's own strata, just above the minimap, and follows liveBorder.
-- Hidden until the square game-terrain shape is applied (applyLiveShape).
liveBorder:Hide()
-- The metal frame (newer looks); kept in step with liveBorder below.
local liveFrame
if WalkMapUI and WalkMapUI.Look() ~= "classic" and _G.Minimap then
    local holder = CreateFrame("Frame", nil, UIParent)
    liveFrame = holder
    source.walkmapLiveFrame = holder
    holder:SetAllPoints(liveBorder)
    holder:EnableMouse(false)
    holder:SetFrameStrata(_G.Minimap:GetFrameStrata())
    holder:SetFrameLevel(_G.Minimap:GetFrameLevel() + 5)
    if WalkMapUI.FrameBorder(holder, 4, 12, 1) then
        for _, region in ipairs({liveBorder:GetRegions()}) do region:SetAlpha(0) end
    end
    -- Only while the square frame is really on screen. (It used to copy
    -- IsShown() before liveBorder was hidden: with the marker layer not yet
    -- visible no OnHide followed, so the square frame stayed around the
    -- round game minimap.)
    holder:Hide()
    liveBorder:HookScript("OnShow", function() holder:SetShown(liveBorder:IsVisible()) end)
    liveBorder:HookScript("OnHide", function() holder:Hide() end)
end

local timeTextureIDs
local function timeArtScore(value)
    if type(value) == "string" then
        local text = value:lower():gsub("[^%w]", "")
        if text:find("gametime") or text:find("daynight") or text:find("daytime")
            or text:find("timeofday") or text:find("sunmoon")
            or text:find("sunandmoon") or text:find("timeindicator")
            or (text:find("minimap") and (text:find("moon")
                or text:find("sun") or text:find("night"))) then
            return 12
        end
        if text:find("uicalendarbutton") then return 10 end
    elseif type(value) == "number" then
        if not timeTextureIDs then
            timeTextureIDs = {}
            local probe = layer:CreateTexture(nil, "BACKGROUND")
            probe:Hide()
            for _, entry in ipairs({
                {"Interface\\Minimap\\UI-Minimap-TimeIndicator", 12},
                {"Interface\\Calendar\\UI-Calendar-Button", 10},
            }) do
                probe:SetTexture(nil)
                local ok = pcall(probe.SetTexture, probe, entry[1])
                local id = ok and probe:GetTexture()
                if type(id) == "number" and id > 0 then
                    timeTextureIDs[id] = entry[2]
                end
            end
        end
        return timeTextureIDs[value]
    end
end

local function findDayNightParts()
    local candidates, visited, notes = {}, {}, {}
    local cluster = _G.MinimapCluster
    local pending = {{cluster, 0}, {_G.Minimap, 0}}
    local count = 0
    local function offer(object, score, reason)
        if not object or not object.GetWidth or not object.GetNumPoints then return end
        if object.__sqmTrayed then return end
        if object.IsVisible and not object:IsVisible() then return end
        local w, h = object:GetWidth(), object:GetHeight()
        -- Never hide an entire minimap, container or indicator row.
        if not w or not h or w < 8 or h < 8 or w > 96 or h > 96 then return end
        if not candidates[object] or candidates[object].score < score then
            candidates[object] = {score = score, reason = reason}
        end
    end
    local function inspectArt(frame, region)
        if not region then return end
        local atlas = region.GetAtlas and region:GetAtlas()
        local texture = region.GetTexture and region:GetTexture()
        local score = timeArtScore(atlas) or timeArtScore(texture)
        if score then
            local w, h = frame:GetWidth(), frame:GetHeight()
            local object = frame
            if w > 96 or h > 96 then object = region end
            offer(object, score, "art " .. tostring(atlas or texture))
        end
        return atlas or texture
    end
    local keys = {"GameTimeFrame", "DayNightFrame", "DayNightIndicator",
        "DayNightIcon", "DayNight", "DayTimeFrame", "DayTimeIndicator",
        "TimeOfDay", "TimeOfDayFrame", "TimeOfDayIndicator",
        "SunMoon", "SunMoonFrame", "SunMoonIndicator"}
    local function nativeSizePart(frame, width, height, name)
        if not cluster or (name and name ~= "") or frame:GetObjectType() ~= "Frame"
            or width < 38 or width > 46 or height < 38 or height > 46 then return false end
        local parent = frame:GetParent()
        local direct = parent == cluster or parent == cluster.IndicatorFrame
        local inCluster = false
        for _ = 1, 8 do
            -- Native quest pins can have the same dimensions. Never use
            -- their size to identify a time control under the map itself.
            if not parent or parent == _G.Minimap then return false end
            if parent == cluster then inCluster = true break end
            parent = parent.GetParent and parent:GetParent()
        end
        if not inCluster then return false end
        if direct then return true end
        -- Other copies may sit in anonymous native containers. Limit these
        -- to the indicator's upper-right quadrant, as in the Forever layout.
        if not frame.GetCenter or not _G.Minimap or not _G.Minimap.GetCenter then return false end
        local ok, x, y = pcall(frame.GetCenter, frame)
        local mapOK, mapX, mapY = pcall(_G.Minimap.GetCenter, _G.Minimap)
        return ok and mapOK and x and y and mapX and mapY and x > mapX and y > mapY
    end
    local function scan(frame, depth)
        if not frame or visited[frame] or depth > 5 or count >= 300 then return end
        visited[frame], count = true, count + 1
        local name = frame.GetName and frame:GetName()
        if timeArtScore(name) then offer(frame, 8, "name " .. name) end
        for _, key in ipairs(keys) do
            local object = frame[key]
            if type(object) == "table" or type(object) == "userdata" then
                offer(object, 9, "key " .. key)
            end
        end
        local artEntries = {}
        local function rememberArt(region)
            local value = inspectArt(frame, region)
            if value and #artEntries < 4 then artEntries[#artEntries + 1] = tostring(value) end
        end
        rememberArt(frame.GetNormalTexture and frame:GetNormalTexture())
        if frame.GetRegions then
            for _, region in ipairs({frame:GetRegions()}) do
                rememberArt(region)
            end
        end
        local width, height = frame:GetWidth(), frame:GetHeight()
        local visible = not frame.IsVisible or frame:IsVisible()
        if visible and nativeSizePart(frame, width, height, name) then
            offer(frame, 7, "Forever 42px cluster frame")
        end
        if visible and width >= 24 and width <= 64
            and height >= 24 and height <= 64 and #notes < 12 then
            notes[#notes + 1] = tostring(name or frame:GetObjectType())
                .. " " .. math.floor(width) .. "x" .. math.floor(height)
                .. " art=" .. (#artEntries > 0 and table.concat(artEntries, ",") or "none")
        end
        if frame.GetChildren then
            for _, child in ipairs({frame:GetChildren()}) do
                pending[#pending + 1] = {child, depth + 1}
            end
        end
    end
    offer(_G.GameTimeFrame, 8, "GameTimeFrame")
    -- Inspect siblings before deep marker pools so a busy minimap cannot
    -- consume the search budget before we reach its day/night control.
    local index = 1
    while index <= #pending and count < 300 do
        scan(pending[index][1], pending[index][2])
        index = index + 1
    end
    local parts = {}
    for object, candidate in pairs(candidates) do
        -- Hiding an owner already hides its children. Save and restore only
        -- that owner, so nested artwork keeps its own original visibility.
        local parent, covered = object, false
        for _ = 1, 8 do
            parent = parent and parent.GetParent and parent:GetParent()
            if not parent then break end
            if candidates[parent] then
                covered = true
                break
            end
        end
        if not covered then
            parts[#parts + 1] = {object = object, reason = candidate.reason}
        end
    end
    return parts, "not found; widgets: " .. table.concat(notes, "; ")
end

local dayNightHiding
local function restoreDayNightPart(button, part)
    if part.alpha ~= nil and button.GetAlpha and button:GetAlpha() == 0 then
        button:SetAlpha(part.alpha)
    end
    if part.shown then button:Show() end
end

local function hideDayNight(saved)
    if dayNightHiding then return end
    if InCombatLockdown and InCombatLockdown() then return end
    saved.dayNightParts = saved.dayNightParts or {}
    local now = GetTime()
    if not saved.dayNightRetryAt or now >= saved.dayNightRetryAt then
        local parts, diagnostic = findDayNightParts()
        saved.dayNightDiagnostic = diagnostic
        saved.dayNightRetryAt = now + 2
        for _, candidate in ipairs(parts) do
            local button = candidate.object
            if not saved.dayNightParts[button] then
                saved.dayNightParts[button] = {shown = button:IsShown(),
                    alpha = button.GetAlpha and button:GetAlpha(),
                    reason = candidate.reason}
            end
        end
    end
    dayNightHiding = true
    local hidden, failed, reasons = 0, 0, {}
    for button, part in pairs(saved.dayNightParts) do
        if button.__sqmTrayed then
            saved.dayNightParts[button] = nil
            pcall(restoreDayNightPart, button, part)
        else
            local ok, message = pcall(function()
                if button.SetAlpha and button:GetAlpha() ~= 0 then button:SetAlpha(0) end
                if button:IsShown() then button:Hide() end
            end)
            if ok then
                hidden = hidden + 1
                if #reasons < 3 then reasons[#reasons + 1] = part.reason end
                part.error = nil
            else
                failed = failed + 1
                if part.error ~= tostring(message) then
                    WalkMapExtras.DebugEvent("Game mini day/night hide: " .. tostring(message))
                    part.error = tostring(message)
                end
            end
        end
    end
    dayNightHiding = nil
    saved.dayNightState = hidden > 0 and ("hidden " .. hidden .. " control(s) ("
        .. table.concat(reasons, "; ") .. ")") or saved.dayNightDiagnostic
    if failed > 0 then saved.dayNightState = saved.dayNightState .. "; hide failures: " .. failed end
end

-- The terrain mask does not clip the engine's circular quest-area ring.
-- Its waffle-pattern edge is separate from both compass textures and the
-- blue quest areas. Only suppress the ring alpha while using square terrain.
local blobRingStates = setmetatable({}, {__mode = "k"})
local changingBlobRing
local function watchBlobRings(original)
    local state = blobRingStates[original]
    if state then return state end
    state = {}
    blobRingStates[original] = state
    -- Alpha alone did not hide the ring of a super-tracked quest, so the
    -- ring scalar (its size) is suppressed too, as BasicMinimap does.
    for _, pair in ipairs({{"Quest", "Alpha"}, {"Task", "Alpha"}, {"Arch", "Alpha"},
        {"Quest", "Scalar"}, {"Task", "Scalar"}, {"Arch", "Scalar"}}) do
        local kind, field = pair[1], pair[2]
        local method = "Set" .. kind .. "BlobRing" .. field
        if type(original[method]) == "function" then
            -- This client exports setters without getters. Use native value
            -- 1 until a getter or an observed client/addon write supplies it.
            -- Blob alphas behave like 0-255 here: restoring "1" left them
            -- invisible. 255 is full in either scale; the scalar is a size.
            local part = {method = method, requested = field == "Alpha" and 255 or 1}
            local getter = original["Get" .. kind .. "BlobRing" .. field]
            if type(getter) == "function" then
                local ok, alpha = pcall(getter, original)
                if ok and type(alpha) == "number" then part.requested = alpha end
            end
            state[#state + 1] = part
            if hooksecurefunc then
                pcall(hooksecurefunc, original, method, function(self, alpha)
                    if changingBlobRing or type(alpha) ~= "number" then return end
                    part.requested = alpha
                    -- Something re-showed the ring while square terrain
                    -- suppresses it: hide it again straight away.
                    if part.applied and alpha ~= 0 and not (InCombatLockdown and InCombatLockdown()) then
                        changingBlobRing = true
                        pcall(self[method], self, 0)
                        changingBlobRing = nil
                    end
                end)
            end
        end
    end
    return state
end

local function setBlobRings(original, suppressed)
    if InCombatLockdown and InCombatLockdown() then return end
    local count, failed = 0, 0
    for _, part in ipairs(watchBlobRings(original)) do
        if suppressed or part.applied then
            changingBlobRing = true
            local ok, message = pcall(original[part.method], original, suppressed and 0 or part.requested)
            changingBlobRing = nil
            if ok then
                part.applied, part.error = suppressed, nil
                count = count + 1
            else
                failed = failed + 1
                if part.error ~= tostring(message) then
                    part.error = tostring(message)
                    WalkMapExtras.DebugEvent("Game mini area ring: " .. part.method .. ": " .. part.error)
                end
            end
        end
    end
    nativeState.blobRings = suppressed and ("suppressed " .. count .. " type(s)") or "restored"
    if failed > 0 then nativeState.blobRings = nativeState.blobRings .. "; failures=" .. failed end
end

-- Settings > Quest areas also applies to the game minimap's own quest areas:
-- with Hide areas, the client's area fill, outside shading and ring are set
-- to alpha 0 on the round or square minimap. Other modes leave them alone.
local areaStates = setmetatable({}, {__mode = "k"})
local changingArea
local function watchAreaParts(original)
    local state = areaStates[original]
    if state then return state end
    state = {}
    areaStates[original] = state
    for _, kind in ipairs({"Quest", "Task", "Arch"}) do
        for _, field in ipairs({"InsideAlpha", "OutsideAlpha"}) do
            local method = "Set" .. kind .. "Blob" .. field
            if type(original[method]) == "function" then
                -- No getters: restore to the game's usual look, edges only.
                -- Inside (fill) 0; outside (edge shading) 255, full in a
                -- 0-255 or clamped 0-1 scale. Observed client writes win.
                local part = {method = method, requested = field == "InsideAlpha" and 0 or 255}
                state[#state + 1] = part
                if hooksecurefunc then
                    pcall(hooksecurefunc, original, method, function(self, alpha)
                        if changingArea or type(alpha) ~= "number" then return end
                        part.requested = alpha
                        if part.applied and alpha ~= 0 and not (InCombatLockdown and InCombatLockdown()) then
                            changingArea = true
                            pcall(self[method], self, 0)
                            changingArea = nil
                        end
                    end)
                end
            end
        end
    end
    return state
end

local function setAreaParts(original, suppressed)
    if InCombatLockdown and InCombatLockdown() then return false end
    local count, failed = 0, 0
    for _, part in ipairs(watchAreaParts(original)) do
        if suppressed or part.applied then
            changingArea = true
            local ok, message = pcall(original[part.method], original, suppressed and 0 or part.requested)
            changingArea = nil
            if ok then
                part.applied, part.error = suppressed, nil
                count = count + 1
            else
                failed = failed + 1
                if part.error ~= tostring(message) then
                    part.error = tostring(message)
                    WalkMapExtras.DebugEvent("Game mini areas: " .. part.method .. ": " .. part.error)
                end
            end
        end
    end
    nativeState.blobAreas = (suppressed and ("hidden " .. count .. " part(s)") or "game default")
        .. (failed > 0 and ("; failures=" .. failed) or "")
    return true
end

local areasHidden, ringsHiddenForAreas = false, false
local function applyAreaSetting(original)
    local hide = WalkMapExtras.AreaMode() == "off" or squareFocusMode()
    if hide == areasHidden then return end
    if not setAreaParts(original, hide) then return end
    areasHidden = hide
    if hide then
        setBlobRings(original, true)
        ringsHiddenForAreas = true
    elseif ringsHiddenForAreas then
        ringsHiddenForAreas = false
        -- Square terrain keeps its own ring suppression.
        if not liveShape then setBlobRings(original, false) end
    end
end

local dayNightWidgetHooks = setmetatable({}, {__mode = "k"})
local function maintainLiveLayout(saved)
    if InCombatLockdown and InCombatLockdown() then return end
    setBlobRings(saved.original, true)
    for decoration in pairs(saved.compassLayers or {}) do
        if decoration:GetAlpha() ~= 0 then pcall(decoration.SetAlpha, decoration, 0) end
    end
    local mask = currentMask(saved.original)
    if mask and mask ~= squareMask then
        local ok, message = pcall(setMask, saved.original, squareMask)
        if not ok then WalkMapExtras.DebugEvent("Game mini square mask: " .. tostring(message)) end
        if ok then queueTerrainRefresh(saved.original, "square mask reapplied") end
    end
    local ok, message = pcall(hideDayNight, saved)
    if not ok then
        WalkMapExtras.DebugEvent("Game mini day/night: " .. tostring(message))
    end
    for button in pairs(saved.dayNightParts or {}) do
        if not dayNightWidgetHooks[button] then
            -- Hide again if the native layout shows its control. Keep every
            -- original anchor, scale and parent intact for the normal minimap.
            local function afterShow()
                if dayNightHiding or not liveShape
                    or not liveShape.dayNightParts[button] then return end
                local success, errorMessage = pcall(hideDayNight, liveShape)
                if not success then
                    WalkMapExtras.DebugEvent("Game mini day/night hide: " .. tostring(errorMessage))
                end
            end
            local hooked = false
            if button.HookScript then
                hooked = pcall(button.HookScript, button, "OnShow", afterShow)
            end
            for _, method in ipairs({"Show", "SetAlpha"}) do
                if hooksecurefunc and button[method] then
                    local success = pcall(hooksecurefunc, button, method, afterShow)
                    hooked = success or hooked
                end
            end
            dayNightWidgetHooks[button] = hooked
        end
    end
end

local function restoreLiveLayout(saved)
    local original = saved.original
    if saved.clamped ~= nil then
        if saved.clampInsets and original.SetClampRectInsets then
            pcall(original.SetClampRectInsets, original,
                saved.clampInsets[1], saved.clampInsets[2],
                saved.clampInsets[3], saved.clampInsets[4])
        end
        pcall(original.SetClampedToScreen, original, saved.clamped)
    end
    for parent in pairs(saved.clipping or {}) do
        pcall(parent.SetClipsChildren, parent, true)
    end
    for button, part in pairs(saved.dayNightParts or {}) do
        pcall(restoreDayNightPart, button, part)
    end
end

local function restoreLiveShape()
    if not liveShape then return end
    if InCombatLockdown and InCombatLockdown() then return end
    local saved, original = liveShape, liveShape.original
    -- Another addon may have resized the minimap since WalkMap did. Leave
    -- its new dimensions alone instead of overwriting them on mode change.
    local ownsSize = math.abs(original:GetWidth() - saved.size) < 0.5
        and math.abs(original:GetHeight() - saved.size) < 0.5
    if ownsSize then
        local ok, message = pcall(original.SetSize, original,
            saved.width, saved.height)
        if not ok then WalkMapExtras.DebugEvent("Game mini size restore: " .. tostring(message)) end
    end
    -- Restore our mask even if somebody resized the native minimap. Size
    -- ownership must not leave the terrain using WalkMap's square mask.
    local mask = currentMask(original)
    if not mask or mask == squareMask then
        local ok, message = pcall(setMask, original, saved.mask)
        if not ok then WalkMapExtras.DebugEvent("Game mini mask restore: " .. tostring(message)) end
    end
    for frame, wasShown in pairs(saved.decoration) do
        if wasShown then pcall(frame.Show, frame) end
    end
    for decoration, alpha in pairs(saved.compassLayers or {}) do
        if decoration:GetAlpha() == 0 then pcall(decoration.SetAlpha, decoration, alpha) end
    end
    if not ringsHiddenForAreas then setBlobRings(original, false) end
    liveShape = nil
    restoreLiveLayout(saved)
    liveBorder:Hide()
    if liveFrame then liveFrame:Hide() end
    queueTerrainRefresh(original, "native minimap restored")
end

local function applyLiveShape(original)
    if liveShape and liveShape.original == original then return end
    if InCombatLockdown and InCombatLockdown() then return end
    if liveShape then restoreLiveShape() end
    local w, h = original:GetWidth(), original:GetHeight()
    if not w or not h or w < 60 or h < 60 then return end
    watchMask(original)
    local mask, maskSource = restoreMask(currentMask(original)), "captured mask"
    if not mask and original.__sqmBorder then
        -- Miniminimap already uses a square mask; preserve it on exit.
        mask, maskSource = squareMask, "existing square minimap"
    elseif not mask then
        mask, maskSource = roundMask, "game round mask"
    end
    local decoration = {}
    for _, frame in pairs({_G.MinimapBorder, _G.MinimapBorderTop}) do
        if frame then decoration[frame] = frame:IsShown() end
    end
    local compassLayers = {}
    for _, name in ipairs({"MinimapCompassTexture", "MinimapCompassTextureUnderlay"}) do
        local texture = _G[name]
        if texture and texture.GetAlpha then compassLayers[texture] = texture:GetAlpha() end
    end
    local size = math.floor(math.max(w, h) * 1.32 + 0.5)
    local saved = {original = original, width = w, height = h,
        size = size, mask = mask, maskSource = maskSource, decoration = decoration,
        compassLayers = compassLayers, clipping = {}}
    if original.IsClampedToScreen and original.SetClampedToScreen then
        saved.clamped = original:IsClampedToScreen()
        if original.GetClampRectInsets and original.SetClampRectInsets then
            saved.clampInsets = {original:GetClampRectInsets()}
        end
    end
    -- A fixed-size container may also clip the enlarged native widget.
    -- Temporarily let that widget draw beyond such containers, not UIParent.
    local ancestor = original:GetParent()
    for _ = 1, 5 do
        if not ancestor or ancestor == UIParent then break end
        if ancestor.DoesClipChildren and ancestor.SetClipsChildren
            and ancestor:DoesClipChildren() then
            saved.clipping[ancestor] = true
        end
        ancestor = ancestor.GetParent and ancestor:GetParent()
    end
    local ok, message = pcall(function()
        if saved.clamped ~= nil then
            if saved.clampInsets then original:SetClampRectInsets(0, 0, 0, 0) end
            original:SetClampedToScreen(true)
        end
        for parent in pairs(saved.clipping) do parent:SetClipsChildren(false) end
        setMask(original, squareMask)
        original:SetSize(size, size)
        for frame in pairs(decoration) do frame:Hide() end
        for texture in pairs(compassLayers) do texture:SetAlpha(0) end
    end)
    if not ok then
        pcall(original.SetSize, original, w, h)
        pcall(setMask, original, mask)
        for frame, wasShown in pairs(decoration) do
            if wasShown then pcall(frame.Show, frame) end
        end
        for texture, alpha in pairs(compassLayers) do pcall(texture.SetAlpha, texture, alpha) end
        restoreLiveLayout(saved)
        WalkMapExtras.DebugEvent("Game mini shape: " .. tostring(message))
        return
    end
    liveShape = saved
    maintainLiveLayout(saved)
    if not original.__sqmBorder then liveBorder:Show() end
    if liveFrame then liveFrame:SetShown(not original.__sqmBorder and liveBorder:IsVisible()) end
    queueTerrainRefresh(original, "game terrain enabled")
    WalkMapExtras.DebugEvent("Game mini square: " .. size .. "x" .. size)
end

local function hideMarkers()
    hideFocusArea()
    topArrow:Hide()
    for _, copies in pairs(pools) do
        for _, marker in pairs(copies) do
            if marker:IsShown() then marker:Hide() end
        end
    end
end

local function vectorXY(point)
    if point.GetXY then return point:GetXY() end
    return point.x, point.y
end

local function worldBounds(mapID)
    if boundsMap == mapID and boundsInstance and mapXWorldX and mapYWorldY
        and GetTime() - boundsCheckedAt < 2 then
        return true
    end
    if boundsMap == mapID and GetTime() < boundsRetryAt then return false end
    boundsMap, boundsInstance, worldX0, worldY0 = mapID, nil, nil, nil
    mapXWorldX, mapXWorldY, mapYWorldX, mapYWorldY = nil, nil, nil, nil
    boundsRetryAt = GetTime() + 2
    if not C_Map or not C_Map.GetWorldPosFromMapPos then return false end
    local zero = CreateVector2D and CreateVector2D(0, 0) or {x = 0, y = 0}
    local right = CreateVector2D and CreateVector2D(1, 0) or {x = 1, y = 0}
    local bottom = CreateVector2D and CreateVector2D(0, 1) or {x = 0, y = 1}
    local id0, p0 = C_Map.GetWorldPosFromMapPos(mapID, zero)
    local idX, pX = C_Map.GetWorldPosFromMapPos(mapID, right)
    local idY, pY = C_Map.GetWorldPosFromMapPos(mapID, bottom)
    if not id0 or id0 ~= idX or id0 ~= idY or not p0 or not pX or not pY then
        return false
    end
    local x0, y0 = vectorXY(p0)
    local xx, xy = vectorXY(pX)
    local yx, yy = vectorXY(pY)
    if not x0 or not y0 or not xx or not xy or not yx or not yy then return false end
    local ax, ay, bx, by = xx - x0, xy - y0, yx - x0, yy - y0
    if math.abs(ax * by - ay * bx) < 0.001 then return false end
    boundsInstance, worldX0, worldY0 = id0, x0, y0
    mapXWorldX, mapXWorldY, mapYWorldX, mapYWorldY = ax, ay, bx, by
    boundsCheckedAt = GetTime()
    return true
end

local function pinArt(pin, kind)
    if kind == "quest" then
        return pin.miniVisible and pin.symbol
            and pin.symbol:GetTexture()
            or "Interface\\GossipFrame\\AvailableQuestIcon"
    elseif kind == "objective" then
        return pin.miniArt or (pin.icon and pin.icon:GetTexture())
    elseif kind == "service" or kind == "giver" or kind == "resource" then
        return pin.texture and pin.texture:GetTexture()
    elseif kind == "party" or kind == "friend" then
        return "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
    elseif kind == "waypoint" then
        return pin.miniArt
    end
end

local function positionPin(pin, index, copies, kind, playerX, playerY,
    factorX, factorY, visibleRadius, focusID, areaMode,
    focusObjectiveIcons, iconScale, iconRange, allowMarker, square)
        local marker = copies[index]
        local x, y = pin.mapPercentX, pin.mapPercentY
        local pinWorldX = x and y and worldX0 + mapXWorldX * x + mapYWorldX * y
        local pinWorldY = x and y and worldY0 + mapXWorldY * x + mapYWorldY * y
        local dx = pinWorldY and -(pinWorldY - playerY) * factorX
        local dy = pinWorldX and (pinWorldX - playerX) * factorY
        -- The waypoint stays on the minimap's edge when it is out of range.
        if kind == "waypoint" and dx and dy then
            local limit = visibleRadius - 8
            local reach = square and math.max(math.abs(dx), math.abs(dy))
                or math.sqrt(dx * dx + dy * dy)
            if limit > 0 and reach > limit then
                dx, dy = dx * limit / reach, dy * limit / reach
            end
        end
        local questAllowed = kind ~= "quest" or areaMode == "all"
            or (areaMode == "focus" and focusID > 0 and pin.questID == focusID)
            or rawget(pin, "ready") == true -- turn-ins always show
        -- 1.08 to 1.12.1 skipped the "?" here for quests in the game's own
        -- tracking list, on the theory that the game's minimap draws its own.
        -- It mostly does not (Bloom of the Heavens in Menethil had no "?" at
        -- all), so a turn-in is always drawn. Where the game does draw one,
        -- two "?" in different colours can appear; that is the lesser evil.
        local objectiveAllowed = kind ~= "objective" or not focusObjectiveIcons
            or (focusID > 0 and pin.questID == focusID)
        if questAllowed and objectiveAllowed
            and (pin.miniVisible or (pin.IsShown and pin:IsShown())) and dx and dy
            and (square and math.abs(dx) < visibleRadius
                and math.abs(dy) < visibleRadius
                or not square and dx * dx + dy * dy
                    < visibleRadius * visibleRadius)
            and (kind == "party" or kind == "friend" or kind == "waypoint" or dx * dx + dy * dy
                < (visibleRadius * iconRange) ^ 2 or iconRange >= 1) then
            local file = pinArt(pin, kind)
            if file and (kind == "party" or kind == "friend" or kind == "waypoint" or allowMarker(dx, dy, false)) then
                if not marker then
                    local priority = kind == "waypoint" and 6 or (kind == "party" or kind == "friend") and 5
                        or (kind == "quest" or kind == "objective") and 4
                        or kind == "giver" and 3 or 2
                    marker = layer:CreateTexture(nil, "OVERLAY", nil, priority)
                    copies[index] = marker
                    if kind == "party" then
                        marker:SetVertexColor(0.2, 0.6, 1)
                    end
                end
                local size = math.floor(((kind == "party" or kind == "friend") and 9 or kind == "waypoint" and 15 or 12)
                    * iconScale + 0.5)
                if marker.iconSize ~= size then
                    marker:SetSize(size, size)
                    marker.iconSize = size
                end
                if marker.iconFile ~= file then
                    marker:SetTexture(file)
                    marker.iconFile = file
                end
                if kind == "objective" or kind == "friend" then
                    -- Objectives: the large map's per-kind tint. Friends: class colour.
                    local color = pin.miniColor
                    if marker.tint ~= color then
                        if color then marker:SetVertexColor(color[1], color[2], color[3], 1)
                        else marker:SetVertexColor(1, 1, 1, 1) end
                        marker.tint = color
                    end
                elseif kind == "giver" then
                    -- Red "!" for a giver with only dungeon or raid quests,
                    -- as on the large map.
                    -- Orange for PvP-only givers.
                    local tint = rawget(pin, "giverTint")
                    if marker.tint ~= tint then
                        local color = WalkMapUI.GiverTint(tint)
                        marker:SetVertexColor(color[1], color[2], color[3], 1)
                        marker.tint = tint
                    end
                end
                -- Turn-in markers are drawn above all other minimap markers.
                if kind == "quest" then
                    local layer = rawget(pin, "ready") == true and 6 or 4
                    if marker.walkmapLayer ~= layer then
                        marker:SetDrawLayer("OVERLAY", layer)
                        marker.walkmapLayer = layer
                    end
                end
                local coords = rawget(pin, "iconCoords")
                if marker.coords ~= coords then
                    if coords then marker:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
                    else marker:SetTexCoord(0, 1, 0, 1) end
                    marker.coords = coords
                end
                if marker.px ~= dx or marker.py ~= dy then
                    marker:ClearAllPoints()
                    marker:SetPoint("CENTER", layer, "CENTER", dx, dy)
                    marker.px, marker.py = dx, dy
                end
                -- For the hover tooltips (WalkMap_MiniHover.lua).
                marker.walkmapPin, marker.walkmapKind = pin, kind
                if not marker:IsShown() then marker:Show() end
                if kind ~= "party" and kind ~= "friend" and kind ~= "waypoint" then allowMarker(dx, dy, true) end
            elseif marker then
                marker:Hide()
            end
        elseif marker and marker:IsShown() then
            marker:Hide()
        end
end

local function positionPool(originals, kind, playerX, playerY, factorX,
    factorY, visibleRadius, focusID, areaMode, focusObjectiveIcons,
    iconScale, iconRange, allowMarker, square)
    local copies = pools[kind]
    if not copies then copies = {}; pools[kind] = copies end
    local failures = 0
    for index, pin in ipairs(originals) do
        local ok, message = pcall(positionPin, pin, index, copies, kind,
            playerX, playerY, factorX, factorY, visibleRadius, focusID,
            areaMode, focusObjectiveIcons, iconScale, iconRange, allowMarker,
            square)
        if not ok then
            failures = failures + 1
            local marker = copies[index]
            if marker then pcall(marker.Hide, marker) end
            WalkMapExtras.DebugEvent("Game mini " .. kind .. " pin " .. index
                .. ": " .. tostring(message))
        end
    end
    for index, marker in pairs(copies) do
        if not originals[index] then pcall(marker.Hide, marker) end
    end
    return failures
end

local function refreshMarkers(original)
    local mapID, _, _, _, _, _, _, _, quests, objectives, party = source.Snapshot()
    if source.MiniPins then quests, objectives = source.MiniPins() end
    if not mapID or not worldBounds(mapID) or not UnitPosition
        or not C_Minimap or not C_Minimap.GetViewRadius then
        hideMarkers()
        return
    end
    -- Blizzard rotates the terrain in this setting. Keep its native markers,
    -- and skip WalkMap markers rather than display them at false locations.
    if GetCVarBool and GetCVarBool("rotateMinimap") then
        hideMarkers()
        return
    end
    local playerX, playerY, _, instance = UnitPosition("player")
    local radius = C_Minimap.GetViewRadius()
    if not playerX or not playerY or instance ~= boundsInstance
        or type(radius) ~= "number" or radius <= 0 then
        hideMarkers()
        return
    end
    -- On some zone/instance transitions the two game APIs briefly describe
    -- different spaces. In that state markers would appear to follow the
    -- player at an incorrect offset, so wait for consistent coordinates.
    local position = C_Map.GetPlayerMapPosition
        and C_Map.GetPlayerMapPosition(mapID, "player")
    local mapX, mapY
    if position then mapX, mapY = vectorXY(position) end
    if not mapX or not mapY or mapX < 0 or mapX > 1
        or mapY < 0 or mapY > 1 then
        hideMarkers()
        return
    end
    local expectedX = worldX0 + mapXWorldX * mapX + mapYWorldX * mapY
    local expectedY = worldY0 + mapXWorldY * mapX + mapYWorldY * mapY
    local errorX, errorY = expectedX - playerX, expectedY - playerY
    if errorX * errorX + errorY * errorY > math.max(12, radius * 0.25) ^ 2 then
        boundsInstance = nil
        boundsRetryAt = GetTime() + 1
        hideMarkers()
        return
    end
    local width, height = original:GetWidth(), original:GetHeight()
    if not width or not height or width <= 0 or height <= 0 then
        hideMarkers()
        return
    end
    local factorX, factorY = width / (2 * radius), height / (2 * radius)
    local visibleRadius = math.min(width, height) / 2 - 10
    do
        local ratio = (original.GetEffectiveScale and layer.GetEffectiveScale
            and original:GetEffectiveScale() / math.max(0.01, layer:GetEffectiveScale())) or 1
        local size = 32 * ratio
        if topArrow.size ~= size then topArrow:SetSize(size, size); topArrow.size = size end
        topArrow:SetRotation(GetPlayerFacing and GetPlayerFacing() or 0)
        topArrow:Show()
    end
    local focusQuest = source.FocusedQuestID and source.FocusedQuestID() or 0
    if squareFocusMode() and type(focusQuest) == "number" and focusQuest > 0
        and mapXWorldY and mapYWorldX and CreateFrame then
        local ok, message = pcall(function()
            -- Map (0,0) corner and size in minimap pixels around the player.
            local left = -(worldY0 - playerY) * factorX
            local top = (worldX0 - playerX) * factorY
            local mapW = math.abs(mapXWorldY * factorX)
            local mapH = math.abs(mapYWorldX * factorY)
            if mapW < 1 or mapH < 1 or mapW > 40000 or mapH > 40000 then hideFocusArea() return end
            if not focusBlob then
                focusBlob = CreateFrame("QuestPOIFrame", nil, areaClip)
                focusBlob:EnableMouse(false)
                if focusBlob.EnableGamePadButton then focusBlob:EnableGamePadButton(false) end
                focusBlob:SetFillTexture("Interface\\WorldMap\\UI-QuestBlob-Inside")
                focusBlob:SetBorderTexture("Interface\\WorldMap\\UI-QuestBlob-Outside")
                focusBlob:SetBorderScalar(1)
                -- Edges only: a fill covers the whole minimap when you
                -- stand inside the area.
                focusBlob:SetFillAlpha(0)
                focusBlob:SetBorderAlpha(215)
            end
            if areaClip.anchor ~= original then
                areaClip:ClearAllPoints()
                areaClip:SetAllPoints(original)
                areaClip.anchor = original
            end
            focusBlob:ClearAllPoints()
            focusBlob:SetPoint("TOPLEFT", areaClip, "CENTER", left, top)
            -- Redraw only when the quest, map or minimap scale changes.
            local key = focusQuest .. ":" .. mapID .. ":" .. math.floor(mapW + 0.5) .. "x" .. math.floor(mapH + 0.5)
            if key ~= focusBlobKey then
                focusBlob:SetSize(mapW, mapH)
                focusBlob:DrawNone()
                focusBlob:SetMapID(mapID)
                focusBlob:DrawBlob(focusQuest, true)
                focusBlobKey = key
            end
            areaClip:Show()
            focusBlob:Show()
        end)
        if not ok then
            hideFocusArea()
            nativeState.focusArea = "failed: " .. tostring(message)
        else
            nativeState.focusArea = "quest " .. focusQuest
        end
    else
        hideFocusArea()
        nativeState.focusArea = nil
    end
    local services, givers, resources
    if source.MiniServices then services, givers, resources = source.MiniServices()
    else services, givers, resources = WalkMapExtras.MiniMapPins() end
    local areaMode = WalkMapExtras.AreaMode()
    local focusID = source.FocusedQuestID and source.FocusedQuestID() or 0
    if type(focusID) ~= "number" then focusID = 0 end
    local focusedOnly = WalkMapExtras.FocusObjectiveIcons()
    local liveTerrain = WalkMapExtras.MiniMap()
        and WalkMapExtras.MiniTerrain() == "game"
    local iconScale, iconGap, iconRange = WalkMapExtras.MiniIconStyle(not liveTerrain)
    local allowMarker = WalkMapExtras.MarkerGrid(iconGap)
    local waypoints = source.MiniWaypoints and source.MiniWaypoints() or {}
    local sharers = WalkMapFriends and WalkMapFriends.MiniPins and WalkMapFriends.MiniPins(mapID) or {}
    for _, entry in ipairs({{waypoints, "waypoint"}, {sharers, "friend"}, {quests, "quest"}, {objectives, "objective"},
        {givers, "giver"}, {services, "service"}, {resources, "resource"},
        {party, "party"}}) do
        local ok, message = pcall(positionPool, entry[1], entry[2],
            playerX, playerY, factorX, factorY, visibleRadius, focusID,
            areaMode, focusedOnly, iconScale, iconRange, allowMarker,
            liveTerrain and liveShape ~= nil)
        if not ok then
            for _, marker in pairs(pools[entry[2]] or {}) do marker:Hide() end
            WalkMapExtras.DebugEvent("Game mini " .. entry[2] .. ": " .. tostring(message))
        end
    end
end

local driver = CreateFrame("Frame", nil, UIParent)
local elapsed, layoutElapsed = 0, 0
driver:SetScript("OnUpdate", function(_, delta)
    layoutTick = layoutTick + 1
    local original = _G.Minimap
    if original and original.IsForbidden and original:IsForbidden() then
        nativeState.shown, nativeState.size = "unavailable", "unavailable"
        nativeState.refresh = "unavailable: protected widget"
        pendingTerrainRefresh = nil
        layer:Hide()
        return
    end
    if original then
        watchBlobRings(original)
        applyAreaSetting(original)
    end
    local liveTerrain = WalkMapExtras.MiniMap()
        and WalkMapExtras.MiniTerrain() == "game"
    if liveTerrain and original then
        applyLiveShape(original)
        layoutElapsed = layoutElapsed + delta
        if liveShape and layoutElapsed >= 0.25 then
            layoutElapsed = 0
            maintainLiveLayout(liveShape)
        end
    elseif liveShape then
        restoreLiveShape()
    end
    updateTerrainRefresh()
    if original then
        local ok, shown, size = pcall(function()
            if original.IsForbidden and original:IsForbidden() then return "unavailable", "unavailable" end
            return original:IsShown() and "on" or "off",
                string.format("%.0fx%.0f", original:GetWidth(), original:GetHeight())
        end)
        nativeState.shown, nativeState.size = ok and shown or "unavailable", ok and size or "unavailable"
    else
        nativeState.shown, nativeState.size = "missing", "missing"
    end
    local showIcons = liveTerrain or (WalkMapExtras.NativeIcons()
        and not WalkMapExtras.MiniMap())
    if not showIcons or not original
        or not original:IsShown()
        or (original.IsVisible and not original:IsVisible()) then
        layer:Hide()
        return
    end
    if layer.anchor ~= original then
        layer:ClearAllPoints()
        layer:SetPoint("CENTER", original, "CENTER", 0, 0)
        layer.anchor = original
    end
    local width, height = original:GetWidth(), original:GetHeight()
    if width ~= layer.width or height ~= layer.height then
        layer:SetSize(width, height)
        layer.width, layer.height = width, height
    end
    local level = original:GetFrameLevel() + 3
    if layer.level ~= level then layer:SetFrameLevel(level); layer.level = level end
    if not layer:IsShown() then layer:Show() end
    elapsed = elapsed + delta
    if elapsed >= 0.2 then
        elapsed = 0
        if not source.IsFullMapShown() then source.Refresh() end
    end
    -- Read-only world coordinates let markers follow Blizzard's own camera.
    -- API availability varies in the Forever beta; native icons always remain.
    local ok, message = pcall(refreshMarkers, original)
    if not ok then
        hideMarkers()
        WalkMapExtras.DebugEvent("Game mini refresh: " .. tostring(message))
    end
end)

-- Tooltips for these markers while the mouse is over them.
if WalkMapMiniHover then WalkMapMiniHover.Watch(layer, pools) end
