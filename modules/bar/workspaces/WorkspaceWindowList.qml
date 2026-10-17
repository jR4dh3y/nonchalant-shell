pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.modules.components
import qs.modules.services
import qs.modules.services.compositor
import qs.modules.theme

Item {
    id: root
    objectName: "workspaceWindows"

    required property list<CompositorWindow> windows
    property bool vertical: false
    readonly property int buttonSize: Config.theme.fontSize + 10

    readonly property int focusedIndex: windows.findIndex(window => window.is_focused)
    readonly property Item focusedButton: {
        const count = windowRepeater.count;
        return focusedIndex >= 0 && focusedIndex < count ? windowRepeater.itemAt(focusedIndex) : null;
    }
    implicitWidth: windowGrid.implicitWidth
    implicitHeight: windowGrid.implicitHeight

    // The proxy survives window delegate replacement during compositor snapshots.
    Item {
        id: highlightTarget
        visible: false
        x: root.vertical ? 0 : Math.max(0, root.focusedIndex) * (root.buttonSize + windowGrid.columnSpacing)
        y: root.vertical ? Math.max(0, root.focusedIndex) * (root.buttonSize + windowGrid.rowSpacing) : 0
        width: root.buttonSize
        height: root.buttonSize
    }

    ElasticHighlight {
        objectName: root.objectName + "-highlight"
        targetItem: root.focusedIndex >= 0 ? highlightTarget : null
        variant: "primary"
        radius: Styling.radius(-4)
        scale: root.focusedButton?.scale ?? 1

        StyledRect {
            variant: "primary"
            enableBorder: false
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            width: root.buttonSize - 14
            height: 2
            radius: 1
            color: Colors.primaryFixed
        }
    }

    function iconForWindow(window: CompositorWindow): string {
        const entry = DesktopEntries.heuristicLookup(window.appId);
        return entry?.icon || AppSearch.guessIcon(window.appId) || "image-missing";
    }

    GridLayout {
        id: windowGrid
        z: 1
        anchors.fill: parent
        columns: root.vertical ? 1 : Math.max(1, root.windows.length)
        rowSpacing: 3
        columnSpacing: 3

        Repeater {
            id: windowRepeater
            model: root.windows

            Item {
                id: appButton

                required property CompositorWindow modelData
                readonly property CompositorWindow windowData: modelData
                readonly property string iconName: root.iconForWindow(windowData)

                objectName: root.objectName + "-window-" + windowData.id
                Layout.preferredWidth: root.buttonSize
                Layout.preferredHeight: root.buttonSize
                Accessible.role: Accessible.Button
                Accessible.name: windowData.title || windowData.appId
                scale: appMouse.pressed ? 0.92 : 1.0

                PressBehavior on scale {
                    pressed: appMouse.pressed
                }

                StyledRect {
                    anchors.fill: parent
                    variant: "common"
                    radius: Styling.radius(-4)
                    backgroundOpacity: 0
                    enableBorder: false

                    HoverTint {
                        hovered: appMouse.containsMouse && !appButton.windowData.is_focused
                        pressed: appMouse.pressed
                        hoverOpacity: 0.18
                    }
                }

                // Keep icon artwork inside the themed app badge.
                ClippingRectangle {
                    id: appIconClip
                    anchors.centerIn: parent
                    width: appButton.width - 2
                    height: width
                    radius: Styling.radius(-5)
                    color: "transparent"
                    clip: true

                    IconImage {
                        id: appIcon
                        anchors.centerIn: parent
                        // Keep even dimensions inside the even-sized
                        // badge so centerIn does not round to one side.
                        width: 2 * Math.round((root.buttonSize - (appButton.windowData.is_focused ? 8 : 10)) / 2)
                        height: width
                        opacity: appButton.windowData.is_focused ? 1 : 0.62
                        source: "image://icon/" + appButton.iconName
                        asynchronous: true

                        Behavior on width {
                            enabled: Config.animDuration > 0
                            NumberAnimation {
                                duration: Math.min(Config.animDuration, 150)
                                easing.type: Easing.OutQuad
                            }
                        }

                        Behavior on opacity {
                            enabled: Config.animDuration > 0
                            NumberAnimation {
                                duration: Math.min(Config.animDuration, 150)
                                easing.type: Easing.OutQuad
                            }
                        }

                        onStatusChanged: {
                            if (status === Image.Error && appButton.iconName !== "image-missing")
                                source = "image://icon/image-missing";
                        }
                    }
                }

                MouseArea {
                    id: appMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        mouse.accepted = true;
                        CompositorService.focusWindow(appButton.windowData.id);
                    }
                }

                StyledToolTip {
                    show: appMouse.containsMouse
                    tooltipText: appButton.windowData.title || appButton.windowData.appId
                }
            }
        }
    }
}
