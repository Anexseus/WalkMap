#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
"""Release check for WalkMap (not loaded by the game).

    python3 tools/Release/check.py              check the addon folder
    python3 tools/Release/check.py --zip DIR    check, then write DIR/WalkMap-<version>.zip

It checks what has gone wrong before or is easy to forget:
  - the version is the same in WalkMap.toc, README.txt and CHANGELOG.md
  - the What's new page: its title matches NEWS_VERSION, and NEWS_VERSION is
    not ahead of the release (a fix-only release may keep the older one)
  - no other version number is written into the Lua code
  - the Questie version is the same everywhere it is written
  - every file in the TOC exists and every WalkMap*.lua is in the TOC
  - no file's main chunk is near Lua's limit of 200 locals
  - no function is defined twice in one file
  - Lua syntax and the tests in tests/ (when a Lua interpreter is installed;
    lua5.1, luajit, lua and texlua are tried), and luacheck when installed
Exit code 0 means ready to pack. Needs Python 3.8+ and nothing else.
"""
import os
import re
import shutil
import subprocess
import sys
import zipfile

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
LOCAL_LIMIT, LOCAL_WARN = 200, 190
KEYWORDS = set("and break do else elseif end false for function goto if in local nil not or repeat "
               "return then true until while".split())

errors, warnings, notes = [], [], []


def read(name):
    with open(os.path.join(ROOT, name), encoding="utf-8", errors="replace") as handle:
        return handle.read()


def error(text):
    errors.append(text)


def warn(text):
    warnings.append(text)


# ----------------------------------------------------------------- Lua scan
def tokens(src):
    """(kind, text, line) for Lua source; comments dropped."""
    out, i, n, line = [], 0, len(src), 1
    while i < n:
        c = src[i]
        if c == "\n":
            line += 1
            i += 1
            continue
        if c in " \t\r":
            i += 1
            continue
        if src.startswith("--", i):
            m = re.match(r"--\[(=*)\[", src[i:i + 12])
            if m:
                close = "]" + m.group(1) + "]"
                j = src.find(close, i)
                j = n if j < 0 else j + len(close)
                line += src.count("\n", i, j)
                i = j
            else:
                j = src.find("\n", i)
                i = n if j < 0 else j
            continue
        m = re.match(r"\[(=*)\[", src[i:i + 10])
        if m:
            close = "]" + m.group(1) + "]"
            j = src.find(close, i)
            j = n if j < 0 else j + len(close)
            out.append(("str", src[i:j], line))
            line += src.count("\n", i, j)
            i = j
            continue
        if c in "\"'":
            j = i + 1
            while j < n and src[j] != c:
                if src[j] == "\\":
                    j += 1
                j += 1
            out.append(("str", src[i:j + 1], line))
            i = j + 1
            continue
        m = re.compile(r"[A-Za-z_][A-Za-z0-9_]*").match(src, i)
        if m:
            text = m.group(0)
            out.append(("kw" if text in KEYWORDS else "id", text, line))
            i = m.end()
            continue
        m = re.compile(r"0[xX][0-9a-fA-F]+|\d+\.?\d*(?:[eE][+-]?\d+)?|\.\d+").match(src, i)
        if m:
            out.append(("num", m.group(0), line))
            i = m.end()
            continue
        m = re.compile(r"\.\.\.|\.\.|==|~=|<=|>=|::|.", re.S).match(src, i)
        out.append(("op", m.group(0), line))
        i = m.end()
    return out


def main_chunk_locals(toks):
    """Locals that stay alive to the end of the main chunk (not those in do-blocks)."""
    depth, count, i = 0, 0, 0
    while i < len(toks) - 2:
        kind, text, _ = toks[i]
        if kind == "kw":
            if text in ("function", "if", "do", "repeat"):
                depth += 1
            elif text in ("end", "until"):
                depth -= 1
            elif text == "local" and depth == 0:
                if toks[i + 1][1] == "function":
                    count += 1
                else:
                    j = i + 1
                    while j < len(toks):
                        count += 1
                        if j + 1 < len(toks) and toks[j + 1][1] == ",":
                            j += 2
                        else:
                            break
        i += 1
    return count


def duplicate_functions(toks):
    """`function a.b` (or a:b) defined more than once at the top level of a file."""
    seen, dups, depth = {}, [], 0
    for i, (kind, text, line) in enumerate(toks):
        if kind != "kw":
            continue
        if text in ("function", "if", "do", "repeat"):
            if text == "function" and depth == 0 and i + 3 < len(toks) and toks[i + 1][0] == "id":
                j, name = i + 1, toks[i + 1][1]
                while j + 2 < len(toks) and toks[j + 1][1] in (".", ":") and toks[j + 2][0] == "id":
                    name += toks[j + 1][1] + toks[j + 2][1]
                    j += 2
                if i == 0 or toks[i - 1][1] != "local":
                    if name in seen:
                        dups.append((name, seen[name], line))
                    seen[name] = line
            depth += 1
        elif text in ("end", "until"):
            depth -= 1
    return dups


