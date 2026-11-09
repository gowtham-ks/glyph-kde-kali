import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground | PlasmaCore.Types.ConfigurableBackground

    property date now: new Date()

    // Cheap: ticks once a second but only changes `now` (and repaints) when the minute changes.
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

    fullRepresentation: Item {
        id: face
        Layout.minimumWidth: Kirigami.Units.gridUnit * 12
        Layout.minimumHeight: Kirigami.Units.gridUnit * 6
        Layout.preferredWidth: Kirigami.Units.gridUnit * 18
        Layout.preferredHeight: Kirigami.Units.gridUnit * 8

        readonly property var glyphs: ({
            "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
            "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
            "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
            "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
            "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
            "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
            "6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
            "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
            "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
            "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
            ":": ["0", "1", "0", "0", "0", "1", "0"]
        })

        Canvas {
            id: canvas
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: Plasmoid.configuration.showDate ? dateLabel.top : parent.bottom
            anchors.bottomMargin: Kirigami.Units.smallSpacing

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                var cols = 25, rows = 7
                var cell = Math.min(width / cols, height / rows)
                if (cell <= 0)
                    return
                var r = cell * 0.36
                var ox = (width - cell * cols) / 2
                var oy = (height - cell * rows) / 2
                var tc = Kirigami.Theme.textColor
                var hc = Kirigami.Theme.highlightColor
                var off = Qt.rgba(tc.r, tc.g, tc.b, 0.10)
                var d = root.now
                var hour = d.getHours()
                if (!Plasmoid.configuration.use24h) {
                    hour = hour % 12
                    if (hour === 0)
                        hour = 12
                }
                var hh = (hour < 10 ? "0" : "") + hour
                var mm = Qt.formatTime(d, "mm")
                var seq = [hh.charAt(0), hh.charAt(1), ":", mm.charAt(0), mm.charAt(1)]
                var x = 0
                for (var i = 0; i < seq.length; ++i) {
                    var g = face.glyphs[seq[i]]
                    var w = g[0].length
                    for (var row = 0; row < rows; ++row) {
                        for (var col = 0; col < w; ++col) {
                            var on = g[row].charAt(col) === "1"
                            ctx.fillStyle = on ? (seq[i] === ":" ? hc : tc) : off
                            ctx.beginPath()
                            ctx.arc(ox + (x + col + 0.5) * cell, oy + (row + 0.5) * cell, r, 0, Math.PI * 2)
                            ctx.fill()
                        }
                    }
                    x += w + 1
                }
            }
        }

        Text {
            id: dateLabel
            visible: Plasmoid.configuration.showDate
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(root.now, "ddd d MMM").toUpperCase()
            color: Kirigami.Theme.textColor
            opacity: 0.6
            font.family: "monospace"
            font.letterSpacing: 3
            font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.8)
        }

        Connections {
            target: root
            function onNowChanged() { canvas.requestPaint() }
        }
        Connections {
            target: Plasmoid.configuration
            function onUse24hChanged() { canvas.requestPaint() }
        }
        Connections {
            target: Kirigami.Theme
            function onTextColorChanged() { canvas.requestPaint() }
            function onHighlightColorChanged() { canvas.requestPaint() }
        }
    }
}
