-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- Bag sorting and vendor tools, adapted from Underbuks' SortPants.
-- Keep these controls independent of map profiles and gamepad navigation.
WalkMapBags = {}
local bags = WalkMapBags
local settings = WalkMapCharacterSettings
local driver = CreateFrame("Frame")
local merchantOpen, queue, nextItem, elapsed = false, nil, 1, 0
local attempted, announced, conflictAnnounced = 0, false, false
local lastResult = "idle"
local previousBindings = {}
local action = "WALKMAP_SORT_BAGS"
local lastAutoSell = settings.autoSellJunk

local function say(message)
    print("|cff80ff80WalkMap:|r " .. message)
end

local function restricted()
    if InCombatLockdown and InCombatLockdown() then return true end
    if C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive
        and Enum and Enum.AddOnRestrictionType then
        local ok, active = pcall(C_RestrictedActions.IsAddOnRestrictionActive,
            Enum.AddOnRestrictionType.Combat)
        if not ok or active then return true end
    end
    return false
end

local function separateAddonLoaded()
    local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if type(isLoaded) == "function" then
        local ok, loaded = pcall(isLoaded, "SortPants")
        if ok and loaded then return true end
    end
    return type(SortPants_SortBags) == "function"
end

local function stopSelling(reason)
    queue = nil
    driver:SetScript("OnUpdate", nil)
    lastResult = reason or "idle"
end

local function vendorAvailable()
    return merchantOpen and (not MerchantFrame or MerchantFrame:IsShown())
        and (not MerchantFrame or MerchantFrame.selectedTab ~= 2)
end

local function eligibleItem(bag, slot)
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if not info or info.quality ~= 0 or info.isLocked or info.hasNoValue
        or info.isQuestItem or not info.itemID then return nil end
    if C_Container.GetContainerItemQuestInfo then
        local ok, quest = pcall(C_Container.GetContainerItemQuestInfo, bag, slot)
        if not ok or (quest and quest.isQuestItem) then return nil end
    end
    return info
end

local function sellBatch(_, delta)
    if not settings.autoSellJunk or not vendorAvailable() or restricted()
        or separateAddonLoaded() then
        stopSelling("stopped: vendor closed, option disabled, restriction or SortPants")
        return
    end
    elapsed = elapsed + delta
    if elapsed < 0.15 then return end
    elapsed = 0
    for _ = 1, 3 do
        local item = queue and queue[nextItem]
        if not item then
            stopSelling("finished: " .. attempted .. " gray stacks attempted")
            return
        end
        nextItem = nextItem + 1
        -- Bags may have changed since MERCHANT_SHOW. Never trust a queued slot.
        local ok, info = pcall(eligibleItem, item.bag, item.slot)
        if ok and info and info.itemID == item.id then
            local used, message = pcall(C_Container.UseContainerItem, item.bag, item.slot)
            if not used then
                stopSelling("stopped: " .. tostring(message))
                say("Auto-sell stopped because the game rejected an item action.")
                return
            end
            attempted = attempted + 1
            if settings.vendorMessages and not announced then
                announced = true
                say("Auto-selling gray-quality items.")
            end
            -- An item action can close the merchant or change an option.
            if not queue or not settings.autoSellJunk or not vendorAvailable()
                or restricted() or separateAddonLoaded() then
                stopSelling("stopped during vendor action")
                return
            end
        end
    end
end

