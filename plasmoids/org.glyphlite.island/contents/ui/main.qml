import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

// A pill for a panel: dot-matrix time, short date and a CPU dot.
// Click it for a popup with big time, CPU/RAM/disk rings and a dark/light switch.
PlasmoidItem {
    id: root

    preferredRepresentation: compactRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    property date now: new Date()
    property real cpu: 0
    property real ram: 0
    property real disk: 0
    property real lastBusy: -1
    property real lastTotal: -1

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            var d = new Date()
            if (d.getMinutes() !== root.now.getMinutes() || d.getDate() !== root.now.getDate())
                root.now = d
        }
    }

    P5Support.DataSource {
        engine: "executable"
        interval: root.expanded ? 3000 : 10000
        connectedSources: ["awk '/^cpu /{print $2+$3+$4+$7, $2+$3+$4+$5+$6+$7+$8}' /proc/stat; awk '/^MemTotal/{t=$2} /^MemAvailable/{a=$2} END{print t, a}' /proc/meminfo; df --output=pcent / | tail -n 1"]
        onNewData: function (source, data) { root.parse(data["stdout"]) }
    }

    P5Support.DataSource {
        id: runner
        engine: "executable"
        onNewData: function (source, data) { disconnectSource(source) }
    }

    function parse(out) {
        var lines = String(out).trim().split("\n")
        if (lines.length < 3)
            return
        var c = lines[0].trim().split(/\s+/).map(Number)
        if (lastTotal >= 0 && c[1] > lastTotal)
            cpu = Math.max(0, Math.min(1, (c[0] - lastBusy) / (c[1] - lastTotal)))
        lastBusy = c[0]
        lastTotal = c[1]
        var m = lines[1].trim().split(/\s+/).map(Number)
        if (m[0] > 0)
            ram = Math.max(0, Math.min(1, 1 - m[1] / m[0]))
        var dsk = parseInt(lines[2].trim())
        if (!isNaN(dsk))
            disk = dsk / 100
    }

    compactRepresentation: Item {
        id: compact
        readonly property real pad: Kirigami.Units.smallSpacing * 3
        Layout.minimumWidth: row.implicitWidth + pad * 2
        Layout.preferredWidth: Layout.minimumWidth
        Layout.minimumHeight: Kirigami.Units.gridUnit * 1.4

        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: height / 2
            color: Qt.rgba(Kirigami.Theme.backgroundColor.r, Kirigami.Theme.backgroundColor.g, Kirigami.Theme.backgroundColor.b, 0.9)
            border.width: Plasmoid.configuration.showBorder ? 1 : 0
            border.color: root.expanded ? Kirigami.Theme.highlightColor
                                        : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.22)
        }

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing * 2

            DotTime {
                time: root.now
                use24h: Plasmoid.configuration.use24h
                cellSize: Math.max(2, Math.floor((compact.height - 6) / 7))
                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: implicitHeight
            }
            Text {
                visible: Plasmoid.configuration.showDate
                text: Qt.formatDate(root.now, ["ddd d", "d MMM", "dd/MM"][Plasmoid.configuration.dateStyle] || "ddd d").toUpperCase()
                color: Kirigami.Theme.textColor
                opacity: 0.7
                font.family: "monospace"
                font.pixelSize: Math.max(10, Math.round(compact.height * 0.38))
            }
            Rectangle {
                visible: Plasmoid.configuration.showCpuDot
                width: Math.max(6, Math.round(compact.height * 0.22)); height: width; radius: width / 2
                color: root.cpu > 0.85 ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.highlightColor
                opacity: 0.35 + 0.65 * root.cpu
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }
    }

    fullRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 18
        Layout.minimumHeight: Kirigami.Units.gridUnit * 14
        Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        Layout.preferredHeight: Kirigami.Units.gridUnit * 16

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            DotTime {
                Layout.alignment: Qt.AlignHCenter
                use24h: Plasmoid.configuration.use24h
                time: root.now
                cellSize: Math.max(3, Math.floor((parent.width - 2 * Kirigami.Units.largeSpacing) / 25))
                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: implicitHeight
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDate(root.now, "dddd d MMMM").toUpperCase()
                color: Kirigami.Theme.textColor
                opacity: 0.6
                font.family: "monospace"
                font.letterSpacing: 3
                font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.8)
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Kirigami.Units.largeSpacing
                Meter { Layout.fillWidth: true; Layout.fillHeight: true; value: root.cpu;  label: "CPU" }
                Meter { Layout.fillWidth: true; Layout.fillHeight: true; value: root.ram;  label: "RAM" }
                Meter { Layout.fillWidth: true; Layout.fillHeight: true; value: root.disk; label: "DSK" }
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: toggleLabel.implicitWidth + Kirigami.Units.gridUnit * 2
                implicitHeight: toggleLabel.implicitHeight + Kirigami.Units.smallSpacing * 3
                radius: height / 2
                color: "transparent"
                border.width: 1
                border.color: Kirigami.Theme.highlightColor
                Text {
                    id: toggleLabel
                    anchors.centerIn: parent
                    text: "DARK / LIGHT"
                    color: Kirigami.Theme.highlightColor
                    font.family: "monospace"
                    font.letterSpacing: 2
                    font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.75)
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: runner.connectSource("\"$HOME/.local/bin/glyph-lite-mode\" toggle")
                }
            }
        }
    }
}
