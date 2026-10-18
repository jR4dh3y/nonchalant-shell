pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.modules.components

ShellRoot {
    PanelWindow {
        id: panel
        screen: Quickshell.screens.find(screen => screen.name === "TEST-1") ?? Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Overlay
        color: "#303030"

        component Sample: Text {
            x: 10
            y: 10
            text: "Workspace 2  21:10  Abcdef"
            font.family: "DejaVu Sans Mono"
            font.pixelSize: 14
            font.bold: true
            color: "white"
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
        }

        Repeater {
            model: 3
            delegate: Item {
                id: column
                required property int index
                x: 20 + index * 300
                y: 30
                width: 280
                height: 400

                Text {
                    text: ["Direct text", "Three StyledRects", "Three texture masks"][column.index]
                    color: "white"
                    font.pixelSize: 18
                }

                Repeater {
                    model: 4
                    delegate: Item {
                        id: row
                        required property int index
                        x: (index % 2) * 10
                        y: 50 + index * 70
                        width: 281
                        height: 51

                        Sample { visible: column.index === 0 }

                        StyledRect {
                            anchors.fill: parent
                            variant: "pane"
                            color: "#303030"
                            enableBorder: false
                            radius: 10
                            visible: column.index === 1

                            StyledRect {
                                anchors.fill: parent
                                variant: "pane"
                                color: "#303030"
                                enableBorder: false
                                radius: 10

                                StyledRect {
                                    anchors.fill: parent
                                    variant: "pane"
                                    color: "#303030"
                                    enableBorder: false
                                    radius: 10
                                    Sample {}
                                }
                            }
                        }

                        ClippingRectangle {
                            anchors.fill: parent
                            color: "#303030"
                            radius: 10
                            visible: column.index === 2

                            ClippingRectangle {
                                anchors.fill: parent
                                color: "#303030"
                                radius: 10

                                ClippingRectangle {
                                    anchors.fill: parent
                                    color: "#303030"
                                    radius: 10
                                    Sample {}
                                }
                            }
                        }
                    }
                }
            }
        }

        Repeater {
            model: ["common", "focus", "internalbg"]
            delegate: StyledRect {
                id: gradientCard
                required property int index
                required property string modelData
                x: 20 + index * 300
                y: 380
                width: 260
                height: 70
                radius: 20
                variant: modelData
                border.width: 4
                border.color: Qt.rgba(1, 1, 1, 0.5)

                Sample { text: ["Linear", "Radial", "Halftone"][gradientCard.index] }
            }
        }

        StyledRect {
            x: 20
            y: 480
            width: 260
            height: 65
            variant: "pane"
            color: "#303030"
            radius: 20
            topLeftRadius: 0
            topRightRadius: 30
            bottomLeftRadius: 15
            bottomRightRadius: 0
            enableBorder: false

            HoverTint { hovered: true; hoverOpacity: 1 }
            Sample { text: "Asymmetric hover" }
        }

        StyledRect {
            x: 320
            y: 480
            width: 260
            height: 65
            variant: "pane"
            color: "transparent"
            radius: 20
            border.width: 4
            border.color: Qt.rgba(1, 1, 1, 0.5)
        }

        IpcHandler {
            target: "text-rendering-test"
            function width(): real { return panel.width; }
        }
    }
}
