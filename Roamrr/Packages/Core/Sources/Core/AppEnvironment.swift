import Foundation

/// The backend the app build talks to.
public enum AppEnvironment: String, Sendable, CaseIterable {
    case dev
    case uat
    case prod

    /// Derives the environment from the app's bundle identifier. A `.dev` or `.uat`
    /// suffix selects that environment; anything else is production.
    public init(bundleIdentifier: String) {
        let id = bundleIdentifier.lowercased()
        if id.hasSuffix(".dev") {
            self = .dev
        } else if id.hasSuffix(".uat") {
            self = .uat
        } else {
            self = .prod
        }
    }
}
