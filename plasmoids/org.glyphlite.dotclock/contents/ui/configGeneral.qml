import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_use24h: use24h.checked
    property alias cfg_showDate: showDate.checked

    Kirigami.FormLayout {
        QQC2.CheckBox { id: use24h; Kirigami.FormData.label: "Time:"; text: "24-hour clock" }
        QQC2.CheckBox { id: showDate; Kirigami.FormData.label: "Below the clock:"; text: "Show the date" }
    }
}
