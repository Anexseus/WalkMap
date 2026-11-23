-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- WalkMap's wheel for combat (Settings > Controller & help, "WalkMap's
-- wheel in combat").
--
-- The game's wheel (GamepadRadial, opened by the OPENRADIAL binding) runs
-- its entries as addon-free game code, but its Quest & Maps entry only
-- clicks the game's quest log button, and in a fight nothing may open or
-- close WalkMap's protected map except a real key press. So in combat the
-- key that opens the game's wheel opens this one instead: a copy of the
-- wheel's main page (same entries, same places, the game's own art), whose
-- Quest & Maps clicks WalkMapKeyboardToggle. Out of combat nothing changes.
--
-- How it stays allowed in combat:
--   * The swap is a secure state driver ([combat]): its snippet binds the
--     wheel's key to our toggle as a fight starts and clears it after.
--   * The wheel is an explicitly protected frame; secure snippets show and
--     hide it and bind A, B and the right stick's four directions while it
--     is open.
--   * Choosing runs a secure macro button ("/click CharacterMicroButton",
--     "/click WalkMapKeyboardToggle", ...): what a macro may do in combat.
--     A wrapped OnClick snippet reads the right stick (GetGamePadState, part
--     of the secure environment) to find the entry, like the game's wheel:
--     point and let go, or point and press A.
--   * The art is a plain child frame (shown with the wheel); it reads the
--     stick each frame for the highlight. It is never protected.
WalkMapCombatWheel = {}
local cw = WalkMapCombatWheel

local SEGMENT_ANGLE = 45
local HIGHLIGHT_DISTANCE = 150
local ICON_DISTANCE = 100
local TEXT_ANCHOR = {
    {60, 0}, {30, 45}, {0, 60}, {-30, 45}, {-60, 0}, {-30, -45}, {0, -60}, {30, -45},
}

-- The game's main page, counter-clockwise from east (GamepadRadial.lua
-- mainMenuPages[2]). button: the game's button the macro clicks.
local ENTRIES = {
    {key = "bags", label = "RADIAL_LABEL_BAGS", fallback = "Bags", button = "MainMenuBarBackpackButton"},
    {key = "professions", label = "RADIAL_LABEL_PROFESSIONS", fallback = "Professions", button = "ProfessionMicroButton"},
    {key = "character", label = "RADIAL_LABEL_CHARACTER", fallback = "Character", button = "CharacterMicroButton"},
    {key = "talents", label = "RADIAL_LABEL_TALENTS", fallback = "Talents", button = "TalentMicroButton"},
    {key = "quests", label = "RADIAL_LABEL_QUEST_MAPS", fallback = "Quest & Maps", map = true},
    -- The game's Chat entry gives the chat window controller focus; no
    -- macro can do that, so it is greyed out here.
    {key = "chat", label = "RADIAL_LABEL_CHAT", fallback = "Chat"},
    {key = "gamemenu", label = "RADIAL_LABEL_GAME_MENU", fallback = "Game Menu", button = "MainMenuMicroButton"},
    {key = "spellbook", label = "RADIAL_LABEL_SPELLBOOK", fallback = "Spellbook", button = "SpellbookMicroButton"},
}

local header, wheel, art, toggle, pick, close
local ready, lastError, keys, guessed, stickIndex = false, nil, {}, false, 2
local opened = 0
local AXIS_CVAR, savedAxis = "GamePadStickAxisButtons", nil

local function locked() return InCombatLockdown and InCombatLockdown() == true end
local function enabled()
    return WalkMapExtras and WalkMapExtras.CombatWheel and WalkMapExtras.CombatWheel() == true
        and not (WalkMapCombat and WalkMapCombat.Free and WalkMapCombat.Free())
end

-- True while WalkMap's wheel takes over in combat (then the game's quest log
-- button need not be greyed out, see WalkMap_WheelCombat.lua).
function cw.Active() return ready and enabled() and #keys > 0 end

local function label(entry)
    local text = _G[entry.label]
    return type(text) == "string" and text ~= "" and text or entry.fallback
end

local function macroFor(entry)
    if entry.map then
        -- Inside a dungeon with "Game map in dungeons": the game's map.
        if WalkMapExtras and WalkMapExtras.HandOffDungeonMap and WalkMapExtras.HandOffDungeonMap() then
            return "/click QuestLogMicroButton"
        end
        return "/click WalkMapKeyboardToggle"
    end
    if entry.button then return "/click " .. entry.button end
    return nil
