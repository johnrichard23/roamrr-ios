import RoamrrDesign
import SwiftUI
import UIKit

/// An idea's photos as a short stack: the cover in front, the next ones peeking out behind like a pile of prints, and a
/// count. Tapping it opens the gallery, which grows out of the front photo.
struct IdeaPhotoStack: View {
    let photos: [Data]
    var zoomNamespace: Namespace.ID?
    let onOpen: () -> Void

    @Environment(\.theme) private var theme

    private let height: CGFloat = 188
    /// How much of each photo behind shows above the one in front.
    private let peek: CGFloat = 10
    /// How far each one is lifted: its peek, plus what shrinking it takes off its own height.
    private var lift: CGFloat { peek + height * 0.05 }

    private var behind: Int { min(photos.count, PlanItem.maxPhotos) - 1 }

    var body: some View {
        Button(action: onOpen) {
            ZStack(alignment: .bottom) {
                // Furthest back first, so the cover ends up on top.
                ForEach(Array(photos.prefix(PlanItem.maxPhotos).enumerated()).reversed(), id: \.offset) { index, data in
                    card(data, index: index)
                }
            }
            .padding(.top, lift * CGFloat(behind))
            .overlay(alignment: .bottomTrailing) { countChip.padding(10) }
        }
        .buttonStyle(CardPressStyle())
        .accessibilityLabel(photos.count == 1 ? "1 photo" : "\(photos.count) photos")
        .accessibilityHint("Opens the photos")
        .accessibilityAddTraits(.isButton)
    }

    private func card(_ data: Data, index: Int) -> some View {
        let isCover = index == 0
        return Group {
            if let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color.Roamrr.ice
            }
        }
        .frame(maxWidth: .infinity).frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous))
        // The ones behind step back: a little smaller, higher, and a touch darker.
        .overlay { if !isCover { RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous).fill(.black.opacity(0.06 * Double(index))) } }
        .scaleEffect(1 - 0.05 * CGFloat(index), anchor: .bottom)
        .offset(y: -lift * CGFloat(index))
        .shadow(color: .black.opacity(isCover ? 0.16 : 0.08), radius: isCover ? 8 : 4, y: isCover ? 3 : 1)
        .ideaPhotoZoomSource(isCover ? zoomNamespace : nil)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var countChip: some View {
        if photos.count > 1 {
            Label("\(photos.count) photos", systemImage: "photo.on.rectangle.angled")
                .textRole(.footnote, emphasized: true).foregroundStyle(theme.labelPrimary)
                .padding(.horizontal, 10).frame(minHeight: 30)
                .background(Color.Roamrr.pill.opacity(0.95), in: Capsule())
                .accessibilityHidden(true)
        }
    }
}

/// The photos full screen on black: swipe between them, pinch or double-tap to zoom, drag down or tap the cross to close.
struct IdeaPhotoGallery: View {
    let title: String
    let photos: [Data]
    var zoomNamespace: Namespace.ID?

    @Environment(\.dismiss) private var dismiss
    @State private var index = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TabView(selection: $index) {
                ForEach(Array(photos.enumerated()), id: \.offset) { position, data in
                    ZoomablePhoto(data: data).tag(position)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                Spacer()
                if photos.count > 1 { dots }
            }
        }
        .statusBarHidden()
        .ideaPhotoZoomDestination(zoomNamespace)
    }

    private var topBar: some View {
        ZStack {
            VStack(spacing: 0) {
                Text(title).textRole(.subheadline, emphasized: true).foregroundStyle(.white).lineLimit(1)
                if photos.count > 1 {
                    Text("\(index + 1) of \(photos.count)").textRole(.footnote).foregroundStyle(.white.opacity(0.75))
                        .contentTransition(.numericText())
                }
            }
            .padding(.horizontal, 64)
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 44, height: 44).background(.white.opacity(0.16), in: Circle())
                }
                .accessibilityLabel("Close photos")
                Spacer()
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
    }

    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(photos.indices, id: \.self) { position in
                Circle().fill(.white.opacity(position == index ? 1 : 0.35)).frame(width: 7, height: 7)
            }
        }
        .animation(DesignSystem.Motion.enter, value: index)
        .padding(.bottom, 24)
        .accessibilityHidden(true)
    }
}

/// One photo that can be pinched and double-tapped to zoom, and dragged around while it is zoomed in.
private struct ZoomablePhoto: View {
    let data: Data

    @State private var scale: CGFloat = 1
    @State private var settled: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var dragStart: CGSize = .zero

    var body: some View {
        Group {
            if let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFit()
            }
        }
        .scaleEffect(scale)
        .offset(offset)
        .gesture(
            MagnifyGesture()
                .onChanged { scale = min(4, max(1, settled * $0.magnification)) }
                .onEnded { _ in
                    settled = scale
                    if scale <= 1.01 { reset() }
                }
        )
        // Moving the photo only while it is zoomed, so a swipe at normal size still turns the page.
        .simultaneousGesture(
            scale > 1 ? DragGesture()
                .onChanged { offset = CGSize(width: dragStart.width + $0.translation.width, height: dragStart.height + $0.translation.height) }
                .onEnded { _ in dragStart = offset } : nil
        )
        .onTapGesture(count: 2) {
            withAnimation(DesignSystem.Motion.enter) {
                if scale > 1 { reset() } else { scale = 2; settled = 2 }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("Photo")
    }

    private func reset() {
        scale = 1; settled = 1; offset = .zero; dragStart = .zero
    }
}

// MARK: Zoom transition

private extension View {
    /// Marks the front photo as where the gallery grows from. The zoom needs iOS 18; earlier versions use the plain cover.
    @ViewBuilder
    func ideaPhotoZoomSource(_ namespace: Namespace.ID?) -> some View {
        if #available(iOS 18.0, *), let namespace {
            matchedTransitionSource(id: "ideaPhotos", in: namespace)
        } else {
            self
        }
    }
}

extension View {
    @ViewBuilder
    func ideaPhotoZoomDestination(_ namespace: Namespace.ID?) -> some View {
        if #available(iOS 18.0, *), let namespace {
            navigationTransition(.zoom(sourceID: "ideaPhotos", in: namespace))
        } else {
            self
        }
    }
}
