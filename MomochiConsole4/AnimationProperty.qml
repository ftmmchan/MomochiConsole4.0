import QtQuick 2.15

SequentialAnimation {
    // 外部から変更したい値をプロパティとして定義（関数の引数に相当）
    property var targetObj
    property var targetCnt
    property int durationTime: 2000
        loops: Animation.Infinite
        PauseAnimation { duration: durationTime }
        NumberAnimation { target: targetObj; property: "x"; to: -(targetObj.width - targetCnt.width); duration: (targetObj.width - targetCnt.width) * 30; easing.type: Easing.Linear }
        PauseAnimation { duration: durationTime }
        NumberAnimation { target: targetObj; property: "opacity"; to: 0; duration: 300 }
        PropertyAction { target: targetObj; property: "x"; value: 0 }
        NumberAnimation { target: targetObj; property: "opacity"; to: 1; duration: 300 }
    }