end

-- Keys bound to the game's wheel (its binding lives in the gamepad
-- binding context). Start when none is found.
local function findKeys()
    local found, seen = {}, {}
    local function add(...)
        for i = 1, select("#", ...) do
            local key = select(i, ...)
            if type(key) == "string" and key ~= "" and not seen[key] then
                seen[key] = true
                found[#found + 1] = key
            end
        end
    end
    if C_KeyBindings and C_KeyBindings.GetBindingContextForAction then
        local ok, context = pcall(C_KeyBindings.GetBindingContextForAction, "OPENRADIAL")
        if ok and context then
            local results = {pcall(GetBindingKey, "OPENRADIAL", nil, context)}
            if results[1] then add(unpack(results, 2)) end
        end
    end
    local results = {pcall(GetBindingKey, "OPENRADIAL")}
    if results[1] then add(unpack(results, 2)) end
    guessed = #found == 0
    if guessed then found[1] = "PADFORWARD" end
    return found
end

local function findStick()
    if not (C_GamePad and C_GamePad.GetDeviceMappedState and C_GamePad.StickIndexToConfigName) then return 2 end
    local ok, state = pcall(C_GamePad.GetDeviceMappedState)
    local count = ok and type(state) == "table" and state.stickCount or 2
    for i = 1, count do
        local okName, name = pcall(C_GamePad.StickIndexToConfigName, i - 1)
        if okName and name == "Camera" then return i end
    end
    return 2
end

-- Index (1-8) the stick points at, or nil when it is near the middle. The
-- same sums as the secure snippet below and the game's wheel.
local function aimed(x, y)
    if type(x) ~= "number" or type(y) ~= "number" or x * x + y * y < 0.15 then return nil end
    local degrees = math.deg(math.atan2(y, x))
    if degrees < -SEGMENT_ANGLE / 2 then degrees = degrees + 360 end
    local index = math.floor((degrees + SEGMENT_ANGLE) / SEGMENT_ANGLE + 0.5)
    if index > 8 then index = index - 8 end
    if index < 1 then index = 1 end
    return index
end
cw.Aimed = aimed

-- Out of combat: keys, stick and each entry's macro for the secure side.
local function refresh()
    if not ready or locked() then return end
    keys = enabled() and findKeys() or {}
    stickIndex = findStick()
    header:SetAttribute("enabled", enabled() or nil)
    for i = 1, 4 do header:SetAttribute("key-" .. i, keys[i]) end
    header:SetAttribute("key-count", math.min(#keys, 4))
    wheel:SetAttribute("stick", stickIndex)
    for i, entry in ipairs(ENTRIES) do wheel:SetAttribute("macro-" .. i, macroFor(entry)) end
end
cw.Refresh = function() pcall(refresh) end

local function entryEnabled(entry)
    if entry.map then return true end
    if not entry.button then return false end
    local b = _G[entry.button]
    if not b then return false end
    if b.IsEnabled then
        local ok, on = pcall(b.IsEnabled, b)
        if ok and on == false then return false end
    end
    return true
end

local function buildArt()
    art = CreateFrame("Frame", nil, wheel)
    art:SetSize(400, 590)
    art:SetPoint("CENTER", UIParent, "CENTER", 312, 0)
    art:SetFrameStrata("DIALOG")
    local bg = art:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("CENTER", 0, 10)
    if not (bg.SetAtlas and pcall(bg.SetAtlas, bg, "gamepad-radial-menu-wheelbg", true)) then
        bg:SetSize(400, 400)
        bg:SetColorTexture(0, 0, 0, 0.7)
    end
    art.bg = bg
    local title = art:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("BOTTOM", art, "TOP", 0, 25)
    title:SetText(type(FRAME_LABEL_MAIN_MENU) == "string" and FRAME_LABEL_MAIN_MENU or "Main Menu")
    local sub = art:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOP", title, "BOTTOM", 0, -6)
    sub:SetText("|cff80ff80WalkMap|r - in combat")
    local hint = art:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOP", art, "BOTTOM", 0, -6)
    hint:SetText("Right stick: point, let go or press A to choose.  B closes.")
    local highlight = art:CreateTexture(nil, "ARTWORK")
    if not (highlight.SetAtlas and pcall(highlight.SetAtlas, highlight, "gamepad-radial-menu-selected", true)) then
        highlight:SetSize(90, 90)
        highlight:SetColorTexture(1, 0.82, 0, 0.25)
    end
    highlight:Hide()
    art.highlight = highlight
    art.segments = {}
    for i, entry in ipairs(ENTRIES) do
        local rad = math.rad((i - 1) * SEGMENT_ANGLE)
        local segment = {}
        local disabled = art:CreateTexture(nil, "BORDER")
        if disabled.SetAtlas then pcall(disabled.SetAtlas, disabled, "gamepad-radial-menu-disabled", true) end
        disabled:SetPoint("CENTER", bg, "CENTER", HIGHLIGHT_DISTANCE * math.cos(rad), HIGHLIGHT_DISTANCE * math.sin(rad))
        if disabled.SetRotation then pcall(disabled.SetRotation, disabled, math.rad((i - 1) * SEGMENT_ANGLE - 270)) end
        disabled:Hide()
        local icon = art:CreateTexture(nil, "OVERLAY")
        icon:SetPoint("CENTER", bg, "CENTER", ICON_DISTANCE * math.cos(rad), ICON_DISTANCE * math.sin(rad))
        local text = art:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetSize(90, 40)
        text:SetWordWrap(true)
        text:SetPoint("CENTER", icon, "CENTER", TEXT_ANCHOR[i][1], TEXT_ANCHOR[i][2])
        text:SetText(label(entry))
        segment.icon, segment.text, segment.disabled, segment.entry = icon, text, disabled, entry
        art.segments[i] = segment
    end
    local function setIcon(segment, on)
        local icon = segment.icon
        local atlas = "gamepad-radial-icon-" .. segment.entry.key .. (on and "" or "-disabled")
        local ok = icon.SetAtlas and pcall(icon.SetAtlas, icon, atlas, false)
        if ok and C_Texture and C_Texture.GetAtlasInfo then
            local okInfo, info = pcall(C_Texture.GetAtlasInfo, atlas)
            if okInfo and info and info.width and info.width > 0 and info.height > 0 then
                -- (Sized, not scaled: a scaled texture also scales its
                -- offset, and beta2 drew every icon in the middle.)
                local scale = math.min(45 / info.width, 45 / info.height)
                icon:SetSize(info.width * scale, info.height * scale)
            else
                icon:SetSize(45, 45)
            end
        else
            icon:SetSize(45, 45)
        end
    end
    -- While the wheel is up it takes both sticks, so the camera and your
    -- character stand still (the game hands stick input to a shown frame
    -- that asks for it). And the game only sends the stick's directions as
    -- keys - what the secure side listens to - with GamePadStickAxisButtons
    -- on: switched on while the wheel is up, put back when it closes.
    -- (Both found by Controller Forever's wheels; beta2 had neither: the
    -- camera turned and letting go chose nothing.)
    if art.EnableGamePadStick then
        pcall(art.EnableGamePadStick, art, true)
        art:SetScript("OnGamePadStick", function() end)
    end
    art:SetScript("OnHide", function()
        if savedAxis ~= nil and C_CVar and C_CVar.SetCVar then pcall(C_CVar.SetCVar, AXIS_CVAR, savedAxis) end
        savedAxis = nil
    end)
    art:SetScript("OnShow", function(self)
        if C_CVar and C_CVar.GetCVar and C_CVar.SetCVar then
            local ok, current = pcall(C_CVar.GetCVar, AXIS_CVAR)
            if ok and current ~= nil and tostring(current) ~= "1" then
                if savedAxis == nil then savedAxis = tostring(current) end
                pcall(C_CVar.SetCVar, AXIS_CVAR, "1")
            end
        end
        self.selected = nil
        self.highlight:Hide()
        for _, segment in ipairs(self.segments) do
            local on = entryEnabled(segment.entry)
            segment.on = on
            setIcon(segment, on)
            segment.disabled:SetShown(not on)
            if on then segment.text:SetTextColor(1, 0.82, 0) else segment.text:SetTextColor(0.5, 0.5, 0.5) end
        end
        opened = opened + 1
    end)
    art:SetScript("OnUpdate", function(self)
        if not (C_GamePad and C_GamePad.GetDeviceMappedState) then return end
        local ok, state = pcall(C_GamePad.GetDeviceMappedState)
        local stick = ok and type(state) == "table" and state.sticks and state.sticks[stickIndex]
        local index = stick and aimed(stick.x, stick.y)
        if not index or index == self.selected then return end
        self.selected = index
        local rad = math.rad((index - 1) * SEGMENT_ANGLE)
        local highlight = self.highlight
        highlight:ClearAllPoints()
        highlight:SetPoint("CENTER", self.bg, "CENTER", HIGHLIGHT_DISTANCE * math.cos(rad), HIGHLIGHT_DISTANCE * math.sin(rad))
        if highlight.SetRotation then pcall(highlight.SetRotation, highlight, math.rad((index - 1) * SEGMENT_ANGLE - 270)) end
        if highlight.SetDesaturated then highlight:SetDesaturated(not self.segments[index].on) end
        highlight:Show()
    end)
end

-- Secure side. Attributes on the wheel: sel (entry aimed at), held-UP ..
-- held-RIGHT (stick direction keys down), stick (index of the right
-- stick), macro-1..8.
-- Lessons from the stick (also found by Controller Forever's class wheels):
-- the game reports one direction key per stick at a time and often never
-- the earlier key coming up as the stick turns on, so each key's state is
-- kept and a new push clears the others; in a fight the stick can read as
-- centred just as its key goes down, so the held key's direction is used
-- then; the release is the last key coming up (the stick is still well
-- out at that moment), or the stick itself back in the middle.
local PICK_SNIPPET = [[
    if not owner:IsShown() then return false end
    if button ~= "A" then
        owner:SetAttribute("held-" .. button, down and 1 or 0)
        if down then
            for _, other in ipairs(newtable("UP", "DOWN", "LEFT", "RIGHT")) do
                if other ~= button then owner:SetAttribute("held-" .. other, 0) end
            end
        end
    end
    local state = GetGamePadState()
    local sticks = state and state.sticks
    local stick = sticks and sticks[owner:GetAttribute("stick") or 2]
    local x, y = 0, 0
    if stick and stick.x and stick.y then x, y = stick.x, stick.y end
    local lengthSq = x * x + y * y
    if lengthSq < 0.15 then
        x, y = 0, 0
        if owner:GetAttribute("held-UP") == 1 then y = 1 end
        if owner:GetAttribute("held-DOWN") == 1 then y = -1 end
        if owner:GetAttribute("held-RIGHT") == 1 then x = 1 end
        if owner:GetAttribute("held-LEFT") == 1 then x = -1 end
    end
    if x ~= 0 or y ~= 0 then
        local degrees = math.deg(math.atan2(y, x))
        if degrees < -22.5 then degrees = degrees + 360 end
        local index = math.floor((degrees + 45) / 45 + 0.5)
        if index > 8 then index = index - 8 end
        if index < 1 then index = 1 end
        owner:SetAttribute("sel", index)
    end
    local sel = owner:GetAttribute("sel") or 0
    if down or sel < 1 then return false end
    if button ~= "A" then
        if lengthSq > 0.08 then
            for _, key in ipairs(newtable("UP", "DOWN", "LEFT", "RIGHT")) do
                if owner:GetAttribute("held-" .. key) == 1 then return false end
            end
        end
    end
    local macro = owner:GetAttribute("macro-" .. sel)
    owner:ClearBindings()
    owner:Hide()
    if not macro then return false end
    self:SetAttribute("*macrotext*", macro)
]]

-- Bound with every modifier too: the triggers and shoulders can act as
-- Shift / Ctrl / Alt on a controller, and a stick key then arrives as
-- "SHIFT-PADRSTICKUP".
local TOGGLE_SNIPPET = [[
    local wheel = self:GetFrameRef("wheel")
    if wheel:IsShown() then
        wheel:ClearBindings()
        wheel:Hide()
        return
    end
    wheel:SetAttribute("sel", 0)
    for _, key in ipairs(newtable("UP", "DOWN", "LEFT", "RIGHT")) do wheel:SetAttribute("held-" .. key, 0) end
    wheel:Show()
    local pick = self:GetFrameRef("pick"):GetName()
    local close = self:GetFrameRef("close"):GetName()
    for _, modifier in ipairs(newtable("", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "ALT-CTRL-", "ALT-CTRL-SHIFT-")) do
        wheel:SetBindingClick(true, modifier .. "PAD1", pick, "A")
        wheel:SetBindingClick(true, modifier .. "PADRSTICKUP", pick, "UP")
        wheel:SetBindingClick(true, modifier .. "PADRSTICKDOWN", pick, "DOWN")
        wheel:SetBindingClick(true, modifier .. "PADRSTICKLEFT", pick, "LEFT")
        wheel:SetBindingClick(true, modifier .. "PADRSTICKRIGHT", pick, "RIGHT")
        wheel:SetBindingClick(true, modifier .. "PAD2", close, "LeftButton")
    end
]]

local function build()
    assert(RegisterStateDriver and SecureHandlerWrapScript, "secure APIs unavailable")
    wheel = CreateFrame("Frame", "WalkMapCombatWheel", UIParent, "SecureHandlerStateTemplate")
    wheel:SetSize(400, 590)
    wheel:SetPoint("CENTER", UIParent, "CENTER", 312, 0)
    wheel:SetFrameStrata("DIALOG")
    wheel:EnableMouse(false)
    wheel:Hide()

    pick = CreateFrame("Button", "WalkMapCombatWheelPick", UIParent, "SecureActionButtonTemplate")
    pick:RegisterForClicks("AnyUp", "AnyDown")
    pick:SetAttribute("*type*", "macro")
    pick:SetAttribute("useOnKeyDown", false)
    pick:Hide()
    SecureHandlerWrapScript(pick, "OnClick", wheel, PICK_SNIPPET)

    close = CreateFrame("Button", "WalkMapCombatWheelClose", UIParent, "SecureHandlerClickTemplate")
    close:RegisterForClicks("AnyDown")
    close:SetFrameRef("wheel", wheel)
    close:SetAttribute("_onclick", [[
        local wheel = self:GetFrameRef("wheel")
        wheel:ClearBindings()
        wheel:Hide()
    ]])
    close:Hide()

    toggle = CreateFrame("Button", "WalkMapCombatWheelToggle", UIParent, "SecureHandlerClickTemplate")
    toggle:RegisterForClicks("AnyDown")
    toggle:SetFrameRef("wheel", wheel)
    toggle:SetFrameRef("pick", pick)
    toggle:SetFrameRef("close", close)
    toggle:SetAttribute("_onclick", TOGGLE_SNIPPET)
    toggle:Hide()

    header = CreateFrame("Frame", "WalkMapCombatWheelBindings", UIParent, "SecureHandlerStateTemplate")
    header:SetFrameRef("wheel", wheel)
    header:SetFrameRef("toggle", toggle)
    header:SetAttribute("_onstate-combat", [[
        self:ClearBindings()
        local wheel = self:GetFrameRef("wheel")
        wheel:ClearBindings()
        if wheel:IsShown() then wheel:Hide() end
        if newstate == "combat" and self:GetAttribute("enabled") then
            local toggle = self:GetFrameRef("toggle"):GetName()
            for i = 1, self:GetAttribute("key-count") or 0 do
                local key = self:GetAttribute("key-" .. i)
                if key then self:SetBindingClick(true, key, toggle, "LeftButton") end
            end
        end
    ]])
    buildArt()
    ready = true
    refresh()
    RegisterStateDriver(header, "combat", "[combat] combat; safe")
end

function cw.Status()
    if not ready then return "not ready (" .. tostring(lastError or "loading") .. ")" end
    if not enabled() then
        return (WalkMapCombat and WalkMapCombat.Free and WalkMapCombat.Free()) and "off (free window)" or "off"
    end
    return "on; key " .. table.concat(keys, ", ") .. (guessed and " (guessed: no key found for the game's wheel)" or "")
        .. "; stick " .. stickIndex .. "; opened " .. opened .. " time(s)"
end

local driver = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_LOGIN", "UPDATE_BINDINGS", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD",
    "ZONE_CHANGED_NEW_AREA"}) do driver:RegisterEvent(event) end
driver:SetScript("OnEvent", function(_, event)
    if locked() then return end
    if event == "PLAYER_LOGIN" and not ready then
        local ok, message = pcall(build)
        if not ok then ready, lastError = false, tostring(message) end
        return
    end
    pcall(refresh)
end)
