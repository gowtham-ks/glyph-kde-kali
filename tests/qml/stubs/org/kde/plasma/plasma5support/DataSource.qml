import QtQuick
QtObject {
    property string engine
    property int interval: 0
    property var connectedSources: []
    signal newData(string source, var data)
    function connectSource(s) {}
    function disconnectSource(s) {}
}
