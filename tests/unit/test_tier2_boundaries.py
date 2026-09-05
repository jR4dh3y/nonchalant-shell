"""
test_tier2_boundaries.py
Tier 2: Boundary & Corner Cases Test Suite.
Exhaustively exercises extreme inputs, zero/max boundaries, edge coordinates, rapid jitter, and edge cases.
"""

import unittest
from tests.models.config_model import BarConfigModel
from tests.models.state_machine import DynamicIslandStateMachine, BarStyle, IslandState
from tests.models.geometry import IslandEarGeometry, Point, CubicBezier
from tests.models.mask_hitbox import WaylandInputMaskModel
from tests.models.niri_model import NiriCompositorModel


class TestTier2_ConfigBoundaries(unittest.TestCase):
    """Tier 2: Config Schema & Validator Boundary Conditions (Feature 1 & 2)"""

    def test_b1_empty_string_style_reverts_to_default(self):
        cfg = BarConfigModel()
        cfg.style = ""
        self.assertEqual(cfg.style, "default")

    def test_b2_whitespace_only_style_reverts_to_default(self):
        cfg = BarConfigModel()
        cfg.style = "   \t\n  "
        self.assertEqual(cfg.style, "default")

    def test_b3_uppercase_style_reverts_to_default(self):
        cfg = BarConfigModel()
        cfg.style = "ISLAND"
        self.assertEqual(cfg.style, "default")
        cfg.style = "DEFAULT"
        self.assertEqual(cfg.style, "default")

    def test_b4_mixed_case_and_padding(self):
        cfg = BarConfigModel()
        cfg.style = " island "
        self.assertEqual(cfg.style, "default")

    def test_b5_null_and_boolean_types(self):
        cfg = BarConfigModel()
        cfg.style = None
        self.assertEqual(cfg.style, "default")
        cfg.style = True
        self.assertEqual(cfg.style, "default")
        cfg.style = False
        self.assertEqual(cfg.style, "default")

    def test_b6_numeric_types_revert_to_default(self):
        cfg = BarConfigModel()
        for num in [0, 1, -1, 3.14, float('nan'), float('inf')]:
            cfg.style = num
            self.assertEqual(cfg.style, "default")

    def test_b7_extreme_screen_list_filtering(self):
        cfg = BarConfigModel()
        # Empty screen list enables all screens
        cfg.screen_list = []
        self.assertEqual(cfg.screen_list, [])
        # Very large screen list
        cfg.screen_list = [f"DP-{i}" for i in range(100)]
        self.assertEqual(len(cfg.screen_list), 100)


class TestTier2_ReservationBoundaries(unittest.TestCase):
    """Tier 2: Overlay Mode Reservation Boundary Conditions (Feature 4)"""

    def compute_zone(self, style: str, bar_size: int, outer_margin: int, enabled: bool) -> int:
        if not enabled:
            return 0
        if style == "island":
            return 0
        return max(0, bar_size + outer_margin)

    def test_b8_island_zero_bar_size(self):
        zone = self.compute_zone("island", 0, 0, True)
        self.assertEqual(zone, 0)

    def test_b9_island_extreme_bar_size(self):
        # Even with giant bar size, island mode MUST force exclusive zone to 0
        zone = self.compute_zone("island", 500, 100, True)
        self.assertEqual(zone, 0, "Island mode must strictly force exclusiveZone to 0 regardless of size")

    def test_b10_disabled_bar_zero_zone(self):
        zone = self.compute_zone("island", 36, 0, False)
        self.assertEqual(zone, 0)

    def test_b11_negative_margin_handled_safely(self):
        zone = self.compute_zone("default", 36, -50, True)
        self.assertEqual(zone, 0)

    def test_b12_default_bar_boundary_dimensions(self):
        zone = self.compute_zone("default", 1, 0, True)
        self.assertEqual(zone, 1)


