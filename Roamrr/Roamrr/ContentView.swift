import Core
import RoamrrDesign
import SwiftUI

struct ContentView: View {
    @Environment(\.theme) private var theme
    private let environment = AppEnvironment(bundleIdentifier: Bundle.main.bundleIdentifier ?? "")

    var body: some View {
        WelcomeView()
            .overlay(alignment: .top) {
                if environment != .prod {
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
