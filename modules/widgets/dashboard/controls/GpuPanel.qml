pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

Item {
    id: root

    property int maxContentWidth: 480
    readonly property int contentWidth: Math.min(width, maxContentWidth)

    component ActionRow: StyledRect {
        id: action

        required property string icon
        required property string label
        property bool selected: false
        property bool actionEnabled: true

        signal triggered

        Layout.fillWidth: true
        Layout.preferredHeight: 36
        variant: {
            if (action.selected)
                return actionMouse.containsMouse ? "primaryfocus" : "primary";
            return actionMouse.containsMouse ? "focus" : "common";
        }
        radius: action.selected ? Styling.radius(-4) : Styling.radius(4)
        opacity: action.actionEnabled ? 1 : 0.45

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            Text {
                text: action.icon
                font.family: Icons.font
                font.pixelSize: 16
                color: action.item
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                Layout.preferredWidth: 20
            }

            Text {
                text: action.label
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                font.weight: Font.Medium
                color: action.item
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                visible: action.selected
                text: Icons.accept
                font.family: Icons.font
                font.pixelSize: 14
                color: action.item
            }
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            enabled: action.actionEnabled
            hoverEnabled: true
            cursorShape: action.actionEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: action.triggered()
        }
    }

    Component.onCompleted: GpuService.refresh()

    Flickable {
        anchors.fill: parent
        contentHeight: contentColumn.implicitHeight
        clip: true

        ColumnLayout {
            id: contentColumn
            width: root.contentWidth
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4

            PanelTitlebar {
                Layout.fillWidth: true
                title: "RTX 3050"
                statusText: GpuService.modeLabel + " · VM " + GpuService.vmStateLabel
                statusColor: GpuService.lastError !== "" ? Colors.error : Styling.srItem("overprimary")
                actions: [
                    {
                        icon: Icons.sync,
                        tooltip: "Refresh GPU and VM status",
                        loading: GpuService.switching,
                        onClicked: function () {
                            GpuService.refresh();
                        }
                    }
                ]
            }

            ActionRow {
                icon: Icons.gpu
                label: GpuService.switching ? "Switching…" : "Linux PRIME"
                selected: GpuService.nvidiaActive
                actionEnabled: !GpuService.switching && !GpuService.nvidiaActive
                onTriggered: GpuService.switchToLinux()
            }

            ActionRow {
                icon: GpuService.vmRunning ? Icons.shutdown : Icons.windowsLogo
                label: GpuService.vmRunning ? "Shut down Windows VM" : "Start Windows VM"
                selected: GpuService.vmRunning
                actionEnabled: !GpuService.switching
                onTriggered: GpuService.toggleVm()
            }

            ActionRow {
                icon: Icons.frameCorners
                label: "Open Looking Glass"
                actionEnabled: GpuService.vmRunning && !GpuService.switching
                onTriggered: GpuService.openLookingGlass()
            }

            ActionRow {
                icon: Icons.popOpen
                label: "Open virt-manager"
                actionEnabled: !GpuService.switching
                onTriggered: GpuService.openVirtManager()
            }

            ActionRow {
                icon: Icons.info
                label: "GPU status"
                actionEnabled: !GpuService.switching
                onTriggered: GpuService.openStatus()
            }
        }
    }
}
