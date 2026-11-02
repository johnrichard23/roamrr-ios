import RoamrrDesign
import SwiftUI

/// T2b: the last step of the create sheet. The new trip, its code, and one next step.
struct TripCreatedView: View {
    let trip: Trip
    var onDone: () -> Void

    @Environment(\.theme) private var theme
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacing.lg) {
                Text("Trip created")
                    .textRole(.headline)
                    .foregroundStyle(theme.labelPrimary)
                    .padding(.top, theme.spacing.lg)
                TripCoverCard(trip: trip, subtitle: "\(trip.datesDecided ? DateRangeText.withYear(trip.start, trip.end) : trip.dates) · just you so far") {
                    EmptyView()
                } bottom: {
                    EmptyView()
                }
                VStack(spacing: theme.spacing.xs) {
                    Text("Your trip is ready")
                        .font(.system(.title2, design: .serif, weight: .medium))
                        .foregroundStyle(theme.labelPrimary)
                    Text("Invite your friends so everyone can add ideas and vote on the plan.")
                        .textRole(.body)
                        .foregroundStyle(theme.labelSecondary)
                        .multilineTextAlignment(.center)
                }
                codePill
            }
            .padding(.horizontal, theme.spacing.lg)
        }
        .background(theme.background)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: theme.spacing.xs) {
                ShareLink(item: shareText) {
                    Label("Invite friends", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.ds(.ink))
                Button("Not now", action: onDone).buttonStyle(.ds(.plain))
            }
            .padding(.horizontal, theme.spacing.lg)
            .padding(.vertical, theme.spacing.sm)
            .background(theme.background)
        }
    }

    private var shareText: String {
        "Join my trip “\(trip.title)” on Roamrr. Code \(trip.code)\nroamrr://join?code=\(trip.code.replacingOccurrences(of: "-", with: ""))"
    }

    private var codePill: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("Trip code").textRole(.footnote).foregroundStyle(theme.labelSecondary)
                Text(trip.code)
                    .font(.system(.title3, design: .monospaced, weight: .bold))
                    .foregroundStyle(theme.labelPrimary)
            }
            Spacer()
            Button {
                UIPasteboard.general.string = trip.code
                copied = true
            } label: {
                Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.ds(.soft, size: .regular, expandsWidth: false))
            .sensoryFeedback(.success, trigger: copied)
        }
        .padding(theme.spacing.md)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    TripCreatedView(
        trip: Trip(
            id: UUID(), title: "Sagada weekend", destination: "Sagada",
            start: MockData.date(2026, 11, 20), end: MockData.date(2026, 11, 22), cover: .hills, coverPhoto: nil,
            members: [], balance: nil, newCount: 0, code: "H4TN-2WQC"
        )
    ) {}
    .theme(.roamrr)
}
