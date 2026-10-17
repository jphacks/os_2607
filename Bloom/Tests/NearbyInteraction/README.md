# UWB verification

Standalone checks cover direction math, missing values, bounded wire messages,
handshake validation, and task cancellation. Physical UWB needs two supported devices.

Run from the repository root:

```sh
xcrun swiftc -swift-version 6 -warnings-as-errors -parse-as-library \
  -module-cache-path /tmp/Bloom-UWB-module-cache \
  Bloom/Bloom/NearbyInteraction/Models/UWBObservation.swift \
  Bloom/Bloom/NearbyInteraction/Infrastructure/Networking/UWBWireMessage.swift \
  Bloom/Bloom/NearbyInteraction/Application/UWBTimeout.swift \
  Bloom/Tests/NearbyInteraction/UWBChecks.swift -o /tmp/Bloom-UWB-checks
/tmp/Bloom-UWB-checks
```

These checks do not verify Bonjour discovery, live NetworkConnection cancellation,
NI permissions, UWB measurements, or UI rendering. See `.codex/uwb-verification.md`
for the two-device procedure and outstanding integration checks.

## 2026-10-17 results

- Xcode 26.3 / iOS Simulator SDK / Debug: BUILD SUCCEEDED.
- Xcode 26.3 / iOS 26.2 SDK / Release / signing disabled: BUILD SUCCEEDED.
- Swift 6, warnings-as-errors: no Swift compiler or deprecation warnings.
- Standalone checks: PASS (direction, missing values, framing, handshake, timeout,
  cancellation).
- Generated app Info.plist: Nearby Interaction and local-network usage strings,
  Bonjour service array, and iPhone portrait orientation verified.
- The build tool emitted an AppIntents metadata-skipped warning because this app
  does not use AppIntents; it is not a Swift/deprecation warning.
- UI rendering and real-device discovery/ranging remain unverified. Simulator
  operation permission was declined; no simulator launch was attempted afterward.
