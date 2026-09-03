pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import qs.config

Rectangle {
    id: root
    color: "transparent"

    implicitWidth: 464
    implicitHeight: 320

    focus: true

    property string searchText: GlobalStates.projectPickerSearchText
    property int selectedIndex: GlobalStates.projectPickerSelectedIndex
    property var filteredProjects: []

    signal modeSwitchRequested

    onActiveFocusChanged: {
        if (activeFocus)
            focusSearchInput();
    }

    Component.onCompleted: {
        ProjectPickerService.refresh();
        rebuildList();
        focusSearchInput();
    }

    Connections {
        target: ProjectPickerService
        function onProjectsUpdated() {
            root.rebuildList();
        }
    }

    function focusSearchInput() {
        searchInput.focusInput();
    }

    function rebuildList() {
        filteredProjects = ProjectPickerService.fuzzyFilter(searchText);
        if (filteredProjects.length === 0) {
            selectedIndex = -1;
            GlobalStates.projectPickerSelectedIndex = -1;
            return;
        }
        if (selectedIndex < 0 || selectedIndex >= filteredProjects.length) {
            selectedIndex = searchText.length > 0 ? 0 : 0;
            GlobalStates.projectPickerSelectedIndex = selectedIndex;
        }
        resultsList.currentIndex = selectedIndex;
    }

    function openSelected() {
        if (selectedIndex < 0 || selectedIndex >= filteredProjects.length)
            return;
        const path = filteredProjects[selectedIndex];
        if (ProjectPickerService.openProject(path))
            Visibilities.setActiveModule("");
    }

    function copySelected() {
        if (selectedIndex < 0 || selectedIndex >= filteredProjects.length)
            return;
        ProjectPickerService.copyPath(filteredProjects[selectedIndex]);
    }

    function moveSelection(delta) {
        if (filteredProjects.length === 0) {
            selectedIndex = -1;
            GlobalStates.projectPickerSelectedIndex = -1;
            return;
        }
        let next = selectedIndex;
        if (next < 0)
            next = delta > 0 ? 0 : filteredProjects.length - 1;
        else
            next = Math.max(0, Math.min(filteredProjects.length - 1, next + delta));
        selectedIndex = next;
        GlobalStates.projectPickerSelectedIndex = next;
        resultsList.currentIndex = next;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        SearchInput {
            id: searchInput
            Layout.fillWidth: true
            text: GlobalStates.projectPickerSearchText
            placeholderText: "Search projects..."
            iconText: ""
            handleTabNavigation: true
            disableCursorNavigation: false
            clearOnEscape: false

            onSearchTextChanged: text => {
                GlobalStates.projectPickerSearchText = text;
                root.searchText = text;
                root.rebuildList();
                if (root.filteredProjects.length > 0) {
                    root.selectedIndex = 0;
                    GlobalStates.projectPickerSelectedIndex = 0;
                    resultsList.currentIndex = 0;
                    resultsList.contentY = 0;
                }
            }

            onAccepted: root.openSelected()
            onTabPressed: root.modeSwitchRequested()
            onShiftTabPressed: root.modeSwitchRequested()

            onEscapePressed: Visibilities.setActiveModule("")

            onDownPressed: root.moveSelection(1)
            onUpPressed: root.moveSelection(-1)

            onPageDownPressed: {
                const step = Math.max(1, Math.floor(resultsList.height / 48));
                root.moveSelection(step);
            }
            onPageUpPressed: {
                const step = Math.max(1, Math.floor(resultsList.height / 48));
                root.moveSelection(-step);
            }
            onHomePressed: {
                if (root.filteredProjects.length > 0) {
                    root.selectedIndex = 0;
                    GlobalStates.projectPickerSelectedIndex = 0;
                    resultsList.currentIndex = 0;
                }
            }
            onEndPressed: {
                if (root.filteredProjects.length > 0) {
                    root.selectedIndex = root.filteredProjects.length - 1;
                    GlobalStates.projectPickerSelectedIndex = root.selectedIndex;
                    resultsList.currentIndex = root.selectedIndex;
                }
            }

            onRightPressed: root.copySelected()
        }

        ListView {
            id: resultsList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 0
            model: root.filteredProjects
            currentIndex: root.selectedIndex
            boundsBehavior: Flickable.StopAtBounds
            reuseItems: true
            highlightFollowsCurrentItem: false

            property bool enableScrollAnimation: true

            Behavior on contentY {
                enabled: Config.animDuration > 0 && resultsList.enableScrollAnimation && !resultsList.moving
                NumberAnimation {
                    duration: Config.animDuration / 2
                    easing.type: Easing.OutCubic
                }
            }

            onCurrentIndexChanged: {
                if (currentIndex >= 0 && currentIndex !== root.selectedIndex) {
                    root.selectedIndex = currentIndex;
                    GlobalStates.projectPickerSelectedIndex = currentIndex;
                }
                if (currentIndex >= 0)
                    positionViewAtIndex(currentIndex, ListView.Contain);
            }

            delegate: Item {
                id: row
                required property string modelData
                required property int index

                property string projectIcon: ProjectPickerService.projectIcon(modelData)

                width: resultsList.width
                height: 48

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: {
                        root.selectedIndex = index;
                        GlobalStates.projectPickerSelectedIndex = index;
                        resultsList.currentIndex = index;
                    }
                    onClicked: {
                        root.selectedIndex = index;
                        GlobalStates.projectPickerSelectedIndex = index;
                        root.openSelected();
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 12

                    Item {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32

                        Image {
                            id: projectIconImage
                            anchors.fill: parent
                            source: row.projectIcon.length > 0
                                ? encodeURI("file://" + row.projectIcon)
                                : ""
                            fillMode: Image.PreserveAspectFit
                            mipmap: true
                        }

                        Text {
                            anchors.centerIn: parent
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            visible: projectIconImage.status !== Image.Ready
                            text: Icons.folder
                            font.family: Icons.font
                            font.pixelSize: 20
                            color: root.selectedIndex === index
                                ? Styling.srItem("primary")
                                : Colors.outline

                            Behavior on color {
                                enabled: Config.animDuration > 0
                                ColorAnimation {
                                    duration: Config.animDuration / 2
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            width: parent.width
                            text: ProjectPickerService.projectName(row.modelData)
                            color: root.selectedIndex === index
                                ? Styling.srItem("primary")
                                : Colors.overBackground
                            font.family: Config.theme.font
                            font.pixelSize: Config.theme.fontSize
                            font.weight: Font.Bold
                            elide: Text.ElideRight

                            Behavior on color {
                                enabled: Config.animDuration > 0
                                ColorAnimation {
                                    duration: Config.animDuration / 2
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        Text {
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            width: parent.width
                            text: ProjectPickerService.displayPath(row.modelData)
                            color: root.selectedIndex === index
                                ? Styling.srItem("primary")
                                : Colors.outline
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            elide: Text.ElideMiddle

                            Behavior on color {
                                enabled: Config.animDuration > 0
                                ColorAnimation {
                                    duration: Config.animDuration / 2
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }

                    Text {
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        visible: root.selectedIndex === index
                        text: Icons.copy
                        font.family: Icons.font
                        font.pixelSize: 16
                        color: Styling.srItem("primary")
                        Layout.alignment: Qt.AlignVCenter
                        opacity: 0.75
                    }
                }
            }

            // Same primary bar highlight as the app launcher
            highlight: Item {
                width: resultsList.width
                height: 48
                y: Math.max(0, resultsList.currentIndex) * 48
                visible: resultsList.currentIndex >= 0

                Behavior on y {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration / 2
                        easing.type: Easing.OutCubic
                    }
                }

                StyledRect {
                    anchors.fill: parent
                    variant: "primary"
                    radius: Styling.radius(4)
                }
            }

            // Empty / loading states
            Text {
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                anchors.centerIn: parent
                visible: resultsList.count === 0
                text: ProjectPickerService.scanning
                    ? "Scanning projects..."
                    : (root.searchText.length > 0 ? "No matching projects" : "No projects found")
                color: Colors.outline
                font.family: Config.theme.font
                font.pixelSize: Config.theme.fontSize
            }
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            Visibilities.setActiveModule("");
            event.accepted = true;
        }
    }
}
