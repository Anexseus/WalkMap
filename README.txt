WalkMap 1.14.12 - a controller-friendly map for WoW Forever
=======================================================
By Anexseus and Underbuks. Free software under the GNU GPL v3 or later.

WalkMap is a zone map, quest log and quest tracker built for playing with a
controller (mouse works everywhere too). It shows where your quests are, who
gives new quests, trainers and vendors, herbs and ore, and your party - on a
large map, on the minimap and in a compact on-screen tracker.


INSTALLING
----------
1. Install QuestieDB (it also comes with Questie's download). WalkMap reads
   quest, NPC and object locations from it. In the addon list, enable
   QuestieDB. Questie itself can stay disabled - WalkMap brings Questie's
   list of hidden quests with it.
2. Put the WalkMap folder in Interface/AddOns.
3. Log in. The first time, WalkMap opens with a welcome page. "Use
   recommended settings" sets up WalkMap the way its authors play: WalkMap
   replaces the game map, quest log and quest tracker, controller focus,
   quest icons, Follow, fading, the square game-terrain minimap and group
   messages. Then choose game quest areas, the player halo and auto-selling
   of grey items yourself. Open it again with /walkmap welcome.
   After an update, the first time you open the map shows a short
   "What's new" page with that update's changes (/walkmap news shows it
   again).

Open and close the map with /walkmap, a key you bind under
Key Bindings > WalkMap > Toggle WalkMap, or - with "Use WalkMap instead of
game map" on - the game's map key, quest log key and the gamepad wheel's
Quest & Maps.


THE MAP
-------
- Click the map title to browse zones, continents, the world and dungeons.
  Your current zone is green. Follow (or Current zone in that menu) brings
  you back.
- On the world map, click a continent to open it; on a continent, click a
  zone. What a click opens is outlined on the map, and the name under the
  mouse shows it with the zone's level range in a colour for your level
  (red: far above you, yellow: fits, grey: outgrown). With a controller: map
  control (X), move the crosshair, A opens it; the outline follows the
  crosshair. While controller focus is on the map, the mouse outline and
  name show for a few seconds after you move the mouse.
- One level back up (zone -> continent -> world): the button with the gold
  arrow and the continent's name in the map's top-left corner, or
  right-click on a continent or the
  world map. With a controller: in map control, zoom all the way out and
  press LB once more. On zone maps right-click sets a waypoint, unless you
  turn on Settings > Map > Right-click goes a map level up.
- The map always opens on the zone you are in. A zone you browsed to is
  forgotten when you close the map.
- Settings > Map > Unexplored areas (off by default) shows the parts of a
  zone you have not explored yet, dimmed in red.
- Friends and guild: the button left of the quest log button shows who is
  online in the zone you are looking at (click it, or A, to pick someone
  there and invite them to your group); on the continent and world maps
  each zone with people gets a badge (Settings > Map > Friends on the map / Guild on the
  map). With Share where you are (off by default) your guild and friends
  who use WalkMap or OpenMap see a dot where you stand, and you see theirs;
  never shared from dungeons, raids or battlegrounds.
  Their dot says whether they are on the same layer as you, when both
  layers are known (WalkMap reads yours from creatures you target or mouse
  over).
- Places > Other > Rare mobs shows rare mobs and rare elites with their
  level (from QuestieDB).
- Click a quest's marker (its ? or one of its objective icons) to focus
  that quest: only its markers and area stay on the maps. Click the marker
  again to show all quests. A marker shared by several quests steps
  through them.
- Mouse wheel or LB/RB zooms, drag pans. Follow keeps you centred while
  zoomed in; panning pauses Follow for 15 seconds (or until you leave map
  control, press Center or close the map).
- Quest icons from QuestieDB: red = kill, blue = object, green = loot,
  gold = other. Hover for the quest, progress, monster level, drop rate,
  elite/rare and the next quest in the chain. Nearby icons merge into one
  numbered icon when zoomed out.
