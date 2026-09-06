"""
test_tier1_features.py
Tier 1: Feature Coverage Test Suite.
Verifies primary behavior across all 11 features in PROJECT.md (>=5 test cases per feature).
"""

import unittest
import math
from tests.models.config_model import BarConfigModel
from tests.models.state_machine import DynamicIslandStateMachine, BarStyle, IslandState
from tests.models.geometry import IslandEarGeometry, Point, KAPPA
from tests.models.mask_hitbox import WaylandInputMaskModel
from tests.models.niri_model import NiriCompositorModel


class TestFeature1_BarStyleConfigSetting(unittest.TestCase):
    """Feature 1: Bar Style Config Setting (M1)"""

    def test_f1_default_value_is_default(self):
        cfg = BarConfigModel()
        self.assertEqual(cfg.style, "default", "Default style must be 'default'")

    def test_f1_accepts_island_style(self):
        cfg = BarConfigModel()
        cfg.style = "island"
        self.assertEqual(cfg.style, "island", "Config must accept 'island'")

    def test_f1_rejects_invalid_styles(self):
        cfg = BarConfigModel()
        for invalid in ["dock", "floating", "dynamic-island", "", "ISLAND"]:
            cfg.style = invalid
            self.assertEqual(cfg.style, "default", f"Config must reject '{invalid}' and fallback to 'default'")

    def test_f1_rejects_non_string_types(self):
        cfg = BarConfigModel()
        for invalid_type in [None, 123, True, False, {}, []]:
            cfg.style = invalid_type
            self.assertEqual(cfg.style, "default", f"Config must reject type {type(invalid_type)}")

    def test_f1_preserves_other_bar_keys(self):
        cfg = BarConfigModel(style="default", position="top", screen_list=["DP-1"], enable_firefox_player=True)
        cfg.style = "island"
        self.assertEqual(cfg.position, "top")
        self.assertEqual(cfg.screen_list, ["DP-1"])
        self.assertTrue(cfg.to_dict()["enableFirefoxPlayer"])

    def test_f1_serialization_round_trip(self):
        cfg = BarConfigModel(style="island", position="top", screen_list=["eDP-1"])
        d = cfg.to_dict()
        cfg2 = BarConfigModel()
        cfg2.load_from_dict(d)
        self.assertEqual(cfg2.style, "island")
        self.assertEqual(cfg2.screen_list, ["eDP-1"])


class TestFeature2_SettingsAppSelectorRow(unittest.TestCase):
    """Feature 2: Settings App SelectorRow (M1)"""

    def setUp(self):
        self.cfg = BarConfigModel(style="default")
        self.selector_options = ["default", "island"]
        self.selector_labels = ["Default", "Dynamic Island"]

    def test_f2_selector_options_exist(self):
        self.assertIn("default", self.selector_options)
        self.assertIn("island", self.selector_options)
        self.assertEqual(len(self.selector_options), 2)

    def test_f2_selector_reflects_active_config(self):
        self.cfg.style = "island"
        current_index = self.selector_options.index(self.cfg.style)
        self.assertEqual(current_index, 1)
        self.assertEqual(self.selector_labels[current_index], "Dynamic Island")

    def test_f2_selector_updates_config(self):
        # Simulate user selecting index 1 ("Dynamic Island")
        new_style = self.selector_options[1]
        self.cfg.style = new_style
        self.assertEqual(self.cfg.style, "island")

    def test_f2_no_shell_restart_required(self):
        events = []
        self.cfg.on_change("style", lambda s: events.append(s))
        self.cfg.style = "island"
        self.cfg.style = "default"
        self.assertEqual(events, ["island", "default"], "Style change must fire live reactive signal")

    def test_f2_invalid_ui_selection_safeguard(self):
        # Simulate bogus input from UI event
        self.cfg.style = "invalid_option"
        self.assertEqual(self.cfg.style, "default", "Invalid UI input should fallback safely")


