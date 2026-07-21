pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs.modules.components
import qs.modules.corners
import qs.modules.theme
import qs.modules.globals
import qs.modules.services
import qs.modules.widgets.dashboard.widgets
import qs.config

// Lock surface UI - shown on each screen when locked
WlSessionLockSurface {
    id: root

    property bool startAnim: false
    property bool authenticating: false
    property string errorMessage: ""
    property int failLockSecondsLeft: 0

    readonly property string freezeSource: LockscreenService.freezeSourceFor(root.screen ? root.screen.name : "")
    readonly property bool freezeReady: freezeBackground.status === Image.Ready

    // Opaque fallback only. The freeze frame (pre-lock desktop) sits on top of
    // this so unlock never reveals a solid Colors.background / black slab.
    color: "black"

    // Pre-lock desktop freeze. Captured with grim *before* WlSessionLock is
    // raised (see LockscreenService). Post-lock ScreencopyView only sees lock
    // surfaces, which is why the first unlock used to flash black.
    Image {
        id: freezeBackground
        anchors.fill: parent
        z: 0
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        cache: false
        smooth: true
        visible: true
        source: root.freezeSource

        property real zoomScale: startAnim ? 1.25 : 1.0

        transform: Scale {
            origin.x: freezeBackground.width / 2
            origin.y: freezeBackground.height / 2
            xScale: freezeBackground.zoomScale
            yScale: freezeBackground.zoomScale
        }

        Behavior on zoomScale {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration * 2
                easing.type: Easing.OutExpo
            }
        }
    }

    // Wallpaper + blur over the freeze. Fades in on lock, out on unlock so the
    // last lock frame is the real desktop again — not wallpaper, not black.
    // If freeze failed, keep this fully opaque through unlock.
    TintedWallpaper {
        id: wallpaperBackground
        anchors.fill: parent
        z: 1
        radius: 0
        tintEnabled: GlobalStates.wallpaperManager ? GlobalStates.wallpaperManager.tintEnabled : false

        property string lockscreenFramePath: {
            if (!GlobalStates.wallpaperManager)
                return "";
            return GlobalStates.wallpaperManager.getLockscreenFramePath(GlobalStates.wallpaperManager.currentWallpaper);
        }

        source: lockscreenFramePath ? "file://" + lockscreenFramePath : ""

        opacity: (startAnim || !root.freezeReady) ? 1 : 0
        visible: true

        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration * 2
                easing.type: Easing.OutQuint
            }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: startAnim ? 1 : 0
            blurMax: 64
        }

        property real zoomScale: startAnim ? 1.25 : 1.0
        transform: Scale {
            origin.x: wallpaperBackground.width / 2
            origin.y: wallpaperBackground.height / 2
            xScale: wallpaperBackground.zoomScale
            yScale: wallpaperBackground.zoomScale
        }

        Behavior on zoomScale {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration * 2
                easing.type: Easing.OutExpo
            }
        }
    }

    // Authentication happens on one lock surface, but every monitor needs to
    // animate back to its captured workspace before the shared session unlocks.
    Connections {
        target: GlobalStates

        function onLockscreenUnlockingChanged() {
            if (GlobalStates.lockscreenUnlocking)
                root.startAnim = false;
        }
    }

    // Overlay for dimming
    Rectangle {
        id: dimOverlay
        anchors.fill: parent
        color: "black"
        opacity: startAnim ? 0.25 : 0
        z: 3

        property real zoomScale: startAnim ? 1.1 : 1.0

        transform: Scale {
            origin.x: dimOverlay.width / 2
            origin.y: dimOverlay.height / 2
            xScale: dimOverlay.zoomScale
            yScale: dimOverlay.zoomScale
        }

        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration * 2
                easing.type: Easing.OutQuint
            }
        }

        Behavior on zoomScale {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration * 2
                easing.type: Easing.OutExpo
            }
        }
    }

    // Clock (center)
    Item {
        id: clockContainer
        anchors.centerIn: parent
        width: clockRow.width
        height: hoursText.height + (hoursText.height * 0.5)
        z: 10

        property date currentTime: new Date()

        Row {
            id: clockRow
            spacing: 0
            anchors.top: parent.top

            Text {
                id: hoursText
                text: Config.bar.use12hFormat ? (clockContainer.currentTime.getHours() % 12 || 12).toString() : Qt.formatTime(clockContainer.currentTime, "hh")
                font.family: "League Gothic"
                font.pixelSize: 240
                color: Colors.primaryFixed
                antialiasing: true
                opacity: startAnim ? 1 : 0

                property real slideOffset: startAnim ? 0 : -150

                transform: Translate {
                    y: hoursText.slideOffset
                }

                layer.enabled: true
                layer.effect: BgShadow {}

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration * 2
                        easing.type: Easing.OutExpo
                    }
                }

                Behavior on slideOffset {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration * 2
                        easing.type: Easing.OutExpo
                    }
                }
            }

            Text {
                id: minutesText
                text: Qt.formatTime(clockContainer.currentTime, "mm")
                font.family: "League Gothic"
                font.pixelSize: 240
                color: Colors.primaryFixedDim
                antialiasing: true
                anchors.verticalCenter: undefined
                anchors.top: hoursText.top
                anchors.topMargin: hoursText.height * 0.5
                opacity: startAnim ? 1 : 0

                property real slideOffset: startAnim ? 0 : 150

                transform: Translate {
                    y: minutesText.slideOffset
                }

                layer.enabled: true
                layer.effect: BgShadow {}

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration * 2
                        easing.type: Easing.OutExpo
                    }
                }

                Behavior on slideOffset {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration * 2
                        easing.type: Easing.OutExpo
                    }
                }
            }

            Text {
                id: amPmText
                text: Config.bar.use12hFormat ? Qt.formatTime(clockContainer.currentTime, "ap").toLowerCase() : ""
                font.family: "League Gothic"
                font.pixelSize: 100
                color: hoursText.color
                antialiasing: true
                anchors.top: hoursText.top
                anchors.topMargin: hoursText.height * 0.35
                visible: Config.bar.use12hFormat
                opacity: startAnim ? 1 : 0

                property real slideOffset: startAnim ? 0 : -150

                transform: Translate {
                    y: amPmText.slideOffset
                }

                layer.enabled: true
                layer.effect: BgShadow {}

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration * 2
                        easing.type: Easing.OutExpo
                    }
                }

                Behavior on slideOffset {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration * 2
                        easing.type: Easing.OutExpo
                    }
                }
            }
        }

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: clockContainer.currentTime = new Date()
        }
    }

    Item {
        id: playerContainer
        z: 10

        property bool isTopPosition: Config.lockscreen.position === "top"

        anchors {
            left: parent.left
            leftMargin: startAnim ? 32 : -(playerContainer.width + 64)
            top: isTopPosition ? parent.top : undefined
            topMargin: isTopPosition ? 32 : 0
            bottom: !isTopPosition ? parent.bottom : undefined
            bottomMargin: !isTopPosition ? 32 : 0
        }
        width: 350
        height: playerContent.height

        opacity: startAnim ? 1 : 0

        Behavior on anchors.leftMargin {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration * 2
                easing.type: Easing.OutExpo
            }
        }

        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration * 2
                easing.type: Easing.OutQuad
            }
        }

        LockPlayer {
            id: playerContent
            width: parent.width
        }
    }

    Item {
        id: passwordContainer
        z: 10

        property bool isTopPosition: Config.lockscreen.position === "top"

        anchors {
            horizontalCenter: parent.horizontalCenter
            top: isTopPosition ? parent.top : undefined
            topMargin: isTopPosition ? (startAnim ? 32 : -80) : 0
            bottom: !isTopPosition ? parent.bottom : undefined
            bottomMargin: !isTopPosition ? (startAnim ? 32 : -80) : 0
        }
        width: 350
        height: 96

        opacity: startAnim ? 1 : 0
        scale: startAnim ? 1 : 0.92

        Behavior on anchors.topMargin {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration * 2
                easing.type: Easing.OutExpo
            }
        }

        Behavior on anchors.bottomMargin {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration * 2
                easing.type: Easing.OutExpo
            }
        }

        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration * 2
                easing.type: Easing.OutQuad
            }
        }

        Behavior on scale {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration * 2
                easing.type: Easing.OutBack
                easing.overshoot: 1.2
            }
        }

        // Password input with avatar
        StyledRect {
            id: passwordInputBox
            variant: "bg"
            anchors.centerIn: parent
            width: parent.width
            height: 96
            radius: Config.roundness > 0 ? (height / 2) * (Config.roundness / 16) : 0

            property real shakeOffset: 0
            property bool showError: false

            transform: Translate {
                x: passwordInputBox.shakeOffset
            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 24
                spacing: 12

                StyledRect {
                    id: passwordFieldBg
                    width: parent.width - parent.spacing
                    height: 48
                    anchors.verticalCenter: parent.verticalCenter
                    variant: passwordInputBox.showError ? "error" : "common"
                    radius: Config.roundness > 0 ? (height / 2) * (Config.roundness / 16) : 0

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 32
                        spacing: 8

                        // User icon / Spinner
                        Text {
                            id: userIcon
                            text: authenticating ? Icons.circleNotch : Icons.user
                            font.family: Icons.font
                            font.pixelSize: 24
                            color: passwordFieldBg.item
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            Layout.alignment: Qt.AlignVCenter
                            z: 10
                            rotation: 0

                            Behavior on color {
                                enabled: Config.animDuration > 0
                                ColorAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Timer {
                                id: spinnerTimer
                                interval: 100
                                repeat: true
                                running: authenticating
                                onTriggered: {
                                    userIcon.rotation = (userIcon.rotation + 45) % 360;
                                }
                            }

                            onTextChanged: {
                                if (userIcon.text === Icons.user) {
                                    userIcon.rotation = 0;
                                }
                            }
                        }

                        // Text field
                        TextField {
                            id: passwordInput
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            placeholderText: usernameCollector.text.trim()
                            placeholderTextColor: Qt.rgba(passwordFieldBg.item.r, passwordFieldBg.item.g, passwordFieldBg.item.b, 0.5)
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(0)
                            color: passwordFieldBg.item
                            background: null
                            echoMode: TextInput.Password
                            verticalAlignment: TextInput.AlignVCenter
                            enabled: !authenticating

                            Behavior on color {
                                enabled: Config.animDuration > 0
                                ColorAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Behavior on placeholderTextColor {
                                enabled: Config.animDuration > 0
                                ColorAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutQuad
                                }
                            }

                            onAccepted: {
                                if (passwordInput.text.trim() === "")
                                    return;
                                authPasswordHolder.password = passwordInput.text;
                                passwordInput.text = "";

                                authenticating = true;
                                errorMessage = "";
                                pamAuth.start();
                            }
                        }
                    }
                }
            }

            SequentialAnimation {
                id: wrongPasswordAnim
                ScriptAction {
                    script: {
                        passwordInputBox.showError = true;
                    }
                }
                NumberAnimation {
                    target: passwordInputBox
                    property: "shakeOffset"
                    to: 10
                    duration: 50
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    target: passwordInputBox
                    property: "shakeOffset"
                    to: -10
                    duration: 100
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    target: passwordInputBox
                    property: "shakeOffset"
                    to: 10
                    duration: 100
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    target: passwordInputBox
                    property: "shakeOffset"
                    to: 0
                    duration: 50
                    easing.type: Easing.InOutQuad
                }
                ScriptAction {
                    script: {
                        passwordInput.text = "";
                        authenticating = false;
                        passwordInputBox.showError = false;
                    }
                }
            }
        }
    }

    // Timer to unlock after exit animation. Handoff overlay bridges the
    // compositor gap between lock-surface destruction and live desktop.
    Timer {
        id: unlockTimer
        interval: Math.max(Config.animDuration * 2, 1)
        onTriggered: {
            LockscreenService.beginUnlockHandoff();
        }
    }

    // Processes for user info
    Process {
        id: usernameProc
        command: ["whoami"]
        running: true

        stdout: StdioCollector {
            id: usernameCollector
            waitForEnd: true
        }
    }

    Process {
        id: hostnameProc
        command: ["hostname"]
        running: true

        stdout: StdioCollector {
            id: hostnameCollector
            waitForEnd: true
        }
    }

    // Holder temporal para la contraseña durante autenticación
    QtObject {
        id: authPasswordHolder
        property string password: ""
    }

    // Proceso para verificar tiempo de faillock
    Process {
        id: failLockCheck
        command: ["bash", "-c", `faillock --user '${usernameCollector.text.trim()}' 2>/dev/null | grep -oP 'left \\K[0-9]+' | head -1`]
        running: false

        stdout: StdioCollector {
            id: failLockCollector

            onStreamFinished: {
                const output = text.trim();
                const seconds = parseInt(output);

                if (!isNaN(seconds) && seconds > 0) {
                    failLockSecondsLeft = seconds;
                    failLockCountdown.start();
                } else {
                    failLockSecondsLeft = 0;
                }
            }
        }
    }

    // Timer para actualizar el countdown de faillock
    Timer {
        id: failLockCountdown
        interval: 1000
        repeat: true
        running: false

        onTriggered: {
            if (failLockSecondsLeft > 0) {
                failLockSecondsLeft--;
            } else {
                stop();
                errorMessage = "";
            }
        }
    }

    // PAM authentication process
    PamContext {
        id: pamAuth
        // Use custom PAM config for lockscreen authentication
        configDirectory: Qt.resolvedUrl("../../config/pam").toString().replace("file://", "")
        config: "password.conf"

        onPamMessage: {
            console.log("PAM Message:", this.message, "Type:", this.messageType, "Required:", this.responseRequired);
            if (this.responseRequired) {
                // pam_unix asks for password, respond with stored password
                this.respond(authPasswordHolder.password);
            }
        }

        onCompleted: result => {
            // Limpiar contraseña
            authPasswordHolder.password = "";

            if (result === PamResult.Success) {
                // Autenticación exitosa - trigger exit animation
                GlobalStates.lockscreenUnlocking = true;
                root.startAnim = false;

                // Wait for exit animation, then unlock
                unlockTimer.start();

                errorMessage = "";
                authenticating = false;
            } else {
                errorMessage = "Authentication failed";
                console.warn("PAM auth failed with result:", result);
                if (Config.animDuration > 0) {
                    wrongPasswordAnim.start();
                }
            }
        }
    }

    // Initialize when component is created (when lock becomes active).
    // Freeze was already captured pre-lock; just start the entry animation.
    Component.onCompleted: {
        startAnim = true;
        passwordInput.forceActiveFocus();
    }
}
