-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- Optional, unprotected overlays for the standalone WalkMap canvas.
WalkMapExtras = {}
local extras = WalkMapExtras
local function setControllerPanelVisible(panel, shown)
    if WalkMapNativeController then return WalkMapNativeController.SetVisible(panel, shown) end
    if shown then panel:Show() else panel:Hide() end
    return true
end
-- The old account-wide table is retained only as a first-login template.
-- A separate SavedVariablesPerCharacter table keeps each character's choices.
-- Account settings (Settings > Profiles): one saved copy of a character's
-- settings that every character on the account can load, and that new
-- characters can start from. Things that belong to one character - quest
-- focus, waypoint, hidden markers, removed tracker quests, debug logs - are
-- never copied.
local CHARACTER_ONLY = {
    browsedMapID = true, debugEvents = true, debugFocus = true, hiddenGivers = true,
    hiddenMarkers = true, lastBlockedAction = true, lastDebugReport = true,
    lastNativeCombatAction = true, questFocusID = true, questSolo = true,
    questLogCollapsed = true, trackerHidden = true, trackerNearbySeen = true, mapReleased = true,
    lastInterface = true,
    waypoint = true, walkmapNativeFirstButton = true,
}
local function deepCopy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, inner in pairs(value) do copy[key] = deepCopy(inner) end
    return copy
end
local function accountCopy(from)
    local copy = {}
    for key, value in pairs(from) do
        if not CHARACTER_ONLY[key] and type(key) == "string" then copy[key] = deepCopy(value) end
    end
    return copy
end
if type(WalkMapCharacterSettings) ~= "table"
    and type(WalkMapSettings) == "table" and WalkMapSettings.accountForNew
    and type(WalkMapSettings.accountSettings) == "table" then
    WalkMapCharacterSettings = accountCopy(WalkMapSettings.accountSettings)
    WalkMapCharacterSettings.fromAccountSettings = true
end
if type(WalkMapCharacterSettings) ~= "table" then
    local old = type(WalkMapSettings) == "table" and WalkMapSettings or {}
    WalkMapCharacterSettings = {}
    for _, field in ipairs({"givers", "areas", "level", "clearView",
        "controllerMode", "miniMap", "miniZoom", "miniTerrain", "nativeIcons",
        "objectiveIcons", "focusObjectiveIcons", "questLabels", "follow", "mapWidth", "mapX", "mapY",
        "zoomIndex", "places"}) do
        WalkMapCharacterSettings[field] = old[field]
    end
    for _, field in ipairs({"placeFilters", "hiddenGivers", "hiddenMarkers"}) do
        if type(old[field]) == "table" then
            local copy = {}
            for key, value in pairs(old[field]) do copy[key] = value end
            WalkMapCharacterSettings[field] = copy
        end
    end
end
local settings = WalkMapCharacterSettings
-- Migrate saved single-choice place filters from WalkMap 0.8.
if type(settings.placeFilters) ~= "table" then
    settings.placeFilters = {}
    if type(settings.places) == "string" and settings.places ~= "none" then
        settings.placeFilters[settings.places] = true
    end
end
settings.places = nil
if settings.givers == nil then settings.givers = true end
settings.clearView = settings.clearView == true
settings.objectiveIcons = settings.objectiveIcons == true
settings.focusObjectiveIcons = settings.focusObjectiveIcons == true
settings.questLabels = settings.questLabels == true
settings.follow = settings.follow == true
settings.controllerMode = settings.controllerMode == true
if settings.nativeController == nil then settings.nativeController = true end
-- Pulsing halo around the large-map player arrow; on unless turned off.
if settings.playerHalo == nil then settings.playerHalo = true end
settings.miniMap = settings.miniMap == true
if settings.miniTerrain ~= "game" then settings.miniTerrain = "zone" end
settings.nativeMiniMap = nil
settings.nativeIcons = settings.nativeIcons == true
-- WalkMap's own quest focus ("solo"): shows only that quest's icons/areas.
settings.questSolo = settings.questSolo == true and type(settings.questFocusID) == "number"
if not settings.questSolo then settings.questFocusID = nil end
settings.fadeWhileMoving = settings.fadeWhileMoving == true
if settings.zoneTracker == nil then settings.zoneTracker = true end
-- Zone tracker look: cycles shown on the "Quest tracker" settings page.
local TRACKER_CHOICES = {
    trackerFont = {{0.85, "Small"}, {1, "Normal"}, {1.2, "Large"}, {1.4, "Extra large"}},
    trackerBgAlpha = {{0, "Off"}, {0.15, "Light"}, {0.3, "Medium"}, {0.5, "Dark"}, {0.75, "Solid"}},
    trackerMax = {{5, "5"}, {8, "8"}, {10, "10"}, {12, "12"}, {15, "15"}, {20, "20"}},
    trackerWidth = {{210, "Narrow"}, {250, "Normal"}, {310, "Wide"}},
}
if type(settings.trackerFont) ~= "number" then settings.trackerFont = 1 end
if type(settings.trackerBgAlpha) ~= "number" then settings.trackerBgAlpha = 0.3 end
if type(settings.trackerMax) ~= "number" then settings.trackerMax = 12 end
if type(settings.trackerWidth) ~= "number" then settings.trackerWidth = 250 end
-- 4.75 had a separate background switch; 4.76 folds it into "Off".
if settings.trackerBackground == false then settings.trackerBgAlpha = 0 end
settings.trackerBackground = nil
settings.hideGameTracker = settings.hideGameTracker == true
-- Quests the player removed from WalkMap's tracker: [questID] = true.
if type(settings.trackerHidden) ~= "table" then settings.trackerHidden = {} end
settings.combatPad = nil
-- Close the map when combat starts: on for players new to WalkMap (no
-- welcome page seen yet), off for everyone who had WalkMap before 1.14.14.
if settings.closeInCombat == nil then
    settings.closeInCombat = not (type(WalkMapSettings) == "table" and WalkMapSettings.welcomeSeen == true)
end
settings.closeInCombat = settings.closeInCombat == true
settings.turnInWaypoint = settings.turnInWaypoint == true
-- Unexplored areas on the large map (WalkMap.lua): off unless turned on.
settings.unexplored = settings.unexplored == true
-- Friends and guild on the map (WalkMap_Friends.lua): by zone on unless
-- turned off; sharing your own place is off unless turned on.
if settings.friendsOnMap == nil then settings.friendsOnMap = true end
if settings.guildOnMap == nil then settings.guildOnMap = true end
settings.shareLocation = settings.shareLocation == true
-- Those who share where they are, also on the minimaps; on unless turned off.
if settings.friendsOnMinimap == nil then settings.friendsOnMinimap = true end
-- Party members' quest progress in the tracker (WalkMap_GroupProgress.lua).
if settings.groupProgress == nil then settings.groupProgress = true end
-- Focus waypoint on the minimaps (WalkMap.lua); on unless turned off.
if settings.focusWaypoint == nil then settings.focusWaypoint = true end
settings.rightClickUp = settings.rightClickUp == true
-- Controller button hints at the top of the map; on unless turned off.
if settings.controllerHints == nil then settings.controllerHints = true end
if settings.announce ~= "done" and settings.announce ~= "progress" then settings.announce = "off" end
-- Tracker scope: "zone", "nearby" (this zone plus quests from neighbouring
-- zones that reach into this map; the default since 1.11) or "all". Saves
-- from before 1.11 only knew "zone" and move to "nearby" once.
if settings.trackerScope ~= "all" and settings.trackerScope ~= "nearby" then settings.trackerScope = "zone" end
if not settings.trackerNearbySeen then
    settings.trackerNearbySeen = true
    if settings.trackerScope == "zone" then settings.trackerScope = "nearby" end
end
if settings.trackerObjectives == nil then settings.trackerObjectives = true end
if settings.showQuestXP == nil then settings.showQuestXP = true end
-- Metal frame and title band around the quest tracker (newer looks only).
if settings.trackerFrame == nil then settings.trackerFrame = true end
-- Window look (WalkMapUI): per character, falling back to the account choice.
if settings.look == nil then
    settings.look = type(WalkMapSettings) == "table" and WalkMapSettings.look or WalkMapUI.DefaultLook()
end
local FADE_CHOICES = {0.2, 0.35, 0.5, 0.7}
if type(settings.fadeAlpha) ~= "number" then settings.fadeAlpha = 0.35 end
if settings.fadeKeepArrow == nil then settings.fadeKeepArrow = true end
-- Opt-in: the game's world map / quest log keys open WalkMap instead.
-- On for new installs; a saved choice (on or off) is kept.
if settings.useGameMapKeys == nil then settings.useGameMapKeys = true end
settings.useGameMapKeys = settings.useGameMapKeys == true
-- Wheel's Quest & Maps (the game's world map): open WalkMap with its quest
-- log (default) or the map alone.
if settings.wheelOpensQuestLog == nil then settings.wheelOpensQuestLog = true end
-- Inside a dungeon, leave the map key and the wheel to the game's map when a
-- dungeon map addon is installed (see extras.HandOffDungeonMap).
if settings.dungeonMapHandoff == nil then settings.dungeonMapHandoff = true end
-- "Game map in dungeons: Always": also without a known dungeon map addon.
settings.dungeonMapAlways = settings.dungeonMapAlways == true
-- WalkMap's wheel in combat (WalkMap_CombatWheel.lua): on unless turned off.
if settings.combatWheel == nil then settings.combatWheel = true end
-- 1.14.17 betas only: "Wheel closes WalkMap in combat" (removed; the game
-- runs no addon snippet on its quest log button in combat).
settings.wheelClosesInCombat = nil
if type(settings.waypoint) ~= "table" or type(settings.waypoint.mapID) ~= "number"
    or type(settings.waypoint.x) ~= "number" or type(settings.waypoint.y) ~= "number" then
    settings.waypoint = nil
end
if settings.bagSortEnabled == nil then settings.bagSortEnabled = true end
settings.autoSellJunk = settings.autoSellJunk == true
if settings.vendorMessages == nil then settings.vendorMessages = true end
if type(settings.miniZoom) ~= "number" or settings.miniZoom < 1
    or settings.miniZoom > 6 or settings.miniZoom ~= math.floor(settings.miniZoom) then
    settings.miniZoom = 3
end
if type(settings.hiddenGivers) ~= "table" then settings.hiddenGivers = {} end
if type(settings.hiddenMarkers) ~= "table" then settings.hiddenMarkers = {} end
for _, field in ipairs({"miniIconScale", "nativeIconScale"}) do
    if settings[field] ~= 0.8 and settings[field] ~= 1.25 then
        settings[field] = 1
    end
end
for _, field in ipairs({"miniIconGap", "nativeIconGap"}) do
    if settings[field] ~= 14 and settings[field] ~= 22 then
        settings[field] = 0
    end
end
for _, field in ipairs({"miniIconRange", "nativeIconRange"}) do
    if settings[field] ~= 0.5 and settings[field] ~= 0.75 then
        settings[field] = 1
    end
end
settings.nearestObjective = settings.nearestObjective == true
if settings.areas ~= "all" and settings.areas ~= "off" then
    settings.areas = "focus"
end

-- Profiles only change quest display. Places, minimap and gamepad choices
-- remain independent. Keep a personal snapshot across preset changes.
local profileFields = {"areas", "givers", "objectiveIcons",
    "focusObjectiveIcons", "questLabels", "clearView"}
local profiles = {
    questing = {areas = "all", givers = true, objectiveIcons = true,
        focusObjectiveIcons = false, questLabels = false, clearView = false},
    exploration = {areas = "focus", givers = false, objectiveIcons = false,
        focusObjectiveIcons = false, questLabels = false, clearView = true},
}
local function snapshotProfile()
    local copy = {}
    for _, field in ipairs(profileFields) do copy[field] = settings[field] end
    return copy
end
if type(settings.customProfile) ~= "table" then
    settings.customProfile = snapshotProfile()
end
if settings.profile ~= "questing" and settings.profile ~= "exploration" then
    settings.profile = "custom"
end
local function markProfileEdited(field)
    for _, name in ipairs(profileFields) do
        if field == name then
            settings.profile = "custom"
            settings.customProfile = snapshotProfile()
            return
        end
    end
end
if type(settings.level) ~= "number" or settings.level < 1 or settings.level > 60 then
    settings.level = 0
end

local professions = {
    {"alchemy", "Alchemy"}, {"blacksmithing", "Blacksmithing"},
    {"enchanting", "Enchanting"}, {"engineering", "Engineering"},
    {"herbalism", "Herbalism"}, {"leatherworking", "Leatherworking"},
    {"mining", "Mining"}, {"skinning", "Skinning"},
    {"tailoring", "Tailoring"}, {"first aid", "First Aid"},
    {"cooking", "Cooking"}, {"fishing", "Fishing"},
}
local classOptions = {
    {"class", "All class trainers"},
    {"class:warrior", "Warrior"}, {"class:paladin", "Paladin"},
    {"class:hunter", "Hunter"}, {"class:rogue", "Rogue"},
    {"class:priest", "Priest"}, {"class:shaman", "Shaman"},
    {"class:mage", "Mage"}, {"class:warlock", "Warlock"},
    {"class:druid", "Druid"},
}
local professionOptions = {{"trainer", "All profession trainers"}}
for _, profession in ipairs(professions) do
    professionOptions[#professionOptions + 1] = profession
end
local otherOptions = {
    {"inn", "Inns"}, {"weapon", "Weapon vendors"},
    {"flight", "Flight masters"},
    {"repair", "Repair vendors"}, {"bank", "Banks"},
    {"auction", "Auction houses"}, {"stable", "Stable masters"},
    {"pet", "Pet trainers"},
    {"herb", "Herbs"}, {"ore", "Mining"},
    {"rare", "Rare mobs"},
}
local placeGroups = {
    {"profession", "Profession Trainers", professionOptions},
    {"class", "Class Trainers", classOptions},
    {"other", "Other", otherOptions},
}
local questGroups = {
    areas = {"areas", "Quest areas", {
        {"focus", "Focused quest"}, {"all", "All quests"},
        {"off", "Hide areas"},
    }},
    level = {"level", "Quest giver level", {{0, "Automatic"}}},
    profiles = {"profiles", "Profiles", {
        {"questing", "Questing"}, {"exploration", "Exploration"},
        {"custom", "My settings"}, {"save", "Save current as My settings"},
    }},
}
for start = 1, 60, 10 do
    questGroups.level[3][#questGroups.level[3] + 1] =
        {start + 4, start .. "-" .. (start + 9)}
end
local placeNames = {}
for _, group in ipairs(placeGroups) do
    for _, option in ipairs(group[3]) do placeNames[option[1]] = option[2] end
end
for key in pairs(settings.placeFilters) do
    if not placeNames[key] then settings.placeFilters[key] = nil end
end

local icons = {
    class = "Interface\\Icons\\INV_Misc_Book_09",
    trainer = "Interface\\Icons\\INV_Misc_Book_09",
    inn = "Interface\\Icons\\INV_Misc_Rune_01",
    weapon = "Interface\\Icons\\INV_Sword_04",
    flight = "Interface\\Icons\\Ability_Mount_Wyvern_01",
    repair = "Interface\\Icons\\Trade_BlackSmithing",
    bank = "Interface\\Icons\\INV_Misc_Coin_01",
    auction = "Interface\\Icons\\INV_Misc_Coin_02",
    stable = "Interface\\Icons\\Ability_Mount_RidingHorse",
    pet = "Interface\\Icons\\Ability_Hunter_BeastCall",
    giver = "Interface\\GossipFrame\\AvailableQuestIcon",
    herb = "Interface\\Icons\\Trade_Herbalism",
    ore = "Interface\\Icons\\Trade_Mining",
    rare = "Interface\\Icons\\Ability_Hunter_SniperShot",
}
local professionIcons = {
    alchemy = "Interface\\Icons\\Trade_Alchemy",
    blacksmithing = "Interface\\Icons\\Trade_BlackSmithing",
    enchanting = "Interface\\Icons\\Trade_Engraving",
    engineering = "Interface\\Icons\\Trade_Engineering",
    herbalism = "Interface\\Icons\\Trade_Herbalism",
    leatherworking = "Interface\\Icons\\Trade_LeatherWorking",
    mining = "Interface\\Icons\\Trade_Mining",
    skinning = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
    tailoring = "Interface\\Icons\\Trade_Tailoring",
    ["first aid"] = "Interface\\Icons\\INV_Misc_Bandage_15",
    cooking = "Interface\\Icons\\INV_Misc_Food_15",
    fishing = "Interface\\Icons\\Trade_Fishing",
}
local professionSpells = {
    alchemy = 2259, blacksmithing = 2018, enchanting = 7411,
    engineering = 4036, herbalism = 2366, leatherworking = 2108,
    mining = 2575, skinning = 8613, tailoring = 3908,
    ["first aid"] = 3273, cooking = 2550, fishing = 7620,
}
local function professionIcon(key)
    local spell = professionSpells[key]
    if spell and C_Spell and C_Spell.GetSpellTexture then
        local ok, texture = pcall(C_Spell.GetSpellTexture, spell)
        if ok and texture then return texture end
    end
    if spell and GetSpellTexture then
        local ok, texture = pcall(GetSpellTexture, spell)
        if ok and texture then return texture end
    end
    return professionIcons[key] or icons.trainer
end
-- Class icons come from the game's class-circle sheet when it is available.
local CLASS_CIRCLES = "Interface\\TargetingFrame\\UI-Classes-Circles"
local function classIcon(token)
    local coords = CLASS_ICON_TCOORDS and token and CLASS_ICON_TCOORDS[token:upper()]
    if coords then return CLASS_CIRCLES, {coords[1], coords[2], coords[3], coords[4]} end
    return icons.class
end
local owner, canvas, changed, buttons, menu, submenu, viewButton, settingsPanel, questButton
local refreshSettingsRows
-- Time of the first click on Load account settings (it needs a second click).
local accountLoadArmedAt
local styleRow
local styleMenu
local servicePins, giverPins, resourcePins, rarePins = {}, {}, {}, {}
local lastGiverSummary = "not checked yet"
local nextRefresh = 0
local lastMap, lastLevel
local revision = 0
local mapGroups, mapGroupInfo = {}, {}
local questFocusGroup
-- Something changed: redraw places/givers on the next pass, and tell the
-- minimap scenes (they compare Revision()). Quest events call this often,
-- so the revision moves at most twice a second. (Until 1.04 a second,
-- smaller copy of this function further down replaced it, so the minimaps
-- only caught up on their 2-5 s timer.)
local revisionAt = 0
function extras.Invalidate()
    lastMap = nil
    nextRefresh = 0
    local now = GetTime and GetTime() or 0
    if now - revisionAt >= 0.5 then
        revisionAt = now
        revision = revision + 1
    end
end
function extras.Revision() return revision end
local classBits = {
    WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16,
    DEATHKNIGHT = 32, SHAMAN = 64, MAGE = 128, WARLOCK = 256,
    MONK = 512, DRUID = 1024,
}

local function playerClassBit()
    if not UnitClass then return nil end
    local _, token, id = UnitClass("player")
    -- QuestieDB's class bits follow the original class IDs, not faction IDs.
    if type(id) == "number" and id >= 1 and id <= 11 then
        return 2 ^ (id - 1)
    end
    return classBits[token]
end

local raceBits = {
    HUMAN = 1, ORC = 2, DWARF = 4, NIGHTELF = 8,
    SCOURGE = 16, TAUREN = 32, GNOME = 64, TROLL = 128,
    GOBLIN = 256, BLOODELF = 512, DRAENEI = 1024,
    WORGEN = 2097152, PANDAREN = 8388608,
}

local function playerRaceBit()
    if not UnitRace then return nil end
    local _, token, id = UnitRace("player")
    local masks = LibQuestieDB and LibQuestieDB.Enum and LibQuestieDB.Enum.raceMaskById
    if type(masks) == "table" and type(masks[id]) == "number" then return masks[id] end
    -- Unknown Forever races should not be rejected by a Classic race mask.
    return raceBits[token]
end

local function trivialRange(level)
    if settings.level == 0 and UnitQuestTrivialLevelRange then
        local ok, value = pcall(UnitQuestTrivialLevelRange, "player")
        if ok and type(value) == "number" and value >= 2 and value <= 10 then
            return value
        end
    end
    if settings.level == 0 and GetQuestGreenRange then
        local ok, value = pcall(GetQuestGreenRange, "player")
        if ok and type(value) == "number" and value >= 2 and value <= 10 then
            return value
        end
    end
    return 5 -- Approximation for a manual level or a missing beta API.
end

local function playerLevel()
    if settings.level > 0 then return settings.level end
    local level = UnitLevel and UnitLevel("player")
    if type(level) == "number" and level > 0 then return level end
    return 5 -- Fallback when this beta does not expose UnitLevel.
end

local function factionOK(faction)
    local player = UnitFactionGroup and UnitFactionGroup("player")
    return faction == "AH" or not player
        or (player == "Alliance" and faction == "A")
        or (player == "Horde" and faction == "H")
end

local function hidePool(pool)
    for _, pin in ipairs(pool) do pin:Hide() end
end

function extras.Hide()
    hidePool(servicePins)
    hidePool(giverPins)
    hidePool(resourcePins)
    hidePool(rarePins)
    lastMap = nil
end

function extras.CloseMenus()
    if submenu then
        setControllerPanelVisible(submenu, false)
        submenu.parentRow = nil
    end
    if menu then
        setControllerPanelVisible(menu, false)
        menu.from = nil
        menu.mode = nil
        menu.pressHeld = false
    end
    if settingsPanel then setControllerPanelVisible(settingsPanel, false) end
    if WalkMapNativeController then WalkMapNativeController.RequestRefresh() end
end

local function questInLog(questID)
    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
        local ok, index = pcall(C_QuestLog.GetLogIndexForQuestID, questID)
        if ok then return index ~= nil and index ~= 0 end
    end
    return true -- no lookup API: keep the player's choice
end

-- WalkMap's own quest focus. Turned-in or abandoned quests clear it.
function extras.QuestFocus()
    if not settings.questSolo then return nil end
    if not questInLog(settings.questFocusID) then
        settings.questSolo, settings.questFocusID = false, nil
        return nil
    end
    return settings.questFocusID
end

function extras.AreaMode()
    -- Quest focus narrows what is shown; it never turns hidden areas back on.
    if settings.areas ~= "off" and extras.QuestFocus() then return "focus" end
    return settings.areas
end

function extras.ClearView()
    return settings.clearView
end

function extras.ObjectiveIcons()
    return settings.objectiveIcons
end

function extras.FocusObjectiveIcons()
    if extras.QuestFocus() then return true end
    return settings.focusObjectiveIcons
end

function extras.WheelOpensQuestLog()
    return settings.wheelOpensQuestLog ~= false
end

function extras.UseGameMapKeys()
    return settings.useGameMapKeys == true
end

-- Addons that draw their own dungeon map in the game's map window.
local DUNGEON_MAP_ADDONS = {
    {"ForeverDungeonJournal", "DungeonJournal"},
    {"ForeverDungeonScout", "Forever Dungeon Scout"},
}
function extras.DungeonMapAddon()
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    if not loaded then return nil end
    for _, addon in ipairs(DUNGEON_MAP_ADDONS) do
        local ok, on = pcall(loaded, addon[1])
        if ok and on then return addon[2] end
    end
end

-- True inside a dungeon or raid with such an addon and the setting on:
-- then the map key and the wheel open the game's map (with that addon's
-- dungeon map), not WalkMap. The WalkMap key still opens WalkMap.
function extras.HandOffDungeonMap()
    if settings.dungeonMapHandoff == false then return false end
    local ok, inside = pcall(IsInInstance)
    if not (ok and inside == true) then return false end
    return settings.dungeonMapAlways == true or extras.DungeonMapAddon() ~= nil
end

-- "Game map in dungeons": "auto" (with DungeonJournal or Forever Dungeon
-- Scout), "always" (any other dungeon map addon) or "off".
function extras.DungeonMapMode()
    if settings.dungeonMapHandoff == false then return "off" end
    return settings.dungeonMapAlways == true and "always" or "auto"
end

function extras.CombatWheel() return settings.combatWheel ~= false end

function extras.ZoneTracker()
    return settings.zoneTracker ~= false
end

-- Quests removed from WalkMap's tracker (Untrack in the quest log, or
-- right-click in the tracker). Per character; a quest that leaves the quest
-- log is dropped from the list (WalkMap_Tracker.lua).
function extras.TrackerHidden(questID)
    return settings.trackerHidden[questID] == true
