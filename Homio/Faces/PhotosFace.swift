import PhotosUI
import SwiftUI

/// Digitale fotolijst met langzaam inzoomende foto's (Ken Burns) en een kleine klok.
struct PhotosFace: View {
    @EnvironmentObject private var photos: PhotoLibraryStore
    @State private var index = 0
    @State private var picks: [PhotosPickerItem] = []

    private let timer = Timer.publish(every: 12, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.black.ignoresSafeArea()

            if photos.urls.isEmpty {
                VStack(spacing: 18) {
                    Image(systemName: "photo.stack").font(.system(size: 60))
                    Text("Kies foto's voor je fotolijst").font(.title2.weight(.semibold))
                    PhotosPicker(selection: $picks, maxSelectionCount: 50, matching: .images) {
                        Label("Foto's kiezen", systemImage: "plus")
                            .font(.headline)
                            .padding(.horizontal, 22).padding(.vertical, 14)
                            .background(Capsule().fill(Theme.amber))
                            .foregroundStyle(.black)
                    }
                    if photos.isImporting { ProgressView() }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let url = photos.urls[safe: index % max(1, photos.urls.count)],
                      let image = photos.image(for: url) {
                KenBurnsImage(image: image)
                    .id(url)
                    .transition(.opacity)
                    .ignoresSafeArea()

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.date, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
                            .font(.system(size: 64, weight: .light, design: .rounded))
                            .monospacedDigit()
                        Text(context.date.formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalized)
                            .font(.title3)
                    }
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 10)
                    .padding(.leading, 44)
                    .padding(.bottom, 130)
                }
            }
        }
        .onReceive(timer) { _ in
            guard photos.urls.count > 1 else { return }
            withAnimation(.easeInOut(duration: 1.6)) {
                index = (index + 1) % photos.urls.count
            }
        }
        .onChange(of: picks) { _, items in
            guard !items.isEmpty else { return }
            Task {
                await photos.add(items)
                picks = []
            }
        }
    }
}

private struct KenBurnsImage: View {
    let image: UIImage
    @State private var zoomed = false
    @State private var anchor: UnitPoint = [UnitPoint.topLeading, .topTrailing, .bottomLeading, .bottomTrailing, .center].randomElement() ?? .center

    var body: some View {
        GeometryReader { geo in
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .scaleEffect(zoomed ? 1.14 : 1.0, anchor: anchor)
                .clipped()
        }
        .onAppear {
            withAnimation(.linear(duration: 14)) { zoomed = true }
        }
    }
}
