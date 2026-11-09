import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground | PlasmaCore.Types.ConfigurableBackground

    property date today: new Date()
    property int shownYear: today.getFullYear()
    property int shownMonth: today.getMonth()

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: root.today = new Date()
    }

    function cells() {
        var first = new Date(shownYear, shownMonth, 1)
        var offset = (first.getDay() + (Plasmoid.configuration.weekStart === 1 ? 0 : 6)) % 7
        var days = new Date(shownYear, shownMonth + 1, 0).getDate()
        var out = []
        for (var i = 0; i < 42; ++i) {
            var d = i - offset + 1
            var ok = d >= 1 && d <= days
            out.push({
                day: ok ? d : 0,
                isToday: ok && d === today.getDate() && shownMonth === today.getMonth() && shownYear === today.getFullYear()
            })
        }
        return out
    }

    function shift(delta) {
        var m = shownMonth + delta
        shownYear += Math.floor(m / 12)
        shownMonth = ((m % 12) + 12) % 12
    }

    fullRepresentation: Item {
        id: face
        Layout.minimumWidth: Kirigami.Units.gridUnit * 12
        Layout.minimumHeight: Kirigami.Units.gridUnit * 11
        Layout.preferredWidth: Kirigami.Units.gridUnit * 15
        Layout.preferredHeight: Kirigami.Units.gridUnit * 13

        readonly property real cell: Math.min(width / 7, (height - header.height - Kirigami.Units.smallSpacing) / 7)
        readonly property var weekdays: Plasmoid.configuration.weekStart === 1
            ? ["S", "M", "T", "W", "T", "F", "S"] : ["M", "T", "W", "T", "F", "S", "S"]

        RowLayout {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Kirigami.Units.gridUnit * 1.6

            Text {
                text: "<"
                color: Kirigami.Theme.textColor
                font.family: "monospace"
                font.pixelSize: Kirigami.Units.gridUnit
                Layout.leftMargin: Kirigami.Units.largeSpacing
                MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: root.shift(-1) }
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: Qt.locale().monthName(root.shownMonth, Locale.LongFormat).toUpperCase() + "  " + root.shownYear
                color: Kirigami.Theme.textColor
                font.family: "monospace"
                font.letterSpacing: 2
                font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.85)
            }
            Text {
                text: ">"
                color: Kirigami.Theme.textColor
                font.family: "monospace"
                font.pixelSize: Kirigami.Units.gridUnit
                Layout.rightMargin: Kirigami.Units.largeSpacing
                MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: root.shift(1) }
            }
        }

        Grid {
            anchors.top: header.bottom
            anchors.topMargin: Kirigami.Units.smallSpacing
            anchors.horizontalCenter: parent.horizontalCenter
            columns: 7

            Repeater {
                model: face.weekdays
                Item {
                    width: face.cell; height: face.cell
                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: Kirigami.Theme.textColor
                        opacity: 0.45
                        font.family: "monospace"
                        font.pixelSize: Math.round(face.cell * 0.38)
                    }
                }
            }
            Repeater {
                model: root.cells()
                Item {
                    width: face.cell; height: face.cell
                    Rectangle {
                        anchors.centerIn: parent
                        width: face.cell * 0.82; height: width; radius: width / 2
                        visible: modelData.isToday
                        color: Kirigami.Theme.highlightColor
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: modelData.day > 0
                        text: modelData.day
                        color: modelData.isToday ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                        font.family: "monospace"
                        font.pixelSize: Math.round(face.cell * 0.4)
                    }
                }
            }
        }
    }
}
