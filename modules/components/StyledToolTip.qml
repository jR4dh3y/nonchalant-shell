pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import qs.modules.theme
import qs.modules.components

ToolTip {
    id: root
    property string tooltipText: ""
    property string description: ""
    property bool show: false
    // Drag-value tips can follow a pointer grab outside the owner.
    property bool requireHover: true

    // Popup content is reparented to the window overlay, so owner state must gate it.
    function ownerAvailable(): bool {
        let owner = root.parent;
        if (!owner)
            return false;
        while (owner) {
            if (!owner.visible || !owner.enabled || owner.opacity <= 0)
                return false;
            owner = owner.parent;
        }
        return true;
    }

    HoverHandler {
        id: ownerHover
        parent: root.parent
        enabled: root.requireHover && (parent?.visible ?? false) && (parent?.enabled ?? false)
    }

    text: tooltipText
    delay: 1000
    timeout: -1
    visible: root.show && root.ownerAvailable() && (!root.requireHover || (ownerHover?.hovered ?? false))
        && root.tooltipText.length > 0

    background: StyledRect {
        variant: "popup"
        radius: Styling.radius(-8)
    }

    contentItem: ColumnLayout {
        spacing: 0

        StyledText {
            text: root.tooltipText
            color: Colors.overBackground
            font.pixelSize: Config.theme.fontSize
            font.weight: Font.Bold
            font.family: Config.theme.font
        }

        StyledText {
            text: root.description
            visible: root.description.length > 0
            color: Colors.overBackground
            font.pixelSize: Config.theme.fontSize - 2
            font.family: Config.theme.font
        }
    }
}
