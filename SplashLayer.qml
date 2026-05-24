import QtQuick 2.0
import QtMultimedia 5.0

Item {
    id: splashRoot
    anchors.fill: parent

    // 起動した瞬間にこのスプラッシュにフォーカスを奪う
    focus: true
    Component.onCompleted: splashRoot.forceActiveFocus()

    Keys.onPressed: {
        event.accepted = true;
        splashRoot.closeSplash();
    }

    MouseArea {
        anchors.fill: parent
        enabled: splashRoot.visible
        onClicked: splashRoot.closeSplash();
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    Video {
        id: introVideo
        source: "assets/boot.mp4"
        anchors.fill: parent
        fillMode: Video.PreserveAspectCrop
        autoPlay: true // ★Loaderで必要な時だけ呼ぶので、ここはtrueでOK
        volume: 0.8

        onStopped: {
            splashRoot.closeSplash();
        }
    }

    Timer {
        id: safetyTimer
        interval: 10000
        running: true  // ★こちらもtrueに戻します
        repeat: false
        onTriggered: {
            splashRoot.closeSplash();
        }
    }

    function closeSplash()
    {
        if (splashRoot.visible)
        {
            introVideo.stop();
            safetyTimer.stop();
            splashRoot.visible = false; // これをトリガーにtheme.qml側が検知します
        }
    }
}