end

function extras.SetTrackerHidden(questID, hidden)
    if type(questID) ~= "number" then return end
    settings.trackerHidden[questID] = hidden and true or nil
    if WalkMapTracker and WalkMapTracker.Refresh then WalkMapTracker.Refresh() end
    extras.Invalidate()
    if changed then changed() end
end

-- A quest removed from the tracker (Untrack) also leaves the maps: no game
-- marker, area, objective icons or turn-in "?" on the large map and the
-- minimaps. The focused quest is always shown.
function extras.HiddenOnMap(questID)
    if type(questID) ~= "number" or not settings.trackerHidden[questID] then return false end
    if settings.zoneTracker == false then return false end
    return questID ~= extras.QuestFocus()
end

-- quests: a list of {questID = ...}; returns it without hidden quests.
function extras.WithoutHidden(quests)
    if type(quests) ~= "table" or next(settings.trackerHidden) == nil then return quests end
    local kept = {}
    for _, quest in ipairs(quests) do
        if not extras.HiddenOnMap(quest.questID) then kept[#kept + 1] = quest end
    end
    return kept
end

-- "Select keeps the map released" (Controller & help). While it is on, a
-- map you left with Select stays released when it is closed and opened
-- again, until Select takes it back. settings.mapReleased is that state.
function extras.SelectKeepsReleased() return settings.selectKeepsReleased == true end
function extras.MapReleased() return settings.selectKeepsReleased == true and settings.mapReleased == true end
function extras.SetMapReleased(released)
    if released and settings.selectKeepsReleased ~= true then return end
    settings.mapReleased = released and true or nil
end

function extras.TrackerHiddenCount()
    local count = 0
    for _ in pairs(settings.trackerHidden) do count = count + 1 end
    return count
end

-- inLog: [questID] = true for every quest in the quest log right now.
function extras.PruneTrackerHidden(inLog)
    for questID in pairs(settings.trackerHidden) do
        if not inLog[questID] then settings.trackerHidden[questID] = nil end
    end
end

-- Per-character storage for the zone tracker (position).
-- The quest tracker's place and size are kept per game interface: the
-- mouse and keyboard layout has its action bars where the gamepad layout
-- has room, so each gets its own position, width and height
-- (settings.trackerLayouts.gamepad / .mouse). Both start from the single
-- position saved before 1.14.7 (zoneTrackerPos).
function extras.TrackerInterface()
    return (WalkMapCombat and WalkMapCombat.GamepadUI and WalkMapCombat.GamepadUI()) and "gamepad" or "mouse"
end
function extras.TrackerSettings()
    if type(settings.trackerLayouts) ~= "table" then settings.trackerLayouts = {} end
    local key = extras.TrackerInterface()
    local layout = settings.trackerLayouts[key]
    if type(layout) ~= "table" then
        layout = {}
        if type(settings.zoneTrackerPos) == "table" then
            for k, v in pairs(settings.zoneTrackerPos) do layout[k] = v end
        end
        settings.trackerLayouts[key] = layout
    end
    return layout
end

-- Waypoint to the turn-in when a quest is ready (WalkMap_QuestInfo.lua).
-- Quest XP in the tracker, quest log list and quest giver tooltips.
function extras.ShowQuestXP()
    return settings.showQuestXP ~= false
end

function extras.ControllerHints()
    return settings.controllerHints ~= false
end

function extras.Unexplored() return settings.unexplored == true end
function extras.FriendsOnMap() return settings.friendsOnMap ~= false end
function extras.GuildOnMap() return settings.guildOnMap ~= false end
function extras.ShareLocation() return settings.shareLocation == true end
function extras.FriendsOnMinimap() return settings.friendsOnMinimap ~= false end
function extras.GroupProgress() return settings.groupProgress ~= false end

function extras.FocusWaypoint()
    return settings.focusWaypoint ~= false
end

function extras.TurnInWaypoint()
    return settings.turnInWaypoint == true
end

-- Right-click on a zone map: off = waypoint (as before), on = map level up.
function extras.RightClickUp()
    return settings.rightClickUp == true
end

-- Close the map when combat starts (it can still be opened in combat).
function extras.CloseMapInCombat()
    return settings.closeInCombat == true
end

-- Party/raid messages about quest progress (WalkMap_Announce.lua).
function extras.Announce()
    return settings.announce
end

-- Look of the zone tracker; read by WalkMap_Tracker.lua.
function extras.TrackerOptions()
    return {
        font = settings.trackerFont, background = settings.trackerBgAlpha > 0,
        backgroundAlpha = settings.trackerBgAlpha, max = settings.trackerMax,
        width = type(extras.TrackerSettings().w) == "number" and extras.TrackerSettings().w or settings.trackerWidth,
        objectives = settings.trackerObjectives ~= false,
        hideGame = settings.hideGameTracker == true, scope = settings.trackerScope,
        frame = settings.trackerFrame ~= false,
    }
end

local function trackerChoiceLabel(setting)
    for _, choice in ipairs(TRACKER_CHOICES[setting]) do
        if math.abs(settings[setting] - choice[1]) < 0.001 then return choice[2] end
    end
    return tostring(settings[setting])
end

-- Width dragged in Edit Mode (WalkMap_Tracker.lua), for this interface.
-- Cycling the Width row afterwards goes back to the fixed choices.
function extras.SetTrackerWidth(width)
    if type(width) == "number" and width > 0 then extras.TrackerSettings().w = math.floor(width + 0.5) end
end

local function cycleTrackerChoice(setting)
    if setting == "trackerWidth" and extras.TrackerSettings().w then
        -- From a dragged width back to the fixed choices, at the current one.
        extras.TrackerSettings().w = nil
        return
    end
    local choices, nextChoice = TRACKER_CHOICES[setting], 1
    for n, choice in ipairs(choices) do
        if math.abs(settings[setting] - choice[1]) < 0.001 then
            nextChoice = n % #choices + 1
            break
        end
    end
    settings[setting] = choices[nextChoice][1]
end

function extras.FadeWhileMoving()
    return settings.fadeWhileMoving == true
end

function extras.FadeAlpha()
    return math.max(0.1, math.min(0.9, settings.fadeAlpha or 0.35))
end

function extras.FadeKeepArrow()
    return settings.fadeKeepArrow ~= false
end

function extras.Waypoint()
    return settings.waypoint
end

function extras.SetWaypoint(waypoint)
    settings.waypoint = waypoint
end

-- Where the character last died (WalkMap_Corpse.lua); nil once alive.
function extras.Corpse()
    return settings.corpse
end

function extras.SetCorpse(spot)
    settings.corpse = spot
end

function extras.ShowQuestNames()
    return settings.questLabels
end

-- Panning the map pauses Follow instead of turning it off. It comes back
-- by itself 15 s after the last pan, or at once when you leave map
-- control, press Center or Follow, or close the map.
local FOLLOW_RESUME = 15
local followPausedAt = nil
local function followPaused()
    if followPausedAt and GetTime and GetTime() - followPausedAt >= FOLLOW_RESUME then
        followPausedAt = nil
        if extras.RefreshLabels then extras.RefreshLabels() end
    end
    return followPausedAt ~= nil
end

function extras.Follow()
    return settings.follow and not followPaused()
end

function extras.ResumeFollow()
    if not followPausedAt then return end
    followPausedAt = nil
    if extras.RefreshLabels then extras.RefreshLabels() end
    if changed then changed() end
end

function extras.PlayerHalo()
    return settings.playerHalo ~= false
end

function extras.ControllerMode()
    return settings.controllerMode
end

function extras.MiniMap()
    return settings.miniMap
end

function extras.MiniTerrain()
    return settings.miniTerrain
end

function extras.NativeIcons()
    return settings.nativeIcons
end

function extras.MiniZoom()
    return settings.miniZoom
end

function extras.AdjustMiniZoom(direction)
    settings.miniZoom = math.max(1, math.min(6, settings.miniZoom + direction))
    return settings.miniZoom
end

function extras.MiniMapPins()
    -- (4th: rare mobs, on the big map only)
    return servicePins, giverPins, resourcePins, rarePins
end

function extras.MiniIconStyle(native)
    return native and settings.nativeIconScale or settings.miniIconScale,
        native and settings.nativeIconGap or settings.miniIconGap,
        native and settings.nativeIconRange or settings.miniIconRange
end

local function allowEveryMarker() return true end
function extras.MarkerGrid(gap)
    if not gap or gap <= 0 then return allowEveryMarker end
    local cells = {}
    local gapSquared = gap * gap
    return function(x, y, reserve)
        local cx, cy = math.floor(x / gap), math.floor(y / gap)
        for ix = cx - 1, cx + 1 do
            for iy = cy - 1, cy + 1 do
                for _, point in ipairs(cells[ix .. ":" .. iy] or {}) do
                    local dx, dy = x - point[1], y - point[2]
                    if dx * dx + dy * dy < gapSquared then return false end
                end
            end
        end
        if reserve == false then return true end
        local key = cx .. ":" .. cy
        if not cells[key] then cells[key] = {} end
        cells[key][#cells[key] + 1] = {x, y}
        return true
    end
end

function extras.NearestObjective()
    return settings.nearestObjective
end

function extras.MarkerKey(kind, mapID, identity, x, y)
    return string.format("%s|%s|%s|%.2f|%.2f", tostring(kind),
        tostring(mapID), tostring(identity), tonumber(x) or 0, tonumber(y) or 0)
end

function extras.MarkerHidden(key)
    return key and settings.hiddenMarkers[key] == true
end

function extras.HideMarkers(keys)
    local count = 0
    for _, key in ipairs(keys or {}) do
        if key and not settings.hiddenMarkers[key] then
            settings.hiddenMarkers[key] = true
            count = count + 1
        end
    end
    if count == 0 then return end
    extras.DebugEvent("Hidden " .. count .. " marker location(s)")
    extras.Invalidate()
    if changed then changed() end
end

function extras.HideMarker(key)
    extras.HideMarkers({key})
end

function extras.ControllerControls()
    return buttons, viewButton, menu, submenu, settingsPanel, questButton
end

local previousEvents = type(settings.debugEvents) == "table"
    and settings.debugEvents or {}
local previousFocus = type(settings.debugFocus) == "table"
    and settings.debugFocus or {}
settings.debugEvents, settings.debugFocus = {}, {}
local recentEvents, recentFocus = settings.debugEvents, settings.debugFocus
function extras.DebugEvent(message)
    local timestamp = GetTime and GetTime() or 0
    message = tostring(message)
    for _, event in ipairs(recentEvents) do
        if event.message == message and timestamp - event.time < 3 then return end
    end
    recentEvents[#recentEvents + 1] = {time = timestamp, message = message}
    if #recentEvents > 12 then table.remove(recentEvents, 1) end
    if message:find("^Focus quest ") then
        recentFocus[#recentFocus + 1] = {time = timestamp, message = message}
        if #recentFocus > 8 then table.remove(recentFocus, 1) end
    end
end

local debugAction
local blockedActions = CreateFrame("Frame")
blockedActions:RegisterEvent("ADDON_ACTION_BLOCKED")
blockedActions:RegisterEvent("ADDON_ACTION_FORBIDDEN")
blockedActions:SetScript("OnEvent", function(_, event, addon, action)
    if addon ~= "WalkMap" then return end
    local message = event .. ": " .. tostring(action or "unknown action")
    if debugAction then message = message .. " (debug: " .. debugAction .. ")" end
    settings.lastBlockedAction = message
    extras.DebugEvent(message)
    if WalkMapMiniSource and tostring(action):find("SetZoom", 1, true) then
        WalkMapMiniSource.NativeRefreshBlocked = true
    end
end)

function extras.DebugReport()
    -- The version comes from the TOC, so the report always names the build
    -- that produced it.
    local version
    local metadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    if metadata then
        local ok, value = pcall(metadata, "WalkMap", "Version")
        if ok and value then version = tostring(value) end
    end
    local lines = {"WalkMap " .. (version or "(version unknown)") .. " debug report"}
    if WalkMapMaps then
        lines[#lines + 1] = "Browsed map: " .. tostring(WalkMapMaps.Selected() or "automatic current zone")
        lines[#lines + 1] = "Player zone: " .. tostring(WalkMapMaps.CurrentZone() or "unknown")
        lines[#lines + 1] = "Dungeon map: " .. (WalkMapDungeons and WalkMapDungeons.Status() or "unavailable")
        -- Do QuestieDB's dungeon bosses have spots on the dungeon maps?
        if WalkMapLiveDB and WalkMapLiveDB.RawSpawns then
            for _, boss in ipairs({{639, "VanCleef"}, {1716, "Bazil Thredd"}, {4275, "Arugal"}, {3654, "Mutanus"}}) do
                lines[#lines + 1] = ("Boss %s (%d): %s"):format(boss[2], boss[1], WalkMapLiveDB.RawSpawns(boss[1]))
            end
        end
        do
            local inside = IsInInstance and select(2, pcall(IsInInstance))
            local name, kind, _, _, _, _, _, instanceID
            if GetInstanceInfo then name, kind, _, _, _, _, _, instanceID = GetInstanceInfo() end
            local best = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
            local bestInfo = best and C_Map.GetMapInfo and C_Map.GetMapInfo(best)
            lines[#lines + 1] = ("Instance: %s (%s, %s, id %s); game's best map %s (%s, type %s)"):format(
                inside == true and "yes" or "no", tostring(name), tostring(kind), tostring(instanceID),
                tostring(best), tostring(bestInfo and bestInfo.name), tostring(bestInfo and bestInfo.mapType))
        end
    end
    local function add(name, value)
        lines[#lines + 1] = name .. ": " .. tostring(value)
    end
    local function on(value) return value and "on" or "off" end
    if GetBuildInfo then
        local ok, version, build, date, interface = pcall(GetBuildInfo)
        add("Game build", ok and (tostring(version) .. " / " .. tostring(build)
            .. " / " .. tostring(interface) .. " / " .. tostring(date)) or "unavailable")
    end
    add("Last blocked WalkMap action", settings.lastBlockedAction or "none recorded")
    add("Profile", settings.profile)
    add("How you play", extras.PlayStyle() .. (settings.playStyle and "" or " (not chosen yet)"))
    add("Map window", (WalkMapCombat and WalkMapCombat.Free and (WalkMapCombat.Free()
        and "free (game gamepad UI was off at load; usable in combat)" or "protected (game gamepad UI was on at load)") or "unknown")
        .. "; " .. (WalkMapStyleReload and WalkMapStyleReload.Status() or ""))
    add("Select keeps the map released", on(settings.selectKeepsReleased)
        .. (extras.MapReleased() and "; map released now" or ""))
    do
        local from, at = extras.AccountSettingsInfo()
        add("Account settings", (from and ("saved from " .. from .. (at and (" " .. at) or "")) or "none")
            .. "; new characters " .. (extras.AccountForNew() and "use them" or "start with defaults")
            .. (settings.fromAccountSettings and "; this character started from them" or ""))
    end
    add("Quest areas", settings.areas)
    add("Quest givers", on(settings.givers))
    add("QuestieDB version", WalkMapLiveDB and WalkMapLiveDB.Version
        and WalkMapLiveDB.Version() or "unknown")
    add("Quest info", WalkMapQuestInfo and WalkMapQuestInfo.Status and WalkMapQuestInfo.Status() or "unavailable")
    add("Minimap tooltips", WalkMapMiniHover and WalkMapMiniHover.Status and WalkMapMiniHover.Status() or "unavailable")
    add("Window layer", WalkMapDialogLayer and WalkMapDialogLayer.Status and WalkMapDialogLayer.Status() or "unavailable")
    add("Button hints", (settings.controllerHints ~= false and "on" or "off") .. "; context "
        .. tostring(WalkMapNativeController and WalkMapNativeController.HintContext
            and WalkMapNativeController.HintContext() or "none")
        .. "; news seen " .. tostring(type(WalkMapSettings) == "table" and WalkMapSettings.newsSeen or "never"))
    add("Corpse", WalkMapCorpse and WalkMapCorpse.Status and WalkMapCorpse.Status() or "unavailable")
    add("Group announcements", WalkMapAnnounce and WalkMapAnnounce.Status and WalkMapAnnounce.Status() or "unavailable")
    add("Zone tracker", WalkMapTracker and WalkMapTracker.Status and WalkMapTracker.Status() or "unavailable")
    add("Quests removed from tracker", extras.TrackerHiddenCount())
    add("Quest visibility policy", WalkMapQuestRules and WalkMapQuestRules.PolicyStatus()
        or "basic filters")
    add("Last quest giver check", lastGiverSummary)
    add("Giver level", settings.level == 0 and "automatic" or settings.level)
    add("Quest icons", on(settings.objectiveIcons))
    add("Focus icons only", on(settings.focusObjectiveIcons))
    add("Quest names", on(settings.questLabels))
    add("Bag sorting", on(settings.bagSortEnabled))
    add("Auto-sell junk", on(settings.autoSellJunk))
    add("Vendor messages", on(settings.vendorMessages))
    add("Bag tools", WalkMapBags and WalkMapBags.Diagnostics() or "not loaded")
    add("Nearest focused objective", on(settings.nearestObjective))
    add("Clear view", on(settings.clearView))
    add("Follow", on(settings.follow))
    add("Right-click map level up", on(settings.rightClickUp))
    add("Player marker halo", on(settings.playerHalo ~= false))
    add("Fade while moving", on(settings.fadeWhileMoving) .. string.format(" (%d%%, arrow %s)",
        math.floor(extras.FadeAlpha() * 100 + 0.5), settings.fadeKeepArrow ~= false and "kept" or "fades"))
    add("Wheel opens quest log", on(settings.wheelOpensQuestLog ~= false))
    add("Wheel in combat", WalkMapWheelCombat and WalkMapWheelCombat.Status() or "unavailable")
    add("WalkMap's combat wheel", WalkMapCombatWheel and WalkMapCombatWheel.Status() or "unavailable")
    add("Dungeon map addon", tostring(extras.DungeonMapAddon() or "none") .. ", hand-off "
        .. extras.DungeonMapMode() .. (extras.HandOffDungeonMap() and " (active)" or ""))
    add("Game quest log guard", WalkMapGameMapGuard and WalkMapGameMapGuard.Status() or "unavailable")
    add("Friends and guild", WalkMapFriends and WalkMapFriends.Status() or "unavailable")
    add("Group progress", WalkMapGroupProgress and WalkMapGroupProgress.Status() or "unavailable")
    add("Unexplored areas", settings.unexplored and ("on, " .. (WalkMapRevealData and "data loaded" or "no data")) or "off")
    add("Map/quest log keys", on(settings.useGameMapKeys)
        .. (WalkMapQuestLog and WalkMapQuestLog.KeyStatus and ("; " .. WalkMapQuestLog.KeyStatus()) or "")
        .. (WalkMapQuestLog and WalkMapQuestLog.InterceptStatus and ("; " .. WalkMapQuestLog.InterceptStatus()) or ""))
    add("WalkMap quest focus", settings.questSolo and tostring(settings.questFocusID) or "off")
    add("Waypoint", settings.waypoint and string.format("map %s at %.1f, %.1f",
        tostring(settings.waypoint.mapID), settings.waypoint.x * 100, settings.waypoint.y * 100) or "none")
    add("Pad focus", on(settings.controllerMode))
    add("Native controller selected", on(settings.nativeController))
    add("Controller backend", WalkMapNativeController and WalkMapNativeController.Status()
        or "custom navigation")
    add("Native controller details", WalkMapNativeController
        and WalkMapNativeController.Diagnostics() or "not loaded")
    add("Custom controller paused", WalkMapMiniSource and WalkMapMiniSource.ControllerPaused
        and on(WalkMapMiniSource.ControllerPaused()) or "unknown")
    add("WalkMap minimap", on(settings.miniMap))
    add("WalkMap minimap terrain", settings.miniTerrain)
    add("Minimap zoom", settings.miniZoom)
    add("Game minimap icons", on(settings.nativeIcons))
    add("WalkMap mini icon scale / spacing", settings.miniIconScale
        .. " / " .. settings.miniIconGap .. " px")
    add("Game mini icon scale / spacing", settings.nativeIconScale
        .. " / " .. settings.nativeIconGap .. " px")
    add("WalkMap mini marker radius", settings.miniIconRange * 100 .. "%")
    add("Game mini marker radius", settings.nativeIconRange * 100 .. "%")
    add("Large map zoom", settings.zoomIndex or "default")
    local places = {}
    for key, enabled in pairs(settings.placeFilters) do
        if enabled then places[#places + 1] = key end
    end
    table.sort(places)
    add("Places", #places > 0 and table.concat(places, ", ") or "none")
    local hidden = 0
    for _, value in pairs(settings.hiddenGivers) do
        if value then hidden = hidden + 1 end
    end
    add("Hidden quest givers", hidden)
    local hiddenMarkers = 0
    for _, value in pairs(settings.hiddenMarkers) do
        if value then hiddenMarkers = hiddenMarkers + 1 end
    end
    add("Hidden marker locations", hiddenMarkers)
    local levelOK, level = pcall(function() return UnitLevel and UnitLevel("player") end)
    add("Character level", levelOK and level or "unknown")
    local class
    if UnitClass then
        local ok, name, token = pcall(UnitClass, "player")
        if ok then class = token or name end
    end
    add("Class", class or "unknown")
    local source = WalkMapMiniSource
    if source then
        local snapshotOK, snapshotError = pcall(function()
            local mapID, files, artW, artH, _, _, _, _, quests, objectives,
                _, areas, dot = source.Snapshot()
            add("WalkMap zone ID", mapID or "none")
            add("WalkMap art", files and artW and artH
                and (tostring(artW) .. "x" .. tostring(artH)) or "none")
            add("Large map open", on(source.IsFullMapShown()))
            add("Tracked quest ID", source.FocusedQuestID() or 0)
            local function countVisible(pool)
                local count = 0
                for _, marker in ipairs(pool or {}) do
                    if not marker.IsForbidden or not marker:IsForbidden() then
                        local ok, shown = pcall(marker.IsShown, marker)
                        if ok and shown then count = count + 1 end
                    end
                end
                return count
            end
            add("Visible game quest pins / areas", countVisible(quests)
                .. " / " .. countVisible(areas))
            add("Visible objective pins", countVisible(objectives))
            if dot and dot.mapPercentX and dot.mapPercentY then
                add("Player on WalkMap", string.format("%.1f, %.1f",
                    dot.mapPercentX * 100, dot.mapPercentY * 100))
            end
            if source.MiniStatus then
                local state, activeMap = source.MiniStatus()
                add("Minimap preview state", state)
                add("Minimap preview zone ID", activeMap or "none")
            end
        end)
        if not snapshotOK then add("WalkMap snapshot", "unavailable: " .. tostring(snapshotError)) end
    end
    local ok, bestMap = pcall(function()
        return C_Map.GetBestMapForUnit("player")
    end)
    add("Game best zone ID", ok and (bestMap or "none") or "error")
    local function nativeValue(method)
        if not source or type(source[method]) ~= "function" then return "unknown" end
        local ok, value = pcall(source[method])
        return ok and value or "unavailable"
    end
    local native = nativeValue("NativeDebugState")
    if type(native) ~= "table" then native = {} end
    add("Game minimap shown", native.shown or "unknown")
    add("Game minimap size", native.size or "unknown")
    add("Game minimap zoom", native.zoom or "unknown")
    add("Game terrain shape", nativeValue("LiveMiniStatus"))
    add("Game minimap mask", nativeValue("NativeMaskStatus"))
    add("Game minimap redraw", nativeValue("NativeRefreshStatus"))
    lines[#lines + 1] = "Recent events (seconds since login):"
    for _, event in ipairs(recentEvents) do
        lines[#lines + 1] = string.format("%.1f: %s", event.time, event.message)
    end
    lines[#lines + 1] = "Recent quest focus changes:"
    for _, event in ipairs(recentFocus) do
        lines[#lines + 1] = string.format("%.1f: %s", event.time, event.message)
    end
    if #previousEvents > 0 or #previousFocus > 0 then
        lines[#lines + 1] = "Previous session events (saved on normal exit):"
        for _, event in ipairs(previousEvents) do
            lines[#lines + 1] = string.format("%.1f: %s", event.time, event.message)
        end
        lines[#lines + 1] = "Previous session focus changes:"
        for _, event in ipairs(previousFocus) do
            lines[#lines + 1] = string.format("%.1f: %s", event.time, event.message)
        end
    end
    return table.concat(lines, "\n")
end

local debugPanel
local function createDebugPanel()
    if not debugPanel then
        debugAction = "create copy window"
        local panel = CreateFrame("Frame", nil, UIParent)
        panel:Hide()
        panel:SetSize(570, 440)
        panel:SetPoint("CENTER")
        panel:SetFrameStrata("DIALOG")
    -- Keep this layer when the map itself changes layer (NPC and game
    -- windows): a parent's SetFrameStrata otherwise drags children along.
    if panel.SetFixedFrameStrata then panel:SetFixedFrameStrata(true) end
        panel:SetFrameLevel(100)
        panel:SetClampedToScreen(true)
        panel:EnableMouse(true)
        WalkMapUI.Window(panel)
        local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", panel, "TOP", 0, -8)
        title:SetText("WalkMap debug report")
        local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", panel, "TOPLEFT", 15, -43)
        hint:SetText("Click the report, then press Ctrl+C. Alternative: /walkmap debug chat")
        local scroll = CreateFrame("ScrollFrame", nil, panel)
        scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 15, -69)
        scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -15, 43)
        scroll:EnableMouseWheel(true)
        local box = CreateFrame("EditBox", nil, scroll)
        box:SetMultiLine(true)
        box:SetAutoFocus(false)
        box:EnableMouse(true)
        box:SetFontObject("ChatFontNormal")
        box:SetWidth(520)
        box:SetHeight(1550)
        box:SetScript("OnEscapePressed", function() panel:Hide() end)
        box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        box:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0) end)
        scroll:SetScrollChild(box)
        scroll:SetScript("OnMouseWheel", function(self, delta)
            self:SetVerticalScroll(math.max(0, math.min(
                box:GetHeight() - self:GetHeight(),
                self:GetVerticalScroll() - delta * 40)))
        end)
        panel.box = box
        panel.scroll = scroll
        local close = CreateFrame("Button", nil, panel)
        close:SetSize(70, 23)
        close:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -12, 10)
        extras.StyleButton(close)
        local label = close:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("CENTER")
        label:SetText("Done")
        close:SetScript("OnClick", function() panel:Hide() end)
        debugPanel = panel
        debugAction = nil
    end
end

function extras.PrintDebug()
    local report = extras.DebugReport()
    settings.lastDebugReport = report
    for line in report:gmatch("[^\n]+") do
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(line) else print(line) end
    end
end

function extras.ShowDebug()
    if InCombatLockdown and InCombatLockdown() then
        extras.PrintDebug()
        return
    end
    local report = extras.DebugReport()
    settings.lastDebugReport = report
    local ok, message = pcall(function()
        createDebugPanel()
        extras.CloseMenus()
        debugAction = "fill copy window"
        debugPanel.box:SetText(report)
        debugPanel.scroll:SetVerticalScroll(0)
        debugAction = "show copy window"
        debugPanel:Show()
    end)
    debugAction = nil
    if not ok then
        extras.DebugEvent("Debug window unavailable: " .. tostring(message))
        extras.PrintDebug()
    end
    -- The user can focus this edit box directly. Opening a report must not
    -- request keyboard/chat focus from a synthetic gamepad button click.
end

local function makePin(pool, index, icon, x, y, name, detail, size, markerKey, iconCoords)
    local pin = pool[index]
    if not pin then
        pin = CreateFrame("Frame", nil, canvas)
        -- Quest givers sit above places; objectives are drawn above both.
        pin:SetFrameLevel(canvas:GetFrameLevel() + (pool == giverPins and 3 or 2))
        pin:EnableMouse(true)
        pin:EnableKeyboard(false)
        if pin.EnableGamePadButton then pin:EnableGamePadButton(false) end
        if pin.EnableGamePadStick then pin:EnableGamePadStick(false) end
        pin.texture = pin:CreateTexture(nil, "ARTWORK")
        pin.texture:SetAllPoints(pin)
        pin:SetScript("OnEnter", function(self)
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.pinName)
                if self.detail and self.detail ~= "" then
                    GameTooltip:AddLine(self.detail, 0.9, 0.85, 0.5)
                end
                if self.giverKey then
                    GameTooltip:AddLine("Right-click or Shift-click to hide this giver", 0.7, 0.8, 1)
                elseif self.hiddenKey then
                    GameTooltip:AddLine("Right-click or Shift-click to hide this marker", 0.7, 0.8, 1)
                end
                GameTooltip:Show()
            end
        end)
        pin:SetScript("OnLeave", function()
            if GameTooltip then GameTooltip:Hide() end
        end)
        pin:SetScript("OnMouseDown", function(self, button)
            local hideClick = button == "RightButton"
                or (button == "LeftButton" and IsShiftKeyDown and IsShiftKeyDown())
            -- Middle-click or Alt-click: waypoint at this marker.
            if button == "MiddleButton" or (button == "LeftButton" and IsAltKeyDown and IsAltKeyDown()) then
                local mapID = WalkMapCore and WalkMapCore.CurrentMap()
                if mapID and self.mapPercentX and self.mapPercentY and WalkMapWaypoint then
                    WalkMapWaypoint.Set(mapID, self.mapPercentX, self.mapPercentY,
                        self.questTitle or self.pinName or self.objectiveName or "Marker")
                end
                return
            end
            if hideClick and self.giverKey then
                settings.hiddenGivers[self.giverKey] = true
                if GameTooltip then GameTooltip:Hide() end
                self:Hide()
                extras.Invalidate()
                if changed then changed() end
            elseif hideClick and self.hiddenKey then
                if GameTooltip then GameTooltip:Hide() end
                self:Hide()
                extras.HideMarker(self.hiddenKey)
            end
        end)
        pool[index] = pin
    end
    if pin.iconSize ~= size then
        pin:SetSize(size, size)
        pin.iconSize = size
    end
    local px, py = (x / 100) * canvas:GetWidth(), -(y / 100) * canvas:GetHeight()
    if pin.anchorX ~= px or pin.anchorY ~= py then
        pin:ClearAllPoints()
        pin:SetPoint("CENTER", canvas, "TOPLEFT", px, py)
        pin.anchorX, pin.anchorY = px, py
    end
    pin.mapPercentX, pin.mapPercentY = x / 100, y / 100
    if pin.iconFile ~= icon then
        pin.texture:SetTexture(icon)
        pin.iconFile = icon
    end
    -- Sheet icons (class circles) need a crop; minimap copies reuse it.
    if pin.iconCoords ~= iconCoords then
        if iconCoords then
            pin.texture:SetTexCoord(iconCoords[1], iconCoords[2], iconCoords[3], iconCoords[4])
        else
            pin.texture:SetTexCoord(0, 1, 0, 1)
        end
        pin.iconCoords = iconCoords
    end
    pin.pinName = name
    pin.detail = detail
    pin.hiddenKey = markerKey
    pin.giverKey = nil
    pin:Show()
end

-- Moving existing pins is cheap enough to do every frame during a drag.
-- Refreshing quest and vendor data can wait until the drag ends.
function extras.RepositionPins()
    if not canvas then return end
    for _, pool in ipairs({servicePins, giverPins, resourcePins, rarePins}) do
        for _, pin in ipairs(pool) do
            if pin:IsShown() and pin.mapPercentX and pin.mapPercentY then
                local px = pin.mapPercentX * canvas:GetWidth()
                local py = -pin.mapPercentY * canvas:GetHeight()
                pin:ClearAllPoints()
                pin:SetPoint("CENTER", canvas, "TOPLEFT", px, py)
                pin.anchorX, pin.anchorY = px, py
            end
        end
    end
end

-- Flight paths you have not discovered yet, from the game (taxi nodes on this
-- map). A flight master's pin is matched to the nearest node.
local function undiscoveredFlight(nodes, x, y)
    local best, bestDistance
    for _, node in ipairs(nodes) do
        local nx, ny
        if node.position and node.position.GetXY then nx, ny = node.position:GetXY() end
        if nx and ny then
            local d = (nx - x) ^ 2 + (ny - y) ^ 2
            if not bestDistance or d < bestDistance then best, bestDistance = node, d end
        end
    end
    -- Within about 3% of the map: the same flight master.
    return best and bestDistance < 0.0009 and best.isUndiscovered == true or false
end

local function showServices(mapID)
    local count = 0
    local shown = {}
    local taxiNodes
    if settings.placeFilters.flight and C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap then
        local ok, nodes = pcall(C_TaxiMap.GetTaxiNodesForMap, mapID)
        taxiNodes = ok and type(nodes) == "table" and nodes or nil
    end
    for _, entry in ipairs((WalkMapData.services or {})[mapID] or {}) do
        local role, profession = entry[5], entry[6]
        if factionOK(entry[4]) and
            (settings.placeFilters[role] or
             (role == "trainer" and settings.placeFilters[profession]) or
             (role == "class" and settings.placeFilters["class:" .. profession])) then
            local identity = entry[1] .. ":" .. entry[2] .. ":" .. entry[3]
            local key = extras.MarkerKey("service", mapID, entry[3],
                entry[1], entry[2])
            if not shown[identity] and not extras.MarkerHidden(key) then
                shown[identity] = true
                count = count + 1
                local icon, coords = role == "trainer" and professionIcon(profession)
                    or icons[role] or icons.trainer, nil
                if role == "class" and type(profession) == "string" then
                    icon, coords = classIcon(profession)
                end
                local undiscovered = role == "flight" and taxiNodes
                    and undiscoveredFlight(taxiNodes, entry[1] / 100, entry[2] / 100) or false
                makePin(servicePins, count, icon,
                    entry[1], entry[2], entry[3], undiscovered
                        and ((entry[7] and entry[7] ~= "" and (entry[7] .. "\n") or "")
                            .. "|cffff8080Flight path not discovered yet|r") or entry[7], 17, key, coords)
                -- Undiscovered flight paths: greyed out with a red tint.
                local pin = servicePins[count]
                pin.texture:SetDesaturated(undiscovered)
                if undiscovered then pin.texture:SetVertexColor(1, 0.55, 0.55)
                else pin.texture:SetVertexColor(1, 1, 1) end
                if count >= 120 then break end
            end
        end
    end
    for i = count + 1, #servicePins do servicePins[i]:Hide() end
end

local function showResources(mapID)
    local count = 0
    local herbs, ores = 0, 0
    for _, entry in ipairs((WalkMapData.resources or {})[mapID] or {}) do
        local kind = entry[4]
        local key = extras.MarkerKey("resource", mapID,
            kind .. ":" .. entry[3], entry[1], entry[2])
        if settings.placeFilters[kind]
            and not extras.MarkerHidden(key)
            and (kind == "herb" and herbs < 300 or kind == "ore" and ores < 300) then
            count = count + 1
            if kind == "herb" then herbs = herbs + 1 else ores = ores + 1 end
            makePin(resourcePins, count, icons[kind], entry[1], entry[2],
                entry[3], kind == "herb" and "Herb" or "Mining node", 14, key)
        end
    end
    for i = count + 1, #resourcePins do resourcePins[i]:Hide() end
end

-- Rare mobs and rare elites from QuestieDB (LiveDB: WalkMapData.rares).
local RARE_RANK = {[2] = "Rare Elite", [4] = "Rare"}
local function showRares(mapID)
    local count = 0
    if settings.placeFilters.rare then
        for _, entry in ipairs((WalkMapData.rares or {})[mapID] or {}) do
            local key = extras.MarkerKey("rare", mapID, entry[3], entry[1], entry[2])
            if not extras.MarkerHidden(key) then
                count = count + 1
                local levels = entry[5] and (entry[6] and entry[6] ~= entry[5]
                    and ("Level " .. entry[5] .. "-" .. entry[6]) or ("Level " .. entry[5])) or nil
                local detail = (RARE_RANK[entry[4]] or "Rare") .. (levels and (" - " .. levels) or "")
                makePin(rarePins, count, icons.rare, entry[1], entry[2], entry[3],
                    "|cffc0c0ff" .. detail .. "|r", 16, key)
                if count >= 120 then break end
            end
        end
    end
    for i = count + 1, #rarePins do rarePins[i]:Hide() end
end

local function isCompleted(id)
    if C_QuestLog then
        if C_QuestLog.IsQuestFlaggedCompleted then
            local ok, completed = pcall(C_QuestLog.IsQuestFlaggedCompleted, id)
            if ok and completed then return true end
        end
    end
    if IsQuestFlaggedCompleted then
        local ok, completed = pcall(IsQuestFlaggedCompleted, id)
        if ok and completed then return true end
    end
    return false
end

local function isInLog(id)
    if C_QuestLog then
        if C_QuestLog.IsOnQuest then
            local ok, active = pcall(C_QuestLog.IsOnQuest, id)
            if ok and active then return true end
        end
        if C_QuestLog.GetLogIndexForQuestID then
            local ok, index = pcall(C_QuestLog.GetLogIndexForQuestID, id)
            if ok and type(index) == "number" and index > 0 then return true end
        end
    end
    if GetQuestLogIndexByID then
        local ok, index = pcall(GetQuestLogIndexByID, id)
        if ok and type(index) == "number" and index > 0 then return true end
    end
    return false
end

local function prerequisitesMet(id)
    local q = WalkMapData.quests[id]
    if not q then return false end
    -- Without a completion API, treat requirements as unknown.
    if not (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted)
        and not IsQuestFlaggedCompleted then return true end
    local prerequisites = WalkMapData.prereqs and WalkMapData.prereqs[id]
    if prerequisites then
        if #prerequisites[1] > 0 then
            local anyComplete = false
            for _, prior in ipairs(prerequisites[1]) do
                if isCompleted(math.abs(prior)) then anyComplete = true break end
            end
            if not anyComplete then return false end
        end
        for _, prior in ipairs(prerequisites[2]) do
            if not isCompleted(math.abs(prior)) then return false end
        end
    end
    if q[6] ~= 0 and not isInLog(q[6]) then return false end
    if q[7] ~= 0 and (isCompleted(q[7]) or isInLog(q[7])) then return false end
    if q[8] ~= 0 and isCompleted(q[8]) then return false end
    if q[9] ~= 0 and not (isCompleted(q[9]) or isInLog(q[9])) then return false end
    return true
end

local function questIsNearLevel(id, level, classBit, raceBit, minQuestLevel)
    local q = WalkMapData.quests[id]
    if not q then return false end
    local required, questLevel, raceMask, classMask, maximum = q[1], q[2], q[3], q[4], q[5]
    if required > level or (maximum > 0 and maximum < level) then return false end
    if questLevel > 0 and (questLevel < minQuestLevel or questLevel > level + 5) then
        return false
    end
    if classBit and classMask > 0 and math.floor(classMask / classBit) % 2 == 0 then
        return false
    end
    if raceBit and raceMask > 0 and math.floor(raceMask / raceBit) % 2 == 0 then
        return false
    end
    if isCompleted(id) or isInLog(id) or not prerequisitesMet(id) then return false end
    return not WalkMapQuestRules or WalkMapQuestRules.Allows(id, q, isCompleted, isInLog)
end

local function showGivers(mapID, level)
    local count = 0
    local examples = {}
    if WalkMapQuestRules then WalkMapQuestRules.Refresh() end
    local classBit = playerClassBit()
    local raceBit = playerRaceBit()
    local minQuestLevel = level - trivialRange(level)
    if settings.givers then
        for _, entry in ipairs((WalkMapData.givers or {})[mapID] or {}) do
            local giverKey = tostring(mapID) .. "|" .. entry[3]
            if factionOK(entry[4]) and not settings.hiddenGivers[giverKey] then
                local firstLevel, offered, instanceCount, pvpCount = nil, {}, 0, 0
                for _, id in ipairs(entry[5]) do
                    if questIsNearLevel(id, level, classBit, raceBit, minQuestLevel) then
                        local quest = WalkMapData.quests[id]
                        firstLevel = firstLevel or quest[2]
                        -- "[22] Name (Dungeon)", the level coloured against yours.
                        local questLevel = type(quest[2]) == "number" and quest[2] > 0 and quest[2] or nil
                        local levelText = ""
                        if questLevel then
                            local r, g, b = 0.8, 0.8, 0.8
                            if WalkMapQuestInfo then r, g, b = WalkMapQuestInfo.Color(id, questLevel) end
                            levelText = string.format("|cff%02x%02x%02x[%d]|r ", math.floor(r * 255),
                                math.floor(g * 255), math.floor(b * 255), questLevel)
                        end
                        local instance = WalkMapQuestInfo and WalkMapQuestInfo.InstanceTag(id)
                        local pvp = not instance and WalkMapQuestInfo and WalkMapQuestInfo.PvPTag
                            and WalkMapQuestInfo.PvPTag(id)
                        if instance then instanceCount = instanceCount + 1 end
                        if pvp then pvpCount = pvpCount + 1 end
                        offered[#offered + 1] = levelText .. (quest.name or "Quest")
                            .. (instance and (" |cffff5050(" .. instance .. ")|r") or "")
                            .. (pvp and " |cffff9933(PvP)|r" or "")
                            .. (WalkMapQuestInfo and WalkMapQuestInfo.XPText(id) ~= ""
                                and (" " .. WalkMapQuestInfo.XPText(id)) or "")
                            .. " |cff808080[" .. tostring(id) .. "]|r"
                    end
                end
                if firstLevel then
                    count = count + 1
                    local lines = {}
                    for index = 1, math.min(#offered, 6) do
                        lines[#lines + 1] = offered[index]
                    end
                    if #offered > 6 then lines[#lines + 1] = "+ " .. (#offered - 6) .. " more" end
                    makePin(giverPins, count, icons.giver,
                        entry[1], entry[2], entry[3],
                        table.concat(lines, "\n"), 14)
                    giverPins[count].giverKey = giverKey
                    -- Red "!" when everything offered here is a dungeon/raid quest.
                    -- Orange "!" when everything offered is a PvP quest.
                    local instanceOnly = instanceCount > 0 and instanceCount == #offered
                    local pvpOnly = pvpCount > 0 and pvpCount == #offered
                    local tint = instanceOnly and "instance" or pvpOnly and "pvp" or nil
                    local color = WalkMapUI.GiverTint(tint)
                    giverPins[count].texture:SetVertexColor(color[1], color[2], color[3])
                    giverPins[count].instanceOnly = instanceOnly
                    giverPins[count].giverTint = tint
                    if #examples < 8 then
                        examples[#examples + 1] = entry[3] .. ": " .. table.concat(offered, ", ")
                    end
                    if count >= 120 then break end
                end
            end
        end
    end
    for i = count + 1, #giverPins do giverPins[i]:Hide() end
    lastGiverSummary = "map " .. tostring(mapID) .. ", " .. count .. " pins"
        .. (#examples > 0 and ("; " .. table.concat(examples, "; ")) or "")
end

function extras.Refresh(mapID)
    if not canvas or not WalkMapData then return end
    local now = GetTime()
    local level = playerLevel()
    if mapID == lastMap and level == lastLevel and now < nextRefresh then return end
    lastMap, lastLevel = mapID, level
    nextRefresh = now + 5
    -- A subzone's coordinates are not its parent zone's coordinates.
    for _, entry in ipairs({
        {"services", showServices, servicePins},
        {"quest givers", showGivers, giverPins},
        {"resources", showResources, resourcePins},
        {"rare mobs", showRares, rarePins},
    }) do
        local ok, message = pcall(entry[2], mapID, level)
        if not ok then
            for _, pin in pairs(entry[3]) do pcall(pin.Hide, pin) end
            extras.DebugEvent("Place update " .. entry[1] .. ": " .. tostring(message))
        end
    end
end

-- Browsing another zone must not replace live minimap places or quest givers.
local miniPlaces
function extras.RefreshMini(mapID, target)
    if not miniPlaces then miniPlaces = {services = {}, givers = {}, resources = {}} end
    local state, now = miniPlaces, GetTime()
    local level = playerLevel()
    if state.map ~= mapID or state.level ~= level or state.revision ~= revision
        or not state.nextAt or now >= state.nextAt then
        local oldCanvas, oldServices, oldGivers, oldResources, oldSummary = canvas, servicePins, giverPins, resourcePins, lastGiverSummary
        canvas, servicePins, giverPins, resourcePins = target, state.services, state.givers, state.resources
        local ok, message = pcall(function()
            showServices(mapID)
            showGivers(mapID, level)
            showResources(mapID)
        end)
        canvas, servicePins, giverPins, resourcePins, lastGiverSummary = oldCanvas, oldServices, oldGivers, oldResources, oldSummary
        if not ok then
            for _, pool in ipairs({state.services, state.givers, state.resources}) do
                for _, pin in pairs(pool) do pin:Hide() end
            end
            extras.DebugEvent("Live minimap places: " .. tostring(message))
        end
        state.map, state.level, state.revision, state.nextAt = mapID, level, revision, now + 5
    end
    return state.services, state.givers, state.resources
end

local function refreshLabels()
    if not buttons then return end
    local count, only = 0, nil
    for key, enabled in pairs(settings.placeFilters) do
        if enabled and placeNames[key] then count, only = count + 1, key end
    end
    local selection = count == 0 and "None" or
        (count == 1 and placeNames[only] or tostring(count) .. " selected")
    buttons[1].label:SetText(owner:GetWidth() < 480
        and "Places" or "Places: " .. selection)
    buttons[2].label:SetText(owner:GetWidth() < 480
        and (settings.clearView and "Clear: On" or "Clear: Off")
        or (settings.clearView and "Clear view: On" or "Clear view: Off"))
    local miniState = not settings.miniMap and "Off"
        or settings.miniTerrain == "game" and "Game" or "Zone"
    buttons[3].label:SetText(owner:GetWidth() < 480
        and "Mini: " .. miniState or "WalkMap mini: " .. miniState)
    local paused = settings.follow and (followPausedAt ~= nil
        or (WalkMapMaps and WalkMapMaps.Selected and WalkMapMaps.Selected() ~= nil))
    buttons[4].label:SetText(owner:GetWidth() < 480
        and (paused and "Paused" or settings.follow and "Follow ON" or "Follow")
        or (paused and "Follow: Paused" or settings.follow and "Follow: On" or "Follow: Off"))
    for _, index in ipairs({2, 3, 4}) do
        local active = index == 2 and settings.clearView
            or index == 3 and settings.miniMap
            or index == 4 and settings.follow and not paused
        buttons[index].label:SetTextColor(active and 0.4 or 1,
            active and 1 or 1, active and 0.8 or 1)
    end
    if viewButton then viewButton.label:SetText("Settings") end
    if questButton then
        local focus = extras.QuestFocus()
        local title = focus and C_QuestLog and C_QuestLog.GetTitleForQuestID
            and C_QuestLog.GetTitleForQuestID(focus)
        questButton.label:SetText(focus and (title or "1 quest") or "Quests: All")
        if focus then questButton.label:SetTextColor(0.4, 1, 0.8)
        else questButton.label:SetTextColor(1, 1, 1) end
    end
end

local function setOption(field, value)
    settings[field] = value
    if WalkMapBags then WalkMapBags.SettingsChanged() end
    if field == "look" and type(WalkMapSettings) == "table" then
        WalkMapSettings.look = value
    end
    if field == "showQuestXP" then
        if WalkMapTracker and WalkMapTracker.Refresh then WalkMapTracker.Refresh() end
        if WalkMapQuestLog and WalkMapQuestLog.Refresh then WalkMapQuestLog.Refresh() end
    end
    if field == "combatWheel" and WalkMapCombatWheel and WalkMapCombatWheel.Refresh then
        WalkMapCombatWheel.Refresh()
    end
    if field == "closeInCombat" and WalkMapCombat and WalkMapCombat.SettingChanged then
        WalkMapCombat.SettingChanged()
    end
    if field == "unexplored" and WalkMapCore and WalkMapCore.RefreshExploration then
        WalkMapCore.RefreshExploration()
    end
    if (field == "friendsOnMap" or field == "guildOnMap" or field == "shareLocation")
        and WalkMapFriends and WalkMapFriends.SettingChanged then
        WalkMapFriends.SettingChanged(field)
    end
    markProfileEdited(field)
    if menu then setControllerPanelVisible(menu, false) end
    refreshLabels()
    if refreshSettingsRows and settingsPanel and settingsPanel:IsShown() then
        refreshSettingsRows()
    end
    extras.Invalidate()
    if WalkMapNativeController then WalkMapNativeController.RequestRefresh() end
    if changed then changed() end
end

-- =========================================================
-- Dropdown row decoration: icon, submenu arrow, right-hand detail text,
-- separators and a hover/focus bar. The bar follows OnEnter/OnLeave, which
-- both the mouse and native controller focus trigger, and stays lit on the
-- row whose submenu is open so the path through the menu is visible.
-- =========================================================
local MENU_ARROW = "Interface\\ChatFrame\\ChatFrameExpandArrow"
local HOVER_TEXT = {1, 0.82, 0.2}

local function rowDecor(row)
    local decor = rawget(row, "walkmapDecor")
    if decor then return decor end
    decor = {}
    decor.hover = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    decor.hover:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
    decor.hover:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 1)
    decor.hover:SetColorTexture(1, 0.76, 0.28, 0.16)
    decor.hover:Hide()
    decor.accent = row:CreateTexture(nil, "BORDER")
    decor.accent:SetWidth(2)
    decor.accent:SetPoint("TOPLEFT", decor.hover, "TOPLEFT")
    decor.accent:SetPoint("BOTTOMLEFT", decor.hover, "BOTTOMLEFT")
    decor.accent:SetColorTexture(1, 0.82, 0.3, 0.95)
    decor.accent:Hide()
    decor.separator = row:CreateTexture(nil, "BORDER")
    decor.separator:SetHeight(1)
    decor.separator:SetPoint("TOPLEFT", row, "TOPLEFT", 6, 0)
    decor.separator:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, 0)
    decor.separator:SetColorTexture(0.86, 0.68, 0.32, 0.35)
    decor.separator:Hide()
    decor.icon = row:CreateTexture(nil, "ARTWORK")
    decor.icon:SetSize(16, 16)
    decor.icon:Hide()
    decor.arrow = row:CreateTexture(nil, "ARTWORK")
    decor.arrow:SetSize(14, 14)
    decor.arrow:SetPoint("RIGHT", row, "RIGHT", -3, 0)
    if decor.arrow:SetTexture(MENU_ARROW) == false then
        -- Text fallback only if the client lacks the dropdown arrow art.
        decor.arrow = nil
        decor.arrowText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        decor.arrowText:SetPoint("RIGHT", row, "RIGHT", -5, 0)
        decor.arrowText:SetText(">")
        decor.arrowText:Hide()
    else
        decor.arrow:Hide()
    end
    decor.detail = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    decor.detail:SetJustifyH("RIGHT")
    decor.detail:SetWordWrap(false)
    decor.detail:Hide()
    -- The new bar replaces the generic mouse-only highlight on menu rows.
    local highlight = rawget(row, "walkmapHighlight")
    if highlight then highlight:SetAlpha(0) end
    row.walkmapDecor = decor
    return decor
end

local function refreshRowHover(row)
    local decor = rawget(row, "walkmapDecor")
    if not decor then return end
    local lit = row.walkmapHovered or row.walkmapOpen
    decor.hover:SetShown(lit == true)
    decor.accent:SetShown(lit == true)
    local r, g, b = 0.8, 0.78, 0.72
    if lit then r, g, b = 1, 0.85, 0.35 end
    if decor.arrow then decor.arrow:SetVertexColor(r, g, b)
    elseif decor.arrowText then decor.arrowText:SetTextColor(r, g, b) end
end

local function applyRowDecor(row)
    local decor = rowDecor(row)
    local opts = row.walkmapDecorOpts or {}
    local checkbox = rawget(row, "checkboxBorder")
    local left = checkbox and checkbox:IsShown() and 26 or 6
    if opts.icon then
        decor.icon:SetTexture(opts.icon)
        local c = opts.iconCoords or {0.08, 0.92, 0.08, 0.92}
        decor.icon:SetTexCoord(c[1], c[2], c[3], c[4])
        decor.icon:ClearAllPoints()
        decor.icon:SetPoint("LEFT", row, "LEFT", left, 0)
        decor.icon:Show()
        left = left + 21
    else
        decor.icon:Hide()
    end
    local arrow = decor.arrow or decor.arrowText
    if arrow then arrow:SetShown(opts.arrow == true) end
    decor.detail:ClearAllPoints()
    decor.detail:SetPoint("RIGHT", row, "RIGHT", opts.arrow and -20 or -6, 0)
    local detail = opts.detail or ""
    decor.detail:SetText(detail)
    local color = opts.detailColor or {0.62, 0.6, 0.55}
    decor.detail:SetTextColor(color[1], color[2], color[3])
    decor.detail:SetShown(detail ~= "")
    row.label:ClearAllPoints()
    row.label:SetPoint("LEFT", row, "LEFT", left, 0)
    if detail ~= "" then
        row.label:SetPoint("RIGHT", decor.detail, "LEFT", -6, 0)
    else
        row.label:SetPoint("RIGHT", row, "RIGHT", opts.arrow and -20 or -6, 0)
    end
    row.label:SetWordWrap(false)
    decor.separator:SetShown(opts.separator == true)
    refreshRowHover(row)
end

local function decorateRow(row, opts)
    row.walkmapDecorOpts = opts or {}
    applyRowDecor(row)
end

local function setRowEnter(row, handler)
    row:SetScript("OnEnter", function(self)
        self.walkmapHovered = true
        refreshRowHover(self)
        handler(self)
    end)
end

local function menuRowLeave(self)
    self.walkmapHovered = false
    refreshRowHover(self)
    if self.walkmapOpen then
        self.label:SetTextColor(HOVER_TEXT[1], HOVER_TEXT[2], HOVER_TEXT[3])
    else
        self.label:SetTextColor(1, 1, 1)
    end
end

local function resetRowState(row)
    row.walkmapHovered, row.walkmapOpen = false, false
    row.label:SetTextColor(1, 1, 1)
end

local function setRowOpen(row, open)
    if not row then return end
    row.walkmapOpen = open
    refreshRowHover(row)
    if open or row.walkmapHovered then
        row.label:SetTextColor(HOVER_TEXT[1], HOVER_TEXT[2], HOVER_TEXT[3])
    else
        row.label:SetTextColor(1, 1, 1)
    end
end

local function showCheckbox(row, visible, checked)
    if not rawget(row, "checkboxBorder") then
        row.checkboxBorder = row:CreateTexture(nil, "ARTWORK")
        row.checkboxBorder:SetSize(17, 17)
        row.checkboxBorder:SetPoint("LEFT", row, "LEFT", 4, 0)
        row.checkboxBorder:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
        row.checkboxMark = row:CreateTexture(nil, "OVERLAY")
        row.checkboxMark:SetSize(17, 17)
        row.checkboxMark:SetPoint("CENTER", row.checkboxBorder, "CENTER", 0, 0)
        row.checkboxMark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    end
    row:SetChecked(checked == true)
    row.label:ClearAllPoints()
    row.label:SetPoint("LEFT", row, "LEFT", visible and 26 or 4, 0)
    if visible then
        row.checkboxBorder:Show()
        if checked then row.checkboxMark:Show() else row.checkboxMark:Hide() end
    else
        row.checkboxBorder:Hide()
        row.checkboxMark:Hide()
    end
    -- Re-place the icon/label around the checkbox; keeps any decoration.
    if rawget(row, "walkmapDecor") or row.walkmapDecorOpts then applyRowDecor(row) end
end

local function toggleView(field)
    settings[field] = not settings[field]
    markProfileEdited(field)
    for _, row in ipairs(menu.rows) do
        if row:IsShown() and row.option and row.option[1] == field then
            showCheckbox(row, true, settings[field])
        end
    end
    refreshLabels()
    extras.Invalidate()
    if changed then changed() end
end

local function accountTable()
    if type(WalkMapSettings) ~= "table" then WalkMapSettings = {} end
    return WalkMapSettings
end

function extras.HasAccountSettings()
    return type(WalkMapSettings) == "table" and type(WalkMapSettings.accountSettings) == "table"
end

function extras.AccountSettingsInfo()
    if not extras.HasAccountSettings() then return nil end
    local account = WalkMapSettings
    return account.accountSettingsFrom, account.accountSettingsAt
end

function extras.AccountForNew()
    return type(WalkMapSettings) == "table" and WalkMapSettings.accountForNew == true
end

function extras.SetAccountForNew(on)
    accountTable().accountForNew = on and true or nil
end

-- Save this character's settings as the account settings.
function extras.SaveAccountSettings()
    local account = accountTable()
    account.accountSettings = accountCopy(settings)
    local name = UnitName and UnitName("player") or nil
    local realm = GetRealmName and GetRealmName() or nil
    account.accountSettingsFrom = name and (realm and realm ~= "" and (name .. "-" .. realm) or name) or "a character"
    account.accountSettingsAt = date and date("%Y-%m-%d %H:%M") or nil
    return true
end

-- Replace this character's settings with the account settings. The
-- character's own state (focus, waypoint, hidden markers ...) is kept.
-- The caller reloads the interface so every part of WalkMap reads them.
function extras.LoadAccountSettings()
    if not extras.HasAccountSettings() then return false end
    local saved = WalkMapSettings.accountSettings
    for key in pairs(settings) do
        if not CHARACTER_ONLY[key] then settings[key] = nil end
    end
    for key, value in pairs(accountCopy(saved)) do settings[key] = value end
    return true
end

local function chooseProfile(value)
    if value == "save" then
        settings.customProfile = snapshotProfile()
        settings.profile = "custom"
    else
        if settings.profile == "custom" then
            settings.customProfile = snapshotProfile()
        end
        local selected = value == "custom" and settings.customProfile or profiles[value]
        if not selected then return end
        for _, field in ipairs(profileFields) do
            settings[field] = selected[field]
        end
        settings.profile = value
    end
    setControllerPanelVisible(menu, false)
    setControllerPanelVisible(submenu, false)
    refreshLabels()
    if refreshSettingsRows and settingsPanel and settingsPanel:IsShown() then
        refreshSettingsRows()
    end
    extras.Invalidate()
    if changed then changed() end
end

function extras.Guide()
    for _, line in ipairs({
        "|cff80ff80WalkMap guide:|r /walkmap opens or closes the map (/walkmap welcome shows the setup page); mouse wheel or LB/RB in map control zooms it; M+/M- zooms the minimap.",
        "Click the map title to browse zones by region. Your current zone is green; Player returns to it.",
        "Minimaps stay on your current zone while you browse another map.",
        "In combat the map, zone picker, Places, Follow and quest log work with the mouse; your WalkMap key or X closes it.",
        "Settings > Profiles: Questing, Exploration, or your saved My settings.",
        "Settings > Bags & vendors: sort bags or enable auto-sell for gray items. Auto-sell starts off.",
        "Bind Sort bags under Key Bindings > WalkMap, or type /walkmap sort.",
        "Quest icons show QuestieDB locations: red slay, blue object, green loot. Focused quest icons are brighter.",
        "Settings > Quests on the map > Quest icons: all quests, only WalkMap's focused quest, or off.",
        "Settings > Quests on the map > Quest areas: all, focused quest, or off for the blue quest areas.",
        "Places > Other: Herbs and Mining show known QuestieDB node locations.",
        "Right-click or Shift-click a quest giver to hide it; /walkmap givers reset restores all.",
        "WalkMap mini can use zone artwork or live game terrain; choose under Settings > Minimap.",
        "Native controller: use the game's navigation and Change Focus Frame binding.",
        "X takes control of the map: D-pad pans, LB/RB zooms, Y steps through the markers around the crosshair, A focuses the quest of a quest marker and otherwise sets a waypoint (on the selected marker or at the crosshair), X or B returns.",
        "Quests (footer) shows one quest's icons and areas, or All quests.",
        "Right-click, middle-click or Alt-click the map to set a waypoint; right-click the star to clear it. Click a quest's marker to focus that quest, and again to show all quests. Escape closes the map.",
        "Macros: /click WalkMapCloseMacro closes the map (also in combat); /click WalkMapKeyboardToggle toggles it.",
        "The book button at the end of the toolbar (or Y on the controller) folds out the quest log.",
        "The zone quest tracker lists your quests for this zone; click one to open it. Alt-drag its header to move it.",
        "When you die, a skull marks your corpse on the map and minimap until you are alive again.",
        "Settings > Quest tracker > Tell group about quest progress posts finished objectives in party chat.",
        "Settings > Quest tracker: hide the game tracker, text size, background, quests shown and width.",
        "Settings > Controller & help > Map key and wheel open: the game's map, WalkMap, or WalkMap with its quest log.",
        "D-pad follows visible rows and columns; it stops at menu and window edges.",
        "Custom controller: D-pad selects, A confirms, X pans, B backs out, Select releases focus.",
        "Bind Toggle WalkMap Pad focus, or use /walkmap pad in a macro.",
        "Hover DB for database details, or type /walkmap db. QuestieDB must be enabled.",
        "/walkmap news shows what's new in this version.",
    }) do print(line) end
end

function extras.RefreshLabels()
    if buttons then refreshLabels() end
end

-- Called on every pan step: (re)starts the pause; the setting stays on.
function extras.StopFollow()
    if not settings.follow then return end
    local wasPaused = followPausedAt ~= nil
    followPausedAt = GetTime and GetTime() or 0
    if not wasPaused and extras.RefreshLabels then extras.RefreshLabels() end
end

-- Typical level ranges for the zone chooser. WalkMap's own reference list of
-- the classic zones by English map name; zones not listed show no range.
local zoneLevels = {
    ["Dun Morogh"] = {1, 10}, ["Elwynn Forest"] = {1, 10}, ["Tirisfal Glades"] = {1, 10},
    ["Durotar"] = {1, 10}, ["Mulgore"] = {1, 10}, ["Teldrassil"] = {1, 10},
    ["Loch Modan"] = {10, 20}, ["Westfall"] = {10, 20}, ["Silverpine Forest"] = {10, 20},
    ["Darkshore"] = {10, 20}, ["The Barrens"] = {10, 25}, ["Redridge Mountains"] = {15, 25},
    ["Stonetalon Mountains"] = {15, 27}, ["Ashenvale"] = {18, 30}, ["Duskwood"] = {18, 30},
    ["Hillsbrad Foothills"] = {20, 30}, ["Wetlands"] = {20, 30}, ["Thousand Needles"] = {25, 35},
    ["Alterac Mountains"] = {30, 40}, ["Arathi Highlands"] = {30, 40}, ["Desolace"] = {30, 40},
    ["Stranglethorn Vale"] = {30, 45}, ["Badlands"] = {35, 45}, ["Dustwallow Marsh"] = {35, 45},
    ["Swamp of Sorrows"] = {35, 45}, ["Feralas"] = {40, 50}, ["Tanaris"] = {40, 50},
    ["The Hinterlands"] = {40, 50}, ["Searing Gorge"] = {43, 50}, ["Azshara"] = {45, 55},
    ["Blasted Lands"] = {45, 55}, ["Felwood"] = {48, 55}, ["Un'Goro Crater"] = {48, 55},
    ["Burning Steppes"] = {50, 58}, ["Western Plaguelands"] = {51, 58},
    ["Eastern Plaguelands"] = {53, 60}, ["Deadwind Pass"] = {55, 60},
    ["Winterspring"] = {55, 60}, ["Silithus"] = {55, 60},
    -- New in Forever (their map IDs are not in WalkMap's ID table, so the
    -- map labels look them up here by name too). Ranges as Forever's own
    -- zone overview gives them. Shen'dralas is left out until its range is
    -- confirmed (sources say 40-45 or 45-53).
    ["Zephras Isle"] = {1, 12}, ["Riverglades"] = {35, 45}, ["The Riverglades"] = {35, 45},
    ["Mount Hyjal"] = {55, 60},
}

-- Level range by English zone name, or nil.
function extras.ZoneLevelRange(name)
    local range = type(name) == "string" and zoneLevels[name]
    if range then return range[1], range[2] end
    return nil
end
local function zoneLevelDetail(name)
    local range = zoneLevels[name]
    if not range then return nil end
    local level = UnitLevel and UnitLevel("player") or 0
    -- Red-ish above you, grey below you, warm white when it fits.
    local color = level > 0 and level < range[1] - 2 and {1, 0.5, 0.4}
        or level > range[2] and {0.55, 0.55, 0.55} or {1, 0.88, 0.65}
    return range[1] .. "-" .. range[2], color
end

-- " (10-20)" coloured against your level, for the map title; "" if unknown.
function extras.ZoneLevelText(name)
    local text, color = zoneLevelDetail(name)
    if not text then return "" end
    return string.format("  |cff%02x%02x%02x(%s)|r", math.floor(color[1] * 255 + 0.5),
        math.floor(color[2] * 255 + 0.5), math.floor(color[3] * 255 + 0.5), text)
end

local function questLevelColor(level, questID)
    if WalkMapQuestInfo then return {WalkMapQuestInfo.Color(questID, level)} end
    return {0.8, 0.8, 0.8}
end

-- Quests in the log, split into those with something on the displayed map
-- and the rest. Each entry: {questID, title, detail, detailColor}.
local function questFocusEntries()
    local here, other = {}, {}
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo) then
        return here, other
    end
    local mapID = WalkMapMaps and (WalkMapMaps.Selected() or WalkMapMaps.CurrentZone())
    local onMap = {}
    if mapID and C_QuestLog.GetQuestsOnMap then
        local ok, quests = pcall(C_QuestLog.GetQuestsOnMap, mapID)
        if ok and type(quests) == "table" then
            for _, quest in ipairs(quests) do
                if quest.questID then onMap[quest.questID] = true end
            end
        end
    end
    local count, header = C_QuestLog.GetNumQuestLogEntries() or 0, nil
    for index = 1, math.min(count, 100) do
        local info = C_QuestLog.GetInfo(index)
        if info and info.isHeader then header = info.title end
        local id = info and not info.isHeader and info.questID
        if type(id) == "number" then
            local data = WalkMapLiveDB and WalkMapLiveDB.Objective(id)
                or WalkMapObjectives and WalkMapObjectives[id]
            local relevant = WalkMapMaps.QuestHere(mapID, header, onMap[id], data)
            local ready = C_QuestLog.IsComplete and C_QuestLog.IsComplete(id)
            local detail, color
            if ready then detail, color = "Done", {0.5, 0.95, 0.5}
            elseif type(info.level) == "number" and info.level > 0 then
                detail, color = tostring(info.level), questLevelColor(info.level, info.questID)
            end
            local entry = {id, info.title or ("Quest " .. id), detail, color}
            if relevant then here[#here + 1] = entry else other[#other + 1] = entry end
        end
    end
    return here, other
end

function extras.SetQuestFocus(questID)
    if type(questID) == "number" then
        settings.questSolo, settings.questFocusID = true, questID
        -- WalkMap no longer sets the game's super-tracked quest: doing it from
        -- addon code ran the game's tracker handlers in tainted code, and
        -- Forever later blocked SetPreferredGamepadInteractTarget when you
        -- interacted with quest objectives (kills, quest objects). Since 4.79
        -- WalkMap's focus is also independent of the game's own quest log.
    else
        settings.questSolo, settings.questFocusID = false, nil
    end
    refreshLabels()
    extras.Invalidate()
    if WalkMapNativeController then WalkMapNativeController.RequestRefresh() end
    if changed then changed() end
end

-- Icons and right-hand details for dropdown rows.
local placeGroupIcons = {
    profession = "Interface\\Icons\\INV_Misc_Book_09",
    other = "Interface\\Icons\\INV_Misc_Coin_01",
}
local function placeIcon(key)
    if key == "trainer" then return icons.trainer end
    if key == "class" then return icons.class end
    local token = type(key) == "string" and key:match("^class:(.+)$")
    if token then return classIcon(token) end
    if professionSpells[key] then return professionIcon(key) end
    return icons[key]
end
local function placeGroupIcon(group)
    if group[1] == "class" then
        local token
        if UnitClass then token = select(2, UnitClass("player")) end
        return classIcon(token)
    end
    return placeGroupIcons[group[1]]
end
local GREEN_DETAIL = {0.5, 0.95, 0.5}
local function placeGroupDetail(group)
    local count, all = 0, false
    for _, option in ipairs(group[3]) do
        if settings.placeFilters[option[1]] then
            count = count + 1
            if option[1] == "trainer" or option[1] == "class" then all = true end
        end
    end
    if all then return "All" end
    if count > 0 then return count .. " on" end
    return ""
end
local function questGroupDetail(group)
    local current = group[1] == "profiles" and settings.profile or settings[group[1]]
    for _, option in ipairs(group[3]) do
        if option[1] == current then return option[2] end
    end
    return ""
end
local function refreshPlaceGroupRows()
    if not menu or not menu:IsShown() then return end
    for _, row in ipairs(menu.rows) do
        if row:IsShown() and row.walkmapPlaceGroup and row.walkmapDecorOpts then
            row.walkmapDecorOpts.detail = placeGroupDetail(row.walkmapPlaceGroup)
            applyRowDecor(row)
        end
    end
end

local function togglePlace(value)
    if value == "__done" then setControllerPanelVisible(menu, false) return end
    if value == "__clear" then
        for key in pairs(settings.placeFilters) do settings.placeFilters[key] = nil end
    else
        local enable = not settings.placeFilters[value]
        settings.placeFilters[value] = enable or nil
        if enable and value == "trainer" then
            for _, profession in ipairs(professions) do
                settings.placeFilters[profession[1]] = nil
            end
        elseif enable and value == "class" then
            for _, option in ipairs(classOptions) do
                settings.placeFilters[option[1]] = nil
            end
            settings.placeFilters.class = true
        elseif enable and value:sub(1, 6) == "class:" then
            settings.placeFilters.class = nil
        elseif enable then
            for _, profession in ipairs(professions) do
                if value == profession[1] then
                    settings.placeFilters.trainer = nil
                    break
                end
            end
        end
    end
    if submenu:IsShown() then
        for _, row in ipairs(submenu.rows) do
            if row:IsShown() and row.option then
                local key = row.option[1]
                row.label:SetText(row.option[2])
                showCheckbox(row, true, not not settings.placeFilters[key])
            end
        end
    end
    refreshPlaceGroupRows()
    refreshLabels()
    extras.Invalidate()
    if changed then changed() end
end

local function createMenuRow(panel, i)
    local row = CreateFrame("CheckButton", nil, panel)
    row:SetHeight(21)
    row:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4 - (i - 1) * 21)
    row:SetPoint("RIGHT", panel, "RIGHT", -4, 0)
    row:EnableMouse(true)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetPoint("LEFT", 4, 0)
    row.label:SetJustifyH("LEFT")
    setRowEnter(row, function(self) self.label:SetTextColor(HOVER_TEXT[1], HOVER_TEXT[2], HOVER_TEXT[3]) end)
    row:SetScript("OnLeave", menuRowLeave)
    styleRow(row)
    rowDecor(row)
    return row
end

local function showSubmenu(group, parentRow)
    setControllerPanelVisible(submenu, false)
    submenu.parentRow = parentRow
    setRowOpen(parentRow, true)
    submenu:ClearAllPoints()
    submenu:SetPoint("TOPLEFT", parentRow, "TOPRIGHT", 2, 0)
    submenu:SetSize((group[1] == "maps" or group[1] == "questfocus") and 275 or group[1] == "profiles" and 216
        or (group[1] == "profession" or group[1] == "class" or group[1] == "other") and 212
        or 190, #group[3] * 21 + 8)
    for i, option in ipairs(group[3]) do
        local row = submenu.rows[i]
        if not row then
            row = createMenuRow(submenu, i)
            submenu.rows[i] = row
        end
        resetRowState(row)
        local key = option[1]
        local decor = {}
        row.option = option
        row.label:SetText(option[2])
        if group[1] == "maps" then
            local here = key == WalkMapMaps.CurrentZone()
            row.label:SetText(here and ("|cff80ff80" .. option[2] .. "|r") or option[2])
            local levels, levelColor = zoneLevelDetail(option[2])
            decor.detail, decor.detailColor = levels, levelColor
            if here then
                decor.detail = "You are here" .. (levels and ("  " .. levels) or "")
                decor.detailColor = GREEN_DETAIL
            end
            showCheckbox(row, true, key == (WalkMapMaps.Selected() or WalkMapMaps.CurrentZone()))
            row:SetScript("OnClick", function() extras.CloseMenus();WalkMapMaps.Choose(key) end)
        elseif group[1] == "questfocus" then
            showCheckbox(row, true, extras.QuestFocus() == key)
            decor.detail, decor.detailColor = option[3], option[4]
            row:SetScript("OnClick", function() extras.CloseMenus();extras.SetQuestFocus(key) end)
        elseif group[1] == "profiles" then
            showCheckbox(row, key ~= "save", key == settings.profile)
            decor.separator = key == "save"
            row:SetScript("OnClick", function() chooseProfile(key) end)
        elseif group[1] == "areas" or group[1] == "level" then
            showCheckbox(row, true, key == settings[group[1]])
            row:SetScript("OnClick", function() setOption(group[1], key) end)
        else
            local icon, coords = placeIcon(key)
            decor.icon, decor.iconCoords = icon, coords
            -- "All ..." heads its list; set it apart from the single entries.
            if i == 2 and (group[3][1][1] == "trainer" or group[3][1][1] == "class") then
                decor.separator = true
            end
            showCheckbox(row, true, not not settings.placeFilters[key])
            row:SetScript("OnClick", function() togglePlace(key) end)
        end
        decorateRow(row, decor)
        row:Show()
    end
    for i = #group[3] + 1, #submenu.rows do submenu.rows[i]:Hide() end
    setControllerPanelVisible(submenu, true)
end

local buttonsMenu
local openMenu
-- A menu of actions under a button (the friends button's invite list):
-- options = {{key, label, detail, colour, run = function, separator = bool}}.
function extras.OpenActions(button, options)
    if openMenu and #options > 0 then openMenu(button, options, "actions") end
end
function extras.ActionsOpen(button) return menu and menu:IsShown() and menu.from == button end
openMenu = function(button, options, field)
    if menu:IsShown() and menu.from == button then setControllerPanelVisible(menu, false) return end
    setControllerPanelVisible(menu, false)
    menu.from = button
    menu.mode = field
    setControllerPanelVisible(submenu, false)
    menu:ClearAllPoints()
    if field == "view" or field == "questfocus" or field == "hidebuttons" then
        menu:SetPoint("BOTTOMLEFT", button, "TOPLEFT", 0, 2)
    elseif field == "actions" then
        -- From a button at the toolbar's right end: open towards the left.
        menu:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", 0, -2)
    else
        menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
    end
    menu:SetSize(field == "maps" and 245 or field == "questfocus" and 270
        or field == "places" and 205 or field == "actions" and 250 or 178, #options * 21 + 8)
    for i, option in ipairs(options) do
        local row = menu.rows[i]
        if not row then
            row = createMenuRow(menu, i)
            menu.rows[i] = row
        end
        resetRowState(row)
        row.option = option
        row.walkmapOpensSubmenu = false
        row.walkmapPlaceGroup = nil
        local decor = {}
        local value = option[1]
        local questGroup = field == "quests" and
            questGroups[value:match("^__group:(.+)$")]
        local floorIndex = field == "maps" and tonumber(tostring(value):match("^__floor:(%d+)$"))
        if floorIndex then
            -- A floor of the dungeon you are in.
            local chosen = false
            for _, floor in ipairs(WalkMapDungeons.Floors()) do
                if floor[1] == floorIndex then chosen = floor[3] end
            end
            row.label:SetText(option[2])
            showCheckbox(row, true, chosen)
            setRowEnter(row, function(self)
                self.label:SetTextColor(HOVER_TEXT[1], HOVER_TEXT[2], HOVER_TEXT[3])
                setControllerPanelVisible(submenu, false)
            end)
            row:SetScript("OnClick", function()
                extras.CloseMenus()
                WalkMapMaps.Choose(nil)
                WalkMapDungeons.SetFloor(floorIndex)
            end)
        elseif field == "maps" then
            local group = mapGroups[value]
            row.walkmapOpensSubmenu = group ~= nil
            local info = group and mapGroupInfo[value]
            row.label:SetText(info and info.here and ("|cffb8f0b8" .. info.label .. "|r")
                or info and info.label or option[2])
            decor.arrow = group ~= nil
            decor.detail = info and info.detail
            decor.separator = i == 2
            showCheckbox(row, not group, not group and not WalkMapMaps.Selected())
            setRowEnter(row, function(self)
                self.label:SetTextColor(HOVER_TEXT[1], HOVER_TEXT[2], HOVER_TEXT[3])
                if group and not (WalkMapNativeController and WalkMapNativeController.IsSelecting(self)) then
                    showSubmenu(group, self)
                elseif not group then
                    setControllerPanelVisible(submenu, false)
                end
            end)
            row:SetScript("OnClick", function(self)
                if group then showSubmenu(group, self)
                else extras.CloseMenus();WalkMapMaps.Choose(nil) end
            end)
        elseif questGroup then
            row.walkmapOpensSubmenu = true
            row.label:SetText(option[2])
            decor.arrow = true
            decor.detail = questGroupDetail(questGroup)
            showCheckbox(row, false, false)
            setRowEnter(row, function(self)
                self.label:SetTextColor(HOVER_TEXT[1], HOVER_TEXT[2], HOVER_TEXT[3])
                if not (WalkMapNativeController and WalkMapNativeController.IsSelecting(self)) then
                    showSubmenu(questGroup, self)
                end
            end)
            row:SetScript("OnClick", function(self)
                showSubmenu(questGroup, self)
            end)
        elseif field == "view" and (value == "__guide" or value == "__db") then
            row.label:SetText(option[2])
            showCheckbox(row, false, false)
            setRowEnter(row, function(self)
                self.label:SetTextColor(HOVER_TEXT[1], HOVER_TEXT[2], HOVER_TEXT[3])
                setControllerPanelVisible(submenu, false)
            end)
            row:SetScript("OnClick", function()
                extras.CloseMenus()
                if value == "__guide" then
                    extras.Guide()
                else
                    print("|cff80ff80WalkMap:|r " .. (WalkMapLiveDB
                        and WalkMapLiveDB.Status() or "QuestieDB unavailable"))
                end
            end)
        elseif field == "view" or field == "quests" then
            row.label:SetText(option[2])
            showCheckbox(row, true, settings[value])
            setRowEnter(row, function(self)
                self.label:SetTextColor(HOVER_TEXT[1], HOVER_TEXT[2], HOVER_TEXT[3])
                setControllerPanelVisible(submenu, false)
            end)
            row:SetScript("OnClick", function() toggleView(value) end)
        elseif field == "places" then
            local group
            for _, candidate in ipairs(placeGroups) do
                if value == "__group:" .. candidate[1] then group = candidate break end
            end
            if group then
                row.walkmapOpensSubmenu = true
                row.walkmapPlaceGroup = group
                row.label:SetText(group[2])
                local icon, coords = placeGroupIcon(group)
                decor.icon, decor.iconCoords = icon, coords
                decor.arrow = true
                decor.detail, decor.detailColor = placeGroupDetail(group), GREEN_DETAIL
                showCheckbox(row, false, false)
                setRowEnter(row, function(self)
                    self.label:SetTextColor(HOVER_TEXT[1], HOVER_TEXT[2], HOVER_TEXT[3])
                    if not (WalkMapNativeController and WalkMapNativeController.IsSelecting(self)) then
                        showSubmenu(group, self)
                    end
                end)
                row:SetScript("OnClick", function(self) showSubmenu(group, self) end)
            else
                row.label:SetText(value == "__clear" and ("|cffd8b8a8" .. option[2] .. "|r") or option[2])
                decor.separator = value == "__clear"
                showCheckbox(row, false, false)
                setRowEnter(row, function(self)
                    self.label:SetTextColor(HOVER_TEXT[1], HOVER_TEXT[2], HOVER_TEXT[3])
                    setControllerPanelVisible(submenu, false)
                end)
                row:SetScript("OnClick", function() togglePlace(value) end)
            end
        elseif field == "hidebuttons" then
            -- Checked = the button is shown. "Show all" / "Hide all" at the end.
            local provider = buttonsMenu
            local bulk = value == "__showall" or value == "__hideall"
            row.label:SetText(bulk and ("|cffd8b8a8" .. option[2] .. "|r") or option[2])
            decor.separator = value == "__showall"
            showCheckbox(row, not bulk, not bulk and not provider.IsHidden(value))
            setRowEnter(row, function(self)
                self.label:SetTextColor(HOVER_TEXT[1], HOVER_TEXT[2], HOVER_TEXT[3])
                setControllerPanelVisible(submenu, false)
            end)
            row:SetScript("OnClick", function()
                if bulk then provider.SetAll(value == "__hideall") else provider.Toggle(value) end
                -- Update the ticks in place, so the controller stays on this row.
                for _, other in ipairs(menu.rows) do
                    local key = other:IsShown() and other.option and other.option[1]
                    if key and key ~= "__showall" and key ~= "__hideall" then
                        showCheckbox(other, true, not provider.IsHidden(key))
                    end
                end
            end)
        elseif field == "actions" then
            -- A list of things to do (extras.OpenActions): label, detail on
            -- the right, run() on click. Rows without run() are plain text.
            row.label:SetText(option[2])
            decor.detail, decor.detailColor = option[3], option[4]
            decor.separator = option.separator
            showCheckbox(row, false, false)
            setRowEnter(row, function(self)
                self.label:SetTextColor(HOVER_TEXT[1], HOVER_TEXT[2], HOVER_TEXT[3])
                setControllerPanelVisible(submenu, false)
            end)
            row:SetScript("OnClick", function()
                if not option.run then return end
                extras.CloseMenus()
                option.run()
            end)
        elseif field == "questfocus" then
            local group = value == "__other" and questFocusGroup
            row.walkmapOpensSubmenu = group ~= nil and group ~= false
            row.label:SetText(option[2])
            if group then
                decor.arrow = true
                decor.detail = tostring(#group[3])
                decor.separator = true
                showCheckbox(row, false, false)
            else
                local focus = extras.QuestFocus()
                showCheckbox(row, true, value == "__all" and not focus or value == focus)
                decor.detail, decor.detailColor = option[3], option[4]
                decor.separator = i == 2
            end
            setRowEnter(row, function(self)
                self.label:SetTextColor(HOVER_TEXT[1], HOVER_TEXT[2], HOVER_TEXT[3])
                if group and not (WalkMapNativeController and WalkMapNativeController.IsSelecting(self)) then
                    showSubmenu(group, self)
                elseif not group then
                    setControllerPanelVisible(submenu, false)
                end
            end)
            row:SetScript("OnClick", function(self)
                if group then showSubmenu(group, self) return end
                extras.CloseMenus()
                extras.SetQuestFocus(value ~= "__all" and value or nil)
            end)
        else
            row.label:SetText(option[2])
            showCheckbox(row, true, settings[field] == value)
            setRowEnter(row, function(self) self.label:SetTextColor(HOVER_TEXT[1], HOVER_TEXT[2], HOVER_TEXT[3]) end)
            row:SetScript("OnClick", function() setOption(field, value) end)
        end
        decorateRow(row, decor)
        row:Show()
    end
    for i = #options + 1, #menu.rows do menu.rows[i]:Hide() end
    setControllerPanelVisible(menu, true)
end

-- Keep the footer label right when the focused quest leaves the log.
local questFocusWatcher = CreateFrame("Frame")
questFocusWatcher:RegisterEvent("QUEST_LOG_UPDATE")
pcall(questFocusWatcher.RegisterEvent, questFocusWatcher, "QUEST_REMOVED")
questFocusWatcher:SetScript("OnEvent", function(_, event)
    -- WalkMap's focus is its own: focus changes in the game's quest log or
    -- tracker do not change it (4.79). It only ends when the quest leaves
    -- the log.
    if settings.questSolo then
        local before = settings.questFocusID
        extras.QuestFocus()
        if settings.questFocusID ~= before then
            refreshLabels()
            extras.Invalidate()
            if changed then changed() end
        else
            refreshLabels()
        end
    end
end)

function extras.OpenQuestMenu(button)
    if not menu then return end
    local here, other = questFocusEntries()
    local options = {{"__all", "All quests"}}
    for _, entry in ipairs(here) do options[#options + 1] = entry end
    questFocusGroup = nil
    if #other > 0 then
        questFocusGroup = {"questfocus", "Other quests", other}
        options[#options + 1] = {"__other", "Other quests"}
    end
    if #options == 1 then options[1] = {"__all", "All quests (log is empty)"} end
    openMenu(button, options, "questfocus")
end

-- The footer's Buttons menu: WalkMap.lua supplies the list and does the
-- hiding (Items, IsHidden, Toggle, SetAll).
function extras.SetButtonsMenu(provider) buttonsMenu = provider end
function extras.ButtonsProvider() return buttonsMenu end
function extras.OpenButtonsMenu(button)
    if not menu or not buttonsMenu then return end
    local options = buttonsMenu.Items()
    options[#options + 1] = {"__showall", "Show all"}
    options[#options + 1] = {"__hideall", "Hide all"}
    openMenu(button, options, "hidebuttons")
end

function extras.OpenMapMenu(button)
    if not menu or not WalkMapMaps then return end
    local options = {{"__current", "|cff80ff80Current zone: " .. WalkMapMaps.Name(WalkMapMaps.CurrentZone()) .. "|r"}}
    -- In a classic dungeon: its floors first (WalkMap_Dungeons.lua).
    for _, floor in ipairs(WalkMapDungeons and WalkMapDungeons.Floors() or {}) do
        options[#options + 1] = {"__floor:" .. floor[1], floor[2]}
    end
    mapGroups, mapGroupInfo = {}, {}
    local here = WalkMapMaps.CurrentZone()
    for i, group in ipairs(WalkMapMaps.MenuGroups()) do
        local key = "__maps:" .. i
        mapGroups[key] = {"maps", group.name, group.zones}
        local contains = false
        for _, zone in ipairs(group.zones) do
            if zone[1] == here then contains = true break end
        end
        -- Show "Eastern Kingdoms" with "A - L" beside it rather than "(1/2)".
        mapGroupInfo[key] = {label = group.region or group.name,
            detail = group.range or (#group.zones .. " maps"), here = contains}
        options[#options + 1] = {key, group.name}
    end
    openMenu(button, options, "maps")
end

-- "Use recommended settings" on the welcome page: the authors' own setup
-- (Anexseus' settings, debug report of 2026-11-16). Only settings you can
-- choose: quests, givers and markers you hid yourself, places, positions,
-- zoom levels and the window look are left alone. Quest areas, the halo and
-- auto-sell are also asked separately on the welcome page and not set here.
local RECOMMENDED = {
    -- Quests on the map
    {"objectiveIcons", true}, {"focusObjectiveIcons", false}, {"givers", true},
    {"questLabels", false}, {"nearestObjective", false}, {"level", 0},
    -- Map
    {"clearView", false}, {"follow", true}, {"fadeWhileMoving", true}, {"fadeAlpha", 0.35},
    {"fadeKeepArrow", true}, {"turnInWaypoint", false}, {"rightClickUp", true}, {"focusWaypoint", true},
    -- Minimap
    {"miniMap", true}, {"miniTerrain", "game"}, {"nativeIcons", true},
    {"miniIconScale", 1}, {"miniIconGap", 0}, {"miniIconRange", 1},
    {"nativeIconScale", 1}, {"nativeIconGap", 0}, {"nativeIconRange", 1},
    -- Quest tracker
    {"zoneTracker", true}, {"trackerScope", "all"}, {"hideGameTracker", true},
    {"announce", "done"},
    -- Controller & help (Pad focus and Button hints follow "How you play")
    {"nativeController", true}, {"useGameMapKeys", true}, {"wheelOpensQuestLog", false},
    -- Bags & vendors
    {"bagSortEnabled", true}, {"vendorMessages", true},
}

-- "How you play" (welcome page): "mouse", "controller" or "both". Until it
-- is chosen, a guess from the game's own gamepad setting.
local PLAY_STYLES = {mouse = "Mouse and keyboard", controller = "Controller", both = "Both"}
local PLAY_ORDER = {"mouse", "controller", "both"}
function extras.PlayStyle()
    if PLAY_STYLES[settings.playStyle] then return settings.playStyle end
    -- Not chosen yet: follow the game's interface (its gamepad UI), else
    -- its gamepad setting.
    if WalkMapCombat and WalkMapCombat.GamepadUI and WalkMapCombat.GamepadUI() then return "both" end
    local gamepad = GetCVar and GetCVar("GamePadEnable")
    return (gamepad == "1" or gamepad == 1) and "both" or "mouse"
end

-- What "How you play" decides. Mouse and keyboard: no Pad focus, no button
-- hints, the close X stays. Controller: Pad focus and hints, and the close X
-- is hidden (B, Escape or the map key close the map). Both: Pad focus and
-- hints, the close X stays for the mouse.
local function styleValues(style)
    local pad = style ~= "mouse"
    return {{"controllerMode", pad}, {"controllerHints", pad}}, style == "controller"
end

local function recommendedActive()
    for _, entry in ipairs(RECOMMENDED) do
        if settings[entry[1]] ~= entry[2] then return false end
    end
    local values, hideClose = styleValues(extras.PlayStyle())
    for _, entry in ipairs(values) do
        if settings[entry[1]] ~= entry[2] then return false end
    end
    if buttonsMenu and buttonsMenu.IsHidden("close") ~= hideClose then return false end
    return true
end

-- Pad focus, button hints and the close X for this play style. The close
-- button only changes out of combat.
local function applyPlayStyle(style)
    local values, hideClose = styleValues(style)
    for _, entry in ipairs(values) do settings[entry[1]] = entry[2] end
    if buttonsMenu and buttonsMenu.IsHidden("close") ~= hideClose then buttonsMenu.Toggle("close") end
end

-- The game switched its interface (WalkMap_StyleReload.lua): gamepad UI on
-- -> Both (hybrid), unless Controller was chosen; mouse and keyboard UI ->
-- Mouse and keyboard. Returns the new style when it changed. Out of combat
-- only (the close X is a protected button).
function extras.FollowInterfaceStyle(gamepad)
    if WalkMapCombat and WalkMapCombat.Locked() then return nil end
    local current = extras.PlayStyle()
    local wanted
    if gamepad then wanted = current == "mouse" and "both" or current
    else wanted = "mouse" end
    if wanted == settings.playStyle then return nil end
    settings.playStyle = wanted
    applyPlayStyle(wanted)
    setOption("controllerMode", settings.controllerMode)
    if refreshSettingsRows and settingsPanel and settingsPanel:IsShown() then refreshSettingsRows() end
    return wanted
end

local function applyRecommended()
    for _, entry in ipairs(RECOMMENDED) do settings[entry[1]] = entry[2] end
    applyPlayStyle(extras.PlayStyle())
    -- Quest icons and labels belong to the display profile: save as My settings.
    markProfileEdited("objectiveIcons")
    -- One setOption call runs the usual refresh (profile, minimap, menus,
    -- map redraw); every other value above is read live.
    setOption("miniMap", true)
    if WalkMapCombat and WalkMapCombat.SettingChanged then WalkMapCombat.SettingChanged() end
    print("|cff80ff80WalkMap:|r recommended settings applied. Change anything later under Settings.")
end

-- Index of the hidden welcome page; set where settingsPages is defined
-- (declared here because ShowWelcome below uses it).
local WELCOME_PAGE, NEWS_PAGE
local NEWS_VERSION = "1.14.11"
-- Earlier What's new pages that already showed friends, guild and sharing:
-- players who saw one of them do not get this one.
local NEWS_ALREADY_SEEN = {["1.14.8"] = true, ["1.14.10"] = true}

-- Welcome page: opens the map (if needed) with settings on that page.
-- Out of combat only.
local function showHiddenPage(which)
    if not settingsPanel or (WalkMapCombat and WalkMapCombat.Locked()) then return end
    if not owner:IsShown() and WalkMap_Toggle then WalkMap_Toggle() end
    if not owner:IsShown() then return end
    local function open()
        if WalkMapCombat and WalkMapCombat.Locked() then return end
        if settingsPanel:IsShown() then setControllerPanelVisible(settingsPanel, false) end
        local click = viewButton:GetScript("OnClick")
        if click then click(viewButton) end
        local index = which == "news" and NEWS_PAGE or WELCOME_PAGE
        if not index then return end
        settingsPanel.categoryIndex = index
        refreshSettingsRows()
        -- Only counts as seen once it is actually on screen. New players
        -- get the welcome page and skip this release's news.
        if type(WalkMapSettings) == "table" then
            if which ~= "news" then WalkMapSettings.welcomeSeen = true end
            WalkMapSettings.newsSeen = NEWS_VERSION
        end
        -- Controller: start on the first choice, not the category list.
        if WalkMapNativeController and WalkMapNativeController.FocusButton and settingsPanel.options[1] then
            pcall(WalkMapNativeController.FocusButton, settingsPanel, settingsPanel.options[1])
        end
    end
    -- Give the map a moment to finish opening (and the controller to
    -- register it) before the settings window goes on top.
    if C_Timer and C_Timer.After then C_Timer.After(0.3, open) else open() end
end

function extras.ShowWelcome() showHiddenPage("welcome") end
function extras.ShowNews() showHiddenPage("news") end

-- After an update: show What's new the first time the player opens the map
-- (never by itself, never in combat, once per NEWS_VERSION).
function extras.MapOpened()
    local saved = WalkMapSettings
    if type(saved) ~= "table" or not saved.welcomeSeen or saved.newsSeen == NEWS_VERSION
        or NEWS_ALREADY_SEEN[saved.newsSeen] then return end
    if WalkMapCombat and WalkMapCombat.Locked() then return end
    if settingsPanel and settingsPanel:IsShown() then return end
    extras.ShowNews()
end

-- First login with WalkMap (account-wide, once): show the welcome page.
do
    local welcome = CreateFrame("Frame")
    welcome:RegisterEvent("PLAYER_ENTERING_WORLD")
    welcome:SetScript("OnEvent", function(self)
        if type(WalkMapSettings) ~= "table" then WalkMapSettings = {} end
        -- welcomeSeen is set by ShowWelcome once the page is on screen
        -- (4.90 marked it before opening, so a failed open hid it for good).
        WalkMapSettings.welcomeShown = nil
        if WalkMapSettings.welcomeSeen then self:UnregisterAllEvents() return end
        if not (C_Timer and C_Timer.After) then return end
        C_Timer.After(4, function()
            if WalkMapSettings.welcomeSeen or (WalkMapCombat and WalkMapCombat.Locked()) then return end
            self:UnregisterAllEvents()
            extras.ShowWelcome()
        end)
    end)
end

function extras.Resize()
    if not buttons then return end
    -- The quest log button sits at the end of the toolbar, inside the window.
    local logButton = WalkMapQuestLog and WalkMapQuestLog.Tab and WalkMapQuestLog.Tab()
    local logWidth = logButton and 30 or 0
    if logButton then
        logButton:ClearAllPoints()
        logButton:SetPoint("TOPRIGHT", owner, "TOPRIGHT", -8, -WalkMapUI.MapLayout.toolbarTop)
        logButton:SetSize(logWidth - 3, WalkMapUI.MapLayout.toolbarHeight)
    end
    -- Friends and guild button, left of the quest log button.
    local social = WalkMapFriends and WalkMapFriends.Tab and WalkMapFriends.Tab()
    if social then
        local wanted = WalkMapFriends.TabWanted()
        social:SetShown(wanted)
        if wanted then
            social:ClearAllPoints()
            social:SetPoint("TOPRIGHT", owner, "TOPRIGHT", -8 - logWidth, -WalkMapUI.MapLayout.toolbarTop)
            social:SetSize(27, WalkMapUI.MapLayout.toolbarHeight)
            logWidth = logWidth + 30
        end
    end
    local slot = (owner:GetWidth() - 16 - logWidth) / #buttons
    for i, button in ipairs(buttons) do
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", owner, "TOPLEFT", 8 + (i - 1) * slot,
            -WalkMapUI.MapLayout.toolbarTop)
        button:SetSize(slot - 3, WalkMapUI.MapLayout.toolbarHeight)
        button.label:SetWidth(slot - 8)
    end
    refreshLabels()
end

function extras.StyleButton(button)
    -- One button image in three pieces: caps at native width, middle stretched.
    -- Classic uses the game's panel button; other looks use WalkMap's skin.
    local file, _, capWidth, height, tintPressed, edges = WalkMapUI.ButtonArt()
    local coords = {{0, edges[1]}, {edges[1], edges[2]}, {edges[2], edges[3]}}
    local pieces = {}
    for index, limits in ipairs(coords) do
        local piece = button:CreateTexture(nil, "BACKGROUND")
        piece:SetTexture(file)
        piece:SetTexCoord(limits[1], limits[2], 0, height)
        if index == 1 then
            piece:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
            piece:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
            piece:SetWidth(capWidth)
        elseif index == 2 then
            piece:SetPoint("TOPLEFT", pieces[1], "TOPRIGHT", 0, 0)
            piece:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -capWidth, 0)
        else
            piece:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
            piece:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
            piece:SetWidth(capWidth)
        end
        pieces[index] = piece
    end
    local glow = WalkMapUI.ButtonGlow(button)
    if not glow then
        local hover = button:CreateTexture(nil, "HIGHLIGHT")
        -- Cover the whole red face of the button, just inside its border.
        hover:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
        hover:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
        hover:SetColorTexture(0.9, 0.66, 0.25, 0.18)
    end
    local function setPressed(down)
        if tintPressed then
            local shade = down and 0.7 or 1
            for _, piece in ipairs(pieces) do piece:SetVertexColor(shade, shade, shade) end
        else
            local path = "Interface\\Buttons\\UI-Panel-Button-" .. (down and "Down" or "Up")
            for _, piece in ipairs(pieces) do piece:SetTexture(path) end
        end
    end
    button:SetScript("OnMouseDown", function(_, mouseButton)
        if mouseButton == "LeftButton" then setPressed(true) end
    end)
    button:SetScript("OnMouseUp", function() setPressed(false) end)
    button:SetScript("OnHide", function() setPressed(false) end)
    button.walkmapButtonParts = pieces
end

styleMenu = function(panel)
    WalkMapUI.Menu(panel)
end

local function cursorIn(frame, x, y)
    if not frame or not frame:IsShown() then return false end
    local left, right = frame:GetLeft(), frame:GetRight()
    local top, bottom = frame:GetTop(), frame:GetBottom()
    return left and right and top and bottom
        and x >= left and x <= right and y >= bottom and y <= top
end

styleRow = function(row)
    WalkMapUI.Row(row)
end

-- Rows: {field, value, label, description, when = function() ... end}.
-- A row with "when" is only listed while it returns true. Pages with more
-- rows than fit scroll (mouse wheel; with the controller, Up/Down at the
-- first or last row).
local function miniMarkersFor(kind)
    return function()
        if kind == "mini" then return settings.miniMap == true end
        return not settings.miniMap and settings.nativeIcons == true
    end
end
local settingsPages = {
    {"Quests on the map", "Quest areas, QuestieDB icons and quest givers.", {
        {"__welcomeAreas", nil, "Quest areas", "The game's blue quest areas and markers: all quests, only WalkMap's focused quest, or off."},
        {"__welcomeIcons", nil, "Quest icons", "QuestieDB objective and drop locations: all quests, only the focused quest, or off."},
        {"givers", nil, "Quest givers", "Show suitable quests for your class and level."},
        {"questLabels", nil, "Quest names on map", "Write quest titles beside the game markers."},
        {"nearestObjective", nil, "Nearest focused location", "Show the direction to the nearest known objective location."},
        {"__resetHidden", nil, "Restore hidden markers", "Show quest givers, quest locations and places you hid manually again."},
    }},
    {"Giver level", "Use your level automatically or choose a level range.", {}, giverLevel = true},
    {"Map", "The large map: what it shows and how it behaves.", {
        {"clearView", nil, "Clear view", "Make explored terrain and the map frame transparent."},
        {"follow", nil, "Follow player", "Keep the zoomed map centered on your character."},
        {"playerHalo", nil, "Player marker halo", "Show a pulsing gold ring around your arrow on the large map."},
        {"__fade", nil, "Fade while moving", "Make the map transparent while you move, unless it has focus. Click to choose how visible it stays."},
        {"fadeKeepArrow", nil, "Keep player arrow visible", "Your arrow stays fully visible while the map fades.",
            when = function() return settings.fadeWhileMoving == true end},
        {"closeInCombat", nil, "Close map when combat starts", "Closes an open map as a fight begins. You can still open it during the fight; it is not closed again."},
        {"turnInWaypoint", nil, "Waypoint to turn-ins", "When a quest is ready to turn in, set the waypoint where the game says to hand it in."},
        {"rightClickUp", nil, "Right-click goes a map level up", "Right-click a zone map to open the continent instead of setting a waypoint. Waypoints are then set with middle-click or Alt-click."},
        {"unexplored", nil, "Unexplored areas", "Show the parts of a zone you have not explored yet, dimmed in red."},
        {"friendsOnMap", nil, "Friends on the map", "Online friends (and Battle.net friends in this game) by zone. The button left of the quest log button shows who is in the zone you are looking at; on the continent and world maps each zone gets a badge."},
        {"guildOnMap", nil, "Guild on the map", "Online guild members by zone, the same way."},
        {"shareLocation", nil, "Share where you are", "Off: nobody sees where you stand. On: your guild and your friends who use WalkMap or OpenMap see a dot where you are, and you see theirs. Never shared from dungeons, raids or battlegrounds."},
    }},
    {"Minimap", "WalkMap's minimap and the markers it adds.", {
        {"__miniType", nil, "WalkMap minimap", "Off, zone artwork (a larger, independently zoomed zone preview) or game terrain (the live game minimap with WalkMap's markers)."},
        {"nativeIcons", nil, "Game minimap icons", "Add WalkMap's markers to the game's own minimap.",
            when = function() return not settings.miniMap end},
        {"friendsOnMinimap", nil, "Friends and guild", "Friends and guild members who share where they are also show as a dot in their class colour on the minimap, when they are near. Needs Share where you are (Map settings).",
            when = function() return settings.shareLocation == true end},
        {"focusWaypoint", nil, "Focus waypoint", "While a quest is focused, a purple diamond on the minimap shows where to go: its nearest unfinished objective, or where to turn it in. It stays on the edge when out of range and is gone when you stop focusing.",
            when = function() return settings.miniMap or settings.nativeIcons end},
        {"__miniIconScale", nil, "Marker size", "Compact, normal or large icons on WalkMap's minimap.", when = miniMarkersFor("mini")},
        {"__miniIconGap", nil, "Marker spacing", "Hide icons that overlap on WalkMap's minimap: off, medium or wide.", when = miniMarkersFor("mini")},
        {"__miniIconRange", nil, "Marker distance", "Show markers within all, 75% or 50% of WalkMap's minimap.", when = miniMarkersFor("mini")},
        {"__nativeIconScale", nil, "Marker size", "Compact, normal or large icons on the game's minimap.", when = miniMarkersFor("native")},
        {"__nativeIconGap", nil, "Marker spacing", "Hide icons that overlap on the game's minimap: off, medium or wide.", when = miniMarkersFor("native")},
        {"__nativeIconRange", nil, "Marker distance", "Show markers within all, 75% or 50% of the game's minimap.", when = miniMarkersFor("native")},
    }},
    {"Look", "How WalkMap's windows and buttons look. The quest icons and the map itself stay the same.", {
        {"__welcomeLook", nil, "Window look", "Classic (the game's own art), Stone and gold, Wood and parchment, or Leather and bronze. Apply now uses it."},
        {"trackerFrame", nil, "Frame around the quest tracker", "With Stone, Wood or Leather: a metal frame and a title band around the quest tracker. Off: only its background."},
        {"__applyLook", nil, "Use the chosen look", "Reload the interface to use the chosen look."},
    }},
    {"Quest tracker", "WalkMap's on-screen list of quests, and messages to your group.", {
        {"__trackerScope", nil, "Quest tracker", "Off, this zone only, this zone plus nearby quests from neighbouring zones, or all zones. Alt-drag its header to move it, or use the game's Edit Mode to move it and set its size."},
        {"trackerObjectives", nil, "Show objectives", "List each quest's objectives. Off: quest titles only."},
        {"groupProgress", nil, "Group progress", "In a party, under each quest you share, how far the others are with it (\"Anna  3/8, 0/1\"). Needs WalkMap for them too; your progress is shared with your party the same way. Off: nothing sent or shown."},
        {"showQuestXP", nil, "Quest XP", "Show the experience each quest gives at your level, here, in the quest log list and on quest givers."},
        {"hideGameTracker", nil, "Hide game quest tracker", "Hide Forever's own tracker while this one is on, and stop the game adding new quests to it. Turn off if error popups appear."},
        {"__trackerBgAlpha", nil, "Background", "Cycle off (text only), light, medium, dark and solid."},
        {"__trackerFont", nil, "Text size", "Cycle small, normal, large and extra large."},
        {"__trackerMax", nil, "Quests shown", "Most quests listed at once: 5, 8, 10, 12, 15 or 20. Fewer when they do not fit: set the height in the game's Edit Mode."},
        {"__trackerWidth", nil, "Width", "Cycle narrow, normal and wide, or drag its corner in the game's Edit Mode."},
        {"__announce", nil, "Tell group about quest progress", "Party/raid chat: off, finished objectives, or every step. Also says when a quest is ready."},
    }},
    {"Profiles", "Quest display setups for this character, and settings shared by all your characters.", {
        {"profile", "questing", "Questing", "All quest areas, givers and objective icons."},
        {"profile", "exploration", "Exploration", "Focused area and a clearer map."},
        {"profile", "custom", "My settings", "Restore your saved personal quest settings."},
        {"profile", "save", "Save current as My settings", "Keep your current quest display choices."},
        {"__accountSave", nil, "Save as account settings", "Store all of this character's WalkMap settings for your account, so your other characters can load them."},
        {"__accountLoad", nil, "Load account settings", "Use the saved account settings on this character, then reload the interface."},
        {"__accountNew", nil, "New characters use account settings", "A character's first login with WalkMap starts from the saved account settings."},
    }},
    {"Controller & help", "How you play, navigation, the map keys and help.", {
        {"__playStyle", nil, "How you play", "Mouse and keyboard, controller, or both. Sets Pad focus, button hints and the map's close X; you can still change those one by one."},
        {"controllerMode", nil, "Pad focus", "Take controller focus on open. The keybind toggles this choice."},
        {"selectKeepsReleased", nil, "Select keeps the map released", "Off: the map takes the controller every time it opens. On: press Select to leave the map and it stays out of your way - when you open it again you keep control of your character. Press Select to take the map back.",
            when = function() return settings.controllerMode == true end},
        {"nativeController", nil, "Native controller navigation", "Experimental: use the game's focus cursor and window switching. Disable for custom navigation."},
        {"__mapKeys", nil, "Map key and wheel open", "What the map and quest log keys and the gamepad wheel's Quest & Maps open: the game's map, WalkMap, or WalkMap with its quest log."},
        {"__dungeonMap", nil, "Game map in dungeons", "Inside a dungeon, the map key and the wheel open the game's map, for a dungeon map addon. Auto: with DungeonJournal or Forever Dungeon Scout. Always: for any other dungeon map addon. Off: always WalkMap. Your WalkMap key still opens WalkMap."},
        {"combatWheel", nil, "WalkMap's wheel in combat", "In a fight, the button for the game's wheel opens WalkMap's copy of its main page: the same entries in the same places, and Quest & Maps opens and closes WalkMap. Point with the right stick and let go, or press A; B closes it. Out of combat the game's own wheel opens as always."},
        {"controllerHints", nil, "Button hints", "A line at the top of the map says what A, B, X and Y do right now. Only while the controller has focus."},
        {"__intro", nil, "Welcome setup", "Show the first-time page with the most important settings again."},
        {"__debug", nil, "Debug report", "Copy current settings and map state to report a bug."},
    }},
    -- Information only: controllers that work well, set up in Steam Input.
    {"Controllers", "Recommended controllers and how to set them up. WoW Forever must run through Steam (add it as a non-Steam game) to use Steam Input.", {
        {"__info", nil, "Any controller: keys for the map", "Bind M (the map key) or your WalkMap key to a button. Those also open and close WalkMap during combat, which the gamepad wheel cannot."},
        {"__info", nil, "Steam Controller", "Map its back buttons to keys in Steam Input, for example M for the map and B for bags. Set the left touchpad to a radial menu with the keys you use most."},
        {"__info", nil, "8BitDo Pro 3", "Switch it to D-input mode and use it through Steam: Steam then sees its extra buttons (the back buttons too), so you can map them to keys in Steam Input."},
        {"__info", nil, "Xbox Series controller", "On Windows: in Steam's controller settings, install Xbox Extended Feature Support and restart the PC. Then the Share button can be mapped in Steam Input, for example to M. If it still does not show, update the controller in Microsoft's Xbox Accessories app."},
        {"__info", nil, "Other controllers", "Other controllers are most likely fine too; we have only tested with the ones above."},
    }},
    {"Bags & vendors", "Bag tools by Underbuks, integrated from SortPants.", {
        {"bagSortEnabled", nil, "Bag sorting", "Allow manual sorting through the button, command or shortcut."},
        {"__autoSell", nil, "Auto-sell junk", "Sell gray-quality items when a vendor opens: off, on with a chat message, or on quietly."},
        {"__sortBags", nil, "Sort bags now", "Sort your backpack and bags using the game's sorting function."},
        {"__bagBinding", nil, "Sort shortcut", "Set it under Key Bindings > WalkMap > Sort bags. Click for help."},
        {"__bagStatus", nil, "Bag tools status", "WalkMap auto-sell is off."},
    }},
    -- First-time page; not listed under Categories (see WELCOME_PAGE).
    {"Welcome to WalkMap", "Pick the basics now; everything can be changed later under Settings. Done closes this page. Tips: /walkmap guide", {
        {"__recommended", nil, "Use recommended settings", "The authors' setup for the map, quest log, tracker, controller, minimap and map buttons. The choices below are up to you."},
        {"__welcomeAreas", nil, "Game quest areas", "The game's own blue quest areas and markers: all quests, only the focused quest, or off."},
        {"playerHalo", nil, "Player marker halo", "A pulsing gold ring around your arrow on the large map."},
        {"autoSellJunk", nil, "Auto-sell grey items", "Sell grey-quality items when a vendor opens. Recover them from the vendor's Buyback tab."},
        {"__welcomeLook", nil, "Window look", "Classic, Stone and gold, Wood and parchment or Leather and bronze. Settings > Look > Apply now uses it."},
        {"__welcomeIcons", nil, "QuestieDB quest icons", "Where to kill, loot and use things: all quests, only the focused quest, or off."},
        {"__playStyle", nil, "How you play", "Mouse and keyboard, controller, or both. Sets Pad focus, button hints and the map's close X; recommended settings follow it."},
        {"selectKeepsReleased", nil, "Select keeps the map released", "Off: the map takes the controller every time it opens. On: press Select to leave the map and it stays out of your way - when you open it again you keep control of your character. Press Select to take the map back.",
            when = function() return extras.PlayStyle() ~= "mouse" end},
        {"__trackerScope", nil, "Quest tracker", "WalkMap's own tracker: off, this zone only, this zone plus nearby quests, or all zones."},
        {"friendsOnMap", nil, "See friends on the map", "Online friends by zone. The button left of the quest log button shows who is in the zone you are looking at; on the continent and world maps each zone gets a badge."},
        {"guildOnMap", nil, "See guild on the map", "Online guild members by zone, the same way."},
        {"shareLocation", nil, "Share where you are", "Off: nobody sees where you stand. On: your guild and friends who use WalkMap or OpenMap see a dot where you are, and you see theirs. Never from dungeons, raids or battlegrounds."},
    }, hidden = true},
    -- Shown once after an update, the first time the map is opened (see
    -- NEWS_VERSION). Only for releases with significant changes: then
    -- replace the rows, the version in the title and NEWS_VERSION. Hotfixes
    -- and small additions leave all three alone, so nothing pops up.
    {"What's new in WalkMap 1.14.11", "Changes in this update. Done closes this page; /walkmap news shows it again.", {
        {"friendsOnMap", nil, "See friends on the map", "Online friends by zone. The button left of the quest log button shows who is in the zone you are looking at - click it to invite them to your group; on the continent and world maps each zone gets a badge."},
        {"guildOnMap", nil, "See guild on the map", "Online guild members by zone, the same way."},
        {"shareLocation", nil, "Share where you are", "Off: nobody sees where you stand. On: your guild and friends who use WalkMap or OpenMap see a dot where you are, and you see theirs - on the map and on the minimap. Never from dungeons, raids or battlegrounds."},
        {"groupProgress", nil, "Group progress", "In a party, the quest tracker shows under each quest you share how far the others are with it (they need WalkMap too)."},
        {"__news", nil, "Easier to read", "Settings pages scroll with a bar in the window's look; zones stand apart from quests in the quest log; text stays inside its rows and buttons when the font is drawn larger."},
        {"__reportBugs", nil, "Found a bug? Tell us", "Please write in the comments on WalkMap's CurseForge page. A screenshot or the Debug report (Settings > Controller & help) helps a lot."},
    }, hidden = true},
}
NEWS_PAGE = #settingsPages
WELCOME_PAGE = NEWS_PAGE - 1
-- Settings rows that wait until after combat (see the row click handler).
local COMBAT_WAIT = {
    __miniType = true, miniMap = true, nativeIcons = true, __playStyle = true,
    controllerMode = true, nativeController = true, selectKeepsReleased = true, __trySelect = true,
    __mapKeys = true, useGameMapKeys = true, combatWheel = true, __dungeonMap = true, hideGameTracker = true, __trackerScope = true,
    __applyLook = true, __accountLoad = true, __sortBags = true, __bagBinding = true,
    __recommended = true, __intro = true,
}
local giverRows
for _, page in ipairs(settingsPages) do
    if page.giverLevel then giverRows = page[3] end
end
giverRows[1] = {"level", 0, "Automatic", "Use your character's current level."}
for start = 1, 60, 10 do
    giverRows[#giverRows + 1] =
        {"level", start + 4, start .. "-" .. (start + 9),
            "Show quest givers near this level range."}
end

refreshSettingsRows = function()
    if not settingsPanel then return end
    local page = settingsPages[settingsPanel.categoryIndex]
    if not page then
        -- Never leave the window on a missing page.
        settingsPanel.categoryIndex = 1
        page = settingsPages[1]
    end
    settingsPanel.pageTitle:SetText(page[1])
    settingsPanel.summary:SetText(page[2])
    settingsPanel.rows = {}
    -- Rows listed right now ("when"), and the part of them that fits.
    local items = {}
    for _, option in ipairs(page[3]) do
        if not option.when or option.when() then items[#items + 1] = option end
    end
    if settingsPanel.scrollPage ~= settingsPanel.categoryIndex then
        settingsPanel.scrollPage, settingsPanel.scroll = settingsPanel.categoryIndex, 0
    end
    -- Rows take the height their text needs (some setups draw the font
    -- larger, so descriptions wrap to more lines); as many as fit are shown
    -- from the scroll position, at most one frame per slot.
    local slots = #settingsPanel.options
    settingsPanel.scroll = math.max(0, math.min(settingsPanel.scroll or 0, math.max(0, #items - 1)))
    local shownItems = {}
    for n = 1, math.min(slots, #items - settingsPanel.scroll) do
        shownItems[n] = items[settingsPanel.scroll + n]
    end
    for i in ipairs(settingsPages) do
        local row = settingsPanel.categories[i]
        if row then
            local selected = i == settingsPanel.categoryIndex
            row.label:SetTextColor(selected and 1 or 0.88,
                selected and 0.83 or 0.88, selected and 0.36 or 0.88)
            row.walkmapSelected:SetShown(selected)
            settingsPanel.rows[#settingsPanel.rows + 1] = row
        end
    end
    local y, bottom = -110, -(110 + 8 * 44)
    local fitted = #shownItems
    for i, option in ipairs(shownItems) do
        local row = settingsPanel.options[i]
        row.option = {option[1]}
        local field, value = option[1], option[2]
        local display = option[3]
        local description = option[4]
        if field == "__bagBinding" and WalkMapBags then
            display = display .. ": " .. WalkMapBags.BindingLabel()
        elseif field == "__bagStatus" and WalkMapBags then
            description = WalkMapBags.Status()
        end
        if field == "__miniIconScale" or field == "__nativeIconScale" then
            local setting = field:sub(3)
            local size = settings[setting]
            display = display .. ": " .. (size == 0.8 and "Compact"
                or size == 1.25 and "Large" or "Normal")
        elseif field == "__miniIconGap" or field == "__nativeIconGap" then
            local setting = field:sub(3)
            local gap = settings[setting]
            display = display .. ": " .. (gap == 14 and "Medium"
                or gap == 22 and "Wide" or "Off")
        elseif field == "__miniIconRange" or field == "__nativeIconRange" then
            local range = settings[field:sub(3)]
            display = display .. ": " .. (range == 1 and "All"
                or tostring(range * 100) .. "%")
        elseif field == "__fadeAlpha" then
            display = display .. ": " .. math.floor(extras.FadeAlpha() * 100 + 0.5) .. "% visible"
        elseif field == "__fade" then
            display = display .. ": " .. (settings.fadeWhileMoving
                and (math.floor(extras.FadeAlpha() * 100 + 0.5) .. "% visible") or "Off")
        elseif field == "__miniType" then
            display = display .. ": " .. (not settings.miniMap and "Off"
                or settings.miniTerrain == "game" and "Game terrain" or "Zone artwork")
        elseif field == "__mapKeys" then
            display = display .. ": " .. (not settings.useGameMapKeys and "Game map"
                or settings.wheelOpensQuestLog ~= false and "WalkMap + quest log" or "WalkMap")
        elseif field == "__dungeonMap" then
            local mode = extras.DungeonMapMode()
            display = display .. ": " .. (mode == "off" and "Off" or mode == "always" and "Always"
                or "Auto" .. (extras.DungeonMapAddon() and " (" .. extras.DungeonMapAddon() .. ")" or ""))
        elseif field == "__autoSell" then
            display = display .. ": " .. (not settings.autoSellJunk and "Off"
                or settings.vendorMessages ~= false and "On" or "On, quietly")
        elseif field == "__welcomeIcons" then
            display = display .. ": " .. (not settings.objectiveIcons and "Off"
                or settings.focusObjectiveIcons and "Focused quest" or "All quests")
        elseif field == "__welcomeLook" then
            display = display .. ": " .. WalkMapUI.LookName(settings.look)
        elseif field == "__applyLook" then
            if (settings.look or "classic") == WalkMapUI.Look() then
                description = "In use: " .. WalkMapUI.LookName() .. ". Choose another look above, then apply."
            else
                description = "Reload the interface to use " .. WalkMapUI.LookName(settings.look)
                    .. ". Out of combat only."
            end
        elseif field == "__accountSave" then
            local from, at = extras.AccountSettingsInfo()
            if from then description = "Saved from " .. from .. (at and (" (" .. at .. ")") or "")
                .. ". Click to replace them with this character's settings." end
        elseif field == "__accountLoad" then
            if not extras.HasAccountSettings() then
                description = "Nothing saved yet. Use Save as account settings on the character you want to copy."
            elseif accountLoadArmedAt and GetTime and GetTime() - accountLoadArmedAt < 4 then
                display = "|cffff8040Click again to load and reload|r"
                description = "This replaces this character's WalkMap settings. Out of combat only."
            end
        elseif field == "__accountNew" then
            display = display .. ": " .. (extras.AccountForNew() and "On" or "Off")
        elseif field == "__playStyle" then
            display = display .. ": " .. PLAY_STYLES[extras.PlayStyle()]
        elseif field == "__welcomeAreas" then
            display = display .. ": " .. (settings.areas == "off" and "Off"
                or settings.areas == "focus" and "Focused quest" or "All quests")
        elseif field == "__announce" then
            display = display .. ": " .. (settings.announce == "done" and "Finished objectives"
                or settings.announce == "progress" and "Every step" or "Off")
        elseif field == "__trackerScope" then
            display = display .. ": " .. (settings.zoneTracker == false and "Off"
                or settings.trackerScope == "all" and "All zones"
                or settings.trackerScope == "nearby" and "This zone + nearby" or "This zone")
        elseif field == "__trackerWidth" and extras.TrackerSettings().w then
            display = display .. ": Custom (" .. tostring(extras.TrackerSettings().w) .. ")"
        elseif TRACKER_CHOICES[field:sub(3)] then
            display = display .. ": " .. trackerChoiceLabel(field:sub(3))
        end
        row.label:SetText(display)
        row.description:SetText(description)
        local selectable = field:sub(1, 2) ~= "__" and value ~= "save"
        local selected = value == nil and settings[field] == true
            or settings[field] == value
        if field == "miniTerrain" then
            selected = settings.miniMap and settings.miniTerrain == value
        end
        showCheckbox(row, selectable, selectable and selected)
        row.label:ClearAllPoints()
        row.label:SetPoint("TOPLEFT", row, "TOPLEFT", selectable and 26 or 5, -3)
        row.description:ClearAllPoints()
        row.description:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -2)
        row.description:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        -- Rows that do something once (Use recommended settings, Apply now)
        -- get a real button on the right, styled like the game's other
        -- buttons, so it is clear they can be pressed. The button and the
        -- row do the same thing; controller focus stays on the row.
        local isButton = field == "__recommended" or field == "__applyLook" or field == "__trySelect"
        if isButton and not row.walkmapActionButton then
            local button = CreateFrame("Button", nil, row)
            button:SetSize(92, 24)
            button:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            extras.StyleButton(button)
            button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            button.text:SetPoint("CENTER", button, "CENTER", 0, 0)
            button:SetScript("OnClick", function()
                local click = row:GetScript("OnClick")
                if click then click(row, "LeftButton") end
            end)
            -- Hovering the button lights up its row too.
            button:SetScript("OnEnter", function()
                local enter = row:GetScript("OnEnter")
                if enter then enter(row) end
            end)
            button:SetScript("OnLeave", function()
                local leave = row:GetScript("OnLeave")
                if leave then leave(row) end
            end)
            row.walkmapActionButton = button
        end
        local actionButton = row.walkmapActionButton
        if actionButton then actionButton:SetShown(isButton) end
        if isButton then
            local done
            if field == "__recommended" then done = recommendedActive()
            elseif field == "__trySelect" then done = settings.selectKeepsReleased == true
            else done = (settings.look or "classic") == WalkMapUI.Look() end
            local text = field == "__recommended" and (done and "Applied" or "Apply")
                or field == "__trySelect" and (done and "Turn off" or "Try it")
                or (done and "In use" or "Apply now")
            actionButton.text:SetText(text)
            -- Gold when there is something to apply, grey when it is done.
            if done then actionButton.text:SetTextColor(0.62, 0.62, 0.62)
            else actionButton.text:SetTextColor(1, 0.82, 0) end
            actionButton:SetAlpha(done and 0.7 or 1)
            if field == "__recommended" or field == "__trySelect" then row.label:SetText("|cffffd24a" .. display .. "|r") end
            row.description:SetPoint("RIGHT", row, "RIGHT", -108, 0)
        end
        -- What's new highlights: gold heading.
        if field == "__newsStar" or field == "__reportBugs" or field == "__info" then
            row.label:SetText("|cffffd24a" .. display .. "|r")
        end
        if row.description.SetMaxLines then row.description:SetMaxLines(isButton and 2 or 0) end
        row:SetScript("OnClick", function()
            -- Settings that touch the game's minimap, key bindings, its
            -- quest tracker or protected buttons wait until after combat.
            -- (Only reachable in combat with a free map window.)
            if WalkMapCombat and WalkMapCombat.Locked() and COMBAT_WAIT[field] then
                print("|cff80ff80WalkMap:|r " .. (option and option[3] or "This setting") .. " can be changed after combat.")
                return
            end
            if field == "profile" then
                chooseProfile(value)
            elseif field == "__reset" then
                extras.Command("givers", "reset")
            elseif field == "__resetMarkers" then
                extras.Command("markers", "reset")
            elseif field == "__playStyle" then
                -- Mouse and keyboard -> Controller -> Both -> Mouse and keyboard
                local current, nextStyle = extras.PlayStyle(), nil
                for index, style in ipairs(PLAY_ORDER) do
                    if style == current then nextStyle = PLAY_ORDER[index % #PLAY_ORDER + 1] end
                end
                settings.playStyle = nextStyle
                applyPlayStyle(nextStyle)
                setOption("controllerMode", settings.controllerMode)
                refreshSettingsRows()
            elseif field == "__resetHidden" then
                extras.Command("givers", "reset")
                extras.Command("markers", "reset")
            elseif field == "__fade" then
                -- Off -> 20% -> 35% -> 50% -> 70% visible -> Off
                if not settings.fadeWhileMoving then
                    settings.fadeAlpha = FADE_CHOICES[1]
                    setOption("fadeWhileMoving", true)
                else
                    local nextChoice
                    for n, choice in ipairs(FADE_CHOICES) do
                        if math.abs((settings.fadeAlpha or 0) - choice) < 0.01 then nextChoice = FADE_CHOICES[n + 1] end
                    end
                    if nextChoice then
                        settings.fadeAlpha = nextChoice
                        setOption("fadeWhileMoving", true)
                    else
                        setOption("fadeWhileMoving", false)
                    end
                end
                refreshSettingsRows()
            elseif field == "__miniType" then
                -- Off -> Zone artwork -> Game terrain -> Off
                if not settings.miniMap then
                    settings.miniTerrain = "zone"
                    setOption("miniMap", true)
                elseif settings.miniTerrain ~= "game" then
                    settings.miniTerrain = "game"
                    setOption("miniMap", true)
                else
                    setOption("miniMap", false)
                end
                refreshSettingsRows()
            elseif field == "__mapKeys" then
                -- Game map -> WalkMap -> WalkMap + quest log -> Game map
                if not settings.useGameMapKeys then
                    settings.wheelOpensQuestLog = false
                    setOption("useGameMapKeys", true)
                elseif settings.wheelOpensQuestLog == false then
                    setOption("wheelOpensQuestLog", true)
                else
                    setOption("useGameMapKeys", false)
                end
                refreshSettingsRows()
            elseif field == "__dungeonMap" then
                -- Auto -> Always -> Off -> Auto
                local mode = extras.DungeonMapMode()
                if mode == "auto" then
                    settings.dungeonMapAlways = true
                    setOption("dungeonMapHandoff", true)
                elseif mode == "always" then
                    settings.dungeonMapAlways = false
                    setOption("dungeonMapHandoff", false)
                else
                    settings.dungeonMapAlways = false
                    setOption("dungeonMapHandoff", true)
                end
                if WalkMapCombatWheel and WalkMapCombatWheel.Refresh then WalkMapCombatWheel.Refresh() end
                refreshSettingsRows()
            elseif field == "__autoSell" then
                -- Off -> On -> On, quietly -> Off
                if not settings.autoSellJunk then
                    settings.vendorMessages = true
                    setOption("autoSellJunk", true)
                elseif settings.vendorMessages ~= false then
                    setOption("vendorMessages", false)
                else
                    settings.vendorMessages = true
                    setOption("autoSellJunk", false)
                end
                refreshSettingsRows()
            elseif field == "__db" or field == "__guide" then
                extras.CloseMenus()
                if field == "__guide" then extras.Guide()
                else print("|cff80ff80WalkMap:|r " .. (WalkMapLiveDB
                    and WalkMapLiveDB.Status() or "QuestieDB unavailable")) end
            elseif field == "__debug" then
                extras.ShowDebug()
            elseif field == "__intro" then
                extras.ShowWelcome()
            elseif field == "__news" or field == "__newsStar" or field == "__reportBugs" or field == "__info" then
                -- Information only.
                return
            elseif field == "__trySelect" then
                setOption("selectKeepsReleased", settings.selectKeepsReleased ~= true)
                if settings.selectKeepsReleased then
                    print("|cff80ff80WalkMap:|r Select keeps the map released is on. Press Select to leave the map - it stays released even if you close and open the map - and Select takes it back. Turn it off under Settings > Controller & help.")
                end
                refreshSettingsRows()
            elseif field == "__sortBags" and WalkMapBags then
                WalkMapBags.Sort()
            elseif field == "__bagBinding" and WalkMapBags then
                WalkMapBags.BindingHelp()
            elseif field == "__bagStatus" and WalkMapBags then
                print("|cff80ff80WalkMap:|r " .. WalkMapBags.Status())
            elseif field == "__miniIconScale" or field == "__nativeIconScale"
                or field == "__miniIconGap" or field == "__nativeIconGap"
                or field == "__miniIconRange" or field == "__nativeIconRange" then
                local setting = field:sub(3)
                local choices = setting:find("Scale") and {0.8, 1, 1.25}
                    or setting:find("Range") and {1, 0.75, 0.5}
                    or {0, 14, 22}
                local nextChoice = 1
                for n, choice in ipairs(choices) do
                    if settings[setting] == choice then
                        nextChoice = n % #choices + 1
                        break
                    end
                end
                settings[setting] = choices[nextChoice]
                refreshSettingsRows()
            elseif field == "__recommended" then
                applyRecommended()
                refreshSettingsRows()
            elseif field == "__welcomeIcons" then
                -- All quests -> Focused quest -> Off -> All quests
                if not settings.objectiveIcons then
                    setOption("focusObjectiveIcons", false)
                    setOption("objectiveIcons", true)
                elseif not settings.focusObjectiveIcons then
                    setOption("focusObjectiveIcons", true)
                else
                    setOption("objectiveIcons", false)
                end
                refreshSettingsRows()
            elseif field == "__welcomeLook" then
                local order, nextLook = WalkMapUI.LookOrder, nil
                for index, look in ipairs(order) do
                    if look == settings.look then nextLook = order[index % #order + 1] end
                end
                setOption("look", nextLook or "stone")
                refreshSettingsRows()
            elseif field == "__accountSave" then
                extras.SaveAccountSettings()
                print("|cff80ff80WalkMap:|r This character's settings are saved for your account."
                    .. " On another character: Settings > Profiles > Load account settings.")
                refreshSettingsRows()
            elseif field == "__accountNew" then
                extras.SetAccountForNew(not extras.AccountForNew())
                if extras.AccountForNew() and not extras.HasAccountSettings() then
                    print("|cff80ff80WalkMap:|r Save account settings first; until then new characters start with the defaults.")
                end
                refreshSettingsRows()
            elseif field == "__accountLoad" then
                local now = GetTime and GetTime() or 0
                if not extras.HasAccountSettings() then
                    print("|cff80ff80WalkMap:|r No account settings saved yet.")
                elseif InCombatLockdown and InCombatLockdown() then
                    print("|cff80ff80WalkMap:|r Load account settings after combat.")
                elseif accountLoadArmedAt and now - accountLoadArmedAt < 4 then
                    accountLoadArmedAt = nil
                    extras.LoadAccountSettings()
                    if C_UI and C_UI.Reload then C_UI.Reload() elseif ReloadUI then ReloadUI() end
                    return
                else
                    accountLoadArmedAt = now
                    if C_Timer and C_Timer.After then
                        C_Timer.After(4.1, function()
                            if refreshSettingsRows and settingsPanel and settingsPanel:IsShown() then refreshSettingsRows() end
                        end)
                    end
                end
                refreshSettingsRows()
            elseif field == "__applyLook" then
                if InCombatLockdown and InCombatLockdown() then
                    print("|cff80ff80WalkMap:|r The new look applies after combat (Apply now again).")
                elseif (settings.look or "classic") ~= WalkMapUI.Look() then
                    if C_UI and C_UI.Reload then C_UI.Reload() elseif ReloadUI then ReloadUI() end
                end
            elseif field == "__welcomeAreas" then
                setOption("areas", settings.areas == "all" and "focus"
                    or settings.areas == "focus" and "off" or "all")
                refreshSettingsRows()
            elseif field == "__announce" then
                settings.announce = settings.announce == "off" and "done"
                    or settings.announce == "done" and "progress" or "off"
                refreshSettingsRows()
            elseif field == "__trackerScope" then
                -- Off -> This zone -> This zone + nearby -> All zones -> Off
                if settings.zoneTracker == false then
                    settings.zoneTracker, settings.trackerScope = true, "zone"
                elseif settings.trackerScope == "zone" then
                    settings.trackerScope = "nearby"
                elseif settings.trackerScope == "nearby" then
                    settings.trackerScope = "all"
                else
                    settings.zoneTracker = false
                end
                refreshSettingsRows()
            elseif TRACKER_CHOICES[field:sub(3)] then
                cycleTrackerChoice(field:sub(3))
                refreshSettingsRows()
            elseif field == "__fadeAlpha" then
                local nextChoice = 2
                for n, choice in ipairs(FADE_CHOICES) do
                    if math.abs((settings.fadeAlpha or 0) - choice) < 0.01 then
                        nextChoice = n % #FADE_CHOICES + 1
                        break
                    end
                end
                settings.fadeAlpha = FADE_CHOICES[nextChoice]
                refreshSettingsRows()
            elseif field == "miniTerrain" then
                local alreadyShown = settings.miniMap
                    and settings.miniTerrain == value
                settings.miniTerrain = value
                setOption("miniMap", not alreadyShown)
            elseif value == nil then
                setOption(field, not settings[field])
            else
                setOption(field, value)
            end
        end)
        -- The row's height from its text, so rows never overlap.
        local width = row:GetWidth() or 0
        if width <= 0 then width = 446 end
        local left = selectable and 26 or 5
        row.description:ClearAllPoints()
        row.description:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -2)
        row.description:SetWidth(width - left - (isButton and 108 or 4))
        local textHeight = (tonumber(row.label:GetStringHeight()) or 12)
        if description and description ~= "" then
            textHeight = textHeight + 2 + (tonumber(row.description:GetStringHeight()) or 0)
        end
        local height = math.max(43, math.ceil(textHeight + 8))
        if i > 1 and y - height < bottom then
            fitted = i - 1
            break
        end
        row:SetHeight(height)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", settingsPanel, "TOPLEFT", 186, y)
        row:SetPoint("RIGHT", settingsPanel, "RIGHT", -28, 0)
        row.walkmapTop = y
        y = y - height - 1
        row:Show()
        settingsPanel.rows[#settingsPanel.rows + 1] = row
    end
    for i = fitted + 1, #settingsPanel.options do
        settingsPanel.options[i]:Hide()
    end
    -- Scrolling ends when the last row is shown.
    local lastShown = settingsPanel.scroll + fitted
    local scrollMax = lastShown >= #items and settingsPanel.scroll or #items - 1
    settingsPanel.scrollMax = scrollMax
    -- Scroll bar beside the options: only on pages that scroll. The thumb's
    -- size is the share of the page you see, its place where you are.
    local bar = settingsPanel.scrollBar
    if bar then
        if settingsPanel.scroll > 0 or lastShown < #items then
            local trackHeight = bar.walkmapTrack
            local thumbHeight = math.max(24, trackHeight * fitted / math.max(1, #items))
            local range = math.max(1, #items - fitted)
            local offset = (trackHeight - thumbHeight) * math.min(1, settingsPanel.scroll / range)
            if lastShown >= #items then offset = trackHeight - thumbHeight end
            bar.thumb:SetHeight(thumbHeight)
            bar.thumb:ClearAllPoints()
            bar.thumb:SetPoint("TOP", bar, "TOP", 0, -offset)
            bar.up:SetAlpha(settingsPanel.scroll > 0 and 1 or 0.3)
            bar.down:SetAlpha(lastShown < #items and 1 or 0.3)
            bar:Show()
        else
            bar:Hide()
        end
    end
    -- Controller scrolling: Up on the first row / Down on the last row
    -- (WalkMap_Navigation.lua and WalkMap_ControllerNative.lua).
    settingsPanel.walkmapScrollEdges = {
        first = settingsPanel.options[1], last = settingsPanel.options[fitted],
        up = settingsPanel.scroll > 0, down = lastShown < #items,
    }
end

local function createSettingsPanel()
    settingsPanel = CreateFrame("Frame", nil, owner)
    -- Tall enough for eight option rows (44 px each from y -110).
    settingsPanel:SetSize(660, 530)
    settingsPanel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    settingsPanel:SetFrameStrata("TOOLTIP")
    -- Keep this layer when the map itself changes layer (NPC and game
    -- windows): a parent's SetFrameStrata otherwise drags children along.
    if settingsPanel.SetFixedFrameStrata then settingsPanel:SetFixedFrameStrata(true) end
    settingsPanel:SetFrameLevel(owner:GetFrameLevel() + 18)
    settingsPanel:SetClampedToScreen(true)
    settingsPanel:EnableMouse(true)
    settingsPanel.categoryIndex = 1
    settingsPanel.categories, settingsPanel.options, settingsPanel.rows = {}, {}, {}
    WalkMapUI.Window(settingsPanel)
    WalkMapUI.Inset(settingsPanel, 10, 39, 491, 58)
    WalkMapUI.Inset(settingsPanel, 175, 39, 10, 58)
    local title = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", settingsPanel, "TOP", 0, -8)
    title:SetText("WalkMap settings")
    local categoriesTitle = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    categoriesTitle:SetPoint("TOPLEFT", settingsPanel, "TOPLEFT", 22, -51)
    categoriesTitle:SetText("Categories")
    settingsPanel.pageTitle = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    settingsPanel.pageTitle:SetPoint("TOPLEFT", settingsPanel, "TOPLEFT", 188, -50)
    settingsPanel.summary = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    settingsPanel.summary:SetPoint("TOPLEFT", settingsPanel, "TOPLEFT", 188, -75)
    settingsPanel.summary:SetPoint("RIGHT", settingsPanel, "RIGHT", -22, 0)
    settingsPanel.summary:SetJustifyH("LEFT")
    local close = CreateFrame("Button", nil, settingsPanel)
    close:SetSize(66, 22)
    close:SetPoint("BOTTOMRIGHT", settingsPanel, "BOTTOMRIGHT", -16, 12)
    extras.StyleButton(close)
    local closeText = close:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    closeText:SetPoint("CENTER")
    closeText:SetText("Done")
    close:SetScript("OnClick", function() setControllerPanelVisible(settingsPanel, false) end)
    settingsPanel.doneButton = close
    local cornerClose = CreateFrame("Button", nil, settingsPanel)
    -- Same lift as the map window: keep the visible X inside the title band.
    cornerClose:SetSize(24, 24)
    cornerClose:SetPoint("TOPRIGHT", settingsPanel, "TOPRIGHT", -4, 2)
    WalkMapUI.CloseButton(cornerClose)
    cornerClose:SetScript("OnClick", function() setControllerPanelVisible(settingsPanel, false) end)
    settingsPanel.closeButton = cornerClose
    local footer = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    footer:SetPoint("BOTTOMLEFT", settingsPanel, "BOTTOMLEFT", 16, 15)
    footer:SetText("D-pad: navigate    Left/Right: categories/options    B: close")
    footer:SetTextColor(0.7, 0.7, 0.7)
    local authors = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    authors:SetPoint("BOTTOM", settingsPanel, "BOTTOM", 0, 37)
    authors:SetText("Created by Anexseus and Underbuks")
    authors:SetTextColor(0.75, 0.75, 0.75)
    for i, page in ipairs(settingsPages) do
        if page.hidden then break end
        local row = CreateFrame("Button", nil, settingsPanel)
        -- 35 px steps leave room for ten categories above the footer.
        row:SetSize(145, 31)
        row:SetPoint("TOPLEFT", settingsPanel, "TOPLEFT", 17, -78 - (i - 1) * 35)
        row:EnableMouse(true)
        WalkMapUI.Row(row, true)
        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.label:SetPoint("LEFT", row, "LEFT", 7, 0)
        row.label:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row.label:SetJustifyH("LEFT")
        row.label:SetText(page[1])
        row:SetScript("OnClick", function()
            settingsPanel.categoryIndex = i
            refreshSettingsRows()
        end)
        row:Show()
        settingsPanel.categories[i] = row
    end
    for i = 1, 8 do
        local row = CreateFrame("CheckButton", nil, settingsPanel)
        row:SetHeight(43)
        row:SetPoint("TOPLEFT", settingsPanel, "TOPLEFT", 186, -110 - (i - 1) * 44)
        row:SetPoint("RIGHT", settingsPanel, "RIGHT", -28, 0)
        row:EnableMouse(true)
        styleRow(row)
        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.label:SetJustifyH("LEFT")
        row.description = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.description:SetJustifyH("LEFT")
        row.description:SetTextColor(0.72, 0.72, 0.72)
        row.description:SetWordWrap(true)
        settingsPanel.options[i] = row
    end
    -- Scroll bar (refreshSettingsRows shows it on pages that scroll): a
    -- track right of the options with arrows; wheel, the arrows or clicking
    -- the track scroll, and the controller scrolls at the first/last row.
    local bar = CreateFrame("Frame", nil, settingsPanel)
    bar:SetWidth(12)
    bar:SetPoint("TOPRIGHT", settingsPanel, "TOPRIGHT", -12, -124)
    bar:SetPoint("BOTTOMRIGHT", settingsPanel, "TOPRIGHT", -12, -110 - 8 * 44 + 15)
    bar.walkmapTrack = 8 * 44 - 13 - 16
    bar:EnableMouse(true)
    -- The thumb is a frame so the look can draw it in pieces (WalkMapUI.ScrollBar).
    bar.thumb = CreateFrame("Frame", nil, bar)
    bar.thumb:SetWidth(12)
    bar.thumb:EnableMouse(false)
    local function arrow(direction)
        local button = CreateFrame("Button", nil, bar)
        button:SetSize(14, 14)
        if direction < 0 then
            button:SetPoint("BOTTOM", bar, "TOP", 0, 1)
        else
            button:SetPoint("TOP", bar, "BOTTOM", 0, -1)
        end
        button:SetScript("OnClick", function() settingsPanel.walkmapScrollBy(direction) end)
        return button
    end
    bar.up, bar.down = arrow(-1), arrow(1)
    WalkMapUI.ScrollBar(bar, bar.thumb, bar.up, bar.down)
    bar:SetScript("OnMouseDown", function(self)
        local _, y = GetCursorPosition()
        local scale = self:GetEffectiveScale()
        local thumbTop = bar.thumb:GetTop()
        if y and thumbTop then
            settingsPanel.walkmapScrollBy(y / scale > thumbTop and -1 or 1)
        end
    end)
    bar:Hide()
    settingsPanel.scrollBar = bar
    settingsPanel.scroll = 0
    -- Scroll by one row. Returns true when the list moved.
    function settingsPanel.walkmapScrollBy(delta)
        local before = settingsPanel.scroll or 0
        settingsPanel.scroll = math.max(0, math.min(before + delta, settingsPanel.scrollMax or 0))
        if settingsPanel.scroll == before then return false end
        refreshSettingsRows()
        if WalkMapNativeController and WalkMapNativeController.RequestRefresh then
            WalkMapNativeController.RequestRefresh()
        end
        return true
    end
    -- Controller: Up on the first row or Down on the last row scrolls; the
    -- focus stays on the same row, which now shows the next setting.
    -- Rows have their own heights, so after a scroll fewer rows may fit and
    -- the focused row can be hidden. Then the focus belongs on the new last
    -- row; that row is returned as the second value. (Before, the focus sat
    -- on a hidden row and Down did nothing until you pressed Up first.)
    function settingsPanel.walkmapScroll(row, direction)
        local edges = settingsPanel.walkmapScrollEdges
        if not edges then return false end
        local moved = false
        if direction == "down" and row == edges.last and edges.down then moved = settingsPanel.walkmapScrollBy(1)
        elseif direction == "up" and row == edges.first and edges.up then moved = settingsPanel.walkmapScrollBy(-1) end
        if not moved then return false end
        if row and row.IsShown and not row:IsShown() then
            local now = settingsPanel.walkmapScrollEdges
            return true, now and now.last
        end
        return true
    end
    settingsPanel:EnableMouseWheel(true)
    settingsPanel:SetScript("OnMouseWheel", function(_, delta) settingsPanel.walkmapScrollBy(delta > 0 and -1 or 1) end)
    setControllerPanelVisible(settingsPanel, false)
end

function extras.SettingsPanel() return settingsPanel end
function extras.ShowSettingsPage(title)
    for index, page in ipairs(settingsPages) do
        if page[1] == title and settingsPanel then
            settingsPanel.categoryIndex = index
            refreshSettingsRows()
            return true
        end
    end
    return false
end

function extras.Init(window, mapCanvas, onChanged)
    owner, canvas, changed = window, mapCanvas, onChanged
    buttons = {}
    menu = CreateFrame("Frame", nil, owner)
    menu:SetFrameStrata("TOOLTIP")
    -- Keep this layer when the map itself changes layer (NPC and game
    -- windows): a parent's SetFrameStrata otherwise drags children along.
    if menu.SetFixedFrameStrata then menu:SetFixedFrameStrata(true) end
    menu:SetFrameLevel(owner:GetFrameLevel() + 12)
    menu:EnableMouse(true)
    menu.rows = {}
    styleMenu(menu)
    -- Watch clicks only while the menu is open. No fullscreen click-catching
    -- frame is needed, so clicks on the map and other UI still go through.
    menu:SetScript("OnShow", function(self)
        self.pressHeld = IsMouseButtonDown and
            (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton"))
    end)
    menu:SetScript("OnUpdate", function(self)
        if not IsMouseButtonDown or not GetCursorPosition then return end
        local down = IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
        if not down then self.pressHeld = false return end
        if self.pressHeld then return end
        self.pressHeld = true
        local scale = UIParent and UIParent.GetEffectiveScale
            and UIParent:GetEffectiveScale() or 1
        local x, y = GetCursorPosition()
        if not x or not y then return end
        x, y = x / scale, y / scale
        if not cursorIn(self, x, y) and not cursorIn(submenu, x, y)
            and not cursorIn(self.from, x, y) then
            self:Hide()
        end
    end)
    setControllerPanelVisible(menu, false)
    submenu = CreateFrame("Frame", nil, menu)
    submenu:SetFrameStrata("TOOLTIP")
    if submenu.SetFixedFrameStrata then submenu:SetFixedFrameStrata(true) end
    submenu:SetFrameLevel(menu:GetFrameLevel() + 2)
    submenu:EnableMouse(true)
    submenu.rows = {}
    styleMenu(submenu)
    -- Un-light the parent row once its submenu closes, however it closes.
    submenu:HookScript("OnHide", function(self)
        if self.parentRow then setRowOpen(self.parentRow, false) end
    end)
    setControllerPanelVisible(submenu, false)
    -- Menus may open with the mouse during combat (see native.SetVisible).
    menu.walkmapCombatPanel, submenu.walkmapCombatPanel = true, true
    for i = 1, 4 do
        local button = CreateFrame("Button", nil, owner)
        button:SetFrameLevel(owner:GetFrameLevel() + 4)
        button:EnableMouse(true)
        button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        button.label:SetPoint("CENTER")
        button.label:SetWidth(130)
        button.label:SetWordWrap(false)
        extras.StyleButton(button)
        buttons[i] = button
    end
    viewButton = CreateFrame("Button", nil, owner)
    viewButton:SetFrameLevel(owner:GetFrameLevel() + 4)
    viewButton:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT", 10,
        WalkMapUI.MapLayout.footerButtonBottom)
    viewButton:SetSize(86, 19)
    viewButton:EnableMouse(true)
    extras.StyleButton(viewButton)
    viewButton.label = viewButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    viewButton.label:SetPoint("CENTER")
    -- Footer quest focus: pick one quest to declutter, or All quests.
    questButton = CreateFrame("Button", nil, owner)
    questButton:SetFrameLevel(owner:GetFrameLevel() + 4)
    questButton:SetPoint("BOTTOMLEFT", viewButton, "BOTTOMRIGHT", 4, 0)
    questButton:SetSize(112, 19)
    questButton:EnableMouse(true)
    extras.StyleButton(questButton)
    questButton.label = questButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    questButton.label:SetPoint("LEFT", questButton, "LEFT", 6, 0)
    questButton.label:SetPoint("RIGHT", questButton, "RIGHT", -6, 0)
    questButton.label:SetWordWrap(false)
    questButton:SetScript("OnClick", function(self)
        if settingsPanel:IsShown() then setControllerPanelVisible(settingsPanel, false) end
        extras.OpenQuestMenu(self)
    end)
    questButton:HookScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Quest focus")
        GameTooltip:AddLine("Show only one quest's icons and areas, or all quests.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    questButton:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    createSettingsPanel()
    -- Prepare the report's own controls during addon initialization rather
    -- than inside the controller's synthetic click path.
    local debugOK, debugError = pcall(createDebugPanel)
    debugAction = nil
    if not debugOK then extras.DebugEvent("Debug window setup: " .. tostring(debugError)) end
    viewButton:SetScript("OnClick", function(self)
        if settingsPanel:IsShown() then setControllerPanelVisible(settingsPanel, false) return end
        -- Settings opened normally never start on the hidden welcome page.
        local current = settingsPages[settingsPanel.categoryIndex]
        if not current or current.hidden then settingsPanel.categoryIndex = 1 end
        extras.CloseMenus()
        settingsPanel.from = self
        local screenWidth = UIParent:GetWidth()
        local screenHeight = UIParent:GetHeight()
        settingsPanel:SetScale(math.min(1,
            (screenWidth - 24) / settingsPanel:GetWidth(),
            (screenHeight - 24) / settingsPanel:GetHeight()))
        refreshSettingsRows()
        setControllerPanelVisible(settingsPanel, true)
    end)
    local groupOptions = {}
    for _, group in ipairs(placeGroups) do
        groupOptions[#groupOptions + 1] = {"__group:" .. group[1], group[2]}
    end
    groupOptions[#groupOptions + 1] = {"__clear", "Clear all"}
    buttons[1]:SetScript("OnClick", function(self)
        if settingsPanel:IsShown() then setControllerPanelVisible(settingsPanel, false) end
        openMenu(self, groupOptions, "places")
    end)
    buttons[2]:SetScript("OnClick", function()
        setOption("clearView", not settings.clearView)
    end)
    buttons[3]:SetScript("OnClick", function()
        if WalkMapCombat and WalkMapCombat.Locked() then
            print("|cff80ff80WalkMap:|r The minimap can be changed after combat.")
            return
        end
        if not settings.miniMap then
            settings.miniTerrain = "game"
            setOption("miniMap", true)
        elseif settings.miniTerrain == "game" then
            settings.miniTerrain = "zone"
            setOption("miniMap", true)
        else
            setOption("miniMap", false)
        end
    end)
    buttons[4]:SetScript("OnClick", function()
        -- Follow also does what the old Player button did: while paused or
        -- while another zone is shown, it brings the map back to you;
        -- otherwise it switches on/off (and on returns to your zone).
        local elsewhere = WalkMapMaps and WalkMapMaps.Selected and WalkMapMaps.Selected()
        if settings.follow and (followPausedAt or elsewhere) then
            extras.ResumeFollow()
            if elsewhere then WalkMapMaps.Choose(nil) end
            refreshLabels()
            return
        end
        followPausedAt = nil
        setOption("follow", not settings.follow)
        if settings.follow and elsewhere then WalkMapMaps.Choose(nil) end
    end)
    -- Usable with the mouse in combat: Places, Clear view and Follow only
    -- change what WalkMap draws. Minimap stays locked (its game-terrain
    -- mode hides parts of the game's own minimap).
    if WalkMapCombat and WalkMapCombat.AllowInCombat then
        WalkMapCombat.AllowInCombat(buttons[1])
        WalkMapCombat.AllowInCombat(buttons[2])
        WalkMapCombat.AllowInCombat(buttons[4])
    end
    extras.Resize()
end

function extras.Command(command, value)
    if command == "places" and value == "firstaid" then value = "first aid" end
    if command == "clear" and (value == "on" or value == "off") then
        setOption("clearView", value == "on")
    elseif command == "autosell" and (value == "on" or value == "off") then
        setOption("autoSellJunk", value == "on")
    elseif command == "icons" and (value == "on" or value == "off") then
        setOption("objectiveIcons", value == "on")
    elseif command == "focusicons" and (value == "on" or value == "off") then
        setOption("focusObjectiveIcons", value == "on")
    elseif command == "labels" and (value == "on" or value == "off") then
        setOption("questLabels", value == "on")
    elseif command == "follow" and (value == "on" or value == "off") then
        setOption("follow", value == "on")
    elseif command == "pad" and (value == "on" or value == "off") then
        setOption("controllerMode", value == "on")
    elseif command == "pad" and (value == "" or value == "toggle") then
        setOption("controllerMode", not settings.controllerMode)
    elseif command == "navigation" and (value == "native" or value == "custom") then
        setOption("nativeController", value == "native")
    elseif command == "profile" and (profiles[value] or value == "custom" or value == "save") then
        chooseProfile(value)
    elseif command == "minimap" and (value == "on" or value == "off") then
        setOption("miniMap", value == "on")
    elseif command == "miniterrain" and (value == "zone" or value == "game") then
        settings.miniTerrain = value
        setOption("miniMap", true)
    elseif command == "nativeicons" and (value == "on" or value == "off") then
        setOption("nativeIcons", value == "on")
    elseif command == "givers" and value == "reset" then
        settings.hiddenGivers = {}
        extras.Invalidate()
        if changed then changed() end
    elseif command == "markers" and value == "reset" then
        settings.hiddenMarkers = {}
        extras.DebugEvent("Restored hidden markers")
        extras.Invalidate()
        if changed then changed() end
    elseif command == "nearest" and (value == "on" or value == "off") then
        setOption("nearestObjective", value == "on")
    elseif command == "givers" and (value == "on" or value == "off") then
        setOption("givers", value == "on")
    elseif command == "areas" and (value == "all" or value == "focus" or value == "off") then
        setOption("areas", value)
    elseif command == "places" and value == "none" then
        togglePlace("__clear")
    elseif command == "places" and placeNames[value] then
        togglePlace(value)
    elseif command == "level" and (value == "auto" or tonumber(value)) then
        local number = tonumber(value)
        if number and (number < 1 or number > 60) then return false end
        setOption("level", number or 0)
    else
        return false
    end
    return true
end
