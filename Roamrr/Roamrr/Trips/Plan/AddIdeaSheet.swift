import CoreLocation
import PhotosUI
import RoamrrDesign
import SwiftUI

/// P2: add an idea, or edit one. A link is stored as an address and a label you type; nothing is loaded from it.
struct AddIdeaSheet: View {
    let trip: Trip
    let editing: PlanItem?

    static let noteLimit = 280
    static let photoLimit = 40

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(TripsStore.self) private var store
    @State private var title: String
    @State private var linkText: String
    @State private var linkLabel: String
    @State private var category: PlanCategory
    @State private var note: String
    @State private var costText: String
    @State private var placeName: String
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var results: [PlaceResult] = []
    @State private var searching = false
    @State private var picked = false
    @State private var pickedName = ""
    @State private var tripArea: CLLocationCoordinate2D?
    @State private var photo: Data?
    @State private var pickerItem: PhotosPickerItem?
    @FocusState private var focused: Bool

    init(trip: Trip, editing: PlanItem?) {
        self.trip = trip
        self.editing = editing
        _title = State(initialValue: editing?.title ?? "")
        _linkText = State(initialValue: editing?.link?.url.absoluteString ?? "")
        _linkLabel = State(initialValue: editing?.link?.label ?? "")
        _category = State(initialValue: editing?.category ?? .food)
        _note = State(initialValue: editing?.note ?? "")
        _costText = State(initialValue: editing?.cost.map { "\($0)" } ?? "")
        _placeName = State(initialValue: editing?.placeName ?? "")
        _coordinate = State(initialValue: editing?.coordinate)
        _picked = State(initialValue: editing?.coordinate != nil)
        _pickedName = State(initialValue: editing?.placeName ?? "")
        _photo = State(initialValue: editing?.photo)
    }

