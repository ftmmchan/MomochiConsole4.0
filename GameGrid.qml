import QtQuick 2.15
import QtMultimedia 5.15

FocusScope {
    id: gameRoot
    property var currentCollection: null
        property int savedGridIndex: 0


            signal goBack()
            // 💡【追加】最外周のFocusScopeに直接操作フォーカスを当てるための初期化
            focus: true

            Component.onCompleted: {
                var savedGameIndex = api.memory.get("lastGameIndex");
                if (savedGameIndex !== undefined && savedGameIndex >= 0)
                {
                    // 起動・復帰時にデータがあれば即座にスクロールを0にリセットして暴走を防ぐ
                    gameGrid.snapMode = GridView.NoSnap;
                    gameGrid.contentY = 0;
                    gameGrid.currentIndex = savedGameIndex;
                    gameGrid.forceActiveFocus();

                    // 監視タイマーを起動
                    returnScrollTimer.start();
                }
            }

            Timer {
                id: returnScrollTimer
                interval: 50
                repeat: true // データが復活するまでループ
                onTriggered: {
                    var savedIndex = api.memory.get("lastGameIndex");
                    var rowCount = Math.round((parent.width - detailPanel.width) / gameGrid.cellWidth);
                    // データ（count）が復活した瞬間をキャッチ
                    if (gameGrid.count > 0 && savedIndex < gameGrid.count)
                    {

                        // 1. ループを即座に停止
                        returnScrollTimer.stop();

                        // 2. スナップ機能を一度完全に切る
                        gameGrid.snapMode = GridView.NoSnap;

                        // 💡 3. 【最重要】まずはQMLの公式関数を呼び出し、
                        // 目的のインデックス周辺のセルをメモリ上に「強制実体化」させます。
                        // 基準は画面上端（Beginning）に合わせます。
                        gameGrid.positionViewAtIndex(savedIndex, GridView.Center);

                        // 💡 4. 【絶対位置の微調整】
                        // セルが実体化したこの瞬間に、デバッグで判明した完璧な数式を上書きして
                        // 理想のスクロール位置（contentY）へぴったり固定します。
                        var finalContentY = (savedIndex - 1) * gameGrid.cellHeight ;
                        gameGrid.contentY = Math.max(0, finalContentY);

                        // 5. 選択状態と操作フォーカスを固定
                        gameGrid.currentIndex = savedIndex;
                        gameGrid.forceActiveFocus();

                        // 6. 最後にスナップ機能を安全に復活させる
                        snapResetTimer.start();
                    }
                }
            }

            Timer {
                id: snapResetTimer
                interval: 100
                repeat: false
                onTriggered: {
                    gameGrid.snapMode = GridView.SnapToRow;
                }
            }

            // =========================================================================
            // ⚙️ 画面管理プロパティ ＆ 大画面詳細モードのスイッチ
            // =========================================================================
            // false: 通常（リストメイン） / true: 画面いっぱいのゲーム詳細画面モード
            property bool isPanelZoomed: false

                // お気に入りソート＆フィルタシステム（削除した検索機能を完全クリーンアップ）
                property var customSortedList: []
                property string currentFilter: "all"

                    // あなたのカスタムデザイン・カラー設定を100%維持
                    property int labelTextSize: 14
                        property string accentColor: "#00e1ff"

                            // 💡【最重要】2回目以降の画面切り替え時にも確実に初期化させるための外部関数
                            function resetScrollPosition()
                            {
                                descScrollAnimation.stop();
                                descFlickable.contentY = 0;
                                textContainerColumn.opacity = 1.0;

                                // わずかな遅延を挟んでスクロール判定を再始動させる（フライング防止）
                                recheckTimer.restart();
                            }

                            // 各種効果音コンポーネント
                            SoundEffect { id: moveSound; source: "assets/audio/move.wav"; volume: 0.5 }
                            SoundEffect { id: confirmSound; source: "assets/audio/confirm.wav"; volume: 0.6 }
                            SoundEffect { id: favoriteSound; source: "assets/audio/confirm.wav"; volume: 0.6 }
                            SoundEffect { id: filterSound; source: "assets/audio/move.wav"; volume: 0.6 }
                            SoundEffect { id: zoomSound; source: "assets/audio/move.wav"; volume: 0.6 } // 詳細画面切り替え音

                                // ゲーム起動を少しだけ遅らせるタイマー
                                Timer {
                                    id: launchDelayTimer
                                    interval: 300
                                    repeat: false
                                    onTriggered: {
                                        var sortedGame = gameRoot.customSortedList[gameGrid.currentIndex];
                                        if (sortedGame) sortedGame.launch();
                                    }
                                }

                                Rectangle { anchors.fill: parent; color: "transparent" }

                                // =========================================================================
                                // 📊 お気に入りソート＆データ振り分け処理
                                // =========================================================================
                                function updateSortedList()
                                {
                                    if (!currentCollection || !currentCollection.games)
                                    {
                                        customSortedList = [];
                                        return;
                                    }

                                    var favList = [];
                                    var normalList = [];

                                    for (var i = 0; i < currentCollection.games.count; i++) {
                                        var game = currentCollection.games.get(i);
                                        if (game.favorite)
                                        {
                                            favList.push(game);
                                        } else {
                                        normalList.push(game);
                                    }
                                }

                                if (gameRoot.currentFilter === "favorite")
                                {
                                    customSortedList = favList;
                                } else {
                                customSortedList = favList.concat(normalList);
                            }
                        }

                        onCurrentCollectionChanged: {
                            gameRoot.currentFilter = "all";
                            gameRoot.isPanelZoomed = false; // 機種切り替え時は詳細画面を自動で閉じる
                            updateSortedList();
                        }

                        onCurrentFilterChanged: { updateSortedList(); }

                        // =========================================================================
                        // 📐 プラットフォーム固有のアスペクト比・サイズ自動計算
                        // =========================================================================


                        property real realAspectRatio: {
                            var sName = currentCollection.shortName;
                            if (sName === "gba") return 1.5;
                            if (sName === "vb") return 1.716;
                            if (sName === "android") return 1;
                            if (sName === "steam") return 2.139;
                            if (sName === "3ds") return 1.666;
                            if (sName === "md" || sName === "mcd" || sName === "32x") return 1.306;
                            if (sName === "gb" || sName === "gbc" || sName === "gg") return 1.11;
                            if (sName === "ngp" || sName === "ngpc") return 1.052;
                            if (sName === "ps2" || sName === "psp" || sName === "win" || sName === "wii" || sName === "wiiware" || sName === "psvita" || sName === "ps3" || sName === "switch") return 1.777;
                            if (sName === "ws" || sName === "wsc") return 1.5541;
                            return 1.333; // デフォルト値
                        }
                        property int baseWidth: {
                            if (realAspectRatio <= 1.4)
                            {
                                return 180;
                            }else {
                            return 220;
                        }
                    }
                    property int dynamicCellHeight: baseWidth / realAspectRatio

                        // =========================================================================
                        // 1️⃣ 左上：プラットフォームロゴ＆ゲームタイトルの複合ヘッダー
                        // =========================================================================

                        Column {
                            id: gameHeaderArea
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 40
                            spacing: 8
                            z: 2

                            // 💡詳細画面マックス拡大時は、ゲーム情報を引き立たせるために上部ヘッダーを滑らかにフェードアウト
                            opacity: gameRoot.isPanelZoomed ? 0.0 : 1.0
                            visible: opacity > 0.0
                            Behavior on opacity { NumberAnimation { duration: 200 } }

                            Row {
                                width: parent.width - 500
                                height: 45
                                spacing: 15

                                Item {
                                    width: 100
                                    height: parent.height
                                    anchors.verticalCenter: parent.verticalCenter
                                    Image {
                                        id: platformLogo
                                        anchors.fill: parent
                                        source: currentCollection ? "assets/logos/" + currentCollection.shortName + ".png" : ""
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        onStatusChanged: { if (status === Image.Error || source == "") { fallbackPlatformText.visible = true; platformLogo.visible = false; } else { fallbackPlatformText.visible = false; platformLogo.visible = true; } }
                                    }
                                    Text { id: fallbackPlatformText; visible: false; anchors.centerIn: parent; text: currentCollection ? "[" + currentCollection.shortName.toUpperCase() + "]" : ""; color: Qt.rgba(1, 1, 1, 0.4); font.pixelSize: 18; font.bold: true; font.family: customFont.name }
                                }

                                Item {
                                    id: titleTextContainer
                                    width: parent.width - 170
                                    height: parent.height
                                    clip: true

                                    Text {
                                        id: titleText
                                        text: {
                                            if (gameGrid.currentItem && gameGrid.currentItem.gameData) return gameGrid.currentItem.gameData.title;
                                            if (gameRoot.customSortedList.length > 0 && gameRoot.customSortedList[gameGrid.currentIndex]) return gameRoot.customSortedList[gameGrid.currentIndex].title;
                                            return "";
                                        }
                                        color: "white"
                                        font.pixelSize: 38 // あなた独自の指定フォントサイズ
                                        font.bold: true
                                        font.family: customFont.name
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: 0
                                        style: Text.Outline // あなた独自のアウトラインデザイン
                                        styleColor: accentColor
                                        onTextChanged: { headerTextAnimation.stop(); titleText.x = 0; titleText.opacity = 1.0; if (titleText.width > titleTextContainer.width) headerTextAnimation.start(); }
                                    }
                                }
                            }

                            Row {
                                spacing: 10; anchors.leftMargin: 116
                                Text {
                                    text: currentCollection ? (gameGrid.currentIndex + 1) + " / " + gameRoot.customSortedList.length + " Games" : "0 / 0 Games";
                                    color: Qt.rgba(1, 1, 1, 0.8);
                                    font.pixelSize: labelTextSize;
                                    font.bold: true;
                                    font.family: customFont.name
                                    style: Text.Outline;
                                    styleColor: "black";
                                }
                                //お気に入りを示すテキストラベル
                                Text {
                                    text: gameRoot.currentFilter === "favorite" ? "[★ Favorites Only]" : "";
                                    color: "#f1c40f";
                                    font.pixelSize: labelTextSize;
                                    font.bold: true;
                                    font.family: customFont.name;
                                    anchors.verticalCenter:
                                    parent.verticalCenter
                                    style: Text.Outline;
                                    styleColor: "black";
                                }
                            }
                        }

                        AnimationProperty {
                            id: headerTextAnimation
                            targetObj: titleText
                            targetCnt: titleTextContainer
                            durationTime: 2000   // 速度を指定
                        }

                        // =========================================================================
                        // 2️⃣ 右側：詳細パネル（★Yボタンで滑らかにマックス拡張するレスポンシブ設計）
                        // =========================================================================
                        Item {
                            id: detailPanel
                            anchors.bottom: gameFooterBar.top // 操作ガイドバーに被らせない位置
                            anchors.right: parent.right
                            anchors.rightMargin: 580
                            anchors.bottomMargin: 15

                            // 💡 拡大時は画面最上部（parent.top）まで伸び、通常時はヘッダーの下に綺麗に収まる
                            anchors.top: gameRoot.isPanelZoomed ? parent.top : gameHeaderArea.bottom
                            anchors.topMargin: gameRoot.isPanelZoomed ? 40 : 20

                            // 💡 Yボタン（isPanelZoomed）の状態によって横幅を 390 ⇄ 1200（ほぼ全画面化）へシフト
                            width: gameRoot.isPanelZoomed ? 1200 : 390

                            // 横幅が伸び縮みする滑らかなアニメーション効果（250ミリ秒）
                            Behavior on width {
                            NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
                        }

                        Rectangle { anchors.fill: parent; color: "#4a1ea7f7"; radius: 10 }
                        AnimationProperty {
                            id: titleTextAnimation
                            targetObj: panelTitleText
                            targetCnt: panelTitleContainer
                            durationTime: 2000   // 速度を指定
                        }
                        Column {
                            anchors.fill: parent; anchors.margins: 20; spacing: 15
                            // ① スクリーンショット（大画面詳細モード時は、横長360pxの大迫力に拡張）
                            Image {
                                id: boxFrontImage;
                                width: parent.width;

                                // 💡 認識に必須な gameData の階層を完全に維持します
                                source: (gameRoot.customSortedList.length > 0 && gameRoot.customSortedList[gameGrid.currentIndex]) ? gameRoot.customSortedList[gameGrid.currentIndex].assets.boxFront : ""

                                fillMode: Image.PreserveAspectFit;
                                horizontalAlignment: Image.AlignHCenter;
                                verticalAlignment: Image.AlignVCenter;
                                asynchronous: true;
                                clip: true;

                                // 💡 ゲームから戻った瞬間（アクティブになった時）に、
                                // インデックスを一瞬だけ揺らして「キー操作での切り替え」を自動で再現します
                                Connections {
                                    target: api.memory

                                    onActiveChanged: {
                                        if (api.memory.active && gameGrid && gameGrid.currentIndex >= 0)
                                        {
                                            var lastIndex = gameGrid.currentIndex;
                                            gameGrid.currentIndex = -1;
                                            gameGrid.currentIndex = lastIndex;
                                        }
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent;
                                    color: "#151515";
                                    z: -1;
                                    radius: 5
                                }

                                height: gameRoot.isPanelZoomed ? 360: (parent.width / gameRoot.realAspectRatio > 512 ? 512 : parent.width / gameRoot.realAspectRatio)
                            }

                            Item {
                                id: panelTitleContainer;
                                width: parent.width;
                                height: 26;
                                clip: true;
                                anchors.topMargin: -10;

                                Text {
                                    id: panelTitleText
                                    text: {
                                        if (gameGrid.currentItem && gameGrid.currentItem.gameData) return gameGrid.currentItem.gameData.title;
                                        if (gameRoot.customSortedList.length > 0 && gameRoot.customSortedList[gameGrid.currentIndex]) return gameRoot.customSortedList[gameGrid.currentIndex].title;
                                        return "";
                                    }
                                    color: "white";
                                    font.pixelSize: 26;
                                    font.bold: true;
                                    font.family: customFont.name;
                                    x: 0;
                                    style: Text.Outline;
                                    styleColor: accentColor;
                                    onTextChanged: { titleTextAnimation.stop(); panelTitleText.x = 0; panelTitleText.opacity = 1.0; if (panelTitleText.width > panelTitleContainer.width) titleTextAnimation.start(); }
                                    Component.onCompleted: {
                                        titleTextAnimation.stop();
                                        panelTitleText.x = 0;
                                        panelTitleContainer.opacity = 1.0;
                                    }
                                }
                            }

                            Grid {
                                id: metadataGrid
                                property int metadataTextSize: 17;
                                    width: parent.width;
                                    x: 30;
                                    columns: 2;
                                    spacing: 8;
                                    columnSpacing: 3
                                    Text {
                                        id: releaseLabel;
                                        text: "発売日:";
                                        color: "white";
                                        font.pixelSize: metadataGrid.metadataTextSize;
                                        font.family: customFont.name;
                                        font.bold: true;
                                        horizontalAlignment: Text.AlignRight;
                                        width: 60
                                    }
                                    Text {
                                        id: releasetext;
                                        text: {
                                            if (gameRoot.customSortedList.length > 0 && gameRoot.customSortedList[gameGrid.currentIndex])
                                            {
                                                return (!(isNaN(gameRoot.customSortedList[gameGrid.currentIndex].release))) ? Qt.formatDateTime(gameRoot.customSortedList[gameGrid.currentIndex].release, "yyyy年M月d日") : "---";
                                            }
                                            return "---";
                                        }
                                        color: "white";
                                        font.pixelSize: metadataGrid.metadataTextSize;
                                        font.family: customFont.name;
                                        font.bold: true;
                                        width: gameRoot.isPanelZoomed ? 200 : parent.width - 100
                                    }
                                    Text {
                                        id: genreLabel;
                                        text: "ジャンル:";
                                        color: "white";
                                        font.family: customFont.name;
                                        font.pixelSize: metadataGrid.metadataTextSize;
                                        font.bold: true;
                                        horizontalAlignment: Text.AlignRight;
                                        width: 60
                                    }
                                    Item {
                                        id: panelGenreContainer;
                                        width: metadataGrid.width - genreLabel.width - metadataGrid.columnSpacing - metadataGrid.x;
                                        height: metadataGrid.metadataTextSize;
                                        clip: true;
                                        Text {
                                            id: panelGenreText
                                            text: {
                                                if (gameRoot.customSortedList.length > 0 && gameRoot.customSortedList[gameGrid.currentIndex])
                                                {
                                                    return (gameRoot.customSortedList[gameGrid.currentIndex] && gameRoot.customSortedList[gameGrid.currentIndex].genre) ? gameRoot.customSortedList[gameGrid.currentIndex].genre : "---";
                                                }
                                                return "---";
                                            }
                                            color: "white";
                                            font.pixelSize: metadataGrid.metadataTextSize;
                                            font.bold: true;
                                            font.family: customFont.name;
                                            onTextChanged: { genreScrollAnimation.stop(); panelGenreText.x = 0; panelGenreText.opacity = 1.0; if (panelGenreText.width > panelGenreContainer.width) genreScrollAnimation.start(); }
                                            Component.onCompleted: {
                                                genreScrollAnimation.stop();
                                                panelGenreText.x = 0;
                                                panelGenreContainer.opacity = 1.0;
                                            }
                                        }
                                    }

                                    AnimationProperty {
                                        id: genreScrollAnimation
                                        targetObj: panelGenreText
                                        targetCnt: panelGenreContainer
                                        durationTime: 2000
                                    }

                                    Text {
                                        id: publisherLabel
                                        text: "発売元:";
                                        color: "white";
                                        font.pixelSize: metadataGrid.metadataTextSize;
                                        font.family: customFont.name;
                                        font.bold: true;
                                        horizontalAlignment: Text.AlignRight;
                                        width: 60
                                    }
                                    Item {
                                        id: panelPublisherContainer;
                                        width: metadataGrid.width - publisherLabel.width - metadataGrid.columnSpacing - metadataGrid.x;
                                        height: metadataGrid.metadataTextSize;
                                        clip: true;
                                        Text {
                                            id: panelPublisherText
                                            text: {
                                                if (gameRoot.customSortedList.length > 0 && gameRoot.customSortedList[gameGrid.currentIndex])
                                                {
                                                    return (gameRoot.customSortedList[gameGrid.currentIndex] && gameRoot.customSortedList[gameGrid.currentIndex].publisher) ? gameRoot.customSortedList[gameGrid.currentIndex].publisher : "---";
                                                }
                                                return "---";
                                            }
                                            color: "white";
                                            font.pixelSize: metadataGrid.metadataTextSize;
                                            font.bold: true;
                                            font.family: customFont.name;
                                            onTextChanged: { publisherScrollAnimation.stop(); panelPublisherText.x = 0; panelPublisherText.opacity = 1.0; if (panelPublisherText.width > panelPublisherContainer.width) publisherScrollAnimation.start(); }
                                            Component.onCompleted: {
                                                publisherScrollAnimation.stop();
                                                panelPublisherText.x = 0;
                                                panelPublisherContainer.opacity = 1.0;
                                            }
                                        }
                                    }
                                    AnimationProperty {
                                        id: publisherScrollAnimation
                                        targetObj: panelPublisherText
                                        targetCnt: panelPublisherContainer
                                        durationTime: 2000
                                    }
                                    Text {
                                        id: developerLabel;
                                        text: "開発元:";
                                        color: "white";
                                        font.pixelSize: metadataGrid.metadataTextSize;
                                        font.family: customFont.name;
                                        font.bold: true;
                                        horizontalAlignment: Text.AlignRight;
                                        width: 60
                                    }
                                    Item {
                                        id: panelDeveloperContainer;
                                        width: metadataGrid.width - developerLabel.width - metadataGrid.columnSpacing - metadataGrid.x;
                                        height: metadataGrid.metadataTextSize;
                                        clip: true;
                                        Text {
                                            id: panelDeveloperText
                                            text: {
                                                if (gameRoot.customSortedList.length > 0 && gameRoot.customSortedList[gameGrid.currentIndex])
                                                {
                                                    return (gameRoot.customSortedList[gameGrid.currentIndex] && gameRoot.customSortedList[gameGrid.currentIndex].developer) ? gameRoot.customSortedList[gameGrid.currentIndex].developer : "---";
                                                }
                                                return "---";
                                            }
                                            color: "white";
                                            font.pixelSize: metadataGrid.metadataTextSize;
                                            font.bold: true;
                                            font.family: customFont.name;
                                            onTextChanged: { developerScrollAnimation.stop(); panelDeveloperText.x = 0; panelDeveloperText.opacity = 1.0; if (panelDeveloperText.width > panelDeveloperContainer.width) developerScrollAnimation.start(); }
                                            Component.onCompleted: {
                                                developerScrollAnimation.stop();
                                                panelDeveloperText.x = 0;
                                                panelDeveloperContainer.opacity = 1.0;
                                            }
                                        }
                                    }
                                    AnimationProperty {
                                        id: developerScrollAnimation
                                        targetObj: panelDeveloperText
                                        targetCnt: panelDeveloperContainer
                                        durationTime: 2000
                                    }
                                    Text {
                                        text: "プレイ人数:";
                                        color: "white";
                                        font.pixelSize: metadataGrid.metadataTextSize;
                                        font.family: customFont.name;
                                        font.bold: true;
                                        horizontalAlignment: Text.AlignRight;
                                        width: 60
                                    }
                                    Text {
                                        text: {
                                            if (gameRoot.customSortedList.length > 0 && gameRoot.customSortedList[gameGrid.currentIndex])
                                            {
                                                return (gameRoot.customSortedList[gameGrid.currentIndex].players === 1) ? "1人" : "1-" + gameRoot.customSortedList[gameGrid.currentIndex].players + "人";
                                            }
                                            return "1人";
                                        }
                                        color: "white";
                                        font.pixelSize: metadataGrid.metadataTextSize;
                                        font.family: customFont.name;
                                        font.bold: true;
                                        elide: Text.ElideRight;
                                        width: gameRoot.isPanelZoomed ? 200 : parent.width - 100
                                    }
                                    Text {
                                        text: "プレイ回数:";
                                        color: "white";
                                        font.pixelSize: metadataGrid.metadataTextSize;
                                        font.family: customFont.name;
                                        font.bold: true;
                                        horizontalAlignment: Text.AlignRight;
                                        width: 60
                                    }
                                    Text {
                                        text: {
                                            if (gameRoot.customSortedList.length > 0 && gameRoot.customSortedList[gameGrid.currentIndex])
                                            {
                                                return gameRoot.customSortedList[gameGrid.currentIndex].playCount + "回";
                                            }
                                            return "0回";
                                        }
                                        color: "white";
                                        font.pixelSize: metadataGrid.metadataTextSize;
                                        font.family: customFont.name;
                                        font.bold: true;
                                        elide: Text.ElideRight;
                                        width: gameRoot.isPanelZoomed ? 200 : parent.width - 100
                                    }
                                    Text {
                                        text: "プレイ時間:";
                                        color: "white";
                                        font.pixelSize: metadataGrid.metadataTextSize;
                                        font.family: customFont.name;
                                        font.bold: true;
                                        horizontalAlignment: Text.AlignRight;
                                        width: 60
                                    }
                                    Text {
                                        property int playTimeS: gameRoot.customSortedList[gameGrid.currentIndex].playTime % 60
                                            property int playTimeM: gameRoot.customSortedList[gameGrid.currentIndex].playTime / 360 % 60
                                                property int playTimeH: gameRoot.customSortedList[gameGrid.currentIndex].playTime / 3600
                                                    text: {
                                                        if (gameRoot.customSortedList.length > 0 && gameRoot.customSortedList[gameGrid.currentIndex])
                                                        {
                                                            return playTimeH + "時間" + playTimeM + "分" + playTimeS + "秒";
                                                        }
                                                        return "---";
                                                    }
                                                    color: "white";
                                                    font.pixelSize: metadataGrid.metadataTextSize;
                                                    font.family: customFont.name;
                                                    font.bold: true;
                                                    elide: Text.ElideRight;
                                                    width: parent.width - 100
                                                }
                                            }

                                            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.6) }

                                            // ④ 【Summary & Description 統合型スクロールエリア】
                                            Flickable {
                                                id: descFlickable
                                                width: parent.width
                                                height: detailPanel.height - y - 20
                                                contentWidth: width
                                                contentHeight: textContainerColumn.implicitHeight
                                                clip: true

                                                // 💡 対策1：ユーザーやシステムによる余計な手動フリック・慣性を完全にオフにする
                                                interactive: false

                                                Component.onCompleted: {
                                                    descScrollAnimation.stop();
                                                    descFlickable.contentY = 0;
                                                    textContainerColumn.opacity = 1.0;
                                                }

                                                // ★【超重要】ゲームの選択位置が変わった瞬間の完全リセット命令
                                                Connections {
                                                    target: gameGrid
                                                    function onCurrentIndexChanged()
                                                    {
                                                        recheckTimer.stop();        // タイマーを止める
                                                        descScrollAnimation.stop(); // アニメーションを止める

                                                        // 💡 対策2：Flickableの内蔵慣性スクロールを強制的に物理停止させる特権命令
                                                        descFlickable.cancelFlick();

                                                        descFlickable.contentY = 0; // 1行目に強制巻き戻し
                                                        textContainerColumn.opacity = 1.0;

                                                        // 200ミリ秒待って、画面が完全に静止してから長文チェックを行う
                                                        recheckTimer.restart();
                                                    }
                                                }

                                                // 本文の長さ（高さ）が変わったときの処理
                                                onContentHeightChanged: {
                                                    recheckTimer.stop();
                                                    descScrollAnimation.stop();
                                                    descFlickable.cancelFlick();
                                                    descFlickable.contentY = 0;
                                                    textContainerColumn.opacity = 1.0;

                                                    // 枠を超えている長文のときだけタイマーを仕込む
                                                    if (descFlickable.contentHeight > descFlickable.height)
                                                    {
                                                        recheckTimer.restart();
                                                    }
                                                }

                                                // セーフティタイマー（200ミリ秒に広げて安定性を最大化）
                                                Timer {
                                                    id: recheckTimer
                                                    interval: 200
                                                    repeat: false
                                                    onTriggered: {
                                                        // 💡 対策3：現在すでにアニメーションが動いている場合は、二重起動を防ぐためにスルーする
                                                        if (descScrollAnimation.running) return;

                                                        descFlickable.cancelFlick();
                                                        descFlickable.contentY = 0;
                                                        textContainerColumn.opacity = 1.0;

                                                        // テキスト全体の高さが、表示枠の高さよりも【確実に大きい】場合のみ再生
                                                        if (descFlickable.contentHeight > descFlickable.height)
                                                        {
                                                            descScrollAnimation.start();
                                                        } else {
                                                        descScrollAnimation.stop();
                                                        descFlickable.contentY = 0;
                                                    }
                                                }
                                            }

                                            Column {
                                                id: textContainerColumn
                                                width: parent.width
                                                spacing: 12

                                                // 【上段：Summary（概要）】
                                                Text {
                                                    id: summaryTextComponent
                                                    width: parent.width
                                                    text: {
                                                        if (gameRoot.customSortedList.length > 0 && gameRoot.customSortedList[gameGrid.currentIndex])
                                                        {
                                                            return gameRoot.customSortedList[gameGrid.currentIndex].summary ? gameRoot.customSortedList[gameGrid.currentIndex].summary : "概要はありません。";
                                                        }
                                                        return "概要はありません。";
                                                    }
                                                    color: "#ffffff";
                                                    font.pixelSize: metadataGrid.metadataTextSize;
                                                    font.bold: true;
                                                    font.italic: true;
                                                    wrapMode: Text.Wrap;
                                                    lineHeight: 1.3;
                                                    font.family: customFont.name

                                                    onTextChanged: {
                                                        recheckTimer.stop();
                                                        descScrollAnimation.stop();
                                                        descFlickable.cancelFlick();
                                                        descFlickable.contentY = 0;
                                                        textContainerColumn.opacity = 1.0;
                                                    }
                                                }

                                                Rectangle {
                                                    width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.6)
                                                }

                                                // 【下段：Description（詳細説明）】
                                                Text {
                                                    id: descriptionTextComponent
                                                    width: parent.width
                                                    text: {
                                                        if (gameRoot.customSortedList.length > 0 && gameRoot.customSortedList[gameGrid.currentIndex])
                                                        {
                                                            return gameRoot.customSortedList[gameGrid.currentIndex].description ? gameRoot.customSortedList[gameGrid.currentIndex].description : "詳細な説明はありません。";
                                                        }
                                                        return "詳細な説明はありません。";
                                                    }
                                                    color: "#ffffff";
                                                    font.pixelSize: metadataGrid.metadataTextSize;
                                                    wrapMode: Text.Wrap;
                                                    lineHeight: 1.3;
                                                    font.family: customFont.name;
                                                    font.bold: true;

                                                    onTextChanged: {
                                                        recheckTimer.stop();
                                                        descScrollAnimation.stop();
                                                        descFlickable.cancelFlick();
                                                        descFlickable.contentY = 0;
                                                        textContainerColumn.opacity = 1.0;

                                                        // 💡 対策4：文字が書き換わった瞬間、枠内に収まる短文ならタイマーごと完全消滅させる
                                                        if (textContainerColumn.implicitHeight <= descFlickable.height)
                                                        {
                                                            recheckTimer.stop();
                                                            descScrollAnimation.stop();
                                                            descFlickable.contentY = 0;
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // 1回切り使い捨てのスクロールアニメーション
                                        SequentialAnimation {
                                            id: descScrollAnimation
                                            PropertyAction { target: descFlickable; property: "contentY"; value: 0 }
                                            PropertyAction { target: textContainerColumn; property: "opacity"; value: 1.0 }
                                            PauseAnimation { duration: 3500 }
                                            NumberAnimation { target: descFlickable; property: "contentY"; to: descFlickable.contentHeight - descFlickable.height; duration: Math.max(0, (descFlickable.contentHeight - descFlickable.height) * 50); easing.type: Easing.Linear }
                                            PauseAnimation { duration: 2500 }
                                            NumberAnimation { target: textContainerColumn; property: "opacity"; to: 0; duration: 400 }
                                            PropertyAction { target: descFlickable; property: "contentY"; value: 0 }
                                            NumberAnimation { target: textContainerColumn; property: "opacity"; to: 1; duration: 400 }
                                            ScriptAction { script: { if (descFlickable.contentHeight > descFlickable.height) recheckTimer.restart(); else { descScrollAnimation.stop(); descFlickable.contentY = 0; } } }
                                        }
                                    }
                                }

                                // =========================================================================
                                // 3️⃣ 左側：ゲームグリッドビュー（詳細画面展開時は、自動でフェードアウト退避）
                                // =========================================================================

                                GridView {
                                    id: gameGrid
                                    anchors.top: gameHeaderArea.bottom
                                    anchors.left: parent.left
                                    anchors.right: detailPanel.left
                                    width: parent.width - detailPanel.width
                                    anchors.topMargin: 10
                                    anchors.leftMargin: 40
                                    anchors.rightMargin: 10
                                    anchors.bottomMargin: 10
                                    height: parent.height - gameHeaderArea.height - gameFooterBar.height - gameFooterBar.height
                                    clip: true
                                    // 💡 追記：画面外の上下1200ピクセル分のセルを事前に生成・維持しておく
                                    // これにより、急なスクロールでも上のセルが消えず、見切れるバグを防ぎます
                                    cacheBuffer: 1200
                                    z:1

                                    // focusプロパティは生かしたままにするため、キーイベントが最外周（gameRoot）まで透過するようになります
                                    enabled: !gameRoot.isPanelZoomed

                                    // 通常時はグリッドにキー操作を集中させる設定
                                    focus: !gameRoot.isPanelZoomed

                                    opacity: gameRoot.isPanelZoomed ? 0.0 : 1.0
                                    Behavior on opacity { NumberAnimation { duration: 200 } }

                                    cellWidth: gameRoot.baseWidth;
                                    cellHeight: gameRoot.dynamicCellHeight
                                    model: gameRoot.customSortedList

                                    onModelChanged: {
                                        if (model && model.length > 0)
                                        {
                                            var savedGameIndex = api.memory.get("lastGameIndex");
                                            if (savedGameIndex !== undefined && savedGameIndex < model.length)
                                            {
                                                gameGrid.currentIndex = savedGameIndex;

                                                // F5リロード時のみ：スナップを切って中央配置（引き戻し補正入り）
                                                Qt.callLater(function() {
                                                gameGrid.snapMode = GridView.NoSnap;
                                                gameGrid.positionViewAtIndex(savedGameIndex, GridView.Center);
                                                gameGrid.contentY = Math.max(0, gameGrid.contentY - gameGrid.cellHeight);
                                                Qt.callLater(function() { gameGrid.snapMode = GridView.SnapToRow; });
                                            });
                                        }
                                        else
                                        {
                                            gameGrid.currentIndex = 0;
                                        }
                                    }
                                    onCurrentIndexChanged: {
                                        if (currentIndex >= 0 && currentIndex < count)
                                        {
                                            api.memory.set("lastGameIndex", currentIndex);
                                        }
                                    }
                                }

                                highlightFollowsCurrentItem: true; snapMode: GridView.SnapToRow; highlightMoveDuration: 0; boundsBehavior: Flickable.StopAtBounds

                                delegate: Item {
                                    width: gameGrid.cellWidth; height: gameGrid.cellHeight
                                    property bool isSelected: index === gameGrid.currentIndex
                                        property var gameData: modelData

                                            Rectangle {
                                                anchors.fill: parent;
                                                anchors.margins: 8;
                                                color: isSelected ? "#3498db" : (screenshotImage.visible ? Qt.rgba(0.11, 0.11, 0.11, 0.8) : "#2c3e50");
                                                radius: 6;
                                                clip: true;
                                                scale: isSelected ? 1.1 : 1.0;
                                                Behavior on scale { NumberAnimation { duration: 100 } }
                                                Image {
                                                    id: screenshotImage;
                                                    anchors.fill: parent;
                                                    anchors.margins: 0;
                                                    source: modelData.assets.boxFront ? modelData.assets.boxFront : "";
                                                    fillMode: Image.PreserveAspectCrop;
                                                    horizontalAlignment: Image.AlignHCenter;
                                                    verticalAlignment: Image.AlignVCenter;
                                                    asynchronous: true;
                                                    visible: source != "" && status !== Image.Error
                                                }
                                                Image { id: favoriteIcon; anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 6; width: 24; height: 24; source: "assets/icons/favorite.png"; fillMode: Image.PreserveAspectFit; asynchronous: true; z: 5; visible: modelData.favorite }
                                                Text { id: fallbackText; anchors.centerIn: parent; width: parent.width - 20; text: modelData.title; color: "white"; font.pixelSize: 14; font.bold: true; font.family: customFont.name; visible: !screenshotImage.visible; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter }
                                            }
                                        }
                                        Keys.onLeftPressed: {
                                            var columns = Math.floor(width / cellWidth);
                                            if (currentIndex % columns !== 0)
                                            {
                                                moveSound.play();
                                            }
                                            moveCurrentIndexLeft();
                                        }
                                        Keys.onRightPressed: {
                                            var columns = Math.floor(width / cellWidth);
                                            if ((currentIndex % columns !== columns - 1) && (currentIndex + 1 < count))
                                            {
                                                moveSound.play();
                                            }
                                            moveCurrentIndexRight();
                                        }
                                        Keys.onUpPressed: {
                                            var columns = Math.floor(width / cellWidth);
                                            if (currentIndex >= columns)
                                            {
                                                moveSound.play();
                                            }
                                            moveCurrentIndexUp();
                                        }
                                        Keys.onDownPressed: {
                                            var columns = Math.floor(width / cellWidth);
                                            if (currentIndex + columns <= count)
                                            {
                                                moveSound.play();
                                            }
                                            moveCurrentIndexDown();
                                        }
                                    }
                                    // =========================================================================
                                    // 🎮 【最重要・変更点2】キー入力を「外枠（FocusScope）」で統括して処理する
                                    // =========================================================================
                                    Keys.onPressed: {
                                        // 💡 大画面詳細モード中（isPanelZoomed === true）の特別キーマッピング
                                        if (gameRoot.isPanelZoomed)
                                        {
                                            // YボタンまたはBボタンで、いつでも大画面を閉じる（縮小してリストへ復帰）
                                            if (api.keys.isDetails(event) || event.key === Qt.Key_Y || api.keys.isCancel(event))
                                            {
                                                event.accepted = true;
                                                zoomSound.play();
                                                gameRoot.isPanelZoomed = false;
                                            }
                                            // 大画面詳細モード中は、Aボタン（起動）とお気に入り（X）のみ裏側で連動可能にする
                                            else if (api.keys.isAccept(event))
                                            {
                                                event.accepted = true;
                                                api.memory.set("lastGameIndex", gameGrid.currentIndex);
                                                confirmSound.play();
                                                launchDelayTimer.start();
                                            }
                                            else if (api.keys.isFilters(event) || event.key === Qt.Key_F)
                                            {
                                                event.accepted = true;
                                                var currentGame1 = gameRoot.customSortedList[gameGrid.currentIndex];
                                                if (currentGame1)
                                                {
                                                    currentGame1.favorite = !currentGame1.favorite; favoriteSound.play();
                                                }
                                            }
                                            return; // 拡大中は上下左右のカーソル移動（リスト操作）を完全に弾く
                                        }

                                        // 💡 通常モード中（ゲームリスト表示中）の標準キーマッピング

                                        else if (api.keys.isAccept(event))
                                        {
                                            api.memory.set("lastGameIndex", gameGrid.currentIndex);
                                            api.memory.set("returnFromGameFlag", true);
                                            confirmSound.play();
                                            launchDelayTimer.start();
                                            event.accepted = true;
                                        }
                                        else if (api.keys.isFilters(event) || event.key === Qt.Key_F)
                                        {
                                            event.accepted = true;
                                            var currentGame2 = gameRoot.customSortedList[gameGrid.currentIndex];
                                            if (currentGame2)
                                            {
                                                currentGame2.favorite = !currentGame2.favorite; favoriteSound.play();
                                            }
                                        }
                                        else if (api.keys.isNextPage(event) || api.keys.isPrevPage(event) || event.key === Qt.Key_Tab)
                                        {
                                            event.accepted = true;
                                            filterSound.play();
                                            gameGrid.currentIndex = 0;
                                            api.memory.set("lastGameIndex", 0);
                                            gameRoot.currentFilter = (gameRoot.currentFilter === "all") ? "favorite" : "all";
                                        }
                                        // Yボタンで大画面へズームイン
                                        else if (api.keys.isDetails(event) || event.key === Qt.Key_Y)
                                        {
                                            event.accepted = true;
                                            zoomSound.play();
                                            gameRoot.isPanelZoomed = true;
                                        }
                                        else if (api.keys.isCancel(event))
                                        {
                                            event.accepted = true;
                                            api.memory.set("returnFromGameFlag", false);
                                            gameRoot.goBack();
                                        }
                                    }

                                    // =========================================================================
                                    // 📥 4️⃣ 画面下部：操作ガイド（完璧なXbox公式カラー配色＆左寄せライン配置）
                                    // =========================================================================
                                    Rectangle {
                                        id: gameFooterBar
                                        anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 50; color: Qt.rgba(0, 0, 0, 0.5)
                                        Row {
                                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; anchors.leftMargin: 40; spacing: 25
                                            Row {
                                                spacing: 6;
                                                Rectangle {
                                                    width: 22;
                                                    height: 22;
                                                    radius: 11;
                                                    color: "#107c10";
                                                    anchors.verticalCenter: parent.verticalCenter;
                                                    Text {
                                                        text: "A";
                                                        color: "white";
                                                        font.bold: true;
                                                        font.pixelSize: 13;
                                                        anchors.centerIn: parent
                                                    }
                                                }
                                                Text {
                                                    text: "起動";
                                                    color: "white";
                                                    font.pixelSize: 13;
                                                    font.family: customFont.name;
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }

                                            Row {
                                                spacing: 6;
                                                Rectangle {
                                                    width: 22;
                                                    height: 22;
                                                    radius: 11;
                                                    color: "#e81123";
                                                    anchors.verticalCenter: parent.verticalCenter;
                                                    Text {
                                                        text: "B";
                                                        color: "white";
                                                        font.bold: true;
                                                        font.pixelSize: 13;
                                                        anchors.centerIn: parent
                                                    }
                                                }
                                                Text {
                                                    text: gameRoot.isPanelZoomed ? "詳細を閉じる" : "戻る";
                                                    color: "white";
                                                    font.pixelSize: 13;
                                                    font.family: customFont.name;
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }

                                            Row {
                                                spacing: 6;
                                                Rectangle {
                                                    width: 22;
                                                    height: 22;
                                                    radius: 11;
                                                    color: "#0078d4";
                                                    anchors.verticalCenter: parent.verticalCenter;
                                                    Text {
                                                        text: "X";
                                                        color: "white";
                                                        font.bold: true;
                                                        font.pixelSize: 13;
                                                        anchors.centerIn: parent
                                                    }
                                                }
                                                Text {
                                                    text: gameRoot.isPanelZoomed ? "ゲームリストに戻る" : "ゲーム詳細画面を開く";
                                                    color: "white";
                                                    font.pixelSize: 13;
                                                    font.family: customFont.name;
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }

                                            // 🟡 Yボタン操作ガイド（大画面モードの開閉状態をテキストに動的反映）
                                            Row {
                                                spacing: 6;
                                                Rectangle {
                                                    width: 22;
                                                    height: 22;
                                                    radius: 11;
                                                    color: "#ffb900";
                                                    anchors.verticalCenter: parent.verticalCenter;
                                                    Text {
                                                        text: "Y";
                                                        color: "#111111";
                                                        font.bold: true; font.pixelSize: 13;
                                                        anchors.centerIn: parent
                                                    }
                                                }
                                                Text {
                                                    text: "お気に入り";

                                                    color: "white";
                                                    font.pixelSize: 13;
                                                    font.family: customFont.name;
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }

                                            Row {
                                                spacing: 6;
                                                Rectangle {
                                                    width: 38;
                                                    height: 22;
                                                    radius: 4;
                                                    color: "#d2d2d2";
                                                    anchors.verticalCenter: parent.verticalCenter;
                                                    Text {
                                                        text: "L / R";
                                                        color: "#111111";
                                                        font.bold: true;
                                                        font.pixelSize: 11;
                                                        anchors.centerIn: parent
                                                    }
                                                }
                                                Text {
                                                    text: "お気に入り絞り込み (Tab)";
                                                    color: "white";
                                                    font.pixelSize: 13;
                                                    font.family: customFont.name;
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }
                                        }
                                    }

                                }
