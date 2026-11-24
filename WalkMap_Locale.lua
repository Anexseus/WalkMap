-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- Translations. Every text WalkMap shows goes through WalkMapL(text): the
-- English text is the key, so a missing translation simply shows English.
--
-- Each language file (WalkMap_Locale_deDE.lua, ...) calls
-- WalkMapLocale.Add(code, strings, patterns):
--   strings:  ["English text"] = "translation"
--   patterns: ["Follow: %s"] = "Folgen: %s" - %s stands for any text, which
--             is translated in turn ("On" -> "An"); a translation may use
--             %1, %2 to put the parts in another order.
-- %d stands for a number only.
-- Lines ("\n"), colour codes around a text and "Label: value" are split and
-- translated part by part, so most built texts need no pattern of their own.
-- The debug report stays in English (it is for the authors).
WalkMapLocale = {}
local locale = WalkMapLocale

local languages = {}       -- code -> {strings, patterns (compiled)}
local active = nil         -- the language in use, or nil for English
local activeCode = "enUS"
local cache, cacheSize = {}, 0
local misses = nil         -- table while collecting untranslated texts (tests)

local NAMES = {enUS = "English", deDE = "Deutsch", frFR = "Français"}
locale.NAMES = NAMES
locale.ORDER = {"auto", "enUS", "deDE", "frFR"}

local function compile(source)
    -- "Follow: %s" -> "^Follow: (.-)$"
    local count = 0
    local pattern = source:gsub("([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
    pattern = pattern:gsub("%%([sd])", function(kind)
        count = count + 1
        return kind == "d" and "(%d+)" or "(.-)"
    end)
    return "^" .. pattern .. "$", count
end

-- options.colon: how "Label: value" is written (French: " : ").
function locale.Add(code, strings, patterns, options)
    local entry = languages[code] or {strings = {}, patterns = {}}
    languages[code] = entry
    entry.colon = options and options.colon or entry.colon or ": "
    -- options.agree: {["translated label"] = {["value"] = "agreeing value"}}
    -- for languages whose values follow the label (French "Taille : Normale").
    entry.agree = options and options.agree or entry.agree
    for key, value in pairs(strings or {}) do entry.strings[key] = value end
    for key, value in pairs(patterns or {}) do
        local pattern, count = compile(key)
        entry.patterns[#entry.patterns + 1] = {pattern = pattern, value = value, count = count,
            fixed = #key - 2 * count, key = key}
    end
    -- Most specific first: the longest fixed text wins.
    table.sort(entry.patterns, function(a, b)
        if a.fixed ~= b.fixed then return a.fixed > b.fixed end
        return a.key < b.key
    end)
    if code == activeCode then active = entry end
end

local lookup

local function fill(value, captures, count)
    if value:find("%%%d") then
        return (value:gsub("%%(%d)", function(index)
            local capture = captures[tonumber(index)]
            return capture and lookup(capture) or ""
        end))
    end
    local index = 0
    return (value:gsub("%%s", function()
        index = index + 1
        local capture = captures[index]
        return capture and lookup(capture) or ""
    end))
end

lookup = function(text)
    if text == "" or not text:find("%a") then return text end
    local exact = active.strings[text]
    if exact then return exact end
    -- Line by line.
    if text:find("\n", 1, true) then
        local out = {}
        for line in (text .. "\n"):gmatch("(.-)\n") do out[#out + 1] = lookup(line) end
        return table.concat(out, "\n")
    end
    -- Colour code around the whole text.
    local prefix, inner, suffix = text:match("^(|c%x%x%x%x%x%x%x%x)(.-)(|r)$")
    if prefix and not inner:find("|r", 1, true) then return prefix .. lookup(inner) .. suffix end
    -- Leading or trailing spaces.
    local lead, body, trail = text:match("^(%s+)(.-)(%s*)$")
    if lead then return lead .. lookup(body) .. trail end
    lead, body, trail = text:match("^(.-)(%s+)$")
    if lead then return lookup(lead) .. body end
    for _, entry in ipairs(active.patterns) do
        local captures = {text:match(entry.pattern)}
        if entry.count == 0 and captures[1] ~= nil then return entry.value end
        if captures[1] ~= nil and #captures == entry.count then
            return fill(entry.value, captures, entry.count)
        end
    end
    -- "Label: value"
    local label, value = text:match("^([^:|]-): (.+)$")
    if label and label ~= "" then
        local left = active.strings[label]
        if left then
            local translated = lookup(value)
            local forms = active.agree and active.agree[left]
            return left .. active.colon .. (forms and forms[translated] or translated)
        end
    end
    -- "Text (detail)"
    local main, detail = text:match("^(.-) (%b())$")
    if main and main ~= "" and active.strings[main] then
        return active.strings[main] .. " (" .. lookup(detail:sub(2, -2)) .. ")"
    end
    if misses then misses[text] = true end
    return text
end

-- The translation of text in the language in use (English: text itself).
function WalkMapL(text)
    if not active or type(text) ~= "string" then return text end
    local hit = cache[text]
    if hit then return hit end
    local out = lookup(text)
    if cacheSize > 4000 then cache, cacheSize = {}, 0 end
    cache[text] = out
    cacheSize = cacheSize + 1
    return out
end

-- The game's language, or the one chosen under Settings.
local forced = nil  -- tests
local function wanted()
    if forced then return forced end
    local chosen = type(WalkMapSettings) == "table" and WalkMapSettings.language
    if chosen and chosen ~= "auto" and NAMES[chosen] then return chosen end
    local ok, game = pcall(GetLocale)
    return ok and game or "enUS"
end

-- Fixed texts (labels, titles) remember their English text, so a language
-- change shows at once; locale.OnChange functions redraw everything else.
local statics = setmetatable({}, {__mode = "k"})
local listeners = {}
function locale.Static(fontString, text)
    if not fontString or not fontString.SetText then return end
    statics[fontString] = text
    fontString:SetText(WalkMapL(text))
end
function locale.OnChange(fn) listeners[#listeners + 1] = fn end

function locale.Apply(code)
    local before = active
    activeCode = code or wanted()
    active = languages[activeCode]
    cache, cacheSize = {}, 0
    if before == active then return end
    for fontString, text in pairs(statics) do pcall(fontString.SetText, fontString, WalkMapL(text)) end
    for _, fn in ipairs(listeners) do pcall(fn) end
end

function locale.Force(code) forced = code locale.Apply() end

function locale.Code() return active and activeCode or "enUS" end
function locale.Name(code) return NAMES[code or locale.Code()] or "English" end
function locale.Has(code) return code == "enUS" or languages[code] ~= nil end

-- Tests: collect texts that found no translation.
function locale.CollectMisses(on) misses = type(on) == "table" and on or (on and {} or nil) end
function locale.Misses() return misses end

-- Saved settings arrive with ADDON_LOADED; the game's language is known
-- from the start.
locale.Apply()
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, _, name)
    if name ~= "WalkMap" then return end
    locale.Apply()
    self:UnregisterEvent("ADDON_LOADED")
end)
