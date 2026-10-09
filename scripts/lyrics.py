#!/usr/bin/env python3
"""Fetch one track's lyrics from LRCLIB and cache the result locally.

Usage: lyrics.py <artist> <title> <album> <seconds>

The JSON response contains timed lines (`t` in seconds), plain lines (`t: -1`),
an instrumental result, or a missing/network status. Successful answers are
cached indefinitely; confirmed misses are cached for one week. Network errors
are not cached so the caller can retry.
"""

import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

ENDPOINT = "https://lrclib.net/api"
TIMEOUT = 8
AGENT = "Nonchalant Shell lyrics"
MISS_TTL = 7 * 24 * 3600

STAMP = re.compile(r"\[(\d+):(\d+(?:\.\d+)?)\]")
NOISE = re.compile(
    r"\s*[\(\[](official|lyric|audio|video|visuali[sz]er|hd|4k|mv)[^\)\]]*[\)\]]",
    re.IGNORECASE,
)


def cache_dir():
    base = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
    path = os.path.join(base, "nonchalant", "lyrics")
    os.makedirs(path, exist_ok=True)
    return path


def clean(artist, title):
    artist = re.sub(r"\s*-\s*Topic$", "", artist).strip()
    title = NOISE.sub("", title).strip()
    if not artist and " - " in title:
        artist, title = (part.strip() for part in title.split(" - ", 1))
    return artist, title


class Busy(Exception):
    """LRCLIB could not answer this lookup."""


def ask(path, params):
    url = f"{ENDPOINT}/{path}?{urllib.parse.urlencode(params)}"
    request = urllib.request.Request(url, headers={"User-Agent": AGENT})
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT) as answer:
            return json.load(answer)
    except urllib.error.HTTPError as error:
        if error.code < 500 and error.code != 429:
            return None
        raise Busy(f"HTTP {error.code}") from error
    except (urllib.error.URLError, OSError, ValueError) as error:
        raise Busy(str(error)) from error


def folded(text):
    return re.sub(r"\W+", " ", text.casefold()).strip()


def lookup(artist, title, album, seconds):
    """Match artist and duration, preferring exact titles before timed lyrics."""
    found = []
    busy = False
    wanted = folded(title)
    wanted_artist = folded(artist)

    def eligible(entry):
        return (
            wanted in folded(entry.get("trackName") or "")
            and (not wanted_artist or wanted_artist == folded(entry.get("artistName") or ""))
            and (seconds <= 0 or abs((entry.get("duration") or 0) - seconds) <= 8)
            and (entry.get("syncedLyrics") or entry.get("plainLyrics") or entry.get("instrumental"))
        )

    def take(results):
        found.extend(entry for entry in results if entry and eligible(entry))

    if seconds > 0 and artist:
        params = {"artist_name": artist, "track_name": title, "duration": round(seconds)}
        if album:
            params["album_name"] = album
        try:
            take([ask("get", params)])
        except Busy:
            busy = True
        if found and found[0].get("syncedLyrics"):
            return found[0]

    questions = [
        {"track_name": title, **({"artist_name": artist} if artist else {})},
        {"q": f"{artist} {title}".strip()},
    ]
    for params in questions:
        try:
            take(ask("search", params) or [])
        except Busy:
            busy = True
            continue
        if any(entry.get("syncedLyrics") and folded(entry.get("trackName") or "") == wanted
               for entry in found):
            break

    if not found:
        if busy:
            raise Busy("no answer")
        return None

    def rank(entry):
        offset = abs((entry.get("duration") or 0) - seconds) if seconds > 0 else 0
        return (folded(entry.get("trackName") or "") != wanted,
                not entry.get("syncedLyrics"), offset)

    return min(found, key=rank)


def parse(entry):
    if entry.get("instrumental"):
        return {"available": True, "synced": False, "instrumental": True, "lines": []}

    lines = []
    for raw in (entry.get("syncedLyrics") or "").splitlines():
        stamps = STAMP.findall(raw)
        text = STAMP.sub("", raw).strip()
        for minutes, seconds in stamps:
            lines.append({"t": int(minutes) * 60 + float(seconds), "text": text})
    if lines:
        lines.sort(key=lambda line: line["t"])
        return {"available": True, "synced": True, "instrumental": False, "lines": lines}

    plain = [line.strip() for line in (entry.get("plainLyrics") or "").splitlines()]
    if any(plain):
        return {
            "available": True,
            "synced": False,
            "instrumental": False,
            "lines": [{"t": -1, "text": line} for line in plain],
        }
    return None


def report(artist, title, album, seconds):
    artist, title = clean(artist, title)
    if not title:
        return {"available": False, "reason": "missing"}

    key = hashlib.sha1(f"{artist}\n{title}\n{album}\n{round(seconds)}".encode()).hexdigest()
    path = os.path.join(cache_dir(), f"{key}.json")
    try:
        with open(path, encoding="utf-8") as file:
            kept = json.load(file)
        if isinstance(kept, dict) and (
            kept.get("available")
            or (kept.get("reason") == "missing" and time.time() - kept.get("at", 0) < MISS_TTL)
        ):
            kept.pop("at", None)
            return kept
    except (OSError, ValueError):
        pass

    try:
        entry = lookup(artist, title, album, seconds)
        result = (parse(entry) if entry else None) or {"available": False, "reason": "missing"}
    except Busy as error:
        sys.stderr.write(f"lyrics: {error}\n")
        return {"available": False, "reason": "network"}

    staging = f"{path}.tmp"
    with open(staging, "w", encoding="utf-8") as file:
        json.dump({**result, "at": time.time()}, file)
    os.replace(staging, path)
    return result


if __name__ == "__main__":
    args = sys.argv[1:] + [""] * 4
    try:
        length = float(args[3] or 0)
    except ValueError:
        length = 0
    try:
        print(json.dumps(report(args[0], args[1], args[2], length)))
    except Exception as error:
        sys.stderr.write(f"lyrics failed: {error}\n")
        print(json.dumps({"available": False, "reason": "network"}))
