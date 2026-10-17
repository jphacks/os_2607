# Architecture

以下は目標とする構成。今回、モジュール・ファイル・依存関係は実装しない。

## 層と依存方向

- Presentation: SwiftUIで画面状態を表示し、ユーザー操作をApplicationへ渡す。
- Application: 観測入力、Encounter判定、保存、プロフィール同期を調整する。
- Domain: Person、Profile、Proximity、Encounter、Reveal、Connectionとルール。SwiftUI、NearbyInteraction、MultipeerConnectivity、Supabase SDK、SwiftDataに依存しない。
- Infrastructure: 各SDKのアダプターと、保存・通信の実装。Domainの値やApplication側のインターフェースへ変換する。

Presentation → Application → Domainの向きに依存する。Infrastructureは内側で定義したインターフェースを実装する。依存の組み立てはアプリの起動側で行う。SwiftDataのモデルやSDKのtokenをDomainの型にしない。時間源と観測入力を差し替え可能にする。

## 技術ごとの責務

| 技術 | 責務 |
| --- | --- |
| Swift | Domainとアプリ全体の実装言語 |
| SwiftUI | 画面表示と操作入力 |
| Nearby Interaction | 相手との距離・方向の取得 |
| Multipeer Connectivity | 端末発見、接続、discoveryToken交換、personID交換 |
| SwiftData | Encounter履歴、累計時間、プロフィールキャッシュのローカル保存 |
| Supabase | 最新プロフィールの正本と、その取得・更新 |
| ARKit | 将来の方向表示・空間表現などを検討。必須化の判断は未決定 |
| watchOS | 将来の拡張。Domainを共有可能に保ち、通信やUIの対応は別途設計 |

## データの流れ

1. Multipeer Connectivityで端末を発見・接続し、personIDとdiscoveryTokenを交換する。
2. 通信アダプターでpeer・token・personIDを対応付け、Nearby Interactionの計測を開始する。
3. 距離・方向の観測をSDK非依存のProximityへ変換してApplicationへ渡す。
4. DomainがEncounter状態とRevealを判定し、ApplicationがSwiftDataへ履歴・累計を保存する。
5. personIDに対応する公開許可済みの最新プロフィールをSupabaseから取得し、SwiftDataのキャッシュを更新する。
6. 公開許可とRevealの条件を満たす項目をSwiftUIに表示する。

距離が不明な状態を0mとして扱わない。ConnectionとEncounterを分け、接続中という理由だけで時間を加算しない。

## データの正本と境界

- 最新プロフィールの正本はSupabase。ローカルキャッシュを無条件に最新版として扱わず、鮮度やオフライン状態を区別する。
- Encounter履歴と累計時間はSwiftDataに保存する。初期4phaseにEncounterのクラウド同期は含めない。
- 履歴と保存済み累計の整合性を維持する。具体的な更新単位と再計算方法はphase 2で決める。
- Supabaseの認証IDとpersonIDの対応、公開情報のアクセス制御はphase 4で設計する。
- 表示上の非表示だけでアクセス制御が成立するとはみなさない。公開許可のない情報を取得・キャッシュしない設計にする。

## Open Questions

- 対応OS・実機、同時接続人数、計測セッションのライフサイクルとバックグラウンド要件。
- ARKitの必要性、導入phase、電力・権限・対応機種への影響。
- watchOSで共有するDomainの範囲と、iPhoneとの役割分担。
- オフライン中の公開撤回の反映、キャッシュ有効期間、Revealをサーバー側でも強制するか。