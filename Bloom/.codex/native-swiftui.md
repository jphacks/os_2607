# Native SwiftUI presentation — 2026-10-18

> 後続の実データ統合・独自UI改善は [mock-audit.md](mock-audit.md) を参照。以下は最初の標準UI置換時点の記録で、サンプルデータを保持したという記述は現在の状態ではない。

- User requested Liquid Glass and system SwiftUI controls, explicitly disallowing a custom tab bar.
- Home now uses system TabView/Tab and a separate NavigationStack per tab. Details use NavigationLink and sheets use system toolbars. No custom tab-bar overlay or simulated back navigation remains.
- Messages use List/searchable; history uses List/Section; profile editing and authentication use Form, TextField, Toggle and Stepper. Existing authentication, Network/NI and storage behavior remain in their existing adapters.
- Standard glass/glassProminent button styles are used for primary actions. System tabs and toolbars provide Liquid Glass. Content does not receive a blanket glass effect.
- Removed fixed light appearance and small fixed text sizing in the rewritten screens. Semantic colors/text styles follow system appearance and text size.
- Existing sample chat/history/profile data remains sample data; this UI task does not introduce real messaging, profile synchronization, Encounter persistence, or change Reveal thresholds.
- Xcode build passed. No new unit tests for presentation-only changes. Physical-device UI verification is attempted separately; real authentication and UWB are not established by a successful build.