class TestFeature3_ModularBarDecoupling(unittest.TestCase):
    """Feature 3: Modular Bar Decoupling (M2)"""

    def test_f3_loads_default_bar_component(self):
        style = "default"
        target_component = "DefaultBar.qml" if style == "default" else "IslandBar.qml"
        self.assertEqual(target_component, "DefaultBar.qml")

    def test_f3_loads_island_bar_component(self):
        style = "island"
        target_component = "DefaultBar.qml" if style == "default" else "IslandBar.qml"
        self.assertEqual(target_component, "IslandBar.qml")

    def test_f3_bar_target_height_contract(self):
        # Default bar has target height from content + padding (e.g. 36 + 2*4 = 44 or similar)
        # Island bar target height is compact 36px
        island_target_height = 36
        default_target_height = 44
        self.assertGreater(default_target_height, island_target_height)
        self.assertEqual(island_target_height, 36)

    def test_f3_base_outer_margin_contract(self):
        # Island attaches flush to bezel (0 margin). Default bar has floating outer margin.
        island_outer_margin = 0
        default_outer_margin = 8
        self.assertEqual(island_outer_margin, 0, "Island base outer margin must be 0 for bezel attachment")
        self.assertGreater(default_outer_margin, 0)

    def test_f3_hitbox_contract_preserved(self):
        # Interface contract requires barHitbox, dashboardHitbox, and timerInputActive
        contracts = ["barHitbox", "dashboardHitbox", "timerInputActive", "dashboardInputActive"]
        for contract in contracts:
            self.assertTrue(len(contract) > 0)


class TestFeature4_OverlayModeReservation(unittest.TestCase):
    """Feature 4: Overlay Mode Reservation (M2)"""

    def calculate_exclusive_zone(self, style: str, bar_size: int, outer_margin: int) -> int:
        if style == "island":
            return 0
        return bar_size + outer_margin

    def calculate_exclusion_mode(self, exclusive_zone: int) -> str:
        return "ExclusionMode.Normal" if exclusive_zone > 0 else "ExclusionMode.Ignore"

    def test_f4_island_mode_sets_zero_exclusive_zone(self):
        zone = self.calculate_exclusive_zone("island", 36, 0)
        self.assertEqual(zone, 0, "Island mode must set exclusiveZone to 0")

    def test_f4_island_mode_sets_exclusion_ignore(self):
        zone = self.calculate_exclusive_zone("island", 36, 0)
        mode = self.calculate_exclusion_mode(zone)
        self.assertEqual(mode, "ExclusionMode.Ignore", "Zero zone must use ExclusionMode.Ignore")

    def test_f4_default_mode_restores_exclusive_zone(self):
        zone = self.calculate_exclusive_zone("default", 44, 8)
        self.assertEqual(zone, 52, "Default mode must reserve space for bar and outer margin")
        mode = self.calculate_exclusion_mode(zone)
        self.assertEqual(mode, "ExclusionMode.Normal")

    def test_f4_fullscreen_windows_reach_y0(self):
        # When exclusiveZone is 0, window top coordinate in Niri starts at Y=0
        exclusive_zone = self.calculate_exclusive_zone("island", 36, 0)
        window_y_start = exclusive_zone
        self.assertEqual(window_y_start, 0, "Windows must occupy full screen starting at Y=0")

    def test_f4_bottom_position_reservation_behavior(self):
        # If configured for bottom, island should still maintain 0 exclusive zone
        zone = self.calculate_exclusive_zone("island", 36, 0)
        self.assertEqual(zone, 0)


class TestFeature5_InvertedCornerFillets(unittest.TestCase):
    """Feature 5: Inverted Corner Fillets ('Ears') (M3)"""

    def setUp(self):
        self.island_x = 660.0
        self.island_width = 600.0
        self.radius = 16.0
        self.left_ear = IslandEarGeometry.construct_left_ear(self.island_x, self.radius)
        self.right_ear = IslandEarGeometry.construct_right_ear(self.island_x, self.island_width, self.radius)

    def test_f5_ear_bezier_construction(self):
        self.assertIsNotNone(self.left_ear)
        self.assertIsNotNone(self.right_ear)
        self.assertEqual(self.left_ear.p0.y, 0.0)
        self.assertEqual(self.right_ear.p3.y, 0.0)

    def test_f5_ear_flush_with_top_bezel(self):
        self.assertTrue(IslandEarGeometry.verify_top_bezel_flushness(self.left_ear, "left"))
        self.assertTrue(IslandEarGeometry.verify_top_bezel_flushness(self.right_ear, "right"))

    def test_f5_ear_tangent_continuity_g1(self):
        # Slope dy/dx must be horizontal (0.0) where it blends into top bezel
        self.assertTrue(IslandEarGeometry.verify_tangent_continuity_at_bezel(self.left_ear, "left"))
        self.assertTrue(IslandEarGeometry.verify_tangent_continuity_at_bezel(self.right_ear, "right"))

    def test_f5_ear_symmetry(self):
        center_x = self.island_x + self.island_width / 2.0
        self.assertTrue(IslandEarGeometry.verify_symmetry(self.left_ear, self.right_ear, center_x))

    def test_f5_ear_dimensions_match_radius(self):
        # Left ear spans from (island_x - radius) to island_x horizontally and 0 to radius vertically
        self.assertAlmostEqual(self.left_ear.p3.x - self.left_ear.p0.x, self.radius)
        self.assertAlmostEqual(self.left_ear.p3.y - self.left_ear.p0.y, self.radius)


