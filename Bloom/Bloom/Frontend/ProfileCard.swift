import SwiftUI

/// The bottom edge recedes; cards at the top retain their readable size.
struct ProfileCardScrollEffect: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.scrollTransition(topLeading: .identity, bottomTrailing: .interactive.threshold(.centered), axis: .vertical) { view, phase in
            view.scaleEffect(reduceMotion || phase != .bottomTrailing ? 1 : 0.8, anchor: .top)
        }
    }
}

struct ProfileCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
        let reduceMotion = reduceMotion
        return content
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28).strokeBorder(.pink.opacity(0.1))
        }
        .shadow(color: .pink.opacity(0.06), radius: 14, y: 6)
        .modifier(ProfileCardScrollEffect())
    }
}
