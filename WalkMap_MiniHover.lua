-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- Tooltips for the markers on WalkMap's minimaps. The markers are plain
-- textures (cheap to draw, and nothing that could block the game minimap's
-- own clicks), so they cannot take mouse events themselves. Instead a small
-- driver looks at what is under the mouse a few times a second and shows
-- the same kind of information the large map shows for that marker.
--
-- WalkMap_Mini.lua and WalkMap_MiniNative.lua hand in their marker pools
-- with hover.Watch, and stamp each shown marker with the map pin it stands
-- for (marker.walkmapPin) and its kind (marker.walkmapKind).
WalkMapMiniHover = {}
local hover = WalkMapMiniHover
local watched = {}

-- frame: something that is visible exactly when these markers are.
-- pools: [kind] = {marker textures}.
function hover.Watch(frame, pools)
    watched[#watched + 1] = {frame = frame, pools = pools}
end

-- The shown marker nearest the point, within its own radius plus a little.
-- x, y are screen pixels as GetCursorPosition gives them. scale is the
-- effective scale of the frame the markers are drawn on (a texture has the
-- scale of its frame; not every client lets a texture report it itself).
function hover.Find(pools, x, y, scale)
    local best, bestDistance
    scale = (type(scale) == "number" and scale > 0) and scale or 1
    for _, markers in pairs(pools) do
        for _, marker in pairs(markers) do
            if rawget(marker, "walkmapPin") and marker:IsShown() then
                local cx, cy = marker:GetCenter()
                if cx and cy then
                    local reach = math.max(8, (marker:GetWidth() or 12) / 2 + 3)
                    local dx, dy = x / scale - cx, y / scale - cy
                    local distance = dx * dx + dy * dy
                    if distance <= reach * reach and (not bestDistance or distance < bestDistance) then
                        best, bestDistance = marker, distance
                    end
                end
            end
        end
    end
    return best
end

-- What to say about a marker: a title and a list of {text, r, g, b} lines.
-- nil when there is nothing useful to say.
function hover.Describe(pin, kind)
    if type(pin) ~= "table" then return nil end
    local lines = {}
    local function add(text, r, g, b)
        if type(text) == "string" and text ~= "" then lines[#lines + 1] = {text, r or 0.9, g or 0.85, b or 0.5} end
    end
    local title
    if kind == "giver" or kind == "service" or kind == "resource" then
        title = rawget(pin, "pinName")
        add(rawget(pin, "detail"))
    elseif kind == "quest" then
        title = rawget(pin, "questTitle")
        if rawget(pin, "ready") == true then
            local where = rawget(pin, "turnInName")
            add("Ready to turn in" .. (type(where) == "string" and (": " .. where) or ""), 1, 0.85, 0.2)
        end
    elseif kind == "objective" then
        -- One marker can stand for several objectives in the same spot.
        local entries = rawget(pin, "entries")
        if type(entries) == "table" and #entries > 0 then
            title = entries[1].objectiveName or rawget(pin, "objectiveName")
            add(entries[1].questTitle, 0.8, 0.8, 0.8)
            for index = 2, math.min(#entries, 5) do
                local entry = entries[index]
                add(tostring(entry.objectiveName or "Objective")
                    .. (entry.questTitle and ("  -  " .. entry.questTitle) or ""))
            end
            if #entries > 5 then add("+ " .. (#entries - 5) .. " more", 0.7, 0.7, 0.7) end
        else
            title = rawget(pin, "objectiveName")
            add(rawget(pin, "questTitle"), 0.8, 0.8, 0.8)
        end
    elseif kind == "friend" then
        -- The same lines as the dot on the large map (WalkMap_Friends.lua).
        title = rawget(pin, "pinName")
        local rows = rawget(pin, "lines")
        if type(rows) == "table" then
            for index = 2, #rows do add(rows[index].text, rows[index].r or 0.9, rows[index].g or 0.9, rows[index].b or 0.9) end
        end
    elseif kind == "waypoint" then
        title = rawget(pin, "pinName") or rawget(pin, "label") or "Waypoint"
        add(rawget(pin, "detail"))
    end
    if type(title) ~= "string" or title == "" then return nil end
    return title, lines
end

-- WalkMap's own tooltip frame. The game's shared GameTooltip is not used:
-- over the minimap the game shows and hides that one itself (for its own
-- blips), which would wipe ours the moment it appeared.
local tip
local function tooltip()
    if tip == nil then
        local ok, frame = pcall(CreateFrame, "GameTooltip", "WalkMapMiniTooltip", UIParent, "GameTooltipTemplate")
        tip = ok and frame or false
        if tip then
            tip:SetFrameStrata("TOOLTIP")
            if tip.SetClampedToScreen then tip:SetClampedToScreen(true) end
        end
    end
    return tip or nil
end

local state = {checks = 0, markers = 0, found = 0, shownCount = 0}
local shown -- the marker whose tooltip is up
local function hide()
    if shown then
        shown = nil
        if tip then tip:Hide() end
    end
end

local function show(marker, x, y)
    local frame = tooltip()
    if not frame then state.problem = "no tooltip frame" return end
    local title, lines = hover.Describe(rawget(marker, "walkmapPin"), rawget(marker, "walkmapKind"))
    if not title then hide() return end
    shown = marker
    local scale = UIParent:GetEffectiveScale()
    local px, py = x / scale, y / scale
    frame:SetOwner(UIParent, "ANCHOR_NONE")
    frame:ClearAllPoints()
    -- Away from the screen edge the minimap usually sits at.
    if px > (UIParent:GetWidth() or 0) / 2 then
        frame:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", px - 14, py - 6)
    else
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", px + 14, py - 6)
    end
    frame:SetText(title, 1, 0.82, 0)
    for _, line in ipairs(lines) do frame:AddLine(line[1], line[2], line[3], line[4]) end
    frame:Show()
    state.shownCount, state.last = state.shownCount + 1, title
end

-- For /walkmap debug: is the hover check running, and what did it see.
function hover.Status()
    local total = 0
    for _, entry in ipairs(watched) do
        for _, markers in pairs(entry.pools) do
            for _, marker in pairs(markers) do
                if rawget(marker, "walkmapPin") and marker:IsShown() then total = total + 1 end
            end
        end
    end
    return string.format("%d minimaps, %d markers shown, %d checks, under mouse %d times, tooltips %d%s%s",
        #watched, total, state.checks, state.found, state.shownCount,
        state.last and (", last " .. tostring(state.last)) or "",
        state.problem and (", PROBLEM: " .. tostring(state.problem)) or "")
end

-- With a controller the mouse pointer is often hidden and just resting over
-- the minimap while markers slide under it. A tooltip only starts when the
-- mouse itself moved a moment ago; it then stays while it is on the marker.
local lastX, lastY, movedAt = nil, nil, -100
local elapsed = 0
local function check()
    state.checks = state.checks + 1
    local x, y = GetCursorPosition()
    local now = GetTime and GetTime() or 0
    if x ~= lastX or y ~= lastY then
        if lastX then movedAt = now end
        lastX, lastY = x, y
    end
    if IsMouseButtonDown and (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")) then
        hide()
        return
    end
    local found
    for _, entry in ipairs(watched) do
        if entry.frame:IsVisible() then
            found = hover.Find(entry.pools, x, y, entry.frame:GetEffectiveScale())
            if found then break end
        end
    end
    if not found then hide() return end
    state.found = state.found + 1
    -- Still on the same marker: leave the tooltip up (and put it back if
    -- something else closed it).
    if found == shown and tip and tip:IsShown() then return end
    if found ~= shown and now - movedAt > 3 then hide() return end
    show(found, x, y)
end
local driver = CreateFrame("Frame", nil, UIParent)
driver:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + (delta or 0)
    if elapsed < 0.08 then return end
    elapsed = 0
    local ok, message = pcall(check)
    if not ok and state.problem ~= tostring(message) then
        state.problem = tostring(message)
        if WalkMapExtras and WalkMapExtras.DebugEvent then
            WalkMapExtras.DebugEvent("Minimap tooltips: " .. tostring(message))
        end
    end
end)
