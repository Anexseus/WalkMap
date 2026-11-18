# WalkMap 4.94 — author aliases

- Authors are now credited by their aliases, Anexseus and Underbuks, in the
  TOC, LICENSE.txt, README, every file header and the changelog.
  SortPants (bag tools) is credited to Underbuks. No code changes.

# WalkMap 4.93 — Follow pauses instead of switching off

- Panning the map (mouse drag or controller map control) now pauses Follow
  instead of turning it off. The button shows "Follow: Paused". Follow
  picks up again by itself 15 seconds after the last pan, or at once when
  you leave map control (X/B), press Center or the Follow button, or close
  the map. If Follow was off, panning changes nothing.

# WalkMap 4.92 — welcome page fix

- Fixed: the welcome page did not appear; the map and settings opened with a
  Lua error ("WalkMap_Extras.lua:2193: attempt to index local 'page'").
  ShowWelcome was written above the line that defines the welcome page's
  index, so it saw nil. The index is now declared before it.
- The welcome page now counts as seen only once it is actually on screen,
  so anyone who hit the error in 4.90/4.91 gets it on the next login.
- The settings window falls back to the first page instead of erroring if
  it is ever asked for a page that does not exist.
- Checked every WalkMap file for other names used above their definition:
  none.

# WalkMap 4.91 — quest display on the welcome page

- Welcome page: new choices for how quests are shown on the map,
  "QuestieDB quest icons" and "Game quest areas", each cycling All quests,
  Focused quest and Off (same settings as Quest markers and Quest areas).
  Fade while moving and Quick guide left the page to make room (both remain
  available: Settings > Player & group, and /walkmap guide).

# WalkMap 4.90 — welcome page, close on combat, wheel closes

- Welcome page: the first time you log in with WalkMap (once per account),
  WalkMap opens with a "Welcome to WalkMap" settings page: Use WalkMap
  instead of game map, Controller focus when the map opens, Quest tracker,
  Hide game quest tracker, Close map when combat starts, Fade while moving
  and Quick guide. Controller focus starts on the first choice. Reopen it
  from Settings > Controller & help > Welcome setup (replaces the Quick
  guide row; /walkmap guide still prints the guide).
- New: Settings > Map & minimap > Close map when combat starts (off by
  default). WalkMap's secure combat handler closes an open map as a fight
  begins; you can open it again during the fight and it stays open.
