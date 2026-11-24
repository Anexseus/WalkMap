-- Translations (WalkMap_Locale*.lua): English stays as it is, German and
-- French come from the language files, built texts are translated in parts.
local function boot(Mock, language)
    local env = Mock.new({playerMap = 1436, quests = {{header = "Westfall"}, {id = 101, title = "Westfall Stew", level = 13}}})
    env.loadAddon({welcomeSeen = true, newsSeen = "1.14.19", language = language}, {welcomeSeen = true})
    env.fire("ADDON_LOADED", "WalkMap")
    env.fire("PLAYER_LOGIN")
    env.fire("PLAYER_ENTERING_WORLD")
    env.tick(1, 5)
    return env
end

return {
    {"English: texts unchanged", function(Mock)
        local env = boot(Mock)
        Mock.eq(env.WalkMapL("Follow: On"), "Follow: On", "English")
        Mock.eq(env.WalkMapLocale.Code(), "enUS", "English in use")
    end},
    {"German: words, Label: value, patterns and colour codes", function(Mock)
        local env = boot(Mock, "deDE")
        local L = env.WalkMapL
        Mock.eq(env.WalkMapLocale.Code(), "deDE", "German in use")
        Mock.eq(L("Settings"), "Einstellungen", "a word")
        Mock.eq(L("Follow: On"), "Folgen: An", "Label: value")
        Mock.eq(L("Page 3/8"), "Seite 3/8", "pattern")
        Mock.eq(L("|cff80ff80WalkMap:|r Waypoint cleared."), "|cff80ff80WalkMap:|r Wegpunkt entfernt.", "chat line")
        Mock.eq(L("WalkMap - The Deadmines - Floor 2"), "WalkMap - Die Todesminen - Ebene 2", "map title")
        Mock.eq(L("Westfall Stew"), "Westfall Stew", "game names stay")
        Mock.eq(L("Quest 101"), "Quest 101", "numbers")
    end},
    {"French: its own colon", function(Mock)
        local env = boot(Mock, "frFR")
        Mock.eq(env.WalkMapL("Follow: On"), "Suivre : Activé", "Label : value")
        Mock.eq(env.WalkMapL("Settings"), "Réglages", "a word")
        Mock.eq(env.WalkMapL("Marker size: Normal"), "Taille des marqueurs : Normale", "feminine label")
        Mock.eq(env.WalkMapL("Auto-sell junk: On"), "Vente auto de la camelote : Activée", "feminine label")
        Mock.eq(env.WalkMapL("Quest icons: Off"), "Icônes de quête : Désactivées", "feminine plural")
        Mock.eq(env.WalkMapL("Marker distance: All"), "Portée des marqueurs : Toute la minicarte", "whole minimap")
        Mock.eq(env.WalkMapL("Quest tracker: Off"), "Suivi des quêtes : Désactivé", "masculine stays")
    end},
    {"German in use: map, every settings page and the zone menu, without errors", function(Mock)
        local env = boot(Mock, "deDE")
        env.WalkMap_Toggle()
        env.tick(0.5, 5)
        local x = env.WalkMapExtras
        local panel = x.SettingsPanel()
        for i = 1, #panel.categories do
            local row = panel.categories[i]
            if row and row:IsShown() then row:GetScript("OnClick")(row) end
        end
        Mock.ok(tostring(panel.categories[1].label:GetText()):find("Quests auf der Karte", 1, true), "category in German")
        x.OpenMapMenu(env.WalkMapCore.mapPickerButton)
        x.CloseMenus()
        Mock.ok(true, "no errors")
    end},
    {"Language setting: Auto, English, Deutsch, Français", function(Mock)
        local env = boot(Mock)
        env.WalkMapSettings.language = "frFR"
        env.WalkMapLocale.Apply()
        Mock.eq(env.WalkMapL("Settings"), "Réglages", "French chosen")
        env.WalkMapSettings.language = "enUS"
        env.WalkMapLocale.Apply()
        Mock.eq(env.WalkMapL("Settings"), "Settings", "English chosen")
    end},
    {"Changing the language redraws the open map at once", function(Mock)
        local env = boot(Mock)
        env.WalkMap_Toggle()
        env.tick(0.5, 5)
        local x = env.WalkMapExtras
        x.ShowSettingsPage("Look")
        local panel = x.SettingsPanel()
        local row
        for _, r in ipairs(panel.options) do
            if r:IsShown() and tostring(r.label:GetText()):find("^Language") then row = r end
        end
        while not row and panel.walkmapScroll(panel.walkmapScrollEdges.last, "down") do
            for _, r in ipairs(panel.options) do
                if r:IsShown() and tostring(r.label:GetText()):find("^Language") then row = r end
            end
        end
        Mock.ok(row, "Language row")
        row:GetScript("OnClick")(row) -- Auto -> English
        row:GetScript("OnClick")(row) -- English -> Deutsch
        Mock.eq(env.WalkMapLocale.Code(), "deDE", "German chosen")
        local titleFound, followFound = false, false
        local function scan(frame, depth)
            if depth > 8 then return end
            for _, child in ipairs(frame.__children or {}) do
                local text = child.GetText and child:GetText()
                if type(text) == "string" then
                    if text == "WalkMap-Einstellungen" then titleFound = true end
                    if text:find("Folgen", 1, true) then followFound = true end
                end
                scan(child, depth + 1)
            end
        end
        scan(env.UIParent, 0)
        Mock.ok(followFound, "the map's Follow button is German right away")
        Mock.ok(titleFound == true, "the settings window's title is German right away")
    end},
}
