"""Read the selected Cider recording's Apple Music lyrics using its local API.

Credentials stay in this process. CIDER_API_TOKEN_FILE can point to a private
file containing a Cider app token with playback and account scopes.
"""

import json
import math
import os
import re
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path


TTML = "{http://www.w3.org/ns/ttml}"
TIMEOUT = 5


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        # Authentication headers must stay on the intended API host.
        return None


def request_json(url, headers):
    opener = urllib.request.build_opener(NoRedirect)
    request = urllib.request.Request(url, headers=headers)
    with opener.open(request, timeout=TIMEOUT) as response:
        return json.load(response)


def timestamp(value):
    """TTML clock and second offsets, in seconds. Frame-based clocks are unsupported."""
    if value is None:
        return None
    if value.endswith("ms"):
        seconds = float(value[:-2]) / 1000
    elif value.endswith("s"):
        seconds = float(value[:-1])
    else:
        parts = value.split(":")
        if len(parts) > 3:
            raise ValueError("Unsupported TTML clock")
        seconds = 0
        for part in parts:
            seconds = seconds * 60 + float(part)
    if not math.isfinite(seconds) or seconds < 0:
        raise ValueError("Invalid TTML timestamp")
    return seconds


def parse_ttml(ttml):
    """Normalize TTML to line times and word ranges measured in QML's UTF-16 units."""
    root = ET.fromstring(ttml)
    lines = []
    for paragraph in root.iter(TTML + "p"):
        pieces = []
        words = []
        offset = 0

        def append(text):
            nonlocal offset
            text = re.sub(r"\s+", " ", text or "")
            pieces.append(text)
            offset += len(text.encode("utf-16-le")) // 2

        def visit(element):
            start = offset
            append(element.text)
            for child in element:
                if child.tag in (TTML + "span", TTML + "br"):
                    if child.tag == TTML + "br":
                        append(" ")
                    else:
                        visit(child)
                append(child.tail)
            if element.tag == TTML + "span" and not any(
                child.tag == TTML + "span" for child in element
            ):
                begin = timestamp(element.get("begin"))
                end = timestamp(element.get("end"))
                if begin is not None and end is not None and end > begin and offset > start:
                    words.append({"t": begin, "end": end, "start": start, "length": offset - start})

        visit(paragraph)
        text = "".join(pieces)
        begin = timestamp(paragraph.get("begin"))
        end = timestamp(paragraph.get("end"))
        if begin is None and words:
            begin = min(word["t"] for word in words)
        if end is None and words:
            end = max(word["end"] for word in words)
        if not text.strip() and (begin is None or end is None):
            continue
        line = {"t": begin if begin is not None else -1, "text": text if text.strip() else ""}
        if begin is not None and end is not None:
            if end <= begin:
                raise ValueError("Invalid TTML line duration")
            line["end"] = end
        if words and text.strip():
            line["words"] = words
        lines.append(line)

    if not lines:
        return None
    synced = all(line["t"] >= 0 for line in lines)
    if synced:
        lines.sort(key=lambda line: line["t"])
    else:
        # A document without complete line timing can still supply readable lyrics.
        lines = [{"t": -1, "text": line["text"]} for line in lines]
    return {"available": True, "synced": synced, "instrumental": False,
            "source": "cider", "lines": lines}


def report(artist, title, track_id):
    """Return exact-recording lyrics, or None so the caller can use LRCLIB."""
    local_headers = {}
    apple_headers = {}
    auth = {}
    try:
        port = int(os.environ.get("CIDER_PORT", "10767"))
        if not 0 < port < 65536:
            return None
        token_file = os.environ.get("CIDER_API_TOKEN_FILE")
        if token_file:
            local_headers["apptoken"] = Path(token_file).read_text().strip()
        local = f"http://127.0.0.1:{port}/api"
        now = request_json(local + "/v1/playback/now-playing", local_headers)["info"]
        params = now["playParams"]
        identities = {params.get(key) for key in ("id", "catalogId", "reportingId", "libraryId")}
        # Cider strips punctuation from e.id when constructing its MPRIS
        # object path. Match that exported form as well as the original ID,
        # otherwise library tracks silently fall through to another provider.
        if track_id and not any(
            isinstance(identity, str) and (
                track_id == identity or track_id == re.sub(r"[^a-zA-Z 0-9]+", "", identity)
            ) for identity in identities
        ):
            return None
        if now["name"].casefold() != title.casefold() or (
            artist and now["artistName"].casefold() != artist.casefold()
        ):
            return None
        catalog_id = params.get("catalogId") or params.get("reportingId") or params.get("id")
        if not isinstance(catalog_id, str) or not re.fullmatch(r"\d+", catalog_id):
            return None
        session = request_json(local + "/v2/client/tokens", local_headers)["data"]
        if not isinstance(session, dict):
            return None
        auth = session
        storefront = auth["storefront"]
        if not re.fullmatch(r"[a-z]{2}", storefront) or not auth["developerToken"] or not auth["userToken"]:
            return None
        apple_headers.update({
            "Authorization": "Bearer " + auth["developerToken"],
            "Music-User-Token": auth["userToken"],
            "Origin": "https://music.apple.com",
            "User-Agent": "Nonchalant Shell lyrics",
        })
        endpoint = f"https://amp-api.music.apple.com/v1/catalog/{storefront}/songs/{catalog_id}"
        for kind in ("syllable-lyrics", "lyrics"):
            try:
                response = request_json(f"{endpoint}/{kind}", apple_headers)
                entries = response.get("data", [])
                ttml = entries[0]["attributes"].get("ttml") if entries else None
                result = parse_ttml(ttml) if ttml else None
                if result:
                    return result
            except urllib.error.HTTPError as error:
                error.close()
                if error.code not in (400, 404):
                    return None
        return None
    except urllib.error.HTTPError as error:
        error.close()
        return None
    except (OSError, ValueError, KeyError, IndexError, TypeError, AttributeError, ET.ParseError):
        # The external API may be disabled, scoped, offline, or between tracks.
        return None
    finally:
        local_headers.clear()
        apple_headers.clear()
        auth.clear()
