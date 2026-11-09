import QtQuick
Item {
    id: stub
    property Component fullRepresentation
    property Component compactRepresentation
    property var preferredRepresentation
    property bool expanded: false
    Loader {
        anchors.fill: parent
        sourceComponent: (stub.preferredRepresentation === stub.compactRepresentation && stub.compactRepresentation)
                         ? stub.compactRepresentation : stub.fullRepresentation
    }
}
