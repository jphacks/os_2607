import ActivityKit
import SwiftUI
import WidgetKit

struct BloomActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BloomPresenceAttributes.self) { context in
            HStack(spacing: 16) {
                Image(systemName: "leaf.fill")
                    .font(.largeTitle).foregroundStyle(.pink)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Bloom").font(.headline)
                    Text(context.state.isParticipating ? "この場所に参加中" : "参加を終了しました")
                        .font(.subheadline)
                    Text("タップしてBloomを開く").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(20)
            .activityBackgroundTint(Color(uiColor: .secondarySystemBackground))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Bloom", systemImage: "leaf.fill").foregroundStyle(.pink)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.isParticipating ? "この場所に参加中 · タップして開く" : "参加を終了しました")
                }
            } compactLeading: {
                Image(systemName: "leaf.fill").foregroundStyle(.pink)
            } compactTrailing: {
                Text(context.state.isParticipating ? "参加中" : "終了")
            } minimal: {
                Image(systemName: "leaf.fill").foregroundStyle(.pink)
            }
        }
    }
}
