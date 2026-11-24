-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- What testers should look at in a beta. A beta build (its zip carries
-- "## X-Build: 1.14.20-beta4" in WalkMap.toc, written by the release
-- workflow) shows the page "What are we testing" once per beta, the first
-- time the map is opened, instead of What's new. Full releases never show it.
--
-- Update for every beta: version = the version in WalkMap.toc, items = what
-- to try ({title, what to do and look for}). The release workflow refuses a
-- beta whose notes are for another version.
WalkMapBetaNotes = {
    version = "1.14.20",
    items = {
        {"This page",
         "New in betas: this page shows once per beta, the first time you open the map, instead of What's new. Check that it came up by itself and that /walkmap testing opens it again."},
        {"German and French",
         "Settings > Look > Language: try Deutsch and Français. Look for English text left over, text that runs outside its button or window, and translations that read wrong."},
        {"Changing the language",
         "Change it with the map open: the map, its buttons, the quest log, the tracker and the settings categories should change at once."},
        {"Button hints stay as you set them",
         "Turn Button hints off under Settings > Controller & help, restart the game and switch between mouse and controller: they should stay off."},
    },
}