- A quest that is ready to hand in shows a "?" where it is handed in. When
  the game itself has no marker for it (quests handed in at an object),
  WalkMap takes the place from QuestieDB.
- Quest givers ("!") are NPCs and objects that start a quest (posters,
  notes, crates): hover to see each quest they offer with its level
  (coloured against yours), XP, and (Dungeon) or (Raid) for instance quests. A
  red "!" means everything that giver offers is a dungeon or raid quest, an
  orange "!" that it is all PvP quests.
- Yellow question marks = ready to turn in. These and your arrow are always
  drawn on top.
- Places (top row): trainers, inns, flight masters, vendors, banks, herbs,
  ore and more. Several can be shown at once. Flight masters whose flight
  path you have not discovered yet are greyed out with a red tint.
- Waypoints anywhere: right-click, middle-click or Alt-click the map (middle-
  click and Alt-click also work on a marker), or in map control
  press A - on a selected marker, or at the crosshair when none is selected.
  A badge shows direction and distance. Right-click the star to clear it.
- Buttons (footer, next to Settings) chooses which map buttons are shown.
  Everything except Settings and Buttons can be hidden; Show all brings them
  back.
- Escape closes an open menu, then Settings, then the map (out of combat).
- Talking to an NPC (gossip, quests, vendors, trainers, flight masters, bank,
  mail, auction house) puts their window on top of the map.
- Game windows you open after the map (talents, spellbook, character...)
  go on top of it; opening the map again brings it back in front.
- When you die, a skull marks your corpse on the map and minimaps, and the
  badge points to it until you are alive again.
- Wrong quest giver or marker? Right-click (or Shift-click) the marker
  itself to hide it.
  /walkmap givers reset and /walkmap markers reset bring them back.


QUEST FOCUS, QUEST LOG AND TRACKER
----------------------------------
- Quests (footer) or Focus in the quest log: show just one quest's icons and
  areas. WalkMap's focus is its own; the game's tracked quest is not used.
- The book at the end of the top row (or Y on the controller) folds out
  WalkMap's quest log: zones, progress, rewards, full text, Focus, Track,
  Show on map, Share, Link and Abandon (press twice to confirm).
- The zone quest tracker lists quests for your zone with objectives,
  distance (nearest first) and tags such as Elite or Group 3, and the
  experience each quest gives at your level. Settings > Quest tracker >
  Quest tracker chooses how much it shows: this zone only; this zone plus
  nearby quests (quests of a neighbouring zone that reach into this map,
  under their own heading such as "Nearby: Duskwood", with distance); or
  all zones.
  Quest colours use the game's own difficulty for your level. Click a quest to open it in the quest log.
  Right-click a quest in the tracker to remove it from the tracker and the
  maps, or use Untrack in the quest log; Track there brings it back.
  Shift-click a quest in the tracker or the quest log to link it in chat,
  or use the Link button in the quest log. With the chat line closed, open
  it within 30 seconds and the quest is put in.
- Settings > Map > Waypoint to turn-ins: when a quest is ready to
  turn in, the waypoint moves to where the game says to hand it in.
  Alt-drag its header to move it, Alt-right-click to reset. In the game's
  Edit Mode it gets a blue outline: drag it to move it and drag its corner
  to set width and height. It then lists the quests that fit, with "+N more
  quests" below; right-click the outline for automatic height. It never
  runs past the bottom of the screen. The game's gamepad and mouse
  interfaces each keep their own tracker place and size. Settings > Quest tracker sets text
  size, background, number of quests, width, and can hide Forever's own
  tracker.
- Settings > Quest tracker > Tell group about quest progress posts your
  finished objectives (or every step) in party/raid chat. Off by default.


MINIMAP
-------
Settings > Minimap > WalkMap minimap (or the top-row button) shows
WalkMap's markers on a zone-artwork minimap or on a larger, square version of
the game's own minimap. Game minimap icons adds WalkMap's markers to the
ordinary minimap instead. M+ / M- zoom the minimap.
Move the mouse over a marker on any of them to see what it is: the quest
giver and the quests offered, the place, the objective and its quest, or
that a quest is ready to turn in. A red "!" is a giver with only dungeon or
raid quests, an orange "!" one with only PvP quests, as on the large map.


