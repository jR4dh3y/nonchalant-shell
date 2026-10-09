pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.config

Item {
    id: root

    property string searchQuery: ""
    property int searchCursor: 0
    property int historyCursor: 0
    property var visitedSections: ({})
    readonly property var initialPage: settingsIndex.pages.find(entry => entry.section === GlobalStates.settingsCurrentTab) ?? settingsIndex.pages[0]
    property var trail: [{ pageId: initialPage.id, tabId: defaultTab(initialPage.id) }]
    property string loadedPageId: ""

    readonly property var currentEntry: trail[historyCursor] ?? { pageId: initialPage.id, tabId: defaultTab(initialPage.id) }
    readonly property string currentPageId: currentEntry.pageId
    readonly property string currentTabId: currentEntry.tabId
    readonly property var currentPage: pageFor(currentPageId)
    readonly property var currentTab: currentPage.tabs.find(tab => tab.id === currentTabId) ?? { id: "", label: "", panelSection: "" }

    SettingsIndex {
        id: settingsIndex
    }

    function pageFor(pageId: string): var {
        return settingsIndex.pages.find(entry => entry.id === pageId) ?? settingsIndex.pages[0]
    }

    function defaultTab(pageId: string): string {
        const page = pageFor(pageId)
        return page.tabs.length > 0 ? page.tabs[0].id : ""
    }

    function categoryLabel(categoryId: string): string {
        const category = settingsIndex.categories.find(entry => entry.id === categoryId)
        return category ? category.label : ""
    }

    function go(pageId: string, requestedTabId: string): void {
        const page = pageFor(pageId)
        const preferredTab = requestedTabId !== ""
            ? requestedTabId
            : (visitedSections[pageId] ?? defaultTab(pageId))
        const tabId = page.tabs.some(tab => tab.id === preferredTab) ? preferredTab : defaultTab(pageId)
        if (page.tabs.length > 0) {
            const nextVisited = Object.assign({}, visitedSections)
            nextVisited[page.id] = tabId
            visitedSections = nextVisited
        }

        if (page.id === currentPageId && tabId === currentTabId)
            return

        const nextTrail = trail.slice(0, historyCursor + 1)
        nextTrail.push({ pageId: page.id, tabId: tabId })
        trail = nextTrail
        historyCursor = nextTrail.length - 1
        GlobalStates.settingsCurrentTab = page.section
        searchCursor = 0
    }

    function showTab(tabId: string): void {
        if (!currentPage.tabs.some(tab => tab.id === tabId) || tabId === currentTabId)
            return

        const nextVisited = Object.assign({}, visitedSections)
        nextVisited[currentPageId] = tabId
        visitedSections = nextVisited

        const nextTrail = trail.slice()
        nextTrail[historyCursor] = { pageId: currentPageId, tabId: tabId }
        trail = nextTrail
        GlobalStates.settingsCurrentTab = currentPage.section
    }

    function back(): void {
        if (historyCursor <= 0)
            return
        historyCursor--
        GlobalStates.settingsCurrentTab = currentPage.section
        searchCursor = 0
    }

    function forward(): void {
        if (historyCursor >= trail.length - 1)
            return
        historyCursor++
        GlobalStates.settingsCurrentTab = currentPage.section
        searchCursor = 0
    }

    function fuzzyScore(query: string, target: string): int {
        if (query.length === 0)
            return 0
        if (target.length === 0)
            return -1

        const lowerQuery = query.toLowerCase()
        const lowerTarget = target.toLowerCase()
        if (lowerTarget.includes(lowerQuery))
            return 1000 + (100 - target.length)

        let queryIndex = 0
        let score = 0
        let consecutive = 0
        let maxConsecutive = 0
        for (let i = 0; i < lowerTarget.length && queryIndex < lowerQuery.length; i++) {
            if (lowerTarget[i] === lowerQuery[queryIndex]) {
                queryIndex++
                consecutive++
                maxConsecutive = Math.max(maxConsecutive, consecutive)
                if (i === 0 || " -_".includes(lowerTarget[i - 1]))
                    score += 10
            } else {
                consecutive = 0
            }
        }
        return queryIndex === lowerQuery.length ? score + maxConsecutive * 5 : -1
    }

    function bestScore(query: string, first: string, second: string, third: string): int {
        return Math.max(fuzzyScore(query, first), fuzzyScore(query, second), fuzzyScore(query, third))
    }

    readonly property var searchResults: {
        const query = searchQuery.trim()
        if (query === "")
            return []

        const matches = []
        for (const page of settingsIndex.pages) {
            const matchingTabs = []
            for (const tab of page.tabs) {
                if (tab.id === "overview")
                    continue
                const score = bestScore(query, tab.label, tab.keywords, "")
                if (score >= 0) {
                    matchingTabs.push({
                        pageId: page.id,
                        section: page.section,
                        category: page.category,
                        label: tab.label,
                        parentLabel: page.label,
                        icon: page.icon,
                        tabId: tab.id,
                        score: score
                    })
                }
            }

            if (matchingTabs.length > 0) {
                for (const match of matchingTabs)
                    matches.push(match)
                continue
            }

            const score = bestScore(query, page.label, page.description, page.keywords)
            if (score >= 0) {
                matches.push({
                    pageId: page.id,
                    section: page.section,
                    category: page.category,
                    label: page.label,
                    parentLabel: "",
                    icon: page.icon,
                    tabId: "",
                    score: score
                })
            }
        }

        return matches.sort((left, right) => right.score - left.score).map((match, index) => ({
            pageId: match.pageId,
            section: match.section,
            category: match.category,
            label: match.label,
            parentLabel: match.parentLabel,
            icon: match.icon,
            tabId: match.tabId,
            score: match.score,
            resultIndex: index
        }))
    }

    readonly property var sidebarRows: {
        const rows = []
        const query = searchQuery.trim()

        for (const category of settingsIndex.categories) {
            const entries = query === ""
                ? settingsIndex.pages.filter(page => page.category === category.id)
                : searchResults.filter(result => result.category === category.id)
            if (entries.length === 0)
                continue

            rows.push({ heading: true, label: category.label })
            for (const entry of entries) {
                if (query === "") {
                    rows.push({
                        heading: false,
                        pageId: entry.id,
                        section: entry.section,
                        label: entry.label,
                        parentLabel: "",
                        icon: entry.icon,
                        tabId: "",
                        resultIndex: -1
                    })
                } else {
                    rows.push({
                        heading: false,
                        pageId: entry.pageId,
                        section: entry.section,
                        label: entry.label,
                        parentLabel: entry.parentLabel,
                        icon: entry.icon,
                        tabId: entry.tabId,
                        resultIndex: entry.resultIndex
                    })
                }
            }
        }
        return rows
    }

    function openSearchResult(result: var): void {
        if (result)
            go(result.pageId, result.tabId)
    }

    function moveSearchCursor(offset: int): void {
        const count = searchResults.length
        if (count === 0)
            return
        searchCursor = (searchCursor + offset + count) % count
        Qt.callLater(positionSearchSelection)
    }

    function positionSearchSelection(): void {
        if (searchQuery.trim() === "")
            return
        const row = sidebarRows.findIndex(entry => !entry.heading && entry.resultIndex === searchCursor)
        if (row >= 0)
            sidebarList.positionViewAtIndex(row, ListView.Contain)
    }

    function focusSearchInput(): void {
        searchInput.focusInput()
    }

    function applyCurrentPanelTab(): void {
        if (loadedPageId !== currentPageId || panelLoader.status !== Loader.Ready
                || !panelLoader.item || panelLoader.item.currentSection === undefined)
            return
        panelLoader.item.currentSection = currentTab.panelSection ?? ""
    }

    function syncTabFromPanel(): void {
        if (loadedPageId !== currentPageId || !panelLoader.item
                || panelLoader.item.currentSection === undefined)
            return
        const panelSection = panelLoader.item.currentSection
        const tab = currentPage.tabs.find(entry => entry.panelSection === panelSection)
        if (tab && tab.id !== currentTabId)
            showTab(tab.id)
    }

    function resetCurrentPageScroll(): void {
        if (loadedPageId !== currentPageId || !panelLoader.item
                || typeof panelLoader.item.resetScroll !== "function")
            return
        panelLoader.item.resetScroll()
    }

    component IconButton: Button {
        id: iconButton
        required property string glyph
        property string helpText: ""

        implicitWidth: 34
        implicitHeight: 34
        padding: 0

        background: StyledRect {
            variant: iconButton.hovered ? "focus" : "common"
            radius: Styling.radius(-4)
        }

        contentItem: Text {
            text: iconButton.glyph
            font.family: iconButton.glyph === "×" ? Config.theme.font : Icons.font
            font.pixelSize: iconButton.glyph === "×" ? 22 : 16
            color: iconButton.enabled ? Colors.overBackground : Colors.outline
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        StyledToolTip {
            visible: iconButton.hovered && iconButton.helpText !== ""
            tooltipText: iconButton.helpText
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 12

        StyledRect {
            id: sidebar
            Layout.preferredWidth: 220
            Layout.maximumWidth: 220
            Layout.fillHeight: true
            variant: "common"
            radius: Styling.radius(4)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "Nonchalant"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(3)
                        font.weight: Font.Bold
                        color: Colors.overBackground
                    }

                    Text {
                        text: "Settings"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        color: Colors.overSurfaceVariant
                    }
                }

                SearchInput {
                    id: searchInput
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    iconText: Icons.magnifyingGlass
                    placeholderText: "Search settings"
                    clearOnEscape: false

                    onSearchTextChanged: text => {
                        root.searchQuery = text
                    }
                    onDownPressed: root.moveSearchCursor(1)
                    onUpPressed: root.moveSearchCursor(-1)
                    onAccepted: {
                        if (root.searchResults.length > 0)
                            root.openSearchResult(root.searchResults[root.searchCursor])
                    }
                    onEscapePressed: {
                        if (searchInput.text !== "")
                            searchInput.clear()
                        else
                            GlobalStates.settingsWindowVisible = false
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ListView {
                        id: sidebarList
                        anchors.fill: parent
                        clip: true
                        spacing: 1
                        model: root.sidebarRows
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Item {
                            id: sidebarRow
                            required property var modelData
                            required property int index

                            readonly property bool isHeading: modelData.heading
                            readonly property bool isCurrent: !isHeading && root.searchQuery.trim() === ""
                                ? modelData.pageId === root.currentPageId
                                : (!isHeading && modelData.pageId === root.currentPageId
                                    && (modelData.tabId === "" || modelData.tabId === root.currentTabId))
                            readonly property bool isKeyboardTarget: !isHeading
                                && root.searchQuery.trim() !== ""
                                && modelData.resultIndex === root.searchCursor
                            property bool hovered: false

                            width: sidebarList.width
                            height: isHeading ? 24 : 44

                            Text {
                                visible: sidebarRow.isHeading
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 3
                                text: sidebarRow.modelData.label
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                font.weight: Font.DemiBold
                                font.letterSpacing: 0.6
                                color: Colors.outline
                            }

                            StyledRect {
                                anchors.fill: parent
                                visible: !sidebarRow.isHeading && (sidebarRow.isCurrent || sidebarRow.isKeyboardTarget || sidebarRow.hovered)
                                variant: sidebarRow.isCurrent ? "primary" : "focus"
                                radius: Styling.radius(-4)
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 8
                                spacing: 9
                                visible: !sidebarRow.isHeading

                                Text {
                                    text: sidebarRow.modelData.icon ?? ""
                                    font.family: Icons.font
                                    font.pixelSize: 16
                                    color: sidebarRow.isCurrent ? Styling.srItem("primary") : Colors.overSurfaceVariant
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    Text {
                                        Layout.fillWidth: true
                                        text: sidebarRow.modelData.label
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-1)
                                        font.weight: sidebarRow.isCurrent ? Font.DemiBold : Font.Normal
                                        color: sidebarRow.isCurrent ? Styling.srItem("primary") : Colors.overBackground
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        visible: (sidebarRow.modelData.parentLabel ?? "") !== ""
                                        Layout.fillWidth: true
                                        text: sidebarRow.modelData.parentLabel ?? ""
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-3)
                                        color: Colors.overSurfaceVariant
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: !sidebarRow.isHeading
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: sidebarRow.hovered = true
                                onExited: sidebarRow.hovered = false
                                onClicked: {
                                    if (root.searchQuery.trim() !== "")
                                        root.openSearchResult(sidebarRow.modelData)
                                    else
                                        root.go(sidebarRow.modelData.pageId, "")
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: root.searchQuery.trim() !== "" && root.searchResults.length === 0
                        text: "No settings found"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        color: Colors.overSurfaceVariant
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                IconButton {
                    glyph: Icons.arrowLeft
                    helpText: "Back"
                    enabled: root.historyCursor > 0
                    onClicked: root.back()
                }

                IconButton {
                    glyph: Icons.arrowRight
                    helpText: "Forward"
                    enabled: root.historyCursor < root.trail.length - 1
                    onClicked: root.forward()
                }

                Item {
                    Layout.fillWidth: true
                }

                IconButton {
                    glyph: "×"
                    helpText: "Close settings"
                    onClicked: GlobalStates.settingsWindowVisible = false
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                StyledRect {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    variant: "pane"
                    radius: Styling.radius(0)

                    Text {
                        anchors.centerIn: parent
                        text: root.currentPage.icon
                        font.family: Icons.font
                        font.pixelSize: 24
                        color: Styling.srItem("overprimary")
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: root.categoryLabel(root.currentPage.category)
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.8
                        color: Colors.overSurfaceVariant
                    }

                    Text {
                        text: root.currentPage.label
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(2)
                        font.weight: Font.Bold
                        color: Colors.overBackground
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.currentPage.description
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        color: Colors.overSurfaceVariant
                        elide: Text.ElideRight
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 36 : 0
                spacing: 4
                visible: root.currentPage.tabs.length > 0

                Repeater {
                    model: root.currentPage.tabs

                    delegate: Button {
                        id: pageTab
                        required property var modelData
                        required property int index

                        implicitHeight: 36
                        Layout.fillWidth: true
                        padding: 8

                        background: StyledRect {
                            variant: pageTab.modelData.id === root.currentTabId
                                ? "primary"
                                : (pageTab.hovered ? "focus" : "common")
                            radius: Styling.radius(-4)
                        }

                        contentItem: Text {
                            text: pageTab.modelData.label
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: pageTab.modelData.id === root.currentTabId ? Font.DemiBold : Font.Normal
                            color: pageTab.modelData.id === root.currentTabId ? Styling.srItem("primary") : Colors.overBackground
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }

                        onClicked: root.showTab(pageTab.modelData.id)
                    }
                }
            }

            Loader {
                id: panelLoader
                Layout.fillWidth: true
                Layout.fillHeight: true
                asynchronous: true
                source: root.currentPage.component
                opacity: status === Loader.Ready ? 1 : 0

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutCubic
                    }
                }

                onLoaded: {
                    root.loadedPageId = root.currentPageId
                    root.applyCurrentPanelTab()
                    root.resetCurrentPageScroll()
                }
            }

            Connections {
                target: panelLoader.item
                ignoreUnknownSignals: true
                function onCurrentSectionChanged() {
                    Qt.callLater(root.syncTabFromPanel)
                }
            }
        }
    }

    onSearchQueryChanged: {
        searchCursor = 0
        Qt.callLater(positionSearchSelection)
    }

    onSearchCursorChanged: Qt.callLater(positionSearchSelection)
    onCurrentPageIdChanged: searchCursor = 0
    onCurrentTabIdChanged: {
        Qt.callLater(applyCurrentPanelTab)
        Qt.callLater(resetCurrentPageScroll)
    }

    Component.onCompleted: searchInput.focusInput()
}
