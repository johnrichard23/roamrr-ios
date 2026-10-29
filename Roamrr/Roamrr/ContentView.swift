import Core
import DesignSystem
import SwiftUI

struct ContentView: View {
    private let environment = AppEnvironment(bundleIdentifier: Bundle.main.bundleIdentifier ?? "")

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Wordmark()
            if environment != .prod {
                Text("\(environment.rawValue.capitalized) build")
                    .font(Typography.caption)
                    .foregroundStyle(Color.Roamrr.inkSecondary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(Color.Roamrr.pill, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Roamrr.canvas)
    }
}

#Preview {
    ContentView()
}
