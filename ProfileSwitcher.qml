import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "."

// Chord-driven profile switcher.
//
// A persistent helper (scripts/chord-watch.py) watches the physical mouse for
// the Back+Forward chord via the EVIOCGKEY state ioctl (which works despite
// makima's exclusive grab) and, while the chord is held, reports wheel detents
// read from makima's virtual pointer. Its stdout drives this component:
// DOWN shows the overlay, SCROLL moves the selection, UP commits the selected
// profile for the focused app — one makima restart per switch, none while
// browsing. makima's own config plays no part, so this works identically in
// remapped and unmapped profiles.
Scope {
    id: root

    property bool active: false
    property string appKey: ""
    property var names: []
    property int selIndex: 0

    // Center of the focused window in layout coordinates, and the screen it
    // sits on — captured at chord-down so the overlay opens over that window
    // instead of mid-monitor. -1 / null = no target, fall back to centered.
    property real targetCx: -1
    property real targetCy: -1
    property var targetScreen: null

    function begin() {
        if (active) return
        appKey = MakimaService.effectiveAppKey
        names = MakimaService.profileNamesFor(appKey)
        selIndex = Math.max(0, names.indexOf(MakimaService.activeProfileFor(appKey)))
        _captureFocusedWindow()
        active = true
        failsafe.restart()
    }
    function _captureFocusedWindow() {
        targetScreen = null
        targetCx = targetCy = -1
        const t = Hyprland.activeToplevel
        const ipc = t ? t.lastIpcObject : null
        if (!ipc || !ipc.at || !ipc.size) return
        const cx = ipc.at[0] + ipc.size[0] / 2
        const cy = ipc.at[1] + ipc.size[1] / 2
        const screens = Quickshell.screens
        for (let i = 0; i < screens.length; i++) {
            const s = screens[i]
            if (cx >= s.x && cx < s.x + s.width && cy >= s.y && cy < s.y + s.height) {
                targetScreen = s
                targetCx = cx
                targetCy = cy
                return
            }
        }
    }
    function move(delta) {
        if (!active) begin()
        if (names.length === 0) return
        selIndex = ((selIndex + delta) % names.length + names.length) % names.length
        failsafe.restart()
    }
    function commit() {
        if (!active) return
        active = false
        failsafe.stop()
        const chosen = names[selIndex]
        if (chosen && chosen !== MakimaService.activeProfileFor(appKey))
            MakimaService.setActiveProfileFor(appKey, chosen)
    }

    property Process chordWatch: Process {
        running: true
        command: ["python3", Quickshell.shellDir + "/scripts/chord-watch.py",
                  MakimaService.deviceName]
        stdout: SplitParser {
            onRead: data => {
                const line = data.trim()
                if (line === "DOWN") root.begin()
                else if (line === "UP") root.commit()
                else if (line === "SCROLL +1") root.move(-1)   // wheel up → previous
                else if (line === "SCROLL -1") root.move(1)    // wheel down → next
            }
        }
        onExited: {
            if (root.active) root.commit()
            restart.restart()
        }
    }
    property Timer restart: Timer {
        interval: 2000
        onTriggered: root.chordWatch.running = true
    }
    // Absolute cap so a dead watcher can't leave the overlay stuck open.
    property Timer failsafe: Timer {
        interval: 12000
        onTriggered: root.commit()
    }

    // Manual entry points for testing/scripting:
    //   qs ipc -p <shellDir>/shell.qml call switcher begin|next|prev|commit
    property IpcHandler _ipc: IpcHandler {
        target: "switcher"
        function begin(): void { root.begin() }
        function next(): void { root.move(1) }
        function prev(): void { root.move(-1) }
        function commit(): void { root.commit() }
    }

    property PanelWindow overlay: PanelWindow {
        id: overlayWin
        visible: root.active
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "makima-mx-switcher"
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        implicitWidth: card.implicitWidth
        implicitHeight: card.implicitHeight

        // Anchor over the focused window's center (clamped to its monitor)
        // when we know it; otherwise stay compositor-centered.
        readonly property bool positioned: root.targetScreen !== null
        screen: root.targetScreen
        anchors.left: positioned
        anchors.top: positioned
        margins.left: positioned
            ? Math.max(8, Math.min(
                  root.targetCx - root.targetScreen.x - card.implicitWidth / 2,
                  root.targetScreen.width - card.implicitWidth - 8))
            : 0
        margins.top: positioned
            ? Math.max(8, Math.min(
                  root.targetCy - root.targetScreen.y - card.implicitHeight / 2,
                  root.targetScreen.height - card.implicitHeight - 8))
            : 0

        Rectangle {
            id: card
            implicitWidth: Math.max(240, list.implicitWidth + Theme.spacingL * 2)
            implicitHeight: list.implicitHeight + Theme.spacingL * 2
            radius: Theme.radiusL
            color: Theme.background
            border.color: Theme.outlineVariant
            border.width: 1

            Column {
                id: list
                x: Theme.spacingL
                y: Theme.spacingL
                spacing: Theme.spacingXS

                Text {
                    text: MakimaService.displayNameFor(root.appKey)
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSm
                    bottomPadding: Theme.spacingS
                }
                Repeater {
                    model: root.names
                    delegate: Rectangle {
                        required property string modelData
                        required property int index
                        readonly property bool selected: index === root.selIndex
                        width: Math.max(200, rowText.implicitWidth + Theme.spacingL * 2)
                        height: rowText.implicitHeight + Theme.spacingM
                        radius: Theme.radius
                        color: selected ? Theme.primaryContainer : "transparent"

                        Text {
                            id: rowText
                            anchors.verticalCenter: parent.verticalCenter
                            x: Theme.spacingM
                            text: (modelData === MakimaService.activeProfileFor(root.appKey)
                                   ? "● " : "") + modelData
                            color: parent.selected ? Theme.primaryContainerFg : Theme.text
                            font.pixelSize: Theme.fontMd
                            font.bold: parent.selected
                        }
                    }
                }
            }
        }
    }
}
