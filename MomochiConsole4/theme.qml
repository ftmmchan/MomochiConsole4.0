import QtQuick 2.15
import QtMultimedia 5.15 // ★オーディオ機能のために追加

FocusScope {
    id: root
    width: 1280
    height: 720
    FontLoader {
        id: customFont
        source: "assets/fonts/851tegaki.ttf"
    }
    // ★ 1. バックグラウンドBGMシステム
    Audio {
        id: bgmPlayer
        // 音楽ファイルのパスを指定（theme.qmlからの相対パス）
        source: "assets/audio/bgm.mp3"

        // ループ再生の設定（無限ループ）
        loops: Audio.Infinite

        // 音量調整（0.0 が消音、1.0 が最大音量。BGMなので少し小さめの 0.4 がおすすめ）
        volume: 0.2

        // テーマが読み込まれたら自動的に再生を開始する
        autoPlay: true
    }

    // ゲーム起動・終了を検知してBGMを一時停止・再開させるための処理
    // Pegasusが裏に回る際、自動で再生フラグを追従させます
    onActiveFocusChanged: {
        if (root.activeFocus)
        {
            bgmPlayer.play(); // アプリに戻ってきたらBGMを再開
        } else {
        bgmPlayer.pause(); // ゲームが起動して裏に回ったらBGMを停止
    }
}

// 2. 最背面：テーマ共通の背景画像
Item {
    anchors.fill: parent; z: 1
    Rectangle { anchors.fill: parent; color: "#111111" }
    Image { anchors.fill: parent; source: "assets/bg.png"; fillMode: Image.PreserveAspectCrop; asynchronous: true; opacity: 0.85 }
    Rectangle { anchors.fill: parent; color: "#10ffffff" }
}

// 最前面：時計
Text {
    id: clockText
    anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 40; z: 10
    color: "white"; font.pixelSize: 24; font.bold: true
    text: Qt.formatDateTime(new Date(), "hh:mm")
    font.family: customFont.name
    style: Text.Outline;
    styleColor: "#00e1ff";
    Timer { interval: 1000; running: true; repeat: true; onTriggered: clockText.text = Qt.formatDateTime(new Date(), "hh:mm") }
}

// 画面管理用の復元ロジック
Component.onCompleted: {
    var savedScreen = api.memory.get("lastScreen");
    var savedCollectionIndex = api.memory.get("lastCollectionIndex");

    if (savedScreen === "game" && savedCollectionIndex !== undefined)
    {
        var targetCollection = api.collections.get(savedCollectionIndex);
        if (targetCollection)
        {
            root.selectedCollectionData = targetCollection;
            root.currentScreen = "game";

            // プラットフォーム側のカーソルを戻す
            platformView.setGridIndex(savedCollectionIndex);

            // 【変更】ここではゲームカーソルを直接触らず、GameGrid側の自動復元に任せる
        }
    }
}

property string currentScreen: "platform"
    property var selectedCollectionData: null
        // 💡 画面が切り替わった瞬間を監視するハンドラー
        onCurrentScreenChanged: {
            if (currentScreen === "game")
            {
                // ゲーム画面（gameView）へ切り替わったら、即座にスクロール初期化関数を実行する
                gameView.resetScrollPosition();
            }
        }
        // プラットフォーム一覧画面
        PlatformGrid {
            id: platformView
            anchors.fill: parent; visible: root.currentScreen === "platform"; focus: root.currentScreen === "platform"; z: 2
            onPlatformSelected: {
                root.selectedCollectionData = selectedCollection;
                root.currentScreen = "game";
                api.memory.set("lastScreen", "game");
                for (var i = 0; i < api.collections.count; i++) {
                    if (api.collections.get(i).shortName === selectedCollection.shortName)
                    {
                        api.memory.set("lastCollectionIndex", i);
                        break;
                    }
                }
            }
        }

        // ゲーム一覧画面
        GameGrid {
            id: gameView
            anchors.fill: parent; visible: root.currentScreen === "game"; focus: root.currentScreen === "game"; currentCollection: root.selectedCollectionData; z: 2
            onGoBack: {
                root.currentScreen = "platform";
                api.memory.unset("lastScreen");
                api.memory.unset("lastCollectionIndex");
                api.memory.unset("lastGameIndex");
            }
        }
    }
