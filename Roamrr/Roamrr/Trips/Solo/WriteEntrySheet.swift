import PhotosUI
import RoamrrDesign
import SwiftUI

/// J2: write one day's entry. Text comes first; what the app knows about the day waits beside it as chips.
/// It saves as you go, so closing it never loses anything.
struct WriteEntrySheet: View {
    let tripID: Trip.ID
    let day: Date

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(TripsStore.self) private var store
    @State private var entry: JournalEntry?
    @State private var pickerItems: [PhotosPickerItem] = []
    @FocusState private var writing: Bool

    private static let maxPhotos = 6

    var body: some View {
        NavigationStack {
            if let trip = store.trip(id: tripID), let binding = Binding($entry) {
                editor(trip, entry: binding)
            } else {
                Color.clear
            }
        }
        .presentationDragIndicator(.visible)
        .onAppear(perform: load)
        .onDisappear(perform: save)
    }

    private func editor(_ trip: Trip, entry: Binding<JournalEntry>) -> some View {
        VStack(spacing: 0) {
            facts(trip.facts(on: day, now: store.now), entry: entry)
            ZStack(alignment: .topLeading) {
                TextEditor(text: entry.text)
                    .focused($writing)
                    .scrollContentBackground(.hidden)
                    .textRole(.body)
                    .foregroundStyle(theme.labelPrimary)
                    .padding(.horizontal, theme.spacing.lg - 5)
                if entry.wrappedValue.text.isEmpty {
                    Text(placeholder(trip))
                        .textRole(.body).foregroundStyle(theme.labelSecondary)
                        .padding(.horizontal, theme.spacing.lg).padding(.top, 8)
                        .allowsHitTesting(false)
                }
            }
        }
        .background(theme.background)
        .safeAreaInset(edge: .bottom, spacing: 0) { accessory(entry: entry) }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(day.weekdayDayMonth).textRole(.headline).foregroundStyle(theme.labelPrimary)
                    if let number = trip.dayNumber(on: day) {
                        Text("Day \(number) of \(trip.dayCount)").textRole(.caption1).foregroundStyle(theme.labelSecondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }.fontWeight(.semibold)
            }
        }
        .task { writing = entry.wrappedValue.text.isEmpty }
    }

    private func placeholder(_ trip: Trip) -> String {
        Calendar.current.isDate(day, inSameDayAs: store.today) ? "How was \(trip.destination) today?" : "What happened this day?"
    }

    // MARK: Facts

    @ViewBuilder
    private func facts(_ facts: [JournalFact], entry: Binding<JournalEntry>) -> some View {
        if !facts.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("From your day · tap to add").textRole(.footnote).foregroundStyle(theme.labelSecondary)
                    .padding(.horizontal, theme.spacing.lg)
                ScrollView(.horizontal) {
                    HStack(spacing: theme.spacing.xs) {
                        ForEach(facts) { fact in
                            factChip(fact, used: entry.wrappedValue.usedFacts.contains(fact.id)) { toggle(fact, in: entry) }
                        }
                    }
                    .padding(.horizontal, theme.spacing.lg)
                }
                .scrollIndicators(.hidden)
            }
            .padding(.vertical, theme.spacing.xs)
            .sensoryFeedback(.selection, trigger: entry.wrappedValue.usedFacts)
        }
    }

    private func factChip(_ fact: JournalFact, used: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: used ? "checkmark" : fact.symbol)
                    .contentTransition(.symbolEffect(.replace))
                    .foregroundStyle(used ? Color.Roamrr.onInk : theme.accent)
                Text(fact.label).textRole(.subheadline)
                    .foregroundStyle(used ? Color.Roamrr.onInk : theme.labelPrimary)
            }
            .lineLimit(1)
            .padding(.horizontal, 14).frame(minHeight: 40)
            .background(used ? Color.Roamrr.ink : Color.Roamrr.pill, in: Capsule())
            .contentShape(Capsule())
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(fact.label)
        .accessibilityValue(used ? "Added" : "")
        .accessibilityHint(used ? "Removes this line from your entry" : "Adds this line to your entry")
    }

    /// Adds the fact as its own line, or takes that line out again.
    private func toggle(_ fact: JournalFact, in entry: Binding<JournalEntry>) {
        withAnimation(DesignSystem.Motion.enter) {
            if entry.wrappedValue.usedFacts.contains(fact.id) {
                var lines = entry.wrappedValue.text.components(separatedBy: "\n")
                if let index = lines.firstIndex(of: fact.line) { lines.remove(at: index) }
                entry.wrappedValue.text = lines.joined(separator: "\n")
                entry.wrappedValue.usedFacts.remove(fact.id)
            } else {
                let text = entry.wrappedValue.text
                entry.wrappedValue.text = text.isEmpty || text.hasSuffix("\n") ? text + fact.line : text + "\n" + fact.line
                entry.wrappedValue.usedFacts.insert(fact.id)
            }
        }
    }

    // MARK: Mood and photos

    private func accessory(entry: Binding<JournalEntry>) -> some View {
        VStack(spacing: theme.spacing.xs) {
            if !entry.wrappedValue.photos.isEmpty { photoStrip(entry: entry) }
            HStack(spacing: 4) {
                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: max(1, Self.maxPhotos - entry.wrappedValue.photos.count),
                    matching: .images
                ) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title3).foregroundStyle(theme.accent)
                        .frame(width: 48, height: 48)
                }
                .disabled(entry.wrappedValue.photos.count >= Self.maxPhotos)
                .accessibilityLabel("Add photos")
                Divider().frame(height: 28)
                ForEach(JournalMood.allCases, id: \.self) { mood in
                    moodButton(mood, selected: entry.wrappedValue.mood == mood) {
                        withAnimation(DesignSystem.Motion.press) {
                            entry.wrappedValue.mood = entry.wrappedValue.mood == mood ? nil : mood
                        }
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: entry.wrappedValue.mood)
        }
        .padding(.horizontal, theme.spacing.md)
        .padding(.vertical, theme.spacing.xs)
        .background(.bar)
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                for item in items where entry.wrappedValue.photos.count < Self.maxPhotos {
                    if let data = try? await item.loadTransferable(type: Data.self)?.compressedPhoto {
                        entry.wrappedValue.photos.append(data)
                    }
                }
                pickerItems = []
            }
        }
    }

    private func moodButton(_ mood: JournalMood, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: selected ? mood.symbol + ".fill" : mood.symbol)
                    .font(.body)
                    .symbolRenderingMode(.hierarchical)
                    .frame(height: 24)
                Text(mood.title).textRole(.caption2, emphasized: selected)
            }
            .foregroundStyle(selected ? theme.accent : theme.labelSecondary)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(selected ? Color.Roamrr.accentSoft : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Mood: \(mood.title)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func photoStrip(entry: Binding<JournalEntry>) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: theme.spacing.xs) {
                ForEach(Array(entry.wrappedValue.photos.enumerated()), id: \.offset) { index, data in
                    if let image = UIImage(data: data) {
                        Image(uiImage: image).resizable().scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .contextMenu {
                                Button("Remove photo", systemImage: "trash", role: .destructive) {
                                    withAnimation(DesignSystem.Motion.exit) { _ = entry.wrappedValue.photos.remove(at: index) }
                                }
                            }
                            .accessibilityLabel("Photo \(index + 1)")
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Saving

    private func load() {
        guard entry == nil else { return }
        let existing = store.trip(id: tripID)?.journal.first { Calendar.current.isDate($0.day, inSameDayAs: day) }
        entry = existing ?? JournalEntry(id: UUID(), day: day)
    }

    private func save() {
        guard let entry else { return }
        store.saveEntry(entry, in: tripID)
    }
}
