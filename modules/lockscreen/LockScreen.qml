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

    // [lockdbg] temporary instrumentation
    property real lockdbgT0: 0
    function lockdbg(msg) {
        const now = Date.now();
        if (root.lockdbgT0 === 0)
            root.lockdbgT0 = now;
        console.log("[lockdbg]", Math.round(now - root.lockdbgT0) + "ms", "screen:" + (root.screen ? root.screen.name : "?"), msg);
    }

    function beginEntry() {
        if (entryStarted || !lockSecure || unlocking)
            return;

        entryStarted = true;
        root.errorMessage = "";
        root.lockdbg("beginEntry (secure)");
        // Wait until the wallpaper (the frame-1 base layer) is actually
        // presented before animating in, so the lock-in transition starts from
        // a fully rendered lock backdrop. entryTimer polls with a fallback
        // timeout in case the image never becomes ready.
        entryTimer.elapsed = 0;
        entryTimer.start();
    }

    onLockSecureChanged: {
        root.lockdbg("lockSecure=" + lockSecure);
        beginEntry();
    }

    // Pre-lock desktop capture ("lockshot") for this screen, taken by the
    // wallpaper window BEFORE the lock request. Frame-1 of this surface shows
    // it: identical pixels to what the user was seeing, so niri's output
    // switch to the locked frame is invisible - no wallpaper flash.
    readonly property string lockshotPath: GlobalStates.lockshotPaths[root.screen ? root.screen.name : ""] || ""
    readonly property bool shotReady: lockshotPath !== "" && shotImage.ready

    onWallpaperReadyChanged: root.lockdbg("wallpaperReady=" + wallpaperReady)

    onStartAnimChanged: root.lockdbg("startAnim=" + startAnim)

    // PAM can complete on any output. All lock surfaces must run their
    // foreground exit at the same time before the shared lock is released.
    Connections {
        target: GlobalStates

        function onLockscreenUnlockingChanged() {
            if (GlobalStates.lockscreenUnlocking)
                root.startAnim = false;
        }
    }

    readonly property bool revealDesktop: GlobalStates.lockscreenUnlocking && shotReady

    // The wallpaper is the frame-1 fallback base layer of the lock surface. It
    // must be ready at first commit: niri switches the output to the locked
    // frame as soon as this surface commits. The wallpaper window keeps the
    // same image warm in the pixmap cache (see lockscreenFramePreloader), so
    // this is a cache hit.
    readonly property bool wallpaperReady: wallpaperBackground.source === "" || wallpaperBackground.ready

    // Frame-1 base layer: the pre-lock desktop shot. Same source + sourceSize
    // as the wallpaper window's lockshot preloader, so this is a cache hit.
    Image {
        id: shotImage
        anchors.fill: parent
        z: 0
        cache: true
        mipmap: true
        smooth: true
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        visible: lockshotPath !== ""
        source: lockshotPath !== "" ? "file://" + lockshotPath : ""
        sourceSize.width: root.width
        sourceSize.height: root.height
    }

    // Entry choreography:
    // - The desktop shot was captured BEFORE the lock request (see Wallpaper.qml
    //   lockshot prep), so frame 1 is the actual desktop the user was looking
    //   at - niri's output switch to the locked frame is seamless.
    // - The dim scrim hides the surface until a base layer (shot or wallpaper)
    //   is ready. If only the wallpaper is available, it is revealed dimmed,
    //   never at full brightness, so the clean wallpaper can never flash.
    // - startAnim then crossfades the shot into the dimmed wallpaper while
    //   the clock / password slide in.

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
        // Pre-startAnim the lockshot (if present) is the base; the wallpaper
        // crossfades in with the entry animation so the steady-state backdrop
        // is the wallpaper. On unlock it fades back out over the shot for the
        // desktop reveal. Without a shot it stays visible as the fallback.
        opacity: GlobalStates.lockscreenUnlocking
            ? (root.revealDesktop ? 0 : 1)
            : (root.startAnim || !root.shotReady ? 1 : 0)

        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: root.unlockAnimMs
                easing.type: Easing.OutQuint
            }
        }
    }

    // The themed scrim hides the surface until a base layer (capture or
    // wallpaper) is ready, then fades in over it with the entry animation. On
    // unlock it keeps the existing desktop-reveal fade.
    Rectangle {
        id: dimOverlay
        anchors.fill: parent
        color: Colors.background
        // The scrim only clears for the lockshot (identical pixels to the
        // pre-lock desktop - seamless). Without a shot it stays opaque until
        // startAnim dims the wallpaper in, so the clean wallpaper can never
        // flash at full brightness.
        opacity: GlobalStates.lockscreenUnlocking
            ? (root.revealDesktop ? 0 : 0.55)
            : (root.startAnim ? 0.55 : (root.shotReady ? 0 : 1))
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
            // Start once a base layer (lockshot or wallpaper) has been up for
            // at least two frames so the lock-in animation is not skipped;
            // fall back after 250ms if neither ever becomes ready.
            const baseReady = root.shotReady || root.wallpaperReady;
            if ((baseReady && elapsed >= 32) || elapsed >= 250) {
                root.lockdbg("entry trigger: shotReady=" + root.shotReady + " wallpaperReady=" + root.wallpaperReady + " elapsed=" + elapsed + (elapsed >= 250 && !baseReady ? " (FALLBACK)" : ""));
                stop();
                if (!root.unlocking && root.lockSecure) {
                    root.startAnim = true;
                    passwordInput.forceActiveFocus();
                }
            }
        }
    }

    Component.onCompleted: {
        root.lockdbgT0 = LockscreenService.lockdbgT0;
        root.lockdbg("surface completed, shot=" + root.lockshotPath + " framePath=" + wallpaperBackground.lockscreenFramePath);
        beginEntry();
    }
}
