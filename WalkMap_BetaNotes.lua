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
    version = "1.14.23",
    items = {
        {"Quest giver level moved",
         "Settings > Quests on the map > Quest giver level: one row now, click it to go through Automatic, 1-10, 11-20 ... 51-60. The Giver level page is gone. Check that quest givers follow your choice."},
        {"New names and order",
         "Look is now Appearance, Profiles sits under Controller & help, and Controllers is now Tested controllers, at the bottom after Community. Is everything easy to find?"},
        {"Move the settings window",
         "Drag the top of the settings window to move it. It opens there again next time, on all your characters. Right-click the top to put it back in the middle."},
        {"Debug report button",
         "A Debug report button now sits at the bottom left of the settings window. /walkmap debug opens the report window too, also in combat and above the settings window."},
    },
}
