# Frontend Network integration — 2026-10-18

- Scope: replace Frontend's Multipeer Connectivity sample with the existing `UWBMultiPeerSession` (Network.framework + Nearby Interaction). Phase 3 integration; not completion of Encounter/storage/profile phases.
- `UWBConnectionService` is now an Observation-based frontend adapter. Participation starts hosting and browsing; discovery uses `_bloom-uwb._tcp`. The active target's `Backend/Config/Info.plist` already declares this service and both usage descriptions.
- Connect using a discovered `UWBPeer`, never a sample profile's display name. Show connection-specific distance/direction and missing/error states. Exclude the local temporary Bonjour name from discovery results.
- Participation permits incoming ranging connections. No profile information is exchanged. Each device displays its temporary name so the user can select the other device from one side; simultaneous cross-connections are not required.
- Stop and background transitions end all sessions. Restart creates a fresh session so delayed callbacks from the previous session cannot affect the new frontend state.
- Keep the existing installation-local `Bloom.personID`; linking it to authenticated accounts is a separate task. Received identity is not authorization for profile access. The existing transport's lack of peer authentication/encryption remains unchanged.
- Remove sample-only name-keyed Encounter generation (4m/5s/8s) with the Multipeer implementation. Existing name-only history is read without migration or deletion; it is not linked to discovered identities. Encounter timing, SwiftData storage, and real profile/reveal integration remain separate phases. The sample history/profile UI outside the nearby-device area remains unchanged.

## Verification

- Xcode BuildProject: succeeded, no build errors.
- Swift 6 standalone UWB checks with warnings-as-errors: passed (direction, missing values, framing, handshake, timeout, cancellation).
- Xcode RunAllTests: 10 tests reported `not run`; no passing result claimed.
- Frontend source search: no MultipeerConnectivity, MCSession, MCPeerID, or old Bonjour service references.
- Device interaction could not select the physical iPhone (`Cannot select specified device`). Simulator UI was not launched. Real Bonjour discovery, permissions, ranging, reconnect, and background behavior remain unverified.

## Two-device verification

1. On two UWB-capable iPhones, open Home and start participation. Allow local network and Nearby Interaction access.
2. Confirm each device displays its own temporary name and lists the other device, not itself.
3. On one device only, select the other device's name. Confirm both devices show a connection and the remote identity after handshake.
4. Move/rotate the devices and check distance/direction for that connection. Missing observations must show unavailable values, not a retained distance.
5. Disconnect, reconnect, stop participation, and background either device. Confirm observations clear and a manual restart uses a fresh session.
6. Repeat with a third device to verify per-connection display/isolation; supported simultaneous ranging count depends on hardware.