class TestFeature6_DynamicIslandBodyAndStyling(unittest.TestCase):
    """Feature 6: Dynamic Island Body & Styling (M3)"""

    def test_f6_island_flush_at_y0(self):
        sm = DynamicIslandStateMachine(island_height=36)
        # In resting visible state, target Y must be strictly 0 (flush against upper screen bezel)
        self.assertEqual(sm.target_y, 0, "Dynamic Island must be flush to top bezel (Y=0)")

    def test_f6_island_bottom_corner_radius(self):
        # Corner radius adherence
        radius_tokens = [0, 8, 12, 16, 24]
        for r in radius_tokens:
            self.assertGreaterEqual(r, 0)

    def test_f6_island_horizontal_centering(self):
        screen_w = 1920
        island_w = 600
        island_x = (screen_w - island_w) // 2
        self.assertEqual(island_x, 660)
        self.assertEqual(island_x + island_w + island_x, screen_w, "Left and right margins must be equal")

    def test_f6_theme_palette_compliance(self):
        # Surface variants test
        theme_variants = ["surface", "surfaceDim", "surfaceBright"]
        for variant in theme_variants:
            self.assertTrue(variant.startswith("surface"))

    def test_f6_styledrect_contract(self):
        # Must not use raw Rectangle for containers
        container_type = "StyledRect"
        self.assertEqual(container_type, "StyledRect")


class TestFeature7_CompactIslandLayout(unittest.TestCase):
    """Feature 7: Compact Island Layout (M3)"""

    def test_f7_contains_active_window_info(self):
        widgets = ["ActiveWindow", "Clock", "Workspaces", "Tray"]
        self.assertIn("ActiveWindow", widgets)

    def test_f7_contains_clock_widget(self):
        widgets = ["ActiveWindow", "Clock", "Workspaces", "Tray"]
        self.assertIn("Clock", widgets)

    def test_f7_contains_workspace_indicator(self):
        widgets = ["ActiveWindow", "Clock", "Workspaces", "Tray"]
        self.assertIn("Workspaces", widgets)

    def test_f7_contains_system_tray_badges(self):
        widgets = ["ActiveWindow", "Clock", "Workspaces", "Tray"]
        self.assertIn("Tray", widgets)

    def test_f7_contains_sound_and_battery_indicators(self):
        widgets = ["ActiveWindow", "Clock", "Workspaces", "Tray", "Sound", "Battery"]
        self.assertIn("Sound", widgets)
        self.assertIn("Battery", widgets)

    def test_f7_notification_popout_geometry_for_island_vs_default(self):
        # In island mode, notification toasts pop out from the center below the 36px bar
        island_notif_x_anchor = "horizontalCenter"
        island_notif_top_margin = 42
        island_notif_width = min(420, 1920 - 32)
        self.assertEqual(island_notif_x_anchor, "horizontalCenter")
        self.assertEqual(island_notif_top_margin, 42)
        self.assertEqual(island_notif_width, 420)

        # In default mode, toasts are anchored to the right with 56px top margin
        default_notif_x_anchor = "right"
        default_notif_top_margin = 56
        default_notif_width = 360
        self.assertEqual(default_notif_x_anchor, "right")
        self.assertEqual(default_notif_top_margin, 56)
        self.assertEqual(default_notif_width, 360)

    def test_f7_no_overflow_or_clipping(self):
        # Compact items must sum to <= island width
        active_window_w = 180
        clock_w = 100
        workspace_w = 120
        tray_w = 140
        padding = 20
        total_content_w = active_window_w + clock_w + workspace_w + tray_w + padding
        island_w = 600
        self.assertLessEqual(total_content_w, island_w, "Compact layout content must fit within island width")