local function startSelling()
    stopSelling()
    -- MERCHANT_SHOW can reach us before Blizzard's handler shows its frame.
    -- Queue from the event; verify the visible vendor again before every sale.
    if not settings.autoSellJunk or not merchantOpen or restricted()
        or separateAddonLoaded() then return end
    if not C_Container or not C_Container.GetContainerNumSlots
        or not C_Container.GetContainerItemInfo or not C_Container.UseContainerItem then
        lastResult = "container API unavailable"
        say("The game's container API is unavailable; auto-sell cannot run.")
        return
    end
    local pending = {}
    -- Backpack and equipped bags only; never bank or buyback slots.
    for bag = 0, 4 do
        local ok, slots = pcall(C_Container.GetContainerNumSlots, bag)
        if ok and type(slots) == "number" then
            for slot = 1, slots do
                local read, info = pcall(eligibleItem, bag, slot)
                if read and info then
                    pending[#pending + 1] = {bag = bag, slot = slot, id = info.itemID}
                end
            end
        end
    end
    if #pending == 0 then lastResult = "no sellable gray items" return end
    queue, nextItem, elapsed, attempted, announced = pending, 1, 0, 0, false
    lastResult = "selling gray items"
    driver:SetScript("OnUpdate", sellBatch)
end

function bags.SettingsChanged()
    if not settings.autoSellJunk then
        stopSelling("auto-sell off")
    elseif not lastAutoSell then
        startSelling()
    end
    lastAutoSell = settings.autoSellJunk
end

function bags.Status()
    if separateAddonLoaded() then
        return "Separate SortPants is active. Disable it in AddOns to let WalkMap control auto-sell."
    end
    if queue then return "Auto-selling gray items at the open vendor." end
    if not settings.autoSellJunk then return "WalkMap auto-sell is off." end
    return "Auto-sell ready: gray-quality items only, when a vendor opens."
end

function bags.Diagnostics()
    return bags.Status() .. " Last operation: " .. lastResult
end

function bags.Sort()
    if not settings.bagSortEnabled then
        say("Bag sorting is disabled in Settings > Bags & vendors.")
        return false
    end
    if restricted() then say("Wait until you are out of combat to sort bags.") return false end
    if queue then say("Wait for auto-sell to finish before sorting bags.") return false end
    if not C_Container or type(C_Container.SortBags) ~= "function" then
        say("The game's SortBags API is unavailable.")
        return false
    end
    local ok, message = pcall(C_Container.SortBags)
    if ok then
        lastResult = "sort requested"
    else
        lastResult = "sort failed: " .. tostring(message)
        say("The game could not sort your bags.")
    end
    return ok
end

local function saveBindings()
    if not SaveBindings or not GetCurrentBindingSet then return false end
    local ok, result = pcall(function() return SaveBindings(GetCurrentBindingSet()) end)
    return ok and result ~= false
end

function bags.BindingLabel()
    if GetBindingKey then
        local ok, key = pcall(GetBindingKey, action)
        if ok and key then return key end
    end
    return "Not bound"
end

function bags.BindingHelp()
    say("Use Key Bindings > WalkMap > Sort bags. Current shortcut: " .. bags.BindingLabel() .. ".")
    say("Or type /walkmap sort bind KEY. /walkmap sort unbind restores changes from this login.")
end

function bags.Bind(key)
    if restricted() then say("Wait until you are out of combat to change bindings.") return false end
    if not key or key == "" then bags.BindingHelp() return false end
    key = key:upper()
    if not SetBinding or not GetBindingAction then say("Key binding API unavailable.") return false end
    local old = GetBindingAction(key) or ""
    local ok, result = pcall(SetBinding, key, action)
    if not ok or not result then say("Could not bind " .. key .. ".") return false end
    if previousBindings[key] == nil then previousBindings[key] = old end
    local saved = saveBindings()
    say(key .. " now sorts bags" .. (saved and " (saved)." or " for this login; the binding could not be saved."))
    if old ~= "" and old ~= action then say("Previous binding: " .. old .. ".") end
    return true
end

function bags.RestoreBindings()
    if restricted() then say("Wait until you are out of combat to change bindings.") return false end
    local changed, failed = false, 0
    for key, old in pairs(previousBindings) do
        -- Keep any later edits the player made in the game's binding menu.
        if GetBindingAction(key) ~= action then
            previousBindings[key] = nil
        else
            local ok, result = pcall(SetBinding, key, old ~= "" and old or nil)
            if ok and result then previousBindings[key], changed = nil, true
            else failed = failed + 1 end
        end
    end
    local saved = not changed or saveBindings()
    if failed > 0 then
        say("Some sort bindings could not be restored. Try /walkmap sort unbind again outside combat.")
        return false
    end
    say(saved and "Sort bindings changed during this login restored."
        or "Sort bindings restored for this login; saving failed.")
    return saved
end

function bags.Command(message)
    local command, key = (message or ""):match("^%s*(%S*)%s*(%S*)")
    command = command:lower()
    if command == "" then bags.Sort()
    elseif command == "bind" then bags.Bind(key)
    elseif command == "unbind" then bags.RestoreBindings()
    else bags.BindingHelp() end
end

BINDING_NAME_WALKMAP_SORT_BAGS = "Sort bags"
function WalkMap_SortBags() return bags.Sort() end
SLASH_WALKMAPSORT1 = "/wmsort"
SlashCmdList.WALKMAPSORT = bags.Command

driver:RegisterEvent("MERCHANT_SHOW")
driver:RegisterEvent("MERCHANT_CLOSED")
driver:RegisterEvent("PLAYER_REGEN_DISABLED")
driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("ADDON_LOADED")
driver:SetScript("OnEvent", function(_, event, addon)
    if event == "MERCHANT_SHOW" then
        merchantOpen = true
        startSelling()
    elseif event == "MERCHANT_CLOSED" then
        merchantOpen = false
        stopSelling("vendor closed")
    elseif event == "PLAYER_REGEN_DISABLED" then
        stopSelling("combat started")
    elseif event == "PLAYER_LOGIN" or (event == "ADDON_LOADED" and addon == "SortPants") then
        if separateAddonLoaded() then
            stopSelling("separate SortPants active")
            if not conflictAnnounced then
                conflictAnnounced = true
                say(bags.Status())
            end
        end
    end
end)
