import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.modules.theme
import qs.config

Item {
    id: root
    property var appIcon: ""
    property string appName: ""
    property var summary: ""
    property var urgency: NotificationUrgency.Normal
    property var image: ""
    property real scale: 1
    property real size: 48 * scale
    property real appIconScale: scale
    property real smallAppIconScale: 0.4
    property real appIconSize: size * appIconScale
    property real smallAppIconSize: size * smallAppIconScale
    property bool usingAppIconFallback: false
    property bool notificationImageFailed: false
    property bool appIconFailed: false

    onImageChanged: notificationImageFailed = false
    onAppIconChanged: appIconFailed = false

    function resolveIconSource(icon) {
        if (!icon)
            return "";
        const value = String(icon);
        // Quickshell's transient qsimage provider points at an object owned
        // by another shell instance.  Once that instance exits it renders as
        // a magenta/missing texture, so treat it as absent and use our icon
        // fallback instead.
        if (value.startsWith("image://qsimage/") || value.startsWith("image://qsimagetheme/"))
            return "";
        // Chromium/browser scoped temp icons die after the notification
        // process cleans up; skip them so Image does not spam Cannot open.
        if (value.includes("/tmp/org.chromium.") || value.includes("/tmp/.org.chromium.") || value.includes("scoped_dir"))
            return "";
        if (value.startsWith("file://") || value.startsWith("data:") || value.startsWith("image://"))
            return value;
        if (value.startsWith("/"))
            return "file://" + value;
        return "image://icon/" + value;
    }

    readonly property string resolvedImage: resolveIconSource(root.image)
    readonly property string resolvedAppIcon: resolveIconSource(root.appIcon)

    implicitWidth: size
    implicitHeight: size
    property real radius: Styling.radius(-8)

    // Contenedor principal con recorte (Clipping)
    ClippingRectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: root.urgency == NotificationUrgency.Critical ? Colors.shadow : Colors.surfaceBright
            border.width: root.urgency == NotificationUrgency.Critical ? 2 : 0
            border.color: root.urgency == NotificationUrgency.Critical ? Colors.criticalRed : "transparent"
            radius: root.radius
            visible: ((root.resolvedImage == "" || root.notificationImageFailed) && (root.resolvedAppIcon == "" || root.appIconFailed))
                || (appIconLoader.active && root.appIconFailed)

            Text {
                anchors.centerIn: parent
                text: {
                    if (root.urgency == NotificationUrgency.Critical) return Icons.alert;
                    if (root.appName === "Pomodoro") return Icons.timer;
                    return Icons.bell;
                }
                font.family: Icons.font
                font.pixelSize: root.size * 0.5
                color: root.urgency == NotificationUrgency.Critical ? Colors.criticalText : Styling.srItem("overprimary")

                SequentialAnimation on opacity {
                    running: root.urgency == NotificationUrgency.Critical
                    loops: Animation.Infinite
                    NumberAnimation {
                        from: 1.0
                        to: 0.5
                        duration: 800
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        from: 0.5
                        to: 1.0
                        duration: 800
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }

        Loader {
            id: appIconLoader
            active: (root.resolvedImage == "" || root.notificationImageFailed) && root.resolvedAppIcon != "" && !root.appIconFailed
            anchors.fill: parent
            visible: item && item.status === Image.Ready
            sourceComponent: Image {
                mipmap: true
                id: appIconImage
                anchors.fill: parent
                source: root.resolvedAppIcon
                fillMode: Image.PreserveAspectCrop
                smooth: true
                onStatusChanged: {
                    if (status === Image.Error)
                        root.appIconFailed = true;
                }
            }
        }

        // Mostrar imagen de notificación si existe
        Loader {
            id: notifImageLoader
            active: root.resolvedImage != "" && !root.notificationImageFailed
            anchors.fill: parent
            sourceComponent: Item {
                anchors.fill: parent
                clip: true

                Rectangle {
                    anchors.fill: parent
                    radius: root.radius
                    color: "transparent"

                    Image {
                        mipmap: true
                        id: notifImage
                        anchors.fill: parent
                        source: root.resolvedImage
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        onStatusChanged: {
                            if (status === Image.Error)
                                root.notificationImageFailed = true;
                        }
                    }
                }
            }
        }
    }

    // App icon pequeño superpuesto si hay imagen
    Loader {
        id: notifImageAppIconLoader
        active: root.resolvedImage != "" && !root.notificationImageFailed && root.resolvedAppIcon != "" && !root.usingAppIconFallback
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: root.smallAppIconSize
        height: root.smallAppIconSize
        sourceComponent: Rectangle {
            color: "transparent"
            Image {
                mipmap: true
                anchors.fill: parent
                source: root.resolvedAppIcon
                fillMode: Image.PreserveAspectCrop
                smooth: true
                onStatusChanged: {
                    if (status === Image.Error)
                        root.appIconFailed = true;
                }
            }
        }
    }
}