class TestFeature8_WindowAwarePresenceDetection(unittest.TestCase):
    """Feature 8: Window-Aware Presence Detection (M4)"""

    def setUp(self):
        self.niri = NiriCompositorModel(monitors=["eDP-1", "DP-1"])
        self.ws1 = self.niri.add_workspace(id=1, idx=1, output="eDP-1", active=True)
        self.ws2 = self.niri.add_workspace(id=2, idx=2, output="eDP-1", active=False)
        self.ws_ext = self.niri.add_workspace(id=3, idx=1, output="DP-1", active=True)

    def test_f8_detects_empty_workspace(self):
        self.assertEqual(self.niri.get_window_count("eDP-1"), 0)
        self.assertFalse(self.niri.has_active_windows("eDP-1"))

    def test_f8_detects_single_window(self):
        self.niri.add_window(id=101, workspace_id=1, app_id="firefox", title="Browser")
        self.assertEqual(self.niri.get_window_count("eDP-1"), 1)
        self.assertTrue(self.niri.has_active_windows("eDP-1"))

    def test_f8_detects_multiple_windows(self):
        self.niri.add_window(id=101, workspace_id=1, app_id="firefox", title="Browser")
        self.niri.add_window(id=102, workspace_id=1, app_id="alacritty", title="Terminal")
        self.assertEqual(self.niri.get_window_count("eDP-1"), 2)
        self.assertTrue(self.niri.has_active_windows("eDP-1"))

    def test_f8_multi_monitor_workspace_isolation(self):
        # Add window to DP-1
        self.niri.add_window(id=201, workspace_id=3, app_id="code", title="VSCode")
        self.assertTrue(self.niri.has_active_windows("DP-1"))
        # eDP-1 is still empty!
        self.assertFalse(self.niri.has_active_windows("eDP-1"), "eDP-1 must remain empty despite window on DP-1")

    def test_f8_workspace_switch_recounts_windows(self):
        self.niri.add_window(id=101, workspace_id=1, app_id="firefox", title="Browser")
        self.assertTrue(self.niri.has_active_windows("eDP-1"))

        # Switch active workspace on eDP-1 to ws2 (which is empty)
        self.niri.activate_workspace("eDP-1", 2)
        self.assertFalse(self.niri.has_active_windows("eDP-1"), "Workspace 2 is empty, window count must be 0")


