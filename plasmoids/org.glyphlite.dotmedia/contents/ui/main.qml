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

    property string status: ""      // PLAYING / PAUSED / ""
    property string artist: ""
    property string title: ""
    property bool missingTool: false

    P5Support.DataSource {
        engine: "executable"
        interval: 2000
        connectedSources: ["command -v playerctl >/dev/null 2>&1 || { echo NOTOOL; exit 0; }; playerctl metadata --format '{{status}}|{{artist}}|{{title}}' 2>/dev/null"]
        onNewData: function (source, data) { root.parse(data["stdout"]) }
    }

    P5Support.DataSource {
        id: runner
        engine: "executable"
        onNewData: function (source, data) { disconnectSource(source) }
    }

    function parse(out) {
        var s = String(out).trim()
        missingTool = (s === "NOTOOL")
        if (missingTool || s === "") {
            status = ""; artist = ""; title = ""
            return
        }
        var p = s.split("|")
        status = (p[0] || "").toUpperCase()
        artist = p[1] || ""
        title = p.slice(2).join("|")
    }

    function control(cmd) {
        runner.connectSource("playerctl " + cmd)
    }

    fullRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 12
        Layout.minimumHeight: Kirigami.Units.gridUnit * 6
        Layout.preferredWidth: Kirigami.Units.gridUnit * 16
        Layout.preferredHeight: Kirigami.Units.gridUnit * 7

        ColumnLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing

            Text {
                Layout.fillWidth: true
                text: root.missingTool ? "INSTALL PLAYERCTL" : (root.status === "" ? "NO PLAYER" : root.status)
                color: root.status === "PLAYING" ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                opacity: root.status === "PLAYING" ? 1 : 0.6
                font.family: "monospace"
                font.letterSpacing: 3
                font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.75)
            }
            Text {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: root.title !== "" ? root.title : " "
                elide: Text.ElideRight
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                color: Kirigami.Theme.textColor
                font.family: "monospace"
                font.pixelSize: Math.round(Kirigami.Units.gridUnit * 1.1)
            }
            Text {
                Layout.fillWidth: true
                text: root.artist
                elide: Text.ElideRight
                color: Kirigami.Theme.textColor
                opacity: 0.6
                font.family: "monospace"
                font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.8)
            }
            RowLayout {
                spacing: Kirigami.Units.gridUnit
                Repeater {
                    model: [
                        { label: "<<", cmd: "previous" },
                        { label: root.status === "PLAYING" ? "||" : ">", cmd: "play-pause" },
                        { label: ">>", cmd: "next" }
                    ]
                    Text {
                        text: modelData.label
                        color: Kirigami.Theme.textColor
                        font.family: "monospace"
                        font.bold: true
                        font.pixelSize: Math.round(Kirigami.Units.gridUnit * 1.1)
                        MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: root.control(modelData.cmd) }
                    }
                }
            }
        }
    }
}
