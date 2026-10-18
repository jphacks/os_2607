# フロントエンド・バックエンド接続の変更箇所

調査日: 2026-10-18。対象: 現在の作業ツリーの `Bloom/`。本書は変更箇所の調査と責務整理。今回、フォルダ名を `Backend` に統一し、関連パスを更新した。アプリの処理・DBは変更していない。

## 結論

Supabase向けの認証・プロフィールCRUDは存在するが、フロントの起動・認証・プロフィール編集・人物一覧から利用する経路がつながっていない。加えて、人物ID、通信方式、Encounter保存、Reveal判定が別々に実装されている。Repositoryの差し替えだけでは全体は動作しない。

このリポジトリの `Backend/` は**iOSアプリ内のデータアクセス層**であり、独立したAPIサーバーではない。処理の委譲は、SwiftUI → Application/ViewModel → Repository → API → Supabaseという流れで組み立てる。Encounter判定はDomain、履歴・累計・キャッシュ保存はSwiftDataの責務であり、すべてをSupabaseへ移すわけではない。

以下のパスはリポジトリルート `os_2607/` 基準。記載した新規ファイル名は候補で、確定仕様ではない。

## 1. 接続より先に解消する構成上の問題

| 変更対象 | 現状と根拠 | 必要な対応 |
| --- | --- | --- |
| [Xcodeプロジェクト](../Bloom/Bloom.xcodeproj/project.pbxproj)、[旧起動点](../Bloom/Bloom/BloomApp.swift)、[フロント起動点](../Bloom/Bloom/Frontend/BloomApp.swift) | 両ファイルに `@main struct BloomApp` がある。同期グループの `membershipExceptions` は現在 `Supabase.local.xcconfig` のみ | 製品画面側を起動点とする場合、旧起動点をターゲットから除外するなどして一意化。単独UWB確認画面の扱いも整理する |
| [旧ProfileRepository](../Bloom/Bloom/Backend/Profile/ProfileRepository.swift)、[現行ProfileRepository](../Bloom/Bloom/Backend/Repositories/ProfileRepository.swift)、`Backend/Models/` | 同名protocolと `ProfileCreateInput`、`ProfileContentCreateInput`、`ProfileContentType` が重複。旧createメソッドはVoid、現行は作成モデルを返す | 現行Repository・Modelsへ統一し、旧ローカル実装の利用箇所を移行。単に旧ファイルを除外するだけでは `LocalProfileRepository()` の呼出が残る |
| [AuthFlowView](../Bloom/Bloom/Frontend/Auth/AuthFlowView.swift) のRepositoryプロパティ | `LocalAuthRepository()` を生成しているが、現在の `Bloom/Bloom/` 内に定義が見つからない | [AuthRepository](../Bloom/Bloom/Backend/Auth/AuthRepository.swift) の契約でSupabase実装を注入する |
| [Supabase設定](../Bloom/Bloom/Backend/Config/Supabase.xcconfig)、[Config用Info.plist](../Bloom/Bloom/Backend/Config/Info.plist)、[AppInfo.plist](../Bloom/AppInfo.plist)、[UWBInfo.plist](../Bloom/Bloom/NearbyInteraction/Resources/UWBInfo.plist) | Debug/Releaseの `INFOPLIST_FILE` はConfig用plist。そこにはSupabase設定キーだけがあり、通信権限・Bonjour設定は別plistに分散している | 使用するInfo.plistに設定を集約し、生成されたアプリのInfo.plistを検証する。Network版のBonjour型は `_bloom-uwb._tcp`。plistのリソース重複も確認 |

これらはソースと設定の静的確認で検出した問題。今回ビルドを実行してエラーを再現したものではない。Supabase SDKの参照と2.49.0固定、Debug/Releaseのxcconfig参照はすでにあるため、SDKの新規導入からやり直す必要はない。ローカル設定値の有効性は未確認。

## 2. 既存ファイルの変更一覧

### 起動・認証・依存の受け渡し

