#!/usr/bin/env bash

# Check dependencies
for dep in niri tesseract wl-copy notify-send; do
    if ! command -v $dep &> /dev/null; then
        notify-send "OCR Error" "Missing dependency: $dep" -u critical
        exit 1
    fi
done

# Languages based on installed tesseract packages:
# eng (English), spa (Spanish), lat (Latin), jpn (Japanese),
# chi_sim (Simplified Chinese), chi_tra (Traditional Chinese), kor (Korean)
if [ -n "$1" ]; then
    LANGS="$1"
else
    LANGS="eng+spa"
fi

# Open niri's built-in screenshot UI; save the selection to a temp file.
# The IPC returns immediately; the file appears after the user confirms.
TMP="/tmp/nonchalant_ocr_$$.png"
rm -f "$TMP"

niri msg action screenshot --path "$TMP" --show-pointer false

# Wait up to ~120s for the user to complete or cancel the screenshot UI.
ready=0
for _ in $(seq 1 600); do
    if [ -s "$TMP" ]; then
        ready=1
        break
    fi
    sleep 0.2
done

if [ "$ready" != 1 ]; then
    # Cancelled or timed out
    rm -f "$TMP"
    exit 0
fi

# Pipe image to tesseract stdin (-) and output to stdout (-)
TEXT=$(tesseract "$TMP" stdout -l "$LANGS" 2>/dev/null)
rm -f "$TMP"

# Trim whitespace
TEXT=$(echo "$TEXT" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

if [ -n "$TEXT" ]; then
    echo "$TEXT" | wl-copy
    notify-send "OCR Result" "Text copied to clipboard" -i edit-paste
else
    notify-send "OCR Result" "No text detected" -u low -i dialogue-error
fi