# ------------------------------------------------------------------- checks
def toc():
    version, files = None, []
    for line in read("WalkMap.toc").splitlines():
        line = line.strip()
        m = re.match(r"##\s*Version:\s*(\S+)", line)
        if m:
            version = m.group(1)
        elif line and not line.startswith("#"):
            files.append(line.replace("\\", "/"))
    return version, files


def version_key(text):
    return tuple(int(part) for part in re.findall(r"\d+", text))


def check_versions(version):
    if not version:
        error("WalkMap.toc has no '## Version:' line")
        return
    m = re.match(r"WalkMap (\S+) -", read("README.txt"))
    if not m:
        error("README.txt does not start with 'WalkMap <version> -'")
    elif m.group(1) != version:
        error(f"README.txt says {m.group(1)}, the TOC says {version}")
    m = re.search(r"^## (\S+)", read("CHANGELOG.md"), re.M)
    if not m:
        error("CHANGELOG.md has no '## <version>' section")
    elif m.group(1) != version:
        error(f"CHANGELOG.md's newest section is {m.group(1)}, the TOC says {version}")

    extras = read("WalkMap_Extras.lua")
    news = re.search(r'local NEWS_VERSION = "([^"]+)"', extras)
    title = re.search(r"What's new in WalkMap ([0-9.]+)", extras)
    if not news or not title:
        error("WalkMap_Extras.lua: NEWS_VERSION or the What's new title was not found")
    else:
        if news.group(1) != title.group(1):
            error(f"What's new title says {title.group(1)}, NEWS_VERSION is {news.group(1)}")
        if version_key(news.group(1)) > version_key(version):
            error(f"NEWS_VERSION {news.group(1)} is ahead of the release {version}")
        elif news.group(1) != version:
            notes.append(f"What's new stays at {news.group(1)} (right for a fix-only release; "
                         f"for new features set NEWS_VERSION and the page to {version})")


def check_stray_versions(files):
    """A version number inside a Lua string (comments may mention old versions)."""
    for name in files:
        for kind, text, line in tokens(read(name)):
            if kind != "str" or "What's new in WalkMap" in text:
                continue
            m = re.search(r"WalkMap (\d+\.\d+)", text)
            if m:
                error(f"{name}:{line}: version {m.group(1)} written into the code "
                      f"(read it from the TOC instead)")


def check_questie():
    found = {}
    for name, pattern in (
        ("WalkMap_QuestRules.lua", r"\(Questie (\d+\.\d+\.\d+)\)"),
        ("WalkMap_QuestBlacklist.lua", r"Source: Questie (\d+\.\d+\.\d+)"),
        ("THIRD_PARTY_NOTICES.txt", r"QuestieQuestBlacklist\.lua \((\d+\.\d+\.\d+)\)"),
        ("tools/QuestBlacklist/README.txt", r"WalkMap_QuestBlacklist\.lua (\d+\.\d+\.\d+)"),
    ):
        m = re.search(pattern, read(name))
        if not m:
            error(f"{name}: Questie version not found")
        else:
            found[name] = m.group(1)
    if len(set(found.values())) > 1:
        error("Questie version differs: " + ", ".join(f"{k} {v}" for k, v in sorted(found.items())))
    elif found:
        notes.append("Questie blacklist version " + next(iter(found.values())))


def check_files(files):
    for name in files:
        if not os.path.isfile(os.path.join(ROOT, name)):
            error(f"WalkMap.toc lists {name}, which does not exist")
    on_disk = sorted(f for f in os.listdir(ROOT) if re.match(r"WalkMap.*\.lua$", f))
    for name in on_disk:
        if name not in files:
            error(f"{name} is not listed in WalkMap.toc (the game will not load it)")
    if len(files) != len(set(files)):
        error("WalkMap.toc lists a file twice")


def check_lua_structure(files):
    for name in files:
        if not name.endswith(".lua") or not os.path.isfile(os.path.join(ROOT, name)):
            continue
        toks = tokens(read(name))
        count = main_chunk_locals(toks)
        if count >= LOCAL_LIMIT:
            error(f"{name}: {count} main-chunk locals; Lua allows {LOCAL_LIMIT}. Move a piece to its own file.")
        elif count >= LOCAL_WARN:
            warn(f"{name}: {count} main-chunk locals, close to Lua's limit of {LOCAL_LIMIT}")
        elif count >= 150:
            notes.append(f"{name}: {count} main-chunk locals (limit {LOCAL_LIMIT})")
        for func, first, second in duplicate_functions(toks):
            error(f"{name}: function {func} is defined twice (lines {first} and {second}); the second wins")


