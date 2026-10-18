# Supabase backendとXcode統合の実装記録

更新日: 2026-10-17

## 概要

Bloom iOSアプリからSupabase AuthとData APIを利用するbackendを追加し、SwiftUIの認証・初回プロフィール設定画面からRepositoryを使うよう接続した。Supabaseはリモートプロジェクトを使い、ローカルSupabase環境は作成していない。

対象プロジェクトは `10192006haruto's Project`（project_ref: `sapdpmepmeeexppirzle`）。

## リモートDB

`public.profiles`と`public.profile_contents`を作成した。AuthユーザーのUUIDをpersonIDとして`profiles.id`に使い、Authユーザー削除時はProfileとそのContentを連鎖削除する。

両テーブルでRLSを有効にし、本人所有条件を`auth.uid()`で確認するPolicyを設定した。本人は自分の情報を読み書きできる。別の認証ユーザーは、`is_discoverable = true`のProfileと、そのProfileの`is_public = true`のContentだけを読める。ProfileとContentのUPDATE Policyには`USING`と`WITH CHECK`の両方がある。更新日時Triggerと`(profile_id, display_order)` Indexも作成した。

適用したSQLは[Backend/Database/schema.sql](../Bloom/Backend/Database/schema.sql)に保存している。MCPでの適用後にテーブル、制約、Index、RLS Policyを再取得し、トランザクションを最後にrollbackする権限検証も実行した。検証用データは残していない。SecurityおよびPerformance Advisorsの警告は0件だった。

## Swift backend

`Bloom/Backend/`にDomain Model、入出力DTO、Mapper、Supabase Swift SDKを使うAPI Client、Auth Repository、Profile Repository、Mock、Validation、Errorを置いた。SwiftUI画面は`SupabaseClient`やDTOを直接参照せず、Repositoryを受け取る。

ProfileのGET／POST／PATCH、Profile ContentのGET／POST／PATCH／DELETEを実装した。GET結果はDTOからDomain Modelへ変換し、不正なUUID・日時・content_typeを補完せずエラーにする。Repositoryは入力の空白除去、optional空文字のnil化、長さ・URL・負数検証、エラー変換、Contentの安定ソートを担当する。

Supabase SDKは2.49.0に固定した。AuthパスワードはSupabase Authへ渡し、アプリ独自にはハッシュ化・保存・ログ出力しない。

## SwiftUIとの接続

`Bloom/Frontend/BloomApp.swift`で`BackendDependencies`を作り、認証フローへAuth RepositoryとProfile Repositoryを渡す。`AuthFlowView`はアカウント登録、ログイン、初回プロフィール作成にbackend Repositoryを使用する。メール確認が必要で登録直後にセッションがないときは、プロフィール入力へ進まず確認を案内する。

Supabase URLとPublishable Keyは`Supabase.local.xcconfig`からビルド設定へ渡し、既存のルート`AppInfo.plist`内の置換キーからアプリへ渡す。`AppInfo.plist`はResourcesへ別途追加せず、Xcodeの`ProcessInfoPlistFile`入力として扱う。DerivedDataの実際のアプリInfo.plistで設定値が欠落していたことを確認したため、この構成へ修正した。Publishable Key以外の秘密情報はアプリに含めない。

## Xcodeの重複ビルドエラー修正

File System Synchronized Groupに、同じファイル名を持つSwiftソースが複数あったため、Xcodeが同一の`.stringsdata`出力先へ複数のビルドコマンドを割り当てていた。

- `Bloom/BloomApp.swift`と`Bloom/Frontend/BloomApp.swift`が重複していた。起動画面を持つ`Frontend/BloomApp.swift`を使い、ルート直下の旧`BloomApp.swift`をBloomターゲットから除外した。
- `Bloom/Backend/Profile/ProfileRepository.swift`と`Bloom/Backend/Repositories/ProfileRepository.swift`が重複していた。新backendのRepositoryを使い、旧ローカルRepositoryファイルをBloomターゲットから除外した。
- 古いローカルProfile実装の型名も新backendの型と重複していたため、同じ除外でコンパイル対象から外した。ファイルは削除していない。
- 共有SchemeのRunおよびTest環境に`IDEPreferLogStreaming=YES`を加え、Xcodeのログ初期化タイムアウトへの推奨設定を反映した。

`AppInfo.plist`はBuild Settingsの入力として一度だけ処理する。同期グループ内の別Info.plistをアプリリソースとして含めないことで、`Multiple commands produce .../Info.plist`の再発を避ける。

## 検証と未確認事項

- backendの`swift build`成功。
- backendの`swift test`で7件成功。Model/DTO変換、日付・UUID、Validation、DTOの送信フィールド、ソート、Error変換、Mock CRUDを確認。
- リモートDBで本人操作、他人の更新拒否、非公開Profile/Contentの遮断、主要な制約を確認。
- Xcodeプロジェクトの`plutil -lint`と変更差分の空白チェックに成功。
- 実行環境はCommand Line ToolsのみでXcodeが入っていないため、iOS Simulator向けの`xcodebuild`は実行できていない。重複`.stringsdata`エラーとログタイムアウトの解消は、Xcode上での再ビルド後に確認が必要。
- Authの実ユーザーE2E、確認メール・パスワード再設定の画面、SwiftDataキャッシュとEncounter/Revealの統合は未実装・未検証。

