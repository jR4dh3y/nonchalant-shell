pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components

Popup {
    id: root

    property color initialColor: Colors.surface
    property string title: "Select Color"
    property real hue: 0
    property real saturation: 1
    property real value: 1
    property real alpha: 1

    signal colorSelected(string color)

    readonly property color selectedColor: Qt.hsva(hue / 360, saturation, value, alpha)
    readonly property int edgeMargin: 16

    width: parent ? Math.min(380, Math.max(220, parent.width - edgeMargin * 2)) : 360
    height: parent ? Math.min(contentItem.implicitHeight + padding * 2, Math.max(240, parent.height - edgeMargin * 2)) : contentItem.implicitHeight + padding * 2
    x: parent ? Math.max(edgeMargin, (parent.width - width) / 2) : edgeMargin
    y: parent ? Math.max(edgeMargin, (parent.height - height) / 2) : edgeMargin
    padding: 16
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside


    function loadColor(colorValue: color): void {
        hue = colorValue.hsvHue < 0 ? 0 : colorValue.hsvHue * 360;
        saturation = colorValue.hsvSaturation;
        value = colorValue.hsvValue;
        alpha = colorValue.a;
        hueSlider.value = hue;
        alphaSlider.value = alpha;
    }

    function setSaturationValue(x: real, y: real): void {
        saturation = Math.max(0, Math.min(1, x));
        value = 1 - Math.max(0, Math.min(1, y));
    }

    onOpened: loadColor(initialColor)

    background: StyledRect {
        variant: "popup"
        radius: Styling.radius(-8)
    }

    contentItem: ColumnLayout {
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            StyledRect {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                variant: "common"
                radius: Styling.radius(-3)

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: Styling.radius(-4)
                    color: root.selectedColor
                }
            }

            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                Layout.fillWidth: true
                text: root.title
                font.family: Styling.defaultFont
                font.pixelSize: Styling.fontSize(1)
                font.weight: Font.Medium
                color: Colors.overBackground
                elide: Text.ElideRight
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                text: "Saturation " + Math.round(root.saturation * 100) + "%"
                font.family: Styling.defaultFont
                font.pixelSize: Styling.fontSize(-1)
                color: Colors.overBackground
            }

            Item { Layout.fillWidth: true }

            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                text: "Value " + Math.round(root.value * 100) + "%"
                font.family: Styling.defaultFont
                font.pixelSize: Styling.fontSize(-1)
                color: Colors.overBackground
            }
        }
        Item {
            id: saturationValueArea
            Layout.fillWidth: true
            Layout.preferredHeight: 156
            activeFocusOnTab: true

            StyledRect {
                anchors.fill: parent
                variant: "internalbg"
                radius: Styling.radius(-2)
            }

            Item {
                id: spectrumField
                anchors.fill: parent
                anchors.margins: 2
                clip: true

                Rectangle {
                    anchors.fill: parent
                    color: Qt.hsva(root.hue / 360, 1, 1, 1)
                }

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "white" }
                        GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0) }
                        GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 1) }
                    }
                }

                Rectangle {
                    width: 14
                    height: 14
                    x: Math.max(0, Math.min(spectrumField.width - width, root.saturation * spectrumField.width - width / 2))
                    y: Math.max(0, Math.min(spectrumField.height - height, (1 - root.value) * spectrumField.height - height / 2))
                    radius: width / 2
                    color: "transparent"
                    border.width: 2
                    border.color: Colors.overBackground
                    z: 1

                    Rectangle {
                        anchors.centerIn: parent
                        width: 3
                        height: 3
                        radius: width / 2
                        color: Colors.overBackground
                    }
                }
            }

            MouseArea {
                anchors.fill: spectrumField
                hoverEnabled: true
                cursorShape: Qt.CrossCursor
                onPressed: mouse => root.setSaturationValue(mouse.x / width, mouse.y / height)
                onPositionChanged: mouse => {
                    if (pressed)
                        root.setSaturationValue(mouse.x / width, mouse.y / height);
                }
                onClicked: saturationValueArea.forceActiveFocus()
            }

            Keys.onPressed: event => {
                const step = event.modifiers & Qt.ShiftModifier ? 0.1 : 0.02;
                switch (event.key) {
                case Qt.Key_Left:
                    root.saturation = Math.max(0, root.saturation - step);
                    break;
                case Qt.Key_Right:
                    root.saturation = Math.min(1, root.saturation + step);
                    break;
                case Qt.Key_Up:
                    root.value = Math.min(1, root.value + step);
                    break;
                case Qt.Key_Down:
                    root.value = Math.max(0, root.value - step);
                    break;
                default:
                    return;
                }
                event.accepted = true;
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                text: "Hue"
                font.family: Styling.defaultFont
                font.pixelSize: Styling.fontSize(-1)
                color: Colors.overBackground
            }

            Item { Layout.fillWidth: true }

            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                text: Math.round(root.hue) + "°"
                font.family: Styling.defaultFont
                font.pixelSize: Styling.fontSize(-1)
                color: Colors.overBackground
            }
        }

        Slider {
            id: hueSlider
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            from: 0
            to: 360
            stepSize: 1
            value: root.hue
            onMoved: root.hue = value

            background: Item {
                x: hueSlider.leftPadding
                y: hueSlider.topPadding + (hueSlider.availableHeight - height) / 2
                width: hueSlider.availableWidth
                height: 12

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "red" }
                        GradientStop { position: 0.1667; color: "magenta" }
                        GradientStop { position: 0.3333; color: "blue" }
                        GradientStop { position: 0.5; color: "cyan" }
                        GradientStop { position: 0.6667; color: "green" }
                        GradientStop { position: 0.8333; color: "yellow" }
                        GradientStop { position: 1; color: "red" }
                    }
                }
            }

            handle: StyledRect {
                x: hueSlider.leftPadding + hueSlider.visualPosition * (hueSlider.availableWidth - width)
                y: hueSlider.topPadding + (hueSlider.availableHeight - height) / 2
                width: 18
                height: 18
                variant: "common"
                radius: width / 2
                border.width: 2
                border.color: Colors.overBackground
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                text: "Alpha"
                font.family: Styling.defaultFont
                font.pixelSize: Styling.fontSize(-1)
                color: Colors.overBackground
            }

            Item { Layout.fillWidth: true }

            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                text: Math.round(root.alpha * 100) + "%"
                font.family: Styling.defaultFont
                font.pixelSize: Styling.fontSize(-1)
                color: Colors.overBackground
            }
        }

        Slider {
            id: alphaSlider
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            from: 0
            to: 1
            stepSize: 0.01
            value: root.alpha
            onMoved: root.alpha = value

            background: Item {
                x: alphaSlider.leftPadding
                y: alphaSlider.topPadding + (alphaSlider.availableHeight - height) / 2
                width: alphaSlider.availableWidth
                height: 12

                StyledRect {
                    anchors.fill: parent
                    variant: "internalbg"
                    radius: height / 2
                }

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Qt.rgba(root.selectedColor.r, root.selectedColor.g, root.selectedColor.b, 0) }
                        GradientStop { position: 1; color: Qt.rgba(root.selectedColor.r, root.selectedColor.g, root.selectedColor.b, 1) }
                    }
                }
            }

            handle: StyledRect {
                x: alphaSlider.leftPadding + alphaSlider.visualPosition * (alphaSlider.availableWidth - width)
                y: alphaSlider.topPadding + (alphaSlider.availableHeight - height) / 2
                width: 18
                height: 18
                variant: "common"
                radius: width / 2
                border.width: 2
                border.color: Colors.overBackground
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item { Layout.fillWidth: true }

            Button {
                id: cancelButton
                Layout.preferredWidth: 88
                Layout.preferredHeight: 36
                text: "Cancel"
                background: StyledRect {
                    variant: cancelButton.hovered ? "focus" : "common"
                    radius: Styling.radius(-3)
                }
                contentItem: Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: cancelButton.text
                    font.family: Styling.defaultFont
                    font.pixelSize: Styling.fontSize(-1)
                    color: Colors.overBackground
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: root.close()
            }

            Button {
                id: applyButton
                Layout.preferredWidth: 88
                Layout.preferredHeight: 36
                text: "Apply"
                background: StyledRect {
                    variant: applyButton.hovered ? "primaryfocus" : "primary"
                    radius: Styling.radius(-3)
                }
                contentItem: Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    text: applyButton.text
                    font.family: Styling.defaultFont
                    font.pixelSize: Styling.fontSize(-1)
                    font.weight: Font.Medium
                    color: Styling.srItem("overprimary")
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    root.colorSelected(root.selectedColor.toString().toUpperCase());
                    root.close();
                }
            }
        }
    }
}
