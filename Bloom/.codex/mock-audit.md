# モック・固定値の棚卸しと実データ統合（2026-10-18）

対象: BloomアプリのSwiftソース、起動時の依存注入、旧画面、テスト。既存の未コミット変更を維持。以下の「旧」は今回の置換前の実装を指す。

## 棚卸し

| 場所 | モック・仮実装だった内容 | 現在の対応 |
| --- | --- | --- |
| Frontend/BloomApp.swift / HomeView | 大輔・なつみ・悠斗・みさきの4人、距離、経過時間、累計時間、趣味、遭遇中/つながり済み状態 | 削除。Network/NIの最新観測のpersonIDからSupabaseの公開プロフィールを取得 |
| 同 / profileName | 初期名「あおい」、UserDefaultsの名前 | 認証ユーザーのProfile.displayNameを使用 |
| 同 / nearbySection | 「近くに2人」 | 現在表示可能な公開プロフィール数を使用 |
| 同 / EncounterPerson.progress | 固定累計と閾値、最低8%に水増しする進捗 | 削除。終了済みの実測Encounterを根拠にReveal判定 |
| 同 / EncounterProfileView | 人物IDに応じた固定自己紹介、趣味、公開済み写真、リンク/音楽/動画タイル、未確認のつながりバッジ | 削除。本人が公開許可した実Contentだけを表示。写真は偽画像で代用せず実名の頭文字を使用 |
| 同 / lockedSection | 実在しない「これから公開」の項目一覧と解除条件 | 削除。存在や公開許可を確認できない項目を捏造しない |
| 同 / header | 動作のない通知ボタン | 削除。通知機能自体は未実装 |
| 同 / didCompleteOnboarding | ローカルBoolだけで認証済みとしてHomeへ進む | Supabaseセッションと本人Profileを再取得。取得失敗は再試行画面 |
| Frontend/AppPages.swift / MessagesPage | 固定の3会話、メッセージ、時刻、未読マーク | 削除。「準備中」を表示。送受信機能は未実装 |
| 同 / ChatThreadPage | 固定の3吹き出し、送信をローカル配列に追加するだけ | 削除。送信成功を装う操作は提供しない |
| 同 / EncounterHistoryPage | 空のとき「3人」「26分」、固定の人物/日付 | 削除。SwiftDataの本人アカウントの記録だけを表示 |
| 同 / recordRow | 履歴から仮Personを生成し、累計600秒やつながり済みを補完 | 削除。保存済みpersonID/日時/実測時間を使用 |
| 同 / MyProfilePage | 固定自己紹介・音楽/カフェ/散歩・新しいお店、3分/10分/15分、初期公開オン | 削除。Supabase取得・更新・追加・削除へ接続。新規Contentは空/非公開/0秒 |
| 同 / editableProfileFields等 | UserDefaultsだけのプロフィール編集 | 実Repositoryの成功後に反映。失敗時はエラーを表示 |
| Frontend/Auth/AuthFlowView.swift | ローカル完了フラグ、プロフィール作成後の趣味Content自動作成 | 完了時はセッション再取得。趣味は本人がプロフィール画面で明示的に作成 |
| Frontend/UWBConnectionService.swift | 認証と無関係な端末ID、名前だけの旧UserDefaults履歴読込 | AuthのUUIDをpersonIDとして注入。新履歴はownerIDで分離。所有者不明の旧履歴は保持するが表示/移行しない |
| Backend/Profile/ProfileRepository.swift | LocalProfileRepositoryがUserDefaultsに書くだけ | 既にターゲット除外済み。旧コードを保持。本番からの参照なし |
| Backend/Repositories/MockProfileRepository.swift | メモリ上のProfile/Content/Auth、UUID/時刻生成 | テスト用として保持。本番のBackendDependencies.liveからは一切使用しない |
| NearbyInteraction/Infrastructure/Identity/LocalPersonIdentity.swift | 診断用の端末ローカルUUID | 通信診断用に保持。メインアプリは認証UUIDを明示注入。乱数の仮ユーザーへのフォールバックなし |
| BloomApp.swift / ContentView.swift、Frontend/UWBConnectionsView.swift | 旧エントリ/距離診断画面 | 旧エントリはターゲット除外。距離診断ビューは主画面に使用しない。実測用コードは保持 |
| BloomUWBTests、Tests/NearbyInteraction | テスト入力の人物・UUID・距離・時刻・token | 検証用fixtureとして保持。本番データではない |

認証nonce/state、EncounterのUUID、編集sheetの一時ID、通信セッションのUUIDは実際の識別・セキュリティ用途であり、モック値ではない。色・余白・花びらの形・モノグラムは装飾であり、実在する写真や属性を装わない。

## 実装したデータ経路

- BackendDependencies.live → SupabaseAuthRepository / SupabaseProfileRepository。起動・復帰でセッションと本人プロフィールを確認。
- Auth UUID → Network.frameworkのpersonID交換 → NI観測 → 公開プロフィール取得 → NearbyPeoplePageの人物カード/詳細。
- SDK非依存EncounterTracker → EncounterHistoryStore（SwiftData）→ アカウント別の終了済み履歴 → RevealRule。
- コンテンツはisPublicと保存済み累計時間の両方を満たしたものだけを表示。初回/更新時はRLSを通して取得。
- プロフィール編集は取得/保存/削除の実APIを使用。新規項目は非公開が初期値。

