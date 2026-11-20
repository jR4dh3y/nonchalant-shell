#!/usr/bin/env python3
"""Print a static color preset with the shell's status roles filled in.

Presets written before the status roles existed author danger as `error` and
the other status hues in the terminal slots. Use those for missing roles;
authored values win.
Every published palette must carry every role: a reloaded JsonAdapter keeps
the previous value for a key the new file leaves out.
"""

import json
from pathlib import Path
import sys

STATUS_FALLBACKS = {
    "danger": "error",
    "overDanger": "overError",
    "warning": "yellow",
    "overWarning": "overYellow",
    "success": "green",
    "overSuccess": "overGreen",
}


def complete(palette: dict[str, str]) -> dict[str, str]:
    return {**{role: palette[slot] for role, slot in STATUS_FALLBACKS.items() if slot in palette}, **palette}


def main() -> int:
    paths = [Path(argument) for argument in sys.argv[1:] if argument]
    preset = next((path for path in paths if path.is_file()), None)
    if preset is None:
        print(json.dumps({"error": "Color preset not found"}), file=sys.stderr)
        return 1
    try:
        palette = json.loads(preset.read_text())
        if not isinstance(palette, dict):
            raise ValueError("Color preset is not an object")
    except (OSError, ValueError) as error:
        print(json.dumps({"error": str(error)}), file=sys.stderr)
        return 1
    print(json.dumps(complete(palette), indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
