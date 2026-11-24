-- Translations (WalkMap_Locale*.lua): English stays as it is, German and
-- French come from the language files, built texts are translated in parts.
local function boot(Mock, language)
    local env = Mock.new({playerMap = 1436, quests = {{header = "Westfall"}, {id = 101, title = "Westfall Stew", level = 13}}})
    env.loadAddon({welcomeSeen = true, newsSeen = "1.14.20", language = language}, {welcomeSeen = true})
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
        Mock.eq(L("Marker distance: All"), "Reichweite der Markierungen: Gesamte Minimap", "whole minimap")
        Mock.eq(L("Marker distance: 75%"), "Reichweite der Markierungen: 75%", "a share")
        Mock.eq(L("Width: Custom (246)"), "Breite: Benutzerdefiniert (246)", "custom width")
        Mock.eq(L("Low-level quests: Quest chains"), "Niedrigstufige Quests: Questreihen", "low-level quests")
        Mock.eq(L("Fade while moving: 35% visible"), "Sichtbarkeit beim Bewegen: 35%", "fade")
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
        Mock.eq(env.WalkMapL("Width: Normal"), "Largeur : Normale", "feminine width")
        Mock.eq(env.WalkMapL("Low-level quests: Off"), "Quêtes de bas niveau : Désactivées", "feminine plural")
        Mock.eq(env.WalkMapL("chain to level 32"), "chaîne jusqu'au niveau 32", "chain note")
        Mock.eq(env.WalkMapL("Width: Custom (246)"), "Largeur : Personnalisée (246)", "custom width")
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
        x.ShowSettingsPage("Appearance")
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
        -- The footer's Buttons button grows for "Schaltflächen".
        local buttonsLabel
        local function find(frame, depth)
            if depth > 8 or buttonsLabel then return end
            for _, child in ipairs(frame.__children or {}) do
                if child.GetText and child:GetText() == "Schaltflächen" and child.__parent
                    and child.__parent.walkmapFitLabel then buttonsLabel = child end
                find(child, depth + 1)
            end
        end
        find(env.UIParent, 0)
        Mock.ok(buttonsLabel, "Buttons is Schaltflächen")
        Mock.ok(buttonsLabel:GetStringWidth() <= buttonsLabel.__parent:GetWidth() - 8, "and fits its button")
        Mock.ok(buttonsLabel.__parent:GetWidth() > 64, "the button grew")
    end},
}