| 変更対象・シンボル | 現在の処理 | 変更内容・委譲先 |
| --- | --- | --- |
| [Frontend/BloomApp.swift](../Bloom/Bloom/Frontend/BloomApp.swift): `BloomApp.body` | `didCompleteOnboarding` だけで画面を切り替える。BackendDependencies生成なし | 起動側で `SupabaseConfig.load()` → `BackendDependencies.live(config:)` を一度組み立て、Application/ViewModelへ共有。初期化エラーを画面状態へ反映 |
| 同上、[AuthFlowView](../Bloom/Bloom/Frontend/Auth/AuthFlowView.swift): `submitAccount()` | 新規登録直後にプロフィール画面へ、ログイン直後にHomeへ遷移 | `authRepository.currentUser()` と `profileRepository.fetchMyProfile()` を使う認証状態管理へ委譲。確認メール待ち、セッションなし、プロフィール未作成、取得失敗を区別。ローカルフラグだけでログイン済みとしない |
| [AuthFlowView](../Bloom/Bloom/Frontend/Auth/AuthFlowView.swift): `saveProfile()` | ローカルProfile作成後、趣味を別保存して完了フラグを立てる | 現行Repositoryの `createProfile` / `createContent` を呼び、返却モデルをアプリ状態へ反映。Profileだけ保存成功した場合に再試行で重複作成しない復旧手順を設計 |
| [SupabaseProvider.swift](../Bloom/Bloom/Backend/API/SupabaseProvider.swift): `BackendDependencies.live`、[SupabaseAuthRepository](../Bloom/Bloom/Backend/Auth/SupabaseAuthRepository.swift) | 共有clientを使う実装自体はある | 既存実装を接続先として再利用。サインアウト・セッション失効時は画面、通信、ユーザー別キャッシュを切り替えるApplication処理を追加。必要なら認証状態の通知契約を拡張 |

`signUp()` の戻り値はVoidであり、成功だけではセッションの存在を表さない。メール確認ありの場合はプロフィールINSERTまで進めない。パスワード再設定はメール要求メソッドのみ存在し、完了画面・リンク処理は別途必要。

### 本人プロフィールの取得・編集・保存

| 変更対象・シンボル | 現在の処理 | 変更内容・委譲先 |
| --- | --- | --- |
| [AppPages.swift](../Bloom/Bloom/Frontend/AppPages.swift): `MyProfilePage`、`loadFields()` | 名前・所属・bio・追加項目をAppStorageや固定配列から読む | `fetchMyProfile()` と本人IDの `fetchContents(personID:)` で取得し、編集用状態へ変換。読み込み中・未作成・取得失敗を表示 |
| 同上: `saveFields()`、`addField()`、`removeField(id:)` | JSONを `editableProfileFields` に保存するだけ。名前もローカルBinding更新 | Profileは `updateProfile`、項目は `createContent` / `updateContent` / `deleteContent` へ委譲。編集中と保存済みを分け、失敗表示・再試行・送信中の多重操作防止を追加 |
| 同上: `EditableProfileField` | 型情報がなく、ローカルUUID・内容・公開までの「分」を持つ | DBのcontent IDを保持し、`ProfileContent.type`、`value`、`unlockAfterSeconds`、`displayOrder`、`isPublic`へ対応付ける。新規作成時はDB返却IDへ置換 |
| [AuthFlowView](../Bloom/Bloom/Frontend/Auth/AuthFlowView.swift)、同上 | 初回趣味の保存先は `profileContents`、編集画面の読込先は `editableProfileFields` で異なる | 初回作成と編集を同じRepository・モデルに統一。既存ローカル値を移行するか、テストデータ扱いにするか決める |

留意点:

- 現行UpdateInputは編集可能項目全体を送る契約。optionalのnilは「保持」ではなく削除なので、未編集値は取得済みの値を渡す。
- UIの `revealMinutes` は保存時に秒へ変換する。DBの秒数が60の倍数でない場合に、読み込んだだけで丸めて変更しない設計が必要。
- UI説明は公開時間順、Repositoryは `displayOrder` → `createdAt`（同順位はAPIのID順）で並べる。並び順と送信する `displayOrder` の契約を合わせる。
- 画面の1文字入力ごとに無条件で通信する実装にはせず、保存操作または送信をまとめるタイミングを定める。
- `isDiscoverable` を後から変更するUIは現状不足。初回画面の「あとから変更できる」という案内に対応させる。

### 相手一覧・詳細・Reveal

