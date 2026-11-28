-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- =========================================================
-- Setup guide: the first-time welcome, one question per step with big
-- cards (pictures for the quest display and the looks). Shown once for a
-- new player instead of the welcome page; /walkmap setup opens it again.
--
-- Nothing changes until Finish. Then WalkMapExtras.SetupApply applies
-- recommended settings first (if chosen) and the player's picks on top,
-- so recommended settings never override a choice made here. The look is
-- the last step, because using a new look reloads the interface.
-- =========================================================

WalkMapSetup = {}
local setup = WalkMapSetup
local extras = WalkMapExtras

local IMAGES = "Interface\\AddOns\\WalkMap\\Media\\Setup\\"
-- Pictures are 256x128 textures; the used width of each (from the left).
local IMAGE_WIDTH = {
    style_mouse = 205, style_controller = 205, style_both = 205,
    quests_icons = 210, quests_areas = 206, quests_both = 210,
    look_classic = 155, look_stone = 159, look_wood = 162, look_leather = 161,
}

local STEPS = {
    {key = "style", title = "How do you play?",
        text = "WalkMap sets up its controller help and buttons for it. Change it later under Settings > Controller & help.",
        cards = {
            {"mouse", "Mouse and keyboard", "Click the map, its markers and menus. No controller hints.", "style_mouse"},
            {"controller", "Controller", "D-pad, A and B in the map and its menus, with button hints at the top.", "style_controller"},
            {"both", "Both", "A controller and the mouse, side by side. Good for handhelds and the couch.", "style_both"},
        }},
    {key = "quests", title = "How should quests show on the map?",
        text = "Change it later under Settings > Quests on the map.",
        cards = {
            {"icons", "QuestieDB icons", "An icon where to kill, loot or use something, for each objective.", "quests_icons"},
            {"areas", "Game quest areas", "The game's own blue areas and markers, as on its map.", "quests_areas"},
            {"both", "Both", "The blue areas and QuestieDB's icons together.", "quests_both"},
        }},
    {key = "more", title = "A few more choices",
        text = "Click a line to change it. Everything is also under Settings."},
    {key = "look", title = "Choose a look",
        text = "The map, quest log, tracker and minimap change together. A new look reloads the interface when you finish.",
        cards = {
            {"classic", "Classic", "The game's own art.", "look_classic"},
            {"stone", "Stone and gold", "Grey stone with gold edges.", "look_stone"},
            {"wood", "Wood and parchment", "Dark wood and warm parchment.", "look_wood"},
            {"leather", "Leather and bronze", "Red leather with bronze edges.", "look_leather"},
        }},
}

-- Lines on the "more" step: key, label, values in click order, value names.
local TRACKER = {"off", "zone", "nearby", "all"}
local TRACKER_NAMES = {off = "Off", zone = "This zone", nearby = "This zone + nearby", all = "All zones"}
local MORE = {
    {"recommended", "Use recommended settings for the rest",
        "The authors' setup for everything this guide does not ask. Your choices here always win."},
    {"tracker", "Quest tracker", "WalkMap's own tracker: off, this zone, this zone plus nearby quests, or all zones."},
    {"friends", "See friends on the map", "Online friends by zone, with one click to invite them."},
    {"guild", "See guild on the map", "Online guild members by zone, the same way."},
    {"share", "Share where you are",
        "Your guild and friends who use WalkMap or OpenMap see a dot where you are, and you see theirs. Never from dungeons, raids or battlegrounds."},
    {"autoSell", "Auto-sell grey items", "Sell grey items when a vendor opens. Buy them back from the vendor's Buyback tab."},
}

local panel, step, choice
local cards, lines = {}, {}
local stepLabel, titleText, bodyText, backButton, nextButton, skipButton, noteText

local function L(text) return WalkMapL(text) end

local function makeButton(parent, width, height)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, height)
    button:EnableMouse(true)
    extras.StyleButton(button)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.label:SetPoint("CENTER")
    return button
end

local function card(index)
    if cards[index] then return cards[index] end
    local c = CreateFrame("Button", nil, panel)
    c:EnableMouse(true)
    extras.StyleButton(c)
    c.image = c:CreateTexture(nil, "ARTWORK")
    c.image:SetPoint("TOP", c, "TOP", 0, -8)
    -- Chosen: a gold frame around the whole card.
    c.chosen = c:CreateTexture(nil, "BORDER")
    c.chosen:SetPoint("TOPLEFT", c, "TOPLEFT", 2, -2)
    c.chosen:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -2, 2)
    c.chosen:SetColorTexture(1, 0.82, 0.3, 0.22)
    c.title = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    c.text = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.text:SetJustifyH("CENTER")
    c.text:SetJustifyV("TOP")
    c:SetScript("OnClick", function(self)
        choice[STEPS[step].key] = self.value
        setup.Refresh()
    end)
    cards[index] = c
    return c
