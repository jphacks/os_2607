# Bloom backend

iOSアプリ内のSupabaseデータアクセス層。リモートプロジェクトは `10192006haruto's Project` / `sapdpmepmeeexppirzle`。
Supabase MCPで作成済み。ローカルSupabase環境は不要。

## 構成

- Config: `SupabaseConfig.swift`, `Supabase.xcconfig`, `Info.plist`
- Database: `schema.sql`（適用SQL全体）, `002_raw_lengths.sql`（追加適用分）, `verify_rls.sql`（rollback付き検証）
- Models: `AuthUser`, `Profile`, `PublicProfile`, `ProfileContent`, `ProfileContentType`、Profile/ContentのCreateInput・UpdateInput
- DTO: ProfileとProfileContentそれぞれのRowDTO・InsertDTO・UpdateDTO（計6型）
- Mappers: `ProfileMapper`, `ProfileContentMapper`
- API: `SupabaseProvider`・`BackendDependencies`, `ProfileAPI`, `ProfileContentAPI`
- Auth: `AuthRepository`, `SupabaseAuthRepository`
- Repositories: `ProfileRepository`, `SupabaseProfileRepository`, `MockProfileRepository`
- Errors: `BackendError`, `ProfileValidationError`・`ProfileValidation`

Model/入力値はFoundationのみを使う。DTOはsnake_caseのCodingKeysを持ち、Mapperで日時を検証・変換する。不正日時・UUID・未知のcontent_typeを補完しない。
Repositoryが入力整形、検証、API呼出、変換、エラー処理、displayOrder→createdAtの安定ソートを担う。同順位はAPIのid順で安定させる。通信は公式Supabase Swift SDK 2.49.0。 

## 設定

`Config/Supabase.local.xcconfig`はgitignore対象。今回の作業環境ではMCPから取得したURLと公開用キーを設定済み。
別のcheckoutでは次の形式で作成する。`//`はxcconfigのコメントになるためURLの記法に注意。

```text
SUPABASE_URL = https:/$()/YOUR_PROJECT_REF.supabase.co
SUPABASE_PUBLISHABLE_KEY = sb_publishable_YOUR_KEY
```

Configは公開用キー形式だけを受け付ける。privileged key、DBパスワード、MCP access tokenを渡さない。
Info.plistでbuild settingをアプリへ受け渡す。Swiftコードへの本番値の埋め込みはない。
SDKのセッション管理に任せ、アプリ独自にパスワードを保存・ハッシュ化・ログ出力しない。

## SwiftUIからの利用

起動時の依存組立箇所で一度作成し、同じセッションを使うRepositoryを画面に渡す。

```swift
let backend = BackendDependencies.live(config: try SupabaseConfig.load())
try await backend.authRepository.signIn(email: email, password: password)
let profile = try await backend.profileRepository.fetchProfile(personID: personID)
let created = try await backend.profileRepository.createContent(
    ProfileContentCreateInput(type: .text, title: "趣味", value: "読書",
        unlockAfterSeconds: 60, displayOrder: 0, isPublic: true)
)
```

`Bloom/Examples/ProfileRepositoryExampleView.swift`はRepositoryのみを受け取る実行可能なSwiftUI利用例。既存の起動画面は保持している。サインイン後、必要な画面へ組み込む。
認証画面、メール確認の画面、パスワード再設定完了の画面は今回追加していない。Authにメール確認が設定されている場合、signUp後はメール確認・signIn後にcreateProfileする。
Password Resetはメール送信要求まで実装。Supabase DashboardのSite URLとメール配信設定を確認し、再設定完了のWeb画面またはアプリのdeep linkフローを用意する。

## 操作と更新契約

| 対象 | GET/select | POST/insert | PATCH/update | DELETE/delete |
| --- | --- | --- | --- | --- |
| Profile | 自分 / personID | ログイン本人 | ログイン本人 | 提供しない |
| Content | personIDで一覧（ページ取得） | ログイン本人 | IDと所有者で指定 | IDと所有者で指定 |

