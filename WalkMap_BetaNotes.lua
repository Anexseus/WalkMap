-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- What testers should look at in a beta. A beta build (its zip carries
-- "## X-Build: 1.14.20-beta4" in WalkMap.toc, written by the release
-- workflow) shows the page "What are we testing" once per version (any beta of it), the first
-- time the map is opened, instead of What's new. Full releases never show it.
--
-- Update for every beta: version = the version in WalkMap.toc, items = what
-- to try ({title, what to do and look for}). The release workflow refuses a
-- beta whose notes are for another version.
-- round: raise it (2, 3, ...) when a beta adds something new to test, so
-- the page shows again to testers who already saw it for this version.
WalkMapBetaNotes = {
    version = "1.14.20",
    round = 2,
    items = {
        {"Low-level quests (new)",
         "Settings > Quests on the map > Low-level quests: Off, Quest chains or All. With Quest chains, gray quests show at quest givers only when their chain goes on to your level, and the tooltip says how far. Check that chains you know show up, and that single gray quests stay hidden."},
        {"German and French",
         "Settings > Look > Language: try Deutsch and Français. The German texts were revised in this beta. Look for English text left over, text that runs outside its button or window, and translations that read wrong."},
        {"Changing the language",
         "Change it with the map open: the map, its buttons, the quest log, the tracker and the settings categories should change at once."},
        {"Button hints stay as you set them",
         "Turn Button hints off under Settings > Controller & help, restart the game and switch between mouse and controller: they should stay off."},
    },
}