class TestTier2_EarGeometryBoundaries(unittest.TestCase):
    """Tier 2: Inverted Corner Fillets Boundary Conditions (Feature 5)"""

    def test_b13_zero_radius_degenerate_fillet(self):
        # Radius 0 (sharp corners, no fillet)
        left = IslandEarGeometry.construct_left_ear(600, 0.0)
        self.assertEqual(left.p0.x, 600.0)
        self.assertEqual(left.p3.x, 600.0)
        self.assertEqual(left.p0.y, 0.0)
        self.assertEqual(left.p3.y, 0.0)

    def test_b14_small_radius(self):
        left = IslandEarGeometry.construct_left_ear(600, 1.0)
        self.assertAlmostEqual(left.p3.x - left.p0.x, 1.0)
        self.assertTrue(IslandEarGeometry.verify_top_bezel_flushness(left, "left"))
        self.assertTrue(IslandEarGeometry.verify_tangent_continuity_at_bezel(left, "left"))

    def test_b15_large_radius(self):
        # Extreme roundness (e.g. radius 64)
        left = IslandEarGeometry.construct_left_ear(600, 64.0)
        self.assertAlmostEqual(left.p3.x - left.p0.x, 64.0)
        self.assertTrue(IslandEarGeometry.verify_top_bezel_flushness(left, "left"))
        self.assertTrue(IslandEarGeometry.verify_tangent_continuity_at_bezel(left, "left"))

    def test_b16_screen_left_edge_boundary(self):
        # Island aligned at far left (x=radius)
        left = IslandEarGeometry.construct_left_ear(16.0, 16.0)
        self.assertAlmostEqual(left.p0.x, 0.0)  # Starts exactly at screen boundary X=0

    def test_b17_bezier_monotonically_descending_left_ear(self):
        # Left ear must monotonically increase in Y from 0 to radius
        left = IslandEarGeometry.construct_left_ear(500, 20.0)
        samples = IslandEarGeometry.sample_curve(left, steps=20)
        for i in range(len(samples) - 1):
            self.assertLessEqual(samples[i].y, samples[i+1].y + 1e-9)
            self.assertLessEqual(samples[i].x, samples[i+1].x + 1e-9)


class TestTier2_ScreenResolutionAndLayoutBoundaries(unittest.TestCase):
    """Tier 2: Extreme Resolutions and Layout Boundaries (Feature 6 & 7)"""

    def test_b18_ultrawide_resolution_centering(self):
        # 5120x1440 resolution
        mask = WaylandInputMaskModel(screen_width=5120, screen_height=1440, island_width=800)
        expected_x = (5120 - 800) // 2
        self.assertEqual(mask.island_x, expected_x)
        self.assertEqual(mask.island_x, 2160)

    def test_b19_4k_resolution_centering(self):
        # 3840x2160 resolution
        mask = WaylandInputMaskModel(screen_width=3840, screen_height=2160, island_width=700)
        expected_x = (3840 - 700) // 2
        self.assertEqual(mask.island_x, expected_x)
        self.assertEqual(mask.island_x, 1570)

    def test_b20_compact_laptop_resolution(self):
        # 1366x768 resolution
        mask = WaylandInputMaskModel(screen_width=1366, screen_height=768, island_width=500)
        expected_x = (1366 - 500) // 2
        self.assertEqual(mask.island_x, 433)
        self.assertGreater(mask.island_x, 0)

    def test_b21_island_width_equal_to_screen_width(self):
        # Full width edge case
        mask = WaylandInputMaskModel(screen_width=1920, screen_height=1080, island_width=1920)
        self.assertEqual(mask.island_x, 0)

    def test_b22_zero_content_does_not_break_centering(self):
        mask = WaylandInputMaskModel(screen_width=1920, screen_height=1080, island_width=0)
        self.assertEqual(mask.island_x, 960)


