#!/usr/bin/env bash
# run_tests.sh
# Nonchalant Shell Dynamic Island Test Suite Runner wrapper.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

export PYTHONPATH="$ROOT_DIR:${PYTHONPATH:-}"

python3 "$SCRIPT_DIR/run_tests.py" "$@"
