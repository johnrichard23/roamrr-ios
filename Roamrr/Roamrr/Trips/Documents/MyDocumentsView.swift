import RoamrrDesign
import SwiftUI

/// B5: passport, ID and insurance cards. They stay on this phone and are not part of any trip.
struct MyDocumentsView: View {
    @Environment(\.theme) private var theme
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(TripsStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var lock = DocumentLock()
    @State private var showAdd = false
    @State private var deleting: PersonalDocument?

    var body: some View {
        Group {
            if lock.isUnlocked {
                documents
            } else {
                locked
            }
        }
        .background(theme.background)
        .navigationTitle("My documents")
        .navigationBarTitleDisplayMode(.inline)
        .solidNavigationBar()
        .task { await lock.unlock() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { lock.lock() }
        }
    }

    // MARK: Locked

    private var locked: some View {
        VStack(spacing: theme.spacing.sm) {
            Image(systemName: lock.state == .unavailable ? "lock.slash" : "lock.fill")
                .font(.system(size: 28, weight: .semibold)).foregroundStyle(Palette.accent.color)
                .frame(width: 72, height: 72).background(Palette.accentSoft.color, in: Circle())
                .accessibilityHidden(true)
            Text(lock.state == .unavailable ? "Set a passcode first" : "My documents are locked")
                .stepTitleStyle().foregroundStyle(theme.labelPrimary).multilineTextAlignment(.center)
            Text(lock.state == .unavailable
                ? "Roamrr needs a passcode on this phone to keep your passport private. Turn one on in Settings, then come back."
                : "Unlock with Face ID or your passcode to see your passport and insurance.")
                .textRole(.body).foregroundStyle(theme.labelSecondary).multilineTextAlignment(.center)
            if lock.state != .unavailable {
                Button("Unlock", systemImage: "faceid") { Task { await lock.unlock() } }
                    .buttonStyle(.ds(.ink))
                    .disabled(lock.state == .unlocking)
                    .padding(.top, theme.spacing.xs)
            }
        }
        .padding(.horizontal, theme.spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Documents

    private var documents: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.md) {
                if store.myDocuments.isEmpty {
                    Text("Nothing here yet. Add your passport or insurance card.")
                        .textRole(.body).foregroundStyle(theme.labelSecondary).frame(maxWidth: .infinity).padding(.top, theme.spacing.xl)
                } else {
                    GroupedRows(data: store.myDocuments, dividerInset: theme.spacing.md + 44 + theme.spacing.sm) { document in
                        row(document)
                    }
                }
                Label("These stay on this phone. Roamrr does not upload them, and signing out removes them.", systemImage: "lock")
                    .textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                // Landscape and the largest text sizes would let a pinned bar cover the list, so it scrolls with it.
                if inlineAction { addButton }
            }
            .padding(.horizontal, theme.spacing.lg)
            .padding(.bottom, theme.spacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            if !inlineAction {
                addButton
                    .padding(.horizontal, theme.spacing.lg).padding(.vertical, theme.spacing.xs)
                    .background(theme.background)
            }
        }
        .sheet(isPresented: $showAdd) { AddMyDocumentSheet() }
        .confirmationDialog("Delete this document?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("Delete \(deleting?.title ?? "document")", role: .destructive) {
                if let deleting { store.deleteMyDocument(deleting.id) }
                deleting = nil
            }
            Button("Cancel", role: .cancel) { deleting = nil }
        }
    }

    private var inlineAction: Bool { verticalSizeClass == .compact || typeSize.isAccessibilitySize }

    private var addButton: some View {
        Button("Add to my documents", systemImage: "plus") { showAdd = true }
            .buttonStyle(.ds(.ink))
    }

    private func row(_ document: PersonalDocument) -> some View {
        HStack(spacing: theme.spacing.sm) {
            DocumentIconTile(symbol: document.symbol)
            VStack(alignment: .leading, spacing: 2) {
                Text(document.title).textRole(.body, emphasized: true).foregroundStyle(theme.labelPrimary)
                Text(document.detail).textRole(.subheadline).foregroundStyle(theme.labelSecondary)
            }
            Spacer(minLength: 0)
            Menu {
                Button("Delete", systemImage: "trash", role: .destructive) { deleting = document }
            } label: {
                Image(systemName: "ellipsis").frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .tint(theme.labelSecondary)
            .accessibilityLabel("More for \(document.title)")
        }
        .padding(.horizontal, theme.spacing.md).padding(.vertical, theme.spacing.xs)
        .frame(minHeight: 72)
    }
}

/// Adds a passport, ID or insurance card to this phone. Mock-only: no file is read or stored yet.
struct AddMyDocumentSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(TripsStore.self) private var store
    @State private var title = ""
    @State private var type = Kind.passport
    @State private var hasExpiry = true
    @State private var expiry = Calendar.current.date(byAdding: .year, value: 5, to: Date()) ?? Date()
    @FocusState private var focused: Bool

    enum Kind: String, CaseIterable {
        case passport = "Passport", id = "ID card", insurance = "Insurance card", other = "Other"

        var symbol: String {
            switch self {
            case .passport: "person.text.rectangle"
            case .id: "person.crop.rectangle"
            case .insurance: "cross.case"
            case .other: "doc"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.md) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Type").textRole(.subheadline, emphasized: true).foregroundStyle(theme.labelPrimary)
                        Picker("Type", selection: $type) {
                            ForEach(Kind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.menu).tint(theme.labelPrimary)
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading).padding(.horizontal, theme.spacing.xs)
                        .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: theme.radius.field, style: .continuous))
                    }
                    DSTextField("Name", placeholder: type.rawValue, text: $title, isFocused: $focused, autocapitalization: .words)
                    HStack(spacing: theme.spacing.xs) {
                        Toggle("Expires", isOn: $hasExpiry).tint(theme.labelPrimary).textRole(.body)
                        if hasExpiry { DatePicker("Expires", selection: $expiry, displayedComponents: .date).labelsHidden() }
                    }
                    .padding(.horizontal, theme.spacing.md).frame(minHeight: 52)
                    .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: theme.radius.field, style: .continuous))
                    Label("It stays on this phone. Roamrr does not upload it.", systemImage: "lock")
                        .textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                }
                .padding(.horizontal, theme.spacing.lg)
            }
            .background(theme.background)
            .dsSheetToolbar("New document", cancel: { dismiss() })
            .safeAreaInset(edge: .bottom) {
                Button("Save") { save() }
                    .buttonStyle(.ds(.ink))
                    .padding(.horizontal, theme.spacing.lg).padding(.vertical, theme.spacing.sm)
                    .background(theme.background)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func save() {
        let name = title.trimmingCharacters(in: .whitespaces)
        let detail = hasExpiry ? "Expires \(expiry.formatted(.dateTime.month(.abbreviated).year()))" : type.rawValue
        store.addMyDocument(PersonalDocument(id: UUID(), title: name.isEmpty ? type.rawValue : name, detail: detail, symbol: type.symbol))
        dismiss()
    }
}
