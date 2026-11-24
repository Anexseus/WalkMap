-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- Native Forever navigation adapter for WalkMap's own frames only.
-- Uses the client's wrapped FrameShown/FrameHidden and SmartNavigation helpers.
-- Does not replace the world map, modify its keybind, or bind gamepad buttons.
WalkMapNativeController = {}
local native = WalkMapNativeController
local owner, callbacks, windows, controls
local registered, prepared = {}, {}
local failed, failureReason, inCall, busy, dirty = false, nil, false, false, true
local refreshGroups, nextPoll = false, 0
local lastStatus = "not initialized"
local attemptedCleanup = {}
local prepareIgnoredFrames
local pendingVisibility = {}
local closingForCombat = false
local panWindow, panButton, controlRows
local hintBar
local directionStatus = "not prepared"
local outgoing = setmetatable({}, {__mode = "k"})

local function log(message)
    if WalkMapExtras and WalkMapExtras.DebugEvent then
        WalkMapExtras.DebugEvent("Native controller: " .. tostring(message))
    end
end

local function restricted()
    -- Match the client's SecureHelper validator. Legacy combat lockdown is
    -- broader than its native-navigation restriction, including during the
    -- pre-restriction notification where native cleanup is explicitly allowed.
    if C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive
        and Enum and Enum.AddOnRestrictionType
        and Enum.AddOnRestrictionType.Combat ~= nil then
        local ok, active = pcall(C_RestrictedActions.IsAddOnRestrictionActive,
            Enum.AddOnRestrictionType.Combat)
        return not ok or active == true
    end
    return InCombatLockdown and InCombatLockdown() or false
end

local function manager()
    return GamepadMode and GamepadMode.FrameControlsManager
end

local function contains(frame)
    local m = manager()
    for _, shown in ipairs(m and m.shownFrames or {}) do
        if shown == frame then return true end
    end
    return false
end

local function fail(message)
    if not failed then log("using fallback: " .. tostring(message)) end
    failed, failureReason = true, tostring(message)
    dirty = true
end

local function call(object, method, ...)
    if restricted() then dirty = true return false end
    if not object or type(object[method]) ~= "function" then return false end
    local previous = inCall
    inCall = true
    local ok, value = pcall(object[method], object, ...)
    inCall = previous
    if not ok then fail(method .. ": " .. tostring(value)) end
    return ok, value
end

