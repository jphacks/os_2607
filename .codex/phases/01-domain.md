# Phase 1: Domain modelとEncounter / Revealルール

## Goal

SDKに依存しない用語・モデルと、Encounter / Revealの判定を成立させる。

## Scope

Person、Profile、Proximity、Encounter、Reveal、Connection、personID、時間の扱い、相手ごとの累計と開示判定。

## Out of scope

SwiftData、実通信、UWB計測、Supabase、SwiftUI画面の作り込み、ARKit、watchOS。

## Domain assumptions

- personIDは永続ID。discoveryTokenはDomainに持ち込まない。
- 2m以内10秒で開始、3m超15秒で終了する仮ルールを使う。
- 累計60秒で趣味1、180秒で趣味2、300秒で会話のきっかけを開示する仮ルールを使う。
- 公開許可のある項目だけを扱い、ConnectionとEncounterを区別する。

## Implementation tasks

- 用語をSDK非依存のSwift型として表現する。
- 開始待機・遭遇中・終了待機などの状態と遷移を整理する。
- 待機時間の加算、欠損時の連続性、時刻と経過時間の扱いを決めて記録する。
- 時間源と入力観測を差し替えられる判定処理を設計する。
- 相手別累計と公開許可を考慮したReveal判定を実装する。
- 仮の閾値を変更可能にし、境界条件の期待値を整理する。

## Acceptance criteria

- DomainがSwiftUI、NearbyInteraction、MultipeerConnectivity、Supabase SDK、SwiftDataに依存しない。
- 同じ観測と時間入力から同じEncounter / Revealの結果を得られる。
- 開始・終了・開示の閾値前後と一致時の結果が文書化したルールに合う。
- 相手ごとの累計が混ざらず、公開許可のない項目が開示対象にならない。
- 実装結果を左右する未決定事項が解決・記録されている。

## Manual verification

1. 仮のpersonIDと時刻付き距離列を用意する。
2. 2m以内の9秒・10秒、3m超の14秒・15秒に相当する入力で状態を確認する。
3. 2m・3mちょうど、途中の条件解除、欠損を入力し、決めた遷移と比較する。
4. 累計59 / 60、179 / 180、299 / 300秒で開示項目を確認する。
5. 公開許可がない項目と別Personの入力で、誤開示・累計混在がないことを確認する。

## Open questions

- 2m・10秒、3m超・15秒、累計60 / 180 / 300秒は適切か。すべて変更可能な仮ルール。
- 待機時間、2m超から3m以内、欠損期間を累計に含めるか。
- personIDの発行・保持方法、時刻逆転、重複観測、Reveal取り消しをどう扱うか。