end

local function line(index)
    if lines[index] then return lines[index] end
    local l = CreateFrame("Button", nil, panel)
    l:SetSize(600, 40)
    l:EnableMouse(true)
    extras.StyleButton(l)
    l.label = l:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    l.label:SetPoint("TOPLEFT", l, "TOPLEFT", 12, -6)
    l.label:SetJustifyH("LEFT")
    l.text = l:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    l.text:SetPoint("TOPLEFT", l.label, "BOTTOMLEFT", 0, -2)
    l.text:SetPoint("RIGHT", l, "RIGHT", -12, 0)
    l.text:SetJustifyH("LEFT")
    l.text:SetWordWrap(false)
    l:SetScript("OnClick", function(self)
        local key = self.key
        if key == "tracker" then
            local nextValue = "zone"
            for i, value in ipairs(TRACKER) do
                if value == choice.tracker then nextValue = TRACKER[i % #TRACKER + 1] end
            end
            choice.tracker = nextValue
        else
            choice[key] = not choice[key]
        end
        setup.Refresh()
    end)
    lines[index] = l
    return l
end

local function onOff(on) return on and "|cff80ff80" .. L("On") .. "|r" or "|cffff8080" .. L("Off") .. "|r" end

local function focus(button)
    if button and WalkMapNativeController and WalkMapNativeController.FocusButton then
        pcall(WalkMapNativeController.FocusButton, panel, button)
    end
end

local function create()
    if panel then return panel end
    local owner = WalkMapCore and WalkMapCore.frame or UIParent
    panel = CreateFrame("Frame", "WalkMapSetupFrame", owner)
    panel:SetSize(700, 470)
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    panel:SetFrameStrata("TOOLTIP")
    if panel.SetFixedFrameStrata then panel:SetFixedFrameStrata(true) end
    panel:SetFrameLevel((owner.GetFrameLevel and owner:GetFrameLevel() or 0) + 40)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    if WalkMapUI and WalkMapUI.Window then WalkMapUI.Window(panel) end
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", panel, "TOP", 0, -8)
    WalkMapLocale.Static(title, "Set up WalkMap")
    stepLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    stepLabel:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -18, -42)
    titleText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -44)
    bodyText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bodyText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -6)
    bodyText:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    bodyText:SetJustifyH("LEFT")
    noteText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    noteText:SetPoint("BOTTOM", panel, "BOTTOM", 0, 54)
    backButton = makeButton(panel, 120, 26)
    backButton:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 18, 16)
    backButton:SetScript("OnClick", function()
        if step > 1 then step = step - 1 setup.Refresh() end
    end)
    nextButton = makeButton(panel, 170, 26)
    nextButton:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -18, 16)
    nextButton:SetScript("OnClick", function()
        if step < #STEPS then
            step = step + 1
            setup.Refresh()
        else
            setup.Finish()
        end
    end)
    skipButton = makeButton(panel, 150, 26)
    skipButton:SetPoint("BOTTOM", panel, "BOTTOM", 0, 16)
    skipButton:SetScript("OnClick", function() setup.Close() end)
    panel:Hide()
    if WalkMapNativeController and WalkMapNativeController.WatchPanel then
        pcall(WalkMapNativeController.WatchPanel, panel)
    end
    if WalkMapLocale.OnChange then
        WalkMapLocale.OnChange(function() if panel:IsShown() then setup.Refresh() end end)
    end
    return panel
end

