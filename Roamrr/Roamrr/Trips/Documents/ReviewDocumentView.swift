import RoamrrDesign
import SwiftUI

/// B3: check what the phone found, choose who sees it, and, if it has a date in the trip, put it on that day.
struct ReviewDocumentView: View {
    let trip: Trip
    let found: ExtractedDetails?
    let fileName: String
    let onDone: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(TripsStore.self) private var store
    @State private var kind: DocumentKind
    @State private var title: String
    @State private var place: String
    @State private var confirmation: String
    @State private var hasDate: Bool
    @State private var date: Date
    @State private var hasTime: Bool
    @State private var time: Date
    @State private var hasEnd: Bool
    @State private var endDate: Date
    @State private var visibility: DocumentVisibility
    /// Set once the person picks who sees it, so changing the type afterwards never overrides their choice.
    @State private var visibilityChosen = false
    @State private var saved = false
    @State private var placeOnPlan = true
    @State private var planDay: Date?
    @FocusState private var focused: Bool

    init(trip: Trip, found: ExtractedDetails?, fileName: String, onDone: @escaping () -> Void) {
        self.trip = trip
        self.found = found
        self.fileName = fileName
        self.onDone = onDone
        let calendar = Calendar.current
        let kind = found?.kind ?? .other
        let start = found?.start ?? trip.days.first ?? Date()
        let minutes = found?.minutes ?? 9 * 60
        _kind = State(initialValue: kind)
        _title = State(initialValue: found?.title ?? "")
        _place = State(initialValue: found?.place ?? "")
        _confirmation = State(initialValue: found?.confirmation ?? "")
        _hasDate = State(initialValue: found?.start != nil)
        _date = State(initialValue: start)
        _hasTime = State(initialValue: found?.minutes != nil)
        _time = State(initialValue: calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date())
        _hasEnd = State(initialValue: found?.end != nil)
        _endDate = State(initialValue: found?.end ?? start)
        _visibility = State(initialValue: kind.defaultVisibility)
        _planDay = State(initialValue: trip.days.first { calendar.isDate($0, inSameDayAs: start) })
    }

    private var minutes: Int? {
        guard hasTime else { return nil }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    /// The day it goes on, when the person wants it on the plan and it has a place there.
    private var targetDay: Date? {
        guard hasDate, placeOnPlan, kind.planCategory != nil else { return nil }
        return planDay
    }

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    private func dayNumber(_ day: Date) -> Int {
        (trip.days.firstIndex { Calendar.current.isDate($0, inSameDayAs: day) } ?? 0) + 1
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.md) {
                fileCard
                if found == nil {
                    Label("We couldn't read this one. Fill in what you need.", systemImage: "exclamationmark.circle")
                        .textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                }
                kindField
                DSTextField("What is it?", placeholder: "Siargao Surf Camp", text: $title, isFocused: $focused, autocapitalization: .words)
                DSTextField("Place", placeholder: "General Luna, Siargao", text: $place, isFocused: $focused, autocapitalization: .words)
                dateFields
                DSTextField("Confirmation number", placeholder: "SSC-48213", text: $confirmation, isFocused: $focused, autocapitalization: .characters)
                visibilityField
                if kind.planCategory != nil { planRow }
                Label("Nothing is added until you tap the button. Check the details first.", systemImage: "exclamationmark.circle")
                    .textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                if typeSize.isAccessibilitySize { saveButton }
            }
            .padding(.horizontal, theme.spacing.lg)
            .padding(.bottom, theme.spacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(theme.background)
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if !typeSize.isAccessibilitySize {
                saveButton
                    .padding(.horizontal, theme.spacing.lg).padding(.vertical, theme.spacing.sm)
                    .background(theme.background)
            }
        }
    }

    private var saveButton: some View {
        Button(targetDay.map { "Add to Day \(dayNumber($0))" } ?? "Save document") { save() }
            .buttonStyle(.ds(.ink))
            .disabled(!canSave || saved)
    }

    // MARK: Pieces

