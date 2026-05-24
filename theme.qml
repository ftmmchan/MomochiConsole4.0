import QtQuick 2.15
import QtMultimedia 5.15 // ★オーディオ機能のために追加

FocusScope {
    id: root
    width: 1280
    height: 720
    focus: true;

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
        autoPlay: root.showMainUi;

        // テーマが読み込まれたら自動的に再生を開始する
    }

    // ゲーム起動・終了を検知してBGMを一時停止・再開させるための処理
    // Pegasusが裏に回る際、自動で再生フラグを追従させます
    onActiveFocusChanged: {
        if (root.activeFocus && root.showMainUi)
        {
            bgmPlayer.play(); // アプリに戻ってきたらBGMを再開
        } else {
        bgmPlayer.pause(); // ゲームが起動して裏に回ったらBGMを停止
    }
}

// 2. 最背面：テーマ共通の背景画像
Item {
    anchors.fill: parent; z: 1
    opacity: root.showMainUi ? 1.0 : 0.0;
    Rectangle { anchors.fill: parent; color: "#111111" }
    Image { anchors.fill: parent; source: "assets/bg.png"; fillMode: Image.PreserveAspectCrop; asynchronous: true; opacity: 0.85 }
    Rectangle { anchors.fill: parent; color: "#10ffffff" }
}

// 最前面：時計
Text {
    id: clockText
    opacity: root.showMainUi ? 1.0 : 0.0;
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
    // ★ メモリから「ゲーム帰還フラグ」を読み込む
    var returnFromGame = api.memory.get("returnFromGameFlag");

    if (returnFromGame === true)
    {
        api.memory.set("returnFromGameFlag", false);

        // 【ゲームからの復帰時】最初からメイン画面を表示
        root.showMainUi = true;
        bgmPlayer.play()
        root.restoreMainFocus();

    } else {
    // 【アプリ通常起動時】動画が終わるまでメイン画面は非表示

    root.showMainUi = false;
    ;
    bgmPlayer.stop();
    splashLoader.source = "SplashLayer.qml";
}
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
property bool showMainUi: false
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

                anchors.fill: parent;
                visible: root.currentScreen === "platform";
                focus: root.currentScreen === "platform";
                z: 2;
                opacity: root.showMainUi ? 1.0 : 0.0;
                enabled: root.showMainUi;
                onPlatformSelected: {
                    api.memory.set("returnFromGameFlag", true);
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
                anchors.fill: parent;
                visible: root.currentScreen === "game";
                focus: root.currentScreen === "game";
                currentCollection: root.selectedCollectionData;
                z: 2;
                opacity: root.showMainUi ? 1.0 : 0.0;
                enabled: root.showMainUi;
                onGoBack: {
                    api.memory.set("returnFromGameFlag", true);
                    root.currentScreen = "platform";
                    api.memory.unset("lastScreen");
                    api.memory.unset("lastCollectionIndex");
                    api.memory.unset("lastGameIndex");
                }
            }
            // スプラッシュ画面を管理するLoader
            Loader {
                id: splashLoader
                anchors.fill: parent
                z: 100

                Binding {
                    target: splashLoader.item
                    property: "visible"
                    value: splashLoader.status === Loader.Ready
                }

                Connections {
                    target: splashLoader.status === Loader.Ready ? splashLoader.item : null
                    ignoreUnknownSignals: true

                    function onVisibleChanged()
                    {
                        if (splashLoader.item && !splashLoader.item.visible)
                        {
                            if (api.app && api.app.active)
                            {
                                bgmPlayer.play();
                            } else if (!api.app) {
                            bgmPlayer.play();
                        }

                        // ★ 1. まずメイン画面の透明度を100%（表示）にする
                        root.showMainUi = true;

                        // ★ 2. 画面が存在する状態になってから、フォーカスを当てる（これで確実に効きます）
                        root.restoreMainFocus();

                        splashLoader.source = "";
                    }
                }
            }
        }
        // フォーカスを現在の画面に正しく戻すための共通関数
        function restoreMainFocus()
        {
            if (root.currentScreen === "platform")
            {
                platformView.forceActiveFocus();
            } else if (root.currentScreen === "game") {
            gameView.forceActiveFocus();
        }
    }
    Keys.onPressed: {
        if (event.key === Qt.Key_F5)
        {
            api.memory.set("returnFromGameFlag", true);
        }
    }
}
