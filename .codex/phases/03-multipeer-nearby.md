# Phase 3: Network.frameworkとNearby Interaction

## Goal

近くの端末と識別情報を交換し、実測した距離・方向をEncounter判定につなぐ。

## Scope

端末発見、接続、personID / discoveryToken交換、計測アダプター、切断・再接続、モック入力との切り替え。

## Out of scope

Supabase同期、Encounterのクラウド同期、ARKitによる演出、watchOS、本格的な画面デザイン。

## Domain assumptions

- Nearby Interactionは距離・方向を取得する。
- Network.frameworkは端末発見・接続・token交換・personID交換を担う。
- personIDは永続ID、tokenは通信・計測セッションに紐づく情報。
- 接続成立だけではEncounterを開始しない。欠損は近接として扱わない。
- Phase 1で決めた仮ルールと欠損時の判定を利用する。

## Implementation tasks

- peer・token・personIDの対応と交換メッセージを設計する。
- 接続・交換・計測開始・切断・セッション無効化のライフサイクルを実装する。
- SDK値をDomainのProximityとConnectionへ変換する。
- 計測不能・権限拒否・再接続・token更新時の状態を扱う。
- Simulator用の距離・方向・欠損・接続状態モックを用意する。
- 実機観測をEncounter判定とSwiftData保存へ接続する。

## Acceptance criteria

- 対応実機同士で発見・接続・personID / token交換と距離・方向取得を確認できる。
- 再接続やtoken変更で別Personの履歴を作らず、識別の対応を維持できる。
- SDK型がDomainへ漏れず、Simulatorではモック経由で処理できる。
- 切断・欠損時に誤って近接時間を加算しないことを、決めたルールで確認できる。
- UWBの実測結果と未確認事項を記録している。

## Manual verification

1. 対応実機2台の機種・OS・権限状態を記録する。
2. 発見、接続、personID / token交換を確認する。
3. 2m以内で10秒継続、3m超で15秒継続させ、観測値・状態遷移・保存結果を確認する。
4. 方向変化、遮蔽、権限拒否、切断・再接続を確認する。
5. Simulatorでは同等の入力をモックで与える。実測の証拠とは分けて記録する。

## Open questions

- 実測を踏まえ、2m・10秒、3m超・15秒の仮条件を調整するか。Revealの60 / 180 / 300秒も体験に合うか。
- 計測誤差・更新間隔・欠損に対する許容条件は何か。
- 同時接続人数、バックグラウンド動作、対応OS・機種はどこまで含めるか。
- 受信したpersonIDの真正性をどう確認するか。ARKitを追加する必要があるか。

## 今回の実装範囲（2026-10-17）

Network.frameworkのSwift Concurrency APIで1対1接続し、Nearby Interactionの距離・方向を専用UIに表示する。D11〜D18参照。ファイル名は既存リンク維持のため変更しない。

- 機能本体: `Bloom/Bloom/NearbyInteraction/`
- 手順・検証結果: [UWB検証記録](../uwb-verification.md)
- Encounter・SwiftData連携と実機計測は未完了。Phase 1・2は今回の対象外。