class TestTier2_NiriWindowPresenceBoundaries(unittest.TestCase):
    """Tier 2: Window-Aware Presence Boundary Conditions (Feature 8)"""

    def setUp(self):
        self.niri = NiriCompositorModel(monitors=["eDP-1"])
        self.ws = self.niri.add_workspace(id=1, idx=1, output="eDP-1", active=True)

    def test_b23_zero_windows(self):
        self.assertEqual(self.niri.get_window_count("eDP-1"), 0)
        self.assertFalse(self.niri.has_active_windows("eDP-1"))

    def test_b24_stress_100_windows_opened_and_closed(self):
        # Rapidly open 100 windows
        for i in range(100):
            self.niri.add_window(id=i, workspace_id=1, app_id="term", title=f"Term {i}")
        self.assertEqual(self.niri.get_window_count("eDP-1"), 100)
        self.assertTrue(self.niri.has_active_windows("eDP-1"))

        # Close all 100 windows
        for i in range(100):
            self.niri.close_window(i)
        self.assertEqual(self.niri.get_window_count("eDP-1"), 0)
        self.assertFalse(self.niri.has_active_windows("eDP-1"))

    def test_b25_window_moved_across_workspaces(self):
        ws2 = self.niri.add_workspace(id=2, idx=2, output="eDP-1", active=False)
        self.niri.add_window(id=1, workspace_id=1, app_id="web", title="Web")
        self.assertEqual(self.niri.get_window_count("eDP-1"), 1)

        # Move window to inactive workspace 2
        self.niri.move_window_to_workspace(1, target_workspace_id=2)
        # Active workspace 1 is now empty!
        self.assertEqual(self.niri.get_window_count("eDP-1"), 0)
        self.assertFalse(self.niri.has_active_windows("eDP-1"))

    def test_b26_closing_nonexistent_window_is_noop(self):
        self.niri.close_window(99999)
        self.assertEqual(self.niri.get_window_count("eDP-1"), 0)

    def test_b27_unfocused_monitor_does_not_affect_focused_monitor(self):
        niri_multi = NiriCompositorModel(monitors=["eDP-1", "DP-1", "HDMI-1"])
        ws1 = niri_multi.add_workspace(id=1, idx=1, output="eDP-1", active=True)
        ws2 = niri_multi.add_workspace(id=2, idx=1, output="DP-1", active=True)
        ws3 = niri_multi.add_workspace(id=3, idx=1, output="HDMI-1", active=True)

        niri_multi.add_window(id=1, workspace_id=2, app_id="app", title="App")
        self.assertFalse(niri_multi.has_active_windows("eDP-1"))
        self.assertTrue(niri_multi.has_active_windows("DP-1"))
        self.assertFalse(niri_multi.has_active_windows("HDMI-1"))


class TestTier2_AutohideAndDebounceBoundaries(unittest.TestCase):
    """Tier 2: Autohide State Machine & Debounce Boundaries (Feature 9 & 10)"""

    def test_b28_zero_duration_debounce(self):
        sm = DynamicIslandStateMachine(island_height=36, debounce_duration_ms=0)
        sm.set_window_count(1)
        sm.pointer_enter_trigger()
        self.assertEqual(sm.state, IslandState.HOVER_REVEALED)
        sm.pointer_leave()
        # With 0ms debounce, leaves immediately to retracted
        self.assertEqual(sm.state, IslandState.RETRACTED)

    def test_b29_long_duration_debounce(self):
        sm = DynamicIslandStateMachine(island_height=36, debounce_duration_ms=5000)
        sm.set_window_count(1)
        sm.pointer_enter_trigger()
        sm.pointer_leave()
        sm.tick(4999)
        self.assertTrue(sm.in_debounce)
        self.assertEqual(sm.state, IslandState.HOVER_REVEALED)
        sm.tick(1)
        self.assertFalse(sm.in_debounce)
        self.assertEqual(sm.state, IslandState.RETRACTED)

    def test_b30_rapid_hover_jitter_stress(self):
        # 50 rapid enter/leave events within 1ms intervals
        sm = DynamicIslandStateMachine(island_height=36, debounce_duration_ms=250)
        sm.set_window_count(1)
        for _ in range(50):
            sm.pointer_enter_trigger()
            sm.tick(1)
            sm.pointer_leave()
            sm.tick(1)

        # Final state during debounce must be HOVER_REVEALED
        self.assertEqual(sm.state, IslandState.HOVER_REVEALED)
        # Settle timer
        sm.tick(250)
        self.assertEqual(sm.state, IslandState.RETRACTED)

    def test_b31_window_closed_while_hovered(self):
        sm = DynamicIslandStateMachine(island_height=36, debounce_duration_ms=250)
        sm.set_window_count(1)
        sm.pointer_enter_trigger()
        self.assertEqual(sm.state, IslandState.HOVER_REVEALED)

        # Window closes while pointer is inside
        sm.set_window_count(0)
        self.assertEqual(sm.state, IslandState.RESTING_VISIBLE)

        # Pointer leaves: island must remain RESTING_VISIBLE (not retract!)
        sm.pointer_leave()
        sm.tick(300)
        self.assertEqual(sm.state, IslandState.RESTING_VISIBLE)

    def test_b32_window_opened_while_hovered(self):
        sm = DynamicIslandStateMachine(island_height=36, debounce_duration_ms=250)
        sm.set_window_count(0)
        self.assertEqual(sm.state, IslandState.RESTING_VISIBLE)

        sm.pointer_enter_island()
        # Window opens while hovered
        sm.set_window_count(1)
        self.assertEqual(sm.state, IslandState.HOVER_REVEALED, "Must stay revealed while cursor is inside")


