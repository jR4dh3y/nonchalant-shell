#!/usr/bin/env bash

set -euo pipefail

font_root="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"
shell_font_dir="$font_root/nonchalant"
phosphor_font_dir="$font_root/phosphor"

has_font_family() {
    fc-list ":family=$1" family 2>/dev/null | grep -Fqi "$1"
}

mkdir -p "$shell_font_dir" "$phosphor_font_dir"

if ! has_font_family "Phosphor-Bold"; then
    phosphor_archive="$(mktemp "${TMPDIR:-/tmp}/nonchalant-phosphor.XXXXXX.zip")"
    trap 'unlink "$phosphor_archive" 2>/dev/null || true' EXIT

    curl --fail --location --silent --show-error \
        "https://github.com/phosphor-icons/web/archive/refs/tags/v2.1.2.zip" \
        --output "$phosphor_archive"
    unzip -qjo "$phosphor_archive" '*/src/*/*.ttf' -d "$phosphor_font_dir"
fi

if ! has_font_family "Roboto Condensed"; then
    curl --fail --location --silent --show-error \
        'https://raw.githubusercontent.com/google/fonts/main/ofl/robotocondensed/RobotoCondensed%5Bwght%5D.ttf' \
        --output "$shell_font_dir/RobotoCondensed-Variable.ttf"
fi

if ! has_font_family "League Gothic"; then
    curl --fail --location --silent --show-error \
        'https://raw.githubusercontent.com/google/fonts/main/ofl/leaguegothic/LeagueGothic%5Bwdth%5D.ttf' \
        --output "$shell_font_dir/LeagueGothic-Variable.ttf"
fi

fc-cache -f "$font_root"

printf 'Nonchalant fonts are ready:\n'
fc-match ':family=Phosphor-Bold'
fc-match ':family=Roboto Condensed'
fc-match ':family=League Gothic'
