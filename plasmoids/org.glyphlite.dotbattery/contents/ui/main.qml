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

    property bool present: false
    property real level: 0
    property string chargeState: ""

    P5Support.DataSource {
        engine: "executable"
        interval: 30000
        connectedSources: ["for b in /sys/class/power_supply/BAT*; do [ -r \"$b/capacity\" ] && echo \"$(cat $b/capacity) $(cat $b/status)\" && break; done"]
        onNewData: function (source, data) { root.parse(data["stdout"]) }
    }

    function parse(out) {
        var s = String(out).trim()
        if (s === "") {
            present = false
            return
        }
        var parts = s.split(/\s+/)
        var pct = parseInt(parts[0])
        if (isNaN(pct)) {
            present = false
            return
        }
        present = true
        level = Math.max(0, Math.min(1, pct / 100))
        chargeState = parts.slice(1).join(" ").toUpperCase()
    }

    fullRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 8
        Layout.minimumHeight: Kirigami.Units.gridUnit * 8
        Layout.preferredWidth: Kirigami.Units.gridUnit * 10
        Layout.preferredHeight: Kirigami.Units.gridUnit * 10

        Canvas {
            id: ring
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) * 0.9
            height: width

            Connections {
                target: root
                function onLevelChanged() { ring.requestPaint() }
                function onPresentChanged() { ring.requestPaint() }
            }
            onWidthChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                var n = 48
                var dr = width * 0.03
                var R = width / 2 - dr - 1
                var lit = root.present ? Math.round(root.level * n) : 0
                var tc = Kirigami.Theme.textColor
                var low = root.present && root.level <= 0.2
                for (var i = 0; i < n; ++i) {
                    var a = -Math.PI / 2 + 2 * Math.PI * i / n
                    ctx.fillStyle = i < lit ? (low ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.highlightColor)
                                            : Qt.rgba(tc.r, tc.g, tc.b, 0.14)
                    ctx.beginPath()
                    ctx.arc(width / 2 + R * Math.cos(a), height / 2 + R * Math.sin(a), dr, 0, Math.PI * 2)
                    ctx.fill()
                }
            }
        }

        ColumnLayout {
            anchors.centerIn: ring
            spacing: 0
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.present ? Math.round(root.level * 100) + "%" : "--"
                color: Kirigami.Theme.textColor
                font.family: "monospace"
                font.pixelSize: Math.round(ring.width * 0.2)
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.present ? root.chargeState : "NO BATTERY"
                color: Kirigami.Theme.textColor
                opacity: 0.6
                font.family: "monospace"
                font.letterSpacing: 2
                font.pixelSize: Math.max(9, Math.round(ring.width * 0.07))
            }
        }
    }
}
