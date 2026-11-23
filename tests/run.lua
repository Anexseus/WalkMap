-- SPDX-License-Identifier: GPL-3.0-or-later
-- WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
-- Runs WalkMap's tests outside the game.
--   lua tests/run.lua            (from the WalkMap folder; any Lua 5.1-5.4,
--   lua tests/run.lua t_maps      LuaJIT or texlua works)
-- Each tests/t_*.lua file returns a list of {name, function(Mock)} cases.
-- tools/Release/check.py runs this as part of the release check.
local source = debug.getinfo(1, "S").source
local dir = source:match("^@(.*[/\\])[^/\\]+$") or "./"
local Mock = dofile(dir .. "mock.lua")
local FILES = {"t_maps", "t_levels", "t_tracker", "t_xp", "t_livedb", "t_turnins", "t_questlog", "t_minihover", "t_link", "t_clicks", "t_guard", "t_account", "t_settings", "t_miniframe", "t_release", "t_freewindow", "t_focuswaypoint", "t_social", "t_groupprogress", "t_givertint", "t_dungeons", "t_combatwheel", "t_load"}

local only = arg and arg[1]
local passed, failed = 0, 0
for _, name in ipairs(FILES) do
    if not only or only == name then
        local cases = dofile(dir .. name .. ".lua")
        for _, case in ipairs(cases) do
            local ok, message = xpcall(function() case[2](Mock) end, function(m)
                return debug.traceback(tostring(m), 2)
            end)
            if ok then
                passed = passed + 1
            else
                failed = failed + 1
                io.write("FAIL ", name, ": ", case[1], "\n  ", (tostring(message):gsub("\n", "\n  ")), "\n")
            end
        end
    end
end
io.write(string.format("%d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