| 変更対象・シンボル | 現在の処理 | 変更内容・委譲先 |
| --- | --- | --- |
| [Frontend/BloomApp.swift](../Bloom/Bloom/Frontend/BloomApp.swift): `EncounterPerson`、`HomeView.nearbyPeople` | 整数IDの固定4人。距離・時間・趣味・人数も固定値 | personIDをキーに、通信の接続状態、Domainの累計/Reveal、Repositoryの公開プロフィールをApplicationで結合して表示モデルを作る。Color等は表示モデルだけに保持 |
| 同上: `EncounterProfileView` の `revealedSection`、`lockedSection`、`sharedProfileInformation` | 趣味配列・isConnection・固定文言で開示を表示 | `fetchProfile(personID:)` / `fetchContents(personID:)` の結果を使い、公開許可とDomainのReveal結果を満たした項目だけ表示。プロフィール取得不可・公開撤回を扱う |
| 同上: `actionButtons`、`HomeView` の参加切替 | `proximity.connect(to: person.name)`、名前で広告・再接続 | 表示名から接続先を選ぶ処理を廃止し、発見peer/接続IDとpersonIDの対応を使う。接続前のpeer IDと恒久personIDは別物として扱う |

プロフィール取得は受信したpersonIDに対して行うが、受信ID自体を本人確認・認可の証拠にしない。公開プロフィールが取得できることと、目の前の端末がその本人であることは別問題。

### UWB・人物ID・履歴保存

| 変更対象・シンボル | 現在の処理 | 変更内容・委譲先 |
| --- | --- | --- |
| [Frontend/UWBConnectionService.swift](../Bloom/Bloom/Frontend/UWBConnectionService.swift): `startAdvertising`、`connect` | MultipeerConnectivityを使い表示名で接続相手を管理 | 採用方針に合わせNetwork.framework版へ移行。既存 [UWBMultiPeerSession](../Bloom/Bloom/NearbyInteraction/Application/UWBMultiPeerSession.swift) の発見・接続・eventsをApplicationのアダプターで受ける |
| 同上: `updateEncounter(with:)`、`finishEncounter(at:)` | NI処理とEncounter判定・UserDefaults保存が同じクラス。4m以内5秒で開始、4m超8秒で終了 | 判定をSDK非依存Domainへ、履歴保存をSwiftData Repositoryへ切り出す。設計資料の仮ルール（2m/10秒・3m超/15秒）と差があるため、変更前に判断を記録 |
| [LocalPersonIdentity](../Bloom/Bloom/NearbyInteraction/Infrastructure/Identity/LocalPersonIdentity.swift)、[UWBMultiPeerSession](../Bloom/Bloom/NearbyInteraction/Application/UWBMultiPeerSession.swift): `init(personID:)` | デフォルトはUserDefaultsの端末内UUID。DBはAuth UUID | backend側の既存判断に合わせるなら、認証復元後のAuth UUIDを明示注入する。再ログイン・アカウント切替時はセッションを作り直す。独立personIDへ変更するならDB/API/認証対応表も変更対象 |
| [Frontend/UWBConnectionService.swift](../Bloom/Bloom/Frontend/UWBConnectionService.swift): `EncounterRecord` | 履歴に `personName` しかなく、personIDがない | 履歴IDと相手personIDを別々に保存。名前は表示用スナップショットとしてのみ扱う。既存履歴を同名だけでDB人物に結合しない |
| [AppPages.swift](../Bloom/Bloom/Frontend/AppPages.swift): `EncounterHistoryPage`、`recordRow()` | UserDefaults由来履歴、空時のサンプル表示、配列index由来ID、1区間の時間を累計扱い | SwiftDataから実履歴と相手別累計を取得。空状態を表示し、personIDで詳細を開く。「今日会った人」は区間件数と人数を区別する |

Network版とフロント版はBonjour名だけでなく通信プロトコルも別であり、サービス名の変更だけでは統合できない。Network版の本人認証・暗号化はD17で未実装とされている。既存の接続許可UIをどう引き継ぐかも統合時に設計する。

## 3. 新規実装が必要な領域

以下は現状の `Bloom/Bloom/` に責務を満たす独立実装が見当たらないもの。ファイル配置は候補。

| 新規候補 | 責務 | 関連phase |
| --- | --- | --- |
| `Domain/Encounter.swift`、`EncounterRules.swift`、`RevealPolicy.swift` | 観測と時間源を入力に遭遇状態・相手別累計・公開判定を計算。閾値を変更可能にする | 1 |
| `Application/EncounterRepository.swift`、`ProfileCacheRepository.swift` | Domain値を用いた保存・取得契約 | 2 |
| `Infrastructure/Persistence/` 配下のモデル・Mapper・Repository | SwiftDataにEncounter、累計、公開プロフィールキャッシュを保存。重複加算防止・復旧・鮮度・撤回時削除 | 2 |
| `Application/EncounterCoordinator.swift` | UWB観測をDomainへ渡し、保存・プロフィール同期を調整。観測ごとに無制限にプロフィールAPIを呼ばない | 3–4 |
| `Application/AppSessionModel.swift`、プロフィール編集・一覧用ViewModel | 認証・プロフィール有無による遷移、非同期処理、エラー、再試行、Repository結果の画面反映 | 4 |

