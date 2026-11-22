# WalkMap changelog

## 1.14.14

Fixed
- In combat, the wheel's Quest & Maps with WalkMap open closes WalkMap.
  Before, the game's own map opened behind it. The game does not let
  addons close its map in combat, so it shows; B closes it.

New
- Dungeon maps: inside the classic dungeons (Ragefire Chasm to
  Stratholme, 19 in all) the map shows the dungeon instead of the zone
  outside. Floors are picked in the zone menu. The game has no maps of
  these dungeons, so WalkMap ships Blizzard's own (see
  THIRD_PARTY_NOTICES). There is no arrow inside: the game gives no
  position there.

Changed
- Inside a dungeon or raid the map's status line says where you are
  ("In The Deadmines - no position inside") instead of "Position
  unavailable.", and the Debug report shows the instance and the game's
  map for it.

## 1.14.13

Hotfix for 1.14.12.

Changed
- Same layer / Other layer is no longer shown. From game build 71037
  (20 Nov 2026) every creature carries its own number where the layer
  used to be, so addons can no longer tell layers apart (LayerSwap and
  TitanLayer dropped it too). WalkMap now shows no layer rather than a
  wrong one. Dots, zones, invites and group progress are not affected.

## 1.14.12

Hotfix for 1.14.11.

New
- Quest givers with only PvP quests get an orange "!" (on the map and
  both minimaps), and their tooltip marks those quests (PvP), as dungeon
  and raid givers have a red one.

Fixed
- Quest objective tooltips name the mob that drops an item, and its
  level, also when QuestieDB has no drop rate for it ("Dropped by
  Slark", "Level 15-16"). Before, both were left out then.

## 1.14.11

Hotfix for 1.14.10.

Changed
- What's new shows once for players who have not seen it since friends
  and guild came to the map (1.14.8), with the switches for friends,
  guild, sharing where you are and group progress on the page.

Fixed
- Quest log: button labels (Show on map, Full text, the zone filter ...)
  and long zone headers shrink to stay inside on setups that draw the
  font larger, like a handheld at 720p.
- Select keeps the map released: talking to an NPC (or any game window
  opening and closing) no longer selects the map again. Only Select does.
- Quest log: zone headings are light parchment on a faint band, so they
  stand apart from quest titles; "(collapsed in game)" is gone (the
  game's own quest log does not matter to WalkMap's).
- Quest log: "Show on map" is now "On map", so it fits its button on
  every screen.
- Quest tracker: an objective line next to the XP leaves room for the XP
  as wide as it is drawn, so they no longer overlap with larger fonts.

## 1.14.10

Hotfix for 1.14.9.

Fixed
- Settings, the welcome page and What's new: rows take the height their
  text needs, so text no longer runs into the next row on setups that
  draw the font larger. Fewer rows then fit, and the page scrolls.

Changed
- What's new shows once for 1.14.10, with the switches for seeing
  friends and guild on the map, sharing where you are, and group
  progress right on the page.

## 1.14.9

New
- Group progress: in a party, the tracker shows under each quest you
  share how far the others are with it ("Anna  3/8, 0/1", or "ready").
  Needs WalkMap for them too. Settings, Quest tracker, Group progress
  turns it off (then nothing is sent or shown).
- Invite from the friends button: click it (A with the controller) for a
  list of the friends and guild members in the zone you are looking at,
  and pick one to invite them to your group. People already in your group
  are left out.
- Friends and guild members who share where they are now also show on
  the minimap (WalkMap's own and the game's), as a dot in their class
  colour with the same tooltip as on the large map. Settings, Minimap,
  Friends and guild turns it off.
- The friends button can be hidden from the footer's Buttons menu
  (Friends and guild), per character like the other buttons.
- Same layer or not: with Share where you are on, WalkMap learns your layer
  from any creature you target, mouse over or see a nameplate of (read the
  same way as LayerETA does, so it matches the layer LayerSwap hosts use),
  and sends it along. A friend's or guild member's dot (and the friends button
  list) then says "Same layer" or "Other layer" - only when both of you
  are known, in the same zone. OpenMap users and unknown layers show
  nothing about layers. The Debug report shows your own layer.

Changed
- Settings, the welcome page and What's new show a scroll bar with arrows
  on pages that have more rows than fit, so it is clear they scroll. Mouse
  wheel, the arrows or a click on the bar scroll; with a controller Up on
  the first row or Down on the last row scrolls, as before.
  The bar matches the window look: the game's own knob and arrows in
  Classic, and gold, brass or bronze in Stone, Wood and Leather.
  The "x more below (scroll)" line is gone: the bar says it.

Fixed
- No dot for yourself: your own shared place coming back from the guild
  was shown as someone else when the name came back with a second name
  or a sibling realm's name.
- The friends button's list now includes those who share where they are
  in the zone (they have a dot), not only those the game's lists place
  there.

## 1.14.8

New
- Friends and guild on the map: online friends (and Battle.net friends in
  this game, of your faction) and guild members by zone. A new button left
  of the quest log button shows who is in the zone you are looking at
  (mouse over it, or move to it with the controller); on the continent and
  world maps each zone with people gets a badge. Someone who is both a
  friend and in your guild shows once, as Friend. Settings > Map > Friends
  on the map and Guild on the map (on by default).
- Share where you are (off by default): your guild and your friends who use
  WalkMap or OpenMap see a class-coloured dot where you stand, and you see
  theirs. It uses OpenMap's messages, so WalkMap and OpenMap players see
  each other. Never shared from dungeons, raids or battlegrounds.
- Unexplored areas: the parts of a zone you have not explored yet show
  dimmed in red on the large map, so you can see where to go to reveal
  them. Settings > Map > Unexplored areas (off by default). The map data
  comes from OpenMap (MIT).
- Places > Rare mobs: rare mobs and rare elites from QuestieDB, with their
  level. Off unless chosen.
- What's new shows once for this update, where friends, guild, sharing and
  unexplored areas can be turned on right away. The welcome page for new
  players offers friends, guild and sharing too.

Map control (X with a controller)
- The crosshair shows the tooltip of whatever it is over, as the mouse
  does: quest markers, givers, places, rare mobs, friends, the waypoint.
- A on a quest or objective marker focuses that quest, as a click does
  (again to step through its quests or turn focus off).
- A on your waypoint's star clears it. A anywhere else still sets (or
  moves) the waypoint.
