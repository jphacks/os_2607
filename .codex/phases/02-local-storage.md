# Phase 2: SwiftDataによるローカル保存

## Goal

Encounter履歴、累計時間、プロフィールキャッシュを再起動後も参照できるようにする。

## Scope

SwiftDataモデル、Domainとの変換、保存・読込インターフェース、整合性と復旧方針。

## Out of scope

実通信、UWB実測、Supabase接続、Encounterのクラウド同期、ARKit、watchOS。

## Domain assumptions

- Phase 1のルールと時間加算方法を引き継ぐ。
- personIDで相手を識別し、discoveryTokenを永続IDとして保存しない。
- Supabaseが最新プロフィールの正本であり、このphaseのプロフィールはモック由来のキャッシュ。
- キャッシュには本人が公開を許可した情報だけを含める。

## Implementation tasks

- Domainと分離したSwiftDataモデルと変換処理を定義する。
- Encounterの識別と重複保存防止、相手別累計の保存方式を決める。
- 履歴と累計の更新単位、再計算、保存失敗時の扱いを実装する。
- キャッシュの更新時刻・鮮度と差し替え方法を設計する。
- 未終了Encounterの再起動時復旧、削除、スキーマ変更の方針を記録する。

## Acceptance criteria

- 履歴・累計・プロフィールキャッシュが保存・再読込できる。
- DomainにSwiftData依存が入らない。
- 同じEncounterの再保存で累計を二重加算せず、別Personの情報を混同しない。
- 再起動・保存失敗後の履歴と累計の整合性が、決めた復旧方針に従う。
- キャッシュを最新プロフィールの正本として扱わない。

## Manual verification

1. 複数Personの仮Encounterと公開許可済みプロフィールを保存する。
2. 再読込・アプリ再起動後に履歴、累計、キャッシュを比較する。
3. 同じEncounterを再保存し、累計が増えないことを確認する。
4. 未終了Encounterや保存失敗を再現し、決めた復旧結果と比較する。
5. キャッシュ更新後に古い情報が残らないことを確認する。

## Open questions

- 履歴を根拠として累計をいつ再計算するか。更新をどう一貫させるか。
- 未終了Encounter、保存容量、保持期間、削除、マイグレーションの方針は何か。
- キャッシュの有効期間と公開撤回時の削除方法は何か。
- 仮ルールの2m・10秒、3m超・15秒、60 / 180 / 300秒を変更した際、過去の累計・Revealを再評価するか。