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

    property real cpu: 0
    property real ram: 0
    property real disk: 0
    property real lastBusy: -1
    property real lastTotal: -1

    // One short shell command every 3 s: CPU jiffies, memory, root filesystem usage.
    P5Support.DataSource {
        id: sensors
        engine: "executable"
        interval: 3000
        connectedSources: ["awk '/^cpu /{print $2+$3+$4+$7, $2+$3+$4+$5+$6+$7+$8}' /proc/stat; awk '/^MemTotal/{t=$2} /^MemAvailable/{a=$2} END{print t, a}' /proc/meminfo; df --output=pcent / | tail -n 1"]
        onNewData: function (source, data) {
            root.parse(data["stdout"])
        }
    }

    function parse(out) {
        var lines = String(out).trim().split("\n")
        if (lines.length < 3)
            return
        var c = lines[0].trim().split(/\s+/).map(Number)
        if (root.lastTotal >= 0 && c[1] > root.lastTotal)
            root.cpu = Math.max(0, Math.min(1, (c[0] - root.lastBusy) / (c[1] - root.lastTotal)))
        root.lastBusy = c[0]
        root.lastTotal = c[1]
        var m = lines[1].trim().split(/\s+/).map(Number)
        if (m[0] > 0)
            root.ram = Math.max(0, Math.min(1, 1 - m[1] / m[0]))
        var dsk = parseInt(lines[2].trim())
        if (!isNaN(dsk))
            root.disk = dsk / 100
    }

    fullRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 14
        Layout.minimumHeight: Kirigami.Units.gridUnit * 6
        Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        Layout.preferredHeight: Kirigami.Units.gridUnit * 8

        RowLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.largeSpacing

            Meter { Layout.fillWidth: true; Layout.fillHeight: true; value: root.cpu;  label: "CPU" }
            Meter { Layout.fillWidth: true; Layout.fillHeight: true; value: root.ram;  label: "RAM" }
            Meter { Layout.fillWidth: true; Layout.fillHeight: true; value: root.disk; label: "DSK" }
        }
    }
}
