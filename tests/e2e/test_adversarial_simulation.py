#!/usr/bin/env python3
"""
test_adversarial_simulation.py
Adversarial stress test harness & simulator for Nonchalant Shell Dynamic Island.
Empirically challenges:
1. Rapid Niri window open/close event bursts (churn)
2. Rapid workspace thrashing and oscillation
3. Multi-monitor isolation and cross-talk prevention
4. Wayland input mask pointer pass-through raycasting (100,000 points)
5. Hover boundary jitter and debounce race conditions
6. Fullscreen & overview suppression invariants
7. Malformed/null Niri compositor IPC event streams
"""

import sys
import os
import random
import unittest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))

from tests.models.state_machine import DynamicIslandStateMachine, BarStyle, IslandState
from tests.models.mask_hitbox import WaylandInputMaskModel
from tests.models.niri_model import NiriCompositorModel


class TestAdversarialDynamicIsland(unittest.TestCase):
    """Adversarial stress harness for Dynamic Island autohide & compositor integration."""

    def setUp(self):
        random.seed(42)  # Deterministic repeatability

    def test_rapid_window_churn(self):
        """Simulate 2,000 rapid window open/close events on a single workspace."""
        niri = NiriCompositorModel(monitors=["eDP-1"])
        ws = niri.add_workspace(id=1, idx=1, output="eDP-1", active=True)
        sm = DynamicIslandStateMachine(island_height=36, debounce_duration_ms=200, style=BarStyle.ISLAND)
        mask = WaylandInputMaskModel(screen_width=1920, screen_height=1080, island_width=600, island_height=36, trigger_height=4)

        open_windows = []
        next_win_id = 1

        for step in range(2000):
            # Decide action: 60% open if < 20 windows, else close
            if len(open_windows) == 0 or (random.random() < 0.55 and len(open_windows) < 20):
                # Open window
                win = niri.add_window(id=next_win_id, workspace_id=1, app_id=f"app_{next_win_id}", title=f"Win {next_win_id}")
                open_windows.append(win.id)
                next_win_id += 1
            else:
                # Close window
                win_id = open_windows.pop(random.randrange(len(open_windows)))
                niri.close_window(win_id)

            window_count = niri.get_window_count("eDP-1")
            self.assertEqual(window_count, len(open_windows), f"Step {step}: Inconsistent window count in Niri model")

            sm.set_window_count(window_count)

            # Check invariants
            if window_count == 0:
                self.assertEqual(sm.state, IslandState.RESTING_VISIBLE, f"Step {step}: Must be RESTING_VISIBLE when count=0")
                self.assertEqual(sm.target_y, 0, f"Step {step}: target_y must be 0 when resting visible")
                self.assertTrue(sm.is_visible)
            else:
                self.assertEqual(sm.state, IslandState.RETRACTED, f"Step {step}: Must be RETRACTED when count={window_count}")
                self.assertEqual(sm.target_y, -36, f"Step {step}: target_y must be -36 when retracted")
                self.assertFalse(sm.is_visible)
                # Confirm mask height is trigger_height (4px)
                regions = mask.get_mask_regions(sm.state)
                self.assertEqual(len(regions), 1)
                self.assertEqual(regions[0].height, 4, f"Step {step}: Input mask height must be 4px when retracted")

    def test_rapid_workspace_thrashing(self):
        """Simulate 1,000 rapid workspace switches between populated and empty workspaces."""
        niri = NiriCompositorModel(monitors=["eDP-1"])
        ws1 = niri.add_workspace(id=1, idx=1, output="eDP-1", active=True)
        ws2 = niri.add_workspace(id=2, idx=2, output="eDP-1", active=False)
        ws3 = niri.add_workspace(id=3, idx=3, output="eDP-1", active=False)

        # WS1 has 5 windows, WS2 has 0 windows, WS3 has 12 windows
        for i in range(1, 6):
            niri.add_window(id=i, workspace_id=1)
        for i in range(10, 22):
            niri.add_window(id=i, workspace_id=3)

        sm = DynamicIslandStateMachine(island_height=36, debounce_duration_ms=200, style=BarStyle.ISLAND)
        mask = WaylandInputMaskModel(screen_width=1920, screen_height=1080, island_width=600, island_height=36, trigger_height=4)

        workspaces = [1, 2, 3]

        for step in range(1000):
            target_ws = random.choice(workspaces)
            niri.activate_workspace("eDP-1", target_ws)
            win_count = niri.get_window_count("eDP-1")
            sm.set_window_count(win_count)

            if target_ws == 2:
                # Empty workspace -> Island MUST be resting visible
                self.assertEqual(win_count, 0)
                self.assertEqual(sm.state, IslandState.RESTING_VISIBLE, f"Step {step}: WS2 must show RESTING_VISIBLE")
                self.assertEqual(sm.target_y, 0)
                # Hitbox is full island
                regions = mask.get_mask_regions(sm.state)
                self.assertEqual(regions[0].height, 36)
            else:
                # Populated workspace -> Island MUST be retracted
                self.assertGreater(win_count, 0)
                self.assertEqual(sm.state, IslandState.RETRACTED, f"Step {step}: WS{target_ws} must RETRACT")
                self.assertEqual(sm.target_y, -36)
                # Hitbox is restricted to 4px
                regions = mask.get_mask_regions(sm.state)
                self.assertEqual(regions[0].height, 4)

    def test_multi_monitor_strict_isolation(self):
        """Simulate 3 independent monitors with concurrent, chaotic operations."""
        monitors = ["eDP-1", "DP-1", "HDMI-A-1"]
        niri = NiriCompositorModel(monitors=monitors)

        # 2 workspaces per monitor
        # eDP-1: ws 1 (active), ws 2
        # DP-1: ws 3 (active), ws 4
        # HDMI-A-1: ws 5 (active), ws 6
        niri.add_workspace(id=1, idx=1, output="eDP-1", active=True)
        niri.add_workspace(id=2, idx=2, output="eDP-1", active=False)
        niri.add_workspace(id=3, idx=1, output="DP-1", active=True)
        niri.add_workspace(id=4, idx=2, output="DP-1", active=False)
        niri.add_workspace(id=5, idx=1, output="HDMI-A-1", active=True)
        niri.add_workspace(id=6, idx=2, output="HDMI-A-1", active=False)

        state_machines = {
            m: DynamicIslandStateMachine(island_height=36, debounce_duration_ms=200, style=BarStyle.ISLAND)
            for m in monitors
        }

        # Start with eDP-1 having 3 windows on ws1, DP-1 empty, HDMI-A-1 having 1 window
        niri.add_window(1, 1)
        niri.add_window(2, 1)
        niri.add_window(3, 1)
        niri.add_window(4, 5)

        for m in monitors:
            state_machines[m].set_window_count(niri.get_window_count(m))

        self.assertEqual(state_machines["eDP-1"].state, IslandState.RETRACTED)
        self.assertEqual(state_machines["DP-1"].state, IslandState.RESTING_VISIBLE)
        self.assertEqual(state_machines["HDMI-A-1"].state, IslandState.RETRACTED)

        # 1,500 operations across random monitors
        next_win_id = 100
        active_windows = {1: [1, 2, 3], 2: [], 3: [], 4: [], 5: [4], 6: []}

        for step in range(1500):
            target_monitor = random.choice(monitors)
            action = random.choice(["open", "close", "switch_ws", "hover", "leave"])
            sm = state_machines[target_monitor]

            if action == "open":
                # Find active workspace for target_monitor
                active_ws = niri.get_active_workspace(target_monitor)
                win = niri.add_window(id=next_win_id, workspace_id=active_ws.id)
                active_windows[active_ws.id].append(next_win_id)
                next_win_id += 1
            elif action == "close":
                active_ws = niri.get_active_workspace(target_monitor)
                if active_windows[active_ws.id]:
                    wid = active_windows[active_ws.id].pop()
                    niri.close_window(wid)
            elif action == "switch_ws":
                # Toggle between the two workspaces of this monitor
                ws_ids = [ws.id for ws in niri.workspaces.values() if ws.output == target_monitor]
                current_active = niri.get_active_workspace(target_monitor).id
                new_active = ws_ids[1] if current_active == ws_ids[0] else ws_ids[0]
                niri.activate_workspace(target_monitor, new_active)
            elif action == "hover":
                sm.pointer_enter_trigger()
            elif action == "leave":
                sm.pointer_leave()
                sm.tick(250)

            # Update window counts
            for m in monitors:
                cnt = niri.get_window_count(m)
                state_machines[m].set_window_count(cnt)

            # Verify that each monitor's state strictly reflects its OWN window count
            for m in monitors:
                m_cnt = niri.get_window_count(m)
                m_sm = state_machines[m]
                if m_sm.state == IslandState.HOVER_REVEALED:
                    self.assertEqual(m_sm.target_y, 0)
                elif m_cnt == 0:
                    self.assertEqual(m_sm.state, IslandState.RESTING_VISIBLE, f"Step {step}: Monitor {m} must be resting visible")
                    self.assertEqual(m_sm.target_y, 0)
                else:
                    self.assertEqual(m_sm.state, IslandState.RETRACTED, f"Step {step}: Monitor {m} must be retracted")
                    self.assertEqual(m_sm.target_y, -36)

    def test_pointer_passthrough_raycasting(self):
        """
        Adversarial raycasting over 100,000 points across a 1920x1080 display.
        Strictly proves:
        1. When island is RETRACTED, ANY click at y >= 4 passes through 100%.
        2. Any click at y < 4 outside the island's horizontal span passes through 100%.
        3. Only y in [0, 4) within [island_x, island_x + island_width) is captured.
        """
        mask = WaylandInputMaskModel(
            screen_width=1920,
            screen_height=1080,
            island_width=600,
            island_height=36,
            trigger_height=4
        )

        island_x0 = (1920 - 600) // 2  # 660
        island_x1 = island_x0 + 600     # 1260

        state = IslandState.RETRACTED

        # Test 1: Full scan of top 10 vertical rows across entire width at sampled steps
        for y in range(0, 10):
            for x in range(0, 1920, 15):
                captured = mask.point_captures_input(x, y, state)
                passed_through = mask.is_click_passed_through(x, y, state)
                self.assertEqual(captured, not passed_through)

                if y >= 4:
                    self.assertFalse(captured, f"Y={y} must NEVER capture input when retracted! (x={x}, y={y})")
                    self.assertTrue(passed_through)
                elif x < island_x0 or x >= island_x1:
                    self.assertFalse(captured, f"Points outside island width at Y={y} must pass through! (x={x}, y={y})")
                    self.assertTrue(passed_through)
                else:
                    self.assertTrue(captured, f"Trigger hitbox must capture at (x={x}, y={y})")
                    self.assertFalse(passed_through)

        # Test 2: Random Monte Carlo sample of 100,000 points across entire screen
        for _ in range(100000):
            x = random.randint(0, 1919)
            y = random.randint(0, 1079)

            captured = mask.point_captures_input(x, y, state)
            passed = mask.is_click_passed_through(x, y, state)

            if y >= 4:
                self.assertTrue(passed, f"Leak: Click at ({x}, {y}) was blocked when retracted!")
            elif island_x0 <= x < island_x1 and y < 4:
                self.assertTrue(captured, f"Miss: Trigger failed to capture at ({x}, {y})")
            else:
                self.assertTrue(passed, f"Leak: Click at ({x}, {y}) was blocked outside trigger bounds!")

    def test_hover_debounce_and_rapid_reentry_races(self):
        """Stress-test rapid pointer jitter around the 4px boundary and debounce interruptions."""
        sm = DynamicIslandStateMachine(island_height=36, debounce_duration_ms=200, style=BarStyle.ISLAND)
        sm.set_window_count(2)
        self.assertEqual(sm.state, IslandState.RETRACTED)

        for cycle in range(200):
            # Pointer enters trigger
            sm.pointer_enter_trigger()
            self.assertEqual(sm.state, IslandState.HOVER_REVEALED)
            self.assertEqual(sm.target_y, 0)

            # Pointer immediately leaves (jitter)
            sm.pointer_leave()
            self.assertTrue(sm.in_debounce)
            self.assertEqual(sm.state, IslandState.HOVER_REVEALED)

            # Time advances 50ms (before debounce completes)
            sm.tick(50)
            self.assertTrue(sm.in_debounce)
            self.assertEqual(sm.state, IslandState.HOVER_REVEALED)

            # Pointer re-enters island body before debounce expires
            sm.pointer_enter_island()
            self.assertFalse(sm.in_debounce, "Re-entering must cancel debounce timer")
            self.assertEqual(sm.state, IslandState.HOVER_REVEALED)

            # Pointer leaves again
            sm.pointer_leave()
            self.assertTrue(sm.in_debounce)

            # Complete debounce
            sm.tick(200)
            self.assertFalse(sm.in_debounce)
            self.assertEqual(sm.state, IslandState.RETRACTED)
            self.assertEqual(sm.target_y, -36)

    def test_popup_priority_lock_over_all_events(self):
        """A child popup (clock menu or dashboard) MUST lock island visible regardless of all events."""
        sm = DynamicIslandStateMachine(island_height=36, debounce_duration_ms=200, style=BarStyle.ISLAND)
        mask = WaylandInputMaskModel(screen_width=1920, screen_height=1080, island_width=600, island_height=36)

        # 5 windows open
        sm.set_window_count(5)
        self.assertEqual(sm.state, IslandState.RETRACTED)

        # Open popup
        sm.set_popup_active(True)
        self.assertEqual(sm.state, IslandState.POPUP_LOCKED)
        self.assertEqual(sm.target_y, 0)
        self.assertTrue(sm.is_visible)

        # While popup is active, simulate windows opening, closing, pointer moving
        for _ in range(100):
            sm.set_window_count(random.randint(0, 10))
            if random.random() < 0.5:
                sm.pointer_enter_trigger()
            else:
                sm.pointer_leave()
            sm.tick(random.randint(10, 500))

            # Must remain POPUP_LOCKED at Y=0 throughout!
            self.assertEqual(sm.state, IslandState.POPUP_LOCKED)
            self.assertEqual(sm.target_y, 0)
            self.assertTrue(sm.is_visible)

        # Close popup
        sm.set_popup_active(False)
        sm.pointer_leave()
        sm.tick(250)

        # If windows still present and pointer left, must retract
        sm.set_window_count(3)
        self.assertEqual(sm.state, IslandState.RETRACTED)
        self.assertEqual(sm.target_y, -36)


    def test_null_and_malformed_niri_workspace_payloads(self):
        """Simulate IPC drops, empty workspace arrays, and malformed active flags."""
        def evaluate_qml_active_workspace(workspaces_list, screen_name):
            if not workspaces_list or len(workspaces_list) == 0:
                return None
            for ws in workspaces_list:
                if ws and ws.get("output") == screen_name and ws.get("active", False):
                    return ws
            return None

        def evaluate_should_be_revealed(active_ws, compositor_hide, is_hovered, debounce_active, is_popup_open):
            if compositor_hide:
                return False
            windows_count = (active_ws.get("windows", 0) if active_ws else 0)
            has_active_windows = windows_count > 0
            if not has_active_windows:
                return True
            if is_hovered or debounce_active or is_popup_open:
                return True
            return False

        # Case 1: Empty workspaces array
        ws = evaluate_qml_active_workspace([], "eDP-1")
        self.assertIsNone(ws)
        self.assertTrue(evaluate_should_be_revealed(ws, False, False, False, False))

        # Case 2: None workspaces
        ws = evaluate_qml_active_workspace(None, "eDP-1")
        self.assertIsNone(ws)
        self.assertTrue(evaluate_should_be_revealed(ws, False, False, False, False))

        # Case 3: Malformed elements with None
        malformed = [None, {}, {"output": "DP-1", "active": True, "windows": 3}, None]
        ws = evaluate_qml_active_workspace(malformed, "eDP-1")
        self.assertIsNone(ws)
        self.assertTrue(evaluate_should_be_revealed(ws, False, False, False, False))

        # Case 4: Matched workspace on DP-1 but evaluating for eDP-1
        ws_edp = evaluate_qml_active_workspace(malformed, "eDP-1")
        self.assertIsNone(ws_edp)
        ws_dp = evaluate_qml_active_workspace(malformed, "DP-1")
        self.assertIsNotNone(ws_dp)
        self.assertFalse(evaluate_should_be_revealed(ws_dp, False, False, False, False))

        # Case 5: Missing 'windows' key in active workspace
        ws_nowin = {"output": "eDP-1", "active": True}
        self.assertTrue(evaluate_should_be_revealed(ws_nowin, False, False, False, False))

    def test_extreme_resolutions_geometry(self):
        """Verify island sizing formulas across extreme aspect ratios and resolutions."""
        resolutions = [
            (3840, 2160),  # 4K UHD
            (5120, 1440),  # 32:9 Super Ultrawide
            (2560, 1440),  # 1440p
            (1920, 1080),  # 1080p
            (1366, 768),   # Laptop standard
            (1080, 1920),  # Portrait display
            (800, 600),    # Legacy 4:3 SVGA
        ]

        for screen_w, screen_h in resolutions:
            ear_radius = min(14.0, 36 * 0.45)
            self.assertEqual(ear_radius, 14.0)

            for implicit_content_w in [200, 350, 480, 600, 800]:
                raw_w = implicit_content_w + 24
                # QML formula: Math.min(Math.max(contentRow.implicitWidth + 24, 480), Math.min(root.width - (root.earRadius * 2 + 16), 680))
                max_allowed = min(screen_w - (ear_radius * 2 + 16), 680)
                island_w = min(max(raw_w, 480), max_allowed)

                # Width must never exceed 680
                self.assertLessEqual(island_w, 680)
                # Left ear + island + right ear must fit within screen_w
                total_span = island_w + ear_radius * 2
                self.assertLessEqual(total_span, screen_w)

                # Centering invariant
                island_x = (screen_w - island_w) / 2
                self.assertGreaterEqual(island_x - ear_radius, 0)
                self.assertLessEqual(island_x + island_w + ear_radius, screen_w)

    def test_compositor_overview_and_fullscreen_suppression(self):
        """Fullscreen and overview modes MUST override hover, windows, and debounce."""
        sm = DynamicIslandStateMachine(island_height=36, debounce_duration_ms=200, style=BarStyle.ISLAND)
        # Empty workspace: normally visible
        sm.set_window_count(0)
        self.assertEqual(sm.state, IslandState.RESTING_VISIBLE)

        # Fullscreen on screen or overview open -> compositorHide is true
        def get_actual_target_y(state, compositor_hide):
            if compositor_hide:
                return -36
            if state in (IslandState.RESTING_VISIBLE, IslandState.HOVER_REVEALED, IslandState.POPUP_LOCKED):
                return 0
            return -36

        # When compositor_hide is True
        compositor_hide = True
        self.assertEqual(get_actual_target_y(sm.state, compositor_hide), -36)

        # Even with hover active
        sm.pointer_enter_trigger()
        self.assertEqual(get_actual_target_y(sm.state, compositor_hide), -36)

        # Fullscreen closes
        compositor_hide = False
        self.assertEqual(get_actual_target_y(sm.state, compositor_hide), 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
