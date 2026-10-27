pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.modules.components
import qs.modules.theme

// Thin horizontal scrubber for continuous positions such as playback.
Slider {
    id: root
    required property string label
    property bool available: true
    signal edited(real value)
    implicitHeight: Styling.fontSize(0) * 1.4
    from: 0
    to: 1
    stepSize: 0.001
    enabled: available
    Accessible.name: label
    onMoved: root.edited(value)
    background: StyledRect {
        x: root.leftPadding
        y: (root.height - height) / 2
        width: root.availableWidth
        height: Math.max(2, Styling.fontSize(0) / 4)
        radius: height / 2
        variant: "internalbg"
        enableBorder: false
        StyledRect {
            width: parent.width * root.visualPosition
            height: parent.height
            radius: height / 2
            variant: "focus"
            color: Colors.primary
            enableBorder: false
        }
    }
    handle: StyledRect {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: (root.height - height) / 2
        width: Styling.fontSize(0) * (root.pressed || root.hovered ? 0.8 : 0.5)
        height: width
        radius: width / 2
        variant: "focus"
        color: Colors.overBackground
        enableBorder: root.visualFocus
    }
}
