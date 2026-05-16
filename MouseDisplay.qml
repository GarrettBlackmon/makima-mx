import QtQuick
import "."

// Mouse image + clickable button overlays.
// Button positions are percentages of the rendered image rect so they scale
// with the image.
Item {
    id: root

    property string activeButton: ""
    property string hoveredButton: ""
    signal buttonClicked(string id)
    signal buttonHovered(string id)
    signal buttonExited(string id)

    property bool showOverlays: true

    readonly property real pad: 0.038
    readonly property var buttons: [
        { id: "left",    label: "Left Click",   x: 0.457, y: 0.194 },
        { id: "right",   label: "Right Click",  x: 0.577, y: 0.207 },
        { id: "wheel",   label: "Scroll Wheel", x: 0.564, y: 0.271 },
        { id: "back",    label: "Back",         x: 0.433, y: 0.510 },
        { id: "forward", label: "Forward",      x: 0.417, y: 0.456 },
        { id: "gesture", label: "Gesture",      x: 0.299, y: 0.549 }
    ]

    Image {
        id: img
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        source: Qt.resolvedUrl("assets/mouse.png")
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true

        readonly property real renderedW: paintedWidth
        readonly property real renderedH: paintedHeight
        readonly property real renderedX: (width - paintedWidth) / 2
        readonly property real renderedY: (height - paintedHeight) / 2

        Item {
            id: overlay
            x: img.renderedX
            y: img.renderedY
            width: img.renderedW
            height: img.renderedH

            Repeater {
                model: root.buttons
                delegate: Item {
                    id: hitArea
                    required property var modelData
                    x: modelData.x * overlay.width
                    y: modelData.y * overlay.height
                    width:  root.pad * overlay.width
                    height: root.pad * overlay.width

                    readonly property bool isHovered: root.hoveredButton === modelData.id
                    readonly property bool isActive:  root.activeButton === modelData.id

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: hitArea.isActive
                                   ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                               : hitArea.isHovered
                                   ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
                               : root.showOverlays
                                   ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                                   : "transparent"
                        border.color: hitArea.isActive
                                          ? Theme.primary
                                      : hitArea.isHovered
                                          ? Theme.primary
                                      : root.showOverlays
                                          ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.6)
                                          : "transparent"
                        border.width: hitArea.isActive ? 2 : hitArea.isHovered ? 2 : 1
                        Behavior on color  { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }
                    }

                    // Hover/active tooltip
                    Rectangle {
                        visible: hitArea.isHovered || hitArea.isActive
                        anchors.bottom: parent.top
                        anchors.bottomMargin: 6
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: lbl.implicitWidth + Theme.spacingM
                        height: lbl.implicitHeight + Theme.spacingS
                        radius: Theme.radiusS
                        color: Theme.surfaceHigh
                        border.color: Theme.outlineVariant
                        border.width: 1
                        z: 10
                        Text {
                            id: lbl
                            anchors.centerIn: parent
                            text: modelData.label
                            color: Theme.text
                            font.pixelSize: Theme.fontSm
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.buttonHovered(modelData.id)
                        onExited:  root.buttonExited(modelData.id)
                        onClicked: root.buttonClicked(modelData.id)
                    }
                }
            }
        }
    }
}