- Quest & Maps in the gamepad wheel (and the game's map/quest log keys)
  now close WalkMap when it is already open, with "Use WalkMap instead of
  game map" on. Out of combat only.

# WalkMap 4.89 — top buttons in combat

- Fixed: the 4.88 build lost WalkMapCombat.Locked/Passive/Ready when the
  combat controller layer was removed, which would have broken WalkMap on
  load. Do not use 4.88.
- With the mouse in combat: the map picker in the title, Places, Clear view,
  Follow, the quest log book and the quest log, and the DB badge. They are
  lifted above the combat shield while it is up. Their menus and the quest
  log open directly (mouse only) instead of through the game's controller
  navigation, which is restricted in combat; any still open are handed to
  it when combat ends.
- Still locked in combat: moving/resizing, the footer, settings, and the
  Minimap button (game-terrain mode hides parts of the game's minimap).

# WalkMap 4.88 — mouse on the map in combat

- The combat shield now covers only the title bar, footer and edges. On the
  map itself you can hover markers for tooltips, zoom with the wheel, drag to
  pan and Alt-click for a waypoint. Moving, resizing and settings stay locked
  (the window is protected in combat). Controller input in combat is
  unchanged: the controller stays with the game.

# WalkMap 4.87 — GPLv3

- WalkMap is now licensed GPL-3.0-or-later (LICENSE.txt, full text in
  COPYING.md), replacing the earlier custom "personal use" terms. This makes
  it possible to publish WalkMap with the quest blacklist derived from
  Questie (GPLv3).
- THIRD_PARTY_NOTICES.txt credits the Questie contributors for the blacklist
  data, states what was changed, and that WalkMap is not made or endorsed by
  the Questie team. pfQuest icons stay MIT (GPL-compatible).
- Every WalkMap source file starts with an SPDX GPL-3.0-or-later line and a
  copyright notice.
- tools/QuestBlacklist/ (gen.lua + README) is the source used to regenerate
  WalkMap_QuestBlacklist.lua with any Lua interpreter. Not loaded in game.
- No gameplay changes; the blacklist data is unchanged (2485 IDs).

# WalkMap 4.86 — corpse marker

- When you die, a skull marks your corpse on WalkMap (zone, continent and
  world maps when the game can place it) and on both minimaps, kept at the
  minimap edge when it is out of range. While you are dead or a ghost the
  direction badge shows "Corpse: <direction> <distance>". Everything goes
  away when you are alive again (corpse recovered, resurrected or spirit
  healer). Uses the game's corpse position when available, otherwise the
  spot where you died (saved per character, survives /reload).
- Debug report: new "Corpse" line.

# WalkMap 4.85 — monster levels in objective tooltips

- Hovering a kill objective, or a loot objective with a named drop source,
  now shows the monster's level from QuestieDB, e.g. "Level 15-16",
  coloured like quest difficulty for your level (grey, green, yellow,
  orange, red). Elite/rare labels follow on the same line.

# WalkMap 4.84 — zone tracker keeps its top edge

- The zone tracker is always pinned by its top edge, so when the list gets
  shorter it shrinks from the bottom. After Alt-drag it is anchored at the
  top left or top right (whichever half of the screen it is in). A position
  saved by an earlier version is converted the first time it is shown.

# WalkMap 4.83 — fixes

- Fixed a Lua error when hovering a quest icon whose quest has a follow-up:
  "WalkMap.lua:1362: attempt to concatenate local 'nextName' (a nil value)".
  The next quest's name was lost by an "a and f()" expression.
- The class group in Places now shows your own class icon (same mistake).

# WalkMap 4.82 — tell your group about quest progress

- Settings > Player & group (was Player & fading) > Tell group about quest
  progress: Off (default), Finished objectives, or Every step. Messages go
  to party chat (raid chat in a raid) only while you are grouped, e.g.
  "WalkMap: 5/5 Great Goretusk Snout - Redridge Goulash" and
  "WalkMap: Redridge Goulash is ready to turn in". New quests and the first
  quest-log reading after login are never announced; repeats within 3
  seconds are sent once.
- If Questie's own announcements are on, turn one of them off to avoid
  double messages.
- Debug report: new "Group announcements" line.

# WalkMap 4.81 — map redirect timing

- "Use WalkMap instead of game map": the game's map is now closed about
  0.1 s later (still invisible meanwhile). Closing it on the very next
  frame beat the game's own deferred gamepad focus on the quest map, which
  then failed in Blizzard_GamepadSoftCursor/SoftCursor.lua:174
  ("attempt to perform arithmetic on local 'inX'").

# WalkMap 4.80 — only WalkMap's focus; cleaner tracker header

- The map no longer falls back to the game's tracked quest when WalkMap has
  no quest focus. "Focused quest" areas and "Focus icons only" now follow
  WalkMap's own focus only.
- Zone tracker header shows just the zone name (no counts).

# WalkMap 4.79 — WalkMap's quest focus is independent

- WalkMap's quest focus (footer Quests, or Focus in WalkMap's quest log) no
  longer follows focus changes in the game's own quest log or tracker.
  Focus only ends when you clear it in WalkMap or the quest leaves the log.
  The zone tracker's top quest is always WalkMap's focus.

# WalkMap 4.78 — tracker: all zones option

- Settings > Quest tracker > Quest tracker now cycles Off, This zone and
  All zones. All zones lists your current zone's quests first, then the
  rest of the quest log grouped under grey zone names in quest-log order.
  The header shows e.g. "Westfall 3 +7 other". The focused quest stays on
  top. Quests shown (5/8/12/20) still limits the total.

# WalkMap 4.77 — faster zone tracker updates

- New quests appear in the zone tracker within about a second. The game
  often reports a quest change before the new quest can be read from the
  log; the tracker now listens to accept/remove/turn-in events and redraws
  again 0.3, 1 and 2.5 seconds later. A slow 5-second redraw catches
  anything else.

# WalkMap 4.76 — hide the game quest tracker (optional)

- Settings > Quest tracker > Hide game quest tracker (off by default): hides
  Forever's objective tracker while WalkMap's zone tracker is on, the same
  way Questie does it. Forever shows its tracker again when you accept a
  quest; WalkMap hides it again at once. If the game tracker is protected,
  hiding and restoring wait until combat ends. Turning the option (or the
  zone tracker) off gives the game tracker back.
- While the game tracker is hidden and you have not moved WalkMap's tracker,
  WalkMap's tracker takes the game tracker's old spot.
- Background on/off and darkness are now one row: Off, Light, Medium, Dark,
  Solid.
- Debug report: new "Zone tracker" line shows whether the game tracker was
  found and hidden.

# WalkMap 4.75 — zone quest tracker

- New on-screen tracker (Settings > Map & minimap > Zone quest tracker, on by
  default): your quests for the current zone with objectives and progress.
  A quest counts for the zone if it is filed under the zone in the quest
  log, shown on the zone's map by the game, or has QuestieDB locations there.
  WalkMap's focused quest first (star), then quests ready to turn in, then by
  level; up to 12 quests.
- Click a quest to open WalkMap with it selected in the quest log.
  Alt-drag the header to move the tracker (saved per character);
  Alt-right-click resets its position.
- New settings page "Quest tracker": on/off, show objectives (off: titles
  only, with "(ready)"), background on/off, background darkness (light,
  medium, dark, solid), text size (small, normal, large, extra large),
  quests shown (5, 8, 12, 20) and width (narrow, normal, wide). Changes apply
  immediately.
- Settings categories are slightly tighter (35 px steps) to fit ten pages.
- Read-only: it does not hide, move or change the game's own quest tracker.

# WalkMap 4.74 — no game super-tracking from WalkMap

- Fix attempt for random "WalkMap has been blocked" popups while killing quest
  mobs or using quest objects, even with WalkMap closed: WalkMap's quest focus
  (footer Quests, quest log Focus) no longer sets the game's super-tracked
  quest. Setting it from addon code ran the game's tracker code tainted, and
  Forever then blocked SetPreferredGamepadInteractTarget on later quest
  interactions. Focusing a quest in the game's own tracker still updates
  WalkMap's focus while one is set.

# WalkMap 4.73 — quest blacklist without Questie

- New WalkMap_QuestBlacklist.lua: Questie 12.6.1's quest blacklist,
  evaluated for WoW Forever (Era content): 2393 hidden quests and 92 hidden
  on maps. Used for quest givers when Questie is not loaded; when Questie is
  loaded its live list is used instead (it also follows active events).
  QuestieDB stays the data source for everything else.
- The file is a copy of GPLv3 Questie data, kept for personal use; regenerate
  it when Questie updates.
- Debug "Quest visibility policy" names the list in use.

# WalkMap 4.72 — zone level in the title

- The map title shows the zone's typical level range, e.g.
  "WalkMap - Westfall (10-20)", coloured like the zone chooser: red-ish when
  above you, grey when below, warm white when it fits. Zones without a known
  range (cities, world/continent, dungeons) show no range.

# WalkMap 4.71 — player arrow on top of everything

- Large map: the player arrow (and halo) is above every marker, turn-ins
  included (turn-ins stay above all other markers).
- Zone-art minimap: the arrow keeps the top layer alone; turn-ins and the
  waypoint move one layer down, party dots below them.
- Game terrain minimap: the client draws its arrow under WalkMap's markers,
  so WalkMap draws the same arrow on top at the centre (hidden when WalkMap
  markers are hidden, e.g. with a rotating minimap).

# WalkMap 4.70 — turn-in markers on top

- Quest turn-in markers (ready to turn in) are drawn above every other
  marker on the large map (also above the player arrow and waypoint) and on
  both minimaps.

# WalkMap 4.69 — move between the map and the quest log

- Controller: Left anywhere in the quest log (list, zone filter or buttons)
  moves focus to the quest log button on the map; the log stays open.
- Right from the map's quest log button, while the log is open, moves focus
  into the log on the last selected quest. If the client does not allow
  that switch, the log is reopened instead (same result, brief redraw).
- B from the buttons still returns to the selected quest; B in the list
  closes the log.
- Debug report: "map<->quest log=" shows whether the focus switch worked.

# WalkMap 4.68 — combat macro, quest log back, fading options, turn-ins

- Macro: /click WalkMapCloseMacro closes WalkMap, also in combat (secure,
  like the WalkMap key). /click WalkMapKeyboardToggle toggles it.
- Quest log: B on the action buttons (or in Full text) returns to the last
  selected quest; B in the list closes the quest log. Left from a button and
  reopening the log also land on the last selected quest. The close button
  (X) is removed; the zone filter moves to the corner.
- New settings page "Player & fading": Player marker halo, Fade while moving,
  Fade strength (20/35/50/70% visible) and Keep player arrow visible (on by
  default; the arrow and halo ignore the fade).
- Quest turn-in markers (quests ready to turn in) now show on the large map
  and both minimaps even with Quest areas set to Hide areas or Focused.
- Settings categories are spaced slightly tighter to fit nine pages.

# WalkMap 4.67 — Y opens the quest log

- Controller: Y opens the quest log while you navigate the map's buttons,
  and closes it again while focus is in the quest log. In map control
  (after X) Y still steps through markers. Private, focus-scoped override
  like X; released for gameplay, other windows and combat.

# WalkMap 4.66 — abandon without the game's popup

- Fix: abandoning a quest from WalkMap's quest log opened the game's
  confirmation popup from addon code; controller focus moved into it
  through tainted code and the client blocked
  SetPreferredGamepadInteractTarget ("WalkMap has been blocked...").
  Abandon now confirms in the button: press once ("Confirm?"), press again
  within 4 seconds to abandon. No game popup is opened.

# WalkMap 4.65 — A on a quest goes to its buttons

- Controller: A on a quest in the quest log selects it and moves focus to
  the Focus button; Left returns to the list. Mouse clicks only select.

# WalkMap 4.64 — wheel: map only or map + quest log

- Settings > Controller & help > Wheel opens quest log too (on by default):
  the gamepad wheel's Quest & Maps opens WalkMap with its quest log, or with
  it off, the map alone. The game's own quest log window and the quest log
  key still open both.

# WalkMap 4.63 — no flash of the game map

- When the game's map or quest log is redirected to WalkMap, it is made
  invisible the moment it opens, closed on the next frame, then given its
  normal opacity back. If combat starts in between, it is simply shown.

# WalkMap 4.62 — gamepad wheel "Quest & Maps"

- The setting is renamed "Use WalkMap instead of game map". With it on, the
  gamepad wheel's Quest & Maps (and anything else that opens the game's world
  map or quest log) is redirected: WalkMap closes the game's window right
  after it opens and opens WalkMap with its quest log. Out of combat only;
  in combat the game's map opens as usual. The game's own code is not
  replaced, only followed.