UpdateInputは全編集可能項目を受け取る。optional nilはJSON nullとして値を消去する。変更しない項目には現在値を渡す。ID・所有者・createdAt・updatedAtをPATCHしない。Profile INSERTのIDはAuth ID。Content INSERTのID・時刻はDBが生成する。
削除対象が存在しない／他人所有の場合はnotFound。同じ理由で取得不可と不存在を区別して漏らさない。

URL系ContentはHTTP/HTTPS URLを要求する。avatarPathはStorage等のパスとして保持し、画像アップロード・署名URL生成は実装対象外。

## リモートスキーマと権限

- `public.profiles.id` → `auth.users.id`, `profile_contents.profile_id` → `profiles.id`。双方ON DELETE CASCADE。
- 表示名1–50、所属100以下、bio500以下、title1–100、value1–2000文字。型5種、秒数・順序は非負整数。DBの文字長は保存値自体にも適用。
- 主キーIndex2本、`profile_contents_profile_order_idx(profile_id, display_order)`。
- 両テーブルRLS有効。profilesはselect/insert/update、contentsはselect/insert/update/deleteの7ポリシー。
- 所有者以外の参照にはis_discoverable、Contentにはさらにis_publicが必要。anonに権限なし。
- UPDATEのUSING/WITH CHECKにauth.uid()所有者条件。列権限でもID・所有者・作成日時の更新を禁止。
- `bloom_set_updated_at()`はsearch_pathを固定し、両テーブルのBEFORE UPDATE Triggerでupdated_atを更新。
- `20261017071329_create_bloom_profiles`, `20261017071926_enforce_bloom_stored_text_lengths`をMCPで適用。

schema.sqlは空の対象プロジェクトで一度だけ適用する再現用SQL。既存DBへ再適用しない。002はschema.sqlの末尾にも含まれるため重複適用しない。

## 検証結果（2026-10-17）

- リモートカタログからテーブル、制約、Index、RLS、Policy、Triggerを再取得。
- `verify_rls.sql`: 本人Profile GET/POST/PATCH、本人Content GET/POST/PATCH/DELETE、他人の変更拒否、公開参照、非公開Profile/Contentの参照拒否、空表示名・長すぎるbio・負数・不正typeの拒否が成功。全検証データをrollback。
- SQLのauthenticatedロールとJWT subを切り替えたDB検証。実ユーザーのAuthログインを通したData APIのE2E検証とは異なる。
- Security Advisors: 警告0。Performance Advisors: 警告0。
- `swift build`: SDKを含むbackendのmacOSビルド成功。
- `swift test`: 7テスト成功。DTO/Model変換、snake_case、UUID/Date、不正値、送信フィールド、null消去、整形、URL、非負数、安定ソート、エラー変換、Mock CRUD/公開制御を検証。
- `plutil -lint`: Xcodeプロジェクト構文正常。
- iOSメインターゲット: XcodeがなくCommandLineToolsのみのためxcodebuild実行不可。Xcode環境で次を実行する。

```sh
swift test
xcodebuild -project Bloom.xcodeproj -scheme Bloom -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

## 未確認・今後の統合

実ユーザーによるAuth・Data API E2E、メール確認・resetメール到達、iOSビルドとSimulator UIは未確認。
Revealの時間条件は表示側の将来の統合対象で、このRLSは公開許可だけを強制する。許可された公開Contentのvalueは時間条件達成前にも取得可能。
SwiftDataキャッシュ、公開撤回のキャッシュ削除、Encounter、NI/Multipeerへの接続は追加していない。Phase 1–4全体の完了を意味しない。
判断はアプリ側 `.codex/backend-decisions.md` に記録。

参照: [Supabase MCP](https://supabase.com/docs/guides/getting-started/mcp)、[Swift初期化](https://supabase.com/docs/reference/swift/initializing)、[Swift更新](https://supabase.com/docs/reference/swift/update)。
