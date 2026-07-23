#!/usr/bin/env bash

# Check dependencies
for dep in niri zbarimg wl-copy notify-send; do
    if ! command -v $dep &> /dev/null; then
        notify-send "QR Scan Error" "Missing dependency: $dep" -u critical
        exit 1
    fi
done

# Open niri's built-in screenshot UI; save the selection to a temp file.
TMP="/tmp/nonchalant_qr_$$.png"
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
    rm -f "$TMP"
    exit 0
fi

# zbarimg -q (quiet) --raw (raw output)
RESULT=$(zbarimg -q --raw "$TMP" 2>/dev/null)
rm -f "$TMP"

if [ -n "$RESULT" ]; then
    # zbarimg might return multiple lines if multiple codes are found
    echo -n "$RESULT" | wl-copy
    notify-send "QR/Barcode Result" "Content copied to clipboard" -i qr-code
else
    notify-send "QR/Barcode Result" "No code detected" -u low -i dialogue-error
fi
