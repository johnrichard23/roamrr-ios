import SwiftUI

/// "Roam" in ink and "rr" in apricot.
public struct Wordmark: View {
    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            Text("Roam").foregroundStyle(Color.Roamrr.ink)
            Text("rr").foregroundStyle(Color.Roamrr.wordmarkRR)
        }
        .font(.system(.largeTitle, design: .rounded, weight: .semibold))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Roamrr")
    }
}

#Preview {
    Wordmark().padding().background(Color.Roamrr.canvas)
}