- Y steps only through the markers around the crosshair, nearest first
  (up to 12). Move the crosshair to browse another spot.

Fixed
- Select keeps the map released: taking the map back with Select no longer
  leaves the game's red "No interface frame to focus!" message.
- In a group, the controller no longer jumps to the game's group window
  (the raid/party manager on the left) while the map is open - not with
  Select, and not when the group changes. Close the map to use the group
  window. (During combat the game decides.)
- In a group, after the map was released with Select, closed and reopened,
  Select takes the map again. Before, with the group window folded in, the
  game used that Select to open the group window instead.
- Should the group window get the controller anyway, it opens in front of
  the map instead of behind it.

## 1.14.7

New
- Quest tracker in Edit Mode. Open the game's Edit Mode and the tracker
  gets a blue outline: drag it to move it, drag its corner to set width
  and height. The tracker then lists the quests that fit and counts the
  rest at the bottom ("+3 more quests"). Right-click the outline to go
  back to automatic height.
- The game's gamepad and mouse and keyboard interfaces each keep their own
  tracker place and size, so it can reach the bottom of the screen in one
  and stop above the action bars in the other. Both start from where the
  tracker was before.
- Focus waypoint: while a quest is focused, a purple diamond on the
  minimap shows where to go - its nearest unfinished objective, or where
  to turn it in once it is ready. It is separate from your own waypoint
  (the star), stays on the minimap's edge when out of range, and is gone
  when you stop focusing. Settings > Minimap > Focus waypoint (on by
  default).
- WalkMap follows the game's interface. Switch between the mouse and
  keyboard and the gamepad interface, and after the game reloads, the map
  and How you play match the new one (Both with the gamepad UI, Mouse and
  keyboard without it; Controller stays Controller). Should the game not
  reload by itself, WalkMap offers a Reload button.
