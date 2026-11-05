import PhotosUI
import RoamrrDesign
import SwiftUI

/// S2: your photo, display name and color. Trip members see your photo and name.
struct ProfileView: View {
    let me: MemberAppearance
    let onSave: (_ name: String, _ colorIndex: Int, _ photo: Data?) -> Void

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var colorIndex = 0
    @State private var photo: Data?
    @State private var loaded = false
    @State private var showLibrary = false
    @State private var pickerItem: PhotosPickerItem?
    @FocusState private var nameFocused: Bool

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var hasChanges: Bool {
        trimmedName != me.name || colorIndex != me.colorIndex || photo != me.photo
    }
    private var preview: AvatarMember { me.member.updating(name: trimmedName.isEmpty ? me.name : trimmedName, colorIndex: colorIndex, photo: photo) }

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacing.lg) {
                photoBlock
                DSTextField(
                    "Display name", placeholder: "Your name", text: $name, isFocused: $nameFocused,
                    helperMessage: "Trip members see your photo and this name.", autocapitalization: .words
                )
                if photo == nil { colorBlock }
            }
            .padding(.horizontal, theme.spacing.lg)
            .padding(.top, theme.spacing.sm)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .background(theme.background)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .solidNavigationBar()
        .safeAreaInset(edge: .bottom) {
            Button("Save") {
                onSave(trimmedName, colorIndex, photo)
                dismiss()
            }
            .buttonStyle(.ds(.ink))
            .disabled(trimmedName.isEmpty || !hasChanges)
            .padding(.horizontal, theme.spacing.lg).padding(.top, theme.spacing.sm).padding(.bottom, theme.spacing.md)
            .background(theme.background)
        }
        .onAppear {
            guard !loaded else { return }
            name = me.name
            colorIndex = me.colorIndex
            photo = me.photo
            loaded = true
        }
        .photosPicker(isPresented: $showLibrary, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self)?.compressedPhoto { photo = data }
                pickerItem = nil
            }
        }
    }

    // MARK: Pieces

    private var photoBlock: some View {
        VStack(spacing: theme.spacing.sm) {
            MemberAvatar(preview, diameter: 104).environment(\.signedInMember, nil)
            if photo == nil {
                Button { showLibrary = true } label: { photoPill("Add photo") }
                    .buttonStyle(.plain)
            } else {
                Menu {
                    Button("Choose from Library", systemImage: "photo") { showLibrary = true }
                    Button("Remove Photo", systemImage: "trash", role: .destructive) { photo = nil }
                } label: { photoPill("Edit photo") }
            }
        }
    }

    private func photoPill(_ title: String) -> some View {
        Text(title)
            .textRole(.subheadline, emphasized: true).foregroundStyle(theme.labelPrimary)
            .padding(.horizontal, theme.spacing.md).frame(minHeight: 44)
            .background(Color.Roamrr.pill, in: Capsule())
    }

    private var colorBlock: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Text("Color").textRole(.subheadline, emphasized: true).foregroundStyle(theme.labelPrimary)
            HStack(spacing: 0) {
                ForEach(Palette.avatars.indices, id: \.self) { index in
                    Button { colorIndex = index } label: {
                        Circle().fill(Palette.avatarColor(index))
                            .frame(width: 32, height: 32)
                            .overlay { if index == colorIndex { Circle().strokeBorder(theme.labelPrimary, lineWidth: 2).padding(-4) } }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Color \(index + 1)")
                    .accessibilityAddTraits(index == colorIndex ? .isSelected : [])
                }
            }
            Text("Shows behind your initial until you add a photo.")
                .textRole(.footnote).foregroundStyle(theme.labelSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack { ProfileView(me: MemberAppearance(MockData.you), onSave: { _, _, _ in }) }
        .theme(.roamrr)
}