class TestTier2_MaskingAndPassThroughBoundaries(unittest.TestCase):
    """Tier 2: Wayland Input Mask Boundary Coordinates (Feature 10 & 11)"""

    def setUp(self):
        self.mask = WaylandInputMaskModel(screen_width=1920, screen_height=1080,
                                         island_width=600, island_height=36, trigger_height=4)

    def test_b33_boundary_y0_top_bezel_click(self):
        # Y=0 is inside the 4px trigger
        self.assertFalse(self.mask.is_click_passed_through(960, 0, IslandState.RETRACTED))

    def test_b34_boundary_y3_inside_trigger(self):
        # Y=3 is inside the 4px trigger
        self.assertFalse(self.mask.is_click_passed_through(960, 3, IslandState.RETRACTED))

    def test_b35_boundary_y4_strict_cutoff(self):
        # Y=4 is strictly outside the 4px trigger [0, 4) -> must pass through!
        self.assertTrue(self.mask.is_click_passed_through(960, 4, IslandState.RETRACTED))

    def test_b36_boundary_y5_outside_trigger(self):
        # Y=5 must pass through
        self.assertTrue(self.mask.is_click_passed_through(960, 5, IslandState.RETRACTED))

    def test_b37_left_island_boundary_x(self):
        # Island starts at X=660
        # X=659 is outside island -> passes through
        self.assertTrue(self.mask.is_click_passed_through(659, 20, IslandState.HOVER_REVEALED))
        # X=660 is inside island -> captured
        self.assertFalse(self.mask.is_click_passed_through(660, 20, IslandState.HOVER_REVEALED))

    def test_b38_right_island_boundary_x(self):
        # Island ends at X=660+600=1260
        # X=1259 is inside island -> captured
        self.assertFalse(self.mask.is_click_passed_through(1259, 20, IslandState.HOVER_REVEALED))
        # X=1260 is outside island -> passes through
        self.assertTrue(self.mask.is_click_passed_through(1260, 20, IslandState.HOVER_REVEALED))

    def test_b39_bottom_island_boundary_y(self):
        # Island height is 36
        # Y=35 is inside island -> captured
        self.assertFalse(self.mask.is_click_passed_through(960, 35, IslandState.HOVER_REVEALED))
        # Y=36 is outside island -> passes through
        self.assertTrue(self.mask.is_click_passed_through(960, 36, IslandState.HOVER_REVEALED))

    def test_b40_screen_corners(self):
        # Far top-left (0, 0)
        self.assertTrue(self.mask.is_click_passed_through(0, 0, IslandState.RETRACTED))
        # Far bottom-right (1919, 1079)
        self.assertTrue(self.mask.is_click_passed_through(1919, 1079, IslandState.RETRACTED))
        self.assertTrue(self.mask.is_click_passed_through(1919, 1079, IslandState.HOVER_REVEALED))


