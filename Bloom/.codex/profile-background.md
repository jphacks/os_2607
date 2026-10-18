# プロフィール・バックグラウンド対応 — 2026-10-18

## D32: メッセージ機能を廃止（ユーザー指示）

- タブ、近く／履歴プロフィール内ボタン、navigationDestination、全会話画面、Repository注入、Domainメッセージ型、Supabase実装、専用SQLとテストを削除。
- プロフィールのリッチ表示はRichContentKind / MediaAddressとして独立。画像・動画・HTTPSリンクは維持。
- 旧SQLはエージェントからリモートへ未適用。外部で適用済みかは不明であり、リモートテーブルを削除したとは主張しない。

## D33: 履歴の初回表示と取得競合

- 未取得時は読み込み表示。エラー表示は実際の取得失敗時に限定。
- onAppearフラグとtaskの切り替えを廃止し、scenePhaseをキーに可視期間中だけ更新する。
- 再取得ごとのrequestIDで古い応答を無効化。キャンセル済み要求の完了待ちで新しい要求をスキップしない。
- 公開許可の15秒TTL、12秒間隔の更新、Reveal条件は従来通り。非表示・バックグラウンド時にプロフィールを破棄。TTL失効は更新中の要求を無効化しない。
- 「一緒に過ごした時間」の累計だけを表示し、その下の個別日時行を削除。履歴一覧の最終日時は維持。

## D34: カード型プロフィール

- 自分／近くの相手／履歴の相手をScrollView内のカードで表示。自分の公開項目はリッチ表示と編集・削除Menuを持つ。
- SwiftUI scrollTransitionのbottomTrailing / centered閾値で画面下側ほど0.8倍へ縮小。上側は等倍。視差効果を減らす設定では等倍。
- ネイティブTabView・NavigationStack・TextField・Toggle・Menu・編集Formを維持。

## D35: Background NI（Phase 3、D13の停止方針を更新）

- iOS 18.4以降のNI仕様に従い、参加開始時（フォアグラウンド）に標準Live Activityを要求。
- UIBackgroundModes = nearby-interaction と NSSupportsLiveActivities = true。iOS 26.0のホストと同じ最低OSのWidgetKit拡張を埋め込み。ロック画面／Dynamic Islandには参加状態のみを表示し、他者のプロフィールは出さない。
- アクティブなLive Activityがあるバックグラウンド移行ではNetwork接続とNISessionを保持。NIの一時停止では観測値を消し、sessionSuspensionEndedで既存configurationを再実行する既存処理を維持。
- Live Activityが利用不能の場合は前景のみ参加可能。背景移行で終了。Live Activityの終了／ユーザーのdismiss／期限切れ、参加終了、公開撤回、ログアウトではセッションも終了。
- 復帰時は認証を再確認するが、読み込み画面への差し替えでHomeViewと接続を破棄しない。通信失敗時に既存のローカル参加を消さない。認証なし・別アカウント・本人プロフィール消失は従来のフローへ戻す。
- ActivityKitのActivity型はSendable未対応のためpreconcurrency importを使用。所有と操作はMainActorに限定。
- ActivityAttributesの同一wire formatをアプリと拡張に配置。変更時は両方を同時に更新する。
- OSによる停止やNetwork切断、NIのリソース上限は保証できない。新鮮な実測値がない時間をEncounterへ加算しない。Heartbeat等の仮閾値は変更していない。

## 検証

- Xcode BuildProject、およびbuildForTestingが成功。アプリ／Live Activity拡張のコンパイル、署名、埋め込みを確認。
- 生成されたBloom.app/Info.plistでnearby-interaction、NSSupportsLiveActivities=true、埋め込みappexの存在を確認。
- 実際のDomain／HistoryProfileModelとSwift Testingを一時macOS SwiftPM packageで実行し8件成功。初回未取得、キャンセル要求と後続要求の競合、非表示後の遅延応答、非接続プロフィール取得、公開撤回、履歴集約、接続リトライを検証。
- Swift／SQL／plist／entitlements／xcstrings全体を検索しメッセージ機能の型・画面・導線・API参照なし。NI通信プロトコルの「通信メッセージ」はチャットではない。
- 実機が利用可能でないため、D19に従いSimulatorでUIを起動しない。外観・タップ操作、2台以上でのNIバックグラウンド測距、ロック／復帰、Live Activityの許可拒否／dismiss、実Supabaseアカウントでの履歴表示は未検証。

## 実機での受け入れ確認

1. 2台で公開と参加をオン。自動接続後にLive Activityが両方で表示される。
2. 一方／両方をホーム画面またはロックへ移動。計測継続と履歴加算を確認。測距欠損時間は加算しない。
3. 復帰時に参加が維持され、画面が作り直されない。Live Activityを消すと参加が終了する。
4. ライブアクティビティ無効時は背景移行で終了する。
5. 履歴を初めて開くと読み込みからプロフィールへ遷移。公開撤回時だけ非表示となり、再試行が可能。
6. 全タブ／プロフィールにメッセージ導線がない。カードの下側縮小、編集、削除、画像拡大、動画、Dynamic Typeを確認。

参考: Apple DocumentationSearchのNearbyInteraction「Using Nearby Interaction in the background」、ActivityKit request(attributes:content:pushType:)、SwiftUI scrollTransition(topLeading:bottomTrailing:axis:transition:)。
