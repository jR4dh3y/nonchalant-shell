"""Verify the independent settings and lyrics runtime with isolated user state."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
QML = r'''
import QtQuick
import QtTest
import Quickshell
import qs.config
import qs.modules.globals
import qs.modules.services
import qs.modules.components
import qs.modules.widgets.dashboard
import qs.modules.widgets.dashboard.widgets
import qs.modules.widgets.dashboard.controls

ShellRoot {
    FloatingWindow {
        id: testWindow
        visible: true
        implicitWidth: 1000
        implicitHeight: 800
        SettingsTab { id: settings; anchors.fill: parent }
        ThemePanel { id: compactTheme; width: 1000; visible: false }
        LyricsView { id: lyrics; width: 200; height: 22 }
        CustomColorPicker { id: picker; parent: settings }
        Component { id: verticalDashboard; VerticalDashboard { screenName: "lyrics-test" } }
        Component { id: verticalMediaMenu; VerticalControlMenu { mode: "media" } }
        Component {
            id: controlIslands
            VerticalDashboardControls {
                onSectionRequested: section => dashboardSection = section
            }
        }
        TestCase {
            name: "SettingsLyricsRuntime"
            when: Config.initialLoadComplete

            function initTestCase() {
                // Construct pages synchronously in QtTest's nested event loop.
                findChild(settings, "settingsPanelLoader").asynchronous = false
            }

            function expectPage(pageId) {
                const loader = findChild(settings, "settingsPanelLoader")
                compare(settings.currentPageId, pageId)
                compare(String(loader.source), settings.pageFor(pageId).component)
                tryCompare(loader, "status", Loader.Ready, 5000)
                tryCompare(settings, "loadedPageId", pageId, 5000)
            }

            function test_bar_position_for_horizontal_styles() {
                settings.go("shell", "bar")
                expectPage("shell")
                const panel = findChild(settings, "settingsPanelLoader").item
                function findSelector(item, label) {
                    if (item.label === label && item.options !== undefined)
                        return item
                    for (const child of item.children ?? []) {
                        const selector = findSelector(child, label)
                        if (selector !== null)
                            return selector
                    }
                    return null
                }
                const selector = findSelector(panel, "Position")
                const styles = findSelector(panel, "Style")
                verify(selector !== null)
                verify(styles !== null)
                compare(styles.options.map(option => option.value).join(","), "default,island,pills,left,deck")
                function findOption(item, value) {
                    if (item.modelData?.value === value)
                        return item
                    for (const child of item.children ?? []) {
                        const option = findOption(child, value)
                        if (option !== null)
                            return option
                    }
                    return null
                }
                const previousStyle = Config.bar.style
                const previousPosition = Config.bar.position
                try {
                    Config.bar.position = "bottom"
                    for (const style of ["default", "island", "pills", "left", "deck", "default"]) {
                        const target = findOption(styles, style)
                        verify(target !== null)
                        tryVerify(() => target.width > 0 && target.height > 0)
                        mouseClick(target, target.width / 2, target.height / 2, Qt.LeftButton)
                        tryCompare(Config.bar, "style", style)
                        tryCompare(selector, "visible", style === "default" || style === "deck")
                        compare(Config.bar.position, "bottom")
                        compare(selector.value, "bottom")
                        for (const value of ["default", "island", "pills", "left", "deck"]) {
                            const option = findOption(styles, value)
                            verify(option !== null, value + " option exists")
                            tryCompare(option, "visible", true)
                            tryVerify(() => option.width > 0 && option.height > 0, 1000,
                                value + " option has visible geometry")
                        }
                    }
                } finally {
                    Config.bar.style = previousStyle
                    Config.bar.position = previousPosition
                }
                console.log("SETTINGS_BAR_POSITION_RUNTIME_PASSED")
            }

            function test_search_navigation_follows_display_order() {
                for (const query of ["a", "s", "color", "system", "lyrics"]) {
                    settings.searchQuery = query
                    const rows = settings.sidebarRows.filter(row => !row.heading)
                    compare(rows.length, settings.searchResults.length)
                    for (let index = 0; index < rows.length; index++) {
                        compare(rows[index].resultIndex, index, query + ": keyboard order must match rows")
                        compare(settings.searchResults[index].pageId, rows[index].pageId)
                        compare(settings.searchCursor, index)
                        settings.moveSearchCursor(1)
                    }
                    compare(settings.searchCursor, 0, "Down wraps after the last visible result")
                }
                settings.searchQuery = ""
                console.log("SETTINGS_SEARCH_ORDER_PASSED")
            }

            function test_color_picker_hues_match_selection() {
                function hueSlider(item) {
                    if (item.to === 360 && item.from === 0) return item
                    for (const child of item.children ?? []) {
                        const found = hueSlider(child)
                        if (found) return found
                    }
                    return null
                }
                picker.open()
                picker.saturation = 1
                picker.value = 1
                picker.alpha = 1
                const slider = hueSlider(picker.contentItem)
                verify(slider !== null)
                const stops = slider.background.children[0].gradient.stops
                compare(stops.length, 7)
                for (const stop of stops) {
                    const expected = Qt.hsva(stop.position, 1, 1, 1)
                    verify(Math.abs(stop.color.r - expected.r) < 0.002)
                    verify(Math.abs(stop.color.g - expected.g) < 0.002)
                    verify(Math.abs(stop.color.b - expected.b) < 0.002)
                    picker.hue = stop.position * 360
                    compare(picker.selectedColor, expected)
                }
                picker.close()
                console.log("SETTINGS_COLOR_HUES_PASSED")
            }
            function test_independent_settings_and_lyrics() {
                verify(Config.desktop === undefined)
                settings.go("shell", "bar")
                expectPage("shell")
                compare(settings.currentTabId, "bar")
                settings.go("audio", "")
                expectPage("audio")
                settings.back()
                expectPage("shell")
                compare(settings.currentPageId, "shell")
                compare(settings.currentTabId, "bar")
                settings.forward()
                expectPage("audio")
                compare(settings.currentPageId, "audio")
                GlobalStates.openSettings("theme", "colors")
                expectPage("theme")
                compare(settings.currentTabId, "colors")
                settings.searchQuery = "lyrics"
                verify(settings.searchResults.some(result => result.tabId === "bar"))
                verify(settings.searchResults.some(result => result.tabId === "lockscreen"))
                verify(!settings.sidebarRows.some(row => row.pageId === "desktop"))
                compare(LyricsService.watchers, 0)
                lyrics.active = true
                tryCompare(LyricsService, "watchers", 1, 1000)
                Config.bar.lyricsEnabled = false
                tryCompare(LyricsService, "watchers", 0, 1000)
                Config.bar.lyricsEnabled = true
                tryCompare(LyricsService, "watchers", 1, 1000)
                lyrics.visible = false
                tryCompare(LyricsService, "watchers", 0, 1000)
                verify(!LyricsService.queryActive)
                console.log("SETTINGS_LYRICS_RUNTIME_PASSED")
            }

            function test_settings_use_available_width() {
                const loader = findChild(settings, "settingsPanelLoader")
                verify(loader !== null)
                const pages = ["network", "bluetooth", "audio", "ai", "shell", "theme", "system"]
                for (const pageId of pages) {
                    const page = settings.pageFor(pageId)
                    verify(!page.tabs.some(tab => tab.id === "overview"))
                    if (page.tabs.length > 0) {
                        compare(settings.defaultTab(pageId), page.tabs[0].id)
                    }
                    const tabs = page.tabs.length > 0 ? page.tabs.map(tab => tab.id) : [""]
                    for (const tabId of tabs) {
                        settings.go(pageId, tabId)
                        expectPage(pageId)
                        for (const availableWidth of [1600, 900, 680]) {
                            settings.width = availableWidth
                            tryVerify(() => loader.width > 0 && loader.item.contentWidth === loader.width, 1000)
                            compare(loader.item.sideMargin, 0)
                        }
                    }
                }
                settings.go("theme", "colors")
                expectPage("theme")
                loader.item.openColorPicker(["background", "primary"], "background", "Select Color", () => {})
                compare(loader.item.colorPickerActive, true)
                settings.width = 1600
                tryCompare(loader.item, "contentWidth", loader.width, 1000)
                compare(loader.item.sideMargin, 0)
                loader.item.closeColorPicker()
                compare(loader.item.colorPickerActive, false)
                compare(settings.currentTabId, "colors")
                settings.go("theme", "")
                compare(settings.currentTabId, "colors")
                compare(compactTheme.contentWidth, 480)
                console.log("SETTINGS_LAYOUT_RUNTIME_PASSED")
            }

            function test_vertical_dashboard_control_islands() {
                const controls = createTemporaryObject(controlIslands, testWindow.contentItem,
                    {width: 64, height: 420, z: 100})
                verify(controls !== null)
                const top = findChild(controls, "dashboardViewControlsIsland")
                const bottom = findChild(controls, "dashboardStaticControlsIsland")
                tryVerify(() => top.height > 0 && bottom.height > 0)
                compare(top.y, 0)
                compare(bottom.y + bottom.height, controls.height)
                verify(bottom.y > top.y + top.height, "islands have a visible gap")
                const buttons = [
                    ["dashboardWallpapersButton", "wallpapers"],
                    ["dashboardStatsButton", "stats"],
                    ["dashboardNotificationsButton", "notifications"]
                ]
                for (const [name, section] of buttons) {
                    const button = findChild(controls, name)
                    verify(button !== null)
                    mouseClick(button, button.width / 2, button.height / 2, Qt.LeftButton)
                    compare(controls.dashboardSection, section)
                    compare(button.isActive, true)
                    for (const [otherName, otherSection] of buttons)
                        compare(findChild(controls, otherName).isActive, otherSection === section)
                }
                const highlight = findChild(controls, "dashboardViewHighlight")
                verify(highlight !== null)
                const notifications = findChild(controls, "dashboardNotificationsButton")
                const wallpapers = findChild(controls, "dashboardWallpapersButton")
                const stats = findChild(controls, "dashboardStatsButton")
                const previousDuration = Config.theme.animDuration
                function aligned(button) {
                    const target = button.mapToItem(highlight.parent, 0, 0)
                    return Math.abs(highlight.y - target.y) < 0.1
                        && Math.abs(highlight.height - button.height) < 0.1
                }
                try {
                    Config.theme.animDuration = 300
                    tryVerify(() => aligned(notifications))
                    tryCompare(highlight, "morphing", true)
                    const fromY = highlight.y
                    controls.dashboardSection = "stats"
                    const targetY = stats.mapToItem(highlight.parent, 0, 0).y
                    tryVerify(() => highlight.y > fromY && highlight.y < targetY, 1000,
                        "shared highlight travels between buttons")
                    tryVerify(() => aligned(stats))
                    controls.dashboardSection = "wallpapers"
                    wait(40)
                    controls.dashboardSection = "notifications"
                    tryVerify(() => aligned(notifications), 1000,
                        "rapid changes settle at the latest selected view")
                    for (const button of [notifications, wallpapers, stats])
                        compare(button.backgroundOpacity, 0)
                    Config.theme.animDuration = 0
                    controls.dashboardSection = "wallpapers"
                    tryVerify(() => aligned(wallpapers))
                } finally {
                    Config.theme.animDuration = previousDuration
                }
                console.log("VERTICAL_DASHBOARD_CONTROL_ISLANDS_PASSED")
            }

            function test_vertical_dashboard_hides_inactive_media_and_lyrics() {
                const previousStyle = Config.bar.style
                const previousScreen = GlobalStates.dashboardPopupScreen
                const previousLyricsEnabled = Config.bar.lyricsEnabled
                let panel = null
                try {
                    Config.bar.style = "left"
                    Config.bar.lyricsEnabled = true
                    panel = createTemporaryObject(verticalDashboard, testWindow.contentItem,
                        {width: 768, height: 600, z: 100})
                    verify(panel !== null)
                    const media = findChild(panel, "dashboardMediaCard")
                    const detail = findChild(panel, "dashboardLyrics")
                    const row = findChild(panel, "dashboardMediaRow")
                    verify(media !== null && detail !== null && row !== null)
                    compare(MprisController.activePlayer, null)
                    compare(row.visible, false, "No player must hide the media and lyrics row")
                    compare(detail.active, false)
                    GlobalStates.dashboardPopupScreen = "lyrics-test"
                    tryCompare(LyricsService, "watchers", 0, 1000)
                    Config.bar.lyricsEnabled = false
                    tryCompare(LyricsService, "watchers", 0, 1000)
                    Config.bar.lyricsEnabled = true
                    tryCompare(LyricsService, "watchers", 0, 1000)
                    GlobalStates.dashboardPopupScreen = ""
                    tryCompare(LyricsService, "watchers", 0, 1000)
                } finally {
                    if (panel) panel.destroy()
                    GlobalStates.dashboardPopupScreen = previousScreen
                    Config.bar.lyricsEnabled = previousLyricsEnabled
                    Config.bar.style = previousStyle
                }
                console.log("VERTICAL_DASHBOARD_INACTIVE_MEDIA_PASSED")
            }

            function test_vertical_media_menu_lyrics_lifetime() {
                const previousLyricsEnabled = Config.bar.lyricsEnabled
                let menu = null
                try {
                    Config.bar.lyricsEnabled = true
                    menu = createTemporaryObject(verticalMediaMenu, testWindow.contentItem,
                        {width: 392, height: 392, z: 100})
                    verify(menu !== null)
                    compare(LyricsService.watchers, 0)
                    menu.lyricsActive = true
                    tryCompare(LyricsService, "watchers", 1, 1000)
                    Config.bar.lyricsEnabled = false
                    tryCompare(LyricsService, "watchers", 0, 1000)
                    Config.bar.lyricsEnabled = true
                    tryCompare(LyricsService, "watchers", 1, 1000)
                    menu.lyricsActive = false
                    tryCompare(LyricsService, "watchers", 0, 1000)
                    menu.lyricsActive = true
                    tryCompare(LyricsService, "watchers", 1, 1000)
                    menu.mode = "wifi"
                    tryCompare(LyricsService, "watchers", 0, 1000)
                    menu.mode = "media"
                    tryCompare(LyricsService, "watchers", 1, 1000)
                } finally {
                    if (menu) menu.destroy()
                    Config.bar.lyricsEnabled = previousLyricsEnabled
                }
                tryCompare(LyricsService, "watchers", 0, 1000)
                console.log("VERTICAL_MEDIA_LYRICS_LIFETIME_PASSED")
            }

            function cleanupTestCase() { Qt.quit() }
        }
    }
    Timer {
        interval: 15000
        running: true
        onTriggered: { console.error("SETTINGS_LYRICS_RUNTIME_TIMEOUT"); Qt.quit() }
    }
}
'''


@unittest.skipUnless(shutil.which("qs"), "Quickshell is required for runtime checks")
class SettingsLyricsRuntimeTests(unittest.TestCase):
    def test_settings_navigation_and_lyrics_demand(self):
        with tempfile.TemporaryDirectory(prefix="nonchalant-settings-lyrics-") as directory:
            fixture = Path(directory)
            for name in ("modules", "config", "assets", "scripts", "version"):
                (fixture / name).symlink_to(ROOT / name, target_is_directory=(ROOT / name).is_dir())
            (fixture / "shell.qml").write_text(QML)
            home = fixture / "home"
            home.mkdir()
            runtime = fixture / "runtime"
            runtime.mkdir(mode=0o700)
            env = {
                **os.environ,
                "HOME": str(home),
                "XDG_CONFIG_HOME": str(home / ".config"),
                "XDG_STATE_HOME": str(home / ".local/state"),
                "XDG_DATA_HOME": str(home / ".local/share"),
                "XDG_CACHE_HOME": str(home / ".cache"),
                "XDG_RUNTIME_DIR": str(runtime),
                "DBUS_SESSION_BUS_ADDRESS": "unix:path=" + str(runtime / "no-session-bus"),
                "QT_QPA_PLATFORM": "offscreen",
                "QT_QUICK_BACKEND": "software",
                "NIRI_SOCKET": str(fixture / "no-compositor.sock"),
            }
            env.pop("WAYLAND_DISPLAY", None)
            result = subprocess.run(
                ["qs", "-p", str(fixture), "--no-duplicate", "--no-color"],
                env=env, capture_output=True, text=True, timeout=25,
            )
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn("SETTINGS_LYRICS_RUNTIME_PASSED", output, output)
            self.assertIn("SETTINGS_LAYOUT_RUNTIME_PASSED", output, output)
            self.assertIn("SETTINGS_SEARCH_ORDER_PASSED", output, output)
            self.assertIn("SETTINGS_COLOR_HUES_PASSED", output, output)
            self.assertIn("SETTINGS_BAR_POSITION_RUNTIME_PASSED", output, output)
            self.assertIn("VERTICAL_MEDIA_LYRICS_LIFETIME_PASSED", output, output)
            self.assertIn("VERTICAL_DASHBOARD_CONTROL_ISLANDS_PASSED", output, output)
            self.assertIn("VERTICAL_DASHBOARD_INACTIVE_MEDIA_PASSED", output, output)
            self.assertNotIn("SETTINGS_LYRICS_RUNTIME_TIMEOUT", output, output)
            self.assertNotIn("FAIL!", output, output)


if __name__ == "__main__":
    unittest.main()