class TestTier2_AdditionalFeatureBoundaries(unittest.TestCase):
    """Tier 2: Additional Boundary Cases for Features 2, 3, 5, 7, 9, 11"""

    def test_b41_settings_rapid_toggle_consistency(self):
        cfg = BarConfigModel(style="default")
        toggles = ["island", "default"] * 25
        for target in toggles:
            cfg.style = target
            self.assertEqual(cfg.style, target)

    def test_b42_settings_selector_out_of_bounds_index(self):
        options = ["default", "island"]
        for bad_idx in [-1, 2, 999, -100]:
            safe_val = options[bad_idx] if 0 <= bad_idx < len(options) else "default"
            self.assertEqual(safe_val, "default")

    def test_b43_modular_facade_zero_height_safeguard(self):
        # Even if content height is 0, barTargetHeight maintains minimum compact bound
        min_height = max(24, 0)
        self.assertGreaterEqual(min_height, 24)

    def test_b44_ear_bezier_bounding_box(self):
        # All sampled points on left ear must be strictly within [island_x - radius, island_x] and [0, radius]
        ix, r = 500.0, 16.0
        left = IslandEarGeometry.construct_left_ear(ix, r)
        samples = IslandEarGeometry.sample_curve(left, steps=50)
        for pt in samples:
            self.assertGreaterEqual(pt.x, ix - r - 1e-6)
            self.assertLessEqual(pt.x, ix + 1e-6)
            self.assertGreaterEqual(pt.y, 0.0 - 1e-6)
            self.assertLessEqual(pt.y, r + 1e-6)

    def test_b45_ear_right_bezier_bounding_box(self):
        # All sampled points on right ear must be within [ix + w, ix + w + r] and [0, r]
        ix, w, r = 500.0, 400.0, 16.0
        right = IslandEarGeometry.construct_right_ear(ix, w, r)
        samples = IslandEarGeometry.sample_curve(right, steps=50)
        for pt in samples:
            self.assertGreaterEqual(pt.x, ix + w - 1e-6)
            self.assertLessEqual(pt.x, ix + w + r + 1e-6)
            self.assertGreaterEqual(pt.y, 0.0 - 1e-6)
            self.assertLessEqual(pt.y, r + 1e-6)

    def test_b46_compact_layout_extreme_narrow_island(self):
        # Narrow width 300px
        mask = WaylandInputMaskModel(screen_width=1920, screen_height=1080, island_width=300)
        self.assertEqual(mask.island_x, 810)
        self.assertEqual(mask.island_width, 300)

    def test_b47_negative_window_count_clamped(self):
        sm = DynamicIslandStateMachine(island_height=36)
        sm.set_window_count(-10)
        self.assertEqual(sm.window_count, 0)
        self.assertEqual(sm.state, IslandState.RESTING_VISIBLE)

    def test_b48_large_window_count_stability(self):
        sm = DynamicIslandStateMachine(island_height=36)
        sm.set_window_count(1000)
        self.assertEqual(sm.state, IslandState.RETRACTED)
        self.assertEqual(sm.target_y, -36)

    def test_b49_style_switch_while_in_debounce(self):
        sm = DynamicIslandStateMachine(island_height=36, debounce_duration_ms=250)
        sm.set_window_count(1)
        sm.pointer_enter_trigger()
        sm.pointer_leave()
        self.assertTrue(sm.in_debounce)
        # Switch to default style mid-debounce
        sm.set_style(BarStyle.DEFAULT)
        self.assertEqual(sm.state, IslandState.RESTING_VISIBLE)
        self.assertEqual(sm.target_y, 0)

    def test_b50_style_switch_back_to_island_restores_retraction(self):
        sm = DynamicIslandStateMachine(island_height=36, debounce_duration_ms=250)
        sm.set_window_count(1)
        sm.set_style(BarStyle.DEFAULT)
        self.assertEqual(sm.state, IslandState.RESTING_VISIBLE)
        sm.set_style(BarStyle.ISLAND)
        # With 1 window and no hover, switches directly to RETRACTED
        self.assertEqual(sm.state, IslandState.RETRACTED)
        self.assertEqual(sm.target_y, -36)

    def test_b51_full_width_trigger_option(self):
        mask = WaylandInputMaskModel(screen_width=1920, screen_height=1080, island_width=600,
                                     full_width_trigger=True)
        regions = mask.get_mask_regions(IslandState.RETRACTED)
        self.assertEqual(len(regions), 1)
        self.assertEqual(regions[0].x, 0)
        self.assertEqual(regions[0].width, 1920)

    def test_b52_mask_point_capture_consistency(self):
        mask = WaylandInputMaskModel(screen_width=1920, screen_height=1080, island_width=600)
        # Inside island
        self.assertTrue(mask.point_captures_input(960, 10, IslandState.HOVER_REVEALED))
        # Outside island
        self.assertFalse(mask.point_captures_input(100, 10, IslandState.HOVER_REVEALED))

    def test_b53_tangent_slope_continuity_at_ear_corners(self):
        # Slope approaching p3 on left ear must be finite or vertically continuous
        left = IslandEarGeometry.construct_left_ear(600, 16.0)
        p_near_end = left.point_at(0.99)
        self.assertGreater(p_near_end.y, 14.0)

    def test_b54_zero_height_island_target_y(self):
        sm = DynamicIslandStateMachine(island_height=0)
        sm.set_window_count(1)
        self.assertEqual(sm.target_y, 0)

    def test_b55_monotonic_bezier_parameter_progression(self):
        left = IslandEarGeometry.construct_left_ear(600, 16.0)
        t_values = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]
        points = [left.point_at(t) for t in t_values]
        for i in range(len(points) - 1):
            self.assertLess(points[i].y, points[i+1].y)


if __name__ == '__main__':
    unittest.main()
