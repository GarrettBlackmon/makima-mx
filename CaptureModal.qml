import QtQuick
import "."
import "KeyMap.js" as KM

// Modal for capturing a key combo. Auto-saves on full release.
// Esc cancels. Backdrop click cancels.
Item {
    id: root
    anchors.fill: parent
    visible: opacity > 0
    opacity: 0
    Behavior on opacity { NumberAnimation { duration: 140 } }

    property string buttonLabel: ""
    property string currentBinding: ""

    // Live capture state
    property var heldKeys: ({})      // Qt.Key -> "KEY_*" while pressed
    property var comboKeys: []       // capture order ("KEY_*"), what we'll save
    property bool everPressed: false

    signal cancelled()
    signal captured(var keyNames)    // array of "KEY_*"
    signal reset()                   // clear the binding (return to default)

    function open(label, current) {
        buttonLabel = label
        currentBinding = current
        heldKeys = ({})
        comboKeys = []
        everPressed = false
        opacity = 1
        // Defer so focus lands after the modal becomes visible
        Qt.callLater(() => focusCatcher.forceActiveFocus())
    }
    function close() {
        opacity = 0
        heldKeys = ({})
        comboKeys = []
        everPressed = false
    }

    function _previewLabel() {
        if (comboKeys.length === 0) return "Press the key(s) to bind…"
        return KM.comboLabel(comboKeys)
    }

    // Backdrop — also catches keyboard focus
    Rectangle {
        anchors.fill: parent
        color: "#000"
        opacity: 0.55
        MouseArea {
            anchors.fill: parent
            onClicked: { root.cancelled(); root.close(); }
        }
    }

    // Invisible focus catcher — holds focus while the modal is open
    Item {
        id: focusCatcher
        anchors.fill: parent
        focus: root.opacity > 0.5
        Keys.onPressed: (event) => {
            if (event.isAutoRepeat) { event.accepted = true; return }
            const name = KM.fromQtKey(event.key)
            if (!name) { event.accepted = true; return }
            if (!root.heldKeys[event.key]) {
                root.heldKeys[event.key] = name
                root.heldKeys = root.heldKeys      // poke binding
                root.comboKeys = root.comboKeys.concat([name])
                root.everPressed = true
            }
            event.accepted = true
        }
        Keys.onReleased: (event) => {
            if (event.isAutoRepeat) { event.accepted = true; return }
            if (root.heldKeys[event.key]) {
                delete root.heldKeys[event.key]
                root.heldKeys = root.heldKeys      // poke binding
            }
            // All keys released and we captured something → commit
            if (root.everPressed && Object.keys(root.heldKeys).length === 0) {
                root.captured(root.comboKeys)
                root.close()
            }
            event.accepted = true
        }
    }

    // Dialog
    Rectangle {
        anchors.centerIn: parent
        width: 480
        height: 260
        radius: Theme.radiusL
        color: Theme.surfaceHigh
        border.color: Theme.outlineVariant
        border.width: 1

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingXL
            spacing: Theme.spacingL

            Text {
                text: "Rebind " + root.buttonLabel
                color: Theme.text
                font.pixelSize: Theme.fontXl
                font.weight: Font.DemiBold
            }

            // Live capture display
            Rectangle {
                width: parent.width
                height: 90
                radius: Theme.radius
                color: Theme.background
                border.color: Theme.primary
                border.width: 1
                Column {
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        text: root._previewLabel()
                        color: Theme.primary
                        font.pixelSize: Theme.fontXl
                        font.family: root.comboKeys.length > 0 ? "monospace" : "sans-serif"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Text {
                        text: root.everPressed
                              ? "Release all keys to save"
                              : "Listening… Cancel to abort"
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSm
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
                SequentialAnimation on border.color {
                    loops: Animation.Infinite
                    running: root.opacity > 0.5 && !root.everPressed
                    ColorAnimation { to: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3); duration: 800 }
                    ColorAnimation { to: Theme.primary; duration: 800 }
                }
            }

            // Current + actions
            Item {
                width: parent.width
                height: 36

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingM
                    Text {
                        text: "Current:"
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontMd
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: ct.implicitWidth + Theme.spacingM
                        height: ct.implicitHeight + Theme.spacingS
                        radius: Theme.radiusS
                        color: Theme.surfaceLow
                        border.color: Theme.outlineVariant
                        border.width: 1
                        Text {
                            id: ct
                            anchors.centerIn: parent
                            text: root.currentBinding || "—"
                            color: Theme.text
                            font.pixelSize: Theme.fontSm
                            font.family: "monospace"
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingS

                    Rectangle {
                        width: cancelText.implicitWidth + Theme.spacingL
                        height: 36
                        radius: Theme.radiusS
                        color: cancelMA.containsMouse ? Theme.surfaceLow : "transparent"
                        border.color: Theme.outline
                        border.width: 1
                        Text {
                            id: cancelText
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: Theme.text
                            font.pixelSize: Theme.fontMd
                        }
                        MouseArea { id: cancelMA; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { root.cancelled(); root.close(); } }
                    }

                    Rectangle {
                        width: resetText.implicitWidth + Theme.spacingL
                        height: 36
                        radius: Theme.radiusS
                        color: resetMA.containsMouse
                                    ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.18)
                                    : "transparent"
                        border.color: Theme.error
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text {
                            id: resetText
                            anchors.centerIn: parent
                            text: "Reset"
                            color: Theme.error
                            font.pixelSize: Theme.fontMd
                            font.weight: Font.Medium
                        }
                        MouseArea { id: resetMA; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { root.reset(); root.close(); } }
                    }
                }
            }
        }
    }
}
