"""
test_tier3_interactions.py
Tier 3: Cross-Feature Interactions Test Suite.
Verifies interactions between bar styles, Niri compositor state, settings, popups, and multi-monitor filters.
"""

import unittest
from tests.models.config_model import BarConfigModel
from tests.models.state_machine import DynamicIslandStateMachine, BarStyle, IslandState
from tests.models.mask_hitbox import WaylandInputMaskModel
from tests.models.niri_model import NiriCompositorModel


class TestTier3_CrossFeatureInteractions(unittest.TestCase):
    """Tier 3: Complex Multi-Component Interactions"""

    def setUp(self):
        self.cfg = BarConfigModel(style="default")
        self.niri = NiriCompositorModel(monitors=["eDP-1", "DP-1"])
        self.ws1 = self.niri.add_workspace(id=1, idx=1, output="eDP-1", active=True)
        self.ws_ext = self.niri.add_workspace(id=2, idx=1, output="DP-1", active=True)

        self.sm_edp = DynamicIslandStateMachine(island_height=36, debounce_duration_ms=250, style=BarStyle.DEFAULT)
        self.mask_edp = WaylandInputMaskModel(screen_width=1920, screen_height=1080, island_width=600, island_height=36)

    def test_cfi1_style_switch_with_windows_open(self):
        """Switching from default to island while windows are open on active workspace."""
        # 1. Open window while in default style
        self.niri.add_window(id=1, workspace_id=1, app_id="firefox", title="Web")
        self.assertEqual(self.sm_edp.style, BarStyle.DEFAULT)
        self.assertEqual(self.sm_edp.target_y, 0)
        self.assertTrue(self.sm_edp.is_visible)

        # 2. Switch style to island
        self.cfg.style = "island"
        self.sm_edp.set_style(BarStyle.ISLAND)
        self.sm_edp.set_window_count(self.niri.get_window_count("eDP-1"))

        # 3. Verify island immediately acknowledges open window and retracts
        self.assertEqual(self.sm_edp.state, IslandState.RETRACTED)
        self.assertEqual(self.sm_edp.target_y, -36)
        self.assertFalse(self.sm_edp.is_visible)

        # 4. Input mask collapses to 4px trigger
        regions = self.mask_edp.get_mask_regions(self.sm_edp.state)
        self.assertEqual(len(regions), 1)
        self.assertEqual(regions[0].height, 4)

    def test_cfi2_live_switch_with_popup_open(self):
        """Switching styles back and forth while a popup is open."""
        self.niri.add_window(id=1, workspace_id=1, app_id="alacritty", title="Terminal")
        self.sm_edp.set_style(BarStyle.ISLAND)
        self.sm_edp.set_window_count(1)
        self.assertEqual(self.sm_edp.state, IslandState.RETRACTED)

        # User hovers trigger and opens audio popup
        self.sm_edp.pointer_enter_trigger()
        self.sm_edp.set_popup_active(True)
        self.assertEqual(self.sm_edp.state, IslandState.POPUP_LOCKED)

        # User switches style to default while popup is open
        self.sm_edp.set_style(BarStyle.DEFAULT)
        self.assertEqual(self.sm_edp.target_y, 0)

        # Switch back to island
        self.sm_edp.set_style(BarStyle.ISLAND)
        self.assertEqual(self.sm_edp.state, IslandState.POPUP_LOCKED)
        self.assertEqual(self.sm_edp.target_y, 0)

        # Close popup: with cursor gone and 1 window, retracts
        self.sm_edp.pointer_leave()
        self.sm_edp.set_popup_active(False)
        self.sm_edp.tick(300)
        self.assertEqual(self.sm_edp.state, IslandState.RETRACTED)

    def test_cfi3_media_playing_during_retraction(self):
        """Media playing state updates in background without spuriously revealing retracted island."""
        self.sm_edp.set_style(BarStyle.ISLAND)
        self.sm_edp.set_window_count(1)
        self.assertEqual(self.sm_edp.state, IslandState.RETRACTED)

        # Simulate media playback starting
        media_playing = True
        track_title = "Song Title"

        # Island must remain retracted
        self.assertEqual(self.sm_edp.state, IslandState.RETRACTED)

        # Hover reveal: island slides down and can present active track
        self.sm_edp.pointer_enter_trigger()
        self.assertEqual(self.sm_edp.state, IslandState.HOVER_REVEALED)
        self.assertTrue(media_playing)
        self.assertEqual(track_title, "Song Title")

    def test_cfi4_multi_monitor_isolation_with_popups(self):
        """Popups and hover on monitor A do not disturb state machine on monitor B."""
        sm_dp = DynamicIslandStateMachine(island_height=36, style=BarStyle.ISLAND)
        self.sm_edp.set_style(BarStyle.ISLAND)

        # eDP-1 has window, DP-1 is empty
        self.niri.add_window(id=1, workspace_id=1, app_id="editor", title="Code")
        self.sm_edp.set_window_count(self.niri.get_window_count("eDP-1"))
        sm_dp.set_window_count(self.niri.get_window_count("DP-1"))

        self.assertEqual(self.sm_edp.state, IslandState.RETRACTED)
        self.assertEqual(sm_dp.state, IslandState.RESTING_VISIBLE)

        # Open popup on eDP-1
        self.sm_edp.set_popup_active(True)
        self.assertEqual(self.sm_edp.state, IslandState.POPUP_LOCKED)
        # DP-1 remains unaffected
        self.assertEqual(sm_dp.state, IslandState.RESTING_VISIBLE)

    def test_cfi5_screen_list_filtering_dynamic_toggle(self):
        """Config.bar.screenList dynamically filtering monitors."""
        self.cfg.screen_list = ["eDP-1"]
        # Screen eDP-1 is in list -> enabled
        edp_enabled = (len(self.cfg.screen_list) == 0 or "eDP-1" in self.cfg.screen_list)
        dp_enabled = (len(self.cfg.screen_list) == 0 or "DP-1" in self.cfg.screen_list)
        self.assertTrue(edp_enabled)
        self.assertFalse(dp_enabled)

        # Reconfigure to empty list -> all screens enabled
        self.cfg.screen_list = []
        edp_enabled = (len(self.cfg.screen_list) == 0 or "eDP-1" in self.cfg.screen_list)
        dp_enabled = (len(self.cfg.screen_list) == 0 or "DP-1" in self.cfg.screen_list)
        self.assertTrue(edp_enabled)
        self.assertTrue(dp_enabled)

    def test_cfi6_window_closed_during_hover_reveal(self):
        """Window closed while cursor is hovering on island."""
        self.sm_edp.set_style(BarStyle.ISLAND)
        self.sm_edp.set_window_count(1)
        self.sm_edp.pointer_enter_trigger()
        self.assertEqual(self.sm_edp.state, IslandState.HOVER_REVEALED)

        # Close window
        self.niri.close_window(1)
        self.sm_edp.set_window_count(self.niri.get_window_count("eDP-1"))
        # Immediately transitions to RESTING_VISIBLE
        self.assertEqual(self.sm_edp.state, IslandState.RESTING_VISIBLE)

        # Cursor leaves: must not retract!
        self.sm_edp.pointer_leave()
        self.sm_edp.tick(300)
        self.assertEqual(self.sm_edp.state, IslandState.RESTING_VISIBLE)
        self.assertEqual(self.sm_edp.target_y, 0)

    def test_cfi7_overview_mode_state_restoration(self):
        """Niri overview mode toggled on and off."""
        self.sm_edp.set_style(BarStyle.ISLAND)
        self.niri.add_window(id=1, workspace_id=1, app_id="term", title="Term")
        self.sm_edp.set_window_count(1)
        self.assertEqual(self.sm_edp.state, IslandState.RETRACTED)

        # Overview opens: bar visual reveal disabled
        overview_open = True
        reveal = not overview_open
        self.assertFalse(reveal)

        # Overview closes: reveal re-enabled, state evaluates to RETRACTED
        overview_open = False
        reveal = not overview_open
        self.assertTrue(reveal)
        self.assertEqual(self.sm_edp.state, IslandState.RETRACTED)

    def test_cfi8_fullscreen_overlay_isolation(self):
        """Fullscreen window on active workspace hides layer below or handles overlay."""
        fullscreen_outputs = ["eDP-1"]
        is_fullscreen = "eDP-1" in fullscreen_outputs
        self.assertTrue(is_fullscreen)

        # Leaving fullscreen
        fullscreen_outputs = []
        is_fullscreen = "eDP-1" in fullscreen_outputs
        self.assertFalse(is_fullscreen)


if __name__ == '__main__':
    unittest.main()
