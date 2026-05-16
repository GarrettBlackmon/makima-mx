import QtQuick
import QtQuick.Controls
import "."

Item {
    id: root
    property var bindings: ({})
    property var buttonOrder: []
    property string activeButton: ""
    property string hoveredButton: ""
    signal rowClicked(string id)
    signal rowHovered(string id)
    signal rowExited(string id)

    Rectangle {
        anchors.fill: parent
        color: Theme.surfaceLow
        radius: Theme.radius

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingS

            // Header
            Item {
                width: parent.width
                height: 24
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Bindings"
                    color: Theme.text
                    font.pixelSize: Theme.fontLg
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.buttonOrder.length + " buttons"
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSm
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.outlineVariant
                opacity: 0.5
            }

            ListView {
                width: parent.width
                height: parent.height - 60
                clip: true
                spacing: Theme.spacingXS
                model: root.buttonOrder

                delegate: Rectangle {
                    required property string modelData
                    readonly property var binding: root.bindings[modelData] || { label: modelData, keys: "—", isDefault: true }
                    readonly property bool isActive:  root.activeButton  === modelData
                    readonly property bool isHovered: root.hoveredButton === modelData

                    width: ListView.view.width
                    height: 54
                    radius: Theme.radiusS
                    color: isActive
                              ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
                           : isHovered
                              ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.06)
                              : "transparent"
                    border.color: isActive ? Theme.primary : "transparent"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 100 } }

                    // Label (left)
                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                        anchors.right: keysChip.left
                        anchors.rightMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            text: binding.label
                            color: Theme.text
                            font.pixelSize: Theme.fontMd
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            width: parent.width
                        }
                        Text {
                            text: binding.isDefault ? "default" : "remapped"
                            color: binding.isDefault ? Theme.textMuted : Theme.primary
                            font.pixelSize: Theme.fontSm
                            opacity: binding.isDefault ? 0.7 : 1
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }

                    // Key chip (right)
                    Rectangle {
                        id: keysChip
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: keyText.implicitWidth + Theme.spacingM
                        implicitHeight: keyText.implicitHeight + Theme.spacingS
                        radius: Theme.radiusS
                        color: Theme.surfaceHigh
                        border.color: Theme.outlineVariant
                        border.width: 1
                        Text {
                            id: keyText
                            anchors.centerIn: parent
                            text: binding.keys
                            color: Theme.text
                            font.pixelSize: Theme.fontSm
                            font.family: "monospace"
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.rowHovered(modelData)
                        onExited:  root.rowExited(modelData)
                        onClicked: root.rowClicked(modelData)
                    }
                }
            }
        }
    }
}
