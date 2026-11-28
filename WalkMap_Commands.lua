-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- Key bindings, the /walkmap key capture and the slash command. Split from
-- WalkMap.lua in 1.11; loads right after it and reaches the map window
-- through WalkMapCore.
local core = WalkMapCore
if not core then return end
local frame, closeButton, viewport, say = core.frame, core.closeButton, core.viewport, core.Say

-- =========================================================
-- Bindings
-- =========================================================

BINDING_HEADER_WALKMAP =
    "WalkMap"


BINDING_NAME_WALKMAP_TOGGLE =
    "Toggle WalkMap"

BINDING_NAME_WALKMAP_CONTROLLER_FOCUS =
    "Toggle WalkMap Pad focus"


local previous = {}


local keyButton =
    CreateFrame(
        "Button",
        "WalkMapKeyboardToggle",
        UIParent,
        "SecureHandlerClickTemplate"
    )


keyButton:RegisterForClicks(
    "AnyUp"
)


keyButton:HookScript(
    "OnClick",
    function()

        if not WalkMapCombat.FrameLocked() then WalkMap_Toggle() end

    end
)


keyButton:Hide()
WalkMapCombat.Init(frame, closeButton, keyButton, viewport)
-- Closing the map ends a Follow pause from panning.
frame:HookScript("OnHide", function() WalkMapExtras.ResumeFollow() end)


local clickAction =
    "CLICK WalkMapKeyboardToggle:LeftButton"


-- =========================================================
-- Keyboard binding capture
-- =========================================================

local capture =
    CreateFrame(
        "Frame",
        nil,
        UIParent
    )


capture:SetSize(
    430,
    90
)

capture:SetPoint(
    "CENTER"
)

capture:SetFrameStrata(
    "DIALOG"
)

capture:EnableMouse(false)
capture:EnableKeyboard(true)

capture:SetPropagateKeyboardInput(
    false
)


local captureBG =
    capture:CreateTexture(
        nil,
        "BACKGROUND"
    )


captureBG:SetAllPoints()


captureBG:SetColorTexture(
    0.03,
    0.05,
    0.08,
    0.96
)


local captureText =
    capture:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalLarge"
    )


captureText:SetPoint(
    "CENTER"
)


captureText:SetText(
    WalkMapL("WalkMap: Press a key\nEscape cancels")
)


capture:Hide()


local capturedKey


local modifier = {

    LSHIFT = true,
    RSHIFT = true,

    LCTRL = true,
    RCTRL = true,

    LALT = true,
    RALT = true,

}


capture:SetScript(
    "OnKeyDown",
    function(
        self,
        key
    )

        if key == "ESCAPE" then

            self:Hide()

            capturedKey =
                nil

            return

        end


        if not modifier[key] then

            capturedKey =
                key

        end

    end
)


capture:SetScript(
    "OnKeyUp",
    function(
        self,
        key
    )

        if key ~= capturedKey then
            return
        end


        self:Hide()

        capturedKey =
            nil


        if InCombatLockdown() then

            say(
                "Try again out of combat."
            )

            return

        end


        local old =
            GetBindingAction(
                key
            )


        local ok, result =
            pcall(
                SetBindingClick,
                key,
                "WalkMapKeyboardToggle",
                "LeftButton"
            )


        if not ok
            or not result
        then

            say(
                "Could not bind key: "
                .. tostring(key)
            )

            return

        end


        if previous[key]
            == nil
        then

            previous[key] =
                old or ""

        end


        SaveBindings(
            GetCurrentBindingSet()
        )


        say(
            "Key registered as "
            .. key
            .. ". Binding saved."
        )

    end
)


capture:RegisterEvent(
    "PLAYER_REGEN_DISABLED"
)


capture:SetScript(
    "OnEvent",
    function(self)

        if self:IsShown() then

            self:Hide()

            capturedKey =
                nil


            say(
                "Key setup canceled by combat."
            )

        end

    end
)


-- =========================================================
-- Slash command
-- =========================================================

