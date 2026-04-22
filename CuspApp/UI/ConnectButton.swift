import SwiftUI

struct ConnectButton: View {
    let state: ConnectionVisualState
    let isEnabled: Bool
    let size: CGFloat
    let action: () -> Void

    @State private var animationTrigger = 0

    var body: some View {
        Button {
            animationTrigger += 1
            action()
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: state.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(CuspPalette.hairline.opacity(1.2), lineWidth: 1)
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(.white.opacity(0.03), lineWidth: 4)
                            .blur(radius: 4)
                    )
                    .shadow(color: state.shadowColor.opacity(0.82), radius: 11, y: 6)

                VStack(spacing: 10) {
                    Image(systemName: state.symbolName)
                        .font(.system(size: size * 0.155, weight: .semibold))
                    Text(state.buttonTitle)
                        .font(.system(size: size * 0.16, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
            .opacity(isEnabled ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .phaseAnimator([0.94, 1.04, 1.0], trigger: animationTrigger) { content, scale in
            content.scaleEffect(scale)
        } animation: { _ in
            .spring(response: 0.42, dampingFraction: 0.62)
        }
    }
}

struct ConnectionVisualState {
    let buttonTitle: String
    let symbolName: String
    let gradientColors: [Color]
    let shadowColor: Color
}
