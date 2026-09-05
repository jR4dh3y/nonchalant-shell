"""
mask_hitbox.py
Model for Wayland input region masking (WlrLayershell mask / Region) and click pass-through.
"""

from typing import List, Tuple, Optional
from tests.models.state_machine import IslandState

class Rect:
    def __init__(self, x: int, y: int, width: int, height: int):
        self.x = int(x)
        self.y = int(y)
        self.width = int(width)
        self.height = int(height)

    def contains(self, px: int, py: int) -> bool:
        return (self.x <= px < self.x + self.width and
                self.y <= py < self.y + self.height)

    def __repr__(self):
        return f"Rect(x={self.x}, y={self.y}, w={self.width}, h={self.height})"


class WaylandInputMaskModel:
    def __init__(self,
                 screen_width: int = 1920,
                 screen_height: int = 1080,
                 island_width: int = 600,
                 island_height: int = 36,
                 trigger_height: int = 4,
                 full_width_trigger: bool = False):
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.island_width = island_width
        self.island_height = island_height
        self.trigger_height = trigger_height
        self.full_width_trigger = full_width_trigger

    @property
    def island_x(self) -> int:
        return (self.screen_width - self.island_width) // 2

    def get_mask_regions(self, state: IslandState, full_screen_popup_open: bool = False) -> List[Rect]:
        """
        Returns the list of active input capture Rects configured in UnifiedShellPanel.mask.
        Points outside these Rects fall through to underlying application windows.
        """
        if full_screen_popup_open or state == IslandState.POPUP_LOCKED:
            # Full screen capture for open modal popups / dashboard / run menu
            return [Rect(0, 0, self.screen_width, self.screen_height)]

        if state == IslandState.RETRACTED:
            # When retracted, only the 4px trigger hitbox receives input!
            tx = 0 if self.full_width_trigger else self.island_x
            tw = self.screen_width if self.full_width_trigger else self.island_width
            return [Rect(tx, 0, tw, self.trigger_height)]

        # When visible or hover-revealed, island body receives input
        return [Rect(self.island_x, 0, self.island_width, self.island_height)]

    def point_captures_input(self, x: int, y: int, state: IslandState, full_screen_popup_open: bool = False) -> bool:
        """Returns True if (x, y) is captured by the shell panel; False if it passes through to apps."""
        regions = self.get_mask_regions(state, full_screen_popup_open)
        return any(r.contains(x, y) for r in regions)

    def is_click_passed_through(self, x: int, y: int, state: IslandState, full_screen_popup_open: bool = False) -> bool:
        """Returns True if clicks at (x, y) reach the underlying client window."""
        return not self.point_captures_input(x, y, state, full_screen_popup_open)