-- Lay out the current step.
function setup.Refresh()
    if not panel then return end
    local s = STEPS[step]
    stepLabel:SetText(L(("Step %d of %d"):format(step, #STEPS)))
    titleText:SetText(L(s.title))
    bodyText:SetText(L(s.text))
    for _, c in ipairs(cards) do c:Hide() end
    for _, l in ipairs(lines) do l:Hide() end
    local first
    if s.cards then
        local count = #s.cards
        local gap = 14
        local width = math.floor((700 - 48 - gap * (count - 1)) / count)
        local imageHeight = s.cards[1][4] and math.floor(math.min(width - 16, 300) / 1.6) or 0
        if s.key == "look" then imageHeight = math.floor((width - 16) / 1.27) end
        local height = imageHeight + 96
        for i, data in ipairs(s.cards) do
            local c = card(i)
            c.value = data[1]
            c:SetSize(width, height)
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", panel, "TOPLEFT", 24 + (i - 1) * (width + gap), -112)
            if data[4] then
                local imageWidth = width - 16
                c.image:SetTexture(IMAGES .. data[4] .. ".tga")
                c.image:SetTexCoord(0, (IMAGE_WIDTH[data[4]] or 256) / 256, 0, 1)
                c.image:SetSize(imageWidth, imageHeight)
                c.image:Show()
            else
                c.image:Hide()
            end
            c.title:ClearAllPoints()
            if data[4] then
                c.title:SetPoint("TOP", c.image, "BOTTOM", 0, -8)
            else
                c.title:SetPoint("TOP", c, "TOP", 0, -18)
            end
            c.title:SetWidth(width - 12)
            c.text:ClearAllPoints()
            c.text:SetPoint("TOP", c.title, "BOTTOM", 0, -6)
            c.text:SetWidth(width - 20)
            local picked = choice[s.key] == data[1]
            c.title:SetText((picked and "|cff80ff80" or "") .. L(data[2]) .. (picked and "|r" or ""))
            c.text:SetText(L(data[3]))
            c.chosen:SetShown(picked)
            c:Show()
            if picked or not first then first = picked and c or first or c end
        end
        if not s.cards[1][4] then
            -- Text-only cards (How you play): shorter.
            for i = 1, count do cards[i]:SetHeight(110) end
        end
    else
        for i, data in ipairs(MORE) do
            local l = line(i)
            l.key = data[1]
            l:SetWidth(652)
            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -104 - (i - 1) * 46)
            local value
            if data[1] == "tracker" then value = L(TRACKER_NAMES[choice.tracker] or "This zone")
            else value = onOff(choice[data[1]]) end
            l.label:SetText(L(data[2]) .. ": " .. value)
            l.text:SetText(L(data[3]))
            l:Show()
            first = first or l
        end
    end
    backButton.label:SetText(L("Back"))
    backButton:SetShown(step > 1)
    skipButton.label:SetText(L(step == 1 and "Skip setup" or "Cancel"))
    local reload = s.key == "look" and choice.look ~= (WalkMapUI and WalkMapUI.Look and WalkMapUI.Look())
    nextButton.label:SetText(L(step < #STEPS and "Next" or reload and "Finish and reload" or "Finish"))
    noteText:SetText(reload and L("The interface reloads to use the new look.") or "")
    for _, button in ipairs({backButton, nextButton, skipButton}) do
        if WalkMapUI and WalkMapUI.FitText then WalkMapUI.FitText(button.label, button:GetWidth() - 12) end
    end
    focus(first)
end

-- Open the guide (out of combat), on top of the map, which opens with it
-- (the controller works in WalkMap's windows while the map is open).
-- Returns true when it is opening.
local function locked()
    return (WalkMapCombat and WalkMapCombat.Locked()) or (InCombatLockdown and InCombatLockdown())
end
function setup.Show()
    if locked() or not extras or not extras.SetupState then return false end
    local map = WalkMapCore and WalkMapCore.frame
    if map and not map:IsShown() and WalkMap_Toggle then WalkMap_Toggle() end
    if map and not map:IsShown() then return false end
    local function open()
        if locked() then return end
        create()
        choice = extras.SetupState()
        -- Recommended settings: on for a new player, off when opened again.
        choice.recommended = not (type(WalkMapSettings) == "table" and WalkMapSettings.welcomeSeen)
        step = 1
        if extras.CloseMenus then pcall(extras.CloseMenus) end
        local settingsPanel = extras.SettingsPanel and extras.SettingsPanel()
        if settingsPanel and settingsPanel:IsShown() then settingsPanel:Hide() end
        panel:Show()
        setup.Refresh()
        extras.SetupSeen()
    end
    -- Give the map a moment to open (and the controller to register it).
    if C_Timer and C_Timer.After then C_Timer.After(0.3, open) else open() end
    return true
end

function setup.Close()
    if panel then panel:Hide() end
end

function setup.Finish()
    if not choice then return end
    local reload = choice.look ~= (WalkMapUI and WalkMapUI.Look and WalkMapUI.Look())
    extras.SetupApply(choice)
    setup.Close()
    print(L("|cff80ff80WalkMap:|r Setup done. Change anything later under Settings; /walkmap setup runs this guide again."))
    if reload and not (InCombatLockdown and InCombatLockdown()) then
        if C_UI and C_UI.Reload then C_UI.Reload() elseif ReloadUI then ReloadUI() end
    end
end

function setup.Panel() return panel end
function setup.Step() return step end
function setup.Choice() return choice end