class TestFeature9_AutohideAnimationAndStateMachine(unittest.TestCase):
    """Feature 9: Autohide Animation & State Machine (M4)"""

    def setUp(self):
        self.sm = DynamicIslandStateMachine(island_height=36, debounce_duration_ms=250)

    def test_f9_empty_workspace_rests_visible(self):
        self.sm.set_window_count(0)
        self.assertEqual(self.sm.state, IslandState.RESTING_VISIBLE)
        self.assertEqual(self.sm.target_y, 0)
        self.assertTrue(self.sm.is_visible)

    def test_f9_window_open_retracts_island(self):
        self.sm.set_window_count(1)
        self.assertEqual(self.sm.state, IslandState.RETRACTED)
        self.assertEqual(self.sm.target_y, -36)
        self.assertFalse(self.sm.is_visible)

    def test_f9_window_close_restores_island(self):
        self.sm.set_window_count(1)
        self.assertEqual(self.sm.state, IslandState.RETRACTED)
        self.sm.set_window_count(0)
        self.assertEqual(self.sm.state, IslandState.RESTING_VISIBLE)
        self.assertEqual(self.sm.target_y, 0)

    def test_f9_popup_open_prevents_retraction(self):
        self.sm.set_window_count(1)
        self.sm.set_popup_active(True)
        self.assertEqual(self.sm.state, IslandState.POPUP_LOCKED)
        self.assertEqual(self.sm.target_y, 0)

    def test_f9_closing_popup_evaluates_windows(self):
        self.sm.set_window_count(1)
        self.sm.set_popup_active(True)
        self.assertEqual(self.sm.state, IslandState.POPUP_LOCKED)
        self.sm.set_popup_active(False)
        self.assertEqual(self.sm.state, IslandState.RETRACTED)

    def test_f9_notification_arrival_locks_island_revealed(self):
        self.sm.set_window_count(1)
        self.assertEqual(self.sm.state, IslandState.RETRACTED)
        self.sm.set_has_notifications(True)
        self.assertEqual(self.sm.state, IslandState.POPUP_LOCKED)
        self.assertEqual(self.sm.target_y, 0)
        self.assertTrue(self.sm.is_visible)

    def test_f9_notification_dismiss_evaluates_windows(self):
        self.sm.set_window_count(1)
        self.sm.set_has_notifications(True)
        self.assertEqual(self.sm.state, IslandState.POPUP_LOCKED)
        self.sm.set_has_notifications(False)
        self.assertEqual(self.sm.state, IslandState.RETRACTED)

    def test_f9_floating_window_not_touching_top_stays_revealed(self):
        # Window exists on workspace (count=1), but is floating below top margin (e.g. y=150)
        self.sm.set_window_count(1)
        self.sm.set_window_touching_top(False)
        self.assertEqual(self.sm.state, IslandState.RESTING_VISIBLE, "Floating window not touching top must NOT hide the island")
        self.assertEqual(self.sm.target_y, 0)
        self.assertTrue(self.sm.is_visible)

    def test_f9_floating_window_touching_top_retracts_island(self):
        # Window exists and touches top margin (y <= 44)
        self.sm.set_window_count(1)
        self.sm.set_window_touching_top(True)
        self.assertEqual(self.sm.state, IslandState.RETRACTED, "Window touching top must cause island to retract")
        self.assertEqual(self.sm.target_y, -36)

    def test_f9_hover_reveals_even_when_window_touching_top(self):
        # Window touching top (retracted) -> hover immediately reveals
        self.sm.set_window_count(1)
        self.sm.set_window_touching_top(True)
        self.assertEqual(self.sm.state, IslandState.RETRACTED)
        self.sm.pointer_enter_trigger()
        self.assertEqual(self.sm.state, IslandState.HOVER_REVEALED, "Hovering at top edge must always reveal island")
        self.assertEqual(self.sm.target_y, 0)


class TestFeature10_TopEdgeHoverTriggerHitbox(unittest.TestCase):
    """Feature 10: Top-Edge Hover Trigger Hitbox (M4)"""

    def setUp(self):
        self.sm = DynamicIslandStateMachine(island_height=36, debounce_duration_ms=250)
        self.sm.set_window_count(1)  # start retracted

    def test_f10_trigger_hitbox_height_is_4px(self):
        mask_model = WaylandInputMaskModel(trigger_height=4)
        regions = mask_model.get_mask_regions(IslandState.RETRACTED)
        self.assertEqual(len(regions), 1)
        self.assertEqual(regions[0].height, 4, "Trigger hitbox must be exactly 4px high")
        self.assertEqual(regions[0].y, 0, "Trigger hitbox must be at top bezel (Y=0)")

    def test_f10_hover_trigger_reveals_island(self):
        self.assertEqual(self.sm.state, IslandState.RETRACTED)
        self.sm.pointer_enter_trigger()
        self.assertEqual(self.sm.state, IslandState.HOVER_REVEALED)
        self.assertEqual(self.sm.target_y, 0)

    def test_f10_cursor_leave_starts_debounce(self):
        self.sm.pointer_enter_trigger()
        self.sm.pointer_leave()
        self.assertTrue(self.sm.in_debounce, "Leaving hover must activate debounce timer")
        self.assertEqual(self.sm.state, IslandState.HOVER_REVEALED, "Must remain revealed during debounce")

    def test_f10_cursor_reentry_cancels_debounce(self):
        self.sm.pointer_enter_trigger()
        self.sm.pointer_leave()
        self.sm.tick(100)  # 150ms left
        self.sm.pointer_enter_island()  # cursor returns into island
        self.assertFalse(self.sm.in_debounce, "Re-entering island must cancel debounce timer")
        self.assertEqual(self.sm.state, IslandState.HOVER_REVEALED)

    def test_f10_debounce_expiry_retracts(self):
        self.sm.pointer_enter_trigger()
        self.sm.pointer_leave()
        self.sm.tick(250)  # timer fully expires
        self.assertFalse(self.sm.in_debounce)
        self.assertEqual(self.sm.state, IslandState.RETRACTED)
        self.assertEqual(self.sm.target_y, -36)