- Debug report shows whether the game's map/quest log are hooked and how
  often a redirect happened.

# WalkMap 4.61 — quest log opens only on request

- Opening the map (map key, WalkMap key or any other way) always starts with
  the quest log closed, even if it was open when the map was closed.
- The quest log key opens the map with the quest log; the toolbar book
  button still opens it on demand.

# WalkMap 4.60 — zone filter fits the title band

- The All zones / This zone button is smaller (92x15) and centred in the
  quest log's title band instead of overlapping its edges.

# WalkMap 4.59 — quest log filter route

- Controller: Right from the zone filter (All zones / This zone) goes to the
  quest log's close button; Left goes back.

# WalkMap 4.58 — quest log length

- The quest log has its own height and may extend below the map. Drag the
  grip in its bottom-right corner to set the length; it is saved per
  character. Right-click the grip to match the map's height again.
- Controller focus on a quest now also selects it, so Focus/Track/Show on
  map/Full text/Share/Abandon are always shown for it. Mouse hover still
  only previews; click selects.

# WalkMap 4.57 — clearer quest log text

- Parchment text uses the game's quest fonts (QuestTitleFont, QuestFont)
  in near-black brown; objectives, rewards and the description are larger
  and darker. Finished objectives stay green, tags dark red.

# WalkMap 4.56 — quest log improvements

