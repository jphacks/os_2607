# 開発ガイド

近くにいる人とのEncounterを記録し、Encounterの累計時間に応じてプロフィール情報を段階的に開示するiOSアプリの開発方針。

このディレクトリは設計・実装計画と検証結果を記録する。全phaseの実装完了を意味しない。2026-10-17はユーザー指定によりUWB距離・方向表示だけを先行実装する。

## 確認したリポジトリ構成

- `Bloom/`: SwiftUIアプリ。UWB距離・方向の確認画面を起動する。機能本体はBloom/NearbyInteraction/配下。
- `FindingDevicesWithPrecision/`: Nearby InteractionとARKitを利用する参考サンプル。
- `ImplementingInteractionsBetweenUsersInCloseProximity/`: 端末間の近接計測に関する参考サンプル。
- `ImplementingProximityBasedInteractionsBetweenAPhoneAndWatch/`: iPhoneとApple Watchの参考サンプル。
- ルートの`README.md`: 製品紹介用のひな形。

サンプルの構成や動作条件を、そのまま本アプリの仕様として採用しない。

## 資料の役割

| 資料 | 役割 |
| --- | --- |
| [AGENTS.md](../AGENTS.md) | Codexが実装時に守る簡潔なルール |
| [domain.md](domain.md) | 用語、仮ルール、境界条件と未決定事項 |
| [architecture.md](architecture.md) | 層の分離、技術の責務、データの流れ |
| [decisions.md](decisions.md) | 設計判断の理由、決定状況、Open Questions |
| [testing.md](testing.md) | 将来の検証方針と実機・モックの使い分け |
| [01-domain.md](phases/01-domain.md) | Domain modelとEncounter / Revealルール |
| [02-local-storage.md](phases/02-local-storage.md) | SwiftDataによるローカル保存 |
| [03-multipeer-nearby.md](phases/03-multipeer-nearby.md) | 端末間接続と距離・方向の取得 |
| [04-supabase.md](phases/04-supabase.md) | 最新プロフィールの同期 |

## 進め方

1. 関連資料とphaseのOpen questionsを確認する。
2. 実装に必要な未決定事項を解決し、判断と理由をdecisions.mdに記録する。
3. phaseのScope内で実装し、Acceptance criteriaとManual verificationで確認する。
4. 検証結果と残課題を記録して次のphaseへ進む。

使用予定技術はSwift、SwiftUI、SwiftData、Nearby Interaction、Network.framework、Supabase、ARKit。watchOSは将来的な対応とし、初期4phaseの対象外。ARKitの採用範囲も今後決める。
