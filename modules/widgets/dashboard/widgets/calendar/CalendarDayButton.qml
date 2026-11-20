import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.config

Rectangle {
    id: button
    readonly property ShellPalette shellPalette: DisplayPalettes.forItem(button)

    required property string day
    required property int isToday
    property bool bold: false
    property bool isCurrentDayOfWeek: false

    Layout.fillWidth: true
    Layout.fillHeight: false
    Layout.preferredWidth: 28
    Layout.preferredHeight: 28

    color: "transparent"
    radius: Styling.radius(-2)

    StyledRect {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height)
        height: width
        // Today is the selected day: primaryContainer with its paired ink.
        variant: (isToday === 1) ? "primarycontainer" : "transparent"
        radius: parent.radius

        Text {
            anchors.fill: parent
            text: day
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            // The default distance-field renderer gives small bold glyphs a
            // soft halo, especially against light surfaces. These labels are
            // static, so native hinted rendering produces crisper edges.
            renderType: Text.NativeRendering
            font.weight: Font.Bold
            font.hintingPreference: Font.PreferFullHinting
            font.pixelSize: Styling.fontSize(-2)
            font.family: Config.defaultFont
            color: {
                if (isToday === 1)
                    return Styling.srItem("primarycontainer", button.shellPalette);
                if (bold) {
                    return isCurrentDayOfWeek ? button.shellPalette.overBackground : button.shellPalette.overSurfaceVariant;
                }
                if (isToday === 0)
                    return button.shellPalette.overSurface;
                // Other-month days stay readable: subdued ink, no extra fade.
                return button.shellPalette.overSurfaceVariant;
            }

            Behavior on color {
                enabled: Config.animDuration > 0
                ColorAnimation {
                    duration: 150
                }
            }
        }
    }
}