起動側でSwiftDataのModelContainerと各Repositoryを組み立てる変更も必要。DomainへSwiftUI、SwiftData、Network、NearbyInteraction、Supabase SDK型を持ち込まない。既存backendのFoundationモデルを再利用・整理する場合も、重複する `Profile` を新設しない。

## 4. DB/API側で再利用する箇所と変更条件

| 対象 | 既存実装 | 統合時の扱い |
| --- | --- | --- |
| [SupabaseProfileRepository](../Bloom/Bloom/Backend/Repositories/SupabaseProfileRepository.swift) | Profile取得/作成/更新、Content CRUD、検証・変換 | 基本CRUDは再利用。UIの処理をここへ接続し、DTO・SDKをViewへ露出させない |
| [ProfileAPI](../Bloom/Bloom/Backend/API/ProfileAPI.swift)、[ProfileContentAPI](../Bloom/Bloom/Backend/API/ProfileContentAPI.swift)、`DTO/`、`Mappers/` | `profiles` と `profile_contents` への通信・変換 | UI接続だけなら基本的に改修不要。項目・ID・認可の契約を変更するときに対応するDTO/Mapperも更新 |
| [schema.sql](../Bloom/Bloom/Backend/Database/schema.sql)、[verify_rls.sql](../Bloom/Bloom/Backend/Database/verify_rls.sql) | ProfileはAuth UUID、Contentはprofile_idで結合。本人更新制約、公開許可の読取制約あり | 既存構造でプロフィール連携可能。現在のリモート適用状態は別途確認。既存DBへ初期schema.sqlをそのまま再適用しない |

DB側の追加検討は以下に限定する。

- **基本Profileの公開同意**: [backend-decisions.md](../Bloom/.codex/backend-decisions.md) は `is_discoverable` を全基本項目の公開同意としている。一方、UI文言は「近くの人に見つけてもらう」であり、所属・bio等の公開範囲が明瞭でない。現契約の同意文言へ直すか、項目別公開を設計しModels/DTO/SQL/RLSまで変更するか決める。
- **Revealの強制場所**: 現行SQLは `unlock_after_seconds` を読取条件に使わず、公開済みContentのvalueは時間達成前にも取得可能。表示制御ならDomain/UIへ統合する。取得自体を禁止する要件なら、信頼できる累計の証明とサーバー側認可を別途設計する。現行RLSだけで時間制限が成立すると説明しない。
- **personIDの契約変更**: Auth UUIDをpersonIDとするbackend判断を採用する限り、DBのID追加は不要。独立IDへ変更する場合はProfile主キー・Auth所有者・外部キー・RLS・APIをまとめて見直す。

Encounter履歴・累計のクラウド同期はphase 1–4の対象外。DBにEncounterテーブルを追加することを今回の接続の前提にしない。

## 5. 接続時のデータ対応

| フロント側 | 接続先・正本 | 注意 |
| --- | --- | --- |
| `EncounterPerson.id: Int`、`personName` | `Profile.id: UUID` / personID | 名前・配列index・discoveryTokenを恒久キーにしない |
| `profileName`、`profileAffiliation`、`profileBio` | `profiles.display_name`、`affiliation`、`bio` | UserDefaultsを最新情報の正本にしない |
| `EditableProfileField.id` | `profile_contents.id` | 作成時のDB返却IDで更新・削除 |
| `content`、`revealMinutes` | `content_value`、`unlock_after_seconds` | 値と分/秒の変換を明示 |
| `isPublic`、`isDiscoverable` | `is_public`、`is_discoverable` | 公開許可と時間条件を両方確認 |
| `totalTime`、`totalSeconds`、`revealedInterests` | SwiftData履歴・累計とDomain判定 | 表示文字列・固定配列から累計を計算しない |

## 6. 推奨実装順と受け入れ確認