CONTROLLER
----------
WalkMap uses Forever's own controller navigation: D-pad moves between
buttons, A chooses, B goes back or closes. Choose Controller or Both under
How you play (or turn on Pad focus) if you want the D-pad on WalkMap
straight away.
- X: control the map itself. D-pad pans, LB/RB zooms, Y steps through
  the markers around the crosshair (nearest first; move it to browse
  elsewhere), the crosshair shows the tooltip of what it is over. A on a
  quest marker focuses that quest (as a click does); anywhere else A sets a
  waypoint (on the selected marker or at the crosshair; A on the waypoint
  clears it),
  X or B returns. Zoomed all the way out, LB once more opens the map one
  level up (the corner button then reads "LB: ...").
  Tap the D-pad to nudge the crosshair a tiny bit; hold it to move
  smoothly, slowly at first and then faster. Where the map cannot scroll -
  zoomed all the way out, or at an edge - the crosshair moves across the
  map instead, so every spot can be reached at any zoom.
- Y: open or close the quest log. In the quest log, D-pad Left and Right on
  a quest turn the page, looping from the last page to the first and back;
  Up and Down past the list's edge turn the page too.
- The game's Change Focus Frame button (Select) switches between WalkMap and
  your character while the map stays open. With Settings > Controller &
  help > Select keeps the map released, a map you left with Select stays
  released when you close and open it again, until Select takes it back.
- A line at the top of the map says what A, B, X and Y do right now
  (Settings > Controller & help > Button hints).


SETTINGS ON SEVERAL CHARACTERS
------------------------------
Settings are saved per character. To use the same setup on all of them:
- On the character you like: Settings > Profiles > Save as account settings.
- On another character: Settings > Profiles > Load account settings (click
  twice; the interface reloads).
- Settings > Profiles > New characters use account settings: new characters
  start from the saved copy.
Quest focus, waypoint, hidden markers and quests removed from the tracker
always stay with each character.

COMBAT
------
With the game's mouse and keyboard interface (its gamepad UI off), the map
is an ordinary window: in combat you can open and close it, move and
resize it, and use the footer and Settings. Only settings that touch the
game's minimap, key bindings or its own quest tracker wait until the fight
ends.
With the game's gamepad UI on, the window is protected so your WalkMap key
can open and close it in combat. In combat you can still use the map with
the mouse (tooltips, zoom, pan, waypoints), the zone picker, Places, Clear
view, Follow, the quest log and X. Moving and resizing the window, the
footer, Settings and the minimap button are locked until the fight ends.
The controller stays with the game.
WalkMap picks the window type as it loads. If you switch the game's
interface between mouse and keyboard and gamepad, a small window offers to
reload the interface (out of combat), and How you play follows the switch:
Both with the gamepad UI, Mouse and keyboard without it (a chosen
Controller stays Controller).
Optional: Settings > Map > Close map when combat starts.
/click WalkMapCloseMacro in a macro closes the map, also in combat.