## 暫定判断（Phase 1–4の部分実装）

- **D21 / 暫定 / 2026-10-18**: EncounterRulesの2m以下10秒で開始、3m超15秒で終了。待機時間は加算しない。遭遇中の2m超〜3m以下は加算する。距離欠損、3秒超の観測間隔、切断、非公開化、停止/バックグラウンドで区切る。再接近は開始待機からやり直す。閾値は変更可能。初期10秒は開始時刻より前なので履歴にも入れない。
- **D22 / 暫定 / 2026-10-18**: 経過時間はContinuousClockで測り、壁時計は日時表示だけに使う。同じ観測を繰り返し加算しない。前後の観測がともに加算対象の場合のみ区間を加算。1秒周期で最新観測を処理するため全NIサンプルの積分ではない。
- **D23 / 暫定 / 2026-10-18**: 終了したEncounterのみ永続化。通常の停止/背景移行でも終了・保存。強制終了やクラッシュ時の未終了区間は失われ、推測復元しない。保存失敗は未保存キューとエラーを保持して再試行するが、プロセス終了までの耐久性はない。
- **D24 / 採用 / 2026-10-18**: SwiftDataにownerID/personID/EncounterID/日時/実測時間を保存。ownerIDとEncounterIDで重複排除。累計は保存済み履歴から計算し、別の累計値と二重管理しない。削除は現在アカウントのみ。旧所有者不明履歴は新アカウントへ結びつけない。
- **D25 / 暫定 / 2026-10-18**: 公開プロフィールはメモリ内で最長15秒（監視周期分の遅れを含む）、12秒後から再取得。期限切れ/取得拒否/通信エラーで取り下げる。永続プロフィールキャッシュは導入しない。オフラインでは古いプロフィールを表示しない。公開撤回の即時push反映は未実装。
- **D26 / 暫定 / 2026-10-18**: Revealは保存済みの終了したEncounterだけを使う。現在の遭遇中の時間で即時解除しない。本人の公開許可と個別unlockAfterSecondsを使用。履歴削除で再ロック。サーバー側のRLSは公開許可を強制するが時間条件は強制しないため、時間条件は秘密情報の保護機構ではない。
- **D27 / 採用 / 2026-10-18**: 認証UUIDをpersonIDとして本番経路へ注入。受信したUUIDは自己申告であり相手端末所有者の本人証明ではない。公開取得の認可はSupabase側に委ねる。
- **D28 / UI方針 / 2026-10-18**: 標準TabView/NavigationStack/Form/List、標準Liquid Glass操作部品を維持。独自性は花びらモチーフ、大きな見出し、インディゴ〜ティールの背景、人物カード、実Contentの引用で作る。カスタムタブバーは作らない。

## 今回置換できなかった機能・残る制約

1. DM/未読/通知: 会話・メッセージ・参加権限のスキーマ、Realtime/通知経路がない。既存の擬似UIを削除。設計とDB実装が必要。
2. アバター/画像/動画アップロードとメディア表示: Storage bucket/公開条件/署名URL/アップロード経路が未整備。実URLのContentはリンクとして開く。画像を捏造しない。
3. 通信相手の本人証明・暗号化: 現transportのID交換のみでは保証できない。公開プロフィールを持つIDの偽装への対策は未実装。
4. サーバーで強制するReveal: 現RLSは公開Contentのvalueを時間条件前にも取得可能。信頼できる時間証明とサーバー側の認可設計が必要。
5. Appleログインのリモート設定: クライアント実装は既存。以前の設定確認ではApple provider無効。現在のMCP接続に対象プロジェクトの管理権限がなく変更できない。
6. SwiftDataの永続プロフィールキャッシュ、未終了区間のクラッシュ復旧、複数端末の累計統合: 今回は未実装。最新情報と公開撤回を優先し、古いキャッシュや推定時間は使わない。
7. 実機E2E: 2台以上の対応iPhoneで発見/測距/プロフィール取得/保存、背景移行、公開撤回、権限拒否の確認が必要。今回利用可能なDeviceInteraction対象はSimulatorのみ。D19に従いSimulatorでUIや測距成功を装わない。

## 検証

- Xcode BuildProject: 成功、エラー0。テストターゲットを含むビルドも成功。
- Xcode RunAllTests: 実行時点の18件がnot run。成功扱いにしない（後から保存テスト1件を追加）。
- 同じDomain/SwiftDataソースとEncounterTrackerTests/EncounterHistoryStoreTestsを一時SwiftPM packageへコピーしmacOSでSwift Testingを実行: **9テスト成功**。距離/時間境界、待機除外、欠損/古い/重複観測、別Person、時計変更、60/180/300秒と公開許可、保存再読込、同一batch/再保存の重複排除、アカウント分離、本人分のみ削除を検証。
- 一時package実行ではCoreDataのstore changed notification登録警告が出たが、保存/再読込のassertionは成功。iOS実機でのSwiftData検証の代替とはしない。
- git diff --check: 正常。実行経路に固定人物・会話・累計値・ローカル認証完了フラグ・MultipeerConnectivity参照なし。
- UIの実機スクリーンショット/操作、実ユーザーのSupabase CRUD/RLS E2E、UWB実測は未確認。

Phase 1–4全体の受け入れ完了は主張しない。特にPhase 2のプロフィールキャッシュ、Phase 3の実機検証、Phase 4のアクセス制御E2Eは残る。
