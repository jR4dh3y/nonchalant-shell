#!/usr/bin/env python3

"""List available Arch repository and AUR updates without installing them."""

import json
import os
import shutil
import subprocess
import sys
import urllib.parse
import urllib.request

LISTED = 15
AUR_RPC = "https://aur.archlinux.org/rpc/v5/info"
AUR_TIMEOUT = 8
AUR_BATCH = 150
ENV = dict(os.environ, LANG="C", LC_ALL="C")


def run(command, timeout=120):
    try:
        return subprocess.run(command, capture_output=True, text=True, timeout=timeout, env=ENV)
    except (OSError, subprocess.TimeoutExpired):
        return None


def parse(text, source):
    rows = []
    for line in text.splitlines():
        parts = line.split()
        if len(parts) >= 4 and parts[2] == "->":
            rows.append({"name": parts[0], "from": parts[1], "to": parts[3], "source": source})
    return rows


def repositories():
    if shutil.which("checkupdates"):
        result = run(["checkupdates", "--nocolor"])
        if result is not None and result.returncode in (0, 2):
            return "checkupdates", parse(result.stdout, "repo")
    if shutil.which("pacman"):
        result = run(["pacman", "-Qu"])
        if result is not None and (result.returncode == 0
                                   or (result.returncode == 1 and not result.stderr.strip())):
            return "pacman", parse(result.stdout, "repo")
    return None, None


def newer(candidate, installed):
    result = run(["vercmp", candidate, installed], timeout=5)
    try:
        return result is not None and int(result.stdout.strip()) > 0
    except ValueError:
        return False


def aur():
    if not shutil.which("pacman") or not shutil.which("vercmp"):
        return None
    result = run(["pacman", "-Qm"])
    if result is None or result.returncode not in (0, 1):
        return None
    mine = {}
    for line in result.stdout.splitlines():
        fields = line.split()
        if len(fields) >= 2:
            mine[fields[0]] = fields[1]
    if not mine:
        return []

    remote = {}
    names = sorted(mine)
    try:
        for start in range(0, len(names), AUR_BATCH):
            query = urllib.parse.urlencode(
                [("arg[]", name) for name in names[start:start + AUR_BATCH]])
            request = urllib.request.Request(
                f"{AUR_RPC}?{query}", headers={"User-Agent": "Nonchalant desktop widget"})
            with urllib.request.urlopen(request, timeout=AUR_TIMEOUT) as answer:
                for row in json.load(answer).get("results", []):
                    remote[row.get("Name", "")] = row.get("Version", "")
    except (OSError, ValueError, TimeoutError):
        return None

    return [{"name": name, "from": mine[name], "to": remote[name], "source": "aur"}
            for name in names if remote.get(name) and remote[name] != mine[name]
            and newer(remote[name], mine[name])]


def main():
    tool, rows = repositories()
    if rows is None:
        print(json.dumps({"available": False}))
        return
    remote = aur()
    updates = rows + (remote or [])
    print(json.dumps({
        "available": True,
        "tool": tool,
        "aur": remote is not None,
        "count": len(updates),
        "packages": [row["name"] for row in updates[:LISTED]],
        "updates": updates,
    }))


if __name__ == "__main__":
    main()