local function available()
    local m = manager()
    local missing = {}
    for _, entry in ipairs({
        {"SmartNavigationSecureHelper", SmartNavigationSecureHelper ~= nil},
        {"C_RestrictedActions", type(C_RestrictedActions) == "table"},
        {"FrameControlsManager", m ~= nil},
        {"SmartNavigation", SmartNavigation ~= nil},
        {"FrameShown", m and type(m.FrameShown) == "function"},
        {"FrameHidden", m and type(m.FrameHidden) == "function"},
        {"HandlePopupShown", m and type(m.HandlePopupShown) == "function"},
        {"RefreshButtonGroups", SmartNavigation and type(SmartNavigation.RefreshButtonGroups) == "function"},
        {"SetTargetButtonForFrame", SmartNavigation and type(SmartNavigation.SetTargetButtonForFrame) == "function"},
        {"MarkFrameIgnored", type(SmartNavigation_MarkFrameIgnored) == "function"},
        {"MarkFrameIgnoredContainerFrame", type(SmartNavigation_MarkFrameIgnoredContainerFrame) == "function"},
    }) do
        if not entry[2] then missing[#missing + 1] = entry[1] end
    end
    if #missing > 0 then
        return false, "missing native API: " .. table.concat(missing, ", ")
    end
    local ok, enabled = false, false
    if InputUtil and type(InputUtil.IsGamepadUIEnabled) == "function" then
        ok, enabled = pcall(InputUtil.IsGamepadUIEnabled)
    end
    if not ok or not enabled then return false, "game's Gamepad UI is off" end
    return true
end

local function notify()
    if callbacks and callbacks.Changed then callbacks.Changed() end
end

local function refreshActions()
    if WalkMapControllerActions then WalkMapControllerActions.Refresh() end
end

local function setTarget(frame, target)
    if target and target:IsShown() and not restricted() and SmartNavigation then
        call(SmartNavigation, "SetTargetButtonForFrame", frame, target)
    end
end

local function activeFrame()
    local m = manager()
    if not m or type(m.GetActiveFrame) ~= "function" then return nil end
    local ok, frame = pcall(m.GetActiveFrame, m)
    return ok and frame or nil
end

-- Move native focus to another open WalkMap window (map <-> quest log)
-- without closing anything. Returns true when the switch took effect.
local crossStatus = "not used"
local function focusWindow(frame, button)
    if restricted() or (WalkMapCombat and WalkMapCombat.Locked()) or not registered[frame] then return false end
    if frame == owner then
        call(manager(), "FrameShown", frame, false, true)
    else
        call(manager(), "HandlePopupShown", frame)
    end
    if button then setTarget(frame, button) end
    local switched = activeFrame() == frame
    crossStatus = (frame == owner and "to map: " or "to panel: ") .. (switched and "ok" or "not supported")
    return switched
end

local function outgoingAction(button, direction, action)
    if restricted() or (WalkMapCombat and WalkMapCombat.Locked())
        or not SmartNavigation_RegisterOutgoingDirNavCallback then return end
    local done = outgoing[button] or {}
    if done[direction] then return end
    local ok, message = pcall(SmartNavigation_RegisterOutgoingDirNavCallback, button,
        SMART_NAV_INPUT_DIRECTION[direction:upper()], action)
    if ok then done[direction] = true;outgoing[button] = done
    else log("direction callback: " .. tostring(message)) end
end

local function refreshDirections()
    if not WalkMapNavigation or (WalkMapCombat and WalkMapCombat.Locked()) then return end
    local function apply(routes)
        local ok, message = WalkMapNavigation.Apply(routes)
        directionStatus = ok and "visible rows and columns" or tostring(message)
    end
    if panButton then
        apply({[panButton] = {left = panButton, right = panButton, up = panButton, down = panButton}})
        for key, offset in pairs({left = {1, 0}, right = {-1, 0}, up = {0, -1}, down = {0, 1}}) do
            outgoingAction(panButton, key, function()
                if not restricted() and registered[panWindow] then callbacks.Pan(offset[1], offset[2]) end
            end)
        end
    end
    if callbacks.NavigationRows then
        local routes = WalkMapNavigation.Build(callbacks.NavigationRows())
        -- Right from the map's quest log button enters the open quest log.
        local questTab = WalkMapQuestLog and WalkMapQuestLog.Tab and WalkMapQuestLog.Tab()
        local questPanel = WalkMapQuestLog and WalkMapQuestLog.Panel and WalkMapQuestLog.Panel()
        if questTab and questPanel and questPanel:IsShown() and questTab:IsShown() then
            routes[questTab] = routes[questTab] or {}
            routes[questTab].right = questTab
            outgoingAction(questTab, "right", function()
                if not questPanel:IsShown() then return end
                local target = questPanel.walkmapSelectedRow or questPanel.walkmapNativeFirstButton
                if not focusWindow(questPanel, target) then
                    -- Fallback that is known to work: reopen the quest log.
                    native.SetVisible(questPanel, false)
                    native.SetVisible(questPanel, true)
                end
            end)
        end
        apply(routes)
    end
    for _, entry in ipairs(windows) do
        local panel = entry.frame
        if panel:IsVisible() and panel ~= panWindow then
            local routes
            if panel == controls then
                routes = WalkMapNavigation.Build(controlRows)
            elseif panel.categories and panel.options then
                routes = WalkMapNavigation.Settings(panel)
                -- Settings: Up/Down at the list's first/last row scroll it.
                if panel.walkmapScroll then
                    for _, option in ipairs(panel.options) do
                        for _, direction in ipairs({"up", "down"}) do
                            outgoingAction(option, direction, function()
                                if not registered[panel] then return end
                                local _, refocus = panel.walkmapScroll(option, direction)
                                if refocus and refocus ~= option then
                                    setTarget(panel, refocus)
                                    -- Once more after the button groups are rebuilt.
                                    if C_Timer and C_Timer.After then
                                        C_Timer.After(0.05, function()
                                            if registered[panel] and refocus:IsShown() then setTarget(panel, refocus) end
                                        end)
                                    end
                                end
                            end)
                        end
                    end
                end
                -- Panel-specific extra routes, e.g. quest log filter <-> close.
                for button, extra in pairs(panel.walkmapRouteOverrides or {}) do
                    if button:IsShown() then
                        routes[button] = routes[button] or {}
                        for direction, target in pairs(extra) do
                            if target == true or (target.IsShown and target:IsShown()) then
                                routes[button][direction] = target
                            end
                        end
                    end
                end
                -- Quest log: Left from the zone filter or an action button goes
                -- to the map's quest log button (the log stays open). Left
                -- and Right on a quest row turn the page instead.
                local questTab = WalkMapQuestLog and WalkMapQuestLog.Tab and WalkMapQuestLog.Tab()
                if panel.walkmapListItems and questTab then
                    local leftItems = {}
                    for _, item in ipairs(panel.categories) do leftItems[#leftItems + 1] = item end
                    for _, item in ipairs(panel.options) do
                        if item:IsShown() then leftItems[#leftItems + 1] = item end
                    end
                    -- With more than one page, Left and Right on a quest row
                    -- turn the page and keep the same row, looping from the
                    -- last page to the first and back. Returns nil when the
                    -- button is not a quest row.
                    local function turnPage(row, direction)
                        for index, listed in ipairs(panel.walkmapListItems or {}) do
                            if listed == row then
                                return registered[panel] and WalkMapQuestLog and WalkMapQuestLog.Page
                                    and panel.walkmapPageEdges
                                    and WalkMapQuestLog.Page(direction, true, index, true) == true or false
                            end
                        end
                        return nil
                    end
                    for _, item in ipairs(leftItems) do
                        routes[item] = routes[item] or {}
                        routes[item].left = item
                        outgoingAction(item, "left", function()
                            -- A quest row only turns pages. (It used to try the
                            -- map's quest log button, which never took focus.)
                            if turnPage(item, -1) ~= nil then return end
                            if registered[panel] and questTab:IsShown() then focusWindow(owner, questTab) end
                        end)
                    end
                    if (panel.walkmapPages or 1) > 1 then
                        for _, row in ipairs(panel.walkmapListItems) do
                            routes[row] = routes[row] or {}
                            routes[row].right = row
                            outgoingAction(row, "right", function() turnPage(row, 1) end)
                        end
                    end
                end
                -- Quest log paging: at the list's first/last row, Up/Down
                -- stays on the row and the outgoing callback turns the page.
                local edges = panel.walkmapPageEdges
                if edges then
                    for _, row in ipairs(panel.categories) do
                        local route = routes[row]
                        if route then
                            if row == edges.first then route.up = row end
                            if row == edges.last then route.down = row end
                        end
                        for _, direction in ipairs({"up", "down"}) do
                            outgoingAction(row, direction, function()
                                local current = panel.walkmapPageEdges
                                if not registered[panel] or not current or not WalkMapQuestLog then return end
                                if direction == "down" and row == current.last then
                                    WalkMapQuestLog.Page(1, true)
                                elseif direction == "up" and row == current.first then
                                    WalkMapQuestLog.Page(-1, true)
                                end
                            end)
                        end
                    end
                end
            elseif panel.rows then
                local rows = {}
                for _, row in ipairs(panel.rows) do rows[#rows + 1] = {row} end
                routes = WalkMapNavigation.Build(rows)
                for button, route in pairs(routes) do
                    local source = button
                    route.left = source
                    outgoingAction(source, "left", function()
                        if registered[panel] then native.SetVisible(panel, false) end
                    end)
                    if source.walkmapOpensSubmenu then route.right = source end
                    outgoingAction(source, "right", function()
                        if registered[panel] and source.walkmapOpensSubmenu then
                            local click = source:GetScript("OnClick")
                            if click then click(source, "LeftButton") end
                        end
                    end)
                end
            end
            if routes then apply(routes) end
        end
    end
end

local function closeWindow(frame)
    -- A panel can step back inside itself first (quest log: buttons -> list).
    if frame.walkmapOnBack and frame.walkmapOnBack() then return true end
    if frame == owner then
        if controls and controls:IsShown() then native.SetVisible(controls, false)
        else native.SetVisible(frame, false) end
    else native.SetVisible(frame, false) end
    return true
end

local function prepareWindow(frame)
    if prepared[frame] or restricted() then return end
    prepared[frame] = true
    -- All callbacks only change WalkMap frames. The client runs these across
    -- its own callback boundary; no manager internals are replaced or hooked.
    frame.SmartNavigationCloseHandler = closeWindow
    frame.FocusGamepad = function()
        if WalkMapControllerActions then WalkMapControllerActions.Focus(true) end
        notify()
    end
    frame.UnfocusGamepad = function()
        if WalkMapControllerActions then WalkMapControllerActions.Focus(false) end
        notify()
    end

end

local function register(frame, popup)
    if registered[frame] or restricted() then return end
    prepareWindow(frame)
    local ok
    if popup then ok = call(manager(), "HandlePopupShown", frame)
    else ok = call(manager(), "FrameShown", frame, false, true) end
    if contains(frame) then registered[frame] = true end
    if not ok or not registered[frame] then
        fail("client did not register the WalkMap window")
    else
        local first = native.FirstTarget(frame)
        if first then setTarget(frame, first) end
    end
end

-- Where the controller starts in a window: its first button, or - when that
-- button is hidden (the map's Buttons menu) - the first visible button of the
-- map's rows, so focus never lands on a button that is not there.
function native.FirstTarget(frame)
    local first = frame.walkmapNativeFirstButton or (frame.rows and frame.rows[1])
    if first and first.IsShown and first:IsShown() then return first end
    if frame == owner and callbacks.NavigationRows then
        for _, row in ipairs(callbacks.NavigationRows()) do
            for _, target in ipairs(row) do
                if target and target.IsShown and target:IsShown() then return target end
            end
        end
    end
    return first
end

local function unregister(frame)
    if not registered[frame] then return end
    if restricted() then dirty = true return end
    -- A rejected native call must never become an automatic retry loop.
    if failed and attemptedCleanup[frame] then return end
    attemptedCleanup[frame] = failed or nil
    call(manager(), "FrameHidden", frame)
    if not contains(frame) then
        registered[frame] = nil
        attemptedCleanup[frame] = nil
    end
end

local function anyRegistered()
    return next(registered) ~= nil
end

function native.OwnsInput()
    return anyRegistered() or inCall
end

-- True only while the game's focus cursor is actually on a WalkMap window.
function native.HasFocus()
    local m = manager()
    if not m or not m.isUIFocused or not m.GetActiveFrame then return false end
    local ok, active = pcall(m.GetActiveFrame, m)
    return ok and active ~= nil and registered[active] == true
end

-- Map control hint; nil restores the default text.
local PAN_HINT = "D-pad: move   LB/RB: zoom   Y: markers   A: open/waypoint   X/B: back"
function native.SetPanHint(text)
    if panWindow and panWindow.hint then panWindow.hint:SetText(WalkMapL(text or PAN_HINT)) end
end

function native.Status()
    if lastStatus == "native SmartNavigation" then
        local m = manager()
        if m and m.isUIFocused and registered[m:GetActiveFrame()] then
            return lastStatus .. "; WalkMap focused"
        end
        return lastStatus .. "; gameplay or another window focused"
    end
    return lastStatus
end

function native.RequestRefresh()
    refreshGroups, dirty = true, true
end

function native.UsesNativeNavigation()
    return WalkMapCharacterSettings.nativeController ~= false and not failed and available()
end

function native.Diagnostics()
    local supported, reason = available()
    local m = manager()
    local active
    if m and type(m.GetActiveFrame) == "function" then
        local ok, frame = pcall(m.GetActiveFrame, m)
        if ok and frame and frame.GetName then
            local named, name = pcall(frame.GetName, frame)
            active = named and (name or "unnamed window") or "unreadable"
        end
    end
    local count = 0
    for _ in pairs(registered) do count = count + 1 end
    local pending = 0
    for _ in pairs(pendingVisibility) do pending = pending + 1 end
    return "available=" .. tostring(supported) .. "; " .. tostring(reason or "API ready")
        .. "; restricted=" .. tostring(restricted()) .. "; registered=" .. count
        .. "; UI focused=" .. tostring(m and m.isUIFocused or false)
        .. "; active=" .. tostring(active or "none")
        .. "; lockdown=" .. tostring(InCombatLockdown and InCombatLockdown() or false)
        .. "; pending visibility=" .. pending
        .. "; last combat action=" .. tostring(WalkMapCharacterSettings.lastNativeCombatAction or "none")
        .. "; combat map=" .. (WalkMapCombat and WalkMapCombat.Diagnostics() or "unavailable")
        .. "; directions=" .. directionStatus .. "; map<->quest log=" .. crossStatus
        .. "; map pan=" .. tostring(panWindow and panWindow:IsShown() or false)
        .. "; shortcuts=" .. (WalkMapControllerActions and WalkMapControllerActions.Diagnostics() or "unavailable")
end

function native.SetVisible(frame, shown)
    if not shown and not frame:IsShown() then return true end
    -- Free window (game gamepad UI off at load): no native navigation; it
    -- opens and closes directly, also in combat.
    if WalkMapCombat and WalkMapCombat.Free() then
        if shown then frame:Show() else frame:Hide() end
        return true
    end
    -- In combat WalkMap's own menus and quest log open and close directly,
    -- for the mouse only. They are not handed to the game's controller
    -- navigation (restricted in combat); native.Update picks up any that
    -- are still open once combat ends.
    if frame ~= owner and not registered[frame] and frame.walkmapCombatPanel
        and (restricted() or (WalkMapCombat and WalkMapCombat.Locked())) then
        if shown then frame:Show() else frame:Hide() end
        return true
    end
    if (restricted() or (WalkMapCombat and WalkMapCombat.Locked()))
        and (prepared[owner] or (frame == owner and WalkMapCombat and WalkMapCombat.Ready())) then
        if frame == owner then
            print(WalkMapL("|cff80ff80WalkMap:|r " .. (shown and "Use your bound WalkMap key to open the map during combat."
                or "Use your WalkMap key or the X button to close the map during combat.")))
        end
        return false
    end
    if shown and frame == owner and restricted() and prepared[owner] then
        -- SmartNavigation's native OnHide hook remains attached after the
        -- panel unregisters. Reopening it during a restriction would leave an
        -- unclosable window, even if we temporarily used custom navigation.
        pendingVisibility[frame] = nil
        log("open request declined while native navigation is restricted")
        print(WalkMapL("|cff80ff80WalkMap:|r Reopen WalkMap after combat; its native UI is currently restricted."))
        return false
    end
    -- Hiding a registered panel also runs the client's own focus cleanup.
    -- Queue voluntary window changes while addon focus changes are restricted.
    if restricted() and anyRegistered() then
        pendingVisibility[frame] = shown
        if frame == owner and not shown then
            for _, entry in ipairs(windows) do pendingVisibility[entry.frame] = false end
        end
        dirty = true
        return false
    end
    if shown then frame:Show() else frame:Hide() end
    return true
end

local function applyPendingVisibility()
    local changes = pendingVisibility
    pendingVisibility = {}
    for i = #windows, 1, -1 do
        local frame = windows[i].frame
        if changes[frame] == false then frame:Hide() end
    end
    if changes[owner] == false then owner:Hide()
    elseif changes[owner] == true then owner:Show() end
    if owner:IsVisible() then
        for _, entry in ipairs(windows) do
            local frame = entry.frame
            local parent = frame:GetParent()
            if changes[frame] == true and (not parent or parent:IsVisible()) then frame:Show() end
        end
    end
end

function native.IsSelecting(frame)
    if not anyRegistered() or not SmartNavigation
        or type(SmartNavigation.GetCurrentButton) ~= "function" then return false end
    local ok, current = pcall(SmartNavigation.GetCurrentButton, SmartNavigation)
    return ok and current == frame
end

function native.Update()
    if not owner or busy or inCall or closingForCombat then return anyRegistered() or inCall end
    busy = true
    local supported, reason = available()
    if restricted() or (WalkMapCombat and WalkMapCombat.Passive() and WalkMapCombat.Locked()) then
        lastStatus = WalkMapCombat and WalkMapCombat.Passive() and "passive map during combat"
            or anyRegistered() and "native; focus changes deferred in combat"
            or "custom fallback during combat"
        dirty = true
        busy = false
        return anyRegistered()
    end
    if WalkMapCombat and WalkMapCombat.Passive() then WalkMapCombat.SetPassive(false) end
    applyPendingVisibility()
    -- The client may reset its manager during an input-style transition.
    for frame in pairs(registered) do
        if not contains(frame) then
            registered[frame] = nil
        end
    end
    local wanted = not (WalkMapCombat and WalkMapCombat.Free())
        and WalkMapCharacterSettings.nativeController ~= false
        and WalkMapExtras.ControllerMode() and owner:IsShown() and supported and not failed
    if prepareIgnoredFrames then prepareIgnoredFrames() end
    -- "Select keeps the map released": a map opened while released stays out
    -- of the game's window list until Select asks for it (ToggleUIFocus hook
    -- below). Never by writing fields the game reads (skipGamepadAutoFocus):
    -- an addon-written value there tainted the game's UI focus state, and
    -- the next Select was blocked (SetPreferredGamepadInteractTarget).
    local heldBack = WalkMapExtras.MapReleased() and not registered[owner]
    if wanted and not heldBack then
        refreshDirections()
        for _, entry in ipairs(windows) do prepareWindow(entry.frame) end
        register(owner, false)
        if registered[owner] and not failed then
            -- Track only WalkMap's open menus as native popup windows.
            for _, entry in ipairs(windows) do
                if entry.frame:IsVisible() then register(entry.frame, true)
                else unregister(entry.frame) end
            end
        end
    end
    if not wanted or failed then
        for i = #windows, 1, -1 do unregister(windows[i].frame) end
        unregister(owner)
        if controls then controls:Hide() end
        if panWindow then panWindow:Hide() end
    end
    if registered[owner] and not failed then
        lastStatus = "native SmartNavigation"
        if refreshGroups then
            local m = manager()
            local current = m and m:GetActiveFrame()
            if registered[current] then call(SmartNavigation, "RefreshButtonGroups", current) end
        end
    elseif failed then
        lastStatus = (anyRegistered() and "native cleanup incomplete; reload UI: "
            or "custom fallback: ") .. tostring(failureReason)
    elseif not WalkMapCharacterSettings.nativeController then lastStatus = "custom (selected)"
    elseif not WalkMapExtras.ControllerMode() then lastStatus = "Pad focus off"
    elseif not supported then lastStatus = "custom fallback: " .. tostring(reason)
    elseif not owner:IsShown() then lastStatus = "native ready; WalkMap closed"
    else lastStatus = "custom fallback: " .. tostring(reason) end
    refreshGroups, dirty, busy = false, false, false
    refreshActions()
    return anyRegistered()
end

local function closeBeforeCombatRestriction()
    if owner and not restricted() and WalkMapCombat and WalkMapCombat.Ready() then
        -- Prepare the child shield while writes are still permitted, including
        -- when the map is closed and may be opened by a secure combat click.
        WalkMapCombat.SetPassive(true)
    end
    if not owner or (not anyRegistered() and not prepared[owner]
        and not (WalkMapCombat and WalkMapCombat.Ready() and owner:IsShown()))
        or (not owner:IsShown() and not anyRegistered()) then return end
    -- ADDON_RESTRICTION_STATE_CHANGED is dispatched before enforcement.
    -- Do not attempt this cleanup later from PLAYER_REGEN_DISABLED, when
    -- SmartNavigation's native OnHide callback may already be restricted.
    if restricted() then
        WalkMapCharacterSettings.lastNativeCombatAction = "restriction was already active; cleanup deferred"
        log(WalkMapCharacterSettings.lastNativeCombatAction)
        dirty = true
        return
    end
    closingForCombat = true
    pendingVisibility = {}
    local keepOpen = WalkMapCombat and WalkMapCombat.Ready() and owner:IsShown()
    if keepOpen then
        WalkMapCombat.SetPassive(true)
        if owner.EnableGamePadButton then owner:EnableGamePadButton(false) end
        if owner.StopMovingOrSizing then owner:StopMovingOrSizing() end
    end
    WalkMapCharacterSettings.lastNativeCombatAction = keepOpen
        and "map kept open; native focus released before combat" or "closed before native combat restriction"
    log(WalkMapCharacterSettings.lastNativeCombatAction)
    -- Hide child panels before the owner so none reappear on the next open.
    for i = #windows, 1, -1 do windows[i].frame:Hide() end
    unregister(owner)
    if not keepOpen then owner:Hide() end
    closingForCombat = false
    dirty = true
    -- Enforcement has not begun yet: avoid immediately registering the still
    -- visible owner again during this same synchronous transition.
    if not keepOpen then native.Update() end
    notify()
end

local function watch(frame, popup, returnFrame, returnButton)
    if popup then windows[#windows + 1] = {frame = frame} end
    frame:HookScript("OnShow", function()
        dirty = true
        local before = registered[frame]
        native.Update()
        if not before and registered[frame] then
            local first = native.FirstTarget(frame)
            if first then setTarget(frame, first) end
        end
        notify()
    end)
    frame:HookScript("OnHide", function()
        unregister(frame)
        dirty = true
        if returnFrame and registered[returnFrame] then
            local button = returnButton
            if type(button) == "function" then button = button() end
            setTarget(returnFrame, button)
        end
        notify()
    end)
end

local function createControls()
    controls = CreateFrame("Frame", nil, owner)
    controls:SetSize(302, 276)
    controls:SetPoint("CENTER", owner, "CENTER", 0, 0)
    controls:SetFrameStrata("TOOLTIP")
    controls:SetFrameLevel(owner:GetFrameLevel() + 22)
    controls:SetClampedToScreen(true)
    controls:EnableMouse(true)
    WalkMapUI.Window(controls)
    local title = controls:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", controls, "TOP", 0, -10)
    title:SetText(WalkMapL("WalkMap controls"))
    local function button(text, x, y, width, action)
        local b = CreateFrame("Button", nil, controls)
        b:SetSize(width, 26)
        b:SetPoint("TOPLEFT", controls, "TOPLEFT", x, y)
        b:EnableMouse(true)
        WalkMapExtras.StyleButton(b)
        local label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("CENTER")
        label:SetText(WalkMapL(text))
        b:SetScript("OnClick", action)
        return b
    end
    local zoomOut = button("Zoom -", 12, -37, 88,
        function() callbacks.Zoom(-1) end)
    local player = button("Player", 107, -37, 88, callbacks.Center)
    local zoomIn = button("Zoom +", 202, -37, 88, function() callbacks.Zoom(1) end)
    local up = button("Up", 107, -73, 88, function() callbacks.Pan(0, -1) end)
    local left = button("Left", 12, -105, 88, function() callbacks.Pan(1, 0) end)
    local down = button("Down", 107, -105, 88, function() callbacks.Pan(0, 1) end)
    local right = button("Right", 202, -105, 88, function() callbacks.Pan(-1, 0) end)
    local previous = button("Previous pin", 12, -149, 88, function() callbacks.Pin(-1) end)
    local details = button("Details", 107, -149, 88, callbacks.Details)
    local nextPin = button("Next pin", 202, -149, 88, function() callbacks.Pin(1) end)
    local hidePin = button("Hide pin", 12, -190, 135, callbacks.HidePin)
    local done = button("Done", 155, -190, 135, function() native.SetVisible(controls, false) end)
    controls.walkmapNativeFirstButton = zoomOut
    controlRows = {{zoomOut, player, zoomIn}, {up}, {left, down, right},
        {previous, details, nextPin}, {hidePin, done}}
    local note = controls:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("BOTTOM", controls, "BOTTOM", 0, 19)
    note:SetWidth(278)
    note:SetJustifyH("CENTER")
    note:SetText(WalkMapL("X: pan map. Use the game's focus button for skills."))
    controls:Hide()
    controls:HookScript("OnHide", callbacks.ClosePins)
end

local function createPanWindow()
    if not callbacks.Viewport or not WalkMapNavigation
        or not SmartNavigation_AddJumpNavigationOverride
        or not SmartNavigation_RegisterOutgoingDirNavCallback then return end
    panWindow = CreateFrame("Frame", nil, owner)
    panWindow:SetAllPoints(callbacks.Viewport)
    panWindow:SetFrameLevel(owner:GetFrameLevel() + 20)
    panWindow:EnableMouse(false)
    panButton = CreateFrame("Button", nil, panWindow)
    panButton:SetAllPoints(panWindow)
    panButton:EnableMouse(false)
    panButton.OnSmartNavClick = callbacks.PanActivate or callbacks.Center
    for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
        local edge = panButton:CreateTexture(nil, "OVERLAY")
        edge:SetColorTexture(1, 0.82, 0.3, 0.9)
        if side == "TOP" or side == "BOTTOM" then
            edge:SetPoint(side .. "LEFT", panButton, side .. "LEFT", 0, 0)
            edge:SetPoint(side .. "RIGHT", panButton, side .. "RIGHT", 0, 0)
            edge:SetHeight(2)
        else
            edge:SetPoint("TOP" .. side, panButton, "TOP" .. side, 0, 0)
            edge:SetPoint("BOTTOM" .. side, panButton, "BOTTOM" .. side, 0, 0)
            edge:SetWidth(2)
        end
    end
    -- Top edge: the bottom edge holds the waypoint/nearest-location badge.
    local hint = panButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", panButton, "TOPLEFT", 6, -7)
    hint:SetPoint("TOPRIGHT", panButton, "TOPRIGHT", -6, -7)
    hint:SetHeight(14)
    hint:SetJustifyH("CENTER")
    hint:SetWordWrap(false)
    hint:SetShadowColor(0, 0, 0, 1)
    hint:SetShadowOffset(1, -1)
    panWindow.hint = hint
    native.SetPanHint(nil)
    panWindow.walkmapNativeFirstButton = panButton
    panWindow:HookScript("OnShow", function()
        native.SetPanHint(nil)
        if callbacks.PanMode then callbacks.PanMode(true) end
    end)
    panWindow:HookScript("OnHide", function()
        if callbacks.PanMode then callbacks.PanMode(false) end
    end)
    panWindow:Hide()
end

-- Button hints: one line at the top of the map that says what A, B, X and Y
-- do where the controller focus is right now. Only shown while the game's
-- focus cursor is on a WalkMap window. The frame itself stays shown; only
-- its regions are toggled, so nothing changes visibility on a frame in combat.
local HINTS = {
    main = "A: choose   B: close map   X: map control   Y: quest log",
    log = "A: choose   B: back   Y: close quest log   Left/Right: page",
    menu = "A: choose   B: back",
}
local function createHintBar()
    if not callbacks.Viewport then return end
    hintBar = CreateFrame("Frame", nil, owner)
    hintBar:SetPoint("TOPLEFT", callbacks.Viewport, "TOPLEFT", 0, 0)
    hintBar:SetPoint("TOPRIGHT", callbacks.Viewport, "TOPRIGHT", 0, 0)
    hintBar:SetHeight(20)
    hintBar:SetFrameLevel(owner:GetFrameLevel() + 19)
    hintBar:EnableMouse(false)
    hintBar.back = hintBar:CreateTexture(nil, "BACKGROUND")
    hintBar.back:SetAllPoints(hintBar)
    hintBar.back:SetColorTexture(0, 0, 0, 0.55)
    hintBar.text = hintBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hintBar.text:SetPoint("LEFT", hintBar, "LEFT", 6, 0)
    hintBar.text:SetPoint("RIGHT", hintBar, "RIGHT", -6, 0)
    hintBar.text:SetJustifyH("CENTER")
    hintBar.text:SetWordWrap(false)
    hintBar.text:SetTextColor(1, 0.82, 0.35)
    hintBar.text:SetShadowColor(0, 0, 0, 1)
    hintBar.text:SetShadowOffset(1, -1)
    hintBar.back:Hide()
    hintBar.text:Hide()
end

-- True while the game's controller focus cursor is on the interface (not the
-- character). The hidden mouse pointer can still rest over a button then.
function native.PadFocused()
    local m = manager()
    return not failed and m ~= nil and m.isUIFocused == true
end

-- "main", "log", "menu" or nil (no hint; map control has its own line).
function native.HintContext()
    local m = manager()
    if failed or not owner or not owner:IsVisible() or not WalkMapExtras.ControllerMode()
        or not m or not m.isUIFocused then return nil end
    local active = activeFrame()
    if not active or not registered[active] then return nil end
    if active == owner then return "main" end
    if panWindow and active == panWindow then return nil end
    local questLog = WalkMapQuestLog and WalkMapQuestLog.Panel and WalkMapQuestLog.Panel()
    if questLog and active == questLog then return "log" end
    local _, _, menu, submenu, settings = WalkMapExtras.ControllerControls()
    -- Settings has its own controller line at the bottom.
    if active == settings then return nil end
    if active == menu or active == submenu or active == controls then return "menu" end
    return nil
end

local function updateHint()
    if not hintBar then return end
    local context = WalkMapExtras.ControllerHints and WalkMapExtras.ControllerHints()
        and native.HintContext()
    local text = context and HINTS[context] or nil
    if text then hintBar.text:SetText(WalkMapL(text)) end
    hintBar.back:SetShown(text ~= nil)
    hintBar.text:SetShown(text ~= nil)
end
native.UpdateHint = updateHint

function native.TogglePan()
    if not panWindow or restricted() or (WalkMapCombat and WalkMapCombat.Locked()) then return end
    if panWindow:IsShown() then native.SetVisible(panWindow, false)
    else
        WalkMapExtras.CloseMenus()
        if controls:IsShown() then native.SetVisible(controls, false) end
        native.SetVisible(panWindow, true)
    end
end

-- Register another WalkMap popup (e.g. the quest log) for native focus.
-- Panels with .categories/.options get the Settings column routes.
-- Move native focus to a button in a registered WalkMap panel.
function native.FocusButton(panel, button)
    if registered[panel] then setTarget(panel, button) end
end

function native.WatchPanel(panel, returnButton)
    if not owner or not windows then return false end
    watch(panel, true, owner, returnButton)
    return true
end

function native.Init(frame, handlers, ignore, firstButton, controlsButton)
    owner, callbacks, windows = frame, handlers, {}
    createControls()
    createPanWindow()
    createHintBar()
    watch(owner, false)
    local _, view, menu, submenu, settings = WalkMapExtras.ControllerControls()
    menu.walkmapNativeFirstButton = menu.rows and menu.rows[1]
    settings.walkmapNativeFirstButton = settings.categories and settings.categories[1]
    watch(menu, true, owner, function() return menu.from end)
    watch(submenu, true, menu, function() return submenu.parentRow end)
    watch(settings, true, owner, view)
    watch(controls, true, owner, controlsButton)
    if panWindow then
        watch(panWindow, true, owner, controlsButton)
        if WalkMapControllerActions then
            WalkMapControllerActions.Init({TogglePan = native.TogglePan, Zoom = callbacks.Zoom,
                NextMarker = callbacks.NextMarker,
                QuestLog = function() if WalkMapQuestLog and WalkMapQuestLog.Toggle then WalkMapQuestLog.Toggle() end end,
                FocusMode = function()
                    local m = manager()
                    if failed or restricted() or not owner:IsVisible() or not WalkMapExtras.ControllerMode()
                        or not m or not m.isUIFocused then return end
                    local active = m:GetActiveFrame()
                    if active == panWindow and registered[panWindow] then return "pan" end
                    if (active == owner or active == controls) and registered[active] then return "main" end
                    local questLog = WalkMapQuestLog and WalkMapQuestLog.Panel and WalkMapQuestLog.Panel()
                    if questLog and active == questLog and registered[active] then return "log" end
                end})
        end
    end
    owner.walkmapNativeFirstButton = firstButton
    -- Mark only our canvas/decorations, through Blizzard's allowed setters.
    prepareIgnoredFrames = function()
        if restricted() or not available() then return end
        for _, item in ipairs(ignore) do
            if not item.prepared then
                local fn = item.container and SmartNavigation_MarkFrameIgnoredContainerFrame
                    or SmartNavigation_MarkFrameIgnored
                local ok, message = pcall(fn, item.frame)
                if ok then item.prepared = true; refreshGroups = true else fail(message) end
            end
        end
    end
    local driver = CreateFrame("Frame")
    for _, event in ipairs({"PLAYER_LOGIN", "ADDON_LOADED", "PLAYER_REGEN_ENABLED",
        "PLAYER_REGEN_DISABLED", "GAME_PAD_ACTIVE_CHANGED", "ADDON_ACTION_BLOCKED",
        "ADDON_ACTION_FORBIDDEN"}) do driver:RegisterEvent(event) end
    if Enum and Enum.AddOnRestrictionState then
        driver:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
    end
    driver:SetScript("OnEvent", function(_, event, addon, action)
        if event == "ADDON_RESTRICTION_STATE_CHANGED" then
            if addon == Enum.AddOnRestrictionType.Combat then
                if action ~= Enum.AddOnRestrictionState.Inactive then
                    closeBeforeCombatRestriction()
                else
                    log("native combat restriction ended")
                    dirty = true
                end
            end
        elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
            log(event .. "; native restriction=" .. tostring(restricted()))
            dirty = true
        elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
            local text = tostring(action or "")
            -- A block while WalkMap closes the game's map or quest log comes
            -- from that redirect, not from native navigation: keep native.
            if addon == "WalkMap" and not inCall and WalkMapQuestLog
                and WalkMapQuestLog.Intercepting and WalkMapQuestLog.Intercepting() then
                WalkMapQuestLog.InterceptBlocked()
                log("blocked while closing the game's window: " .. text)
            elseif addon == "WalkMap" and (inCall or anyRegistered())
                and (inCall or text:find("SetPreferredGamepadInteractTarget", 1, true)
                    or text:find("RunBinding", 1, true) or text:find("DescendStop", 1, true)
                    or text:find("SmartNavigation", 1, true)) then
                fail(event .. ": " .. text)
            end
        else dirty = true end
    end)
    -- "Select keeps the map released": remember when the player leaves the
    -- map for gameplay (Select, or a click in the world) and when the map
    -- gets focus again. Only a change from "map focused" to "gameplay"
    -- counts, and never around combat (WalkMap itself releases focus then).
    local wasFocused = false
    local function watchRelease()
        if not WalkMapExtras.SelectKeepsReleased() or not owner:IsShown() or not registered[owner]
            or (InCombatLockdown and InCombatLockdown()) or restricted()
            or (WalkMapCombat and (WalkMapCombat.Locked() or WalkMapCombat.Passive())) then
            wasFocused = false
            return
        end
        local m = manager()
        if native.HasFocus() then
            if WalkMapExtras.MapReleased() then WalkMapExtras.SetMapReleased(false) end
            wasFocused = true
        elseif wasFocused and m and m.isUIFocused == false then
            WalkMapExtras.SetMapReleased(true)
            wasFocused = false
            -- Out of the game's window list until Select asks for it, as
            -- when the map opens released. Otherwise the game hands focus
            -- back to the map when another window closes (talking to an
            -- NPC), and the map was selected again.
            for i = #windows, 1, -1 do unregister(windows[i].frame) end
            unregister(owner)
            -- Keep WalkMap's own controller fallback paused too.
            if WalkMapCore and WalkMapCore.UpdatePadMode then pcall(WalkMapCore.UpdatePadMode) end
        end
    end
    native.WatchRelease = watchRelease
    -- Select (the game's ToggleUIFocus) while the map is open but held back:
    -- take the map. Runs after the game's own code (hooksecurefunc), and
    -- registers the map the normal way, which focuses it.
    -- With nothing registered the game has just printed its red "No
    -- interface frame to focus!" for that Select press. WalkMap takes the
    -- map right after, so the message is wrong: clear it. Blanking only its
    -- line (SetText) did not stick in game - the message frame redraws its
    -- lines - so the error frame is cleared (its own method; no Blizzard
    -- fields written). Any other red line shown in that same moment goes
    -- too, which is rare and harmless.
    local function hideNoFrameError()
        local errors, id, text = UIErrorsFrame, LE_GAME_ERR_SYSTEM, ERROR_NO_FRAME_TO_FOCUS
        if not (errors and text) then return end
        local line
        if errors.GetFontStringByID and id then
            local ok, found = pcall(errors.GetFontStringByID, errors, id)
            if ok then line = found end
        end
        local shown = line and line.GetText and line:GetText()
        if shown and shown ~= text and not tostring(shown):find(text, 1, true) then return end
        if errors.Clear then pcall(errors.Clear, errors)
        elseif line then pcall(line.SetText, line, "") end
    end
    native.HideNoFrameError = hideNoFrameError
    -- Group windows the game keeps in its window list (the raid/party
    -- manager on the left edge). Being leftmost, the game focuses them first
    -- when Select brings focus back, and again whenever the group changes
    -- (it re-adds the window). While the map is open the controller never
    -- stays on them: focus goes back to the map (outside combat).
    local GROUP_WINDOWS = {"CompactRaidFrameManager"}
    local function groupWindow(frame)
        if not frame then return false end
        for _, name in ipairs(GROUP_WINDOWS) do
            if frame == _G[name] then return true end
        end
        return false
    end
    -- Move focus to the map the way the game's own windows get it: take the
    -- map out of the list and put it back (FrameHidden/FrameShown, both
    -- taint-wrapped by the game). Never by setting the manager's fields.
    local function preferMap()
        if (InCombatLockdown and InCombatLockdown()) or restricted() then return end
        local m = manager()
        if not (m and m.isUIFocused and registered[owner] and owner:IsShown()) then return end
        local focused = m.focusedFrame
        if focused == owner or registered[focused] or not groupWindow(focused) then return end
        unregister(owner)
        if not registered[owner] then register(owner, false) end
    end
    native.PreferMap = preferMap
    -- The game re-adds (and focuses) the group window when the group
    -- changes: put the map back in front right after.
    if hooksecurefunc and manager() and type(manager().FrameShown) == "function" then
        pcall(hooksecurefunc, manager(), "FrameShown", function(_, frame)
            if not groupWindow(frame) or inCall then return end
            -- With no window in the game's list (the map held back while
            -- released) the group window turns Select into "open me", so
            -- the Select hook never runs: this is that Select - take the map.
            if not registered[owner] and native.AfterToggle then native.AfterToggle()
            else preferMap() end
        end)
    end
    -- Reaching the group window (LB/RB) while the map is open: the game's
    -- group window sits on a lower layer (MEDIUM) than the map (HIGH) and
    -- would open behind it. While it has the controller the map steps down
    -- a layer; it comes back up as soon as focus leaves. Only WalkMap's own
    -- frame changes, never outside combat lockdown.
    local mapStrata, lowered
    local function updateGroupLayer()
        local m = manager()
        local want = m and m.isUIFocused and owner:IsShown() and groupWindow(m.focusedFrame) or false
        if want == (lowered or false) then return end
        if InCombatLockdown and InCombatLockdown() then return end
        if want then
            mapStrata = owner:GetFrameStrata() or "HIGH"
            owner:SetFrameStrata("LOW")
            lowered = true
        else
            owner:SetFrameStrata(mapStrata or "HIGH")
            lowered = nil
        end
    end
    native.UpdateGroupLayer = updateGroupLayer
    local function afterToggle()
        if (InCombatLockdown and InCombatLockdown()) or restricted() then return end
        if registered[owner] then preferMap() return end
        if not WalkMapExtras.MapReleased() or not owner:IsShown() then return end
        local m = manager()
        -- The player just left another focused window for gameplay: leave it.
        if m and m.isUIFocused == false and m.shownFrames and #m.shownFrames > 0 then return end
        if m and m.shownFrames and #m.shownFrames == 0 then hideNoFrameError() end
        WalkMapExtras.SetMapReleased(false)
        native.Update()
        preferMap()
        -- Let the map's footer and hints catch up (no Resume button).
        if WalkMapCore and WalkMapCore.UpdatePadMode then pcall(WalkMapCore.UpdatePadMode) end
    end
    native.AfterToggle = afterToggle
    if hooksecurefunc and manager() and type(manager().ToggleUIFocus) == "function" then
        pcall(hooksecurefunc, manager(), "ToggleUIFocus", afterToggle)
    end
    driver:SetScript("OnUpdate", function()
        local now = GetTime()
        if now < nextPoll then return end
        nextPoll = now + 0.2
        preferMap()
        updateGroupLayer()
        if dirty or owner:IsShown() or anyRegistered() then
            native.Update()
            notify()
        end
        watchRelease()
        updateHint()
    end)
    native.Update()
end
