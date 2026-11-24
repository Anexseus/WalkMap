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
}
