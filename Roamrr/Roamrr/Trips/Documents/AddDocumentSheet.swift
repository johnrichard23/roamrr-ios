import PhotosUI
import RoamrrDesign
import SwiftUI
import UniformTypeIdentifiers

/// B2: choose where the document comes from; the phone reads it, then B3 asks you to check it.
struct AddDocumentSheet: View {
    let trip: Trip

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var reading = false
    @State private var showImporter = false
    @State private var showScanner = false
    @State private var photoItem: PhotosPickerItem?
    @State private var notice: String?
    @State private var reviewing: ReviewItem?
    @State private var detent = PresentationDetent.medium

    /// What B3 opens with: what the phone found, if anything.
    struct ReviewItem: Identifiable, Hashable {
        let id = UUID()
        let fileName: String
        let found: ExtractedDetails?
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: theme.spacing.sm) {
                Button { scan() } label: { SourceRow(title: "Scan with the camera", symbol: "camera.viewfinder") }
                    .buttonStyle(.plain).disabled(reading)
                Button { showImporter = true } label: { SourceRow(title: "Choose a PDF", symbol: "doc") }
                    .buttonStyle(.plain).disabled(reading)
                PhotosPicker(selection: $photoItem, matching: .images) { SourceRow(title: "Choose a photo", symbol: "photo") }
                    .buttonStyle(.plain).disabled(reading)
                Label("Roamrr reads it on your phone. The file is not sent anywhere to be read.", systemImage: "lock")
                    .textRole(.subheadline).foregroundStyle(theme.labelSecondary)
                    .padding(.top, theme.spacing.xs)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, theme.spacing.lg)
            .padding(.top, theme.spacing.sm)
            .background(theme.background)
            .dsSheetToolbar("Add document", cancel: { dismiss() })
            .overlay { if reading { readingOverlay } }
            .navigationDestination(item: $reviewing) { item in
                ReviewDocumentView(trip: trip, found: item.found, fileName: item.fileName, onDone: { dismiss() })
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.pdf]) { result in
                if case .success(let url) = result { read(.pdf(url), named: url.lastPathComponent) }
            }
            .fullScreenCover(isPresented: $showScanner) {
                DocumentScanner(
                    onFinish: { images in
                        showScanner = false
                        read(.scan(images), named: "Scan")
                    },
                    onCancel: { showScanner = false }
                )
                .ignoresSafeArea()
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                photoItem = nil
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) { read(.photo(data), named: "Photo") }
                }
            }
            .alert("Can't scan here", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(notice ?? "")
            }
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
    }

    private var readingOverlay: some View {
        VStack(spacing: theme.spacing.xs) {
            ProgressView()
            Text("Reading on this phone").textRole(.subheadline).foregroundStyle(theme.labelSecondary)
        }
        .padding(theme.spacing.lg)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func scan() {
        if DocumentScanner.isAvailable {
            showScanner = true
        } else {
            notice = "Scanning needs a camera, and this device doesn't have one. Choose a PDF or a photo instead."
        }
    }

    private func read(_ input: DocumentInput, named fileName: String) {
        reading = true
        Task {
            let found = await DocumentReader.read(input)
            reading = false
            detent = .large
            reviewing = ReviewItem(fileName: fileName, found: found)
        }
    }
}

/// One way to add a document: an icon, a name and a chevron.
private struct SourceRow: View {
    let title: String
    let symbol: String

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: theme.spacing.sm) {
            DocumentIconTile(symbol: symbol, base: 40)
            Text(title).textRole(.body, emphasized: true).foregroundStyle(theme.labelPrimary)
            Spacer()
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(theme.labelTertiary)
        }
        .padding(.horizontal, theme.spacing.md).frame(minHeight: 64)
        .background(Color.Roamrr.pill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(Rectangle())
    }
}
