import RoamrrDesign
import SwiftUI

/// A1: the first screen a signed-out person sees. The brand, one line, and
/// the three ways to sign in. The sign-in actions are supplied by the caller.
struct WelcomeView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize

    var onApple: () -> Void = {}
    var onGoogle: () -> Void = {}
    var onFacebook: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacing.lg * 2) {
                header
                // At accessibility sizes the buttons are too tall to pin, so they scroll.
                if typeSize.isAccessibilitySize { signInButtons }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, theme.spacing.lg * 6)
            .padding(.bottom, theme.spacing.lg)
            .screenMargins()
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            if !typeSize.isAccessibilitySize {
                signInButtons
                    .screenMargins()
                    .padding(.vertical, theme.spacing.md)
                    .background(theme.background)
            }
        }
        .background(theme.background)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: theme.spacing.sm) {
            Wordmark()
                .scaleEffect(1.6)
                .padding(.bottom, theme.spacing.sm)
            Text("Roam together.")
                .textRole(.title2)
                .foregroundStyle(theme.labelSecondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Sign in

    private var signInButtons: some View {
        VStack(spacing: theme.spacing.xs) {
            Button("Continue with Apple", systemImage: "apple.logo", action: onApple)
                .buttonStyle(.ds(.ink))
            Button("Continue with Google", action: onGoogle)
                .buttonStyle(.ds(.neutral))
            Button("Continue with Facebook", action: onFacebook)
                .buttonStyle(.ds(.neutral))
        }
    }
}

#Preview("Light") {
    WelcomeView().theme(.roamrr)
}

#Preview("Dark") {
    WelcomeView().theme(.roamrr).preferredColorScheme(.dark)
}

#Preview("Large text") {
    WelcomeView().theme(.roamrr).dynamicTypeSize(.accessibility2)
}
