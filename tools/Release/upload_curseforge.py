#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# WalkMap. Copyright (C) 2026 Anexseus and Underbuks. See LICENSE.txt.
"""Upload a built WalkMap zip to CurseForge (not loaded by the game).

    python3 tools/Release/upload_curseforge.py dist/WalkMap-1.14.7.zip
    python3 tools/Release/upload_curseforge.py --dry-run dist/WalkMap-1.14.7.zip

Used by .github/workflows/release.yml when a version tag is pushed.
  CF_API_KEY      CurseForge API token (GitHub secret; never commit it)
  CF_PROJECT_ID   optional; else ## X-Curse-Project-ID in WalkMap.toc
  CF_GAME_VERSION optional, e.g. "1.60.1"; else made from ## Interface
                  (16001 -> 1.60.1)
  CF_RELEASE_TYPE optional: release (default), beta or alpha
The changelog is this version's section of CHANGELOG.md.
Needs Python 3.8+ and nothing else.
"""
import json
import os
import re
import sys
import urllib.request
import uuid

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
API = "https://wow.curseforge.com/api"


def read(name):
    with open(os.path.join(ROOT, name), encoding="utf-8") as handle:
        return handle.read()


def toc_field(toc, field):
    match = re.search(r"^## " + re.escape(field) + r":\s*(.+?)\s*$", toc, re.M)
    return match.group(1) if match else None


def game_version_name(interface):
    """16001 -> 1.60.1, 110207 -> 11.2.7"""
    digits = re.sub(r"\D", "", interface.split(",")[0])
    major, minor, patch = digits[:-4], digits[-4:-2], digits[-2:]
    return "%d.%d.%d" % (int(major), int(minor), int(patch))


def changelog_section(version):
    text = read("CHANGELOG.md")
    match = re.search(r"^## " + re.escape(version) + r"\s*$(.*?)(?=^## |\Z)", text, re.M | re.S)
    if not match:
        sys.exit("CHANGELOG.md has no section for " + version)
    return "## " + version + "\n" + match.group(1).strip() + "\n"


def request(url, token, data=None, content_type=None):
    req = urllib.request.Request(url, data=data, headers={"X-Api-Token": token})
    if content_type:
        req.add_header("Content-Type", content_type)
    with urllib.request.urlopen(req, timeout=120) as response:
        return json.loads(response.read().decode("utf-8"))


def find_game_version(token, name):
    versions = request(API + "/game/versions", token)
    matches = [v for v in versions if v.get("name") == name]
    if len(matches) > 1:
        # Same name in several WoW flavours: prefer Forever's.
        types = {t["id"]: (t.get("name", "") + " " + t.get("slug", "")).lower()
                 for t in request(API + "/game/version-types", token)}
        forever = [v for v in matches if "forever" in types.get(v.get("gameVersionTypeID"), "")]
        matches = forever or matches[-1:]
    if not matches:
        near = sorted({v.get("name", "") for v in versions if v.get("name", "").startswith(name.rsplit(".", 1)[0])})
        sys.exit("CurseForge has no game version %r. Close names: %s. Set CF_GAME_VERSION." % (name, ", ".join(near) or "none"))
    return matches[0]["id"]


def main(argv):
    dry = "--dry-run" in argv
    paths = [a for a in argv if not a.startswith("--")]
    if len(paths) != 1:
        sys.exit(__doc__)
    path = paths[0]
    toc = read("WalkMap.toc")
    version = toc_field(toc, "Version")
    project = os.environ.get("CF_PROJECT_ID") or toc_field(toc, "X-Curse-Project-ID")
    game = os.environ.get("CF_GAME_VERSION") or game_version_name(toc_field(toc, "Interface"))
    metadata = {
        "changelog": changelog_section(version),
        "changelogType": "markdown",
        "displayName": "WalkMap " + version,
        "releaseType": os.environ.get("CF_RELEASE_TYPE", "release"),
    }
    print("Project %s, WalkMap %s, game version %s, file %s" % (project, version, game, os.path.basename(path)))
    if dry:
        print(json.dumps(metadata, indent=2))
        return
    token = os.environ.get("CF_API_KEY")
    if not token:
        sys.exit("CF_API_KEY is not set")
    if not project:
        sys.exit("No project id: add ## X-Curse-Project-ID to WalkMap.toc or set CF_PROJECT_ID")
    metadata["gameVersions"] = [find_game_version(token, game)]
    boundary = uuid.uuid4().hex
    with open(path, "rb") as handle:
        payload = handle.read()
    body = b"".join([
        b"--" + boundary.encode() + b"\r\n",
        b'Content-Disposition: form-data; name="metadata"\r\n',
        b"Content-Type: application/json\r\n\r\n",
        json.dumps(metadata).encode("utf-8"), b"\r\n",
        b"--" + boundary.encode() + b"\r\n",
        ('Content-Disposition: form-data; name="file"; filename="%s"\r\n' % os.path.basename(path)).encode(),
        b"Content-Type: application/zip\r\n\r\n",
        payload, b"\r\n",
        b"--" + boundary.encode() + b"--\r\n",
    ])
    result = request("%s/projects/%s/upload-file" % (API, project), token, body,
                     "multipart/form-data; boundary=" + boundary)
    print("Uploaded to CurseForge, file id %s" % result.get("id"))


if __name__ == "__main__":
    main(sys.argv[1:])
