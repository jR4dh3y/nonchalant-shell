pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.components
import qs.modules.theme

// One self-contained component of a Deck page. Cards sit apart on the drawer
// surface, carry their own optional heading and trailing controls, and land in
// sequence when their page opens.
Pane {
    id: root
    default property alias cardData: body.data
    property alias headerData: trailing.data
    property string title: ""
    property string glyph: ""
    // Position in the page's entrance sequence; negative skips the entrance.
    property int order: 0
    property string variant: "pane"
    spacing: Styling.fontSize(0) * 0.5
    padding: Styling.fontSize(0) * 0.7
    opacity: order < 0 || !DeckMotion.enabled ? 1 : 0
    transform: Translate { id: lift; y: root.order < 0 || !DeckMotion.enabled ? 0 : Styling.fontSize(0) * DeckMotion.cardTravel }

    background: StyledRect {
        variant: root.variant
        radius: Styling.radius(-2)
        enableBorder: false
    }
    contentItem: ColumnLayout {
        spacing: root.spacing
        RowLayout {
            Layout.fillWidth: true
            visible: root.title !== "" || trailing.children.length > 0
            spacing: Styling.fontSize(0) * 0.4
            StyledText {
                visible: root.glyph !== ""
                text: root.glyph
                font.family: Icons.font
                font.pixelSize: Styling.fontSize(0)
                color: Colors.overSurfaceVariant
            }
            StyledText {
                Layout.fillWidth: true
                text: root.title
                elide: Text.ElideRight
                color: Colors.overSurfaceVariant
                font.pixelSize: Styling.fontSize(-2)
                font.weight: Font.DemiBold
            }
            RowLayout {
                id: trailing
                spacing: Styling.fontSize(0) * 0.2
            }
        }
        ColumnLayout {
            id: body
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.spacing
        }
    }

    ParallelAnimation {
        id: entrance
        NumberAnimation { target: root; property: "opacity"; to: 1; duration: DeckMotion.cardDuration; easing.type: DeckMotion.travelEasing }
        NumberAnimation { target: lift; property: "y"; to: 0; duration: DeckMotion.cardDuration; easing.type: DeckMotion.detentEasing; easing.overshoot: DeckMotion.detentOvershoot }
    }
    Timer {
        id: entranceDelay
        interval: Math.max(1, DeckMotion.delayFor(root.order))
        onTriggered: entrance.start()
    }
    Component.onCompleted: if (root.order >= 0 && DeckMotion.enabled) entranceDelay.start()
}