- Zone headers fold in and out (A or click); a folded zone shows its quest
  count. Saved per character; the game's own quest log is not changed.
- Zone filter in the title band: All zones / This zone (your current zone).
- List rows show objective progress (1/2) and level, "Done" when complete,
  and tags such as Elite, Dungeon or Group.
- Details: level and tag line, objectives, Rewards (XP, money, item icons
  with the game's item tooltip; "Choose one" for choices), then the text.
- Show on map: opens the zone with the quest's most QuestieDB locations
  (greyed with a reason when none is known).
- Full text: the parchment fills the panel with the objective summary and
  the whole description. Press again for the next part ("More text"), and
  at the end ("Back") to return. Mouse wheel scrolls the text.
- Share explains when it is unavailable (not in a group / can't be shared).

# WalkMap 4.55 — quest log paging

- "More quests" is replaced by page arrows with "Page 1/3".
- Controller: Down on the last quest of a page goes to the next page and
  focuses its first quest; Up on the first quest goes back to the previous
  page's last quest.
- Mouse: the arrows, or the mouse wheel anywhere over the quest log.

# WalkMap 4.54 — quest log redesign

- The quest log opens from a book button at the end of the toolbar, inside
  the window, so the D-pad reaches it (Right from Follow). The outside tab is
  gone; the panel's X or B closes it.
- Details sit on parchment with dark ink, like the game's own quest log;
  finished objectives in green. No more grey text on grey.
- The list gets more room (details take about 40% of the height), warm dark
  background, gold zone headers with a rule, gold bar on the selected quest.
- Hovering or moving controller focus over a quest previews its details;
  A/click selects it for the Focus/Track/Share/Abandon buttons.

# WalkMap 4.53 — quest log, world maps and map keys

- Quest log: a tab on the map's right edge folds out a panel (collapsed by
  default; uses the left side near the screen edge). Quests by zone header
  with level or Done, the WalkMap focus marked with a star, paging when the
  list is long. Details show objectives (finished in green) and the quest's
  objective text. Actions: Focus/Unfocus, Track/Untrack, Share (in a group),
  Abandon (the game's own confirmation). Controller: the tab sits at the end
  of the toolbar row; in the panel Up/Down moves in a column, Left/Right
  between the list and the actions, B folds it back in.
- Map chooser: a World group (Azeroth and the continents) first and
  "Dungeons: <continent>" groups last; multi-floor dungeons show floor names.
  Your position is shown on world and continent maps too.
- Settings > Controller & help > Use map and quest log keys (off by default):
  your own world map and quest log keys (normally M and L) open WalkMap and
  WalkMap with its quest log. Private override bindings only; your key
  bindings are not changed. The map key also works in combat (passive map).
  The gamepad radial wheel still opens the game's map and quest log.

# WalkMap 4.52 — minimap areas without blue fill

- Restoring the game minimap's areas no longer fills them solid blue: the
  fallback is fill (inside) 0 and edge (outside) 255, matching the game's
  usual edges-only look. Values the client writes itself still take priority.
- The focused-quest area WalkMap draws on the square minimap is edges only.
- /reload restores the exact game defaults at any time.

# WalkMap 4.51 — focused minimap area; quest log sync

- Square Game terrain minimap + Quest areas "Focused quest": the game's own
  all-quests minimap areas are hidden and WalkMap draws only the focused
  quest's area with the game's QuestPOIFrame, clipped to the square. The round
  minimap cannot be clipped round, so there the game keeps drawing its areas.
  "All quests" uses the game's drawing; "Hide areas" hides it.
- Quests (footer) now also focuses the quest in the game's quest log/tracker.
  While a WalkMap focus is set, focusing another quest in the game updates
  WalkMap; clearing it in the game clears WalkMap's focus.
- Removed the 4.48 one-time super-track cleanup (it would fight the sync).
- Debug report: "WalkMap focus area:" shows the drawn quest or a failure.

# WalkMap 4.50 — restore game minimap areas

- Fix: after Hide areas, choosing Focused or All left the game minimap's
  quest areas invisible. The fallback restore value was alpha 1, which this
  client treats as nearly transparent (0-255 scale). The fallback is now 255
  for area and ring alphas; values the client itself writes still win.

# WalkMap 4.49 — game minimap areas follow Quest areas

- Quest areas > Hide areas now also hides the game minimap's own quest areas
  (fill, outside shading and ring) on the round and square minimap, using the
  client's Quest/Task/Arch blob alpha setters. Focused/All leave the game's
  drawing alone. Re-applies at once if the client shows them again.
- When areas are shown again, values the client wrote are restored; if none
  was observed, alpha 1 is used. A /reload restores the exact game default.
- Debug report: "game areas:" shows hidden parts and any setter failures.
- WalkMap's own markers on both minimaps already follow Quest areas, Quest
  icons and Focus icons only.

# WalkMap 4.48 — quest-area ring

- Square terrain mode also sets the quest/task/archaeology ring scalar to 0
  (restored on exit), because alpha alone did not hide the ring of a
  super-tracked quest.
- One-time cleanup: if the game still super-tracks the exact quest that 4.46
  focused, WalkMap clears that super-track once. Your own tracking is left alone.

# WalkMap 4.47 — quest focus fixes; QuestieDB patrols, ranks and chains

- Fix: quest focus no longer turns quest areas back on when Quest areas is
  set to Hide areas. Focus only narrows what is already shown; Quest icons
  off also stays off.
- Fix: quest focus no longer super-tracks the quest in the game. That made the
  client draw the quest's own minimap area and its ring around the square
  terrain minimap.
- Square terrain mode re-hides the quest-area ring immediately when the
  client or another addon shows it again, instead of waiting for the next
  layout pass.
- Patrol routes: QuestieDB NPC waypoints for the focused quest's NPCs are
  drawn as thin lines on the large map (with Quest icons on).
- Elite marking: objective icons get a gold rim for elite/boss NPCs and a
  silver rim for rare/rare elite, from QuestieDB NPC rank; tooltips name it.
- Objective tooltips show "Next in chain" from QuestieDB nextQuestInChain.
- All QuestieDB reads stay live through the installed QuestieDB API (typed
  readers first); no Questie code or data is bundled.

# WalkMap 4.46 — quest focus, waypoints and map control

- Quest focus: a footer Quests button lists the quests with something on the
  displayed map (level or Done on the right) plus "Other quests". Picking one
  shows only that quest's icons and areas on the large map and both minimaps;
  All quests restores your own settings. Also super-tracks it in the game
  where supported. Clears itself when the quest leaves the log. Per character.
- Map control (X): Y steps through markers nearest the centre and shows their
  tooltip; A on a selected marker sets it as the waypoint (or clears the
  waypoint star); A with nothing selected still centres. A crosshair shows the
  coordinates at the centre of the view. The hint moved to the top edge.
- Waypoint: a saved star on the large map and both minimaps, held on the
  minimap edge when out of range. The map's bottom badge shows direction and
  distance (yards when the client supports it) and clears it on arrival.
  Alt-click the map to set one; right-click the star to clear it.
- Zone chooser shows typical level ranges, coloured against your level.
- Settings > Map & minimap > Fade while moving (off by default): the window
  fades while you move unless the mouse, a menu or controller focus is on it.
- Class trainers use class icons on the large map and minimaps.
- Footer and toolbar button highlights now cover the whole button.

Lua syntax loading checked for all files. Not yet tested in-game.

# WalkMap 4.45 — player halo setting

- Settings > Map & minimap > Player marker halo turns the pulsing gold ring
  around the large-map player arrow on or off. Saved per character; on by
  default. Applies on the next position update without reopening the map.

# WalkMap 4.44 — footer and header polish

- Remove the large-map + / - footer buttons; zoom with the mouse wheel or
  LB/RB in map control. Player moves right; M+ / M- remain for the minimap.
- Raise the DB badge 2 px to centre it in the header; the Zones title keeps
  its position. Lower both close buttons by 1 px.
- Make the player halo's dark core mostly transparent (alpha 0.85 -> 0.3).

# WalkMap 4.43 — dropdown styling and header polish

- Dropdowns get a warm gold-edged panel, a gold hover/focus bar with a left
  accent (also shown for native controller focus), and the game's dropdown
  arrow art for submenus instead of a typed ">". The row whose submenu is
  open stays lit, so the path through the menu is visible.
- Right-hand detail text: region pages show "A - L" instead of "(1/2)", the
  region holding your zone is tinted green, and "You are here" moves to the
  right of the zone name. Places groups show "2 on"/"All"; it updates live.
- Places rows show their icons: book, your class icon, coin; each trainer,
  class and service entry shows its own icon. Thin separators set apart
  "Current zone", "All ..." entries and "Clear all".
- Map window and Settings close buttons are smaller and lifted so the X sits
  inside the header band instead of crossing its bottom edge.
- The DB badge shrinks to a green "DB" when QuestieDB is ready; loading,
  waiting and errors still show full text. The Zones title uses the space.

Lua syntax loading checked for all files. Not yet tested in-game.

# WalkMap 4.42 — map readability and footer cleanup

- Tint QuestieDB objective icons by kind on the large map and both minimaps:
  red slay, blue object/interact, green loot, gold other.
- Merge large-map objective icons a little more when zoomed out (22 px at the
  widest zoom, 19 px at the next, 16 px above), measured from each group's
  first point so a group cannot chain wider. Merged icons sit at the average
  of their points. Zooming in separates spawn points; minimaps stay per-point.
- Give count badges a dark backing disc so the numbers stay readable.
- Enlarge the large-map player arrow and add a pulsing gold halo with a dark
  core above the quest icons.
- Remove the native-mode Controls footer button; X direct map control replaces
  it. Coordinates now stay in the footer in native mode too. Leaving pan mode
  returns focus to Player. The custom fallback keeps its Resume button.
- Add tooltips to + / - and M+ / M-, and tint M+ / M- to read as minimap zoom.
- Replace leftover "beta" wording in tooltips and error messages.

Lua syntax loading checked for all files. Not yet tested in-game.

# WalkMap 4.41 — spatial D-pad navigation and native map panning

- Route Left/Right within visible header, toolbar and footer rows; route
  Up/Down between adjacent rows. Recompute vertical targets after resizing
  and when minimap controls are hidden. Stop at the edges without wrapping.
- Use the same main-window routes in native and custom navigation, replacing
  obsolete custom-navigation indexes. Keep settings navigation in columns.
- Add explicit dropdown routes: Up/Down within a list, Right into submenus,
  Left back to the parent button. Use the client's supported static jump
  setters and outgoing callbacks without replacing native navigation methods.
- Restore X direct-map control in native mode. D-pad pans, LB/RB zooms the
  large map, A centers, and X/B returns to normal button navigation.
- Scope temporary X/LB/RB shortcuts to WalkMap's actual native focus. Release
  them for menus, settings, gameplay, other windows and close. Clear them in
  combat through a private secure state driver; retain passive combat behavior.
- Add routing and private-shortcut diagnostics. Retain the zone chooser and
  minimap ring fix from 4.40, and preserve all saved preferences.

Local tests execute the client's actual direction-override and navigation
code, focus manager, menu transitions and secure combat cleanup with mocks.
In-game controller and taint testing remains necessary.

# WalkMap 4.40 — discoverable zone chooser and native area rings

- Add a gold Zones label, a larger arrow and a hover highlight to the map title.
- Suppress the native quest-area ring in square Game terrain mode, alongside
  the compass layers. Handle task and archaeology rings when available.
- Reapply suppression after native layout updates; keep fills, area borders
  and quest markers intact. Restore observed or readable alphas on exit, using
  native alpha 1 when setter-only APIs provide no previous value.
- Contain individual ring API failures and include their status in debug output.

The ring diagnosis matches the documented waffle-pattern artifact on square
minimaps with blue quest objective areas. This build needs in-game confirmation.
All map browsing, minimap separation and combat behavior from 4.39 is retained.

# WalkMap 4.39 — map browsing and combat opening test

- Add a map-title dropdown with zones grouped by region and bounded pages.
- Highlight the player's actual zone; keep the selected map checked and saved
  per character. Current zone and Player restore automatic zone selection.
- Keep artwork and quest/place markers on both minimaps in the player's
  actual zone while browsing a different large map, using separate pools.
- Hide the native circular compass underlay as well as its foreground in
  square game-terrain mode; restore both original alphas on exit.
- Extend the existing secure WalkMap key to open and close the passive map
  repeatedly throughout combat, including when it was closed before combat.
- Preserve normal map bindings, saved Pad focus and minimap choices. Native
  focus, menus, dragging and resizing remain suspended during combat.

Local checks cover zone catalogues, separate minimap rendering, pool cleanup,
native decoration restoration and secure combat toggling. Live client testing
is still required for rendering and taint behavior.

# WalkMap 4.38 — persistent combat map test

- Keep the large map visible as a passive map while combat is active.
- Close menus and release native controller focus before combat restrictions.
- Close the map in combat with the user's existing WalkMap key or the X button,
  using preconfigured secure click handlers on WalkMap's own protected frame.
- Use private temporary overrides only for keys already assigned to WalkMap;
  retain permanent bindings and the ordinary game map binding.
- Lock settings, movement and resizing while the map is passive. Defer root
  size changes until combat ends; retain marker and player rendering.
- Restore normal navigation after combat if the map remains open. Keep a map
  closed if the player closed it during combat.
- Add combat readiness and binding diagnostics to the debug report.

Local checks execute the current client frame manager and the shipped secure
snippets with mocked engine security. Actual client testing remains necessary.

# WalkMap 4.37 — native combat window cleanup

- Match the client's native restriction check instead of treating all legacy
  combat lockdown as a forbidden native action.
- Close the large map and its menus before a native combat restriction becomes
  active, using ADDON_RESTRICTION_STATE_CHANGED's permitted cleanup window.
- Release native registration before enforcement rather than queueing the
  player's close request until the fight ends.
- Keep the map closed after combat and preserve the minimap and Pad focus choices.
- Decline reopening a previously native-managed window during an active native
  restriction, because its client OnHide hook persists after unregistering.
- Record combat transitions and the last native combat action in debug reports.
- Ignore missing menu return buttons when a closing menu has no remaining
  selection target, rather than treating the lookup callback as a button.

This uses the documented pre-restriction notification in client 1.60.1 (70790).
It needs an in-game test of being attacked with the map and a menu open.
SortPants integration, marker priority and independent zoom controls are retained.

# WalkMap 4.36 — bag tools and quest marker priority

- Integrate Underbuks' SortPants functions into Bags & vendors.
- Add per-character controls for bag sorting, auto-sell and vendor messages.
- Keep auto-sell off by default; sell only eligible gray items at an open vendor.
- Cancel queued sales immediately on disable, vendor close or combat.
- Recheck each queued bag slot and contain failed item actions.
- Add Sort bags now, a separate Sort bags keybinding and /walkmap sort.
- Preserve existing keys unless explicitly changed; support session restoration.
- Skip integrated auto-sell while the standalone SortPants addon is loaded.
- Include bag configuration and operation status in debug reports.
- Draw quest markers above shops, trainers and gathering icons on every map.
- Give quest givers priority over places when minimap spacing is enabled.

Native controller navigation, map opening bindings and independent map/minimap
zoom controls continue to use the existing implementation.

# WalkMap 4.35 — independent zoom controls and consistent map layers

- Keep + and - on the main window dedicated to large-map zoom.
- Add separate M+ and M- buttons for either WalkMap minimap mode.
- Keep the footer controls separated at narrow and wide window sizes.
- Remove WalkMap's native A Select / B Back footers without changing native
  directional focus, selection, Back or View/Select behavior.
- Reposition explored artwork, quest areas and all cached pins in the same
  update as a zoom change, instead of waiting for the periodic refresh.
- Reuse unchanged map textures and avoid forced exploration reloads on zoom.
- Apply Follow's player-centered view during the zoom update.

Native LB/RB inputs remain with the game's input system. Large-map zoom is
available through +/- and the mouse wheel, independently from minimap zoom.

# WalkMap 4.34 — separate native and custom focus state

- Prevent the custom Select pause flag from blocking native registration.
- Hand over to native navigation when its API becomes ready before processing
  a legacy controller event. The game handles View/Select in native mode.
- Keep the persistent Pad focus toggle and independent WalkMap opening key.
- Report missing native API names, manager registration, actual UI focus and
  the custom pause flag in debug reports.

This remains a native-controller test build; a screenshot alone cannot tell
whether a missing registration is caused by a client capability or a failed
native call. Debug details distinguish those cases.

# WalkMap 4.33 — experimental native controller navigation

- Register only WalkMap's standalone window and its menus with Forever's
  native frame controls through the client's wrapped focus entry points.
- Use native directional focus, selection, Back, focus switching and native
  Select/Back button prompts, without adding gamepad binding groups.
- Keep the separate WalkMap opening binding and the game's normal map intact.
- Add a Controls popup for zooming, panning, centering and marker browsing.
- Keep the saved Pad focus preference and the existing keybind/macro toggle.
- Add a native/custom navigation choice and automatic capability fallback.
- Defer restricted native focus changes in combat and stop native retries
  after a reported focus failure for the rest of that login.
- Include the selected/active controller backend in debug reports.

Requires an in-game test. The previous custom controller navigation remains
available in Settings > Controller & help or /walkmap navigation custom.
All quest giver filtering from 4.32 is included.

# WalkMap 4.32 — quest giver filtering

- Read additional quest requirements from the separate QuestieDB addon.
- Filter mutually exclusive quests, active breadcrumbs, temporarily disabling
  quests, profession skill, reputation, spell knowledge and specializations.
- Support Forever's C_SkillInfo API and QuestieDB's extended race masks.
- Refresh quest giver eligibility after skill, spell and reputation changes.
- Show candidate quest names and IDs on giver tooltips and in debug reports.
- Include QuestieDB's version, contract and available visibility policy in reports.
- Respect Questie's loaded quest blacklist when Questie itself is enabled;
  Questie remains optional and its code/database is not bundled.

Unknown or restricted client information remains unknown. QuestieDB alone does
not expose Questie's separate event/blacklist policy, and locations remain
possible spawns rather than a guarantee that the server currently offers a quest.

# WalkMap 4.31 — initial public release

Controller-friendly map and optional minimap views for the WoW Forever beta.

- Movable, resizable zone map with zoom, panning, player follow and Clear View.
- Controller navigation for map controls, menus, settings and marker browsing.
- Saved Pad focus preference, optional focus keybind and macro toggle.
- Minimap button cycles Off -> Game terrain -> Zone artwork -> Off.
- Enlarged square live game minimap or independently zoomed zone-artwork preview.
- Optional WalkMap markers on the normal game minimap.
- Shared filters for WalkMap markers and configurable minimap marker size,
  spacing and radius.
- All/focused/hidden quest areas and separate focused-only objective icons.
- Quest giver filters, quest progress tooltips and available drop estimates.
- Profession and class trainers, vendors, inns, flight masters, banks,
  auction houses, stable masters, pet trainers and known gathering locations.
- Individually hidden markers, nearest focused location helper and profiles.
- Per-character preferences, database status, quick guide and debug reports.
- Terrain redraws after minimap mode changes while standing still.
- Debug report copy window uses direct user text focus; chat export is available.

Packaging for this public release adds credits, license notices and current
installation documentation. The Lua files and Bindings.xml are identical to
the tested 4.31 release candidate. QuestieDB is an external dependency.