BAGS & VENDORS
--------------
Settings > Bags & vendors (based on Underbuks' SortPants): sort bags, and
optionally sell grey items automatically at vendors (off by default). Bind
Sort bags under Key Bindings > WalkMap or type /walkmap sort. Disable the
separate SortPants addon when using these.


COMMANDS
--------
/walkmap                  Open or close the map
/walkmap welcome          Show the welcome page again
/walkmap news             What's new in this version
/walkmap guide            Short guide in chat
/walkmap db               QuestieDB status
/walkmap debug            Debug report to copy (/walkmap debug chat prints it)
/walkmap sort             Sort bags
/walkmap autosell on|off  Auto-sell grey items
/walkmap areas all|focus|off      Game quest areas
/walkmap icons on|off             QuestieDB quest icons
/walkmap focusicons on|off        Icons for the focused quest only
/walkmap givers on|off|reset      Quest givers
/walkmap markers reset            Restore hidden markers
/walkmap follow on|off            Follow your character
/walkmap minimap on|off           WalkMap minimap
/walkmap miniterrain zone|game    Minimap background
/walkmap places <name>|none       e.g. inn, flight, bank, herb, ore,
                                  trainer, class:mage, cooking
/walkmap level auto|<1-60>        Level used for quest givers
/walkmap profile questing|exploration|custom|save
/walkmap pad on|off               Controller focus when the map opens
/walkmap navigation native|custom Controller navigation backend


LOOK
----
Settings > Look: Classic (the game's own window art), Stone and gold, Wood and
parchment, or Leather and bronze. "Apply now" reloads the interface to use the
choice. WalkMap's windows, buttons, menus, tracker and minimap frames change;
the map and its icons stay the same.


REPORTING A PROBLEM
-------------------
Open Settings > Controller & help > Debug report (or /walkmap debug) while
the problem is visible, copy it and send it along. BugGrabber/BugSack
screenshots of Lua errors help a lot.


KNOWN LIMITATIONS
-----------------
These come from the game, not from WalkMap. Some have a partial workaround.

In combat, with the game's gamepad interface:
- The map window cannot be moved or resized, and its footer and Settings
  wait until the fight ends. The window is protected so your WalkMap key can
  open and close it in combat, and the game locks protected windows during a
  fight. With the mouse and keyboard interface the map works fully.
- Settings that change the game's minimap, key bindings or its own quest
  tracker are applied after combat.
- Share in the quest log is blocked by the game during a fight.
- WalkMap does not move the controller away from the group window during a
  fight; it leaves the game's controller system alone in combat.

Select and the controller:
- When Select takes the map back, the game may first print "No interface
  frame to focus!". WalkMap removes the message right after.
- In a group, with the map released, closed and reopened and the group
  window folded in, the game uses Select to open the group window. WalkMap
  then takes the controller to the map, but the group window stays open.
- LB + RB + D-pad up always opens the game's own quest tracker.
- If the game's own map hits its "SoftCursor" error, the controller can stop
  working in menus. WalkMap prevents the known cause; if it happens anyway,
  /reload fixes it.

Chat and data:
- WalkMap never opens the chat line itself (the game blocks addons from it
  in controller mode). A linked quest waits until you open chat.
- The game does not tell addons which parts of a map are still unexplored.
- WoW has no Danish client, so quest and NPC names follow the game's language.


NOTES
-----
- Locations come from QuestieDB: they show where things spawn, not whether
  something is there right now.
- WalkMap.toc uses Interface 16001. If your client uses another number,
  check /dump select(4, GetBuildInfo()) and edit ## Interface in the TOC.
- WalkMap is not made or endorsed by the Questie team.


LICENSE AND CREDITS
-------------------
WalkMap is free software under the GNU General Public License, version 3 or
later (LICENSE.txt; full text in COPYING.md). You may use, change and share
it, as long as shared versions keep the same license and include the source.
- WalkMap_QuestBlacklist.lua is derived from Questie's quest blacklist
  (GPLv3, the Questie contributors); tools/QuestBlacklist/ regenerates it.
- Four marker images in Icons/ come from pfQuest by Shagu (MIT, Icons/MIT.txt).
- The unexplored-area data (WalkMap_RevealData.lua) comes from OpenMap by the
  OpenMap contributors (MIT; notice in the file), and location sharing uses
  OpenMap's message format so both addons see each other.
- QuestieDB is a separate addon by the Questie contributors.
See THIRD_PARTY_NOTICES.txt for details. Change history: CHANGELOG.md and
docs/CHANGELOG-test-builds.md.
For people changing WalkMap: tests/ holds tests that run outside the game
(lua tests/run.lua) and tools/Release/ the release check; the game loads
neither.
