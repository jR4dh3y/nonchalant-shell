import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.config

Item {
    id: root
    property bool schemeListExpanded: false
    readonly property var matugenSchemes: [
        "scheme-content",
        "scheme-expressive",
        "scheme-fidelity",
        "scheme-fruit-salad",
        "scheme-monochrome",
        "scheme-neutral",
        "scheme-rainbow",
        "scheme-tonal-spot",
        "scheme-vibrant"
    ]
    property var presets: GlobalStates.wallpaperManager ? GlobalStates.wallpaperManager.colorPresets : []

    property var combinedModel: {
        var currentPresets = presets;
        var list = [];
        for (var i = 0; i < matugenSchemes.length; i++) {
            list.push({
                id: matugenSchemes[i],
                label: getSchemeDisplayName(matugenSchemes[i]),
                type: "matugen"
            });
        }
        for (var j = 0; j < currentPresets.length; j++) {
            list.push({
                id: currentPresets[j],
                label: currentPresets[j],
                type: "preset"
            });
        }
        return list;
    }

    property int selectedSchemeIndex: -1
    property bool keyboardNavigationActive: false

    signal schemeSelectorClosed
    signal escapePressedOnScheme
    signal tabPressed
    signal shiftTabPressed

    function openAndFocus() {
        schemeListExpanded = true;
        updateSelectedIndex();
        keyboardNavigationActive = true;
        schemeButton.forceActiveFocus();
        positionTimer.restart();
    }

    function positionAtSelectedScheme() {
        if (selectedSchemeIndex >= 0 && selectedSchemeIndex < combinedModel.length)
            schemeListView.positionViewAtIndex(selectedSchemeIndex, ListView.Center);
    }

    Timer {
        id: positionTimer
        interval: 50
        repeat: false
        onTriggered: positionAtSelectedScheme()
    }

    // Closing on focus loss used to fire *before* the list item click, so
    // the menu collapsed and the click hit the wallpaper grid instead.
    // Debounce: only collapse if focus left the whole selector and the
    // pointer is not still over it.
    Timer {
        id: focusCloseTimer
        interval: 150
        repeat: false
        onTriggered: {
            if (!root.schemeListExpanded)
                return;
            if (schemeButton.activeFocus)
                return;
            if (rootMouse.containsMouse)
                return;
            keyboardNavigationActive = false;
            schemeListExpanded = false;
            schemeSelectorClosed();
        }
    }

    function closeAndSignal() {
        keyboardNavigationActive = false;
        schemeListExpanded = false;
        schemeSelectorClosed();
    }

    function applySchemeAt(index) {
        if (index < 0 || index >= combinedModel.length || !GlobalStates.wallpaperManager)
            return;
        var item = combinedModel[index];
        if (item.type === "preset")
            GlobalStates.wallpaperManager.setColorPreset(item.id);
        else
            GlobalStates.wallpaperManager.setMatugenScheme(item.id);
        selectedSchemeIndex = index;
        closeAndSignal();
    }

    Connections {
        target: GlobalStates.wallpaperManager
        function onCurrentMatugenSchemeChanged() {
            updateSelectedIndex();
        }
        function onActiveColorPresetChanged() {
            updateSelectedIndex();
        }
    }

    function updateSelectedIndex() {
        if (!GlobalStates.wallpaperManager)
            return;

        var activePreset = GlobalStates.wallpaperManager.activeColorPreset;
        var activeMatugen = GlobalStates.wallpaperManager.currentMatugenScheme;
        var index = -1;

        if (activePreset) {
            for (var i = 0; i < combinedModel.length; i++) {
                if (combinedModel[i].type === "preset" && combinedModel[i].id === activePreset) {
                    index = i;
                    break;
                }
            }
        } else if (activeMatugen) {
            for (var i = 0; i < combinedModel.length; i++) {
                if (combinedModel[i].type === "matugen" && combinedModel[i].id === activeMatugen) {
                    index = i;
                    break;
                }
            }
        }

        if (index !== -1)
            selectedSchemeIndex = index;
    }

    Component.onCompleted: updateSelectedIndex()

    function getSchemeDisplayName(scheme) {
        const map = {
            "scheme-content": "Content",
            "scheme-expressive": "Expressive",
            "scheme-fidelity": "Fidelity",
            "scheme-fruit-salad": "Fruit Salad",
            "scheme-monochrome": "Monochrome",
            "scheme-neutral": "Neutral",
            "scheme-rainbow": "Rainbow",
            "scheme-tonal-spot": "Tonal Spot",
            "scheme-vibrant": "Vibrant"
        };
        return map[scheme] || scheme;
    }

    function getCurrentDisplayName() {
        if (!GlobalStates.wallpaperManager)
            return "Select Scheme";
        if (GlobalStates.wallpaperManager.activeColorPreset)
            return GlobalStates.wallpaperManager.activeColorPreset;
        if (GlobalStates.wallpaperManager.currentMatugenScheme)
            return getSchemeDisplayName(GlobalStates.wallpaperManager.currentMatugenScheme);
        return "Select Scheme";
    }

    implicitWidth: 200
    implicitHeight: 48

    MouseArea {
        id: rootMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        propagateComposedEvents: true
        z: -1
    }

    StyledRect {
        variant: keyboardNavigationActive && schemeButton.activeFocus ? "focus" : "pane"
        radius: Styling.radius(4)
        anchors.fill: parent

        ColumnLayout {
            id: mainLayout
            anchors.fill: parent
            anchors.margins: 4
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Button {
                    id: schemeButton
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    text: getCurrentDisplayName()
                    focus: true
                    // Keep focus inside the selector while picking so the list
                    // does not collapse before the row click is delivered.
                    focusPolicy: Qt.StrongFocus

                    onActiveFocusChanged: {
                        if (!activeFocus && schemeListExpanded)
                            focusCloseTimer.restart();
                        else if (activeFocus)
                            focusCloseTimer.stop();
                    }

                    onClicked: {
                        keyboardNavigationActive = true;
                        schemeListExpanded = !schemeListExpanded;
                        if (schemeListExpanded) {
                            updateSelectedIndex();
                            positionTimer.restart();
                        } else {
                            schemeSelectorClosed();
                        }
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Tab) {
                            keyboardNavigationActive = false;
                            if (schemeListExpanded)
                                schemeListExpanded = false;
                            if (event.modifiers & Qt.ShiftModifier)
                                shiftTabPressed();
                            else
                                tabPressed();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Space) {
                            schemeListExpanded = !schemeListExpanded;
                            if (schemeListExpanded) {
                                updateSelectedIndex();
                                positionTimer.restart();
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Left) {
                            Config.theme.lightMode = true;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Right) {
                            Config.theme.lightMode = false;
                            event.accepted = true;
                        } else if (!schemeListExpanded) {
                            return;
                        } else if (event.key === Qt.Key_Down) {
                            if (selectedSchemeIndex < combinedModel.length - 1) {
                                selectedSchemeIndex++;
                                schemeListView.currentIndex = selectedSchemeIndex;
                                schemeListView.positionViewAtIndex(selectedSchemeIndex, ListView.Contain);
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            if (selectedSchemeIndex > 0) {
                                selectedSchemeIndex--;
                                schemeListView.currentIndex = selectedSchemeIndex;
                                schemeListView.positionViewAtIndex(selectedSchemeIndex, ListView.Contain);
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            applySchemeAt(selectedSchemeIndex);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            keyboardNavigationActive = false;
                            schemeListExpanded = false;
                            schemeButton.focus = false;
                            escapePressedOnScheme();
                            event.accepted = true;
                        }
                    }

                    background: Rectangle {
                        color: Colors.surfaceContainerLow
                        radius: Styling.radius(0)
                    }

                    contentItem: Text {
                        text: parent.text
                        color: Colors.overSurface
                        font.family: Config.theme.font
                        font.pixelSize: Config.theme.fontSize
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 8
                        elide: Text.ElideRight
                    }
                }

                Switch {
                    Layout.preferredWidth: 72
                    Layout.preferredHeight: 40
                    checked: Config.theme.lightMode
                    focusPolicy: Qt.NoFocus

                    onCheckedChanged: Config.theme.lightMode = checked

                    indicator: Rectangle {
                        implicitWidth: 72
                        implicitHeight: 40
                        radius: Styling.radius(0)
                        color: Colors.surfaceContainerLow

                        Text {
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            z: 1
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: Icons.sun
                            color: Config.theme.lightMode ? Styling.srItem("primary") : Colors.overBackground
                            font.family: Icons.font
                            font.pixelSize: 20
                        }

                        Text {
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            z: 1
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: Icons.moon
                            color: Config.theme.lightMode ? Colors.overBackground : Styling.srItem("primary")
                            font.family: Icons.font
                            font.pixelSize: 20
                        }

                        StyledRect {
                            variant: "primary"
                            z: 0
                            width: 36
                            height: 36
                            radius: Styling.radius(-2)
                            x: Config.theme.lightMode ? 2 : 36
                            anchors.verticalCenter: parent.verticalCenter

                            Behavior on x {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    PopupWindow {
        id: schemeListPopup
        anchor.item: root
        anchor.rect.x: 4
        anchor.rect.y: 48
        anchor.rect.width: 0
        anchor.rect.height: 0
        implicitWidth: Math.max(0, root.width - 8)
        implicitHeight: 40 * 4
        color: "transparent"
        visible: root.schemeListExpanded

        ClippingRectangle {
            anchors.fill: parent
            color: Colors.surfaceContainerLow
            radius: Styling.radius(0)
            opacity: root.schemeListExpanded ? 1 : 0
            clip: true

            ListView {
                id: schemeListView
                anchors.fill: parent
                clip: true
                model: combinedModel
                currentIndex: selectedSchemeIndex
                interactive: true
                boundsBehavior: Flickable.StopAtBounds
                highlightFollowsCurrentItem: true
                keyNavigationEnabled: false
                focus: false

                onCurrentIndexChanged: {
                    if (currentIndex !== selectedSchemeIndex && currentIndex >= 0)
                        selectedSchemeIndex = currentIndex;
                }

                delegate: Item {
                    id: delegateRoot
                    required property var modelData
                    required property int index

                    width: schemeListView.width
                    height: 40

                    readonly property bool isSelected: selectedSchemeIndex === index

                    StyledRect {
                        anchors.fill: parent
                        variant: delegateRoot.isSelected ? "primary" : "transparent"
                        radius: Styling.radius(0)
                        opacity: delegateRoot.isSelected ? 1 : 0
                    }

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        text: modelData.label
                        color: delegateRoot.isSelected ? Styling.srItem("primary") : Colors.overSurface
                        font.family: Config.theme.font
                        font.pixelSize: Config.theme.fontSize
                        font.weight: delegateRoot.isSelected ? Font.Bold : Font.Normal
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        // Prevent the parent Button from stealing focus on press
                        // before we apply the selection.
                        preventStealing: true
                        onEntered: {
                            selectedSchemeIndex = index;
                            schemeListView.currentIndex = index;
                        }
                        onPressed: mouse => {
                            // Keep scheme button focused so focusCloseTimer does not fire mid-click.
                            schemeButton.forceActiveFocus();
                            mouse.accepted = true;
                        }
                        onClicked: {
                            applySchemeAt(index);
                        }
                    }
                }
            }

            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: Easing.OutQuart
                }
            }
        }
    }
}
