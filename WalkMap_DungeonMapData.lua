-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- Floors of the classic dungeons, whose maps the Forever client does not have:
-- twelve 256 px tiles each (4 x 3, the 1002 x 668 world-map format). The tile
-- pictures in Maps/Dungeons are Blizzard Entertainment's World of Warcraft artwork
-- (not under WalkMap's GPL; see THIRD_PARTY_NOTICES.txt). Numbers are game file IDs.
-- [instance ID] = {names = {...}, floors = {{label, {tiles}}, ...}}
WalkMapDungeonMapData = {
    [33] = {names = {"Shadowfang Keep"}, floors = {
        {"Floor 1", {"ShadowfangKeep1_1", "ShadowfangKeep1_2", "ShadowfangKeep1_3", "ShadowfangKeep1_4", "ShadowfangKeep1_5", "ShadowfangKeep1_6", "ShadowfangKeep1_7", "ShadowfangKeep1_8", "ShadowfangKeep1_9", "ShadowfangKeep1_10", "ShadowfangKeep1_11", "ShadowfangKeep1_12"}},
        {"Floor 2", {"ShadowfangKeep2_1", "ShadowfangKeep2_2", "ShadowfangKeep2_3", "ShadowfangKeep2_4", "ShadowfangKeep2_5", "ShadowfangKeep2_6", "ShadowfangKeep2_7", "ShadowfangKeep2_8", "ShadowfangKeep2_9", "ShadowfangKeep2_10", "ShadowfangKeep2_11", "ShadowfangKeep2_12"}},
        {"Floor 3", {"ShadowfangKeep3_1", "ShadowfangKeep3_2", "ShadowfangKeep3_3", "ShadowfangKeep3_4", "ShadowfangKeep3_5", "ShadowfangKeep3_6", "ShadowfangKeep3_7", "BlackrockDepths2_8", "ShadowfangKeep3_9", "ShadowfangKeep3_10", "ShadowfangKeep3_11", "BlackFathomDeeps3_12"}},
        {"Floor 4", {"ShadowfangKeep4_1", "ShadowfangKeep4_2", "ShadowfangKeep4_3", "ShadowfangKeep3_4", "ShadowfangKeep4_5", "ShadowfangKeep4_6", "ShadowfangKeep4_7", "BlackrockDepths2_8", "ShadowfangKeep4_9", "ShadowfangKeep4_10", "ShadowfangKeep4_11", "BlackFathomDeeps3_12"}},
        {"Floor 5", {"ShadowfangKeep3_1", "ShadowfangKeep5_2", "ShadowfangKeep5_3", "ShadowfangKeep5_4", "ShadowfangKeep5_5", "ShadowfangKeep5_6", "ShadowfangKeep5_7", "ShadowfangKeep5_8", "ShadowfangKeep5_9", "ShadowfangKeep5_10", "ShadowfangKeep5_11", "BlackFathomDeeps3_12"}},
        {"Floor 6", {"ShadowfangKeep6_1", "ShadowfangKeep6_2", "ShadowfangKeep6_3", "ShadowfangKeep6_4", "ShadowfangKeep6_5", "ShadowfangKeep6_6", "ShadowfangKeep6_7", "ShadowfangKeep6_8", "ShadowfangKeep6_9", "ShadowfangKeep6_10", "ShadowfangKeep6_11", "BlackFathomDeeps3_12"}},
        {"Floor 7", {"ShadowfangKeep7_1", "ShadowfangKeep7_2", "ShadowfangKeep7_3", "ShadowfangKeep7_4", "ShadowfangKeep7_5", "ShadowfangKeep7_6", "ShadowfangKeep7_7", "ShadowfangKeep7_8", "ShadowfangKeep7_9", "ShadowfangKeep7_10", "ShadowfangKeep7_11", "BlackFathomDeeps3_12"}},
    }},
    [34] = {names = {"The Stockade", "Stormwind Stockade"}, floors = {
        {"Floor 1", {"TheStockade1_1", "TheStockade1_2", "TheStockade1_3", "TheStockade1_4", "TheStockade1_5", "TheStockade1_6", "TheStockade1_7", "TheStockade1_8", "TheStockade1_9", "TheStockade1_10", "TheStockade1_11", "TheStockade1_12"}},
    }},
    [36] = {names = {"The Deadmines", "Deadmines"}, floors = {
        {"Floor 1", {"TheDeadmines1_1", "TheDeadmines1_2", "TheDeadmines1_3", "TheDeadmines1_4", "TheDeadmines1_5", "TheDeadmines1_6", "TheDeadmines1_7", "TheDeadmines1_8", "BlackFathomDeeps2_9", "TheDeadmines1_10", "TheDeadmines1_11", "BlackFathomDeeps3_12"}},
        {"Floor 2", {"ShadowfangKeep2_1", "TheDeadmines2_2", "TheDeadmines2_3", "TheDeadmines2_4", "TheDeadmines2_5", "TheDeadmines2_6", "TheDeadmines2_7", "TheDeadmines2_8", "TheDeadmines2_9", "TheDeadmines2_10", "TheDeadmines2_11", "TheDeadmines2_12"}},
    }},
    [43] = {names = {"Wailing Caverns"}, floors = {
        {"Floor 1", {"WailingCavernsClassic1_1", "WailingCavernsClassic1_2", "WailingCavernsClassic1_3", "WailingCavernsClassic1_4", "WailingCavernsClassic1_5", "WailingCavernsClassic1_6", "WailingCavernsClassic1_7", "WailingCavernsClassic1_8", "WailingCavernsClassic1_9", "WailingCavernsClassic1_10", "WailingCavernsClassic1_11", "WailingCavernsClassic1_12"}},
    }},
    [47] = {names = {"Razorfen Kraul"}, floors = {
        {"Floor 1", {"RazorfenKraul1_1", "RazorfenKraul1_2", "RazorfenKraul1_3", "RazorfenKraul1_4", "RazorfenKraul1_5", "RazorfenKraul1_6", "RazorfenKraul1_7", "RazorfenKraul1_8", "RazorfenKraul1_9", "RazorfenKraul1_10", "RazorfenKraul1_11", "RazorfenKraul1_12"}},
    }},
    [48] = {names = {"Blackfathom Deeps"}, floors = {
        {"Floor 1", {"BlackFathomDeeps1_1", "BlackFathomDeeps1_2", "BlackFathomDeeps1_3", "BlackFathomDeeps1_4", "BlackFathomDeeps1_5", "BlackFathomDeeps1_6", "BlackFathomDeeps1_7", "BlackFathomDeeps1_8", "BlackFathomDeeps1_9", "BlackFathomDeeps1_10", "BlackFathomDeeps1_11", "BlackFathomDeeps1_12"}},
        {"Floor 2", {"BlackFathomDeeps2_1", "BlackFathomDeeps2_2", "BlackFathomDeeps2_3", "BlackFathomDeeps2_4", "BlackFathomDeeps2_5", "BlackFathomDeeps2_6", "BlackFathomDeeps2_7", "BlackFathomDeeps2_8", "BlackFathomDeeps2_9", "BlackFathomDeeps2_10", "BlackFathomDeeps2_11", "BlackFathomDeeps2_12"}},
        {"Floor 3", {"BlackFathomDeeps3_1", "BlackFathomDeeps3_2", "BlackFathomDeeps3_3", "BlackFathomDeeps3_4", "BlackFathomDeeps3_5", "BlackFathomDeeps3_6", "BlackFathomDeeps3_7", "BlackFathomDeeps3_8", "BlackFathomDeeps3_9", "BlackFathomDeeps3_10", "BlackFathomDeeps3_11", "BlackFathomDeeps3_12"}},
    }},
    [70] = {names = {"Uldaman"}, floors = {
        {"Floor 1", {"Uldaman1_1", "Uldaman1_2", "Uldaman1_3", "Uldaman1_4", "Uldaman1_5", "Uldaman1_6", "Uldaman1_7", "Uldaman1_8", "BlackFathomDeeps2_9", "Uldaman1_10", "Uldaman1_11", "Uldaman1_12"}},
        {"Floor 2", {"Uldaman2_1", "Uldaman2_2", "Uldaman2_3", "Uldaman2_4", "Uldaman2_5", "Uldaman2_6", "Uldaman2_7", "BlackFathomDeeps3_8", "Uldaman2_9", "Uldaman2_10", "BlackFathomDeeps3_11", "BlackFathomDeeps3_12"}},
        {"Floor 3", {"Scholomance1_1", "Uldaman18_2", "Uldaman18_3", "Uldaman18_4", "Uldaman18_5", "Uldaman18_6", "Uldaman18_7", "Uldaman18_8", "BlackFathomDeeps2_9", "Uldaman18_10", "Uldaman18_11", "Scholomance3_12"}},
    }},
    [90] = {names = {"Gnomeregan"}, floors = {
        {"Floor 1", {"Gnomeregan1_1", "Gnomeregan1_2", "Gnomeregan1_3", "Gnomeregan1_4", "Gnomeregan1_5", "Gnomeregan1_6", "Gnomeregan1_7", "Gnomeregan1_8", "Gnomeregan1_9", "Gnomeregan1_10", "Gnomeregan1_11", "Gnomeregan1_12"}},
        {"Floor 2", {"Gnomeregan2_1", "Gnomeregan2_2", "Gnomeregan2_3", "Gnomeregan2_4", "Gnomeregan2_5", "Gnomeregan2_6", "Gnomeregan2_7", "Gnomeregan2_8", "Gnomeregan2_9", "Gnomeregan2_10", "Gnomeregan2_11", "Gnomeregan2_12"}},
        {"Floor 3", {"Gnomeregan3_1", "Gnomeregan3_2", "Gnomeregan3_3", "Gnomeregan1_4", "Gnomeregan3_5", "Gnomeregan3_6", "Gnomeregan3_7", "Gnomeregan3_8", "BlackFathomDeeps2_9", "Gnomeregan3_10", "Gnomeregan3_11", "BlackFathomDeeps3_12"}},
        {"Floor 4", {"Gnomeregan4_1", "Gnomeregan4_2", "Gnomeregan4_3", "Gnomeregan4_4", "Gnomeregan4_5", "Gnomeregan4_6", "Gnomeregan4_7", "Gnomeregan4_8", "BlackFathomDeeps2_9", "Gnomeregan4_10", "Gnomeregan4_11", "BlackFathomDeeps3_12"}},
    }},
    [109] = {names = {"The Temple of Atal'Hakkar", "Sunken Temple"}, floors = {
        {"Floor 1", {"TheTempleOfAtalHakkar1_1", "TheTempleOfAtalHakkar1_2", "TheTempleOfAtalHakkar1_3", "TheTempleOfAtalHakkar1_4", "TheTempleOfAtalHakkar1_5", "TheTempleOfAtalHakkar1_6", "TheTempleOfAtalHakkar1_7", "TheTempleOfAtalHakkar1_8", "BlackFathomDeeps2_9", "TheTempleOfAtalHakkar1_10", "TheTempleOfAtalHakkar1_11", "BlackFathomDeeps3_12"}},
    }},
    [129] = {names = {"Razorfen Downs"}, floors = {
        {"Floor 1", {"RazorfenDowns1_1", "RazorfenDowns1_2", "RazorfenDowns1_3", "RazorfenDowns1_4", "RazorfenDowns1_5", "RazorfenDowns1_6", "RazorfenDowns1_7", "RazorfenDowns1_8", "BlackFathomDeeps2_9", "RazorfenDowns1_10", "RazorfenDowns1_11", "RazorfenDowns1_12"}},
    }},
    [189] = {names = {"Scarlet Monastery"}, floors = {
        {"Floor 1", {"ScarletMonastery1_1", "ScarletMonastery1_2", "ScarletMonastery1_3", "ScarletMonastery1_4", "ScarletMonastery1_5", "ScarletMonastery1_6", "ScarletMonastery1_7", "ScarletMonastery1_8", "BlackFathomDeeps2_9", "ScarletMonastery1_10", "ScarletMonastery1_11", "ScarletMonastery1_12"}},
        {"Floor 2", {"ScarletMonastery2_1", "ScarletMonastery2_2", "ScarletMonastery2_3", "ScarletMonastery2_4", "ScarletMonastery2_5", "ScarletMonastery2_6", "ScarletMonastery2_7", "ScarletMonastery2_8", "ScarletMonastery2_9", "ScarletMonastery2_10", "ScarletMonastery2_11", "ScarletMonastery2_12"}},
        {"Floor 3", {"ScarletMonastery3_1", "ScarletMonastery3_2", "ScarletMonastery3_3", "ScarletMonastery3_4", "ScarletMonastery3_5", "ScarletMonastery3_6", "ScarletMonastery3_7", "ScarletMonastery3_8", "ScarletMonastery3_9", "ScarletMonastery3_10", "ScarletMonastery3_11", "ScarletMonastery3_12"}},
        {"Floor 4", {"ScarletMonastery4_1", "ScarletMonastery4_2", "ScarletMonastery4_3", "ScarletMonastery4_4", "ScarletMonastery4_5", "ScarletMonastery4_6", "ScarletMonastery4_7", "BlackFathomDeeps3_8", "ScarletMonastery4_9", "ScarletMonastery4_10", "ScarletMonastery4_11", "BlackFathomDeeps3_12"}},
    }},
    [209] = {names = {"Zul'Farrak"}, floors = {
        {"Floor 1", {"ZulFarrak1", "ZulFarrak2", "ZulFarrak3", "ZulFarrak4", "ZulFarrak5", "ZulFarrak6", "ZulFarrak7", "ZulFarrak8", "ZulFarrak9", "ZulFarrak10", "ZulFarrak11", "ZulFarrak12"}},
    }},
    [229] = {names = {"Blackrock Spire", "Lower Blackrock Spire", "Upper Blackrock Spire"}, floors = {
        {"Floor 1", {"BlackrockSpire1_1", "BlackrockSpire1_2", "BlackrockSpire1_3", "BlackrockSpire1_4", "BlackrockSpire1_5", "BlackrockSpire1_6", "BlackrockSpire1_7", "BlackrockSpire1_8", "BlackrockSpire1_9", "BlackrockSpire1_10", "BlackrockSpire1_11", "BlackrockSpire1_12"}},
        {"Floor 2", {"BlackrockSpire1_1", "BlackrockSpire1_2", "BlackrockSpire2_3", "BlackrockSpire2_4", "BlackrockSpire1_5", "BlackrockSpire2_6", "BlackrockSpire2_7", "BlackrockSpire2_8", "BlackrockSpire1_9", "BlackrockSpire2_10", "BlackrockSpire2_11", "BlackrockSpire2_12"}},
        {"Floor 3", {"BlackrockSpire1_1", "BlackrockSpire1_2", "BlackrockSpire3_3", "BlackrockSpire2_4", "BlackrockSpire1_5", "BlackrockSpire3_6", "BlackrockSpire3_7", "BlackrockSpire2_8", "BlackrockSpire1_9", "BlackrockSpire1_10", "BlackrockSpire3_11", "BlackrockSpire2_12"}},
        {"Floor 4", {"BlackrockSpire4_1", "BlackrockSpire4_2", "BlackrockSpire4_3", "BlackrockSpire4_4", "BlackrockSpire4_5", "BlackrockSpire4_6", "BlackrockSpire4_7", "BlackrockSpire4_8", "BlackrockSpire1_9", "BlackrockSpire4_10", "BlackrockSpire4_11", "BlackrockSpire4_12"}},
        {"Floor 5", {"BlackrockSpire5_1", "BlackrockSpire5_2", "BlackrockSpire5_3", "BlackrockSpire2_4", "BlackrockSpire5_5", "BlackrockSpire5_6", "BlackrockSpire5_7", "BlackrockSpire2_8", "BlackrockSpire5_9", "BlackrockSpire5_10", "BlackrockSpire5_11", "BlackrockSpire2_12"}},
        {"Floor 6", {"BlackrockSpire1_1", "BlackrockSpire6_2", "BlackrockSpire6_3", "BlackrockSpire6_4", "BlackrockSpire1_5", "BlackrockSpire6_6", "BlackrockSpire6_7", "BlackrockSpire6_8", "BlackrockSpire1_9", "BlackrockSpire6_10", "BlackrockSpire6_11", "BlackrockSpire6_12"}},
        {"Upper Spire", {"BlackrockSpire7_1", "BlackrockSpire7_2", "BlackrockSpire7_3", "BlackrockSpire7_4", "BlackrockSpire7_5", "BlackrockSpire7_6", "BlackrockSpire7_7", "BlackrockSpire7_8", "BlackFathomDeeps2_9", "BlackrockSpire7_10", "BlackrockSpire7_11", "BlackrockSpire7_12"}},
    }},
    [230] = {names = {"Blackrock Depths"}, floors = {
        {"Floor 1", {"BlackFathomDeeps2_1", "BlackrockDepths1_2", "BlackrockDepths1_3", "BlackrockDepths1_4", "BlackrockDepths1_5", "BlackrockDepths1_6", "BlackrockDepths1_7", "BlackrockDepths1_8", "BlackFathomDeeps2_9", "BlackrockDepths1_10", "BlackrockDepths1_11", "BlackrockDepths1_12"}},
        {"Floor 2", {"BlackrockDepths2_1", "BlackrockDepths2_2", "BlackrockDepths2_3", "BlackrockDepths2_4", "BlackrockDepths2_5", "BlackrockDepths2_6", "BlackrockDepths2_7", "BlackrockDepths2_8", "BlackrockDepths2_9", "BlackrockDepths2_10", "BlackrockDepths2_11", "BlackFathomDeeps3_12"}},
    }},
    [289] = {names = {"Scholomance"}, floors = {
        {"Floor 1", {5332424, 5332428, 5332429, 5332430, 5332431, 5332432, 5332433, 5332434, 5332435, 5332425, 5332426, 5332427}},
        {"Floor 2", {5332436, 5332440, 5332441, 5332442, 5332443, 5332444, 5332445, 5332446, 5332447, 5332437, 5332438, 5332439}},
        {"Floor 3", {5332448, 5332452, 5332453, 5332454, 5332455, 5332456, 5332457, 5332458, 5332459, 5332449, 5332450, 5332451}},
        {"Floor 4", {5332460, 5332464, 5332465, 5332466, 5332467, 5332468, 5332469, 5332470, 5332471, 5332461, 5332462, 5332463}},
    }},
    [329] = {names = {"Stratholme"}, floors = {
        {"Floor 1", {"Stratholme1_1", "Stratholme1_2", "Stratholme1_3", "Stratholme1_4", "Stratholme1_5", "Stratholme1_6", "Stratholme1_7", "Stratholme1_8", "Stratholme1_9", "Stratholme1_10", "Stratholme1_11", "Stratholme1_12"}},
        {"Floor 2", {"Stratholme2_1", "Stratholme2_2", "Stratholme2_3", "Stratholme2_4", "Stratholme2_5", "Stratholme2_6", "Stratholme2_7", "Stratholme2_8", "Stratholme2_9", "Stratholme2_10", "Stratholme2_11", "BlackFathomDeeps3_12"}},
    }},
    [349] = {names = {"Maraudon"}, floors = {
        {"Floor 1", {"Maraudon1_1", "Maraudon1_2", "Maraudon1_3", "Maraudon1_4", "Maraudon1_5", "Maraudon1_6", "Maraudon1_7", "Maraudon1_8", "Maraudon1_9", "Maraudon1_10", "Maraudon1_11", "BlackFathomDeeps3_12"}},
        {"Floor 2", {"Maraudon2_1", "Maraudon2_2", "Maraudon2_3", "Maraudon2_4", "Maraudon2_5", "Maraudon2_6", "Maraudon2_7", "Maraudon2_8", "Maraudon2_9", "Maraudon2_10", "Maraudon2_11", "Maraudon2_12"}},
    }},
    [389] = {names = {"Ragefire Chasm"}, floors = {
        {"Floor 1", {"Ragefire1_1", "Ragefire1_2", "Ragefire1_3", "Ragefire1_4", "Ragefire1_5", "Ragefire1_6", "Ragefire1_7", "Ragefire1_8", "Ragefire1_9", "Ragefire1_10", "Ragefire1_11", "BlackFathomDeeps3_12"}},
    }},
    [429] = {names = {"Dire Maul"}, floors = {
        {"Floor 1", {"DireMaul1_1", "DireMaul1_2", "DireMaul1_3", "DireMaul1_4", "DireMaul1_5", "DireMaul1_6", "DireMaul1_7", "DireMaul1_8", "DireMaul1_9", "DireMaul1_10", "DireMaul1_11", "DireMaul1_12"}},
        {"Floor 2", {"DireMaul2_1", "DireMaul2_2", "DireMaul2_3", "DireMaul2_4", "DireMaul2_5", "DireMaul2_6", "DireMaul2_7", "DireMaul2_8", "DireMaul2_9", "DireMaul2_10", "DireMaul2_11", "DireMaul2_12"}},
        {"Floor 3", {"DireMaul3_1", "DireMaul3_2", "DireMaul3_3", "DireMaul3_4", "DireMaul3_5", "DireMaul3_6", "DireMaul3_7", "BlackFathomDeeps3_8", "DireMaul3_9", "DireMaul3_10", "DireMaul3_11", "BlackFathomDeeps3_12"}},
        {"Floor 4", {"DireMaul4_1", "DireMaul4_2", "DireMaul4_3", "DireMaul4_4", "DireMaul4_5", "DireMaul4_6", "DireMaul4_7", "DireMaul4_8", "DireMaul4_9", "DireMaul4_10", "DireMaul4_11", "DireMaul4_12"}},
        {"Floor 5", {"DireMaul5_1", "DireMaul5_2", "DireMaul5_3", "DireMaul5_4", "DireMaul5_5", "DireMaul5_6", "DireMaul5_7", "DireMaul5_8", "DireMaul5_9", "DireMaul5_10", "DireMaul5_11", "DireMaul5_12"}},
        {"Floor 6", {"DireMaul6_1", "DireMaul6_2", "DireMaul6_3", "DireMaul6_4", "DireMaul6_5", "DireMaul6_6", "DireMaul6_7", "BlackFathomDeeps3_8", "DireMaul6_9", "DireMaul6_10", "DireMaul6_11", "BlackFathomDeeps3_12"}},
    }},
    -- WoW Forever's new dungeons: painted maps by Santiago Reyes (Maps/Dungeons/
    -- Painted, see CREDITS.txt there), one picture per floor. Matched by name.
    [900001] = {names = {"The Hall of Thanes", "Hall of Thanes"}, painted = true, floors = {
        {"Floor 1", {"HallOfThanes"}},
    }},
    [900002] = {names = {"Ruins of Lordaeron"}, painted = true, floors = {
        {"Floor 1", {"RuinsOfLordaeron"}},
    }},
    [900003] = {names = {"Excavation Site: Wetlands"}, painted = true, floors = {
        {"Floor 1", {"ExcavationSiteWetlands"}},
    }},
    [900004] = {names = {"City of Dalaran", "Dalaran"}, painted = true, floors = {
        {"The Underbelly", {"CityOfDalaranSewers"}},
        {"City", {"CityOfDalaranCity"}},
    }},
}
