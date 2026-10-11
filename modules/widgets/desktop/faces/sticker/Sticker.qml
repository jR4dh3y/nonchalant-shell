// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S   T   I   C   K   E   R                                              │
// │   sticker widget theme · coloured die-cut stickers per module            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import qs.modules.widgets.desktop.impasto.services

// The Sticker theme's registry: one row per module, each face laying itself
// out at whatever family it is given. `seed` is what every sticker's tilt is
// hashed from: the row's key, or the module on the tray, so two clocks on
// the desk lean differently and each keeps its angle.
Item {
    id: root

    property string moduleId: ""
    property string family: "2x2"
    property var ink: DesktopService.inkFor(null)
    property var row: null

    readonly property string seed: root.row && root.row.key ? root.row.key : root.moduleId

    readonly property var components: ({
        clock: clockFace,
        weather: weatherFace,
        github: githubFace,
        battery: batteryFace,
        stats: statsFace,
        claude: claudeFace,
        codex: codexFace,
        media: mediaFace,
        calendar: calendarFace,
        timer: timerFace,
        volume: volumeFace,
        brightness: brightnessFace,
        tasks: tasksFace,
        updates: updatesFace,
        network: networkFace,
        bluetooth: bluetoothFace,
        pet: creatureFace,
        games: gamesFace,
        photo: photoFace
    })

    Loader {
        anchors.fill: parent
        sourceComponent: root.components[root.moduleId] ?? null
    }

    Component { id: clockFace;      ClockFace      { family: root.family; ink: root.ink; seed: root.seed } }
    Component { id: weatherFace;    WeatherFace    { family: root.family; ink: root.ink; seed: root.seed } }
    Component { id: githubFace;     GithubFace     { family: root.family; ink: root.ink; seed: root.seed } }
    Component { id: batteryFace;    BatteryFace    { family: root.family; ink: root.ink; seed: root.seed } }
    Component { id: statsFace;      StatsFace      { family: root.family; ink: root.ink; seed: root.seed } }
    Component { id: claudeFace;     ClaudeFace     { family: root.family; ink: root.ink; seed: root.seed } }
    Component { id: codexFace;      CodexFace      { family: root.family; ink: root.ink; seed: root.seed } }
    Component { id: mediaFace;      MediaFace      { family: root.family; ink: root.ink; seed: root.seed } }
    Component { id: calendarFace;   CalendarFace   { family: root.family; ink: root.ink; seed: root.seed; row: root.row } }
    Component { id: timerFace;      TimerFace      { family: root.family; ink: root.ink; seed: root.seed } }
    Component { id: volumeFace;     VolumeFace     { family: root.family; ink: root.ink; seed: root.seed } }
    Component { id: brightnessFace; BrightnessFace { family: root.family; ink: root.ink; seed: root.seed } }
    Component { id: tasksFace;      TasksFace      { family: root.family; ink: root.ink; seed: root.seed; row: root.row } }
    Component { id: updatesFace;    UpdatesFace    { family: root.family; ink: root.ink; seed: root.seed } }
    Component { id: networkFace;    NetworkFace    { family: root.family; ink: root.ink; seed: root.seed } }
    Component { id: bluetoothFace;  BluetoothFace  { family: root.family; ink: root.ink; seed: root.seed } }
    Component { id: creatureFace;   CreatureFace   { family: root.family; ink: root.ink; seed: root.seed } }
    Component { id: gamesFace;      GamesFace      { family: root.family; ink: root.ink; seed: root.seed; row: root.row } }
    Component { id: photoFace;      PhotoFace      { family: root.family; ink: root.ink; seed: root.seed; row: root.row } }
}
