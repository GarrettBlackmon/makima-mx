import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "."

// Lists currently-focused Hyprland windows; pick one to add as a per-app override.
Item {
    id: root
    anchors.fill: parent
    visible: opacity > 0
    opacity: 0
    Behavior on opacity { NumberAnimation { duration: 140 } }

    property var existing: []         // WM_CLASSes already overridden, to mark in list
    property var windows: []          // [{class, title, icon}]

    signal selected(string wmClass)
    signal cancelled()

    function open(existing) {
        root.existing = existing || []
        root.windows = []
        opacity = 1
        _refreshProc.running = true
    }
    function close() { opacity = 0 }

    function _resolveIcon(cls) {
        if (!cls) return ""
        try {
            const entry = DesktopEntries.heuristicLookup(cls)
            let p = Quickshell.iconPath(entry ? entry.icon : "", true)
            if (p && p.length > 0) return p
            p = Quickshell.iconPath(cls, true)
            if (p && p.length > 0) return p
            p = Quickshell.iconPath(cls.toLowerCase(), true)
            if (p && p.length > 0) return p
        } catch (e) { /* ignore */ }
        return ""
    }

    property Process _refreshProc: Process {
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const arr = JSON.parse(text)
                    const seen = {}
                    const out = []
                    for (let i = 0; i < arr.length; i++) {
                        const c = arr[i]
                        const cls = c.class || c.initialClass
                        if (!cls || seen[cls]) continue
                        seen[cls] = true
                        out.push({
                            "class": cls,
                            "title": c.title || cls,
                            "icon": root._resolveIcon(cls),
                            "alreadyHas": root.existing.indexOf(cls) >= 0
                        })
                    }
                    out.sort((a, b) => a.class.localeCompare(b.class))
                    root.windows = out
                } catch (e) {
                    console.warn("makima-mx: failed to parse hyprctl output:", e)
                    root.windows = []
                }
            }
        }
    }

    // Backdrop
    Rectangle {
        anchors.fill: parent
        color: "#000"
        opacity: 0.55
        MouseArea { anchors.fill: parent; onClicked: { root.cancelled(); root.close() } }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 520
        height: 480
        radius: Theme.radiusL
        color: Theme.surfaceHigh
        border.color: Theme.outlineVariant
        border.width: 1

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingXL
            spacing: Theme.spacingL

            Text {
                text: "Add app override"
                color: Theme.text
                font.pixelSize: Theme.fontXl
                font.weight: Font.DemiBold
            }
            Text {
                text: root.windows.length + " windows currently open"
                color: Theme.textMuted
                font.pixelSize: Theme.fontSm
            }

            // List
            Rectangle {
                width: parent.width
                height: parent.height - 130
                color: Theme.background
                radius: Theme.radius
                border.color: Theme.outlineVariant
                border.width: 1

                ListView {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    clip: true
                    spacing: 2
                    model: root.windows

                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width
                        height: 56
                        radius: Theme.radiusS
                        color: ma.containsMouse && !modelData.alreadyHas
                               ? Theme.surfaceHigh
                               : "transparent"
                        opacity: modelData.alreadyHas ? 0.5 : 1
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingM
                            anchors.rightMargin: Theme.spacingM
                            spacing: Theme.spacingM

                            Image {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 32; height: 32
                                source: modelData.icon
                                fillMode: Image.PreserveAspectFit
                                sourceSize.width: 64; sourceSize.height: 64
                                smooth: true
                                visible: modelData.icon && modelData.icon.length > 0
                            }
                            // Fallback when no icon
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 32; height: 32
                                radius: 6
                                color: Theme.surfaceVariant
                                visible: !modelData.icon || modelData.icon.length === 0
                                Text {
                                    anchors.centerIn: parent
                                    text: (modelData.class || "?").substring(0, 1).toUpperCase()
                                    color: Theme.text
                                    font.pixelSize: 16
                                    font.weight: Font.DemiBold
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 130
                                spacing: 1
                                Text {
                                    text: modelData.class
                                    color: Theme.text
                                    font.pixelSize: Theme.fontMd
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                                Text {
                                    text: modelData.title
                                    color: Theme.textMuted
                                    font.pixelSize: Theme.fontSm
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                            }
                            Text {
                                visible: modelData.alreadyHas
                                anchors.verticalCenter: parent.verticalCenter
                                text: "already added"
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontSm
                                font.italic: true
                            }
                        }

                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: modelData.alreadyHas ? Qt.ArrowCursor : Qt.PointingHandCursor
                            enabled: !modelData.alreadyHas
                            onClicked: { root.selected(modelData.class); root.close() }
                        }
                    }
                }
            }

            // Cancel button
            Item {
                width: parent.width
                height: 36
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: cTxt.implicitWidth + Theme.spacingL
                    height: 36
                    radius: Theme.radiusS
                    color: cMA.containsMouse ? Theme.surfaceLow : "transparent"
                    border.color: Theme.outline
                    border.width: 1
                    Text { id: cTxt; anchors.centerIn: parent; text: "Cancel"; color: Theme.text; font.pixelSize: Theme.fontMd }
                    MouseArea { id: cMA; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { root.cancelled(); root.close() } }
                }
            }
        }
    }
}
