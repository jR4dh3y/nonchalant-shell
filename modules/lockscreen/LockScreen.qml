pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs.modules.components
import qs.modules.theme
import qs.modules.globals
import qs.modules.services
import qs.modules.widgets.dashboard.widgets
import qs.config

// Lock surface UI - shown on each screen when locked
WlSessionLockSurface {
    id: root

    // WlSessionLock.secure is set only after niri has covered every output.
    // The shell passes it in so entry animation never races surface mapping.
    property bool lockSecure: false
    property bool startAnim: false
    property bool entryStarted: false
    property bool unlocking: false
    property bool authenticating: false
    property string errorMessage: ""
    property int failLockSecondsLeft: 0

    readonly property int unlockAnimMs: Math.max(1, (Config.animDuration !== undefined ? Config.animDuration : 0) * 2)

    // An opaque surface is important here. Transparent session-lock surfaces
    // can briefly show an undefined compositor buffer while they map.
    color: Colors.background

    function beginEntry() {
        if (entryStarted || !lockSecure || unlocking)
            return;

        entryStarted = true;
        // Wait until the captured desktop frame is actually presented before
        // animating in, so the lock-in transition starts from the real desktop
        // instead of a solid backdrop. entryTimer polls with a fallback
        // timeout in case the capture never lands.
        entryTimer.elapsed = 0;
        entryTimer.start();
    }

    onLockSecureChanged: beginEntry()

    // PAM can complete on any output. All lock surfaces must run their
    // foreground exit at the same time before the shared lock is released.
    Connections {
        target: GlobalStates

        function onLockscreenUnlockingChanged() {
            if (GlobalStates.lockscreenUnlocking)
                root.startAnim = false;
        }
    }

    // Capture one native compositor frame as soon as this surface exists. It
    // remains hidden behind the lock backdrop until PAM succeeds, when it
    // becomes the desktop-reveal layer for the exit animation.
    ScreencopyView {
        id: desktopFrame
        anchors.fill: parent
        z: 0
        captureSource: root.screen
        live: false
        paintCursor: false
        visible: true
    }

    readonly property bool revealDesktop: GlobalStates.lockscreenUnlocking && desktopFrame.hasContent

    // The wallpaper stays static on lock, while this inexpensive themed scrim
    // provides the lock-in motion. On entry the wallpaper stays hidden until
    // startAnim so the captured desktop frame below is visible first (seamless
    // lock-in); on unlock it fades out over that same captured frame.
    TintedWallpaper {
        id: wallpaperBackground
        anchors.fill: parent
        z: 1
        radius: 0
        tintEnabled: GlobalStates.wallpaperManager ? GlobalStates.wallpaperManager.tintEnabled : false

        property string lockscreenFramePath: {
            const manager = GlobalStates.wallpaperManager;
            if (!manager)
                return "";
            const perScreen = manager.perScreenWallpapers || {};
            const wallpaper = perScreen[root.screen ? root.screen.name : ""] || manager.currentWallpaper;
            return manager.getLockscreenFramePath(wallpaper);
        }

        source: lockscreenFramePath ? "file://" + lockscreenFramePath : ""
        visible: source !== ""
        opacity: GlobalStates.lockscreenUnlocking
            ? (root.revealDesktop ? 0 : 1)
            : (root.startAnim || !desktopFrame.hasContent ? 1 : 0)

        Behavior on opacity {
            // Snap to the desktop frame during entry; animate only the
            // startAnim crossfade and the unlock reveal.
            enabled: Config.animDuration > 0
                && (GlobalStates.lockscreenUnlocking || root.startAnim)
            NumberAnimation {
                duration: root.unlockAnimMs
                easing.type: Easing.OutQuint
            }
        }
    }

    // The themed scrim fades in over the captured desktop once the entry
    // animation starts. Until the desktop capture lands it stays opaque so an
    // undefined compositor buffer can never leak through. On unlock it keeps
    // the existing desktop-reveal fade.
    Rectangle {
        id: dimOverlay
        anchors.fill: parent
        color: Colors.background
        opacity: GlobalStates.lockscreenUnlocking
            ? (root.revealDesktop ? 0 : 0.55)
            : (root.startAnim ? 0.55 : (desktopFrame.hasContent ? 0 : 1))
        z: 2

        Behavior on opacity {
            enabled: Config.animDuration > 0
                && (GlobalStates.lockscreenUnlocking || root.startAnim)
            NumberAnimation {
                duration: root.unlockAnimMs
                easing.type: Easing.OutQuint
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
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
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

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.unlockAnimMs
                        easing.type: Easing.OutExpo
                    }
                }

                Behavior on slideOffset {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.unlockAnimMs
                        easing.type: Easing.OutExpo
                    }
                }
            }

            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
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

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.unlockAnimMs
                        easing.type: Easing.OutExpo
                    }
                }

                Behavior on slideOffset {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.unlockAnimMs
                        easing.type: Easing.OutExpo
                    }
                }
            }

            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
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

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.unlockAnimMs
                        easing.type: Easing.OutExpo
                    }
                }

                Behavior on slideOffset {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: root.unlockAnimMs
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
                duration: root.unlockAnimMs
                easing.type: Easing.OutExpo
            }
        }

        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: root.unlockAnimMs
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
        height: 48

        opacity: startAnim ? 1 : 0

        Behavior on anchors.topMargin {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: root.unlockAnimMs
                easing.type: Easing.OutExpo
            }
        }

        Behavior on anchors.bottomMargin {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: root.unlockAnimMs
                easing.type: Easing.OutExpo
            }
        }

        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: root.unlockAnimMs
                easing.type: Easing.OutQuad
            }
        }

        // Single pill input only — no outer "bg" frame around it.
        StyledRect {
            id: passwordInputBox
            variant: showError ? "error" : "common"
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            radius: Config.roundness > 0 ? (height / 2) * (Config.roundness / 16) : 0

            property real shakeOffset: 0
            property bool showError: false

            transform: Translate {
                x: passwordInputBox.shakeOffset
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 8

                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    id: userIcon
                    text: authenticating ? Icons.circleNotch : Icons.user
                    font.family: Icons.font
                    font.pixelSize: 24
                    color: passwordInputBox.item
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
                        if (userIcon.text === Icons.user)
                            userIcon.rotation = 0;
                    }
                }

                TextField {
                    id: passwordInput
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    placeholderText: usernameCollector.text.trim()
                    placeholderTextColor: Qt.rgba(passwordInputBox.item.r, passwordInputBox.item.g, passwordInputBox.item.b, 0.5)
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    color: passwordInputBox.item
                    background: null
                    echoMode: TextInput.Password
                    verticalAlignment: TextInput.AlignVCenter
                    enabled: !authenticating && !root.unlocking

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

    // The opaque backdrop stays in place until the lock protocol tears down;
    // only the chrome exits. This avoids blending a stale capture into a
    // desktop that niri is concurrently restoring.
    Timer {
        id: unlockTimer
        interval: root.unlockAnimMs
        repeat: false
        onTriggered: LockscreenService.finishUnlock()
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
                // Exit the foreground only, then release the native session
                // lock. This path is intentionally unavailable through IPC.
                errorMessage = "";
                authenticating = false;
                if (root.unlocking)
                    return;
                root.unlocking = true;
                GlobalStates.lockscreenUnlocking = true;
                root.startAnim = false;
                if (Config.animDuration > 0)
                    unlockTimer.restart();
                else
                    LockscreenService.finishUnlock();
            } else {
                errorMessage = "Authentication failed";
                console.warn("PAM auth failed with result:", result);
                if (Config.animDuration > 0) {
                    wrongPasswordAnim.start();
                } else {
                    // Without animations, the old flow left the input disabled
                    // after one failed attempt.
                    passwordInput.text = "";
                    authenticating = false;
                    passwordInputBox.showError = true;
                    errorResetTimer.restart();
                }
            }
        }
    }

    Timer {
        id: errorResetTimer
        interval: 400
        repeat: false
        onTriggered: passwordInputBox.showError = false
    }

    Timer {
        id: entryTimer
        interval: 16
        repeat: true
        property int elapsed: 0
        onTriggered: {
            elapsed += interval;
            // Start once the desktop capture has been presented for at least
            // two frames so the lock-in animation is not skipped; fall back
            // after 250ms if the capture never produces content.
            if ((desktopFrame.hasContent && elapsed >= 32) || elapsed >= 250) {
                stop();
                if (!root.unlocking && root.lockSecure) {
                    root.startAnim = true;
                    passwordInput.forceActiveFocus();
                }
            }
        }
    }

    Component.onCompleted: {
        desktopFrame.captureFrame();
        beginEntry();
    }
}
