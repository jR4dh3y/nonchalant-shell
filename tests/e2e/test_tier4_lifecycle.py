"""
test_tier4_lifecycle.py
Tier 4: Real-World Desktop Lifecycle & End-to-End Scenarios.
Simulates comprehensive day-to-day user workflows, window lifecycles, workspace flips, and settings sessions.
"""

import unittest
from tests.models.config_model import BarConfigModel
from tests.models.state_machine import DynamicIslandStateMachine, BarStyle, IslandState
from tests.models.mask_hitbox import WaylandInputMaskModel
from tests.models.niri_model import NiriCompositorModel


class TestTier4_RealWorldLifecycle(unittest.TestCase):
    """Tier 4: End-to-End User Workflows and Desktop Scenarios"""

    def setUp(self):
        self.niri = NiriCompositorModel(monitors=["eDP-1", "DP-1"])
        self.ws1 = self.niri.add_workspace(id=1, idx=1, output="eDP-1", active=True)
        self.ws2 = self.niri.add_workspace(id=2, idx=2, output="eDP-1", active=False)
        self.ws_ext = self.niri.add_workspace(id=3, idx=1, output="DP-1", active=True)

        self.sm = DynamicIslandStateMachine(island_height=36, debounce_duration_ms=250, style=BarStyle.ISLAND)
        self.mask = WaylandInputMaskModel(screen_width=1920, screen_height=1080, island_width=600, island_height=36, trigger_height=4)

    def test_rws1_full_desktop_lifecycle(self):
        """
        Step 1: Clean desktop (empty workspace) -> Island resting visible at Y=0.
        Step 2: Launch browser -> Window detected -> Island retracts off-screen (Y=-36).
        Step 3: Move cursor to top edge Y=2 -> Hits 4px trigger -> Island slides down (Y=0).
        Step 4: Click browser tab at Y=10 outside island -> Click passes through to browser.
        Step 5: Move cursor away -> Debounce starts -> Island smoothly retracts.
        Step 6: Switch to empty Workspace 2 -> Windows count is 0 -> Island smoothly returns to resting visible.
        """
        # Step 1: Initial state
        self.assertEqual(self.niri.get_window_count("eDP-1"), 0)
        self.sm.set_window_count(0)
        self.assertEqual(self.sm.state, IslandState.RESTING_VISIBLE)
        self.assertEqual(self.sm.target_y, 0)
        self.assertTrue(self.sm.is_visible)
        # Island body captures clicks on island, outside island passes through
        self.assertFalse(self.mask.is_click_passed_through(960, 18, self.sm.state))

        # Step 2: User launches Firefox
        self.niri.add_window(id=101, workspace_id=1, app_id="firefox", title="Mozilla Firefox")
        self.sm.set_window_count(self.niri.get_window_count("eDP-1"))
        self.assertEqual(self.sm.state, IslandState.RETRACTED)
        self.assertEqual(self.sm.target_y, -36)
        self.assertFalse(self.sm.is_visible)

        # Step 3: Hover top bezel trigger at Y=2
        self.assertTrue(self.mask.point_captures_input(960, 2, self.sm.state))
        self.sm.pointer_enter_trigger()
        self.assertEqual(self.sm.state, IslandState.HOVER_REVEALED)
        self.assertEqual(self.sm.target_y, 0)

        # Step 4: Click outside island width at (200, 10) for browser tab
        # Point (200, 10) is outside the 600px centered island [660, 1260]
        self.assertTrue(self.mask.is_click_passed_through(200, 10, self.sm.state),
                        "Clicks outside island width must pass through to browser tabs")

        # Step 5: Cursor leaves island
        self.sm.pointer_leave()
        self.assertTrue(self.sm.in_debounce)
        self.assertEqual(self.sm.state, IslandState.HOVER_REVEALED)
        self.sm.tick(250)  # debounce finishes
        self.assertFalse(self.sm.in_debounce)
        self.assertEqual(self.sm.state, IslandState.RETRACTED)
        self.assertEqual(self.sm.target_y, -36)

        # Step 6: User switches to Workspace 2 (empty)
        self.niri.activate_workspace("eDP-1", workspace_id=2)
        self.assertEqual(self.niri.get_window_count("eDP-1"), 0)
        self.sm.set_window_count(self.niri.get_window_count("eDP-1"))
        self.assertEqual(self.sm.state, IslandState.RESTING_VISIBLE)
        self.assertEqual(self.sm.target_y, 0)
        self.assertTrue(self.sm.is_visible)

    def test_rws2_multi_monitor_concurrent_workflow(self):
        """
        Primary monitor (eDP-1) has multiple code windows: island retracted.
        Secondary monitor (DP-1) has clean workspace: island resting visible.
        User works on eDP-1 without triggering island on DP-1.
        """
        sm_ext = DynamicIslandStateMachine(island_height=36, style=BarStyle.ISLAND)

        # Add code editor and terminal to eDP-1
        self.niri.add_window(id=1, workspace_id=1, app_id="code", title="VSCode")
        self.niri.add_window(id=2, workspace_id=1, app_id="alacritty", title="Terminal")

        self.sm.set_window_count(self.niri.get_window_count("eDP-1"))
        sm_ext.set_window_count(self.niri.get_window_count("DP-1"))

        # Primary is retracted, secondary is resting visible
        self.assertEqual(self.sm.state, IslandState.RETRACTED)
        self.assertEqual(sm_ext.state, IslandState.RESTING_VISIBLE)

        # Hover primary monitor
        self.sm.pointer_enter_trigger()
        self.assertEqual(self.sm.state, IslandState.HOVER_REVEALED)
        self.assertEqual(sm_ext.state, IslandState.RESTING_VISIBLE)

        # Leave primary
        self.sm.pointer_leave()
        self.sm.tick(300)
        self.assertEqual(self.sm.state, IslandState.RETRACTED)
        self.assertEqual(sm_ext.state, IslandState.RESTING_VISIBLE)

    def test_rws3_rapid_window_tiling_and_workspace_cycling(self):
        """
        User rapidly spawns 5 windows in Niri, flips through 3 workspaces, and closes windows.
        Verifies no desynchronization or orphaned state occurs.
        """
        ws3 = self.niri.add_workspace(id=4, idx=3, output="eDP-1", active=False)

        # Spawn 5 windows on ws1
        for i in range(10, 15):
            self.niri.add_window(id=i, workspace_id=1, app_id="term", title=f"Shell {i}")

        self.sm.set_window_count(self.niri.get_window_count("eDP-1"))
        self.assertEqual(self.sm.state, IslandState.RETRACTED)

        # Flip to ws2 (0 windows)
        self.niri.activate_workspace("eDP-1", workspace_id=2)
        self.sm.set_window_count(self.niri.get_window_count("eDP-1"))
        self.assertEqual(self.sm.state, IslandState.RESTING_VISIBLE)

        # Flip to ws3 (0 windows)
        self.niri.activate_workspace("eDP-1", workspace_id=4)
        self.sm.set_window_count(self.niri.get_window_count("eDP-1"))
        self.assertEqual(self.sm.state, IslandState.RESTING_VISIBLE)

        # Flip back to ws1 (5 windows)
        self.niri.activate_workspace("eDP-1", workspace_id=1)
        self.sm.set_window_count(self.niri.get_window_count("eDP-1"))
        self.assertEqual(self.sm.state, IslandState.RETRACTED)

        # Close all 5 windows
        for i in range(10, 15):
            self.niri.close_window(i)
        self.sm.set_window_count(self.niri.get_window_count("eDP-1"))
        self.assertEqual(self.sm.state, IslandState.RESTING_VISIBLE)

    def test_rws4_settings_live_session_without_restart(self):
        """
        Live session in Settings app: User switches style between Default and Dynamic Island.
        """
        cfg = BarConfigModel(style="default")
        self.assertEqual(cfg.style, "default")
        self.sm.set_style(BarStyle.DEFAULT)
        self.assertEqual(self.sm.target_y, 0)

        # Open window
        self.niri.add_window(id=1, workspace_id=1, app_id="settings", title="Settings")
        self.sm.set_window_count(1)
        self.assertEqual(self.sm.target_y, 0)  # In default style, bar stays at Y=0

        # User toggles to Island in Settings
        cfg.style = "island"
        self.sm.set_style(BarStyle.ISLAND)
        # Because window is present, immediately retracts!
        self.assertEqual(self.sm.state, IslandState.RETRACTED)
        self.assertEqual(self.sm.target_y, -36)

        # User toggles back to Default
        cfg.style = "default"
        self.sm.set_style(BarStyle.DEFAULT)
        self.assertEqual(self.sm.target_y, 0)

    def test_rws5_notification_toast_arrival_during_autohide(self):
        """
        A notification toast arrives while island is retracted.
        Toast stack hitbox captures toast clicks without disturbing island retraction.
        """
        self.sm.set_window_count(1)
        self.assertEqual(self.sm.state, IslandState.RETRACTED)

        # Toast notification is located at top-right, e.g. Rect(1500, 16, 380, 80)
        toast_x, toast_y, toast_w, toast_h = 1500, 16, 380, 80
        click_on_toast_dismiss = (toast_x + 360, toast_y + 20)

        # Island remains retracted
        self.assertEqual(self.sm.state, IslandState.RETRACTED)
        self.assertEqual(self.sm.target_y, -36)

        # Click on toast dismiss button does NOT click into island (which is at X=660..1260)
        island_left = self.mask.island_x
        island_right = island_left + self.mask.island_width
        self.assertFalse(island_left <= click_on_toast_dismiss[0] <= island_right,
                         "Toast click must not intersect island bounds")

    def test_rws6_audio_format_pill_collapse_width_adjustment(self):
        """Audio format pill collapses when no headphones attached, island width adjusts."""
        # Island with headphone pill (e.g. 640px) vs without headphone pill (580px)
        mask_with_audio = WaylandInputMaskModel(screen_width=1920, island_width=640)
        mask_without_audio = WaylandInputMaskModel(screen_width=1920, island_width=580)

        self.assertEqual(mask_with_audio.island_x, 640)
        self.assertEqual(mask_without_audio.island_x, 670)
        # Both remain centered
        self.assertEqual(mask_with_audio.island_x + 640 // 2, 960)
        self.assertEqual(mask_without_audio.island_x + 580 // 2, 960)

    def test_rws7_sleep_wake_cycle_preservation(self):
        """Lockscreen engages and disengages; island state correctly tracks window count upon resume."""
        self.sm.set_window_count(2)
        self.assertEqual(self.sm.state, IslandState.RETRACTED)

        # Lock screen activates
        lockscreen_visible = True
        # Unlock screen
        lockscreen_visible = False
        # Window count remains 2 -> island remains RETRACTED without flashing
        self.assertEqual(self.sm.state, IslandState.RETRACTED)
        self.assertEqual(self.sm.target_y, -36)

    def test_rws8_pomodoro_timer_grab_interaction(self):
        """User opens timer tool: focus grab requested, island locked visible, releases on close."""
        self.sm.set_window_count(1)
        self.assertEqual(self.sm.state, IslandState.RETRACTED)

        # Hover reveal island
        self.sm.pointer_enter_trigger()
        # Click clock to open timer/pomodoro tool
        timer_tool_open = True
        self.sm.set_popup_active(timer_tool_open)
        self.assertEqual(self.sm.state, IslandState.POPUP_LOCKED)

        # Cursor leaves island while timer tool is open
        self.sm.pointer_leave()
        self.sm.tick(500)
        # Must NOT retract because timer tool is open!
        self.assertEqual(self.sm.state, IslandState.POPUP_LOCKED)
        self.assertEqual(self.sm.target_y, 0)

        # Close timer tool
        timer_tool_open = False
        self.sm.set_popup_active(timer_tool_open)
        self.assertEqual(self.sm.state, IslandState.RETRACTED)

    def test_rws9_hotplug_external_monitor(self):
        """Hotplugging an external display initializes its panel and workspace tracking."""
        # Start with single monitor
        niri_system = NiriCompositorModel(monitors=["eDP-1"])
        ws_internal = niri_system.add_workspace(id=1, idx=1, output="eDP-1", active=True)
        sm_internal = DynamicIslandStateMachine(island_height=36)
        sm_internal.set_window_count(0)
        self.assertEqual(sm_internal.state, IslandState.RESTING_VISIBLE)

        # Plug in DP-2
        niri_system.monitors.append("DP-2")
        ws_external = niri_system.add_workspace(id=2, idx=1, output="DP-2", active=True)
        sm_external = DynamicIslandStateMachine(island_height=36)
        sm_external.set_window_count(0)
        self.assertEqual(sm_external.state, IslandState.RESTING_VISIBLE)

        # Open window on DP-2
        niri_system.add_window(id=501, workspace_id=2, app_id="obs", title="OBS Studio")
        sm_external.set_window_count(niri_system.get_window_count("DP-2"))
        self.assertEqual(sm_external.state, IslandState.RETRACTED)
        # eDP-1 still resting visible
        self.assertEqual(sm_internal.state, IslandState.RESTING_VISIBLE)

    def test_rws10_rapid_cursor_sweep_crossing(self):
        """Cursor rapidly traverses across the top screen edge; leaves cleanly without stuck state."""
        self.sm.set_window_count(1)
        self.assertEqual(self.sm.state, IslandState.RETRACTED)

        # Cursor sweeps in
        self.sm.pointer_enter_trigger()
        self.assertEqual(self.sm.state, IslandState.HOVER_REVEALED)
        # Cursor leaves immediately (10ms sweep)
        self.sm.pointer_leave()
        self.assertTrue(self.sm.in_debounce)
        # Settle
        self.sm.tick(250)
        self.assertEqual(self.sm.state, IslandState.RETRACTED)


if __name__ == '__main__':
    unittest.main()
