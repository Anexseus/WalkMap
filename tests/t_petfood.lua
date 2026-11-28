-- Places > Pet food (hunters): vendors that sell food the pet eats, from
-- QuestieDB's pet food data and each item's vendors.
local function setup(Mock, class)
    local env = Mock.new({playerMap = 1436})
    env.UnitClass = function() return "Hunter", class or "HUNTER" end
    local function entity(rows)
        return {
            GetByIndex = function(id, field) return rows[id] and rows[id][field] end,
            Get = function(id, key) return rows[id] and rows[id][key] end,
            Exists = function(id) return rows[id] ~= nil end,
            GetAllIds = function()
                local ids = {}
                for id in pairs(rows) do ids[#ids + 1] = id end
                table.sort(ids)
                return ids
            end,
        }
    end
    env.LibQuestieDB = {
        RequireContract = function() return true end,
        Npc = entity({
            [1000] = {[1] = "Innkeeper Farley", [7] = {[40] = {{52.5, 53.1}}}, [13] = "A"},
            [1001] = {[1] = "Fishmonger", [7] = {[40] = {{30.0, 40.0}}}, [13] = "H"},
            -- A giver and a flight master, so the QuestieDB read counts as ready.
            [234] = {[1] = "Gryan Stoutmantle", [7] = {[40] = {{56.3, 47.5}}}, [10] = {12},
                [13] = "A", [14] = "", [15] = 2},
            [523] = {[1] = "Thor", [7] = {[40] = {{56.6, 52.6}}}, [13] = "A", [14] = "Gryphon Master", [15] = 8},
        }),
        Object = entity({}),
        Quest = entity({[12] = {[1] = "The People's Militia", [3] = {{234}}, [4] = 9, [5] = 12}}),
        Item = entity({
            [117] = {[1] = "Tough Jerky", name = "Tough Jerky", itemLevel = 5, requiredLevel = 1, vendors = {1000}},
            [2287] = {[1] = "Haunch of Meat", name = "Haunch of Meat", itemLevel = 15, requiredLevel = 5, vendors = {1000}},
            [3770] = {[1] = "Mutton Chop", name = "Mutton Chop", itemLevel = 25, requiredLevel = 15, vendors = {1000}},
            [787] = {[1] = "Slitherskin Mackerel", name = "Slitherskin Mackerel", itemLevel = 5, requiredLevel = 1, vendors = {1001}},
        }),
        Support = {Get = function(name)
            if name == "ZoneDB" then return {private = {uiMapIdToAreaId = "return { [1436] = 40, }"}} end
            if name == "PetFood" then
                return {itemIdsByFoodType = {[1] = {117, 2287, 3770}, [2] = {787}},
                    foodTypesByFamily = {[1] = {1}}, foodTypesByName = {Meat = 1, Fish = 2}}
            end
        end},
    }
    env.load("WalkMap_Data.lua")
    env.load("WalkMap_LiveDB.lua")
    env.tick(2, 40)
    return env
end

return {
    {"Vendors with food the pet eats and the player may buy", function(Mock)
        local env = setup(Mock)
        local live = env.WalkMapLiveDB
        Mock.eq((live.State()), "ready", tostring(live.Status()))
        Mock.ok(live.PetFoodData(), "QuestieDB has pet food data")
        local vendors = live.PetFoodVendors({1}, 10, 10)[1436]
        Mock.eq(#vendors, 1, "one meat vendor in Westfall")
        local farley = vendors[1]
        Mock.eq(farley[3], "Innkeeper Farley", "the vendor")
        Mock.eq(table.concat(farley[5], ", "), "Haunch of Meat, Tough Jerky", "foods for a level 10 player")
        local later = live.PetFoodVendors({1}, 40, 20)[1436][1]
        Mock.eq(table.concat(later[5], ", "), "Haunch of Meat, Mutton Chop",
            "a level 40 pet refuses Tough Jerky; Mutton Chop needs level 15")
        local both = live.PetFoodVendors({1, 2}, 10, 10)[1436]
        Mock.eq(#both, 2, "meat and fish vendors")
    end},
    {"Pet food is a place for hunters only", function(Mock)
        local hunter = setup(Mock)
        hunter.loadAddon({welcomeSeen = true, newsSeen = "1.14.22"}, {placeFilters = {petfood = true}})
        Mock.eq(hunter.WalkMapCharacterSettings.placeFilters.petfood, true, "kept for a hunter")
        local types = hunter.WalkMapExtras.PetFood()
        Mock.eq(#types, 6, "no pet known yet: all food")
        hunter.fire("PLAYER_LOGIN")
        hunter.fire("PLAYER_ENTERING_WORLD")
        hunter.tick(3, 60)
        hunter.WalkMapExtras.Refresh(1436)
        local services = hunter.WalkMapExtras.MiniMapPins()
        local farley
        for _, pin in ipairs(services) do
            if pin:IsShown() and pin.pinName == "Innkeeper Farley" then farley = pin end
        end
        Mock.ok(farley, "the vendor is on the map")
        Mock.ok(tostring(farley.detail):find("Pet food: ", 1, true), "its tooltip lists the food")
        local mage = setup(Mock, "MAGE")
        mage.loadAddon({welcomeSeen = true, newsSeen = "1.14.22"}, {placeFilters = {petfood = true}})
        Mock.eq(mage.WalkMapCharacterSettings.placeFilters.petfood, nil, "not for other classes")
    end},
}
