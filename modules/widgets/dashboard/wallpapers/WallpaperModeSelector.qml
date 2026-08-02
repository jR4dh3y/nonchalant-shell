import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.config

Item {
    id: root

    readonly property var modes: [
        { id: "crop", label: "Crop" },
        { id: "fit", label: "Fit" },
        { id: "stretch", label: "Stretch" },
        { id: "center", label: "Center" }
    ]
    property bool modeListExpanded: false
    property int selectedModeIndex: -1
    property bool keyboardNavigationActive: false

    signal modeSelectorClosed
    signal escapePressedOnMode
    signal tabPressed
    signal shiftTabPressed

    function currentModeId() {
        const manager = GlobalStates.wallpaperManager;
        if (!manager || !manager.wallpaperMode)
            return "crop";
        for (let i = 0; i < modes.length; i++) {
            if (modes[i].id === manager.wallpaperMode)
                return manager.wallpaperMode;
        }
        return "crop";
    }

    function currentModeLabel() {
        const mode = currentModeId();
        for (let i = 0; i < modes.length; i++) {
            if (modes[i].id === mode)
                return modes[i].label;
        }
        return modes[0].label;
    }

    function updateSelectedIndex() {
        const mode = currentModeId();
        for (let i = 0; i < modes.length; i++) {
            if (modes[i].id === mode) {
                selectedModeIndex = i;
                return;
            }
        }
        selectedModeIndex = 0;
    }

    function openAndFocus() {
        modeListExpanded = true;
        updateSelectedIndex();
        keyboardNavigationActive = true;
        modeButton.forceActiveFocus();
        positionTimer.restart();
    }

    function closeAndSignal() {
        keyboardNavigationActive = false;
        modeListExpanded = false;
        modeSelectorClosed();
    }

    function toggleModeList() {
        keyboardNavigationActive = true;
        if (modeListExpanded) {
            closeAndSignal();
        } else {
            openAndFocus();
        }
    }

    function applyModeAt(index) {
        if (index < 0 || index >= modes.length || !GlobalStates.wallpaperManager)
            return;

        GlobalStates.wallpaperManager.setWallpaperMode(modes[index].id);
        selectedModeIndex = index;
        closeAndSignal();
    }

    Timer {
        id: positionTimer
        interval: 50
        repeat: false
        onTriggered: {
            if (selectedModeIndex >= 0 && selectedModeIndex < modes.length)
                modeListView.positionViewAtIndex(selectedModeIndex, ListView.Contain);
        }
    }

    Timer {
        id: focusCloseTimer
        interval: 150
        repeat: false
        onTriggered: {
            if (!root.modeListExpanded || modeButton.activeFocus || rootMouse.containsMouse)
                return;
            keyboardNavigationActive = false;
            modeListExpanded = false;
            modeSelectorClosed();
        }
    }

    implicitWidth: 150
    implicitHeight: modeListExpanded ? 48 + 4 + (40 * modes.length) + 8 : 48

    Behavior on implicitHeight {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutQuart
        }
    }

    MouseArea {
        id: rootMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        propagateComposedEvents: true
        z: -1
    }

    StyledRect {
        variant: keyboardNavigationActive && modeButton.activeFocus ? "focus" : "pane"
        radius: Styling.radius(4)
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 0

            Button {
                id: modeButton
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                text: root.modeListExpanded
                    ? modes[selectedModeIndex >= 0 ? selectedModeIndex : 0].label
                    : root.currentModeLabel()
                focus: true
                focusPolicy: Qt.StrongFocus

                onActiveFocusChanged: {
                    if (!activeFocus && modeListExpanded)
                        focusCloseTimer.restart();
                    else if (activeFocus)
                        focusCloseTimer.stop();
                }

                onClicked: toggleModeList()

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Tab) {
                        keyboardNavigationActive = false;
                        if (modeListExpanded)
                            modeListExpanded = false;
                        if (event.modifiers & Qt.ShiftModifier)
                            shiftTabPressed();
                        else
                            tabPressed();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Space) {
                        toggleModeList();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Down) {
                        if (!modeListExpanded)
                            openAndFocus();
                        else if (selectedModeIndex < modes.length - 1)
                            selectedModeIndex++;
                        modeListView.currentIndex = selectedModeIndex;
                        modeListView.positionViewAtIndex(selectedModeIndex, ListView.Contain);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up) {
                        if (!modeListExpanded)
                            openAndFocus();
                        else if (selectedModeIndex > 0)
                            selectedModeIndex--;
                        modeListView.currentIndex = selectedModeIndex;
                        modeListView.positionViewAtIndex(selectedModeIndex, ListView.Contain);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (modeListExpanded)
                            applyModeAt(selectedModeIndex);
                        else
                            openAndFocus();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape) {
                        keyboardNavigationActive = false;
                        modeListExpanded = false;
                        modeButton.focus = false;
                        escapePressedOnMode();
                        event.accepted = true;
                    }
                }

                background: StyledRect {
                    variant: "common"
                    color: Colors.surfaceContainerLow
                    radius: Styling.radius(0)
                }

                contentItem: RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 4

                    Text {
                        Layout.fillWidth: true
                        text: modeButton.text
                        color: Colors.overSurface
                        font.family: Config.theme.font
                        font.pixelSize: Config.theme.fontSize
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    Text {
                        text: Icons.caretDown
                        color: Colors.overSurface
                        font.family: Icons.font
                        font.pixelSize: 14
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                    }
                }
            }

            ClippingRectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: modeListExpanded ? 40 * modes.length : 0
                Layout.topMargin: modeListExpanded ? 4 : 0
                color: Colors.surfaceContainerLow
                radius: Styling.radius(0)
                opacity: modeListExpanded ? 1 : 0
                visible: Layout.preferredHeight > 0
                clip: true

                ListView {
                    id: modeListView
                    anchors.fill: parent
                    clip: true
                    model: root.modes
                    currentIndex: root.selectedModeIndex
                    interactive: true
                    boundsBehavior: Flickable.StopAtBounds
                    keyNavigationEnabled: false
                    focus: false

                    onCurrentIndexChanged: {
                        if (root.modeListExpanded && currentIndex !== selectedModeIndex && currentIndex >= 0)
                            selectedModeIndex = currentIndex;
                    }

                    delegate: Item {
                        id: delegateRoot
                        required property var modelData
                        required property int index

                        width: modeListView.width
                        height: 40
                        readonly property bool isSelected: root.selectedModeIndex === index

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
                            preventStealing: true

                            onEntered: {
                                selectedModeIndex = index;
                                modeListView.currentIndex = index;
                            }

                            onPressed: mouse => {
                                modeButton.forceActiveFocus();
                                mouse.accepted = true;
                            }

                            onClicked: applyModeAt(index)
                        }
                    }
                }

                Behavior on Layout.topMargin {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }

                Behavior on Layout.preferredHeight {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
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

    Connections {
        target: GlobalStates.wallpaperManager
        function onWallpaperModeChanged() {
            updateSelectedIndex();
        }
    }

    Component.onCompleted: updateSelectedIndex()
}
