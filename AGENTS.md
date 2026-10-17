# 開発時のルール
- 実装前に開発ガイド、関連する設計資料とphaseを読み、依頼された範囲だけを変更する。
- 開発はDomain → SwiftData → Multipeer Connectivity / Nearby Interaction → Supabaseの順に進める。各phaseの受け入れ条件を確認する。
- Domain層をSwiftUI、NearbyInteraction、MultipeerConnectivity、Supabase SDK、SwiftDataから分離する。SDK型や永続化モデルをDomainに持ち込まない。
- Nearby Interactionは距離・方向の取得、Multipeer Connectivityは端末発見・接続・token交換・personID交換に使う。
- personIDをアプリ固有の永続IDとして扱う。discoveryTokenを永続的なユーザーIDや保存データの主キーに使わない。
- Supabaseを最新プロフィールの正本、SwiftDataをEncounter履歴・累計時間・プロフィールキャッシュの保存先とする。
- プロフィールは本人が公開を許可した情報だけを扱う。開示条件を満たしても公開許可を省略しない。
- 距離・時間・Revealの閾値は変更可能な仮ルールとして扱う。未決定事項を確定仕様として実装せず、判断を.codexに記録する。
- UWBの実測は対応実機で確認し、Simulatorではモックを使う。モックの成功を実機検証の代わりにしない。
- 既存の作業中の変更を保持し、サンプルを変更する場合も依頼の範囲を確認する。変更内容、確認結果、未確認事項を報告する。

## Documentation

作業前に、タスクに関連する以下のドキュメントを確認する。

- `.codex/domain.md`
- `.codex/architecture.md`
- `.codex/decisions.md`
- `.codex/testing.md`

実装フェーズに関係する場合は、
`.codex/phases/` の該当ファイルも確認する。
