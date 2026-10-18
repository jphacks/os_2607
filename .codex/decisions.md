# 設計判断

「採用方針」は今回共有する設計上の制約を示し、実装済みを意味しない。「仮」は実装前・実機評価後に見直せる。

| ID | 状態 | 判断 | 理由 |
| --- | --- | --- | --- |
| D01 | 採用方針 | DomainをUI・通信・保存・Supabase SDKから分離 | ルールを独立して検証し、将来のwatchOSでも再利用しやすくする |
| D02 | 採用方針 | Nearby Interactionは距離・方向、Network.frameworkは発見・接続・token / personID交換 | 計測と通信の責務を明確にする |
| D03 | 採用方針 | 永続識別にはpersonIDを使い、discoveryTokenを使わない | 接続や計測セッションを越えてPersonの履歴を扱う |
| D04 | 採用方針 | Supabaseを最新プロフィールの正本とする | プロフィール更新の基準を統一する |
| D05 | 採用方針 | SwiftDataにEncounter履歴・累計時間・プロフィールキャッシュを保存 | ローカルで履歴と表示に必要な情報を保持する |
| D06 | 採用方針 | 本人が公開を許可したプロフィール情報だけを扱う | Revealによる開示と本人の公開意思を両立する |
| D07 | 更新済み | UWB実測は実機で行う | D19によりUWB確認用モックは廃止 |
| D08 | 仮 | 2m以内10秒で開始、3m超15秒で終了 | 一時的な接近や距離変動を除くための初期案 |
| D09 | 仮 | 累計60秒で趣味1、180秒で趣味2、300秒で会話のきっかけ | 遭遇時間に応じた段階的な開示の初期案 |
| D10 | 採用方針 | Domain → ローカル保存 → 端末通信・計測 → プロフィール同期 | ルールと保存を先に固めて外部依存を段階的に導入する |

## Open Questions

- D08の2m・10秒・3m超・15秒、D09の60秒・180秒・300秒と開示項目は確定仕様ではない。体験と実測を踏まえて変更するか。
- 待機時間の加算、観測欠損、再起動、履歴の重複、Revealの取り消しはどう扱うか。[Domain](domain.md)で詳細を管理する。
- personIDを誰が発行し、認証・再インストール・複数端末にどう対応させるか。
- 公開撤回、キャッシュの期限、サーバー側の開示制御をどう実現するか。
- ARKit、watchOS、バックグラウンド動作、対応OS・実機をいつ対象にするか。

## 更新方法

判断を追加・変更するときはID、日付、状態、理由、影響するphaseを記録する。仮ルールを変更したらdomain.md、testing.md、関連phaseも更新する。未決定事項を実装上の都合だけで確定扱いにしない。


## 2026-10-17: UWB単独実装（Phase 3の一部）

- D11 / 採用 / 通信はiOS 26のNetworkBrowser・NetworkListener・NetworkConnectionとSwift Concurrencyを使う。ユーザー指定によりMultipeer Connectivityは不採用。D02更新。既存のiOS 26.2以上を維持し、Swift 6と警告のエラー化で検証。参考: https://developer.apple.com/videos/play/wwdc2025/250/
- D12 / 採用 / ユーザー担当範囲に合わせ「2台間の距離・方向表示」を先行実装する。Encounter、Reveal、保存、Supabase、AR、メインUIは今回の対象外。Phase 1・2やPhase 3全体の完了とはしない。
- D13 / 暫定 / 1対1・フォアグラウンドのみ。片方が待受、片方がBonjourから端末を選択。待受側は同時に1接続のみ。バックグラウンドでは停止し、復帰・切断・無効化後は手動で開始する。新しいNISessionとtokenを作り直す。
- D14 / 採用 / NIの現行SDKにはasync計測APIがないため、非deprecatedのNISessionDelegateを専用アダプターに閉じ込め、AsyncStreamで渡す。tokenは現行のNSSecureCoding APIで交換。NISession.isSupportedは使わずdeviceCapabilitiesを使う。
- D15 / 暫定 / SDK非依存のUWBObservationにpersonID・距離・方向・観測時刻を格納。欠損・切断・停止時に表示を消す。更新停止3秒で消す。通信初回交換20秒、heartbeat間隔2秒、受信待ち10秒は実機で見直す仮値。Encounterの加算ルールではない。
- D16 / 暫定 / UUIDをUserDefaultsのBloom.personIDに保存。tokenは永続化しない。再インストール時復元・認証対応は未実装。Bonjourには開始ごとの一時名を公開する。
- D17 / 検証用途限定 / Bonjour + TCP（peer-to-peer Wi-Fiを有効化）でID・token・heartbeatのみ交換。受信サイズ上限、version、ID、tokenを検証。暗号化と本人認証は未実装で、受信IDをプロフィール取得の認可に使わない。公開運用前にペアリングと暗号化の設計が必要。
- D18 / 採用 / UIはUWB操作、距離、左右・上下方向、計測状態のみ。iPhoneは縦向き。directionのx右・y上・-z背面方向から角度を計算。鉛直方向では上下のみ表示。ARカメラ補助は使用しない。
- D19 / 採用 / 2026-10-17 / UWB確認用モックとDebug UIを廃止する。SimulatorはビルドとSDK非依存の単体チェックに限定し、画面起動と距離・方向取得は対応実機で検証する。影響: Phase 3。
- D20 / 採用 / 2026-10-17 / D13の単一ペア実装と確認UIを維持したまま、複数端末向けには接続ごとに独立したNISessionを持つ`UWBMultiPeerSession`を追加する。発見一覧・接続状態・personID・最新観測値をSDK非依存型とAsyncStream / Observationで公開し、UIや将来のAR実装から利用できるようにする。NIの同時セッション上限は端末・プラットフォームで異なるため固定人数を仕様化せず、上限到達は該当接続だけの失敗として扱う。影響: Phase 3。

将来のAPI非推奨化は保証できないため、現在のSDKの非推奨警告がないことを確認する。

## 2026-10-18: 履歴カードとセッションタイトル（Phase 2 / Presentation）

- D21 / 暫定 / 今回のセッションは既存のRecordedEncounter（相手ごとの終了済み遭遇区間）として扱う。参加開始から終了までを複数人でまとめる新しい単位は導入しない。
- D22 / 採用 / 履歴を人物別の可変列カードグリッドにし、詳細で各Encounterの日時・実測時間・タイトルを確認・編集する。既存の任意titleとアカウント別SwiftData保存を使用し、空白のみはタイトル解除とする。保存失敗時は編集画面に入力を保持してエラーを表示する。
