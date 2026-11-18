Releasing WalkMap (nothing in this folder is loaded by the game)

Before you pack a version, from the WalkMap folder:

  1. Version. Set the new number in three places:
       WalkMap.toc      ## Version: 1.14
       README.txt       first line, "WalkMap 1.14 - ..."
       CHANGELOG.md     new "## 1.14" section at the top
     The debug report reads its version from the TOC.

  2. What's new page (WalkMap_Extras.lua). Only for releases with something
     new for players; a fix-only release leaves it alone.
       - replace the "__news" rows with this release's changes only
       - the page title "What's new in WalkMap 1.14"
       - local NEWS_VERSION = "1.14"

  3. README.txt and the in-game guide: describe new or changed features.

  4. Questie updated? Regenerate the hidden-quest list (see
     ../QuestBlacklist/README.txt). The Questie version is written in four
     places; gen.lua writes one, the check below compares all four:
       WalkMap_QuestBlacklist.lua, WalkMap_QuestRules.lua,
       THIRD_PARTY_NOTICES.txt, tools/QuestBlacklist/README.txt

  5. New Lua file? Add it to WalkMap.toc, and to tests/run.lua if it is a
     test file.

  6. Run the check:
       python3 tools/Release/check.py
     It compares the versions above, checks the TOC against the files,
     counts main-chunk locals (Lua allows 200 per file), looks for functions
     defined twice, and runs the Lua syntax check and tests/ when a Lua
     interpreter is installed. "Ready to pack" means no errors.

  7. Pack:
       python3 tools/Release/check.py --zip ..
     writes WalkMap-<version>.zip next to the WalkMap folder, only when the
     check passes.

  8. In the game, before uploading: /reload, open the map, /walkmap debug,
     and try what changed. The tests run in a stand-in for the game client;
     they do not replace this.

The tests alone:  lua tests/run.lua   (any Lua 5.1-5.4, LuaJIT or texlua)

License: GPL-3.0-or-later, see ../../LICENSE.txt.
