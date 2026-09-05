"""
state_machine.py
State machine model for Dynamic Island autohide, debounce, and popup locking.
"""

from enum import Enum
from typing import Optional, List, Callable

class BarStyle(str, Enum):
    DEFAULT = "default"
    ISLAND = "island"

class IslandState(str, Enum):
    RESTING_VISIBLE = "resting_visible"
    RETRACTED = "retracted"
    HOVER_REVEALED = "hover_revealed"
    POPUP_LOCKED = "popup_locked"

class DynamicIslandStateMachine:
    def __init__(self,
                 island_height: int = 36,
                 debounce_duration_ms: int = 250,
                 style: BarStyle = BarStyle.ISLAND):
        self.island_height = island_height
        self.debounce_duration_ms = debounce_duration_ms
        self.style = style

        self.window_count: int = 0
        self.is_pointer_in_trigger: bool = False
        self.is_pointer_in_island: bool = False
        self.popup_active: bool = False

        self._debounce_remaining_ms: int = 0
        self._in_debounce: bool = False

        # State transition history for debugging and verification
        self.history: List[IslandState] = []
        self._current_state = IslandState.RESTING_VISIBLE
        self.history.append(self._current_state)

    @property
    def state(self) -> IslandState:
        return self._current_state

    @property
    def in_debounce(self) -> bool:
        return self._in_debounce

    @property
    def debounce_remaining_ms(self) -> int:
        return self._debounce_remaining_ms

    @property
    def target_y(self) -> int:
        if self.style == BarStyle.DEFAULT:
            return 0
        if self._current_state in (IslandState.RESTING_VISIBLE, IslandState.HOVER_REVEALED, IslandState.POPUP_LOCKED):
            return 0
        return -self.island_height

    @property
    def is_visible(self) -> bool:
        if self.style == BarStyle.DEFAULT:
            return True
        return self._current_state != IslandState.RETRACTED

    def set_style(self, style: BarStyle):
        if self.style != style:
            self.style = style
            self._evaluate_state()

    def set_window_count(self, count: int):
        self.window_count = max(0, count)
        self._evaluate_state()

    def pointer_enter_trigger(self):
        self.is_pointer_in_trigger = True
        self._in_debounce = False
        self._debounce_remaining_ms = 0
        self._evaluate_state()

    def pointer_enter_island(self):
        self.is_pointer_in_island = True
        self._in_debounce = False
        self._debounce_remaining_ms = 0
        self._evaluate_state()

    def pointer_leave(self):
        self.is_pointer_in_trigger = False
        self.is_pointer_in_island = False

        # If we were revealed due to hover, begin leave debounce if duration > 0
        if self._current_state == IslandState.HOVER_REVEALED and self.debounce_duration_ms > 0:
            self._in_debounce = True
            self._debounce_remaining_ms = self.debounce_duration_ms
        else:
            self._in_debounce = False
            self._debounce_remaining_ms = 0

        self._evaluate_state()

    def set_popup_active(self, active: bool):
        self.popup_active = active
        self._evaluate_state()

    def tick(self, delta_ms: int):
        """Simulate passage of time in milliseconds."""
        if self._in_debounce:
            self._debounce_remaining_ms -= delta_ms
            if self._debounce_remaining_ms <= 0:
                self._in_debounce = False
                self._debounce_remaining_ms = 0
                self._evaluate_state()

    def _transition_to(self, new_state: IslandState):
        if self._current_state != new_state:
            self._current_state = new_state
            self.history.append(new_state)

    def _evaluate_state(self):
        if self.style != BarStyle.ISLAND:
            self._transition_to(IslandState.RESTING_VISIBLE)
            return

        # 1. Popup priority: if child popup or dashboard is active, island MUST stay locked visible
        if self.popup_active:
            self._transition_to(IslandState.POPUP_LOCKED)
            return

        # 2. If no windows present on active workspace, island rests visible
        if self.window_count == 0:
            self._in_debounce = False
            self._debounce_remaining_ms = 0
            self._transition_to(IslandState.RESTING_VISIBLE)
            return

        # 3. Windows are present:
        # If pointer is inside trigger or island body
        if self.is_pointer_in_trigger or self.is_pointer_in_island:
            self._in_debounce = False
            self._debounce_remaining_ms = 0
            self._transition_to(IslandState.HOVER_REVEALED)
            return

        # If we are waiting out the leave debounce period
        if self._in_debounce:
            self._transition_to(IslandState.HOVER_REVEALED)
            return

        # 4. Otherwise, retract off-screen
        self._transition_to(IslandState.RETRACTED)
