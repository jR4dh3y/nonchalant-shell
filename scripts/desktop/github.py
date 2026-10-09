#!/usr/bin/env python3

"""Read a public GitHub contribution calendar without authentication."""

import json
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

ENDPOINT = "https://github.com/users/{user}/contributions"
TIMEOUT = 12
DAY = re.compile(
    r'data-date="(\d{4}-\d{2}-\d{2})"[^>]*?'
    r'id="contribution-day-component-(\d+)-(\d+)"[^>]*?'
    r'data-level="(\d)"'
)
TIP = re.compile(
    r'for="contribution-day-component-(\d+)-(\d+)"[^>]*?>\s*'
    r'(No|[\d,]+) contribution'
)
TOTAL = re.compile(r'js-contribution-activity-description[^>]*>\s*([\d,]+)')


class UserNotFound(Exception):
    pass


def number(value):
    return int(value.replace(",", ""))


def fetch(user):
    request = urllib.request.Request(
        ENDPOINT.format(user=urllib.parse.quote(user, safe="")),
        headers={"User-Agent": "Nonchalant desktop widget"},
    )
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
            return response.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as error:
        if error.code == 404:
            raise UserNotFound from None
        raise


def report(user):
    html = fetch(user)
    cells = DAY.findall(html)
    if not cells:
        raise UserNotFound

    counts = {
        (int(row), int(column)): 0 if amount == "No" else number(amount)
        for row, column, amount in TIP.findall(html)
    }
    columns = max(int(column) for _, _, column, _ in cells) + 1
    weeks = [[None] * 7 for _ in range(columns)]
    days = []
    for date, row, column, level in cells:
        row, column, level = int(row), int(column), int(level)
        weeks[column][row] = level
        days.append({"date": date, "level": level, "count": counts.get((row, column), 0)})
    days.sort(key=lambda day: day["date"])

    streak = 0
    for index, day in enumerate(reversed(days)):
        if day["level"] > 0:
            streak += 1
        elif index > 0:
            break

    total = TOTAL.search(html)
    return {
        "available": True,
        "user": user,
        "total": number(total.group(1)) if total else sum(day["count"] for day in days),
        "streak": streak,
        "today": days[-1]["count"] if days else 0,
        "busiest": max((day["count"] for day in days), default=0),
        "weeks": weeks,
    }


def main():
    user = " ".join(sys.argv[1:]).strip().lstrip("@").strip()
    if not user:
        print(json.dumps({"available": False, "reason": "user"}))
        return
    if len(user) > 39 or not re.fullmatch(r"[A-Za-z0-9-]+", user):
        print(json.dumps({"available": False, "reason": "user"}))
        return
    try:
        print(json.dumps(report(user)))
    except UserNotFound:
        print(json.dumps({"available": False, "reason": "user"}))
    except (OSError, TimeoutError, ValueError) as error:
        print(json.dumps({"available": False}))
        print(f"github request failed: {type(error).__name__}", file=sys.stderr)


if __name__ == "__main__":
    main()
