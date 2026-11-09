import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: meter

    property real value: 0
    property string label: ""
    readonly property int dots: 36

    onValueChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(0, Math.min(meter.width, meter.height - lbl.height - Kirigami.Units.smallSpacing))
        height: width

        onWidthChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            if (width <= 0)
                return
            var dr = width * 0.035
            var R = width / 2 - dr - 1
            var cx = width / 2, cy = height / 2
            var lit = Math.round(Math.max(0, Math.min(1, meter.value)) * meter.dots)
            var tc = Kirigami.Theme.textColor
            var off = Qt.rgba(tc.r, tc.g, tc.b, 0.14)
            for (var i = 0; i < meter.dots; ++i) {
                var a = -Math.PI / 2 + 2 * Math.PI * i / meter.dots
                ctx.fillStyle = i < lit ? Kirigami.Theme.highlightColor : off
                ctx.beginPath()
                ctx.arc(cx + R * Math.cos(a), cy + R * Math.sin(a), dr, 0, Math.PI * 2)
                ctx.fill()
            }
        }
    }

    Text {
        anchors.centerIn: canvas
        text: Math.round(meter.value * 100) + "%"
        color: Kirigami.Theme.textColor
        font.family: "monospace"
        font.pixelSize: Math.max(8, Math.round(canvas.width * 0.2))
    }

    Text {
        id: lbl
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        text: meter.label
        color: Kirigami.Theme.textColor
        opacity: 0.6
        font.family: "monospace"
        font.letterSpacing: 2
        font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.75)
    }

    Connections {
        target: Kirigami.Theme
        function onTextColorChanged() { canvas.requestPaint() }
        function onHighlightColorChanged() { canvas.requestPaint() }
    }
}
