import PhotosUI
import RoamrrDesign
import SwiftUI

/// T2 and T2b: make a trip, then invite people, all in one sheet.
struct CreateTripSheet: View {
    /// Called with the new trip when the sheet closes after creating it, so the app can open its Planning home.
    var onOpen: (Trip.ID) -> Void = { _ in }

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(TripsStore.self) private var store

    @State private var model = CreateTripViewModel()
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationStack {
            if let trip = model.created {
                TripCreatedView(trip: trip) {
                    dismiss()
                    onOpen(trip.id)
                }
                    .navigationTitle("Trip created")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar(.hidden, for: .navigationBar)
            } else {
                form
                    .dsSheetToolbar("New trip", cancel: { dismiss() })
            }
        }
        .animation(DesignSystem.Motion.enter, value: model.created)
    }

    // MARK: Form

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.lg) {
                coverField
                DSTextField(
                    "Trip name", placeholder: "Sagada weekend", text: $model.name, isFocused: $nameFocused,
                    autocapitalization: .words
                )
                datesField
                currencyField
            }
            .padding(.horizontal, theme.spacing.lg)
            .padding(.bottom, theme.spacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(theme.background)
        .safeAreaInset(edge: .bottom) {
            Button("Create trip") { model.create(in: store) }
                .buttonStyle(.ds(.ink))
                .disabled(!model.canCreate)
                .padding(.horizontal, theme.spacing.lg)
                .padding(.vertical, theme.spacing.sm)
                .background(theme.background)
        }
    }

    private var coverField: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            label("Cover", optional: true)
            ZStack(alignment: .bottomTrailing) {
                if let data = model.photo, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    CoverArt(model.cover)
                }
                PhotosPicker(selection: $model.pickerItem, matching: .images) {
                    Label("Add photo", systemImage: "camera")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(theme.labelPrimary)
                        .padding(.horizontal, theme.spacing.sm)
                        .frame(minHeight: 36)
                        .background(Color.Roamrr.pill, in: Capsule())
                }
                .padding(theme.spacing.xs)
            }
            .frame(height: 132)
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous))
            .accessibilityElement(children: .contain)

            HStack(spacing: theme.spacing.xs) {
                ForEach(CoverStyle.allCases, id: \.self) { style in
                    Button { model.chooseIllustration(style) } label: {
                        CoverArt(style)
                            .frame(width: 52, height: 38)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay {
                                if model.photo == nil && model.cover == style {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(theme.labelPrimary, lineWidth: 2)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(style.rawValue.capitalized) illustration")
                    .accessibilityAddTraits(model.photo == nil && model.cover == style ? .isSelected : [])
                }
                Text("or pick an illustration").textRole(.subheadline).foregroundStyle(theme.labelSecondary)
            }
        }
    }

    private var datesField: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            label("Dates", optional: true)
            CalendarCard(start: $model.start, end: $model.end, today: store.today)
        }
    }

    private var currencyField: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            label("Home currency", optional: false)
            HStack(spacing: theme.spacing.sm) {
                Text("₱")
                    .font(.system(.footnote, weight: .bold))
                    .frame(width: 28, height: 28)
                    .background(Palette.accentSoft.color, in: Circle())
                Text("PHP · Philippine peso").textRole(.body)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(theme.labelTertiary)
            }
            .foregroundStyle(theme.labelPrimary)
            .padding(.horizontal, theme.spacing.md)
            .frame(minHeight: theme.size.fieldHeight)
            .overlay {
                RoundedRectangle(cornerRadius: theme.radius.field, style: .continuous)
                    .strokeBorder(theme.border, lineWidth: theme.size.borderWidth)
            }
            Label("Every expense is converted to this. It can't be changed after the first expense.", systemImage: "info.circle")
                .textRole(.footnote)
                .foregroundStyle(theme.labelSecondary)
        }
    }

    private func label(_ title: String, optional: Bool) -> some View {
        HStack(spacing: theme.spacing.xxs) {
            Text(title).textRole(.subheadline, emphasized: true)
            if optional { Text("optional").textRole(.subheadline).foregroundStyle(theme.labelTertiary) }
        }
        .foregroundStyle(theme.labelPrimary)
    }
}

#Preview("New trip") {
    Color.clear.sheet(isPresented: .constant(true)) { CreateTripSheet() }
        .environment(TripsStore())
        .theme(.roamrr)
}
