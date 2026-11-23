Regenerating WalkMap_QuestBlacklist.lua (not loaded by the game)

1. Download Questie and unpack it so you have its "Questie" folder.
2. From this folder run, with any Lua 5.1-5.4 interpreter:
     lua gen.lua /path/to/Questie ../../WalkMap_QuestBlacklist.lua 12.12.0
   (the last argument is the Questie version, written into the header).
3. Check the printed counts and reload the game.

The script evaluates Questie's blacklist the way Questie does on WoW
Forever (Era content) and writes one Lua table of quest IDs.
License: GPL-3.0-or-later, see ../../LICENSE.txt.
