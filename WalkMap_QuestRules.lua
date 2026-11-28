-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- Character-dependent quest requirements. No Questie code or data is bundled.
-- A missing/restricted client API leaves that requirement unknown, not failed.
WalkMapQuestRules = {}
local rules = WalkMapQuestRules
local skillRanks, skillsComplete, spellCache, reputationCache, policyCache

function rules.Refresh()
    skillRanks, skillsComplete = nil, false
    spellCache, reputationCache = {}, {}
    policyCache = nil
end
rules.Refresh()

local function spellKnown(id)
    if spellCache[id] ~= nil then return spellCache[id] end
    local fn = C_SpellBook and C_SpellBook.IsSpellKnown or IsPlayerSpell or IsSpellKnown
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, id)
    if ok and type(value) == "boolean" then
        spellCache[id] = value
        return value
    end
end

local function readSkills()
    if skillRanks then return end
    skillRanks = {}
    if C_SkillInfo and C_SkillInfo.GetNumSkillLines and C_SkillInfo.GetSkillLineInfo then
        local ok, count = pcall(C_SkillInfo.GetNumSkillLines)
        if not ok or type(count) ~= "number" or count <= 0 then return end
        skillsComplete = true
        for index = 1, count do
            local success, info = pcall(C_SkillInfo.GetSkillLineInfo, index)
            if not success or type(info) ~= "table" then
                skillsComplete = false
            elseif info.isHeader then
                -- Do not expand or change the game's professions UI to read it.
                if info.isCollapsed then skillsComplete = false end
            elseif type(info.skillID) == "number" and type(info.rank) == "number" then
                skillRanks[info.skillID] = info.rank
            else
                skillsComplete = false
            end
        end
    elseif GetProfessions and GetProfessionInfo then
        local found = {pcall(GetProfessions)}
        if not found[1] then return end
        skillsComplete = true
        for _, index in pairs(found) do
            if type(index) == "number" then
                local info = {pcall(GetProfessionInfo, index)}
                if info[1] and type(info[8]) == "number" and type(info[4]) == "number" then
                    skillRanks[info[8]] = info[4]
                else
                    skillsComplete = false
                end
            end
        end
    end
end

local function hasSkill(requirement)
    if type(requirement) ~= "table" or type(requirement[1]) ~= "number"
        or requirement[1] <= 0 then return true end
    readSkills()
    local rank = skillRanks[requirement[1]]
    if rank == nil then return not skillsComplete end
    return rank >= (tonumber(requirement[2]) or 1)
end

local function reputation(factionID)
    if reputationCache[factionID] ~= nil then return reputationCache[factionID] or nil end
    local value
    if C_Reputation and C_Reputation.GetFactionDataByID then
        local ok, info = pcall(C_Reputation.GetFactionDataByID, factionID)
        if ok and type(info) == "table" then value = info.currentStanding end
    elseif GetFactionInfoByID then
        local ok, _, _, _, _, _, standing = pcall(GetFactionInfoByID, factionID)
        if ok then value = standing end
    end
    if type(value) ~= "number" then value = nil end
    reputationCache[factionID] = value or false
    return value
end

local function repAllows(pair, maximum)
    if type(pair) ~= "table" or type(pair[1]) ~= "number"
        or type(pair[2]) ~= "number" then return true end
    local standing = reputation(pair[1])
    if standing == nil then return true end
    if maximum then return standing < pair[2] end
    return standing >= pair[2]
end

local function specializationAllows(id)
    if type(id) ~= "number" or id <= 0 then return true end
    local enums = LibQuestieDB and LibQuestieDB.Enum
    local name
    for key, value in pairs(enums and enums.professionKeys or {}) do
        if value == id then name = key break end
    end
    if not name then return spellKnown(id) ~= false end
    if not hasSkill({id, 1}) then return false end
    -- A profession ID means no specialization in that profession yet.
    for key, spell in pairs(enums and enums.specializationKeys or {}) do
        if key:sub(1, #name + 1) == name .. "_" and spellKnown(spell) == true then
            return false
        end
    end
    return true
end

local function loadedPolicy()
    if policyCache ~= nil then return policyCache or nil end
    policyCache = false
    if not (Questie and Questie.db and Questie.db.char and QuestieLoader
        and type(QuestieLoader.ImportModule) == "function") then return nil end
    local ok, policy = pcall(QuestieLoader.ImportModule, QuestieLoader, "QuestieCorrections")
    if ok and type(policy) == "table" and type(policy.hiddenQuests) == "table" then
        policyCache = policy.hiddenQuests
        return policyCache
    end
end

-- Questie's live list when Questie is loaded (it also knows active events);
-- otherwise WalkMap's static copy evaluated for Forever.
local function hiddenList()
    local live = loadedPolicy()
    if live then return live, "Questie blacklist" end
    if type(WalkMapQuestBlacklist) == "table" then return WalkMapQuestBlacklist, "WalkMap copy of Questie blacklist" end
end

function rules.PolicyStatus()
    if loadedPolicy() then return "QuestieDB + loaded Questie blacklist" end
    if type(WalkMapQuestBlacklist) == "table" then
        return "QuestieDB + WalkMap's static copy of Questie's blacklist (Questie 12.16.0)"
    end
    return "QuestieDB only; Questie's separate blacklist is unavailable"
end

function rules.Allows(id, quest, completed, inLog)
    local hidden, reason = hiddenList()
    if hidden and hidden[id] then return false, reason end
    for _, other in pairs(quest.exclusive or {}) do
        if completed(other) or inLog(other) then return false, "exclusive quest" end
    end
    if quest.disabledBy and inLog(quest.disabledBy) then return false, "disabling quest" end
    if quest.breadcrumbFor and (completed(quest.breadcrumbFor) or inLog(quest.breadcrumbFor)) then
        return false, "breadcrumb destination" end
    for _, breadcrumb in ipairs(quest.breadcrumbs or {}) do
        if inLog(breadcrumb) then return false, "active breadcrumb" end
    end
    if not hasSkill(quest.skill) then return false, "profession requirement" end
    if not repAllows(quest.minRep, false) or not repAllows(quest.maxRep, true) then
        return false, "reputation requirement" end
    local spell = quest.spell
    if type(spell) == "number" and spell ~= 0 then
        local known = spellKnown(math.abs(spell))
        if spell > 0 and known == false or spell < 0 and known == true then
            return false, "spell requirement"
        end
    end
    if not specializationAllows(quest.specialization) then
        return false, "specialization requirement" end
    return true
end