def find(*names):
    for name in names:
        path = shutil.which(name)
        if path:
            return path
    return None


def check_with_lua(files):
    lua = find("lua5.1", "luajit", "lua", "lua5.4", "lua5.3", "lua5.2", "texlua")
    if not lua:
        warn("no Lua interpreter found (lua5.1, luajit, lua, texlua): syntax and tests were NOT run")
        return
    lua_files = [f for f in files if f.endswith(".lua")]
    tests_dir = os.path.join(ROOT, "tests")
    if os.path.isdir(tests_dir):
        lua_files += ["tests/" + f for f in sorted(os.listdir(tests_dir)) if f.endswith(".lua")]
    lua_files += ["tools/QuestBlacklist/gen.lua"]
    loader = ("local bad = 0 for i = 1, #arg do local chunk, message = loadfile(arg[i]) "
              "if not chunk then bad = bad + 1 io.write(message, '\\n') end end os.exit(bad == 0 and 0 or 1)")
    scratch = os.path.join(ROOT, "tests", ".syntax-check.lua")
    try:
        with open(scratch, "w") as handle:
            handle.write(loader)
        result = subprocess.run([lua, scratch] + lua_files, cwd=ROOT, capture_output=True, text=True)
    finally:
        if os.path.exists(scratch):
            os.remove(scratch)
    if result.returncode != 0:
        error("Lua syntax:\n    " + (result.stdout + result.stderr).strip().replace("\n", "\n    "))
    else:
        notes.append(f"syntax OK for {len(lua_files)} Lua files ({os.path.basename(lua)})")
    runner = os.path.join("tests", "run.lua")
    if os.path.isfile(os.path.join(ROOT, runner)):
        result = subprocess.run([lua, runner], cwd=ROOT, capture_output=True, text=True)
        tail = (result.stdout + result.stderr).strip()
        if result.returncode != 0:
            # Each failure's name and first detail line; the runner itself prints the full traces.
            lines, keep = tail.splitlines(), []
            for index, line in enumerate(lines):
                if line.startswith("FAIL"):
                    keep.append(line)
                    if index + 1 < len(lines):
                        keep.append("  " + lines[index + 1].strip())
            keep.append(lines[-1] if lines else "no output")
            error("tests failed (lua tests/run.lua shows the details):\n    " + "\n    ".join(keep))
        else:
            notes.append("tests: " + tail.splitlines()[-1])
    luacheck = find("luacheck")
    if luacheck:
        result = subprocess.run([luacheck, "--codes", "--no-color", "-q"] + [f for f in files if f.endswith(".lua")],
                                cwd=ROOT, capture_output=True, text=True)
        text = result.stdout.strip()
        if result.returncode > 1:
            error("luacheck:\n    " + text.replace("\n", "\n    "))
        elif result.returncode == 1:
            warn("luacheck warnings:\n    " + text.replace("\n", "\n    "))
        else:
            notes.append("luacheck clean")
    else:
        notes.append("luacheck not installed (optional)")


def build_zip(version, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    target = os.path.join(out_dir, f"WalkMap-{version}.zip")
    count = 0
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
        for folder, dirs, names in os.walk(ROOT):
            dirs[:] = sorted(d for d in dirs if not d.startswith(".") and d != "__pycache__")
            for name in sorted(names):
                if name.startswith(".") or name.endswith((".zip", ".pyc")):
                    continue
                path = os.path.join(folder, name)
                archive.write(path, os.path.join("WalkMap", os.path.relpath(path, ROOT)))
                count += 1
    return target, count


def main():
    version, files = toc()
    check_versions(version)
    check_files(files)
    check_stray_versions([f for f in files if f.endswith(".lua")])
    check_questie()
    check_lua_structure(files)
    check_with_lua(files)

    print(f"WalkMap {version or '?'} release check")
    for text in notes:
        print("  ok    " + text)
    for text in warnings:
        print("  WARN  " + text)
    for text in errors:
        print("  ERROR " + text)
    if errors:
        print(f"{len(errors)} error(s). Not ready.")
        return 1
    print("Ready to pack." if not warnings else f"Ready to pack, with {len(warnings)} warning(s).")
    if "--zip" in sys.argv:
        index = sys.argv.index("--zip")
        out_dir = sys.argv[index + 1] if index + 1 < len(sys.argv) else os.path.dirname(ROOT)
        target, count = build_zip(version, out_dir)
        print(f"Wrote {target} ({count} files)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
