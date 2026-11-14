/* Calamares-slideshow voor Quickshell Desktop. */
import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation
{
    id: presentation

    Timer {
        interval: 20000
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    Slide {
        Image {
            id: background1
            source: "slide1.png"
            width: 640
            height: 360
            fillMode: Image.PreserveAspectFit
            anchors.centerIn: parent
        }
        Text {
            anchors.horizontalCenter: background1.horizontalCenter
            anchors.top: background1.bottom
            anchors.topMargin: 18
            text: qsTr("Welkom bij Quickshell Desktop.<br/>" +
                       "Debian sid met BSPWM en een Quickshell-bar.")
            wrapMode: Text.WordWrap
            width: 640
            horizontalAlignment: Text.Center
        }
    }

    Slide {
        Image {
            id: background2
            source: "slide2.png"
            width: 640
            height: 360
            fillMode: Image.PreserveAspectFit
            anchors.centerIn: parent
        }
        Text {
            anchors.horizontalCenter: background2.horizontalCenter
            anchors.top: background2.bottom
            anchors.topMargin: 18
            text: qsTr("De installatie maakt een BTRFS-root in subvolume @rootfs,<br/>" +
                       "met aparte subvolumes voor /home en /var,<br/>" +
                       "snapper-momentopnamen in /.snapshots en<br/>" +
                       "een schrijfbare overlay voor snapshot-boots.")
            wrapMode: Text.WordWrap
            width: 640
            horizontalAlignment: Text.Center
        }
    }
}