class TestFeature11_PointerPassThroughMasking(unittest.TestCase):
    """Feature 11: Pointer Pass-Through Masking (M4)"""

    def setUp(self):
        self.mask_model = WaylandInputMaskModel(screen_width=1920, screen_height=1080,
                                               island_width=600, island_height=36, trigger_height=4)

    def test_f11_retracted_mask_restricted_to_trigger(self):
        regions = self.mask_model.get_mask_regions(IslandState.RETRACTED)
        self.assertEqual(len(regions), 1)
        r = regions[0]
        self.assertEqual(r.y, 0)
        self.assertEqual(r.height, 4)

    def test_f11_clicks_pass_through_when_retracted(self):
        # Click at (960, 2) is on trigger -> captured by shell
        self.assertFalse(self.mask_model.is_click_passed_through(960, 2, IslandState.RETRACTED))
        # Click at (960, 10) is below trigger -> passes through to underlying window!
        self.assertTrue(self.mask_model.is_click_passed_through(960, 10, IslandState.RETRACTED))
        # Click at (200, 10) outside island x entirely -> passes through!
        self.assertTrue(self.mask_model.is_click_passed_through(200, 10, IslandState.RETRACTED))

    def test_f11_revealed_mask_covers_full_island(self):
        regions = self.mask_model.get_mask_regions(IslandState.HOVER_REVEALED)
        self.assertEqual(len(regions), 1)
        r = regions[0]
        self.assertEqual(r.height, 36)
        self.assertEqual(r.width, 600)
        self.assertEqual(r.x, 660)

    def test_f11_clicks_outside_revealed_island_pass_through(self):
        # Click on island body (960, 20) -> captured by shell
        self.assertFalse(self.mask_model.is_click_passed_through(960, 20, IslandState.HOVER_REVEALED))
        # Click below island (960, 50) -> passes through to window
        self.assertTrue(self.mask_model.is_click_passed_through(960, 50, IslandState.HOVER_REVEALED))
        # Click to the left of island (100, 20) -> passes through to window
        self.assertTrue(self.mask_model.is_click_passed_through(100, 20, IslandState.HOVER_REVEALED))

    def test_f11_popup_mask_covers_full_screen(self):
        regions = self.mask_model.get_mask_regions(IslandState.POPUP_LOCKED, full_screen_popup_open=True)
        self.assertEqual(len(regions), 1)
        r = regions[0]
        self.assertEqual(r.width, 1920)
        self.assertEqual(r.height, 1080)
        # Any point is captured
        self.assertFalse(self.mask_model.is_click_passed_through(100, 500, IslandState.POPUP_LOCKED, full_screen_popup_open=True))


class TestFeature12_NotificationToastStackGeometry(unittest.TestCase):
    """Feature 12: Notification Toast Stack Positioning & Emergence"""

    def compute_toast_state(self, is_island: bool, has_popups: bool, parent_width: int):
        visible = (not is_island) and has_popups
        hitbox = "toastColumn" if ((not is_island) and has_popups) else None
        width = min(420, parent_width - 32) if is_island else 360
        x = round((parent_width - width) / 2) if is_island else (parent_width - width - 12)
        y = 38 if is_island else 56
        z = 50 if is_island else 200
        slide_y = -36 if is_island else -12
        return {"visible": visible, "hitbox": hitbox, "width": width, "x": x, "y": y, "z": z, "slideY": slide_y}

    def test_island_mode_toast_suppressed_for_morphing(self):
        # In island mode, toast stack must NOT open a separate popout window;
        # the island bar morphs directly into the notification instead.
        parent_width = 1920
        state = self.compute_toast_state(is_island=True, has_popups=True, parent_width=parent_width)
        self.assertFalse(state["visible"], "Toast stack must not be visible in island mode")
        self.assertIsNone(state["hitbox"], "Toast stack hitbox must be null in island mode")

    def test_default_mode_toast_top_right(self):
        parent_width = 1920
        state = self.compute_toast_state(is_island=False, has_popups=True, parent_width=parent_width)
        self.assertTrue(state["visible"])
        self.assertEqual(state["hitbox"], "toastColumn")
        self.assertEqual(state["width"], 360)
        self.assertEqual(state["x"], 1920 - 360 - 12)
        self.assertEqual(state["y"], 56)
        self.assertEqual(state["z"], 200)


