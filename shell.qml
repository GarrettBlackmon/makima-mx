import Quickshell
import QtQuick
import "."

ShellRoot {
    FloatingWindow {
        id: win
        title: "makima-mx"
        color: Theme.background
        implicitWidth: 1100
        implicitHeight: 640
        minimumSize: Qt.size(880, 540)

        // ---- runtime state ----
        readonly property string activeApp: MakimaService.activeApp
        readonly property string activeProfile: MakimaService.currentActiveProfile
        readonly property var profiles: MakimaService.currentProfileNames
        property string activeButton: ""
        property string hoveredButton: ""
        property bool profileMenuOpen: false
        property string iconEditFor: ""
        property string tooltipText: ""
        property var tooltipAnchor: null

        // Material Symbols (bundled in assets/fonts/)
        FontLoader {
            id: materialFont
            source: Qt.resolvedUrl("assets/fonts/MaterialSymbolsRounded.ttf")
        }

        property var buttonOrder: [
            "left", "right", "wheel",
            "forward", "back", "gesture"
        ]
        readonly property var buttonLabels: ({
            "left": "Left Click", "right": "Right Click", "wheel": "Scroll Wheel",
            "back": "Back", "forward": "Forward", "gesture": "Gesture"
        })
        readonly property var bindings: {
            const out = {}
            for (let i = 0; i < buttonOrder.length; i++) {
                const id = buttonOrder[i]
                const remapped = MakimaService.bindingFor(id).length > 0
                out[id] = {
                    label: buttonLabels[id],
                    keys: remapped ? MakimaService.labelFor(id) : "default",
                    isDefault: !remapped
                }
            }
            return out
        }

        Column {
            anchors.fill: parent
            spacing: 0

            // ============ TOP BAR ============
            Rectangle {
                width: parent.width
                height: 56
                color: Theme.surfaceLow

                // Left group: logo | app pills (icon-only) | + | divider | profile pill | +
                Row {
                    id: topBarLeft
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingL
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingM

                    Text {
                        text: "makima-mx"
                        color: Theme.text
                        font.pixelSize: Theme.fontLg
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Rectangle {
                        width: 1; height: 28
                        color: Theme.outlineVariant
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // App pills (icon-only). Absolutely-positioned inside a sized Item
                    // so we can drag-reorder by mutating MakimaService.appOrder.
                    Item {
                        id: appPillsBox
                        readonly property int pillSize: 36
                        readonly property int pillGap: 8
                        readonly property int slot: pillSize + pillGap
                        anchors.verticalCenter: parent.verticalCenter
                        height: pillSize
                        width: MakimaService.appKeys.length * slot - pillGap

                        Repeater {
                            model: MakimaService.appKeys
                            delegate: Rectangle {
                                id: pill
                                required property string modelData
                                required property int index
                                readonly property bool isGlobal: modelData === MakimaService.globalKey
                                readonly property bool isActive: modelData === MakimaService.activeApp
                                readonly property string customIcon: MakimaService.customIconFor(modelData)
                                readonly property string resolvedIcon: {
                                    if (isGlobal) return ""
                                    if (customIcon) return customIcon.startsWith("/") ? "file://" + customIcon : customIcon
                                    try {
                                        const e = DesktopEntries.heuristicLookup(modelData)
                                        let p = Quickshell.iconPath(e ? e.icon : "", true)
                                        if (p) return p
                                        p = Quickshell.iconPath(modelData, true)
                                        if (p) return p
                                        return Quickshell.iconPath(modelData.toLowerCase(), true) || ""
                                    } catch (err) { return "" }
                                }

                                property real dragOffset: 0
                                readonly property bool isDragging: appMA.pressed && appMA._wasDrag

                                width: appPillsBox.pillSize
                                height: appPillsBox.pillSize
                                radius: Theme.radius
                                x: index * appPillsBox.slot + dragOffset
                                y: 0
                                z: isDragging ? 10 : 0
                                color: isActive ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20)
                                                : (appMA.containsMouse ? Theme.surfaceHigh : "transparent")
                                border.color: isActive ? Theme.primary : Theme.outlineVariant
                                border.width: 1
                                opacity: isDragging ? 0.85 : 1.0
                                Behavior on x { enabled: !pill.isDragging; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Behavior on opacity { NumberAnimation { duration: 120 } }

                                Text {
                                    visible: pill.isGlobal
                                    anchors.centerIn: parent
                                    text: "public"          // Material Symbols ligature → wireframe globe
                                    color: pill.isActive ? Theme.primary : Theme.text
                                    font.family: materialFont.name
                                    font.pixelSize: 22
                                }
                                Image {
                                    visible: !pill.isGlobal && pill.resolvedIcon.length > 0
                                    anchors.centerIn: parent
                                    width: 22; height: 22
                                    source: pill.resolvedIcon
                                    sourceSize.width: 48; sourceSize.height: 48
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                }
                                Text {
                                    visible: !pill.isGlobal && pill.resolvedIcon.length === 0
                                    anchors.centerIn: parent
                                    text: MakimaService.displayNameFor(modelData).substring(0, 1).toUpperCase()
                                    color: Theme.text
                                    font.pixelSize: 16
                                    font.weight: Font.DemiBold
                                }

                                MouseArea {
                                    id: appMA
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: pill.isDragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                                    property point _pressedAt: Qt.point(0, 0)
                                    property real _pressedOffset: 0
                                    property bool _wasDrag: false

                                    onEntered: {
                                        if (pill.isDragging) return
                                        win.tooltipText = MakimaService.displayNameFor(modelData)
                                        win.tooltipAnchor = pill
                                    }
                                    onExited: {
                                        if (win.tooltipAnchor === pill) {
                                            win.tooltipText = ""
                                            win.tooltipAnchor = null
                                        }
                                    }

                                    onPressed: (mouse) => {
                                        if (mouse.button === Qt.RightButton) return
                                        const abs = mapToItem(null, mouse.x, mouse.y)
                                        _pressedAt = abs
                                        _pressedOffset = pill.dragOffset
                                        _wasDrag = false
                                    }
                                    onPositionChanged: (mouse) => {
                                        // Only drag while the left button is held — right-press
                                        // also fires positionChanged but must not move the pill.
                                        if (!(pressedButtons & Qt.LeftButton) || pill.isGlobal) return
                                        const abs = mapToItem(null, mouse.x, mouse.y)
                                        const dx = abs.x - _pressedAt.x
                                        if (Math.abs(dx) > 4) {
                                            _wasDrag = true
                                            win.tooltipText = ""
                                            win.tooltipAnchor = null
                                        }
                                        if (_wasDrag) {
                                            pill.dragOffset = _pressedOffset + dx
                                        }
                                    }
                                    onReleased: (mouse) => {
                                        if (mouse.button === Qt.RightButton) return
                                        if (_wasDrag && !pill.isGlobal) {
                                            const naturalX = pill.x  // already includes dragOffset
                                            const slot = appPillsBox.slot
                                            const total = MakimaService.appKeys.length
                                            let targetIdx = Math.round(naturalX / slot)
                                            if (targetIdx < 1) targetIdx = 1   // can't pass _global
                                            if (targetIdx > total - 1) targetIdx = total - 1
                                            if (targetIdx !== pill.index) {
                                                MakimaService.moveApp(pill.index, targetIdx)
                                            }
                                            pill.dragOffset = 0
                                            _wasDrag = false
                                        }
                                    }
                                    onClicked: (mouse) => {
                                        if (_wasDrag) { _wasDrag = false; return }
                                        if (mouse.button === Qt.RightButton) {
                                            if (!pill.isGlobal) {
                                                win.tooltipText = ""
                                                win.tooltipAnchor = null
                                                iconEditModal.open(modelData,
                                                    MakimaService.customIconFor(modelData),
                                                    MakimaService.displayNameFor(modelData))
                                            }
                                            return
                                        }
                                        MakimaService.setActiveApp(modelData)
                                    }
                                }
                            }
                        }
                    }

                    // + Add app
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36; height: 36
                        radius: Theme.radius
                        color: addAppMA.containsMouse ? Theme.surfaceHigh : "transparent"
                        border.color: Theme.outlineVariant
                        border.width: 1
                        Text { anchors.centerIn: parent; text: "+"; color: Theme.text; font.pixelSize: Theme.fontLg }
                        MouseArea {
                            id: addAppMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: appPickerModal.open(MakimaService.appOverrideKeys)
                        }
                    }

                    // Divider
                    Rectangle {
                        width: 1; height: 28
                        color: Theme.outlineVariant
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Profile selector (pill) — applies to active app
                    Rectangle {
                        id: profilePill
                        anchors.verticalCenter: parent.verticalCenter
                        height: 36
                        width: profileText.implicitWidth + chevron.width + Theme.spacingL * 2
                        radius: Theme.radius
                        color: profileMA.containsMouse ? Theme.surfaceHigh : Theme.surfaceVariant
                        border.color: Theme.outlineVariant
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.spacingS
                            Text {
                                id: profileText
                                text: win.activeProfile
                                color: Theme.text
                                font.pixelSize: Theme.fontMd
                                font.weight: Font.Medium
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                id: chevron
                                text: "▾"
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontMd
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea {
                            id: profileMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.profileMenuOpen = !win.profileMenuOpen
                        }
                    }

                    // + New profile (for active app)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        height: 36; width: 36
                        radius: Theme.radius
                        color: addProfMA.containsMouse ? Theme.surfaceHigh : "transparent"
                        border.color: Theme.outlineVariant
                        border.width: 1
                        Text { anchors.centerIn: parent; text: "+"; color: Theme.text; font.pixelSize: Theme.fontLg }
                        MouseArea {
                            id: addProfMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: nameProfileModal.open("New profile", "Name (e.g. PvP)", "", win.profiles)
                        }
                    }
                }

                // Right group (anchored to right)
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingL
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingM

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: MakimaService.deviceName
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSm
                        opacity: MakimaService.deviceConnected ? 1 : 0.5
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8; height: 8; radius: 4
                        color: MakimaService.deviceConnected ? "#62ff74" : Theme.error
                        Behavior on color { ColorAnimation { duration: 200 } }
                        // Tooltip on hover
                        MouseArea {
                            id: devDotMA
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            onEntered: {
                                win.tooltipText = MakimaService.deviceConnected
                                                  ? "Device connected"
                                                  : "Device disconnected"
                                win.tooltipAnchor = parent
                            }
                            onExited: {
                                if (win.tooltipAnchor === parent) {
                                    win.tooltipText = ""
                                    win.tooltipAnchor = null
                                }
                            }
                        }
                    }
                }
            }

            // Divider
            Rectangle { width: parent.width; height: 1; color: Theme.outlineVariant; opacity: 0.5 }

            // ============ MAIN BODY ============
            Row {
                width: parent.width
                height: parent.height - 56 - 1 - 32
                spacing: 0

                // Mouse panel (left, ~60%)
                Rectangle {
                    width: parent.width * 0.58
                    height: parent.height
                    color: Theme.background

                    MouseDisplay {
                        id: mouseDisplay
                        anchors.fill: parent
                        anchors.margins: Theme.spacingL
                        activeButton: win.activeButton
                        hoveredButton: win.hoveredButton
                        onButtonHovered: (id) => win.hoveredButton = id
                        onButtonExited:  (id) => { if (win.hoveredButton === id) win.hoveredButton = "" }
                        onButtonClicked: (id) => {
                            win.activeButton = id
                            const b = win.bindings[id]
                            captureModal.open(b.label, b.keys)
                        }
                    }

                    // Hint at the bottom
                    Text {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottomMargin: Theme.spacingM
                        text: win.hoveredButton
                              ? (win.bindings[win.hoveredButton] ? win.bindings[win.hoveredButton].label : "")
                              : "Hover a button on the mouse, or pick from the list"
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSm
                        opacity: 0.8
                    }
                }

                // Divider
                Rectangle { width: 1; height: parent.height; color: Theme.outlineVariant; opacity: 0.5 }

                // Bindings panel (right, ~42%)
                Item {
                    width: parent.width * 0.42 - 1
                    height: parent.height

                    BindingsList {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingL
                        bindings: win.bindings
                        buttonOrder: win.buttonOrder
                        activeButton: win.activeButton
                        hoveredButton: win.hoveredButton
                        onRowHovered:  (id) => win.hoveredButton = id
                        onRowExited:   (id) => { if (win.hoveredButton === id) win.hoveredButton = "" }
                        onRowClicked:  (id) => {
                            win.activeButton = id
                            const b = win.bindings[id]
                            captureModal.open(b.label, b.keys)
                        }
                    }
                }
            }

            // ============ STATUS BAR ============
            Rectangle {
                width: parent.width
                height: 32
                color: Theme.surfaceLow

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingL
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        const app = MakimaService.displayNameFor(MakimaService.effectiveAppKey)
                        const prof = MakimaService.effectiveProfileName
                        return "Active: " + app + (prof ? " » " + prof : "")
                    }
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSm
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingL
                    anchors.verticalCenter: parent.verticalCenter
                    text: "makima " + (MakimaService.daemonRunning ? "running" : "stopped")
                    color: MakimaService.daemonRunning ? Theme.textMuted : Theme.error
                    font.pixelSize: Theme.fontSm
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }
        }

        // ============ PROFILE DROPDOWN (overlay) ============
        // Hoisted out of the top bar so it draws above the main panel.
        // Closes on outside click via the backdrop.
        MouseArea {
            anchors.fill: parent
            visible: win.profileMenuOpen
            onClicked: win.profileMenuOpen = false
        }
        Rectangle {
            id: profileMenu
            visible: win.profileMenuOpen
            width: Math.max(profilePill.width, 140)
            height: profMenuCol.implicitHeight + Theme.spacingS * 2
            radius: Theme.radiusS
            color: Theme.surfaceHigh
            border.color: Theme.outlineVariant
            border.width: 1
            // Position below the pill, in window coords
            onVisibleChanged: if (visible) {
                const p = profilePill.mapToItem(null, 0, profilePill.height + 4)
                x = p.x; y = p.y
            }
            Column {
                id: profMenuCol
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: 2
                Repeater {
                    model: win.profiles
                    delegate: Rectangle {
                        required property string modelData
                        readonly property bool isActive: modelData === win.activeProfile
                        readonly property bool canDelete: !isActive && win.profiles.length > 1
                        width: parent.width
                        height: 32
                        radius: Theme.radiusS
                        color: pMA.containsMouse ? Theme.surfaceVariant : "transparent"
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingM
                            text: modelData
                            color: parent.isActive ? Theme.primary : Theme.text
                            font.pixelSize: Theme.fontMd
                            font.weight: parent.isActive ? Font.DemiBold : Font.Normal
                        }
                        MouseArea {
                            id: pMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                MakimaService.setActiveProfile(modelData)
                                win.profileMenuOpen = false
                            }
                        }
                        // Delete × (only on non-active rows when there's more than one)
                        Rectangle {
                            visible: parent.canDelete && (pMA.containsMouse || delMA.containsMouse)
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            width: 22; height: 22
                            radius: 11
                            color: delMA.containsMouse ? Theme.surfaceHigh : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                color: Theme.textMuted
                                font.pixelSize: 16
                            }
                            MouseArea {
                                id: delMA
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: MakimaService.deleteProfile(modelData)
                            }
                        }
                    }
                }
            }
        }

        // ============ MODAL OVERLAY ============
        CaptureModal {
            id: captureModal
            onCancelled: win.activeButton = ""
            onCaptured: (keys) => {
                if (win.activeButton && keys && keys.length > 0)
                    MakimaService.setBinding(win.activeButton, keys)
                win.activeButton = ""
            }
            onReset: {
                if (win.activeButton) MakimaService.clearBinding(win.activeButton)
                win.activeButton = ""
            }
        }

        NameProfileModal {
            id: nameProfileModal
            onConfirmed: (name) => MakimaService.createProfile(name)
        }

        AppPickerModal {
            id: appPickerModal
            onSelected: (cls) => MakimaService.createApp(cls)
        }

        IconEditModal {
            id: iconEditModal
            onPathChanged: (appKey, path) => MakimaService.setAppIcon(appKey, path)
            onNameChanged: (appKey, name) => MakimaService.setAppDisplayName(appKey, name)
            onDeleteRequested: (appKey) => MakimaService.deleteApp(appKey)
        }

        // ============ TOOLTIP (root overlay) ============
        Rectangle {
            id: tooltip
            visible: win.tooltipText.length > 0 && win.tooltipAnchor
            width: tooltipText.implicitWidth + Theme.spacingM
            height: tooltipText.implicitHeight + Theme.spacingS
            radius: Theme.radiusS
            color: Theme.surfaceHigh
            border.color: Theme.outlineVariant
            border.width: 1
            z: 1000
            x: {
                if (!win.tooltipAnchor) return 0
                const p = win.tooltipAnchor.mapToItem(null, win.tooltipAnchor.width / 2, 0)
                return Math.max(4, Math.min(win.width - width - 4, p.x - width / 2))
            }
            y: {
                if (!win.tooltipAnchor) return 0
                const p = win.tooltipAnchor.mapToItem(null, 0, win.tooltipAnchor.height + 6)
                return p.y
            }
            Text {
                id: tooltipText
                anchors.centerIn: parent
                text: win.tooltipText
                color: Theme.text
                font.pixelSize: Theme.fontSm
            }
        }
    }
}
