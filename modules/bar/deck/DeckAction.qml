pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import qs.modules.components
import qs.modules.theme

Button {
    id: root
    enum Kind { Plain, Tab, Icon, Action, Tile }
    property int kind: DeckAction.Plain
    property string glyph: ""
    property string label: ""
    // Trailing live value: counts, levels, or state that make a row worth visiting.
    property string detail: ""
    property string description: label
    property bool selected: false
    // Selected accent actions fill with the primary color, like active toggles.
    property bool accent: false
    property bool quiet: false
    wheelEnabled: false
    property string imageSource: ""
    property int textElide: Text.ElideRight
    property real maximumLabelWidth: Styling.fontSize(0) * 14
    property real controlHeight: Styling.fontSize(0) * 2
    property int labelAlignment: kind === DeckAction.Action || tile ? Text.AlignHCenter : Text.AlignLeft
    readonly property bool tile: kind === DeckAction.Tile
    readonly property bool filled: selected && accent
    // Tabs draw no selected surface: the rail's sliding indicator sits behind them.
    readonly property color ink: (kind === DeckAction.Tab || filled) && selected ? Styling.srItem("primary")
        : selected || visualFocus ? surface.item : Colors.overBackground
    signal secondaryClicked()
    signal middleClicked()
    signal scrolled(real delta)

    implicitWidth: Math.max(controlHeight, contents.implicitWidth + padding * 2)
    implicitHeight: tile ? contents.implicitHeight + padding * 2 : controlHeight
    padding: kind === DeckAction.Icon ? 0 : Styling.fontSize(0) * 0.5
    hoverEnabled: true
    Accessible.name: description
    scale: pressed ? 0.96 : 1
    PressBehavior on scale { pressed: root.pressed }
    opacity: enabled ? 1 : 0.45

    background: StyledRect {
        id: surface
        variant: root.filled ? "primary" : "focus"
        radius: root.kind === DeckAction.Icon ? height / 2 : Styling.radius(-6)
        enableBorder: root.visualFocus
        backgroundOpacity: root.kind === DeckAction.Tab && root.selected ? 0
            : root.selected || root.visualFocus || root.kind === DeckAction.Action ? 1 : 0
        Behavior on backgroundOpacity { enabled: DeckMotion.enabled; NumberAnimation { duration: DeckMotion.closeDuration } }
        HoverTint { hovered: root.hovered; pressed: root.pressed; hoverOpacity: 0.08; pressedOpacity: 0.16 }
    }
    contentItem: GridLayout {
        id: contents
        columns: root.tile ? 1 : 4
        columnSpacing: Styling.fontSize(0) * 0.5
        rowSpacing: Styling.fontSize(0) * 0.4
        Image {
            id: artwork
            visible: root.imageSource !== "" && status !== Image.Error
            source: root.imageSource
            Layout.fillWidth: root.tile
            Layout.preferredWidth: root.tile ? -1 : Styling.fontSize(4)
            Layout.preferredHeight: root.tile ? Math.max(0, root.width - root.padding * 2) * 0.5625 : Styling.fontSize(4)
            sourceSize.width: root.tile ? Styling.fontSize(0) * 24 : Styling.fontSize(4) * 2
            sourceSize.height: root.tile ? Styling.fontSize(0) * 13.5 : Styling.fontSize(4) * 2
            fillMode: root.tile ? Image.PreserveAspectCrop : Image.PreserveAspectFit
            asynchronous: root.tile
            clip: root.tile
        }
        StyledText {
            visible: (root.imageSource === "" && root.glyph !== "") || artwork.status === Image.Error
            text: root.glyph || Icons.apps
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(3)
            color: root.ink
            // A fixed glyph column keeps labels aligned down a list.
            Layout.preferredWidth: Styling.fontSize(3) * 1.15
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignCenter
        }
        StyledText {
            visible: root.label !== ""
            text: root.label
            Layout.fillWidth: true
            Layout.maximumWidth: root.maximumLabelWidth
            elide: root.textElide
            font.pixelSize: Styling.fontSize(root.quiet || root.tile ? -3 : -1)
            font.weight: root.selected ? Font.DemiBold : Font.Medium
            color: root.ink
            horizontalAlignment: root.labelAlignment
            verticalAlignment: Text.AlignVCenter
        }
        StyledText {
            objectName: root.objectName ? root.objectName + "-detail" : ""
            visible: root.detail !== ""
            text: root.detail
            font.pixelSize: Styling.fontSize(-3)
            font.weight: Font.DemiBold
            color: root.selected || root.visualFocus ? root.ink : Colors.overSurfaceVariant
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        }
    }
    TapHandler { acceptedButtons: Qt.RightButton; onTapped: root.secondaryClicked() }
    TapHandler { acceptedButtons: Qt.MiddleButton; onTapped: root.middleClicked() }
    WheelHandler {
        enabled: root.wheelEnabled
        onWheel: event => {
            root.scrolled(event.angleDelta.y || event.angleDelta.x);
            event.accepted = true;
        }
    }
    StyledToolTip { show: root.hovered && (root.label === "" || root.description !== root.label); tooltipText: root.description }
}
