import SwiftUI

struct UWBDirectionView: View {
    let direction: UWBDirection?

    var body: some View {
        VStack(spacing: 12) {
            if let direction {
                if let azimuth = direction.azimuthDegrees {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 64, weight: .semibold))
                        .rotationEffect(.degrees(azimuth))
                        .frame(width: 110, height: 110)
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    Text("左右 \(azimuth, format: .number.precision(.fractionLength(0)))°")
                    Text("上下 \(direction.elevationDegrees, format: .number.precision(.fractionLength(0)))°")
                } else {
                    Image(systemName: direction.y > 0 ? "arrow.up.circle" : "arrow.down.circle")
                        .font(.system(size: 64))
                    Text(direction.y > 0 ? "端末の上方向" : "端末の下方向")
                }
                Text("矢印は上から見た方向。↑ は端末背面の先、→ は右。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "location.slash")
                    .font(.system(size: 48))
                    .frame(height: 110)
                    .foregroundStyle(.secondary)
                Text("方向は未取得")
            }
        }
        .monospacedDigit()
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .padding()
    }
}