1. **構成整理**: 起動点・重複型・未定義参照・Info.plistを整理し、iOSターゲットのビルドを確認する。
2. **Phase 1 / Domain**: 仮閾値と欠損・待機・再起動時の扱いを決め、境界値、相手別累計、公開許可なしの非開示をSDK非依存テストで確認する。
3. **Phase 2 / SwiftData**: 保存・再読込・再起動、重複加算防止、保存失敗後の整合性、キャッシュの鮮度を確認する。
4. **Phase 3 / Network・NI**: Network版を接続し、personIDと観測をApplicationへ渡す。実機2台以上で発見・接続・再接続・欠損を確認。同名ユーザーの履歴が混ざらないことを確認する。
5. **Phase 4 / Supabase**: 共有Repositoryを注入し、登録→確認→ログイン→初回Profile作成→編集→再取得を確認。途中失敗後の再試行、既存プロフィールでの再ログイン、失効・別アカウントへの切替も確認する。
6. **画面までの統合**: 相手の公開項目だけ表示され、Reveal境界で表示が変わること、公開撤回後にキャッシュと画面から消えること、オフライン時に古い情報を最新と表示しないことを確認する。他人の更新・非公開項目読取は実ユーザーのAuth/Data API経由でも拒否を確認する。

検証方針は [.codex/testing.md](../.codex/testing.md) と [各phase](../.codex/README.md) を参照。SimulatorではSDK非依存のモック入力による判定・UI確認を行い、UWB実測の代替とはしない。既存の実UWB単独確認はD19によりSimulator対象外。

未決定事項（閾値、時間加算、移行、キャッシュ期限、公開撤回、通信本人認証等）は実装前に [.codex/decisions.md](../.codex/decisions.md) に理由と影響phaseを記録する。本調査では新たな仕様決定をしていない。

## 7. 今回の範囲外と既存資料との差

- [AppPages.swift](../Bloom/Bloom/Frontend/AppPages.swift) の `MessagesPage` は固定会話、`ChatThreadPage` は `@State` 配列への追加のみ。DM用Repository・DB・送受信処理はない。DMを実動作させるなら別機能の設計が必要で、プロフィール接続だけでは送信できない。
- 写真・動画・音楽・URLの型はbackendにあるが、画像アップロードやStorageアクセス、メディア実表示まで実装済みという意味ではない。
- [既存の統合記録](../Bloom/docs/supabase-backend-and-xcode-integration.md) は、依存注入・メール確認待ち・旧ファイル除外・AppInfo.plist利用を「実装済み」と記載している。**現在の作業ツリーはその状態と一致しない**。本書は現在のソースを根拠とし、過去記録を動作確認の代用にしない。
- backend READMEに記載されたSwiftPMテストやExampleは、現在のファイル一覧では `Package.swift` と該当Exampleが見当たらない。過去の「7テスト成功」を今回再実行済みとは扱わない。統合時には実在するテストターゲットへ必要な検証を配置する。

## 8. フロントエンド側では不要になる処理

ここでの「不要」は、画面側で重複実装する必要がない処理、または接続後に置き換える仮処理を指す。アプリ全体として必要な責務は委譲先に残す。以下は整理方針であり、今回コードの削除・移行は行っていない。

### Application・Domain・Infrastructureへ委譲する処理

| 現在の場所・処理 | フロント側で不要になる実装 | 委譲先・画面が受け取るもの |
| --- | --- | --- |
| `AuthFlowView.submitAccount()`、`didCompleteOnboarding` | ローカル完了フラグだけで認証済みと判断し、登録直後に無条件でプロフィール入力へ進む処理 | ApplicationがAuth Repositoryのセッションと本人Profileを確認し、未認証・メール確認待ち・初回設定・利用可能の状態を返す |
| `AuthFlowView.saveProfile()` | Profileと趣味の連続保存、部分成功からの復旧をView内で管理する処理 | ApplicationがProfile Repositoryを呼び、保存結果・再試行可能なエラーを返す |
| `MyProfilePage.loadFields()` / `saveFields()` | `profileName`・`profileAffiliation`・`profileBio`・`editableProfileFields`を最新プロフィールの保存先として使う処理 | Profile Repositoryで取得・更新し、Applicationが編集状態へ反映。公開プロフィールのキャッシュはLocalStoreへ |
| `UWBConnectionService` の発見・招待・token交換・NI delegate | フロント独自のMultipeerConnectivity / Nearby Interaction実装 | 既存の `NearbyInteraction/` 配下のNetwork・NI実装へ接続。Application経由で接続状態、personID、距離・方向を受け取る。接続許可UIの引継ぎは別途必要 |
| `updateEncounter(with:)` / `finishEncounter(at:)` | 距離・時間の閾値、開始・終了判定を通信サービス内に持つ処理 | `Domain/Encounter.swift` のTracker・RulesをApplicationから利用。ルール差分と欠損時の扱いを確認してから移行 |
| `hello.encounter.records` のJSON読込・保存 | UserDefaultsへのEncounter永続化、名前を人物キーとして扱う処理 | `Application/LocalStore.swift` と `Infrastructure/Persistence/SwiftDataLocalStore.swift` へ委譲。personID付き履歴から相手別累計をApplicationで取得・集計 |
| `EncounterProfileView` の開示条件 | 固定の趣味配列や `isConnection` だけで開示を決める処理 | Applicationが本人の公開許可・累計・DomainのReveal判定を組み合わせ、表示可能な項目を渡す |