    private var fileCard: some View {
        HStack(spacing: theme.spacing.sm) {
            Text(fileName.lowercased().hasSuffix("pdf") ? "PDF" : "IMG")
                .font(.caption2.weight(.semibold)).foregroundStyle(theme.labelSecondary)
                .frame(width: 44, height: 56)
                .background(theme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(theme.separator))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(fileName).textRole(.subheadline, emphasized: true).foregroundStyle(theme.labelPrimary).lineLimit(1)
                Text("Read on this phone").textRole(.footnote).foregroundStyle(theme.labelSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(theme.spacing.sm)
        .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var kindField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Type").textRole(.subheadline, emphasized: true).foregroundStyle(theme.labelPrimary)
            Picker("Type", selection: $kind) {
                ForEach(DocumentKind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu).tint(theme.labelPrimary)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .padding(.horizontal, theme.spacing.xs)
            .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: theme.radius.field, style: .continuous))
            .onChange(of: kind) { _, new in
                if !visibilityChosen { visibility = new.defaultVisibility }
            }
        }
    }

    private var dateFields: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            toggleRow("Date", isOn: $hasDate) {
                DatePicker("Date", selection: $date, displayedComponents: .date).labelsHidden()
                    .onChange(of: date) { _, new in
                        planDay = trip.days.first { Calendar.current.isDate($0, inSameDayAs: new) }
                    }
            }
            if hasDate {
                toggleRow("Time", isOn: $hasTime) {
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute).labelsHidden()
                }
            }
            if kind == .stay, hasDate {
                toggleRow("Check-out", isOn: $hasEnd) {
                    DatePicker("Check-out", selection: $endDate, in: date..., displayedComponents: .date).labelsHidden()
                }
            }
        }
    }

    private func toggleRow<Control: View>(_ label: String, isOn: Binding<Bool>, @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: theme.spacing.xs) {
            Toggle(label, isOn: isOn).tint(theme.labelPrimary).textRole(.body)
            if isOn.wrappedValue { control() }
        }
        .padding(.horizontal, theme.spacing.md).frame(minHeight: 52)
        .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: theme.radius.field, style: .continuous))
    }

    private var visibilityField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Who can see it").textRole(.subheadline, emphasized: true).foregroundStyle(theme.labelPrimary)
            Picker("Who can see it", selection: Binding(get: { visibility }, set: { visibility = $0; visibilityChosen = true })) {
                Text("Shared with the trip").tag(DocumentVisibility.trip)
                Text("Only me").tag(DocumentVisibility.onlyMe)
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var planRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            if hasDate, planDay != nil {
                Toggle(isOn: $placeOnPlan) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(planDay.map { "Add to \($0.weekdayDayMonth)" } ?? "").textRole(.body, emphasized: true)
                        Text("Day \(planDay.map(dayNumber) ?? 1)\(minutes.map { " · \(PlanItem.clockText($0))" } ?? "")")
                            .textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                    }
                }
                .tint(theme.labelPrimary)
                .padding(theme.spacing.md)
                .background(Palette.accentSoft.color, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                if placeOnPlan, visibility == .onlyMe {
                    Text("Only the name, place and time go on the plan. The file and confirmation number stay private.")
                        .textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                }
            } else if hasDate {
                Text("This date isn't on the trip, so it won't go on the plan.")
                    .textRole(.subheadline).foregroundStyle(theme.labelSecondary)
            }
        }
    }

    // MARK: Save

    private func save() {
        // A second tap before the sheet has gone must not add the booking twice.
        guard !saved else { return }
        saved = true
        let document = TripDocument(
            id: UUID(), kind: kind, title: title.trimmingCharacters(in: .whitespaces), fileName: fileName,
            addedBy: store.me, visibility: visibility, place: place.trimmingCharacters(in: .whitespaces),
            start: hasDate ? date : nil, minutes: hasDate ? minutes : nil, end: kind == .stay && hasDate && hasEnd ? endDate : nil,
            confirmation: confirmation.trimmingCharacters(in: .whitespaces)
        )
        store.addDocument(document, onDay: targetDay, in: trip.id)
        onDone()
    }
}
