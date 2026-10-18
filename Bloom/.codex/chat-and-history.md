# Chat / rich content / automatic discovery / history — 2026-10-18

## Scope and status

- Implemented a real Supabase-backed one-to-one message repository and native SwiftUI conversation UI. No production mock injection or fake sent messages.
- **Remote deployment is not complete.** Supabase MCP `list_tables` for `sapdpmepmeeexppirzle` twice returned `You do not have permission to perform this action`. No remote table, policy, or function was created or changed in this task.
- SQL is prepared at `Bloom/Backend/Database/chat_schema.sql`. Apply once using the target project's SQL Editor as its administrator. It creates only the new chat objects; do not rerun the old `schema.sql` against existing profile tables.
- Run `Bloom/Backend/Database/verify_chat_rls.sql` afterwards. It creates generated temporary user IDs and rolls back all test users/profiles/messages. This script is prepared, **not executed** in this environment. Then run Security/Performance Advisors and the two-account checks below.

## D29 — provisional messaging behavior

- 1:1 conversations are derived from immutable `chat_messages` rows. The server assigns creation time and an identity sequence. There is no group chat or separate mutable membership table.
- Authenticated sender can insert only their own sender ID, to an existing currently discoverable profile. This is not a server-verified encounter requirement. Turning profile discovery off prevents new messages to that person; participants can still read their existing messages.
- RLS limits reads to sender/recipient. Only recipient can update `read_at`; column grants prohibit editing sender, recipient, body, kind, sequence, or creation time. Anonymous roles cannot access the table or inbox function.
- The inbox RPC uses SECURITY INVOKER and respects existing Profile RLS. A withdrawn profile name is not returned by the RPC.
- A client-generated message UUID is retained after an ambiguous send failure. Retry uses the same UUID; an existing row is fetched and checked against sender/recipient/body/kind before treating it as success. Definite access rejection or missing setup releases the draft for editing.
- Drafts/pending sends are memory-only. They are not an offline outbox and are not guaranteed across app termination/logout.
- Foreground visible thread refreshes every 3 seconds; inbox every 5 seconds. These intervals are provisional. No Realtime subscription or push notification is claimed. Background/hidden-screen polling stops.
- History is paged in batches of 50. Catch-up fetches multiple pages after a gap. Read receipts are sent only for fetched received message IDs. Older loaded outbound receipts can stay stale until those pages are fetched again.
- Message kinds: text, image URL, video URL, link URL. Nontext drafts require HTTPS without URL credentials. Native image rendering with expansion/zoom, VideoPlayer without autoplay, and host-labelled link cards are shared with public profiles. Direct video file/HLS URLs can play; arbitrary video-provider web pages should be links.
- Photo-library picking, Storage upload, signed attachment URLs, provider-specific embeds, blocking/reporting, message deletion/editing and push notifications remain unimplemented. Existing avatar Storage paths are not assumed to be public image URLs.

## D30 — automatic nearby connections

- Normal UI no longer exposes device IDs, peer selection, or a connection-management sheet. Participation remains explicit consent.
- Temporary discovery names elect one initiator per pair. Attempts are retried every 5 seconds; `UWBMultiPeerSession.connect` reuses live sessions and replaces failed sessions. Different peers have independent retry schedules. Disappearing peers are removed from the schedule; stopping resets it.
- Hosting/browsing restart checks are also every 5 seconds and are no-ops while the corresponding task is running. These intervals are provisional, not a validated device limit.
- Existing manual diagnostic code is retained but not reachable from the normal screen. Network.framework/NI responsibilities and the lack of authenticated transport identity are unchanged.
- Real multi-device discovery, permission denial, reconnect, and UWB behavior remain unverified without physical devices.

## D31 — historical profiles independent of live connections

- The old history read names from `proximity.people`; disconnected peers therefore lost their displayed names. Replaced this with `HistoryProfileModel`, which fetches by persisted `personID` through ProfileRepository without any UWB dependency.
- History groups stored Encounter records by person and shows encounter count, latest time, cumulative duration, public profile details, permitted content, and a chat entry point.
- Display uses current Supabase permission decisions, not a durable snapshot of withdrawn information. A profile stays valid in memory for at most 15 seconds; refresh starts every 12 seconds. Errors or disappearance/background invalidate it. Private/deleted/unreachable profiles retain their local encounter record with an unavailable state and retry action.
- Reveal uses that person's saved total and the current item's `isPublic` and `unlockAfterSeconds`. No live connection is required.
- Encounter eligibility itself is unchanged: history contains saved completed Encounters under the existing provisional proximity/time rules. Merely establishing a network connection does not fabricate a timed Encounter. Offline historical profile snapshots and persistence of every brief connection are not added.

## Validation

- Xcode BuildProject after the integrated changes: successful, no compiler errors.
- Xcode RunAllTests at that stage reported 26 not run; no passing Xcode test run is claimed. Three history tests were added afterwards.
- The actual Domain/application sources and matching Swift Testing sources were copied to an isolated temporary macOS SwiftPM package. **10 tests passed**: draft validation, URL validation, deduplication/receipt updates, retry identity after a lost response, receipt failure/retry, cancellation, initiator election/retry timing/peer independence, historical grouping, profile loading without a live connection, and removal after permission loss. Test doubles are confined to tests.
- `git diff --check` passed. Database SQL/RLS execution, actual auth accounts, network delivery, remote media, UI layout/interaction, and physical UWB validation remain unverified.

## After SQL deployment

1. Run `verify_chat_rls.sql` and check that it reaches ROLLBACK without exception. Run Supabase advisors.
2. With two distinct signed-in test accounts and public profiles, start participation and verify automatic discovery without selecting IDs.
3. Open a profile and send a message. Verify the second account's inbox/unread count, received body, and receipt after opening the thread. Only perform real sends with the users' consent.
4. Retry a send after a network interruption and confirm the same message is not duplicated. Send >50 test messages to verify older-page/catch-up behavior.
5. Test image/video file URLs, invalid/unreachable URLs, image zoom, background pause, and large text sizes.
6. End a qualifying encounter, stop participation, restart the app, and open the person from history. Verify current profile/content remains available without UWB. Withdraw publication and verify profile/content is removed while the local record remains.

References used: Supabase RLS and Swift client docs via MCP, current changelog (explicit Data API grants), Apple DocumentationSearch for AsyncImage and VideoPlayer. No SDK version was changed.
