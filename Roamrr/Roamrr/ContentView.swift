import Core
import RoamrrDesign
import SwiftUI

struct ContentView: View {
    @Environment(\.theme) private var theme
    @State private var isSignedIn = false
    private let environment = AppEnvironment(bundleIdentifier: Bundle.main.bundleIdentifier ?? "")

    var body: some View {
        Group {
            if isSignedIn {
                MainTabView()
            } else {
                WelcomeView(
                    onApple: { isSignedIn = true },
                    onGoogle: { isSignedIn = true },
                    onFacebook: { isSignedIn = true }
                )
            }
        }
            .overlay(alignment: .top) {
                if environment != .prod && !isSignedIn {
                    Text("\(environment.rawValue.capitalized) build")
                        .textRole(.caption1)
                        .foregroundStyle(theme.labelSecondary)
                        .padding(.horizontal, theme.spacing.sm)
                        .padding(.vertical, theme.spacing.xxs)
                        .background(theme.surface, in: Capsule())
                }
            }
    }
}

#Preview {
    ContentView()
        .theme(.roamrr)
}
