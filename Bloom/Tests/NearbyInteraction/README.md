# UWB verification

Standalone checks cover direction math, missing values, bounded wire messages,
handshake validation, and task cancellation. Physical UWB needs two supported devices.

Run from the repository root:

```sh
xcrun swiftc -swift-version 6 -warnings-as-errors -parse-as-library \
  -module-cache-path /tmp/Bloom-UWB-module-cache \
  Bloom/NearbyInteraction/Models/UWBObservation.swift \
  Bloom/NearbyInteraction/Models/UWBMultiPeerModels.swift \
  Bloom/NearbyInteraction/Infrastructure/Networking/UWBWireMessage.swift \
  Bloom/NearbyInteraction/Application/UWBTimeout.swift \
  Tests/NearbyInteraction/UWBChecks.swift -o /tmp/Bloom-UWB-checks
/tmp/Bloom-UWB-checks
```

These checks do not verify Bonjour discovery, live NetworkConnection cancellation,
NI permissions, UWB measurements, or UI rendering. See `.codex/uwb-verification.md`
for the two-device procedure and outstanding integration checks.

The Xcode-native suite uses Swift Testing. Select the `BloomUWBTests` scheme and
an iOS Simulator, then run Test. It covers normalized direction values, invalid
distance handling, multi-peer connection isolation and replacement, bounded wire
framing, handshake validation, and timeout behavior.

## 2026-10-17 results

- Xcode 26.3 / iOS Simulator SDK / Debug: BUILD SUCCEEDED.
- Xcode 26.3 / iOS 26.2 SDK / Release / signing disabled: BUILD SUCCEEDED.
- Swift 6, warnings-as-errors: no Swift compiler or deprecation warnings.
- Standalone checks: PASS (direction, missing values, framing, handshake, timeout,
  cancellation).
- `BloomUWBTests` on iPhone 17 Simulator (iOS 27.0): 17/17 PASS.
- Generated app Info.plist: Nearby Interaction and local-network usage strings,
  Bonjour service array, and iPhone portrait orientation verified.
- The build tool emitted an AppIntents metadata-skipped warning because this app
  does not use AppIntents; it is not a Swift/deprecation warning.
- The UWB verification screen launches on iPhone 17 Simulator in portrait. Hosting
  changes the screen to its temporary Bonjour name and Stop returns it to the idle
  controls, with no visible clipping or overlap. Real-device discovery and ranging
  remain unverified; Simulator UI behavior is not evidence of UWB operation.

## Multi-peer API

`UWBMultiPeerSession` is independent of a particular screen. It exposes observable
snapshots for SwiftUI and an `AsyncStream<UWBMultiPeerEvent>` for a render loop or
future AR layer. Network.framework and Nearby Interaction types stay internal.

```swift
@State private var uwb = UWBMultiPeerSession()

uwb.startHosting()  // Accept and range multiple incoming peers.
uwb.startBrowsing() // Keep discovery active while connecting to multiple peers.

let connectionID = try uwb.connect(to: peer)
let latest = uwb.connections
let observations = uwb.observations

uwb.disconnect(id: connectionID)
uwb.stop()
```

`UWBPeerConnection.id` identifies one live connection. After the handshake,
`personID` is the persistent app identity and should be used to associate domain
data. Discovery tokens are never exposed by this API. One connection owns one
`NISession`; the framework's device-dependent concurrent-session limit is reported
as a failure on only the affected connection.
