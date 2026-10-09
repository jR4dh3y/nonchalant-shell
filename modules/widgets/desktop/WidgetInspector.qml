import QtQuick
import QtQuick.Controls
import Quickshell
import qs.config
import qs.modules.components
import qs.modules.services
import qs.modules.services.desktop
import qs.modules.theme

Item {
    id: root

    required property Item board

    readonly property string key: DesktopWidgetService.selected
    readonly property var row: DesktopWidgetService.entryOf(key)
    readonly property string moduleId: row?.id ?? ""
    readonly property bool edgeRow: DesktopWidgetService.isEdge(row)
    readonly property bool deck: DeckService.isDeck(row)
    readonly property string theme: DesktopWidgetService.themeOf(row)
    readonly property var box: row && !root.edgeRow
        ? DesktopWidgetService.geometry(row, board.width, board.height)
        : ({ x: width / 2, y: height / 2, width: 0, height: 0 })
    readonly property string ownTheme: row && typeof row.theme === "string" ? row.theme : ""
    readonly property string ownStyle: row && typeof row.style === "string" ? row.style : ""
    readonly property bool photo: moduleId === "photo"
    readonly property bool captioned: photo && theme === "analogue"
        && DesktopWidgetService.familyOf(row) !== "8x2"
    readonly property bool onSpectrum: moduleId === "spectrum"
    readonly property bool styled: moduleId !== "notes" && moduleId !== "photo" && !onSpectrum
    readonly property var spectrum: DesktopWidgetService.spectrumOf(row)
    readonly property list<var> spectrumMeasures: [
        { id: "reach", label: "Height" },
        { id: "bar", label: "Bar width" },
        { id: "gap", label: "Gap" }
    ]
    readonly property real cardWidth: Math.max(1, Math.min(320, width - 24))
    readonly property real cardGap: Styling.fontSize(0)

    function placeX(): real {
        if (root.edgeRow)
            return Math.max(DesktopWidgetService.gutter, root.width - root.cardWidth - DesktopWidgetService.gutter)
        if (root.box.x + root.box.width + root.cardGap + root.cardWidth <= root.width - DesktopWidgetService.gutter)
            return root.box.x + root.box.width + root.cardGap
        if (root.box.x - root.cardGap - root.cardWidth >= DesktopWidgetService.gutter)
            return root.box.x - root.cardGap - root.cardWidth
        return Math.max(DesktopWidgetService.gutter,
            Math.min(root.width - root.cardWidth - DesktopWidgetService.gutter, root.box.x))
    }

    function placeY(): real {
        if (root.edgeRow)
            return DesktopWidgetService.gutter
        const available = root.height - column.implicitHeight - 2 * DesktopWidgetService.gutter
        return Math.max(DesktopWidgetService.gutter,
            Math.min(available, root.box.y + root.box.height / 2 - card.height / 2))
    }
    function setSpectrum(field: string, value: var): void {
        const changes = ({})
        changes[field] = value
        DesktopWidgetService.setSpectrum(root.key, changes)
    }

    StyledRect {
        id: card

        x: root.placeX()
        y: root.placeY()
        width: root.cardWidth
        height: column.implicitHeight + 28
        variant: "popup"
        backgroundOpacity: 0.98
        radius: Styling.radius(8)
        border.color: Colors.outlineVariant
        border.width: 1
        clip: true

        Behavior on x {
            NumberAnimation { duration: Config.animDuration > 0 ? Config.animDuration : 0 }
        }
        Behavior on y {
            NumberAnimation { duration: Config.animDuration > 0 ? Config.animDuration : 0 }
        }

        TapHandler {
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            gesturePolicy: TapHandler.ReleaseWithinBounds
        }

        Column {
            id: column

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            spacing: 10

            Row {
                width: parent.width
                height: 30
                spacing: 8

                Text {
                    width: parent.width - removeButton.width - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    text: DesktopWidgetService.catalogueEntry(root.moduleId)?.name ?? root.moduleId
                    elide: Text.ElideRight
                    font.family: Config.defaultFont
                    font.pixelSize: Styling.fontSize(1)
                    font.weight: Font.DemiBold
                    color: Colors.overBackground
                }

                StyledRect {
                    id: removeButton
                    width: 74
                    height: 28
                    anchors.verticalCenter: parent.verticalCenter
                    variant: "error"
                    radius: Styling.radius(4)

                    Text {
                        anchors.centerIn: parent
                        text: "Remove"
                        font.family: Config.defaultFont
                        font.pixelSize: Styling.fontSize(-1)
                        color: Colors.overError
                    }

                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: DesktopWidgetService.remove(root.key)
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: 1
                variant: "transparent"
                backgroundOpacity: 0
                border.width: 0
            }
            Row {
                visible: root.deck
                width: parent.width
                height: 32
                spacing: 8

                Text {
                    width: parent.width - newNotesToggle.width - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    text: "New notes land here"
                    elide: Text.ElideRight
                    font.family: Config.defaultFont
                    font.pixelSize: Styling.fontSize(-1)
                    color: Colors.outline
                }

                StyledRect {
                    id: newNotesToggle
                    width: 66
                    height: 28
                    anchors.verticalCenter: parent.verticalCenter
                    variant: root.row?.takesNew === true ? "focus" : "common"
                    radius: Styling.radius(4)
                    border.color: Colors.outlineVariant
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: root.row?.takesNew === true ? "On" : "Off"
                        font.family: Config.defaultFont
                        font.pixelSize: Styling.fontSize(-2)
                        color: root.row?.takesNew === true ? Colors.overBackground : Colors.outline
                    }

                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: DeckService.setTakesNew(
                            root.key, root.row?.takesNew !== true)
                    }
                }
            }

            Text {
                visible: !root.edgeRow
                text: "Shape"
                font.family: Config.defaultFont
                font.pixelSize: Styling.fontSize(-1)
                font.weight: Font.DemiBold
                color: Colors.outline
            }

            Flow {
                visible: !root.edgeRow
                width: parent.width
                spacing: 6

                Repeater {
                    model: DesktopWidgetService.familiesFor(root.moduleId, root.theme)

                    delegate: StyledRect {
                        id: familyTile
                        required property string modelData

                        readonly property var shape: DesktopWidgetService.family(modelData)
                        readonly property bool current: DesktopWidgetService.familyOf(root.row) === modelData

                        width: Math.max(58, shape.cols * 8 + 22)
                        height: 34
                        variant: current ? "focus" : "common"
                        radius: Styling.radius(4)
                        border.color: current ? Colors.primary : Colors.outlineVariant
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: `${familyTile.modelData} · ${familyTile.shape.label}`
                            font.family: Config.defaultFont
                            font.pixelSize: Styling.fontSize(-2)
                            color: familyTile.current ? Colors.overBackground : Colors.outline
                        }

                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: DesktopWidgetService.setFamily(root.key, familyTile.modelData)
                        }
                    }
                }
            }
            Text {
                visible: root.onSpectrum
                text: "Look"
                font.family: Config.defaultFont
                font.pixelSize: Styling.fontSize(-1)
                font.weight: Font.DemiBold
                color: Colors.outline
            }

            Flow {
                visible: root.onSpectrum
                width: parent.width
                spacing: 6

                Repeater {
                    model: root.onSpectrum ? DesktopWidgetService.spectrumLooks : []

                    delegate: StyledRect {
                        id: lookTile
                        required property var modelData
                        readonly property bool current: root.spectrum.look === modelData.id

                        width: 90
                        height: 30
                        variant: current ? "focus" : "common"
                        radius: Styling.radius(4)
                        border.color: current ? Colors.primary : Colors.outlineVariant
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: lookTile.modelData.label
                            font.family: Config.defaultFont
                            font.pixelSize: Styling.fontSize(-2)
                            color: lookTile.current ? Colors.overBackground : Colors.outline
                        }

                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: root.setSpectrum("look", lookTile.modelData.id)
                        }
                    }
                }
            }

            Text {
                visible: root.onSpectrum
                text: "Fill"
                font.family: Config.defaultFont
                font.pixelSize: Styling.fontSize(-1)
                font.weight: Font.DemiBold
                color: Colors.outline
            }

            Flow {
                visible: root.onSpectrum
                width: parent.width
                spacing: 6

                Repeater {
                    model: root.onSpectrum ? DesktopWidgetService.spectrumFills : []

                    delegate: StyledRect {
                        id: fillTile
                        required property var modelData
                        readonly property bool current: root.spectrum.fill === modelData.id

                        width: 90
                        height: 30
                        variant: current ? "focus" : "common"
                        radius: Styling.radius(4)
                        border.color: current ? Colors.primary : Colors.outlineVariant
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: fillTile.modelData.label
                            font.family: Config.defaultFont
                            font.pixelSize: Styling.fontSize(-2)
                            color: fillTile.current ? Colors.overBackground : Colors.outline
                        }

                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: root.setSpectrum("fill", fillTile.modelData.id)
                        }
                    }
                }
            }

            Text {
                visible: root.onSpectrum
                text: "Colour"
                font.family: Config.defaultFont
                font.pixelSize: Styling.fontSize(-1)
                font.weight: Font.DemiBold
                color: Colors.outline
            }

            Flow {
                visible: root.onSpectrum
                width: parent.width
                spacing: 6

                Repeater {
                    model: root.onSpectrum ? DesktopWidgetService.spectrumColours : []

                    delegate: StyledRect {
                        id: colourTile
                        required property var modelData
                        readonly property bool current: root.spectrum.colorName === modelData.id

                        width: 82
                        height: 28
                        variant: current ? "focus" : "common"
                        radius: Styling.radius(4)
                        border.color: current ? Colors.primary : Colors.outlineVariant
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: colourTile.modelData.label
                            font.family: Config.defaultFont
                            font.pixelSize: Styling.fontSize(-2)
                            color: colourTile.current ? Colors.overBackground : Colors.outline
                        }

                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: root.setSpectrum("color", colourTile.modelData.id)
                        }
                    }
                }
            }

            Text {
                visible: root.onSpectrum && root.spectrum.fill === "blend"
                text: "Colour at the tip"
                font.family: Config.defaultFont
                font.pixelSize: Styling.fontSize(-1)
                font.weight: Font.DemiBold
                color: Colors.outline
            }

            Flow {
                visible: root.onSpectrum && root.spectrum.fill === "blend"
                width: parent.width
                spacing: 6

                Repeater {
                    model: root.onSpectrum && root.spectrum.fill === "blend"
                        ? DesktopWidgetService.spectrumColours : []

                    delegate: StyledRect {
                        id: tipColourTile
                        required property var modelData
                        readonly property bool current: root.spectrum.color2Name === modelData.id

                        width: 82
                        height: 28
                        variant: current ? "focus" : "common"
                        radius: Styling.radius(4)
                        border.color: current ? Colors.primary : Colors.outlineVariant
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: tipColourTile.modelData.label
                            font.family: Config.defaultFont
                            font.pixelSize: Styling.fontSize(-2)
                            color: tipColourTile.current ? Colors.overBackground : Colors.outline
                        }

                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: root.setSpectrum("color2", tipColourTile.modelData.id)
                        }
                    }
                }
            }

            Text {
                visible: root.onSpectrum
                text: "Size"
                font.family: Config.defaultFont
                font.pixelSize: Styling.fontSize(-1)
                font.weight: Font.DemiBold
                color: Colors.outline
            }

            Column {
                visible: root.onSpectrum
                width: parent.width
                spacing: 4

                Repeater {
                    model: root.onSpectrum ? root.spectrumMeasures : []

                    delegate: Column {
                        id: measure
                        required property var modelData

                        readonly property var range: DesktopWidgetService.spectrumRanges[modelData.id]
                        width: parent.width
                        spacing: 2

                        Text {
                            width: parent.width
                            text: `${measure.modelData.label} · ${Math.round(measureSlider.value)} px`
                            elide: Text.ElideRight
                            font.family: Config.defaultFont
                            font.pixelSize: Styling.fontSize(-2)
                            color: Colors.outline
                        }

                        Slider {
                            id: measureSlider
                            width: parent.width
                            from: measure.range.from
                            to: measure.range.to
                            stepSize: 1
                            value: root.spectrum[measure.modelData.id]
                            onMoved: root.setSpectrum(measure.modelData.id, Math.round(value))
                        }
                    }
                }
            }

            Text {
                visible: root.onSpectrum
                text: "Low points"
                font.family: Config.defaultFont
                font.pixelSize: Styling.fontSize(-1)
                font.weight: Font.DemiBold
                color: Colors.outline
            }

            Flow {
                visible: root.onSpectrum
                width: parent.width
                spacing: 6

                Repeater {
                    model: root.onSpectrum
                        ? [{ id: "corners", label: "Corners" }, { id: "along", label: "Along edge" }]
                        : []

                    delegate: StyledRect {
                        id: lowsTile
                        required property var modelData
                        readonly property bool current: root.spectrum.lows === modelData.id

                        width: 98
                        height: 30
                        variant: current ? "focus" : "common"
                        radius: Styling.radius(4)
                        border.color: current ? Colors.primary : Colors.outlineVariant
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: lowsTile.modelData.label
                            font.family: Config.defaultFont
                            font.pixelSize: Styling.fontSize(-2)
                            color: lowsTile.current ? Colors.overBackground : Colors.outline
                        }

                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: root.setSpectrum("lows", lowsTile.modelData.id)
                        }
                    }
                }
            }

            Row {
                visible: root.onSpectrum
                width: parent.width
                height: 30
                spacing: 8

                Text {
                    width: parent.width - peaksSwitch.width - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Peaks"
                    font.family: Config.defaultFont
                    font.pixelSize: Styling.fontSize(-1)
                    color: Colors.outline
                }

                StyledRect {
                    id: peaksSwitch
                    width: 66
                    height: 28
                    anchors.verticalCenter: parent.verticalCenter
                    variant: root.spectrum.peaks ? "focus" : "common"
                    radius: Styling.radius(4)
                    border.color: Colors.outlineVariant
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: root.spectrum.peaks ? "On" : "Off"
                        font.family: Config.defaultFont
                        font.pixelSize: Styling.fontSize(-2)
                        color: root.spectrum.peaks ? Colors.overBackground : Colors.outline
                    }

                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: root.setSpectrum("peaks", !root.spectrum.peaks)
                    }
                }
            }


            Text {
                visible: root.moduleId !== "notes" && root.moduleId !== "spectrum" && root.moduleId !== "lyrics"
                text: "Face"
                font.family: Config.defaultFont
                font.pixelSize: Styling.fontSize(-1)
                font.weight: Font.DemiBold
                color: Colors.outline
            }

            Flow {
                visible: root.moduleId !== "notes" && root.moduleId !== "spectrum" && root.moduleId !== "lyrics"
                width: parent.width
                spacing: 6

                Repeater {
                    model: [{ id: "", label: "Default" }].concat(DesktopWidgetService.themes)

                    delegate: StyledRect {
                        id: themeTile
                        required property var modelData

                        readonly property string themeId: modelData.id
                        readonly property bool current: root.ownTheme === themeId

                        width: 74
                        height: 30
                        variant: current ? "focus" : "common"
                        radius: Styling.radius(4)
                        border.color: current ? Colors.primary : Colors.outlineVariant
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: themeTile.modelData.label
                            font.family: Config.defaultFont
                            font.pixelSize: Styling.fontSize(-2)
                            color: themeTile.current ? Colors.overBackground : Colors.outline
                        }

                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: DesktopWidgetService.setTheme(root.key, themeTile.themeId)
                        }
                    }
                }
            }

            Text {
                visible: root.styled
                text: "Style"
                font.family: Config.defaultFont
                font.pixelSize: Styling.fontSize(-1)
                font.weight: Font.DemiBold
                color: Colors.outline
            }

            Flow {
                visible: root.styled
                width: parent.width
                spacing: 6

                Repeater {
                    model: [
                        { id: "", label: "Default" },
                        { id: "solid", label: "Solid" },
                        { id: "glass", label: "Glass" }
                    ]

                    delegate: StyledRect {
                        id: styleTile
                        required property var modelData

                        readonly property bool current: root.ownStyle === modelData.id

                        width: 78
                        height: 30
                        variant: current ? "focus" : "common"
                        radius: Styling.radius(4)
                        border.color: current ? Colors.primary : Colors.outlineVariant
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: styleTile.modelData.label
                            font.family: Config.defaultFont
                            font.pixelSize: Styling.fontSize(-2)
                            color: styleTile.current ? Colors.overBackground : Colors.outline
                        }

                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: DesktopWidgetService.setStyle(root.key, styleTile.modelData.id)
                        }
                    }
                }
            }

            Column {
                visible: !root.deck
                width: parent.width
                spacing: 4

                Text {
                    width: parent.width
                    text: `Opacity · ${DesktopWidgetService.opacityOf(root.row)}%`
                    elide: Text.ElideRight
                    font.family: Config.defaultFont
                    font.pixelSize: Styling.fontSize(-1)
                    font.weight: Font.DemiBold
                    color: Colors.outline
                }

                Row {
                    width: parent.width
                    height: 30
                    spacing: 6

                    Slider {
                        id: opacitySlider
                        width: parent.width - resetOpacity.width - parent.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        from: 0
                        to: 100
                        value: DesktopWidgetService.opacityOf(root.row)
                        onMoved: DesktopWidgetService.setOpacity(root.key, Math.round(value))
                    }

                    StyledRect {
                        id: resetOpacity
                        width: 52
                        height: 28
                        anchors.verticalCenter: parent.verticalCenter
                        variant: "common"
                        radius: Styling.radius(4)
                        border.color: Colors.outlineVariant
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "Reset"
                            font.family: Config.defaultFont
                            font.pixelSize: Styling.fontSize(-2)
                            color: Colors.outline
                        }

                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: DesktopWidgetService.setOpacity(root.key, -1)
                        }
                    }
                }
            }

            Text {
                visible: root.photo
                text: "Picture path · drop a file or enter its path"
                font.family: Config.defaultFont
                font.pixelSize: Styling.fontSize(-1)
                font.weight: Font.DemiBold
                color: Colors.outline
            }

            Row {
                visible: root.photo
                width: parent.width
                height: 34
                spacing: 6

                TextField {
                    id: picturePath
                    width: parent.width - applyPicture.width - clearPicture.width - 12
                    height: 34
                    text: root.photo && typeof root.row.picture === "string" ? root.row.picture : ""
                    placeholderText: "/path/to/image.png"
                    selectByMouse: true
                    font.family: Config.defaultFont
                    font.pixelSize: Styling.fontSize(-1)
                    color: Colors.overBackground
                    background: StyledRect {
                        variant: "internalbg"
                        radius: Styling.radius(4)
                        border.color: picturePath.activeFocus ? Colors.primary : Colors.outlineVariant
                        border.width: 1
                    }

                    DropArea {
                        anchors.fill: parent
                        onDropped: drop => {
                            if (drop.urls && drop.urls.length > 0) {
                                const path = String(drop.urls[0])
                                if (DesktopWidgetService.setPicture(root.key, path))
                                    drop.accepted = true
                            }
                        }
                    }
                }

                StyledRect {
                    id: applyPicture
                    width: 54
                    height: 34
                    variant: "primary"
                    radius: Styling.radius(4)

                    Text {
                        anchors.centerIn: parent
                        text: "Apply"
                        font.family: Config.defaultFont
                        font.pixelSize: Styling.fontSize(-2)
                        color: Colors.overPrimary
                    }

                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: DesktopWidgetService.setPicture(root.key, picturePath.text)
                    }
                }

                StyledRect {
                    id: clearPicture
                    width: 48
                    height: 34
                    variant: "common"
                    radius: Styling.radius(4)
                    border.color: Colors.outlineVariant
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Clear"
                        font.family: Config.defaultFont
                        font.pixelSize: Styling.fontSize(-2)
                        color: Colors.outline
                    }

                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: {
                            DesktopWidgetService.update(root.key, { picture: null })
                            picturePath.text = ""
                        }
                    }
                }
            }

            Text {
                visible: root.captioned
                text: "Caption"
                font.family: Config.defaultFont
                font.pixelSize: Styling.fontSize(-1)
                font.weight: Font.DemiBold
                color: Colors.outline
            }

            TextField {
                visible: root.captioned
                width: parent.width
                height: 34
                text: root.captioned && typeof root.row.caption === "string" ? root.row.caption : ""
                placeholderText: "Written under the picture"
                selectByMouse: true
                font.family: Config.defaultFont
                font.pixelSize: Styling.fontSize(-1)
                color: Colors.overBackground
                maximumLength: 40
                background: StyledRect {
                    variant: "internalbg"
                    radius: Styling.radius(4)
                    border.color: Colors.outlineVariant
                    border.width: 1
                }
                onTextEdited: DesktopWidgetService.setCaption(root.key, text)
            }
        }
    }
}
