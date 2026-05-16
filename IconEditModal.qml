import QtQuick
import QtQuick.Dialogs
import Quickshell
import "."

// Modal for editing an app pill's display name + icon.
Item {
    id: root
    anchors.fill: parent
    visible: opacity > 0
    opacity: 0
    Behavior on opacity { NumberAnimation { duration: 140 } }

    property string appKey: ""
    property string currentPath: ""
    property string currentName: ""

    // Snapshots for Cancel revert
    property string _originalPath: ""
    property string _originalName: ""

    signal pathChanged(string appKey, string path)
    signal nameChanged(string appKey, string name)
    signal deleteRequested(string appKey)
    signal closed()

    function open(appKey, currentPath, currentName) {
        root.appKey = appKey
        root.currentPath = currentPath || ""
        root.currentName = currentName || ""
        root._originalPath = root.currentPath
        root._originalName = root.currentName
        nameField.text = root.currentName
        opacity = 1
        Qt.callLater(() => nameField.forceActiveFocus())
    }
    function close() { opacity = 0; root.closed() }
    function _commit() {
        root.nameChanged(root.appKey, nameField.text)
        root.close()
    }
    function _cancel() {
        // Revert any icon change made during this session
        if (root.currentPath !== root._originalPath) {
            root.pathChanged(root.appKey, root._originalPath)
        }
        // Don't commit name field (TextInput state is local until commit)
        root.close()
    }

    function _resolved(p) {
        if (!p) return ""
        if (p.startsWith("/")) return "file://" + p
        return p
    }
    function _autoResolveIcon() {
        try {
            const e = DesktopEntries.heuristicLookup(appKey)
            let r = Quickshell.iconPath(e ? e.icon : "", true)
            if (r) return r
            r = Quickshell.iconPath(appKey, true)
            if (r) return r
            return Quickshell.iconPath(appKey.toLowerCase(), true) || ""
        } catch (err) { return "" }
    }

    Rectangle {
        anchors.fill: parent
        color: "#000"
        opacity: 0.55
        MouseArea { anchors.fill: parent; onClicked: root._cancel() }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 480
        height: dialogCol.implicitHeight + Theme.spacingXL * 2
        radius: Theme.radiusL
        color: Theme.surfaceHigh
        border.color: Theme.outlineVariant
        border.width: 1
        clip: true

        Column {
            id: dialogCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacingXL
            spacing: Theme.spacingL

            // Header — title + raw appKey subheader
            Column {
                width: parent.width
                spacing: 2
                Text {
                    text: "App settings"
                    color: Theme.text
                    font.pixelSize: Theme.fontXl
                    font.weight: Font.DemiBold
                }
                Text {
                    width: parent.width
                    text: root.appKey
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSm
                    font.family: "monospace"
                    elide: Text.ElideMiddle
                }
            }

            // Icon (clickable) + Display name (inline)
            Row {
                width: parent.width
                spacing: Theme.spacingM

                Rectangle {
                    id: iconBox
                    width: 56; height: 56
                    radius: Theme.radius
                    color: iconMA.containsMouse ? Theme.surfaceLow : Theme.background
                    border.color: iconMA.containsMouse ? Theme.primary : Theme.outlineVariant
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on border.color { ColorAnimation { duration: 100 } }

                    Image {
                        anchors.centerIn: parent
                        width: 40; height: 40
                        source: root.currentPath
                                ? root._resolved(root.currentPath)
                                : root._autoResolveIcon()
                        sourceSize.width: 80; sourceSize.height: 80
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    // Small × overlay (only when custom icon is set, on hover)
                    Rectangle {
                        visible: root.currentPath.length > 0 && (iconMA.containsMouse || rmMA.containsMouse)
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: -6
                        anchors.rightMargin: -6
                        width: 20; height: 20; radius: 10
                        color: rmMA.containsMouse ? Theme.error : Theme.surfaceHigh
                        border.color: Theme.error
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text {
                            anchors.centerIn: parent
                            text: "×"
                            color: rmMA.containsMouse ? Theme.primaryFg : Theme.error
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }
                        MouseArea {
                            id: rmMA
                            anchors.fill: parent
                            anchors.margins: -2
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.pathChanged(root.appKey, "")
                                root.currentPath = ""
                            }
                        }
                    }

                    MouseArea {
                        id: iconMA
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: filePicker.open()
                    }
                }

                // Display name field
                Rectangle {
                    width: parent.width - iconBox.width - Theme.spacingM
                    height: 56
                    radius: Theme.radius
                    color: Theme.background
                    border.color: nameField.activeFocus ? Theme.primary : Theme.outlineVariant
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 100 } }

                    Column {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingM
                        anchors.rightMargin: Theme.spacingM
                        anchors.topMargin: 6
                        anchors.bottomMargin: 6
                        spacing: 0

                        Text {
                            text: "Display name"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSm - 1
                        }
                        TextInput {
                            id: nameField
                            width: parent.width
                            height: parent.height - 16
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.text
                            font.pixelSize: Theme.fontMd
                            selectByMouse: true
                            selectionColor: Theme.primary
                            selectedTextColor: Theme.primaryFg
                            maximumLength: 40
                            clip: true
                            Keys.onReturnPressed: root._commit()
                            Keys.onEnterPressed:  root._commit()
                            Keys.onEscapePressed: root._cancel()
                        }
                    }
                }
            }

            // Action row — Delete (left) + Cancel + Done (right)
            Item {
                width: parent.width
                height: 36

                // Delete (destructive, left)
                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: delTxt.implicitWidth + Theme.spacingL
                    height: 36
                    radius: Theme.radiusS
                    color: delMA2.containsMouse
                                ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.18)
                                : "transparent"
                    border.color: Theme.error
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Text {
                        id: delTxt
                        anchors.centerIn: parent
                        text: "Delete app"
                        color: Theme.error
                        font.pixelSize: Theme.fontMd
                        font.weight: Font.Medium
                    }
                    MouseArea {
                        id: delMA2
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.deleteRequested(root.appKey)
                            root.close()
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingS

                    Rectangle {
                        width: cancelTxt.implicitWidth + Theme.spacingL
                        height: 36
                        radius: Theme.radiusS
                        color: cancelMA.containsMouse ? Theme.surfaceLow : "transparent"
                        border.color: Theme.outline
                        border.width: 1
                        Text { id: cancelTxt; anchors.centerIn: parent; text: "Cancel"; color: Theme.text; font.pixelSize: Theme.fontMd }
                        MouseArea { id: cancelMA; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root._cancel() }
                    }

                    Rectangle {
                        width: closeTxt.implicitWidth + Theme.spacingL
                        height: 36
                        radius: Theme.radiusS
                        color: closeMA.containsMouse
                                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.85)
                                    : Theme.primary
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text {
                            id: closeTxt
                            anchors.centerIn: parent
                            text: "Done"
                            color: Theme.primaryFg
                            font.pixelSize: Theme.fontMd
                            font.weight: Font.Medium
                        }
                        MouseArea {
                            id: closeMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root._commit()
                        }
                    }
                }
            }
        }
    }

    FileDialog {
        id: filePicker
        title: "Choose an icon"
        nameFilters: ["Images (*.png *.svg *.ico *.jpg *.jpeg *.webp)"]
        onAccepted: {
            const url = selectedFile.toString()
            const path = url.startsWith("file://") ? url.substring(7) : url
            root.pathChanged(root.appKey, path)
            root.currentPath = path
        }
    }
}