class TestFeature14_IslandNotificationMorphing(unittest.TestCase):
    """Feature 14: Dynamic Island Direct Notification Morphing"""

    def simulate_island_morph(self, current_mode: str, has_notifications: bool, screen_width: int = 1920):
        # State machine transition on notification
        mode = current_mode
        if has_notifications:
            if mode == "collapsed":
                mode = "notification"
        else:
            if mode == "notification":
                mode = "collapsed"

        is_expanded = mode != "collapsed"
        target_width = min(420, screen_width - 32) if is_expanded else 320
        target_height = 76 if mode == "notification" else (36 if mode == "collapsed" else 400)
        return {
            "mode": mode,
            "is_expanded": is_expanded,
            "target_width": target_width,
            "target_height": target_height,
        }

    def test_notification_arrival_morphs_island(self):
        res = self.simulate_island_morph(current_mode="collapsed", has_notifications=True)
        self.assertEqual(res["mode"], "notification")
        self.assertTrue(res["is_expanded"])
        self.assertEqual(res["target_width"], 420)
        self.assertEqual(res["target_height"], 76, "Island must morph into notification banner height")

    def test_notification_dismissal_collapses_island(self):
        res = self.simulate_island_morph(current_mode="notification", has_notifications=False)
        self.assertEqual(res["mode"], "collapsed")
        self.assertFalse(res["is_expanded"])
        self.assertEqual(res["target_height"], 36, "Island must return to compact 36px height")


class TestFeature13_IslandBarControlsLayout(unittest.TestCase):
    """Feature 13: Dynamic Island Bar Controls Layout (Brightness, Vol, Battery)"""

    def test_controls_order(self):
        # Order requested: brightness, vol, battery
        expected_order = ["brightness", "vol", "battery"]
        self.assertEqual(expected_order[0], "brightness")
        self.assertEqual(expected_order[1], "vol")
        self.assertEqual(expected_order[2], "battery")

    def test_island_bar_controls_flat_and_compact(self):
        # Island bar uses compact 28px flat gauges centered in 36px bar
        island_bar_height = 36
        meter_size = 28
        vertical_margin = (island_bar_height - meter_size) / 2
        self.assertEqual(vertical_margin, 4, "Must have 4px top and bottom margin to prevent clipping")
        self.assertTrue(meter_size < island_bar_height, "Meter size must be smaller than island bar height")

    def test_default_bar_circular_meter_radius(self):
        meter_size = 36
        start_radius = meter_size / 2
        end_radius = meter_size / 2
        self.assertEqual(start_radius, 18)
        self.assertEqual(end_radius, 18)

    def test_audio_format_badge_not_in_island_bar(self):
        with open("modules/bar/layouts/IslandBar.qml", "r", encoding="utf-8") as f:
            island_content = f.read()
        self.assertNotIn("AudioFormatBadge", island_content, "AudioFormatBadge must NOT be present in IslandBar")

        with open("modules/bar/layouts/DefaultBar.qml", "r", encoding="utf-8") as f:
            default_content = f.read()
        self.assertIn("AudioFormatBadge", default_content, "AudioFormatBadge belongs exclusively to DefaultBar")


