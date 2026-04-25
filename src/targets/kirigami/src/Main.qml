import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
    id: root

    width: 500
    height: 400

    title: backend.title

    pageStack.initialPage: Kirigami.ScrollablePage {
        title: backend.title

        ColumnLayout {
            width: parent.width
            spacing: Kirigami.Units.largeSpacing

            Repeater {
                model: backend.sections

                delegate: ColumnLayout {
                    id: sectionDelegate
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    // displayValue section
                    Kirigami.Card {
                        visible: sectionDelegate.modelData.contentType === "displayValue"
                        Layout.fillWidth: true

                        header: Kirigami.Heading {
                            text: sectionDelegate.modelData.label ?? ""
                            level: 3
                            padding: Kirigami.Units.smallSpacing
                        }

                        contentItem: Controls.Label {
                            text: sectionDelegate.modelData.value ?? ""
                            font.pointSize: 18
                            horizontalAlignment: Text.AlignHCenter
                            padding: Kirigami.Units.largeSpacing

                            Controls.ToolTip.text: sectionDelegate.modelData.tooltip ?? ""
                            Controls.ToolTip.visible: sectionDelegate.modelData.tooltip ? tooltipArea.containsMouse : false

                            MouseArea {
                                id: tooltipArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }
                        }
                    }

                    // actionGroup section
                    RowLayout {
                        visible: sectionDelegate.modelData.contentType === "actionGroup"
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        Repeater {
                            model: sectionDelegate.modelData.actions ?? []

                            delegate: Controls.Button {
                                required property var modelData
                                text: modelData.name

                                Controls.ToolTip.text: modelData.tooltip ?? ""
                                Controls.ToolTip.visible: hovered && (modelData.tooltip ?? "") !== ""

                                onClicked: backend.invokeAction(modelData.actionIndex)
                            }
                        }
                    }
                }
            }
        }
    }
}
