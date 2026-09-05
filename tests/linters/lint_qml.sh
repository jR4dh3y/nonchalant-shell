#!/usr/bin/env bash
# lint_qml.sh
# Validates QML syntax across shell files using qmllint.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Locate Qt6 qmllint if available, else PATH
if [ -x "/usr/lib/qt6/bin/qmllint" ]; then
    QMLLINT="/usr/lib/qt6/bin/qmllint"
elif command -v qmllint >/dev/null 2>&1; then
    QMLLINT="$(command -v qmllint)"
else
    echo "ERROR: qmllint binary not found" >&2
    exit 1
fi

echo "Using QML Linter: $QMLLINT ($("$QMLLINT" --version 2>/dev/null || echo 'v1.0'))"

# Candidate files to lint
CORE_FILES=(
    "shell.qml"
    "config/Config.qml"
    "modules/bar/BarContent.qml"
    "modules/shell/ReservationWindows.qml"
    "modules/shell/UnifiedShellPanel.qml"
    "modules/widgets/dashboard/controls/ShellPanel.qml"
)

# Also include modular bar files if they exist
OPTIONAL_FILES=(
    "modules/bar/layouts/DefaultBar.qml"
    "modules/bar/layouts/IslandBar.qml"
    "modules/bar/island/IslandEar.qml"
    "modules/bar/island/IslandDashboard.qml"
    "modules/bar/island/IslandPowerPanel.qml"
    "modules/bar/island/IslandSoundPanel.qml"
    "modules/bar/island/IslandMicPanel.qml"
    "modules/bar/island/IslandWifiPanel.qml"
    "modules/bar/island/IslandBluetoothPanel.qml"
    "modules/bar/island/IslandStatsPanel.qml"
    "modules/bar/island/IslandAlertsPanel.qml"
    "modules/bar/island/IslandWallpaperPanel.qml"
    "modules/bar/island/IslandBatteryPanel.qml"
    "modules/bar/island/IslandWeatherPanel.qml"
    "modules/bar/island/IslandGaugeButton.qml"
    "modules/bar/island/IslandMediaCard.qml"
    "modules/bar/island/IslandWaveformBar.qml"
)

FILES_TO_LINT=()
for f in "${CORE_FILES[@]}"; do
    if [ -f "$ROOT_DIR/$f" ]; then
        FILES_TO_LINT+=("$ROOT_DIR/$f")
    fi
done

for f in "${OPTIONAL_FILES[@]}"; do
    if [ -f "$ROOT_DIR/$f" ]; then
        FILES_TO_LINT+=("$ROOT_DIR/$f")
    fi
done

# If arguments passed, lint those instead
if [ "$#" -gt 0 ]; then
    FILES_TO_LINT=("$@")
fi

echo "Linting ${#FILES_TO_LINT[@]} QML files..."

SYNTAX_ERRORS=0
for file in "${FILES_TO_LINT[@]}"; do
    REL_PATH="${file#$ROOT_DIR/}"
    # Run qmllint and capture output
    OUTPUT=""
    if ! OUTPUT=$("$QMLLINT" "$file" 2>&1); then
        # Check if output contains fatal syntax error
        if echo "$OUTPUT" | grep -qiE "Expected token|Unexpected token|Syntax error"; then
            echo "  ✗ SYNTAX ERROR in $REL_PATH:"
            echo "$OUTPUT" | grep -iE "Expected token|Unexpected token|Syntax error" | head -n 5
            SYNTAX_ERRORS=$((SYNTAX_ERRORS + 1))
        else
            echo "  ✓ $REL_PATH (passed syntax check)"
        fi
    else
        echo "  ✓ $REL_PATH (passed syntax check)"
    fi
done

if [ "$SYNTAX_ERRORS" -gt 0 ]; then
    echo "FAILED: $SYNTAX_ERRORS file(s) failed QML syntax validation."
    exit 1
else
    echo "SUCCESS: All ${#FILES_TO_LINT[@]} QML files passed syntax validation."
    exit 0
fi
