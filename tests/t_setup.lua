-- Setup guide (WalkMap_Setup.lua): shown once to a new player instead of
-- the welcome page; picks apply at Finish, on top of recommended settings.
local function newPlayer(Mock, account)
    local env = Mock.new({playerMap = 1436})
    env.loadAddon(account or {}, {})
    env.fire("PLAYER_LOGIN")
    env.fire("PLAYER_ENTERING_WORLD")
    env.tick(5, 20) -- the 4 s wait, then the map opens
    env.tick(0.5, 5)
    return env
end

local function cardNamed(env, text)
    local panel = env.WalkMapSetup.Panel()
    for _, child in ipairs(panel.__children or {}) do
        if child.value and child:IsShown() and child.title
            and tostring(child.title:GetText()):find(text, 1, true) then return child end
    end
end

local function lineNamed(env, text)
    local panel = env.WalkMapSetup.Panel()
    for _, child in ipairs(panel.__children or {}) do
        if child.key and child:IsShown() and tostring(child.label:GetText()):find(text, 1, true) then return child end
    end
end

local function click(button) button:GetScript("OnClick")(button, "LeftButton") end

local function nextButton(env)
    local panel = env.WalkMapSetup.Panel()
    for _, child in ipairs(panel.__children or {}) do
        if child.label and child:IsShown() and not child.key and not child.value then
            local text = tostring(child.label:GetText())
            if text == "Next" or text:find("^Finish") then return child end
        end
    end
end

return {
    {"A new player gets the setup guide, not the welcome page", function(Mock)
        local env = newPlayer(Mock)
        local panel = env.WalkMapSetup.Panel()
        Mock.ok(panel and panel:IsShown(), "guide shown")
        Mock.eq(env.WalkMapSetup.Step(), 1, "starts at How do you play")
        Mock.eq(env.WalkMapSettings.welcomeSeen, true, "counts as the welcome")
        local settingsPanel = env.WalkMapExtras.SettingsPanel()
        Mock.ok(not (settingsPanel and settingsPanel:IsShown()), "no welcome page under it")
        Mock.ok(cardNamed(env, "Mouse and keyboard") and cardNamed(env, "Controller") and cardNamed(env, "Both"), "three choices")
    end},
    {"Picks win over recommended settings; the look is last and reloads", function(Mock)
        local env = newPlayer(Mock)
        local reloaded = false
        env.C_UI = {Reload = function() reloaded = true end}
        click(cardNamed(env, "Controller"))
        click(nextButton(env))
        Mock.eq(env.WalkMapSetup.Step(), 2, "quest display step")
        local areas = cardNamed(env, "Game quest areas")
        Mock.ok(areas.image:IsShown(), "with a picture")
        click(areas)
        click(nextButton(env))
        Mock.ok(env.WalkMapSetup.Choice().recommended, "recommended on for a new player")
        local tracker = lineNamed(env, "Quest tracker")
        while env.WalkMapSetup.Choice().tracker ~= "off" do click(tracker) end
        click(lineNamed(env, "Share where you are"))
        click(nextButton(env))
        Mock.eq(env.WalkMapSetup.Step(), 4, "the look is the last step")
        click(cardNamed(env, "Stone and gold"))
        local finish = nextButton(env)
        Mock.ok(tostring(finish.label:GetText()):find("reload", 1, true), "Finish says it reloads")
        click(finish)
        local s = env.WalkMapCharacterSettings
        Mock.eq(s.playStyle, "controller", "how you play")
        Mock.eq(s.objectiveIcons, false, "areas only: recommended did not turn icons back on")
        Mock.eq(s.areas, "all", "game quest areas")
        Mock.eq(s.zoneTracker, false, "tracker off: recommended did not turn it on")
        Mock.eq(s.shareLocation, true, "share where you are")
        Mock.eq(s.look, "stone", "look")
        Mock.eq(s.follow, true, "recommended applied to the rest")
        Mock.ok(reloaded, "reloaded for the new look")
        Mock.ok(not env.WalkMapSetup.Panel():IsShown(), "guide closed")
    end},
    {"Skip changes nothing; /walkmap setup opens it again", function(Mock)
        local env = newPlayer(Mock)
        local s = env.WalkMapCharacterSettings
        local before = s.objectiveIcons
        local panel = env.WalkMapSetup.Panel()
        for _, child in ipairs(panel.__children or {}) do
            if child.label and child:IsShown() and child.label:GetText() == "Skip setup" then click(child) end
        end
        Mock.ok(not panel:IsShown(), "skipped")
        Mock.eq(s.objectiveIcons, before, "nothing changed")
        env.SlashCmdList.WALKMAP("setup")
        env.tick(0.5, 5)
        Mock.ok(panel:IsShown(), "opens again")
        Mock.eq(env.WalkMapSetup.Choice().recommended, false, "recommended off when opened again")
    end},
}
