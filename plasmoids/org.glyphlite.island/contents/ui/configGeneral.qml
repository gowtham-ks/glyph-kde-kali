import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_use24h: use24h.checked
    property alias cfg_showDate: showDate.checked
    property alias cfg_dateStyle: dateStyle.currentIndex
    property alias cfg_showCpuDot: showCpuDot.checked
    property alias cfg_showBorder: showBorder.checked

    Kirigami.FormLayout {
        QQC2.CheckBox { id: use24h; Kirigami.FormData.label: "Time:"; text: "24-hour clock" }
        QQC2.CheckBox { id: showDate; Kirigami.FormData.label: "Pill:"; text: "Show the date" }
        QQC2.ComboBox {
            id: dateStyle
            Kirigami.FormData.label: "Date format:"
            enabled: showDate.checked
            model: ["SAT 7", "7 NOV", "07/11"]
        }
        QQC2.CheckBox { id: showCpuDot; text: "Show the CPU dot" }
        QQC2.CheckBox { id: showBorder; text: "Show the outline" }
    }
}
