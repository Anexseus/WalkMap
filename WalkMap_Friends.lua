-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
--
-- Friends and guild on the map (Settings > Map).
--
-- By zone (Friends on the map, Guild on the map; on unless turned off):
-- everyone online on your friends list (and Battle.net friends playing this
-- game, of your faction) and in your guild, as the game's own lists give it
-- - a badge on the zone with who is there.
--
-- Dots (Share where you are; OFF unless turned on): your place goes to your
-- guild and to your friends who use WalkMap or OpenMap, and theirs come
-- back as class-coloured dots. Never sent from a dungeon, raid or
-- battleground. Party and raid members already have WalkMap's own dots.
--
-- The messages are OpenMap's (github.com/openmap-world/openmap, MIT), so
-- WalkMap and OpenMap players see each other: addon prefix "OpenMapLoc";
--   "L1\t<uiMapID>\t<x>\t<y>\t<CLASS>\t<level>"  (x, y 0..1 on that map)
--   "L0"  stopped sharing;  "H1" hello to a friend who comes online,
--   answered with "H2" (or your place when you share it).
-- Every few seconds while you move, each minute while you stand still. The
-- realm handling (Forever's numbered realms share one pool) follows
-- OpenMap's Map/Friends.lua.

WalkMapFriends = {}
local friendsMod = WalkMapFriends

local PREFIX = "OpenMapLoc"
local TICK = 2              -- seconds between looks at where you are
local SEND_EVERY = 10       -- seconds between places sent while moving
local STILL_EVERY = 60      -- ... and while standing still
local GONE_AFTER = 150      -- seconds without word before a dot goes
local MOVED = 0.002
local SEND_GAP = 0.5        -- seconds between messages
local LIST_MAX = 25         -- names in a zone tooltip

local roster = {}           -- full name -> {name, class, level, area, guild, friend, guid}
local friends = {}          -- full name -> {whisper = name} or {bn = gameAccountID}
local known = {}            -- full name -> true: friends who use WalkMap/OpenMap
local live = {}             -- full name -> {map, x, y, class, level, guild, at}
local last = {at = -math.huge}
local sharing = false
local realm
local classByName
local zonePins, dotPins = {}, {}
local currentMapShown

local wipe = wipe or function(t) for k in pairs(t) do t[k] = nil end end
local function split(text)
    if strsplit then return strsplit("\t", text, 6) end
    local parts = {}
    for part in (text .. "\t"):gmatch("([^\t]*)\t") do parts[#parts + 1] = part end
    return parts[1], parts[2], parts[3], parts[4], parts[5], parts[6]
end
local function look(texture, atlas, file)
    if not (texture.SetAtlas and pcall(texture.SetAtlas, texture, atlas)) then
        texture:SetTexture(file)
        texture:SetTexCoord(0, 1, 0, 1)
    end
end

local function secret(value)
    return issecretvalue and issecretvalue(value) or false
end
local function value(v)
    if secret(v) then return nil end
    return v
end
local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if not ok or secret(a) then return nil end
    return a, b, c
end
local function now() return GetTime and GetTime() or 0 end

local function wantZones() return WalkMapExtras.FriendsOnMap() or WalkMapExtras.GuildOnMap() end
local function wantShare() return WalkMapExtras.ShareLocation() end

-- =========================================================
-- Names and realms
-- =========================================================
local function Realm()
    if not realm then
        local r = call(GetNormalizedRealmName)
        if type(r) ~= "string" or r == "" then r = (call(GetRealmName) or ""):gsub("[%s%-]", "") end
        if r == "" then return "" end
        realm = r
    end
    return realm
end

local function plain(rlm) return (rlm:gsub("[%s%-']", "")):lower() end

-- Forever's numbered realms (CAMWOWEU5Realm4PvP ...) share one pool.
local function pool(rlm)
    return (plain(rlm):gsub("%d+realm", "realm"):gsub("realm%d+", "realm"))
end

local function samePool(full)
    local _, rlm = full:match("^([^%-]+)%-(.+)$")
    local mine = Realm()
    return rlm and mine ~= "" and pool(rlm) == pool(mine) or false
end

local function Full(name, rlm)
    if secret(name) or type(name) ~= "string" or name == "" then return nil end
    if name:find("-", 1, true) then return name end
    if type(rlm) == "string" and rlm ~= "" then return name .. "-" .. rlm:gsub("[%s%-]", "") end
    return name .. "-" .. Realm()
end

-- Shown without the realm; another realm's name gets " (*)".
local function Shown(full)
    local name, rlm = full:match("^([^%-]+)%-(.+)$")
    name = name or full
    if rlm and Realm() ~= "" and plain(rlm) ~= plain(Realm()) then
        name = name .. (FOREIGN_SERVER_LABEL or " (*)")
    end
    return name
end

local function isMe(full)
    if type(full) ~= "string" then return false end
    local me = call(UnitName, "player")
    if type(me) ~= "string" then return false end
    local name, rlm = full:match("^([^%-]+)%-?(.*)$")
    if name ~= me then return false end
    return rlm == "" or plain(rlm) == plain(Realm())
end

local function classFile(name)
    if type(name) ~= "string" then return nil end
    if not classByName then
        classByName = {}
        for file, n in pairs(LOCALIZED_CLASS_NAMES_MALE or {}) do classByName[n] = file end
        for file, n in pairs(LOCALIZED_CLASS_NAMES_FEMALE or {}) do classByName[n] = file end
    end
    return classByName[name] or (name:match("^%u+$") and name) or nil
end

local function classColor(class)
    local c = type(class) == "string" and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

local function inGroup(full)
    if not (IsInGroup and IsInGroup()) then return false end
    local short = full:match("^[^%-]+") or full
    return (call(UnitInParty, short) or call(UnitInRaid, short)) and true or false
end

-- =========================================================
-- Sending: one message every SEND_GAP; a newer one per target replaces it
-- =========================================================
local outbox, order = {}, {}
local sender = CreateFrame("Frame")
sender:Hide()
local wait = 0
sender:SetScript("OnUpdate", function(self, elapsed)
    wait = wait - (elapsed or 0)
    if wait > 0 then return end
    local key = table.remove(order, 1)
    if not key then self:Hide() return end
    local m = outbox[key]
    outbox[key] = nil
    wait = SEND_GAP
    -- Your place never leaves once sharing is off, whatever was queued.
    if m.text:sub(1, 2) == "L1" and not wantShare() then return end
    if m.bn then
        if BNSendGameData then pcall(BNSendGameData, m.bn, PREFIX, m.text) end
    elseif C_ChatInfo and C_ChatInfo.SendAddonMessage then
        pcall(C_ChatInfo.SendAddonMessage, PREFIX, m.text, m.channel, m.target)
    end
end)

local function send(key, text, channel, target, bn)
    if not outbox[key] then order[#order + 1] = key end
    outbox[key] = {text = text, channel = channel, target = target, bn = bn}
    sender:Show()
end

local function toFriend(full, text)
    local f = friends[full]
    if not f then return end
    if f.bn then send(full, text, nil, nil, f.bn) else send(full, text, "WHISPER", f.whisper) end
end

local function broadcast(text)
    local guild = IsInGuild and IsInGuild()
    if guild then send("GUILD", text, "GUILD") end
    for full in pairs(known) do
        if friends[full] and not (guild and roster[full] and roster[full].guild) then toFriend(full, text) end
    end
end

-- Where you are: zone uiMapID and x, y; nil inside an instance.
local function here()
    if value(IsInInstance and IsInInstance()) then return nil end
    local best = call(C_Map.GetBestMapForUnit, "player")
    if type(best) ~= "number" then return nil end
    local p = call(C_Map.GetPlayerMapPosition, best, "player")
    if not p or not p.GetXY then return nil end
    local ok, x, y = pcall(p.GetXY, p)
    if not ok or secret(x) or secret(y) or type(x) ~= "number" or type(y) ~= "number" then return nil end
    if x <= 0 and y <= 0 then return nil end
    return best, x, y
end

local function stopSharing()
    if sharing then
        sharing = false
        last.at, last.text = -math.huge, nil
        broadcast("L0")
    end
end

local function tick()
    if not wantShare() then stopSharing() return end
    local m, x, y = here()
    if not m then stopSharing() return end
    local moved = m ~= last.map or math.abs(x - (last.x or 0)) > MOVED or math.abs(y - (last.y or 0)) > MOVED
    if now() - last.at < (moved and SEND_EVERY or STILL_EVERY) then return end
    local _, class = UnitClass("player")
    class = value(class)
    last.map, last.x, last.y, last.at = m, x, y, now()
    last.text = ("L1\t%d\t%.4f\t%.4f\t%s\t%d"):format(m, x, y, type(class) == "string" and class or "",
        tonumber(value(UnitLevel("player"))) or 0)
    sharing = true
    broadcast(last.text)
end
friendsMod.Tick = tick
friendsMod.LastSent = function() return last.text end

-- =========================================================
-- Who is online
-- =========================================================
local function scanGuild()
    if not (IsInGuild and IsInGuild()) or not GetGuildRosterInfo then return end
    for i = 1, tonumber(value(GetNumGuildMembers and GetNumGuildMembers())) or 0 do
        local name, _, _, level, _, area, _, _, online, _, class = GetGuildRosterInfo(i)
        local full = value(online) and Full(name)
        if full and not isMe(full) then
            roster[full] = {name = Shown(full), class = value(class), level = tonumber(value(level)),
                area = value(area), guild = true}
        end
    end
end

local function addFriend(full, level, area, className, how)
    local r = roster[full]
    if not samePool(full) and not r then return end
    r = r or {name = Shown(full), level = tonumber(value(level)), area = value(area),
        class = classFile(value(className))}
    r.friend = true
    roster[full] = r
    if how.bn or not friends[full] then friends[full] = how end
end

local function scanFriends()
    if not (C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetFriendInfoByIndex) then return end
    for i = 1, tonumber(value(C_FriendList.GetNumFriends())) or 0 do
        local f = C_FriendList.GetFriendInfoByIndex(i)
        local full = type(f) == "table" and value(f.connected) and Full(f.name)
        if full and not isMe(full) then addFriend(full, f.level, f.area, f.className, {whisper = f.name}) end
    end
end

-- The other faction's place is never shown (Battle.net reaches across).
local function sameFaction(g)
    local mine = call(UnitFactionGroup, "player")
    local theirs = type(g) == "table" and value(g.factionName)
    return type(mine) == "string" and mine ~= "" and theirs == mine
end

local function scanBattleNet()
    if not (BNGetNumFriends and C_BattleNet and C_BattleNet.GetFriendAccountInfo) then return end
    for i = 1, tonumber(value(BNGetNumFriends())) or 0 do
        local a = C_BattleNet.GetFriendAccountInfo(i)
        local g = type(a) == "table" and a.gameAccountInfo
        if type(g) == "table" and value(g.isOnline) and g.clientProgram == (BNET_CLIENT_WOW or "WoW")
            and (not WOW_PROJECT_ID or g.wowProjectID == WOW_PROJECT_ID) and sameFaction(g) then
            local full = Full(g.characterName, g.realmName)
            if full and not isMe(full) then
                addFriend(full, g.characterLevel, g.areaName, g.className, {bn = g.gameAccountID})
            end
        end
    end
end

local function scan()
    local before = {}
    for full in pairs(friends) do before[full] = true end
    wipe(roster)
    wipe(friends)
    for _, fn in ipairs({scanGuild, scanFriends, scanBattleNet}) do pcall(fn) end
    -- A friend just online gets a hello, to learn whether they use it too.
    if wantZones() or wantShare() then
        for full in pairs(friends) do
            if not before[full] then toFriend(full, "H1") end
        end
    end
end
friendsMod.Scan = scan

local function askRosters()
    if IsInGuild and IsInGuild() then
        if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster)
        elseif GuildRoster then pcall(GuildRoster) end
    end
    if C_FriendList and C_FriendList.ShowFriends then pcall(C_FriendList.ShowFriends) end
end

-- =========================================================
-- Receiving
-- =========================================================
local function heard(full, text, guild)
    local kind, m, x, y, class, level = split(text)
    if friends[full] then known[full] = true end
    if kind == "H1" or kind == "H2" then
        if kind == "H1" and friends[full] then
            toFriend(full, sharing and wantShare() and last.text or "H2")
        end
        return
    end
    if not guild and not friends[full] then return end   -- a whisper only from a friend
    if kind == "L0" then
        live[full] = nil
    elseif kind == "L1" then
        m, x, y = tonumber(m), tonumber(x), tonumber(y)
        if not (m and x and y) or x < 0 or x > 1 or y < 0 or y > 1 then return end
        local row = roster[full]
        live[full] = {map = m, x = x, y = y, class = class and class:match("^%u+$"),
            level = tonumber(level), guild = guild or (row and row.guild) or false, at = now()}
    end
end
friendsMod.Heard = heard

local function onAddonMessage(prefix, text, channel, from)
    if prefix ~= PREFIX then return end
    if secret(text) or secret(from) or secret(channel) or type(text) ~= "string" then return end
    if channel ~= "GUILD" and channel ~= "WHISPER" then return end
    local full = Full(from)
    if not full or isMe(full) then return end
    heard(full, text, channel == "GUILD")
end

local function onBattleNetMessage(prefix, text, _, id)
    if prefix ~= PREFIX then return end
    if secret(text) or secret(id) or type(text) ~= "string" or type(id) ~= "number" then return end
    local g = C_BattleNet and C_BattleNet.GetGameAccountInfoByID and C_BattleNet.GetGameAccountInfoByID(id)
    local full = type(g) == "table" and Full(g.characterName, g.realmName)
    if not full or isMe(full) or not sameFaction(g) then return end
    friends[full] = friends[full] or {bn = id}
    heard(full, text, false)
end

-- =========================================================
-- On the map
-- =========================================================
-- x, y of a point on map `from` as seen on map `to` (nil if not on it).
local function project(from, x, y, to)
    if from == to then return x, y end
    if not (C_Map and C_Map.GetMapRectOnMap) then return nil end
    local ok, left, right, top, bottom = pcall(C_Map.GetMapRectOnMap, from, to)
    if not ok or type(left) ~= "number" or right == left or bottom == top then return nil end
    local px, py = left + x * (right - left), top + y * (bottom - top)
    if px < 0 or px > 1 or py < 0 or py > 1 then return nil end
    return px, py
end

local function pin(pool, index, size, parent)
    local canvas = parent or (WalkMapCore and WalkMapCore.canvas)
    local p = pool[index]
    if not p then
        p = CreateFrame("Frame", nil, canvas)
        p:SetFrameLevel((canvas:GetFrameLevel() or 1) + (parent and 20 or 4))
        p:EnableMouse(true)
        if p.EnableGamePadButton then p:EnableGamePadButton(false) end
        p.texture = p:CreateTexture(nil, "OVERLAY")
        p.texture:SetAllPoints(p)
        p:SetScript("OnEnter", function(self)
            if not GameTooltip or not self.lines then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            for i, line in ipairs(self.lines) do
                if line.right then
                    GameTooltip:AddDoubleLine(line.text, line.right, line.r, line.g, line.b, 0.6, 0.8, 1)
                elseif i == 1 then
                    GameTooltip:SetText(line.text, line.r or 1, line.g or 0.82, line.b or 0)
                else
                    GameTooltip:AddLine(line.text, line.r or 1, line.g or 1, line.b or 1)
                end
            end
            GameTooltip:Show()
        end)
        p:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        pool[index] = p
    end
    p:SetSize(size, size)
    return p
end

local function place(p, x, y)
    local canvas = WalkMapCore.canvas
    p.mapPercentX, p.mapPercentY = x, y
    p:ClearAllPoints()
    p:SetPoint("CENTER", canvas, "TOPLEFT", x * canvas:GetWidth(), -y * canvas:GetHeight())
    p:Show()
end

-- The zone you are looking at gets its badge in the map's top-right corner
-- (not in the middle of the map, under everything else).
local herePins = {}

local function hideAll()
    for _, p in ipairs(herePins) do p:Hide() end
    for _, p in ipairs(zonePins) do p:Hide() end
    for _, p in ipairs(dotPins) do p:Hide() end
end
friendsMod.Hide = hideAll

local function tag(guild) return guild and "Guild" or "Friend" end

function friendsMod.Refresh(mapID)
    currentMapShown = mapID
    if not (WalkMapCore and WalkMapCore.canvas) or type(mapID) ~= "number" then hideAll() return end
    local t = now()
    for full, p in pairs(live) do
        if t - p.at > GONE_AFTER then live[full] = nil end
    end
    -- Dots: those sharing (not your party/raid: they have WalkMap's own dots).
    local dots, placed = 0, {}
    if wantShare() then
        for full, p in pairs(live) do
            local x, y = project(p.map, p.x, p.y, mapID)
            if x and not inGroup(full) then
                dots = dots + 1
                local d = pin(dotPins, dots, 12)
                look(d.texture, "WhiteCircle-RaidBlips", "Interface\\Minimap\\PartyRaidBlips")
                local r, g, b = classColor(p.class or (roster[full] and roster[full].class))
                d.texture:SetVertexColor(r, g, b, 1)
                local lines = {{text = Shown(full), r = r, g = g, b = b}}
                if p.level and p.level > 0 then lines[#lines + 1] = {text = "Level " .. p.level} end
                lines[#lines + 1] = {text = tag(p.guild), r = 0.6, g = 0.8, b = 1}
                local ago = t - p.at
                if ago >= 20 then lines[#lines + 1] = {text = ("Updated %d s ago"):format(ago), r = 0.6, g = 0.6, b = 0.6} end
                d.lines, d.pinName = lines, Shown(full)
                place(d, x, y)
                placed[full] = true
            end
        end
    end
    for i = dots + 1, #dotPins do dotPins[i]:Hide() end
    -- Zone badges: everyone online by zone, as the game's lists give it.
    local zones, order = {}, {}
    if wantZones() then
        for full, r in pairs(roster) do
            local wanted = (r.guild and WalkMapExtras.GuildOnMap()) or (r.friend and WalkMapExtras.FriendsOnMap())
            local zone = wanted and not placed[full] and not inGroup(full)
                and WalkMapMaps and WalkMapMaps.IdByName(r.area)
            if zone then
                if not zones[zone] then zones[zone] = {}; order[#order + 1] = zone end
                table.insert(zones[zone], r)
            end
        end
    end
    local badges, hereShown = 0, false
    for _, zone in ipairs(order) do
        local x, y = project(zone, 0.5, 0.5, mapID)
        if x then
            local here = zone == mapID and WalkMapCore.viewport
            local b
            if here then
                b = pin(herePins, 1, 22, WalkMapCore.viewport)
                hereShown = true
            else
                badges = badges + 1
                b = pin(zonePins, badges, 20)
            end
            look(b.texture, "socialqueuing-icon-group", "Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon")
            b.texture:SetVertexColor(1, 1, 1, 1)
            local people = zones[zone]
            table.sort(people, function(a, c) return a.name < c.name end)
            local info = C_Map.GetMapInfo and C_Map.GetMapInfo(zone)
            local lines = {{text = (info and info.name or "?") .. " (" .. #people .. ")"}}
            for i, r in ipairs(people) do
                if i > LIST_MAX then
                    lines[#lines + 1] = {text = ("... and %d more"):format(#people - LIST_MAX), r = 0.6, g = 0.6, b = 0.6}
                    break
                end
                local cr, cg, cb = classColor(r.class)
                lines[#lines + 1] = {text = r.level and r.level > 0 and ("%s  %d"):format(r.name, r.level) or r.name,
                    right = tag(r.guild), r = cr, g = cg, b = cb}
            end
            b.lines, b.pinName = lines, lines[1].text
            if here then
                if not b.count then
                    b.count = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    b.count:SetPoint("RIGHT", b, "LEFT", -2, 0)
                end
                b.count:SetText(#people)
                b.mapPercentX, b.mapPercentY = nil, nil
                b:ClearAllPoints()
                b:SetPoint("TOPRIGHT", WalkMapCore.viewport, "TOPRIGHT", -8, -8)
                b:Show()
            else
                place(b, x, y)
            end
        end
    end
    for i = badges + 1, #zonePins do zonePins[i]:Hide() end
    if not hereShown and herePins[1] then herePins[1]:Hide() end
end

function friendsMod.Reposition()
    local canvas = WalkMapCore and WalkMapCore.canvas
    if not canvas then return end
    for _, pool in ipairs({zonePins, dotPins}) do
        for _, p in ipairs(pool) do
            if p:IsShown() and p.mapPercentX then
                p:ClearAllPoints()
                p:SetPoint("CENTER", canvas, "TOPLEFT", p.mapPercentX * canvas:GetWidth(),
                    -p.mapPercentY * canvas:GetHeight())
            end
        end
    end
end

-- Controller browsing (WalkMap.lua visiblePins).
function friendsMod.Pins()
    local list = {}
    for _, pool in ipairs({dotPins, zonePins, herePins}) do
        for _, p in ipairs(pool) do list[#list + 1] = p end
    end
    return list
end

function friendsMod.SettingChanged(field)
    if field == "shareLocation" and not wantShare() then stopSharing() end
    if field == "shareLocation" and wantShare() then last.at = -math.huge; tick() end
    if wantZones() or wantShare() then askRosters() end
    if currentMapShown then friendsMod.Refresh(currentMapShown) end
end

function friendsMod.Status()
    local online, sharingNow = 0, 0
    for _ in pairs(roster) do online = online + 1 end
    for _ in pairs(live) do sharingNow = sharingNow + 1 end
    return ("friends/guild online %d, sharing %d, my sharing %s"):format(online, sharingNow,
        wantShare() and (sharing and "on (sent)" or "on") or "off")
end

-- Test hooks.
friendsMod.Live, friendsMod.Roster, friendsMod.Known = live, roster, known

-- =========================================================
-- Events
-- =========================================================
local events = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_LOGIN", "GUILD_ROSTER_UPDATE", "FRIENDLIST_UPDATE",
    "BN_FRIEND_INFO_CHANGED", "BN_FRIEND_ACCOUNT_ONLINE", "BN_FRIEND_ACCOUNT_OFFLINE",
    "CHAT_MSG_ADDON", "BN_CHAT_MSG_ADDON", "PLAYER_ENTERING_WORLD"}) do
    pcall(events.RegisterEvent, events, event)
end
local scanQueued = false
local function queueScan()
    if scanQueued then return end
    scanQueued = true
    local function run()
        scanQueued = false
        scan()
    end
    if C_Timer and C_Timer.After then C_Timer.After(1, run) else run() end
end
events:SetScript("OnEvent", function(_, event, ...)
    if event == "CHAT_MSG_ADDON" then
        onAddonMessage(...)
    elseif event == "BN_CHAT_MSG_ADDON" then
        onBattleNetMessage(...)
    elseif event == "PLAYER_LOGIN" then
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
        end
        askRosters()
        queueScan()
        if C_Timer and C_Timer.NewTicker then
            C_Timer.NewTicker(TICK, function() pcall(tick) end)
            -- The guild roster only updates when asked: every 30 s while
            -- something here is on.
            C_Timer.NewTicker(30, function()
                if wantZones() or wantShare() then askRosters() end
            end)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Into an instance: stop at once (tick also checks).
        if wantShare() then pcall(tick) end
    else
        queueScan()
    end
end)
