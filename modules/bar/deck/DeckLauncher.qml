pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import qs.modules.theme

// Deck's launcher: a start panel that unrolls under the bar's launcher button.
// Search stays pinned in its own card; frequent apps and the full list or
// results sit in separate cards below it, and only the list scrolls.
FocusScope {
    id: root
    required property bool open
    required property real barClearance
    required property bool bottomEdge
    property real progress: open ? 1 : 0
    readonly property Item hitbox: progress > 0.001 ? frame : null
    readonly property bool projects: GlobalStates.launcherMode === "projects"
    readonly property string query: search.text.trim()
    readonly property real em: Styling.fontSize(0)
    readonly property real gap: em * 0.5
    property list<var> apps: []
    property list<string> projectPaths: []
    readonly property list<var> frequent: query === "" && !projects ? apps.slice(0, 8) : []
    readonly property int resultCount: projects ? projectPaths.length : apps.length
    property int selectedIndex: 0

    objectName: "deckLauncher"
    visible: progress > 0.001

    function refresh(): void {
        if (root.projects) root.projectPaths = ProjectPickerService.fuzzyFilter(root.query);
        else root.apps = root.query === "" ? AppSearch.getAllApps() : AppSearch.fuzzyQuery(root.query);
        root.selectedIndex = 0;
        results.positionViewAtBeginning();
    }
    function close(): void {
        Visibilities.setActiveModule("");
    }
    function launchApp(app: var): void {
        if (!app?.execute) return;
        UsageTracker.recordUsage(app.id);
        app.execute();
        root.close();
    }
    function activate(index: int): void {
        if (index < 0 || index >= root.resultCount) return;
        if (root.projects) {
            if (ProjectPickerService.openProject(root.projectPaths[index])) root.close();
        } else root.launchApp(root.apps[index]);
    }
    function move(step: int): void {
        if (root.resultCount === 0) return;
        root.selectedIndex = Math.max(0, Math.min(root.resultCount - 1, root.selectedIndex + step));
        results.positionViewAtIndex(root.selectedIndex, ListView.Contain);
    }
    function setMode(mode: string): void {
        if (GlobalStates.launcherMode === mode) return;
        GlobalStates.launcherMode = mode;
    }
    onOpenChanged: if (open) prepare()
    Component.onCompleted: if (open) prepare()
    function prepare(): void {
        search.clear();
        if (root.projects) ProjectPickerService.refresh();
        root.refresh();
        Qt.callLater(() => { if (root.open) search.forceActiveFocus(); });
    }
    onProjectsChanged: {
        if (root.projects) ProjectPickerService.refresh();
        root.refresh();
        Qt.callLater(() => { if (root.open) search.forceActiveFocus(); });
    }
    Connections {
        target: ProjectPickerService
        function onProjectsUpdated(): void { if (root.projects) root.refresh(); }
    }
    Behavior on progress {
        enabled: DeckMotion.enabled
        NumberAnimation {
            duration: root.open ? DeckMotion.openDuration : DeckMotion.closeDuration
            easing.type: root.open ? DeckMotion.openEasing : DeckMotion.closeEasing
        }
    }

    Item {
        id: frame
        objectName: "deckLauncherFrame"
        readonly property real fullHeight: Math.max(0, Math.min(root.height - root.barClearance - root.em, root.em * 34))
        x: root.em / 2
        width: Math.max(0, Math.min(root.width - root.em, root.em * 32))
        height: fullHeight * Math.max(0, Math.min(1, root.progress))
        y: root.bottomEdge ? root.height - root.barClearance - height : root.barClearance
        clip: true
        StyledRect { anchors.fill: parent; variant: "popup"; radius: Styling.radius(0) }

        ColumnLayout {
            id: contents
            x: root.gap
            y: (root.bottomEdge ? frame.height - frame.fullHeight : 0) + root.gap
                + (root.bottomEdge ? 1 : -1) * (1 - root.progress) * root.em * DeckMotion.railTravel
            width: frame.width - root.gap * 2
            height: frame.fullHeight - root.gap * 2
            opacity: Math.max(0, Math.min(1, root.progress * 1.6 - 0.3))
            spacing: root.gap

            DeckCard {
                objectName: "deckLauncherSearch"
                Layout.fillWidth: true
                order: -1
                padding: root.em * 0.35
                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.em * 0.3
                    StyledText {
                        Layout.leftMargin: root.em * 0.4
                        text: Icons.magnifyingGlass
                        font.family: Icons.font
                        color: Colors.overSurfaceVariant
                    }
                    TextField {
                        id: search
                        objectName: "deckLauncherInput"
                        Layout.fillWidth: true
                        placeholderText: root.projects ? "Open a project…" : "Search apps…"
                        placeholderTextColor: Colors.overSurfaceVariant
                        Accessible.name: placeholderText
                        color: Colors.overBackground
                        font.family: Config.theme.font
                        background: null
                        onTextChanged: root.refresh()
                        onAccepted: root.activate(root.selectedIndex)
                        Keys.onDownPressed: root.move(1)
                        Keys.onUpPressed: root.move(-1)
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_PageDown) root.move(6);
                            else if (event.key === Qt.Key_PageUp) root.move(-6);
                            else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) root.setMode(root.projects ? "apps" : "projects");
                            else if (event.key === Qt.Key_Escape) root.close();
                            else return;
                            event.accepted = true;
                        }
                    }
                    DeckAction {
                        objectName: "deckLauncherApps"
                        accent: true
                        quiet: true
                        controlHeight: root.em * 1.8
                        label: "Apps"
                        selected: !root.projects
                        onClicked: root.setMode("apps")
                    }
                    DeckAction {
                        objectName: "deckLauncherProjects"
                        accent: true
                        quiet: true
                        controlHeight: root.em * 1.8
                        label: "Projects"
                        description: "Projects · Tab"
                        selected: root.projects
                        onClicked: root.setMode("projects")
                    }
                }
            }

            DeckCard {
                objectName: "deckLauncherFrequent"
                Layout.fillWidth: true
                visible: root.frequent.length > 0
                title: "Frequent"
                order: 0
                GridLayout {
                    Layout.fillWidth: true
                    columns: 4
                    uniformCellWidths: true
                    rowSpacing: root.em * 0.2
                    columnSpacing: rowSpacing
                    Repeater {
                        model: root.frequent
                        Button {
                            id: tile
                            required property var modelData
                            objectName: "deckLauncherFrequent-" + (modelData?.id ?? "")
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            implicitHeight: root.em * 4.6
                            hoverEnabled: true
                            Accessible.name: modelData?.name ?? ""
                            scale: pressed ? 0.94 : 1
                            PressBehavior on scale { pressed: tile.pressed }
                            onClicked: root.launchApp(modelData)
                            background: StyledRect {
                                variant: "focus"
                                radius: Styling.radius(-4)
                                backgroundOpacity: tile.hovered ? 1 : 0
                                enableBorder: false
                            }
                            contentItem: ColumnLayout {
                                spacing: root.em * 0.25
                                Image {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: root.em * 2.2
                                    Layout.preferredHeight: Layout.preferredWidth
                                    source: "image://icon/" + (tile.modelData?.icon ?? "application-x-executable")
                                    sourceSize.width: width * 2
                                    sourceSize.height: height * 2
                                    asynchronous: true
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: tile.modelData?.name ?? ""
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    font.pixelSize: Styling.fontSize(-3)
                                }
                            }
                        }
                    }
                }
            }

            DeckCard {
                objectName: "deckLauncherResults"
                Layout.fillWidth: true
                Layout.fillHeight: true
                title: root.projects ? "Projects" : root.query === "" ? "All apps" : "Results"
                order: 1
                ListView {
                    id: results
                    objectName: "deckLauncherList"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: root.em * 0.15
                    boundsBehavior: Flickable.StopAtBounds
                    currentIndex: root.selectedIndex
                    highlightFollowsCurrentItem: false
                    model: root.projects ? root.projectPaths : root.apps
                    ScrollBar.vertical: ScrollBar {}
                    highlight: StyledRect {
                        width: results.width
                        height: results.currentItem?.height ?? 0
                        y: results.currentItem?.y ?? 0
                        variant: "primary"
                        radius: Styling.radius(-6)
                        enableBorder: false
                        visible: results.count > 0
                        Behavior on y {
                            enabled: DeckMotion.enabled
                            NumberAnimation { duration: DeckMotion.detentDuration; easing.type: DeckMotion.detentEasing; easing.overshoot: DeckMotion.detentOvershoot }
                        }
                    }
                    delegate: Button {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool current: index === root.selectedIndex
                        // Rows decide by their own data: the model and mode change in separate steps.
                        readonly property bool project: typeof modelData === "string"
                        readonly property string name: project ? ProjectPickerService.projectName(modelData) : (modelData?.name ?? "")
                        readonly property string detail: project ? ProjectPickerService.displayPath(modelData) : (modelData?.comment ?? "")
                        readonly property string projectIcon: project ? ProjectPickerService.projectIcon(modelData) : ""
                        objectName: "deckLauncherRow-" + index
                        width: results.width
                        implicitHeight: root.em * 3.1
                        hoverEnabled: true
                        Accessible.name: name
                        leftPadding: root.em * 0.5
                        rightPadding: root.em * 0.5
                        topPadding: 0
                        bottomPadding: 0
                        scale: pressed ? 0.97 : 1
                        PressBehavior on scale { pressed: row.pressed }
                        onHoveredChanged: if (hovered) root.selectedIndex = index
                        onClicked: root.activate(index)
                        background: null
                        contentItem: RowLayout {
                            spacing: root.em * 0.6
                            Item {
                                Layout.preferredWidth: root.em * 1.7
                                Layout.preferredHeight: Layout.preferredWidth
                                Image {
                                    id: rowIcon
                                    anchors.fill: parent
                                    source: row.project ? (row.projectIcon !== "" ? encodeURI("file://" + row.projectIcon) : "")
                                        : "image://icon/" + (row.modelData?.icon ?? "application-x-executable")
                                    sourceSize.width: width * 2
                                    sourceSize.height: height * 2
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    visible: status === Image.Ready
                                }
                                StyledText {
                                    anchors.centerIn: parent
                                    visible: !rowIcon.visible
                                    text: row.project ? Icons.folder : Icons.apps
                                    font.family: Icons.font
                                    font.pixelSize: Styling.fontSize(2)
                                    color: row.current ? Styling.srItem("primary") : Colors.overSurfaceVariant
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                StyledText {
                                    Layout.fillWidth: true
                                    text: row.name
                                    elide: Text.ElideRight
                                    font.weight: row.current ? Font.DemiBold : Font.Medium
                                    color: row.current ? Styling.srItem("primary") : Colors.overBackground
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                    text: row.detail
                                    elide: row.project ? Text.ElideLeft : Text.ElideRight
                                    font.pixelSize: Styling.fontSize(-3)
                                    color: row.current ? Styling.srItem("primary") : Colors.overSurfaceVariant
                                    opacity: row.current ? 0.8 : 1
                                }
                            }
                        }
                    }
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: root.resultCount === 0
                    text: root.projects ? (ProjectPickerService.scanning ? "Looking for projects…" : "No matching projects") : "No matching apps"
                    horizontalAlignment: Text.AlignHCenter
                    color: Colors.overSurfaceVariant
                }
            }
        }
    }
}
