-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- A small stand-in for the game client, enough to load WalkMap's files and
-- drive them from tests. Nothing here ships to players: the TOC does not
-- list this folder.
--
--   local Mock = dofile("tests/mock.lua")
--   local env = Mock.new()            -- a fresh fake client
--   env.load("WalkMap_Maps.lua")      -- run an addon file inside it
--   env.WalkMapMaps.Parent(1436)      -- addon globals live on env
--
-- Works with Lua 5.1 (the game's version), LuaJIT and Lua 5.2-5.4.
local Mock = {}
local unpack = table.unpack or unpack

local source = debug and debug.getinfo and debug.getinfo(1, "S").source or ""
Mock.root = (source:match("^@(.*)[/\\]tests[/\\][^/\\]+$") or ".") .. "/"

-- ---------------------------------------------------------------- widgets
local W = {}
local function newWidget(env, kind, name, parent)
    local w = {__kind = kind, __name = name, __parent = parent, __scripts = {}, __shown = true,
        __w = 0, __h = 0, __level = parent and (parent.__level or 0) + 1 or 1, __alpha = 1,
        __events = {}, __attr = {}, __env = env, __children = {}}
    if parent and parent.__children then parent.__children[#parent.__children + 1] = w end
    return setmetatable(w, env.__widgetMeta)
end
local function fire(w, script, ...)
    local fn = w.__scripts[script]
    if fn then return fn(w, ...) end
end
function W:SetSize(w, h) self.__w, self.__h = w or 0, h or w or 0 end
function W:SetWidth(w) self.__w = w or 0 end
function W:SetHeight(h) self.__h = h or 0 end
function W:GetWidth() return self.__w end
function W:GetHeight() return self.__h end
function W:GetSize() return self.__w, self.__h end
function W:Show() if not self.__shown then self.__shown = true fire(self, "OnShow") end end
function W:Hide() if self.__shown then self.__shown = false fire(self, "OnHide") end end
function W:SetShown(v) if v then self:Show() else self:Hide() end end
function W:IsShown() return self.__shown end
function W:IsVisible()
    local w = self
    while w do
        if not w.__shown then return false end
        w = w.__parent
    end
    return true
end
function W:SetScript(name, fn) self.__scripts[name] = fn end
function W:GetScript(name) return self.__scripts[name] end
function W:HasScript() return true end
function W:HookScript(name, fn)
    local old = self.__scripts[name]
    self.__scripts[name] = old and function(...) old(...) return fn(...) end or fn
end
function W:Click(button) fire(self, "OnClick", button or "LeftButton") end
function W:SetText(text) self.__text = text end
function W:SetFormattedText(fmt, ...) self.__text = string.format(fmt, ...) end
function W:GetText() return self.__text end
-- 12 px a line; with a width set, the text wraps at 6 px a character.
function W:GetStringHeight()
    local width = tonumber(self.__w) or 0
    if width <= 0 or not self.__text or self.__text == "" then return 12 end
    return 12 * math.max(1, math.ceil(#tostring(self.__text) * 6 / width))
end
-- 6 px a character at size 12; SetFont scales it (tests can set
-- env.__fontScale to draw everything larger, like a small screen).
function W:GetStringWidth()
    local scale = (self.__fontSize or 12) / 12 * ((self.__env and self.__env.__fontScale) or 1)
    return #tostring(self.__text or "") * 6 * scale
end
function W:GetFont() return "Fonts\\FRIZQT__.TTF", self.__fontSize or 12, "" end
function W:EnableGamePadButton(on) self.__gamepadButtons = on and true or false end
function W:SetFont(_, size) self.__fontSize = size return true end
function W:GetFrameLevel() return self.__level end
function W:SetFrameLevel(level) self.__level = level end
function W:GetFrameStrata() return self.__strata or "MEDIUM" end
function W:SetFrameStrata(strata) self.__strata = strata end
function W:GetEffectiveScale() return 1 end
function W:GetScale() return 1 end
function W:GetLeft() return self.__left or 0 end
function W:GetRight() return (self.__left or 0) + self.__w end
function W:GetTop() return self.__top or self.__h end
function W:GetBottom() return (self.__top or self.__h) - self.__h end
function W:GetCenter() return (self.__left or 0) + self.__w / 2, (self.__top or self.__h) - self.__h / 2 end
function W:SetPoint(...) self.__point = {...} end
function W:GetPoint()
    if self.__point then return Mock.unpack(self.__point) end
    return "CENTER", self.__parent, "CENTER", 0, 0
end
function W:GetNumPoints() return 1 end
function W:GetParent() return self.__parent end
function W:SetParent(parent) self.__parent = parent end
function W:GetName() return self.__name end
function W:GetObjectType() return self.__kind end
function W:SetAttribute(k, v) self.__attr[k] = v end
function W:GetAttribute(k) return self.__attr[k] end
function W:RegisterEvent(event) self.__events[event] = true return true end
function W:UnregisterEvent(event) self.__events[event] = nil end
function W:UnregisterAllEvents() self.__events = {} end
function W:IsEventRegistered(event) return self.__events[event] == true end
function W:SetAlpha(a) self.__alpha = a end
function W:GetAlpha() return self.__alpha end
function W:SetChecked(v) self.__checked = v and true or false end
function W:GetChecked() return self.__checked == true end
function W:IsMouseOver() return self.__mouseOver == true end
function W:IsProtected() return false end
function W:GetChildren() end
function W:GetRegions() end
function W:GetVertexColor() return 1, 1, 1, 1 end
function W:GetTextColor() return 1, 1, 1, 1 end
function W:GetID() return self.__id or 0 end
function W:SetID(id) self.__id = id end
function W:GetTexture() return self.__texture end
function W:SetTexture(texture) self.__texture = texture end
function W:GetTexCoord() return 0, 0, 0, 1, 1, 0, 1, 1 end
function W:NumLines() return 0 end
for _, method in ipairs({"CreateTexture", "CreateFontString", "CreateAnimationGroup", "CreateAnimation",
    "CreateLine", "CreateMaskTexture"}) do
    local kind = method:sub(7)
    W[method] = function(self, name) return newWidget(self.__env, kind, name, self) end
end
for _, method in ipairs({"GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture",
    "GetCheckedTexture", "GetFontString", "GetThumbTexture"}) do
    W[method] = function(self)
        local key = "__" .. method
        if not self[key] then self[key] = newWidget(self.__env, "Region", nil, self) end
        return self[key]
    end
end
-- Any other method that starts with a usual verb (SetPoint, EnableMouse,
-- ClearAllPoints...) exists and does nothing; Is/Has/Can give false, Get
-- gives nil. Everything else stays a plain field (nil when unset), so
-- checks such as "if frame.Inset then" behave as in the game.
local VERBS = {"Set", "Get", "Is", "Has", "Can", "Enable", "Disable", "Register", "Unregister", "Clear",
    "Start", "Stop", "Add", "Remove", "Lock", "Unlock", "Raise", "Lower", "Play", "Pause", "Finish",
    "Apply", "Update", "Reset", "Does", "Propagate"}
local generic = {}
local function isMethodName(key)
    for _, verb in ipairs(VERBS) do
        if key:sub(1, #verb) == verb and key:sub(#verb + 1, #verb + 1):match("^%u?$") then return true end
    end
    return false
end
local function fallback(_, key)
    if W[key] then return W[key] end
    if type(key) ~= "string" or not isMethodName(key) then return nil end
    local fn = generic[key]
    if not fn then
        if key:match("^Is") or key:match("^Has") or key:match("^Can") then fn = function() return false end
        else fn = function() end end
        generic[key] = fn
    end
    return fn
end

-- ------------------------------------------------------------------ world
-- A small classic world: Azeroth, two continents and a few zones.
local function defaultMaps()
    return {
        [946] = {name = "Cosmic", type = 0, art = false},
        [947] = {name = "Azeroth", type = 1, parent = 946},
        [1414] = {name = "Kalimdor", type = 2, parent = 947},
        [1415] = {name = "Eastern Kingdoms", type = 2, parent = 947},
        [1429] = {name = "Elwynn Forest", type = 3, parent = 1415},
        [1431] = {name = "Duskwood", type = 3, parent = 1415},
        [1433] = {name = "Redridge Mountains", type = 3, parent = 1415},
        [1436] = {name = "Westfall", type = 3, parent = 1415},
        [1453] = {name = "Stormwind City", type = 3, parent = 1415},
        [1411] = {name = "Durotar", type = 3, parent = 1414},
        [1413] = {name = "The Barrens", type = 3, parent = 1414},
    }
end

function Mock.new(options)
    options = options or {}
    local env = setmetatable({}, {__index = _G})
    env._G = env
    env.__widgetMeta = {__index = fallback}
    env.__frames, env.__timers, env.__printed = {}, {}, {}
    env.__time = 100
    env.__maps = options.maps or defaultMaps()
    env.__playerMap = options.playerMap or 1436
    env.__zone = options.zone or (env.__maps[env.__playerMap] or {}).name or "Westfall"
    env.__level = options.level or 20
    env.__quests = options.quests or {}      -- quest-log rows: {header = "Zone"} or {id =, title =, level =}
    env.__onMap = options.onMap or {}        -- [mapID] = {questID, ...} for C_QuestLog.GetQuestsOnMap
    env.__distance = options.distance or {}  -- [questID] = yards
    env.__cvars, env.__combat = {autoQuestWatch = "1"}, false
    env.__cursor = {0, 0}

    function env.CreateFrame(kind, name, parent)
        local frame = newWidget(env, kind or "Frame", name, parent)
        env.__frames[#env.__frames + 1] = frame
        if name then env[name] = frame end
        return frame
    end
    env.UIParent = env.CreateFrame("Frame", "UIParent")
    env.UIParent:SetSize(1920, 1080)
    env.WorldFrame = env.CreateFrame("Frame", "WorldFrame")
    env.GameTooltip = env.CreateFrame("GameTooltip", "GameTooltip", env.UIParent)
    env.GameTooltip:Hide()
    env.Minimap = env.CreateFrame("Minimap", "Minimap", env.UIParent)
    env.Minimap:SetSize(140, 140)

    env.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
        env.__printed[#env.__printed + 1] = table.concat(parts, " ")
    end
    env.GetTime = function() return env.__time end
    env.GetCursorPosition = function() return env.__cursor[1], env.__cursor[2] end
    env.InCombatLockdown = function() return env.__combat end
    env.UnitLevel = function() return env.__level end
    env.UnitName = function() return "Tester" end
    env.UnitExists = function() return false end
    env.GetMaxPlayerLevel = function() return 60 end
    env.GetZoneText = function() return env.__zone end
    env.GetRealZoneText = env.GetZoneText
    env.GetCVar = function(name) return env.__cvars[name] end
    env.SetCVar = function(name, value) env.__cvars[name] = tostring(value) end
    env.IsAltKeyDown = function() return false end
    env.IsShiftKeyDown = function() return false end
    env.IsControlKeyDown = function() return false end
    env.IsMouseButtonDown = function() return false end
    env.hooksecurefunc = function() end
    env.GetQuestDifficultyColor = function() return {r = 1, g = 0.82, b = 0} end
    env.SlashCmdList = {}
    env.tinsert, env.tremove, env.wipe = table.insert, table.remove, function(t)
        for k in pairs(t) do t[k] = nil end
        return t
    end
    env.format, env.strfind, env.strsub, env.strlower = string.format, string.find, string.sub, string.lower
    env.C_Timer = {After = function(delay, fn)
        env.__timers[#env.__timers + 1] = {at = env.__time + (delay or 0), fn = fn}
    end}
    -- Addon metadata comes straight from WalkMap.toc.
    env.C_AddOns = {GetAddOnMetadata = function(addon, field)
        if addon ~= "WalkMap" then return nil end
        for line in io.lines(Mock.root .. "WalkMap.toc") do
            local key, value = line:match("^##%s*([^:]+):%s*(.-)%s*$")
            if key == field then return value end
        end
    end}
    env.Enum = {UIMapType = {Cosmic = 0, World = 1, Continent = 2, Zone = 3, Dungeon = 4, Micro = 5, Orphan = 6}}

    local function mapInfo(id)
        local map = id and env.__maps[id]
        if not map then return nil end
        return {mapID = id, name = map.name, mapType = map.type, parentMapID = map.parent or 0}
    end
    env.C_Map = {
        GetMapInfo = mapInfo,
        GetBestMapForUnit = function() return env.__playerMap end,
        GetMapArtLayers = function(id)
            local map = env.__maps[id]
            if not map or map.art == false then return {} end
            return {{layerWidth = 1002, layerHeight = 668, tileWidth = 256, tileHeight = 256}}
        end,
        GetMapArtLayerTextures = function(id)
            local map = env.__maps[id]
            if not map or map.art == false then return {} end
            local files = {}
            for i = 1, 12 do files[i] = "map" .. id .. "_" .. i end
            return files
        end,
        GetPlayerMapPosition = function(id)
            if not env.__maps[id] then return nil end
            return {GetXY = function() return 0.5, 0.5 end}
        end,
        GetMapChildrenInfo = function(id, kind, all)
            local list = {}
            for childID, map in pairs(env.__maps) do
                local under, current = false, map
                for _ = 1, 6 do
                    if not current or not current.parent then break end
                    if current.parent == id then under = true break end
                    if not all then break end
                    current = env.__maps[current.parent]
                end
                if under and (kind == nil or map.type == kind) then list[#list + 1] = mapInfo(childID) end
            end
            table.sort(list, function(a, b) return a.mapID < b.mapID end)
            return list
        end,
        -- Tests set env.__childAt = function(mapID, x, y) return childMapID end.
        GetMapInfoAtPosition = function(id, x, y)
            local child = env.__childAt and env.__childAt(id, x, y)
            return child and mapInfo(child) or nil
        end,
        -- Tests set env.__highlight = function(mapID, x, y) return fileID,
        -- atlas, texX, texY, width, height, left, top end (map fractions).
        GetMapHighlightInfoAtPosition = function(id, x, y)
            if env.__highlight then return env.__highlight(id, x, y) end
            return 0
        end,
    }

    local function questRow(id)
        for _, row in ipairs(env.__quests) do if row.id == id then return row end end
    end
    env.C_QuestLog = {
        GetNumQuestLogEntries = function() return #env.__quests end,
        GetInfo = function(index)
            local row = env.__quests[index]
            if not row then return nil end
            if row.header then return {isHeader = true, title = row.header} end
            return {isHeader = false, questID = row.id, title = row.title, level = row.level,
                suggestedGroup = row.group or 0}
        end,
        GetQuestsOnMap = function(mapID)
            local list = {}
            for _, id in ipairs(env.__onMap[mapID] or {}) do list[#list + 1] = {questID = id, x = 0.5, y = 0.5} end
            return list
        end,
        IsComplete = function(id) local row = questRow(id) return row and row.complete == true or false end,
        ReadyForTurnIn = function(id) local row = questRow(id) return row and row.complete == true or false end,
        GetTitleForQuestID = function(id) local row = questRow(id) return row and row.title or nil end,
        GetQuestObjectives = function(id)
            local row = questRow(id)
            return row and row.objectives or {}
        end,
        GetDistanceSqToQuest = function(id)
            local yards = env.__distance[id]
            if not yards then return nil end
            return yards * yards, true
        end,
    }

    -- Run one addon file (path relative to the addon folder) inside env.
    function env.load(file)
        -- Every module shows text through WalkMapL (WalkMap_Locale.lua).
        if not rawget(env, "WalkMapL") and not file:find("^WalkMap_Locale") then
            env.load("WalkMap_Locale.lua")
            env.load("WalkMap_Locale_deDE.lua")
            env.load("WalkMap_Locale_frFR.lua")
        end
        -- WALKMAP_COLLECT=deDE texlua tests/run.lua: list every shown text
        -- without a translation (tests/untranslated.txt).
        local collect = os.getenv("WALKMAP_COLLECT")
        if collect and not env.__collecting and rawget(env, "WalkMapLocale") and file ~= "WalkMap_Locale.lua" then
            env.__collecting = true
            env.WalkMapLocale.Force(collect)
            Mock.collected = Mock.collected or {}
            env.WalkMapLocale.CollectMisses(Mock.collected)
        end
        local path = Mock.root .. file
        local chunk, message
        if setfenv then
            chunk, message = loadfile(path)
            if chunk then setfenv(chunk, env) end
        else
            chunk, message = loadfile(path, "t", env)
        end
        if not chunk then error(message, 0) end
        return chunk("WalkMap", {})
    end
    -- The files the TOC lists, in order.
    function env.tocFiles()
        local files = {}
        for line in io.lines(Mock.root .. "WalkMap.toc") do
            line = line:gsub("%s+$", "")
            if line ~= "" and line:sub(1, 1) ~= "#" then files[#files + 1] = line end
        end
        return files
    end
    -- Load the whole addon as the client would. Saved variables come first.
    function env.loadAddon(savedAccount, savedCharacter)
        env.WalkMapSettings = savedAccount or {}
        -- savedCharacter false: a character that has never run WalkMap.
        if savedCharacter == false then env.WalkMapCharacterSettings = nil
        else env.WalkMapCharacterSettings = savedCharacter or {} end
        for _, file in ipairs(env.tocFiles()) do env.load(file) end
    end
    function env.fire(event, ...)
        for _, frame in ipairs(env.__frames) do
            if frame.__events[event] and frame.__scripts.OnEvent then frame.__scripts.OnEvent(frame, event, ...) end
        end
    end
    -- Advance the clock: timers, then OnUpdate on every visible frame.
    function env.tick(seconds, steps)
        steps = steps or 1
        local delta = (seconds or 0.1) / steps
        for _ = 1, steps do
            env.__time = env.__time + delta
            local due = {}
            for i = #env.__timers, 1, -1 do
                if env.__timers[i].at <= env.__time then due[#due + 1] = table.remove(env.__timers, i) end
            end
            for i = #due, 1, -1 do due[i].fn() end
            local count = #env.__frames
            for i = 1, count do
                local frame = env.__frames[i]
                if frame.__scripts.OnUpdate and frame:IsVisible() then frame.__scripts.OnUpdate(frame, delta) end
            end
        end
    end
    return env
end

-- ------------------------------------------------------------- assertions
function Mock.eq(got, want, what)
    if got ~= want then
        error((what or "value") .. ": expected " .. tostring(want) .. ", got " .. tostring(got), 2)
    end
end
function Mock.ok(value, what)
    if not value then error((what or "check") .. " failed", 2) end
end
Mock.unpack = unpack
return Mock
