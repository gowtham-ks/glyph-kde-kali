import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground | PlasmaCore.Types.ConfigurableBackground

    readonly property int pollMs: 2000
    property real rxRate: 0      // bytes per second
    property real txRate: 0
    property real lastRx: -1
    property real lastTx: -1

    P5Support.DataSource {
        engine: "executable"
        interval: root.pollMs
        connectedSources: ["awk 'NR>2{gsub(\":\",\" \"); if($1!=\"lo\"){rx+=$2; tx+=$10}} END{print rx+0, tx+0}' /proc/net/dev"]
        onNewData: function (source, data) { root.parse(data["stdout"]) }
    }

    function parse(out) {
        var p = String(out).trim().split(/\s+/).map(Number)
        if (p.length < 2 || isNaN(p[0]) || isNaN(p[1]))
            return
        if (lastRx >= 0 && p[0] >= lastRx && p[1] >= lastTx) {
            rxRate = (p[0] - lastRx) / (pollMs / 1000)
            txRate = (p[1] - lastTx) / (pollMs / 1000)
        }
        lastRx = p[0]
        lastTx = p[1]
    }

    function human(b) {
        if (b < 1024) return Math.round(b) + " B/s"
        if (b < 1048576) return (b / 1024).toFixed(1) + " KB/s"
        return (b / 1048576).toFixed(2) + " MB/s"
    }

    // 0..1 on a log scale from 1 KB/s to 100 MB/s
    function level(b) {
        if (b < 1024) return 0
        return Math.max(0, Math.min(1, Math.log(b / 1024) / Math.log(100000)))
    }

    fullRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 12
        Layout.minimumHeight: Kirigami.Units.gridUnit * 5
        Layout.preferredWidth: Kirigami.Units.gridUnit * 16
        Layout.preferredHeight: Kirigami.Units.gridUnit * 6

        ColumnLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.largeSpacing

            Repeater {
                model: [
                    { tag: "DOWN", rate: root.rxRate },
                    { tag: "UP",   rate: root.txRate }
                ]
                RowLayout {
                    id: line
                    readonly property real rate: modelData.rate
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Kirigami.Units.largeSpacing

                    Text {
                        text: modelData.tag
                        color: Kirigami.Theme.textColor
                        opacity: 0.6
                        font.family: "monospace"
                        font.letterSpacing: 2
                        font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.75)
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 3
                    }
                    Row {
                        id: dots
                        spacing: 3
                        Layout.alignment: Qt.AlignVCenter
                        Repeater {
                            model: 20
                            Rectangle {
                                width: 6; height: 6; radius: 3
                                color: index < Math.round(root.level(line.rate) * 20)
                                       ? Kirigami.Theme.highlightColor
                                       : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.14)
                            }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        text: root.human(line.rate)
                        color: Kirigami.Theme.textColor
                        font.family: "monospace"
                        font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.8)
                    }
                }
            }
        }
    }
}
