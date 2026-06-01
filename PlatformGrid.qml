import QtQuick 2.15
import QtMultimedia 5.15

FocusScope {
    id: platformRoot
    signal platformSelected(var selectedCollection)
    property string accentColor: "#00e1ff"
        Rectangle {
            anchors.fill: parent
            color: "transparent"
        }

        // ★左上：現在カーソルが合っているプラットフォーム名と総ゲーム数
        Column {
            id: headerArea
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 40
            spacing: 5 // 文字同士の間隔

            // プラットフォーム名
            Text {
                // 現在のインデックスからデータを安全に取得
                text: (platformGrid.currentItem && api.collections.get(platformGrid.currentIndex))
                ? api.collections.get(platformGrid.currentIndex).name
                : ""
                color: "#ffffff"
                font.pixelSize: 32
                font.bold: true
                font.family: customFont.name
                style: Text.Outline;
                styleColor: accentColor;
            }

            // 総ゲーム数
            Text {
                text: (platformGrid.currentItem && api.collections.get(platformGrid.currentIndex))
                ? api.collections.get(platformGrid.currentIndex).games.count + " Games"
                : "0 Games"
                color: Qt.rgba(1, 1, 1, 0.8) // 少し薄い白
                font.pixelSize: 18
                font.bold: false
                font.family: customFont.name
                style: Text.Outline;
                styleColor: "black";
            }
        }
        // ★追加：外（theme.qml）からカーソル位置を強制的に戻すための関数
        function setGridIndex(idx)
        {
            platformGrid.currentIndex = idx;
        }
        SoundEffect {
            id: moveSound
            source: "assets/audio/move.wav"
            volume: 0.5
        }
        // ★追加：決定音コンポーネント
        SoundEffect {
            id: confirmSound
            source: "assets/audio/confirm.wav"
            volume: 0.6
        }
        GridView {
            id: platformGrid
            // ★位置調整：ヘッダーの下からスタートするように変更
            anchors.top: headerArea.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 0
            anchors.bottomMargin: 60
            anchors.leftMargin: 40
            anchors.rightMargin: 395

            // ★スクロールを綺麗にする設定
            highlightFollowsCurrentItem: true // カーソルに合わせてスクロール
            snapMode: GridView.SnapToRow       // 行単位で綺麗にスナップ
            highlightMoveDuration: 200        // 移動アニメーションの速度（200ミリ秒）
            boundsBehavior: Flickable.StopAtBounds // 画面端で余計なバウンドをさせない
            clip: true

            focus: true
            cellWidth: 220
            cellHeight: cellWidth * 0.7
            model: api.collections

            delegate: Item {
                id: delegateItem
                width: platformGrid.cellWidth
                height: platformGrid.cellHeight
                property bool isSelected: index === platformGrid.currentIndex

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 15
                        color: isSelected ? "#801ef7f7" : "#401ea7f7"
                        radius: 12
                        border.width: isSelected ? 3 : 0
                        border.color: "#1ef7f7"

                        scale: isSelected ? 1.05 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        Image {
                            id: logoImage
                            anchors.centerIn: parent
                            width: parent.width - 40
                            height: parent.height - 40
                            source: "assets/logos/" + modelData.shortName + ".png"
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true

                            onStatusChanged: {
                                if (status === Image.Error || source == "")
                                {
                                    fallbackText.visible = true;
                                    logoImage.visible = false;
                                } else {
                                fallbackText.visible = false;
                                logoImage.visible = true;
                            }
                        }
                    }

                    Text {
                        id: fallbackText
                        visible: false
                        anchors.centerIn: parent
                        width: parent.width - 20
                        text: modelData.name
                        color: "white"
                        font.pixelSize: 20
                        font.bold: true
                        font.family: customFont.name
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            Keys.onLeftPressed: {
                moveCurrentIndexLeft();
                moveSound.play();
            }
            Keys.onRightPressed: {
                moveCurrentIndexRight();
                moveSound.play();
            }
            Keys.onUpPressed: {
                moveCurrentIndexUp();
                moveSound.play();
            }
            Keys.onDownPressed: {
                moveCurrentIndexDown();
                moveSound.play();
            }

            Keys.onPressed: {
                if (api.keys.isAccept(event))
                {
                    event.accepted = true;

                    // ★決定音を鳴らして画面遷移
                    confirmSound.play();
                    api.memory.set("returnFromGameFlag", true);
                    platformRoot.platformSelected(api.collections.get(currentIndex));
                }
                else if (api.keys.isCancel(event))
                {
                    api.memory.set("returnFromGameFlag", false);
                }
            }
        }

        // 画面下部：操作ガイド（プラットフォーム画面用）
        Rectangle {
            id: footerBar
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 50
            color: Qt.rgba(0, 0, 0, 0.5)

            // ★修正：位置を中央から「左寄せ」に変更
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter // 縦方向は中央のまま
                anchors.leftMargin: 40 // 画面の左端からのすき間（ヘッダーと位置が揃います）
                spacing: 30

                // 🟢 Aボタン：決定（グリーン）
                Row {
                    spacing: 8
                    Rectangle { width: 24; height: 24; radius: 12; color: "#107c10"; anchors.verticalCenter: parent.verticalCenter // Xbox Green
                        Text { text: "A"; color: "#ffffff"; font.bold: true; font.pixelSize: 14; anchors.centerIn: parent }
                    }
                    Text { text: "決定"; color: "#ffffff"; font.pixelSize: 14; font.family: customFont.name; anchors.verticalCenter: parent.verticalCenter }
                }

                // ⚪ 十字キー：移動（ホワイト）
                Row {
                    spacing: 8
                    Rectangle { width: 24; height: 24; radius: 4; color: "#e6e6e6"; anchors.verticalCenter: parent.verticalCenter
                        Text { text: "十"; color: "#111111"; font.bold: true; font.pixelSize: 12; anchors.centerIn: parent }
                    }
                    Text { text: "移動"; color: "#ffffff"; font.pixelSize: 14; font.family: customFont.name; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }

