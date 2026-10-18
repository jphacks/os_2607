# 自動接続・履歴 — 2026-10-18

メッセージ機能はユーザーの指示で廃止。D29を撤回し、全画面・導線・依存・専用SQL・テストを削除。以前のSQLはエージェントからリモートへ適用されておらず、今回もリモートDBの削除はしていない。画像・動画・リンク表示はプロフィール専用として維持。現在の修正・検証は [profile-background.md](profile-background.md) を参照。

## D30 — automatic nearby connections

- Normal UI no longer exposes device IDs, peer selection, or a connection-management sheet. Participation remains explicit consent.
- Temporary discovery names elect one initiator per pair. Attempts are retried every 5 seconds; `UWBMultiPeerSession.connect` reuses live sessions and replaces failed sessions. Different peers have independent retry schedules. Disappearing peers are removed from the schedule; stopping resets it.
- Hosting/browsing restart checks are also every 5 seconds and are no-ops while the corresponding task is running. These intervals are provisional, not a validated device limit.
- Existing manual diagnostic code is retained but not reachable from the normal screen. Network.framework/NI responsibilities and the lack of authenticated transport identity are unchanged.
- Real multi-device discovery, permission denial, reconnect, and UWB behavior remain unverified without physical devices.

## D31 — historical profiles independent of live connections

- The old history read names from `proximity.people`; disconnected peers therefore lost their displayed names. Replaced this with `HistoryProfileModel`, which fetches by persisted `personID` through ProfileRepository without any UWB dependency.
- History groups stored Encounter records by person and shows encounter count, latest time, cumulative duration, public profile details, permitted content.
- Display uses current Supabase permission decisions, not a durable snapshot of withdrawn information. A profile stays valid in memory for at most 15 seconds; refresh starts every 12 seconds. Errors or disappearance/background invalidate it. Initial/renewal loading is distinct from failure. Private/deleted/unreachable profiles retain their local encounter record with an unavailable state and retry action.
- Reveal uses that person's saved total and the current item's `isPublic` and `unlockAfterSeconds`. No live connection is required.
- Encounter eligibility itself is unchanged: history contains saved completed Encounters under the existing provisional proximity/time rules. Merely establishing a network connection does not fabricate a timed Encounter. Offline historical profile snapshots and persistence of every brief connection are not added.
