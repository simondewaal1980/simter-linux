// Keycap.qml — één toets in het sneltoetsenoverzicht.
//
// Een keycap toont één toetsnaam (Super, Shift, H, Return, …). Modifiers
// krijgen een iets lichtere achtergrond dan gewone toetsen, zodat een
// combinatie snel leesbaar is.

import QtQuick
import "../theme"

Rectangle {
    id: keycap

    property string label: ""
    property bool modifier: false

    implicitWidth: Math.max(Theme.scaled(20), keyLabel.implicitWidth + Theme.scaled(12))
    implicitHeight: Theme.scaled(24)
    radius: Theme.scaled(4)
    color: keycap.modifier ? Theme.surface1 : Theme.surface0
    border.width: 1
    border.color: keycap.modifier ? Theme.overlay0 : Theme.surface1

    Text {
        id: keyLabel
        anchors.centerIn: parent
        text: keycap.label
        color: keycap.modifier ? Theme.text : Theme.subtext1
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSmall
        font.weight: keycap.modifier ? Font.DemiBold : Font.Normal
    }
}