- What's new shows again for this update, with a Try it button for
  Select keeps the map released (for controller players) and where to
  report bugs: the comments on WalkMap's CurseForge page.

Changed
- With the game's mouse and keyboard interface (its gamepad UI off), the
  map is no longer locked in combat. You can open, close, move and resize
  it and use the footer and Settings during a fight. Settings that touch
  the game's minimap, key bindings or its own quest tracker still wait
  until combat ends. With the gamepad UI on, nothing changes.
- The quest tracker no longer runs past the bottom of the screen, also
  without a set height.
- A width dragged in Edit Mode shows as Custom under Settings > Quest
  tracker > Width; cycling the row goes back to narrow, normal and wide.
- Hide game quest tracker: if the game shows its own tracker during a
  fight, it now stays invisible until WalkMap can hide it after combat
  (as Questie 12.10 does).
- Share in the quest log waits until combat is over, since the game
  blocks sharing during a fight.
- Works with Questie 12.10 and QuestieDB 1.1.2, whose new Forever data
  also makes WalkMap's quest XP more accurate.

## 1.14.6

New
- Settings > Controller & help > Select keeps the map released (off by
  default). Leave the map with Select and it stays released, also when you
  close and open it again, so you keep control of your character. Press
  Select to take the map back; from then on it takes focus on open again.
  Also offered on the welcome page when you play with a controller.

## 1.14.5

Fixed
- With the Stone, Wood or Leather look, the round game minimap could get
  a square frame around it after login, until a minimap setting was
  changed. The frame now only shows around the square game-terrain
  minimap.

## 1.14.4

New
- How you play: mouse and keyboard, controller, or both. On the welcome
  page and under Settings > Controller & help.
  - Mouse and keyboard: Pad focus and button hints off.
  - Controller: Pad focus and button hints on, and the close X in the
    map's corner is hidden.
  - Both: Pad focus and button hints on, and the close X stays.
  It replaces the welcome page's "Controller focus when the map opens".
- Long settings pages scroll, with the mouse wheel or, on the controller,
  Up/Down at the first or last row.
- New players start in the Leather and bronze look. If you have used
  WalkMap before, your look does not change.

Changed
- The settings window is tidier: nine categories instead of eleven (Quests
  on the map, Giver level, Map, Minimap, Look, Quest tracker, Profiles,
  Controller & help, Bags & vendors). Your settings are kept.
- Related settings now share one row you click through:
  - Quest areas: all quests / focused quest / off.
  - Quest icons: all quests / focused quest / off.
  - Fade while moving: off / 20% / 35% / 50% / 70% visible.
  - WalkMap minimap: off / zone artwork / game terrain.
  - Window look: Classic / Stone and gold / Wood and parchment / Leather
    and bronze.
  - Map key and wheel open: game map / WalkMap / WalkMap + quest log.
  - Auto-sell junk: off / on / on, quietly.
- Restore hidden markers restores hidden quest givers too.
- The minimap marker settings show only for the minimap you use, and Keep
  player arrow visible only while the map fades.
- Use recommended settings (welcome page) and the Look page have a real
  button, styled like the game's other buttons.
- Use recommended settings matches the authors' current setup: it also
  turns on Right-click goes a map level up, uses the game-terrain minimap
  with normal marker sizes and automatic giver level, and follows How you
  play. Quests, givers and markers you hid yourself are not touched.

Fixed
- After abandoning a quest with the controller, B on the quest's buttons
  did not go back to the quest list. It now does.

## 1.14.3

- Changed: a quest you untrack (Untrack in the quest log, or right-click in
  the tracker) is also hidden on the map and the minimaps: no quest marker,
  area, objective icons or turn-in "?". Track brings it back. The focused
  quest is always shown.

## 1.14.2

- New: account settings, under Settings > Profiles.
  - Save as account settings stores all of this character's WalkMap
    settings for your account.
  - Load account settings uses them on another character (click twice; the
    interface reloads).
  - New characters use account settings: a character's first login with
    WalkMap starts from them.
  - Quest focus, waypoint, hidden markers and quests removed from the
    tracker stay with each character.
