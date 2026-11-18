-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- Shared visible-layout routes for native SmartNavigation and custom D-pad use.
WalkMapNavigation = {}
local nav = WalkMapNavigation
local applied = setmetatable({}, {__mode = "k"})

local function point(button)
    if not button or not button:IsShown() or (button.IsVisible and not button:IsVisible())
        or (button.IsEnabled and not button:IsEnabled()) then return end
    local x, y = button:GetCenter()
    if type(x) ~= "number" or type(y) ~= "number" then return end
    local scale = button.GetEffectiveScale and button:GetEffectiveScale() or 1
    return {button = button, x = x * scale, y = y * scale}
end

function nav.Build(groups, columns)
    local visible = {}
    for _, group in ipairs(groups or {}) do
        local entries = {}
        for _, button in ipairs(group) do
            local entry = point(button)
            if entry then entries[#entries + 1] = entry end
        end
        if #entries > 0 then
            table.sort(entries, function(a, b)
                if columns then return a.y > b.y end
                return a.x < b.x
            end)
            visible[#visible + 1] = entries
        end
    end
    table.sort(visible, function(a, b)
        if columns then return a[1].x < b[1].x end
        return a[1].y > b[1].y
    end)
    local routes = {}
    local function nearest(group, entry)
        local best, distance
        for _, other in ipairs(group or {}) do
            local delta = math.abs(columns and other.y - entry.y or other.x - entry.x)
            if not distance or delta < distance then best, distance = other.button, delta end
        end
        return best or true
    end
    for g, group in ipairs(visible) do
        for i, entry in ipairs(group) do
            local previous = group[i - 1] and group[i - 1].button or true
            local following = group[i + 1] and group[i + 1].button or true
            if columns then
                routes[entry.button] = {up = previous, down = following,
                    left = nearest(visible[g - 1], entry), right = nearest(visible[g + 1], entry)}
            else
                routes[entry.button] = {left = previous, right = following,
                    up = nearest(visible[g - 1], entry), down = nearest(visible[g + 1], entry)}
            end
        end
    end
    return routes
end

function nav.Step(groups, current, direction, columns)
    local route = nav.Build(groups, columns)[current]
    local target = route and route[direction]
    return target and target ~= true and target or current
end

function nav.Settings(panel)
    local routes = nav.Build({panel.categories, panel.options}, true)
    local first, last
    for _, option in ipairs(panel.options) do
        if routes[option] then first = first or option;last = option end
    end
    for button, route in pairs(routes) do
        if route.up == true then route.up = panel.closeButton or true end
        if route.down == true then route.down = panel.doneButton or true end
        first, last = first or button, last or button
    end
    if panel.closeButton then routes[panel.closeButton] = {down = first or true} end
    if panel.doneButton then routes[panel.doneButton] = {up = last or true} end
    -- A list that can scroll: Up on its first row / Down on its last row stay
    -- on the row, and the panel scrolls (panel.walkmapScroll).
    local edges = panel.walkmapScrollEdges
    if edges then
        if edges.down and edges.last and routes[edges.last] then routes[edges.last].down = edges.last end
        if edges.up and edges.first and routes[edges.first] then routes[edges.first].up = edges.first end
    end
    return routes
end

function nav.Apply(routes)
    if (WalkMapCombat and WalkMapCombat.Locked()) or (InCombatLockdown and InCombatLockdown()) then
        return false, "deferred during combat"
    end
    if not SmartNavigation_AddJumpNavigationOverride or not SMART_NAV_INPUT_DIRECTION then
        return false, "native direction API unavailable"
    end
    for button, route in pairs(routes) do
        local previous = applied[button] or {}
        for _, key in ipairs({"left", "right", "up", "down"}) do
            local target = route[key] or true
            if previous[key] ~= target then
                -- Pass static frame references through the client's supported
                -- setter. Dynamic target callbacks can carry taint into focus.
                local ok, message = pcall(SmartNavigation_AddJumpNavigationOverride,
                    button, SMART_NAV_INPUT_DIRECTION[key:upper()], target)
                if not ok then return false, tostring(message) end
                previous[key] = target
            end
        end
        applied[button] = previous
    end
    return true
end
