import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_weekStart: weekStart.currentIndex

    Kirigami.FormLayout {
        QQC2.ComboBox {
            id: weekStart
            Kirigami.FormData.label: "Week starts on:"
            model: ["Monday", "Sunday"]
        }
    }
}