    private var parsedURL: URL? { PlanLink.parse(linkText) }
    private var linkProblem: Bool { !linkText.trimmingCharacters(in: .whitespaces).isEmpty && parsedURL == nil }
    private var photosOnTrip: Int { trip.plan.filter { $0.photo != nil && $0.id != editing?.id }.count }
    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty && !linkProblem }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.md) {
                    field("Link", note: "optional") {
                        TextField("https://", text: $linkText)
                            .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    }
                    if linkProblem {
                        Text("Links must start with https://").textRole(.subheadline).foregroundStyle(theme.destructive)
                    }
                    DSTextField("What is it?", placeholder: "Sunrise surf at Cloud 9", text: $title, isFocused: $focused, autocapitalization: .sentences)
                    if parsedURL != nil {
                        DSTextField("Link label", placeholder: "Reel: sunrise at Cloud 9", text: $linkLabel, isFocused: $focused, autocapitalization: .sentences)
                    }
                    categoryField
                    placeField
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Note").textRole(.subheadline, emphasized: true).foregroundStyle(theme.labelPrimary)
                        TextField("Best light at 5:45. Bring a rash guard.", text: $note, axis: .vertical)
                            .lineLimit(2...5)
                            .padding(.horizontal, theme.spacing.md).padding(.vertical, 14)
                            .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: theme.radius.field, style: .continuous))
                            .onChange(of: note) { _, value in
                                if value.count > Self.noteLimit { note = String(value.prefix(Self.noteLimit)) }
                            }
                        if note.count > 200 {
                            Text("\(note.count)/\(Self.noteLimit)").textRole(.footnote).foregroundStyle(theme.labelTertiary)
                        }
                    }
                    field("Cost per person", note: "optional") {
                        HStack(spacing: 4) {
                            Text("₱").foregroundStyle(theme.labelSecondary)
                            TextField("0", text: $costText).keyboardType(.decimalPad)
                        }
                    }
                    photoField
                    Label("Roamrr opens links in your browser. It never loads them, so no preview shows.", systemImage: "info.circle")
                        .textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                }
                .padding(.horizontal, theme.spacing.lg)
                .padding(.bottom, theme.spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(theme.background)
            .dsSheetToolbar(editing == nil ? "Add idea" : "Edit idea", cancel: { dismiss() })
            .safeAreaInset(edge: .bottom) {
                Button(editing == nil ? "Add idea" : "Save changes") { save() }
                    .buttonStyle(.ds(.ink))
                    .disabled(!canSave)
                    .padding(.horizontal, theme.spacing.lg).padding(.vertical, theme.spacing.sm)
                    .background(theme.background)
            }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) { photo = data.compressedPhoto }
                pickerItem = nil
            }
        }
    }

    // MARK: Fields

    private func field<Content: View>(_ label: String, note: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(label).textRole(.subheadline, emphasized: true).foregroundStyle(theme.labelPrimary)
                if let note { Text(note).textRole(.subheadline).foregroundStyle(theme.labelTertiary) }
            }
            content()
                .textRole(.body)
                .padding(.horizontal, theme.spacing.md).frame(minHeight: 52)
                .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: theme.radius.field, style: .continuous))
        }
    }

    // MARK: Place

    /// A search box for Apple Maps. Picking a result keeps its coordinates; a typed name alone still works.
    private var placeField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text("Place").textRole(.subheadline, emphasized: true).foregroundStyle(theme.labelPrimary)
                Text("optional").textRole(.subheadline).foregroundStyle(theme.labelTertiary)
            }
            HStack(spacing: theme.spacing.xs) {
                Image(systemName: picked ? "mappin.circle.fill" : "magnifyingglass")
                    .foregroundStyle(picked ? theme.accent : theme.labelSecondary)
                TextField("Search for a place", text: $placeName)
                    .textInputAutocapitalization(.words)
                    .onChange(of: placeName) { _, value in
                        // Editing the text after picking a result drops the spot; picking itself does not.
                        if picked, value != pickedName { picked = false; coordinate = nil }
                    }
                if searching { ProgressView().controlSize(.small) }
                if !placeName.isEmpty {
                    Button("Clear place", systemImage: "xmark.circle.fill") {
                        placeName = ""; pickedName = ""; coordinate = nil; picked = false; results = []
                    }
                    .labelStyle(.iconOnly).foregroundStyle(theme.labelTertiary)
                }
            }
            .textRole(.body)
            .padding(.horizontal, theme.spacing.md).frame(minHeight: 52)
            .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: theme.radius.field, style: .continuous))
            .task(id: placeName) { await search() }
            if picked {
                Text("Directions and Meet here will go to this spot.").textRole(.footnote).foregroundStyle(theme.labelSecondary)
            } else if store.isOffline && !placeName.isEmpty {
                Text("You’re offline, so search is off. The name is saved without a spot on the map.")
                    .textRole(.footnote).foregroundStyle(theme.labelSecondary)
            } else if !results.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                        Button { choose(result) } label: {
                            HStack(spacing: theme.spacing.sm) {
                                Image(systemName: "mappin.and.ellipse").foregroundStyle(theme.accent).frame(width: 24)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(result.name).textRole(.body, emphasized: true).foregroundStyle(theme.labelPrimary).lineLimit(1)
                                    if !result.detail.isEmpty {
                                        Text(result.detail).textRole(.subheadline).foregroundStyle(theme.labelSecondary).lineLimit(1)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, theme.spacing.md).padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if index < results.count - 1 { Divider().padding(.leading, theme.spacing.md + 24 + theme.spacing.sm) }
                    }
                }
                .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: theme.radius.field, style: .continuous))
            } else if !placeName.trimmingCharacters(in: .whitespaces).isEmpty && !searching && placeName.count >= 2 {
                Text("No match. The name is saved without a spot on the map.")
                    .textRole(.footnote).foregroundStyle(theme.labelSecondary)
            }
        }
    }

    /// Waits for a short pause in typing, then asks Apple Maps.
    private func search() async {
        guard !picked, !store.isOffline else { results = []; return }
        let text = placeName
        guard text.trimmingCharacters(in: .whitespaces).count >= 2 else { results = []; searching = false; return }
        searching = true
        try? await Task.sleep(for: .milliseconds(450))
        guard !Task.isCancelled else { return }
        if trip.searchCenter == nil, tripArea == nil {
            tripArea = await PlaceSearch.locate(trip.place.isEmpty ? trip.destination : trip.place)
        }
        let hint = trip.searchCenter == nil
            ? String((trip.place.isEmpty ? trip.destination : trip.place).split(separator: ",").first ?? "")
            : ""
        let found = await PlaceSearch.find(text, around: trip.searchCenter ?? tripArea, hint: hint)
        guard !Task.isCancelled else { return }
        results = found
        searching = false
    }

    private func choose(_ result: PlaceResult) {
        pickedName = result.name
        placeName = result.name
        coordinate = result.coordinate
        picked = true
        results = []
        if title.trimmingCharacters(in: .whitespaces).isEmpty { title = result.name }
    }

    private var categoryField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Category").textRole(.subheadline, emphasized: true).foregroundStyle(theme.labelPrimary)
            FlowLayout(spacing: theme.spacing.xs) {
                ForEach(PlanCategory.allCases, id: \.self) { option in
                    let isOn = category == option
                    Button { category = option } label: {
                        Label(option.rawValue, systemImage: option.symbol)
                            .textRole(.subheadline, emphasized: isOn)
                            .foregroundStyle(isOn ? Palette.accent.color : theme.labelPrimary)
                            .padding(.horizontal, theme.spacing.md).frame(minHeight: 40)
                            .background(isOn ? Palette.accentSoft.color : Color.Roamrr.pill, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
    }

    private var photoField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text("Photo").textRole(.subheadline, emphasized: true).foregroundStyle(theme.labelPrimary)
                Text("optional").textRole(.subheadline).foregroundStyle(theme.labelTertiary)
            }
            if let photo, let image = UIImage(data: photo) {
                HStack {
                    Image(uiImage: image).resizable().scaledToFill().frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    Button("Remove photo", role: .destructive) { self.photo = nil }
                        .textRole(.subheadline, emphasized: true)
                    Spacer()
                }
            } else if photosOnTrip >= Self.photoLimit {
                Text("This trip has \(Self.photoLimit) photos already. You can still save the idea without one.")
                    .textRole(.subheadline).foregroundStyle(theme.labelSecondary)
            } else {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Add a photo", systemImage: "camera")
                        .font(.system(.body)).foregroundStyle(theme.labelPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, theme.spacing.md).frame(minHeight: 52)
                        .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: theme.radius.field, style: .continuous))
                }
            }
        }
    }

    // MARK: Save

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespaces)
        let url = parsedURL
        let label = linkLabel.trimmingCharacters(in: .whitespaces)
        let link = url.map { PlanLink(url: $0, label: label.isEmpty ? ($0.host ?? "Link") : label) }
        let cost = Decimal(string: costText.trimmingCharacters(in: .whitespaces)).flatMap { $0 > 0 ? $0 : nil }
        if var item = editing {
            item.title = cleanTitle; item.category = category; item.link = link; item.note = note
            item.cost = cost; item.placeName = placeName; item.photo = photo
            item.latitude = coordinate?.latitude; item.longitude = coordinate?.longitude
            if photo != nil { item.tile = nil }
            store.updateIdea(item, in: trip.id)
        } else {
            store.addIdea(
                PlanItem(
                    id: UUID(), title: cleanTitle, category: category, placeName: placeName,
                    latitude: coordinate?.latitude, longitude: coordinate?.longitude, link: link, note: note,
                    photo: photo, cost: cost, addedBy: store.me, reactions: [store.me.id: .want]
                ),
                in: trip.id
            )
        }
        dismiss()
    }
}