- Fixed (workaround for a game bug): with a controller, taking an item from
  the mailbox or buying a quest item could raise a Lua error in the game's
  own code (SoftCursor.lua:174 "attempt to perform arithmetic on local
  'inX'") and leave the controller without UI control until /reload.
  WalkMap now keeps the game's quest log from reacting to quest log updates
  while the game's map is closed. It works as normal when the map is open.

## 1.14.1

- Fixed: Untrack in WalkMap's quest log did nothing for WalkMap's quest
  tracker. It now removes the quest from the tracker, and Track brings it
  back.
- New: right-click a quest in the tracker to remove it from the tracker.
- The focused quest is always listed, and a removed quest is forgotten when
  it leaves the quest log.

## 1.14

- New: click a quest's marker on the map - its "?" or one of its objective
  icons - to focus that quest. Click the marker again to show all quests.
  A marker shared by several quests steps through them.
- New: middle-click the map or a marker to set a waypoint there. Alt-click
  now also works on a marker. Right-click and Alt-click on the map work as
  before.
- Changed: when you close the map and open it again, it shows the zone you
  are in instead of the last map you looked at.
- New setting, Map & minimap > Right-click goes a map level up: right-click
  a zone map to open the continent instead of setting a waypoint. Off by
  default.

## 1.13.4

- New: link quests in chat. With the chat line open, Shift-click a quest in
  WalkMap's quest log or in the quest tracker to put it in at the cursor.
  The quest log also has a Link button, so it works with a controller. If
  the chat line is closed, WalkMap keeps the quest for 30 seconds and puts
  it in when you open the chat line.
- Fixed: a block from the game while WalkMap replaced the game's map or
  quest log could switch WalkMap's controller navigation to the fallback
  mode for the rest of the session. It now keeps the native mode.

## 1.13.3

- Fixed: the minimap tooltips from 1.13.2 did not appear. They now use
  WalkMap's own tooltip window instead of the game's shared one, which the
  game closes by itself over the minimap.

## 1.13.2

- New: tooltips on the minimap. Move the mouse over one of WalkMap's
  markers on the minimap to see what it is: a quest giver and the quests
  offered, a trainer or vendor, an objective and its quest, or a quest
  that is ready to turn in. Works on all three minimap views.

## 1.13.1

- Changed: a quest giver that only offers dungeon or raid quests now has
  its red "!" on the minimap too, not just on the large map.

## 1.13

- New (controller): in the quest log, D-pad Left and Right on a quest turn
  the page and keep the same row, looping from the last page to the first
  and back. With more than one page, Right no longer moves to the action
  buttons; A does that.
- New (controller): in map control the crosshair can reach the whole map
  at any zoom. Where the map cannot scroll (zoomed all the way out, or at
  an edge), the D-pad moves the crosshair instead. Zone names, A to open a
  zone, waypoints and Y's nearest marker all follow the crosshair.
- Changed (controller): in map control the D-pad no longer jumps a step at
  a time. A tap nudges the crosshair a tiny bit, for picking exact
  coordinates; holding a direction moves it smoothly, slowly at first and
  then faster.
- Under the hood: removed code that was no longer used.

## 1.12.2

- Fixed: a quest that is ready to turn in could be missing its "?" on the
  minimap (game minimap view) while the large map showed it. WalkMap left
  it to the game for quests the game tracks, and the game usually draws
  none. The "?" is now always drawn; in the few places where the game
  draws its own, you may see two.
- New: the quest tracker can show 10 or 15 quests (Settings > Quest tracker >
  Quests shown: 5, 8, 10, 12, 15 or 20).
- Fixed: quests that QuestieDB has no objective locations for (quests new
  to Forever, such as Brewer's Trade) showed nothing on the map for where
  to go. The game's own quest marker is now shown for such a quest, also
  when Quest icons are off.
- Fixed: such a quest could show a marker where it is handed in, as if
  that were its goal. That stand-in is now only used for quests without
  any objectives (deliveries, the sleeping bag chain).

## 1.12.1

- Fixed: in the quest log with controller focus on, clicking a quest with
  the mouse and then moving the mouse down selected whichever quest the
  mouse passed last, so the action buttons applied to the wrong quest.
  Hovering now only previews; the clicked quest stays selected.

## 1.12

- New: objects that start quests now get a "!" on the map and minimap,
  like NPC quest givers: wanted posters, notes, crates and the Burned-Out
  Remains that begin the sleeping bag quest chain. The same level, class,
  race and prerequisite rules apply as for NPCs.
- New: turn-in places from QuestieDB. A quest that is ready to hand in but
  that the game puts no "?" on (quests handed in at an object, such as the
  steps of the sleeping bag chain) now gets its "?" on the map and minimap
  where QuestieDB says it is handed in; the tooltip names the place.
- New: quests with nothing to kill, collect or reach (deliveries, the
  sleeping bag chain) now count as quests of the zone where they are handed
  in: the tracker lists them there and Show on map opens that zone.
- Hidden-quest list updated from Questie 12.9.0: 8 more quests are hidden
  (six that only exist in Season of Discovery, and the two "A Sealed
  Crate" quests on maps).

## 1.11

- New: click into the map. On the world map, click a continent to open it;
  on a continent, click a zone. What a click opens is outlined on the map,
  and the name under the mouse shows it with the zone's level range, e.g.
  "Duskwood (18-30)", coloured for your level. Dragging to pan still pans.
  With controller focus on the map, the outline and name follow the mouse
  for a few seconds after it moves.
- New: one map level back up. A button with a gold arrow and the name of
  the map above ("Eastern Kingdoms"), in the map's top-left corner, opens
  the continent from a zone and the world from a continent; right-click on
  a continent or the world map does the same. The button can be hidden
  under Buttons. On zone maps right-click still sets a waypoint; on a
  continent use Alt-click for a waypoint.
- Controller: in map control, A on the world or a continent opens the
  continent or zone under the crosshair, which outlines it and shows its
  name and levels; on zone maps A still sets a waypoint. To go back up,
  zoom all the way out and press LB once more.
- Fixed: the quest tracker could list quests from a neighbouring zone as
  quests for this zone (for example Duskwood quests while in Westfall).
  The game's map counts everything inside the map's rectangle, and
  Westfall's map reaches into western Duskwood. Quests filed under another
  zone in the quest log now stay with that zone, unless WalkMap's quest data
  places their objectives only here. The same applies to the "quests on
  this map" list in the Quests menu.
- New: nearby quests in the tracker. Those neighbouring-zone quests that
  reach into the map you are on get their own "Nearby: Duskwood" group
  with distance. Settings > Quest tracker > Quest tracker now cycles
  Off / This zone / This zone + nearby / All zones; "This zone" users are
  moved to "This zone + nearby" once.
- Fixed: the debug report named an old version; it now shows the installed
  one.
- Under the hood: WalkMap.lua is split up (map levels, fade, commands and
  the Buttons menu are their own files), tests that run outside the game
  live in tests/, and tools/Release/check.py checks a release before it is
  packed.

## 1.10

- Fixed: after the map changed layer (around NPC or game windows), Settings
  and WalkMap's menus could end up below the map's frame.
- Game windows opened while the map is up (talents, spellbook, character,
  collections and other game panels) now appear on top of the map. Opening
  the map again brings it back in front.
- Fixed: with Stone, Wood or Leather, the frames around the minimap and the
  quest tracker showed on top of game windows such as Talents.

## 1.09

- New: window looks. Settings > Look offers Classic (the game's window art
  and red buttons, as before), Stone and gold, Wood and parchment, and
  Leather and bronze. "Apply now" reloads the interface to use the choice.
  The looks cover the map window, its buttons, menus and close buttons, the
  quest log, Settings, the zone tracker (material backing, a title band and a
  metal frame, all following the tracker's Background setting; Settings >
  Look > Frame around the quest tracker turns the frame and band off) and the frames of both WalkMap minimaps; the map and
  its icons are unchanged.
- With one of the new looks, the button under the controller or mouse gets a
  gold glow.
- Moving the map: drag the zone title (a click still opens the zone picker)
  or, with one of the new looks, the metal border around the map.
- New "Buttons" menu in the map footer, next to Settings: tick off the map
  buttons you do not need (Pad focus, zone title, DB, close button, Places,
  Clear view, WalkMap mini, Follow, quest log book, Quests, M+/M- and
  the coordinates) for a cleaner map. "Show all" and "Hide all" at the end.
  Settings and the Buttons menu itself always stay. Remembered per character.
  With the controller, the map starts on the first button that is shown.
- The footer's Player button is gone: Follow now does its job. While Follow
  is paused or another zone is shown, Follow brings the map back to you (its
  label then reads "Paused"); turning Follow on also returns to your zone.
  Quests moved to Player's place on the right, and the coordinates are
  centred again.
- The welcome page asks for a window look.
- New Settings page "Look"; the artwork is WalkMap's own (Skins/, drawn by
  tools/Skins/gen_skins.py).

## 1.08

- Fixed: a turn-in could show as two "?" on the game's minimap (one from the
  game, one from WalkMap, in slightly different colours). For quests in the
  game's own tracking list, the game already draws the "?", so WalkMap no
  longer adds its own there. Other turn-ins keep WalkMap's "?".
- "Hide game quest tracker" now also stops the game from adding new quests to
  its own tracking list (the game's "autoQuestWatch" setting). Your earlier
  setting comes back when you turn the option off.
- Fixed: pressing A on a quest in the quest log sometimes did not move to
  the buttons below (Focus, Track, Show on map...). It happened on the one
  row where the hidden mouse pointer was resting.
- The minimaps also show only one "?" when the game lists the same quest twice
  at almost the same spot.

## 1.07

- Quest XP: the zone tracker, the quest log list and quest giver tooltips
  show how much experience each quest gives at your level ("460 XP"), using
  QuestieDB's quest XP data and Questie's level scaling. Hidden at max level;
  temporary XP buffs are not counted. Settings > Quest tracker > Quest XP
  turns it off.
- Settings is a little taller, so a page can hold eight settings.
- The What's new page now lists only the changes in the latest update, and
  shows once more for this one.
- Hidden-quest list updated from Questie 12.7.0: 25 more quests are hidden
  (5 quests that are not in the game, a promotion quest only available in
  Asia, "An Unfortunate End", and 18 Season of Discovery "Duskwood Mission"
  quests). 2518 quests in total; none were removed.

## 1.06

- Fixed: after visiting a mailbox, WalkMap stayed in the "NPC window open"
  layer for the rest of the session, so the controller's action bars, target
  buttons and D-pad labels covered the map and quest log. While you really
  talk to an NPC, the map now also stays above those buttons.

## 1.05

- Controller button hints: while the controller has focus on WalkMap, a
  line at the top of the map says what A, B, X and Y do right now (map,
  quest log or menus). Map control keeps its own line. Turn it off under
  Settings > Controller & help > Button hints.
- What's new: after an update, the first time you open the map shows a short
  page with the highlights (once per version, never in combat). New players
  get the welcome page instead. /walkmap news shows it again.
- "Use WalkMap instead of game map" (map key, quest log key and the gamepad
  wheel's Quest & Maps open WalkMap) is now on by default for new installs.
  If you already have WalkMap, your current choice is kept.
- Fixed: while you talk to an NPC, the map and quest log no longer end up
  behind the controller's action bars, target buttons and D-pad labels.
- The QuestieDB status row moved out of Settings > Controller & help to make
  room; hover the DB badge on the map or type /walkmap db.

## 1.04

- Quest givers: the tooltip shows each offered quest's level, coloured
  against your level, and marks dungeon and raid quests. A giver whose
  quests are all dungeon or raid quests has a red "!". Quest tags the game
  has not loaded yet are requested and filled in a moment later.
- Tooltips no longer say "Possible quests (QuestieDB)" or "Possible herb/ore
  location": QuestieDB is accurate enough that the hedge only added noise.
- Fixed: settings changes and hidden markers now reach the minimaps right
  away (an older duplicate function made them wait for the next 2-5 second
  refresh).

## 1.03

- Zone tracker: distance to each quest in your zone ("230 yd", updated every
  second) and nearest quests first; tags such as Elite, Group 3 or Dungeon
  after the title.
- Quest colours in the tracker, quest log and Quests menu use the game's
  own difficulty level for each quest.
- Quest log tags (Elite, Group 3, Dungeon...) come from the game's quest tag
  and suggested group size.
- Places: flight masters whose flight path you have not discovered yet are
  greyed out with a red tint, and their tooltip says so.
- New: Settings > Map & minimap > Waypoint to turn-ins (off by default). When
  a quest becomes ready to turn in, the waypoint is set where the game says
  to hand it in.
- Clean-up: one shared place for quest facts (WalkMap_QuestInfo.lua); removed
  a call to a function Forever does not have; debug report has a new
  "Quest info" line.

## 1.02

- Welcome page: "Use recommended settings" now looks like a button - a
  framed gold row with an "Apply >" badge, which turns green and reads
  "Applied" while the recommended settings are in use. Its description is
  shorter so it no longer runs into the row below.
- Hidden-quest list updated from Questie 12.6.5: 8 more quests are hidden
  (6 quests Questie now treats as removed, 2 legacy-reward quests hidden on
  the map). 2493 quests in total.
- Quest log: "Show on map" now works for more quests. When QuestieDB has no
  objective locations (talk-to and delivery quests), it uses the game's own
  map for the quest, the game's next waypoint (often the turn-in), or the
  zone the quest is filed under in the quest log.
- Quest log: "Show on map" also makes that quest's markers pulse with a gold
  ring on the large map (QuestieDB icons and the game's quest and turn-in
  markers) until you close the quest log or choose another quest.

## 1.01

- Waypoints anywhere: right-click any empty spot on the map (Alt-click still
  works). In map control (X), A sets a waypoint at the crosshair when no
  marker is selected; Player/Center in the footer still centres the map.
  Right-clicking a marker still hides it.
- Escape closes an open WalkMap menu, then Settings, then the map. It is
  only taken while the map is open and never during combat.
- NPC windows (gossip, quests, vendors, trainers, flight masters, bank, mail,
  auction house, tabard, stable, trade) now appear above the map.
- Welcome page: "Use recommended settings" applies the authors' setup
  (WalkMap replaces the game map, quest log and tracker, with the gamepad
  wheel opening the map only; controller focus; quest icons; Follow;
  fading at 35% with the arrow kept; square game-terrain minimap with
  markers on the game minimap; group messages for finished objectives).
  It shows "On" while in use and leaves places, giver level, sizes and
  positions alone.
- The welcome page now asks separately about game quest areas, the player
  marker halo and auto-selling grey items.
- Debug report: new "Window layer" line.

## 1.0 — first public release

WalkMap's first release, after a long series of private test builds (their
detailed notes are in docs/CHANGELOG-test-builds.md).

- Zone map with zone, continent, world and dungeon browsing, zoom, pan,
  Follow, Clear view and saved size and position.
- QuestieDB quest icons with progress, monster levels, drop rates, elite and
  rare marks, patrol routes and next quest in the chain; quest givers filtered
  for faction, class, race, level, professions and quest history, plus
  Questie's list of hidden quests.
- Places: trainers, vendors, inns, flight masters, banks, auction houses,
  stable masters, herbs and ore.
- Quest focus, WalkMap's own quest log, and a zone quest tracker that can
  replace Forever's tracker.
- Waypoints, corpse marker, party members and an optional message to your
  group when you finish objectives.
- WalkMap minimap (zone artwork or square game terrain) and markers on the
  game's own minimap.
- Controller support through Forever's native navigation, direct map
  control (X), marker browsing (Y) and the gamepad wheel's Quest & Maps.
- Combat: the map, zone picker, Places, Clear view, Follow and quest log work
  with the mouse; your WalkMap key opens and closes it; optional close when
  combat starts.
- Welcome page with the most important settings on first login.
- Bag sorting and optional grey-item auto-sell (from SortPants).
- New in 1.0 compared with the last test build: /walkmap guide and
  /walkmap welcome commands, a rewritten README, and a refreshed in-game
  guide.
- License: GPL-3.0-or-later.
