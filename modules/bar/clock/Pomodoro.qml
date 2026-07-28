pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.modules.theme
import qs.modules.components
import qs.config

Item {
    id: root
    implicitHeight: content.implicitHeight + 24
    width: 300

    // --- State & Logic ---
    property bool isRunning: false
    property bool alarmActive: false
    
    // --- IPC & Notifications ---
    IpcHandler {
        target: "pomodoro"
        function check() {
            root.requestPopupOpen();
        }
        function stop() {
            root.stopAlarm();
            root.isRunning = false;
        }
    }

    signal requestPopupOpen()

    function focusInput() {
        minIn.forceActiveFocus();
        minIn.selectAll();
    }

    Process {
        id: notifyProcess
        stdout: StdioCollector { id: notifyStdout }
        onExited: (exitCode) => {
            let action = notifyStdout.text.trim();
            if (action === "check") {
                root.requestPopupOpen();
            } else if (action === "stop") {
                root.stopAlarm();
                root.isRunning = false;
            }
        }
    }
    
    // Internal countdown state
    property int timeLeft: Config.system.pomodoro.workTime
    property int totalTime: Config.system.pomodoro.workTime
    property real visualProgress: 1.0

    readonly property bool isResuming: !isRunning && !alarmActive
        && timeLeft > 0 && timeLeft < totalTime

    function toggleTimer() {
        if (alarmActive) {
            stopAlarm();
            resetTimer();
            return;
        }
        
        if (!isRunning) {
            if (timeLeft === totalTime) {
                totalTime = timeLeft;
            }
            isRunning = true;
        } else {
            isRunning = false;
        }
    }

    // Smooth progress animation
    NumberAnimation {
        id: progressAnim
        target: root
        property: "visualProgress"
        from: root.totalTime > 0 ? root.timeLeft / root.totalTime : 0
        to: 0
        duration: root.timeLeft * 1000
        running: root.isRunning && root.timeLeft > 0
    }

    // Reset visual progress when not running and time is adjusted
    onTimeLeftChanged: {
        if (!isRunning && !alarmActive) {
            visualProgress = totalTime > 0 ? timeLeft / totalTime : 0;
        }
    }

    function resetTimer() {
        stopAlarm();
        isRunning = false;
        timeLeft = Math.max(1, totalTime);
        visualProgress = 1.0;
    }

    function startAlarm() {
        isRunning = false;
        alarmActive = true;
        visualProgress = 0;
        
        if (alarmSoundLoader.item) {
            alarmSoundLoader.item.loops = 255;
            alarmSoundLoader.active = true;
            alarmSoundLoader.item.play();
        } else {
            alarmSoundLoader.active = true;
        }

        let cmd = [
            "notify-send",
            "-a", "Timer",
            "Timer",
            "Timer finished!"
        ];
        
        // Add wait and actions ONLY if notify-send supports them (most modern ones do)
        // Note: Removing --wait can help if the process hangs
        cmd.splice(1, 0, "--wait", "--action=check=Check", "--action=stop=Stop");
        
        notifyProcess.command = cmd;
        notifyProcess.running = true;
    }

    function stopAlarm() {
        if (alarmSoundLoader.item) {
            alarmSoundLoader.item.stop();
        }
        alarmActive = false;
    }

    Loader {
        id: alarmSoundLoader
        active: false
        source: "PomodoroSound.qml"
        onLoaded: {
            item.alarmActive = Qt.binding(() => root.alarmActive);
            item.autoStart = false;
            item.stopAlarmRequested.connect(root.stopAlarm);
            
            item.loops = 255;
            if (root.alarmActive) {
                item.play();
            }
        }
    }

    Timer {
        id: countdownTimer
        interval: 1000
        running: root.isRunning && root.timeLeft > 0
        repeat: true
        onTriggered: {
            if (root.timeLeft > 0) {
                root.timeLeft--;
                if (root.timeLeft === 0) {
                    startAlarm();
                }
            }
        }
    }

    // --- UI Layout ---
    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // Editable countdown.
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            clip: true

            ColumnLayout {
                id: timerInputs
                anchors.centerIn: parent
                spacing: 4

                RowLayout {
                    spacing: 4
                    Layout.alignment: Qt.AlignHCenter
                    
                    TimerInput {
                        id: minIn
                        value: Math.floor(root.timeLeft / 60)
                        onValueUpdated: val => {
                            let newSeconds = (val * 60) + (root.timeLeft % 60);
                            root.timeLeft = newSeconds;
                            if (!root.isRunning)
                                root.totalTime = newSeconds;
                        }
                    }
                    
                    Text {
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        text: ":"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(8)
                        font.weight: Font.Bold
                        color: root.alarmActive ? Styling.srItem("overprimary") : Colors.overBackground
                        Layout.topMargin: -6
                    }
                    
                    TimerInput {
                        id: secIn
                        value: root.timeLeft % 60
                        onValueUpdated: val => {
                            let newSeconds = (Math.floor(root.timeLeft / 60) * 60) + val;
                            root.timeLeft = newSeconds;
                            if (!root.isRunning)
                                root.totalTime = newSeconds;
                        }
                    }
                }
            }

            StyledRect {
                variant: "common"
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                height: 4
                width: 180
                radius: 2
                opacity: root.isRunning || root.alarmActive || root.visualProgress < 1.0 ? 1.0 : 0.3
                
                Rectangle {
                    height: parent.height
                    width: root.visualProgress * parent.width
                    radius: 2
                    color: Styling.srItem("overprimary")
                }
            }

        }

        // Start expands into equal pause/resume and reset actions.
        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            StyledRect {
                id: playBtn
                variant: root.alarmActive ? "primary" : (root.isRunning ? "focus" : "common")
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: Styling.radius(0)
                
                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    anchors.centerIn: parent
                    text: root.alarmActive ? "STOP ALARM" : (root.isRunning ? "PAUSE" : (root.isResuming ? "RESUME" : "START"))
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    font.weight: Font.Black
                    font.letterSpacing: 1
                    color: playBtn.item
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleTimer()
                }
            }

            StyledRect {
                id: resetBtn
                visible: root.isRunning || root.isResuming || root.alarmActive
                variant: "common"
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: Styling.radius(0)

                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    anchors.centerIn: parent
                    text: "RESET"
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    font.weight: Font.Black
                    font.letterSpacing: 1
                    color: resetBtn.item
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.resetTimer()
                }
            }
        }
    }

    // --- Sub-components ---
    component TimerInput: TextField {
        id: tIn
        property int value: 0
        signal valueUpdated(int newValue)
        
        text: value.toString().padStart(2, '0')
        onActiveFocusChanged: if (!activeFocus) text = value.toString().padStart(2, '0')
        
        font.family: Config.theme.monoFont
        font.pixelSize: Styling.fontSize(8)
        font.weight: Font.Bold
        color: root.alarmActive ? (Math.floor(Date.now() / 500) % 2 === 0 ? Styling.srItem("overprimary") : Colors.overBackground) : Colors.overBackground
        
        background: Item {}
        padding: 0; leftPadding: 0; rightPadding: 0
        horizontalAlignment: TextInput.AlignHCenter
        maximumLength: 2
        validator: IntValidator { bottom: 0; top: 99 }
        selectByMouse: true
        readOnly: root.isRunning || root.alarmActive
        
        onTextEdited: {
            let v = parseInt(text);
            if (!isNaN(v)) {
                tIn.valueUpdated(v);
            }
        }
        
        onEditingFinished: {
            let v = parseInt(text) || 0;
            tIn.valueUpdated(v);
            text = v.toString().padStart(2, '0');
        }
        
        Layout.preferredWidth: 60
        
        Timer {
            interval: 500
            running: root.alarmActive
            repeat: true
            onTriggered: tIn.update()
        }
    }
}
