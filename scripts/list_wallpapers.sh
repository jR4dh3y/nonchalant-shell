#!/usr/bin/env bash
set -euo pipefail

scan() {
    [[ -d $1 ]] || return 0
    find "$1" -mindepth 1 -name '.*' -prune -o -type d -printf '%p/\0' -o -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.avif' \
        -o -iname '*.tif' -o -iname '*.tiff' -o -iname '*.bmp' -o -iname '*.gif' \
        -o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mov' -o -iname '*.avi' -o -iname '*.mkv' \) -printf '%p\0'
}

mapfile -d '' -t entries < <(scan "$1")
for entry in "${entries[@]}"; do
    if [[ $entry != */ ]]; then
        printf '%s\0' "${entries[@]}"
        exit 0
    fi
done
scan "$2"
