import QtQuick
import org.kde.kirigami as Kirigami

// 5x7 dot-matrix "HH:MM". Set `time` and `cellSize`.
Canvas {
    id: dt
    property date time: new Date()
    property real cellSize: 4
    property bool use24h: true
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

    implicitWidth: Math.ceil(cellSize * 25)
    implicitHeight: Math.ceil(cellSize * 7)
    width: implicitWidth
    height: implicitHeight

    onTimeChanged: requestPaint()
    onCellSizeChanged: requestPaint()
    onUse24hChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        var cell = cellSize
        if (cell <= 0)
            return
        var r = cell * 0.36
        var tc = Kirigami.Theme.textColor
        var hc = Kirigami.Theme.highlightColor
        var off = Qt.rgba(tc.r, tc.g, tc.b, 0.10)
        var h = time.getHours()
        if (!use24h) {
            h = h % 12
            if (h === 0)
                h = 12
        }
        var hh = (h < 10 ? "0" : "") + h
        var mm = Qt.formatTime(time, "mm")
        var seq = [hh.charAt(0), hh.charAt(1), ":", mm.charAt(0), mm.charAt(1)]
        var x = 0
        for (var i = 0; i < seq.length; ++i) {
            var g = glyphs[seq[i]]
            var w = g[0].length
            for (var row = 0; row < 7; ++row) {
                for (var col = 0; col < w; ++col) {
                    var on = g[row].charAt(col) === "1"
                    ctx.fillStyle = on ? (seq[i] === ":" ? hc : tc) : off
                    ctx.beginPath()
                    ctx.arc((x + col + 0.5) * cell, (row + 0.5) * cell, r, 0, Math.PI * 2)
                    ctx.fill()
                }
            }
            x += w + 1
        }
    }

    Connections {
        target: Kirigami.Theme
        function onTextColorChanged() { dt.requestPaint() }
        function onHighlightColorChanged() { dt.requestPaint() }
    }
}