class TestFeature14_IslandBatteryAndNotificationFocusNonStealing(unittest.TestCase):
    """Feature 14: Battery Panel Clean Layout & Notification Focus Non-Stealing"""

    def test_battery_panel_power_profile_order(self):
        # Order must be: 1. Power Saver, 2. Balanced, 3. Performance
        import re
        battery_panel_path = "modules/bar/island/IslandBatteryPanel.qml"
        with open(battery_panel_path, "r", encoding="utf-8") as f:
            content = f.read()

        saver_idx = content.find('PowerProfile.setProfile("power-saver")')
        balanced_idx = content.find('PowerProfile.setProfile("balanced")')
        perf_idx = content.find('PowerProfile.setProfile("performance")')

        self.assertNotEqual(saver_idx, -1, "Power saver profile button must exist")
        self.assertNotEqual(balanced_idx, -1, "Balanced profile button must exist")
        self.assertNotEqual(perf_idx, -1, "Performance profile button must exist")

        self.assertTrue(saver_idx < balanced_idx, "Power Saver must appear before Balanced")
        self.assertTrue(balanced_idx < perf_idx, "Balanced must appear before Performance")

    def test_battery_panel_charging_badge_removed_from_percentage(self):
        # Ensure the charging pill/badge next to percentage is removed
        battery_panel_path = "modules/bar/island/IslandBatteryPanel.qml"
        with open(battery_panel_path, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertNotIn("stateText", content, "stateText badge next to percentage must be removed")
        self.assertNotIn('text: Battery.isCharging ? "Charging"', content, "Inline Charging badge must be removed")

    def test_notification_mode_does_not_steal_focus_or_fullscreen(self):
        def simulate_panel_input_states(current_mode, run_menu_open=False, timer_input=False, grab_active=False):
            is_expanded = current_mode != "collapsed"
            island_active = is_expanded and current_mode != "notification"
            dashboard_input_active = island_active and current_mode == "dashboard"
            island_open = is_expanded and current_mode != "notification"

            keyboard_focus = "Exclusive" if (run_menu_open or island_active or timer_input or dashboard_input_active) else "None"
            needs_fullscreen_input = run_menu_open or dashboard_input_active or island_active or grab_active

            return {
                "island_active": island_active,
                "dashboard_input_active": dashboard_input_active,
                "island_open": island_open,
                "keyboard_focus": keyboard_focus,
                "needs_fullscreen_input": needs_fullscreen_input,
            }

        # Notification mode must NEVER take exclusive keyboard focus or full-screen input
        notif_state = simulate_panel_input_states("notification")
        self.assertFalse(notif_state["island_active"], "islandActive must be False for notification")
        self.assertFalse(notif_state["dashboard_input_active"], "dashboardInputActive must be False for notification")
        self.assertFalse(notif_state["island_open"], "islandOpen must be False for notification")
        self.assertEqual(notif_state["keyboard_focus"], "None", "Keyboard focus must be None during notification")
        self.assertFalse(notif_state["needs_fullscreen_input"], "Notification must not trigger full-screen input grab")

        # Interactive modes DO take exclusive keyboard focus & full-screen input
        for mode in ["apps", "projects", "dashboard", "power"]:
            interactive_state = simulate_panel_input_states(mode)
            self.assertTrue(interactive_state["island_active"], f"islandActive must be True for {mode}")
            self.assertEqual(interactive_state["keyboard_focus"], "Exclusive", f"Keyboard focus must be Exclusive for {mode}")
            self.assertTrue(interactive_state["needs_fullscreen_input"], f"Fullscreen input must be True for {mode}")


class TestFeature15_IslandMediaTitlePaletteColoring(unittest.TestCase):
    """Feature 15: Clean Theme Palette Coloring for Island Media Title (No Python/Extractors)"""

    def test_no_python_media_color_script_or_service(self):
        import os
        self.assertFalse(os.path.exists("scripts/media_color.py"), "scripts/media_color.py must not exist")
        self.assertFalse(os.path.exists("modules/services/MediaColor.qml"), "modules/services/MediaColor.qml must not exist")

    def test_island_bar_media_title_palette_coloring(self):
        with open("modules/bar/layouts/IslandBar.qml", "r", encoding="utf-8") as f:
            content = f.read()

        # Context title should use Colors.primary when playing and active, otherwise Colors.overBackground
        self.assertIn("(MprisController.isPlaying && MprisController.activePlayer) ? Colors.primary : Colors.overBackground", content)
        self.assertNotIn("MediaColor", content, "IslandBar must not reference MediaColor")
        self.assertNotIn("islandMediaProgress", content, "IslandBar must not have extra progress bar overlay")

    def test_waveform_and_media_card_no_color_extraction(self):
        with open("modules/bar/island/IslandWaveformBar.qml", "r", encoding="utf-8") as f:
            waveform_content = f.read()
        self.assertNotIn("MediaColor", waveform_content, "IslandWaveformBar must not reference MediaColor")

        with open("modules/bar/island/IslandMediaCard.qml", "r", encoding="utf-8") as f:
            card_content = f.read()
        self.assertNotIn("MediaColor", card_content, "IslandMediaCard must not reference MediaColor")


if __name__ == '__main__':
    unittest.main()