if WalkMapLiveDB then
    WalkMapLiveDB.OnReady = function()
        core.RefreshQuests()
    end
end

SLASH_WALKMAP1 =
    "/walkmap"

SLASH_WALKMAP2 =
    "/walkman"


SlashCmdList.WALKMAP =
    function(message)

        local command, key =
            message:match(
                "^(%S+)%s*(%S*)"
            )


        if command == "key" then

            if InCombatLockdown() then

                say(
                    "Wait until you are out of combat."
                )

                return

            end


            capturedKey =
                nil

            capture:Show()


        elseif command == "bind" then

            if InCombatLockdown() then

                say(
                    "Wait until you are out of combat."
                )

                return

            end


            key =
                key ~= ""
                and key:upper()
                or "PADBACK"


            local old =
                GetBindingAction(
                    key
                )


            if SetBinding(
                key,
                "WALKMAP_TOGGLE"
            )
            then

                if previous[key]
                    == nil
                then

                    previous[key] =
                        old or ""

                end


                say(
                    key
                    .. " toggles the map. Previous binding: "
                    .. tostring(old)
                    .. ". /walkmap unbind restores it."
                )

            else

                say(
                    "Could not bind "
                    .. key
                )

            end


        elseif command == "unbind" then

            if InCombatLockdown() then

                say(
                    "Wait until you are out of combat."
                )

                return

            end


            for button, action
                in pairs(previous)
            do

                local actionNow =
                    GetBindingAction(
                        button
                    )


                if actionNow
                        == "WALKMAP_TOGGLE"
                    or actionNow
                        == clickAction
                then

                    SetBinding(
                        button,
                        action ~= ""
                        and action
                        or nil
                    )

                end

            end


            SaveBindings(
                GetCurrentBindingSet()
            )


            previous = {}


            say(
                "Bindings from this session restored and saved."
            )


        elseif command == "pad" and (key == "pause" or key == "resume") then
            if WalkMapNativeController.UsesNativeNavigation() then
                say("Use the game's Change Focus Frame button in native mode. /walkmap pad toggles saved Pad focus.")
            else
                core.SetPadSuspended(key == "pause")
            end

        elseif command == "sort" or command == "sortbags" then

            WalkMapBags.Command(message:match("^%S+%s*(.-)%s*$"))

        elseif command == "db" then

            say(WalkMapLiveDB and WalkMapLiveDB.Status()
                or "QuestieDB integration unavailable")

        elseif command == "guide" or command == "help" then

            WalkMapExtras.Guide()

        elseif command == "setup" then

            if WalkMapCombat.Locked() or not (WalkMapSetup and WalkMapSetup.Show and WalkMapSetup.Show()) then
                say("The setup guide opens after combat.")
            end

        elseif command == "welcome" or command == "intro" then

            if WalkMapCombat.Locked() then
                say("The welcome page opens after combat.")
            else
                WalkMapExtras.ShowWelcome()
            end

        elseif command == "testing" or command == "beta" then
            if WalkMapExtras.ShowTesting then WalkMapExtras.ShowTesting() end
        elseif command == "news" or command == "new" then

            if WalkMapCombat.Locked() then
                say("What's new opens after combat.")
            else
                WalkMapExtras.ShowNews()
            end

        elseif command == "debug" then

            if key == "chat" then
                WalkMapExtras.PrintDebug()
            else
                WalkMapExtras.ShowDebug()
            end

        elseif command == "pad" and key == "status" then

            local padSuspended, _, lastPadButton = core.PadState()

            say("Controller navigation: "
                .. (WalkMapExtras.ControllerMode() and "on" or "off")
                .. "; focus: " .. (padSuspended and "paused" or "map")
                .. "; last button: " .. tostring(lastPadButton or "none")
                .. "; backend: " .. WalkMapNativeController.Status())

        elseif WalkMapExtras.Command(command, key) then
            core.RefreshQuests()

        else

            WalkMap_Toggle()

        end

    end