`Backend/` 内のAPI呼出、DTOのJSON変換、Mapper、Repositoryの入力検証・ソート・エラー変換を画面に再実装する必要もない。画面はRepositoryの入出力モデルやApplicationの表示状態を使う。SQL・RLS・SDKのセッション保存はそれぞれDB・Backendの責務であり、フロント側の表示制御だけで置き換えない。

### 接続後に取り除く仮処理・旧経路

| 対象 | 置き換え条件 |
| --- | --- |
| `HomeView.nearbyPeople` の固定4人、固定の距離・時間・趣味・人数 | 実際の接続状態と公開プロフィールを表示できたら製品画面から除く。Preview用データとして残す場合は実データと分離 |
| `EncounterHistoryPage` の履歴が空のときのサンプル表示 | SwiftDataの読込と空状態を接続後に置換。履歴がない場合は「履歴なし」を表示 |
| `LocalAuthRepository()` / `LocalProfileRepository()` の直接生成 | 起動側から共有Repositoryを注入後に置換。旧 `Backend/Profile/ProfileRepository.swift` は利用参照を解消してから削除を検討 |
| 名前による `connect(to:)` と履歴・詳細の紐付け、配列index由来の人物ID | 発見peer/接続IDとpersonIDの対応に移行後に置換。同名の人物を同一視しない |
| `Frontend/UWBConnectionService.swift` の旧通信経路 | 接続・停止・権限・欠損・許可UIの代替を接続し、対応実機で検証してから廃止 |

固定DM・チャットは今回のプロフィール連携では実動作しないが、「不要な処理」として削除する判断はしない。メディアアップロードも未実装であり、既存Backendへ接続するだけでは完成しない。

### フロントエンド側に残す処理

- 画面描画、入力フォーム、編集途中の値、フォーカス、タブ・シート等の表示状態。
- 入力補助と即時フィードバック、送信中の多重操作防止、読込中・失敗・再試行・空状態の表示。
- 公開範囲の説明と本人の同意入力、接続許可の操作。Backendへ委譲しても同意UIは必要。
- Applicationから渡された距離・時間の表示整形、開示可能項目の描画、接続・保存等の操作要求。

## 9. 今回確認した作業ツリーとの差分

先行調査後の作業中変更として、旧 `BloomApp.swift`・旧Profile Repository・補助plistはすでにXcodeの `membershipExceptions` に入り、Debug/Releaseの `INFOPLIST_FILE` は `AppInfo.plist` になっている。第1節のこれらは未対応と断定せず、現在の設定とビルド結果で再確認する。

また、`Domain/Encounter.swift`（EncounterTracker・EncounterRules・RevealPolicy）、`Application/LocalStore.swift`、`Infrastructure/Persistence/SwiftDataLocalStore.swift` が存在する。第3節の候補はゼロから新設せず、これらを確認して不足を補う。ファイルの存在だけで各phaseの受け入れ条件や画面連携が完了したとは扱わない。

## 調査・変更・未確認事項

- 確認: 開発ガイド、Domain/Architecture/Decisions/Testing、phase 1–4、Backend判断記録、フロントと保存契約、Xcode設定を読み合わせた。
- 変更: 実フォルダ名を `Bloom/Bloom/Backend` に統一。Xcode参照・除外設定、ローカル設定のgitignore、既存資料のリンクを更新。本書にフロントから委譲・置換する処理と残す責務を追記。
- 保持: 既存の作業中変更と参考サンプル。アプリ処理・DB・仮ルールは変更していない。
- 検証: パス表記、資料の相対リンク、Xcodeプロジェクトの構文、ローカル設定のgitignore適用を確認。
- 未確認: iOSビルド、実ユーザー認証、リモートDB、Data APIのE2E、UWB実機動作。今回の変更で統合完了とはしない。
