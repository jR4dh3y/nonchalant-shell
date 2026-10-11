#!/usr/bin/env python3

"""Read Codex rate-limit snapshots from local session logs only."""

import json
import os
import sys
from datetime import datetime
from pathlib import Path

HOME = Path.home()
SESSIONS = Path(os.environ.get("CODEX_HOME") or HOME / ".codex") / "sessions"
NEWEST = 8
TAIL = 256 * 1024


def unavailable():
    print(json.dumps({"available": False}))


def parse_timestamp(value):
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp()
    except (AttributeError, TypeError, ValueError, OverflowError):
        return None


def window_name(minutes):
    if minutes >= 40000:
        return "Month"
    if minutes >= 10080:
        return "Week"
    if minutes >= 1440:
        return f"{round(minutes / 1440)} days"
    return f"{round(minutes / 60)} hours"

def last_record(path):
    try:
        with path.open("rb") as handle:
            handle.seek(0, os.SEEK_END)
            size = handle.tell()
            start = max(0, size - TAIL)
            handle.seek(start)
            lines = handle.read().decode("utf-8", "replace").splitlines()
    except OSError:
        return None
    if size > TAIL:
        lines = lines[1:]
    for line in reversed(lines):
        if '"rate_limits"' not in line:
            continue
        try:
            record = json.loads(line)
        except ValueError:
            continue
        payload = record.get("payload") if isinstance(record, dict) else None
        limits = payload.get("rate_limits") if isinstance(payload, dict) else None
        if isinstance(limits, dict):
            return record, limits
    return None


def window(limit, observed):
    if not isinstance(limit, dict):
        return None
    used = limit.get("used_percent")
    minutes = limit.get("window_minutes") or 0
    if not isinstance(used, (int, float)) or not 0 <= used <= 100:
        return None
    if not isinstance(minutes, (int, float)) or minutes <= 0:
        return None
    resets = limit.get("resets_at")
    if not isinstance(resets, (int, float)):
        seconds = limit.get("resets_in_seconds")
        resets = observed + seconds if isinstance(seconds, (int, float)) and observed else 0
    return {"name": window_name(minutes), "minutes": minutes,
            "used": used / 100, "resets": int(resets)}


def modified(path):
    try:
        return path.stat().st_mtime
    except OSError:
        return 0


def main():
    if not SESSIONS.is_dir():
        unavailable()
        return
    logs = sorted(SESSIONS.rglob("rollout-*.jsonl"), key=modified, reverse=True)[:NEWEST]
    for path in logs:
        found = last_record(path)
        if found is None:
            continue
        record, raw_limits = found
        observed = parse_timestamp(record.get("timestamp") or "") or int(modified(path))
        if observed is None:
            observed = int(modified(path))
        limits = [window(raw_limits.get(key), observed) for key in ("primary", "secondary")]
        plan = raw_limits.get("plan_type") or ""
        print(json.dumps({
            "available": True,
            "plan": plan[:1].upper() + plan[1:],
            "observed": observed,
            "limits": [item for item in limits if item is not None],
        }))
        return
    unavailable()


if __name__ == "__main__":
    main()
