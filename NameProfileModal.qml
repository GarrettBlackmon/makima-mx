import QtQuick
import "."

// Simple text-input modal for creating / renaming a profile.
Item {
    id: root
    anchors.fill: parent
    visible: opacity > 0
    opacity: 0
    Behavior on opacity { NumberAnimation { duration: 140 } }

    property string title: "New profile"
    property string placeholder: "Name (e.g. Work)"
    property string initial: ""
    property var existing: []        // names already in use, to block duplicates

    signal confirmed(string name)
    signal cancelled()

    function open(title, placeholder, initial, existing) {
        root.title = title || "New profile"
        root.placeholder = placeholder || "Name"
        root.initial = initial || ""
        root.existing = existing || []
        nameField.text = root.initial
        opacity = 1
        Qt.callLater(() => nameField.forceActiveFocus())
    }
    function close() { opacity = 0 }

    readonly property bool valid: {
        const t = nameField.text.trim()
        if (t.length === 0) return false
        if (t.length > 32) return false
        for (let i = 0; i < existing.length; i++) {
            if (existing[i] === t && t !== initial) return false
        }
        return true
    }

    // Backdrop
    Rectangle {
        anchors.fill: parent
        color: "#000"
        opacity: 0.55
        MouseArea { anchors.fill: parent; onClicked: { root.cancelled(); root.close(); } }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 420
        height: 200
        radius: Theme.radiusL
        color: Theme.surfaceHigh
        border.color: Theme.outlineVariant
        border.width: 1

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingXL
            spacing: Theme.spacingL

            Text {
                text: root.title
                color: Theme.text
                font.pixelSize: Theme.fontXl
                font.weight: Font.DemiBold
            }

            Rectangle {
                width: parent.width
                height: 40
                radius: Theme.radius
                color: Theme.background
                border.color: nameField.activeFocus ? Theme.primary : Theme.outlineVariant
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 100 } }

                TextInput {
                    id: nameField
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingM
                    anchors.rightMargin: Theme.spacingM
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.pixelSize: Theme.fontMd
                    selectByMouse: true
                    selectionColor: Theme.primary
                    selectedTextColor: Theme.primaryFg
                    maximumLength: 32
                    Keys.onReturnPressed: if (root.valid) { root.confirmed(nameField.text.trim()); root.close() }
                    Keys.onEnterPressed:  if (root.valid) { root.confirmed(nameField.text.trim()); root.close() }
                    Keys.onEscapePressed: { root.cancelled(); root.close() }
                }
                // Placeholder
                Text {
                    visible: nameField.text.length === 0
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingM
                    verticalAlignment: Text.AlignVCenter
                    text: root.placeholder
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontMd
                    opacity: 0.7
                }
            }

            // Buttons
            Item {
                width: parent.width
                height: 36

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingS

                    Rectangle {
                        width: cancelTxt.implicitWidth + Theme.spacingL
                        height: 36
                        radius: Theme.radiusS
                        color: cancelMA.containsMouse ? Theme.surfaceLow : "transparent"
                        Text {
                            id: cancelTxt
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontMd
                        }
                        MouseArea { id: cancelMA; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { root.cancelled(); root.close() } }
                    }
                    Rectangle {
                        width: createTxt.implicitWidth + Theme.spacingL
                        height: 36
                        radius: Theme.radiusS
                        color: !root.valid
                                   ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
                               : createMA.containsMouse
                                   ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.85)
                                   : Theme.primary
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text {
                            id: createTxt
                            anchors.centerIn: parent
                            text: "Create"
                            color: Theme.primaryFg
                            font.pixelSize: Theme.fontMd
                            font.weight: Font.Medium
                        }
                        MouseArea {
                            id: createMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: root.valid ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled: root.valid
                            onClicked: { root.confirmed(nameField.text.trim()); root.close() }
                        }
                    }
                }
            }
        }
    }
}
