import RoamrrDesign
import SwiftUI

/// S1: Settings home. Your profile first, then sign out.
struct SettingsHomeView: View {
    let me: MemberAppearance
    let onSaveProfile: (_ name: String, _ colorIndex: Int, _ photo: Data?) -> Void
    let onSignOut: () -> Void

    @Environment(\.theme) private var theme
    @State private var confirmSignOut = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.lg) {
                    profileCard
                    signOutButton
                }
                .padding(.horizontal, theme.spacing.lg)
                .padding(.top, theme.spacing.xs)
                .padding(.bottom, theme.spacing.xl)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(theme.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: ProfileRoute.self) { _ in ProfileView(me: me, onSave: onSaveProfile) }
            .confirmationDialog("Sign out of Roamrr?", isPresented: $confirmSignOut, titleVisibility: .visible) {
                Button("Sign out", role: .destructive, action: onSignOut)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You can sign back in any time. Your trips stay with the group.")
            }
        }
    }

    // MARK: Pieces

    private var profileCard: some View {
        NavigationLink(value: ProfileRoute()) {
            HStack(spacing: theme.spacing.md) {
                MemberAvatar(me.member, diameter: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Text(me.name).textRole(.title3, emphasized: true).foregroundStyle(theme.labelPrimary)
                    Text("Your profile").textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                }
                Spacer(minLength: theme.spacing.xs)
                Image(systemName: "chevron.right")
                    .font(.system(.footnote, weight: .semibold)).foregroundStyle(theme.labelTertiary)
            }
            .padding(theme.spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens your profile")
    }

    private var signOutButton: some View {
        Button { confirmSignOut = true } label: {
            Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                .textRole(.body, emphasized: true).foregroundStyle(theme.destructive)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Opens S2.
struct ProfileRoute: Hashable {}

#Preview {
    SettingsHomeView(me: MemberAppearance(MockData.you), onSaveProfile: { _, _, _ in }, onSignOut: {})
        .theme(.roamrr)
}
