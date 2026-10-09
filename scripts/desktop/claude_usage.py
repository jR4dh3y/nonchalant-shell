#!/usr/bin/env python3

"""Aggregate Claude Code transcript usage without accessing account credentials."""

import json
import os
import sys
import tempfile
import time
from pathlib import Path
from datetime import datetime

BLOCK_HOURS = 5
WEEK_HOURS = 24 * 7
CACHE_VERSION = 2
HOME = Path.home()
TRANSCRIPTS = Path(os.environ.get("CLAUDE_CONFIG_DIR") or HOME / ".claude") / "projects"


def unavailable(reason="no transcript usage"):
    print(json.dumps({"available": False, "reason": reason}))


def parse_timestamp(value):
    if not isinstance(value, str):
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp()
    except (TypeError, ValueError, OverflowError):
        return None


def load_cache(path):
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
        if (isinstance(value, dict) and value.get("version") == CACHE_VERSION
                and isinstance(value.get("files"), dict)):
            return value
    except (OSError, ValueError):
        pass
    return {"version": CACHE_VERSION, "files": {}}


def save_cache(path, cache):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path.parent,
                                     prefix=f".{path.name}.", delete=False) as handle:
        temporary = Path(handle.name)
        json.dump(cache, handle, separators=(",", ":"))
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(temporary, path)


def scan(path, entry):
    stat = path.stat()
    offset = entry.get("offset", 0)
    buckets = entry.get("buckets", {})
    if not isinstance(offset, int) or offset < 0 or stat.st_size < offset:
        offset, buckets = 0, {}
    if not isinstance(buckets, dict):
        offset, buckets = 0, {}

    with path.open("rb") as handle:
        handle.seek(offset)
        while True:
            line_start = handle.tell()
            line = handle.readline()
            if not line:
                break
            if not line.endswith(b"\n"):
                handle.seek(line_start)
                break
            if b'"usage"' not in line:
                continue
            try:
                record = json.loads(line)
            except ValueError:
                continue
            if not isinstance(record, dict) or record.get("type") != "assistant":
                continue
            message = record.get("message") or {}
            usage = message.get("usage") if isinstance(message, dict) else None
            when = parse_timestamp(record.get("timestamp"))
            if not isinstance(usage, dict) or when is None:
                continue
            tokens = 0
            for key in (
                "input_tokens", "output_tokens", "cache_creation_input_tokens",
                "cache_read_input_tokens",
            ):
                value = usage.get(key, 0)
                if isinstance(value, int) and value >= 0:
                    tokens += value
            hour = str(int(when // 3600))
            slot = buckets.setdefault(hour, [0, 0])
            slot[0] += tokens
            slot[1] += 1
        offset = handle.tell()
    return {"offset": offset, "mtime": stat.st_mtime, "buckets": buckets}


def total_over(hours, first, last):
    tokens = messages = 0
    for hour in range(first, last + 1):
        slot = hours.get(str(hour))
        if slot:
            tokens += slot[0]
            messages += slot[1]
    return tokens, messages


def transcript_report(cache_path):
    if not TRANSCRIPTS.is_dir():
        return None
    cache = load_cache(cache_path)
    files = cache["files"]
    hours = {}
    for path in TRANSCRIPTS.glob("**/*.jsonl"):
        key = str(path)
        entry = files.get(key, {})
        try:
            stat = path.stat()
            if entry.get("mtime") != stat.st_mtime or not entry.get("buckets"):
                entry = scan(path, entry)
                files[key] = entry
        except (OSError, ValueError, TypeError):
            continue
        for hour, values in entry.get("buckets", {}).items():
            if isinstance(values, list) and len(values) == 2:
                total = hours.setdefault(hour, [0, 0])
                total[0] += values[0]
                total[1] += values[1]

    cache["files"] = files
    save_cache(cache_path, cache)
    if not hours:
        return None

    this_hour = int(time.time() // 3600)
    ordered = sorted(int(hour) for hour in hours)
    block_start = this_hour
    for hour in reversed(ordered):
        if this_hour - BLOCK_HOURS < hour <= this_hour:
            block_start = min(block_start, hour)
    while block_start - 1 > this_hour - BLOCK_HOURS and str(block_start - 1) in hours:
        block_start -= 1

    block_tokens, block_messages = total_over(hours, block_start, this_hour)
    week_tokens, week_messages = total_over(hours, this_hour - WEEK_HOURS + 1, this_hour)
    peak_block = 0
    peak_week = 0
    for hour in range(ordered[0], ordered[-1] + 1):
        peak_block = max(peak_block, total_over(hours, hour, hour + BLOCK_HOURS - 1)[0])
    for hour in range(ordered[0], ordered[-1] + 1):
        peak_week = max(peak_week, total_over(hours, hour, hour + WEEK_HOURS - 1)[0])
    return {
        "available": True,
        "blockStart": block_start * 3600,
        "blockEnd": (block_start + BLOCK_HOURS) * 3600,
        "blockTokens": block_tokens,
        "blockMessages": block_messages,
        "weekTokens": week_tokens,
        "weekMessages": week_messages,
        "peakBlockTokens": peak_block,
        "peakWeekTokens": peak_week,
    }


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "limits":
        unavailable("account usage limits are not requested")
        return
    cache_path = Path(sys.argv[1]) if len(sys.argv) > 1 else (
        Path(os.environ.get("XDG_STATE_HOME") or HOME / ".local" / "state")
        / "quickshell" / "desktop-claude-usage.json")
    try:
        result = transcript_report(cache_path)
    except (OSError, ValueError, TypeError):
        result = None
    print(json.dumps(result if result is not None else {"available": False, "reason": "no transcript usage"}))


if __name__ == "__main__":
    main()
