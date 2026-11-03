import SwiftUI

/// "Roam" in navy ink and "rr" in burnt orange, one serif weight.
public struct Wordmark: View {
    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            Text("Roam").foregroundStyle(Color.Roamrr.ink)
            Text("rr").foregroundStyle(Color.Roamrr.wordmarkRR)
        }
        .font(.system(.largeTitle, design: .serif, weight: .bold))
        .tracking(-0.3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Roamrr")
    }
}

#Preview {
    Wordmark().padding().background(Color.Roamrr.canvas)
}
