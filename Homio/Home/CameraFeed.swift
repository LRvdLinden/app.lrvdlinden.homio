import HomeKit
import SwiftUI

/// Snapshot- en livebeeld van één camera. Gedeeld tussen alle schermen die hem tonen.
final class CameraFeed: NSObject, ObservableObject {
    let accessory: HMAccessory
    @Published private(set) var source: HMCameraSource?
    @Published private(set) var isLive = false

    private var timer: Timer?
    private var viewers = 0
    private var liveViewers = 0

    init(accessory: HMAccessory) {
        self.accessory = accessory
        super.init()
        profile?.snapshotControl?.delegate = self
        profile?.streamControl?.delegate = self
    }

    var name: String { accessory.name }
    private var profile: HMCameraProfile? { accessory.cameraProfiles?.first }

    /// Een tegel verschijnt: elke 10 seconden een nieuwe snapshot.
    func attach() {
        viewers += 1
        guard viewers == 1 else { return }
        refreshSnapshot()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.refreshSnapshot()
        }
    }

    func detach() {
        viewers = max(0, viewers - 1)
        if viewers == 0 {
            timer?.invalidate()
            timer = nil
        }
    }

    func refreshSnapshot() {
        guard !isLive else { return }
        profile?.snapshotControl?.takeSnapshot()
    }

    func startLive() {
        liveViewers += 1
        if liveViewers == 1 { profile?.streamControl?.startStream() }
    }

    func stopLive() {
        liveViewers = max(0, liveViewers - 1)
        if liveViewers == 0 { profile?.streamControl?.stopStream() }
    }
}

extension CameraFeed: HMCameraSnapshotControlDelegate, HMCameraStreamControlDelegate {
    func cameraSnapshotControl(_ cameraSnapshotControl: HMCameraSnapshotControl,
                               didTake snapshot: HMCameraSnapshot?, error: Error?) {
        DispatchQueue.main.async {
            if !self.isLive, let snapshot { self.source = snapshot }
        }
    }

    func cameraStreamControlDidStartStream(_ cameraStreamControl: HMCameraStreamControl) {
        DispatchQueue.main.async {
            self.isLive = true
            self.source = cameraStreamControl.cameraStream
        }
    }

    func cameraStreamControl(_ cameraStreamControl: HMCameraStreamControl,
                             didStopStreamWithError error: Error?) {
        DispatchQueue.main.async {
            self.isLive = false
            self.refreshSnapshot()
        }
    }
}

/// HMCameraView in SwiftUI.
struct CameraSourceView: UIViewRepresentable {
    let source: HMCameraSource?

    func makeUIView(context: Context) -> HMCameraView {
        let view = HMCameraView()
        view.backgroundColor = .black
        view.cameraSource = source
        return view
    }

    func updateUIView(_ uiView: HMCameraView, context: Context) {
        if uiView.cameraSource !== source {
            uiView.cameraSource = source
        }
    }
}

struct CameraTile: View {
    @ObservedObject var feed: CameraFeed
    var showsName = true

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.black
            CameraSourceView(source: feed.source)
            if feed.source == nil {
                ProgressView().tint(.white).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if showsName {
                HStack(spacing: 6) {
                    if feed.isLive {
                        Circle().fill(.red).frame(width: 8, height: 8)
                    }
                    Text(feed.name).font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(10)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onAppear { feed.attach() }
        .onDisappear { feed.detach() }
    }
}

/// Volledig scherm met livebeeld.
struct CameraLiveView: View {
    @ObservedObject var feed: CameraFeed
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            CameraSourceView(source: feed.source).ignoresSafeArea()
            HStack {
                Label(feed.name, systemImage: feed.isLive ? "dot.radiowaves.left.and.right" : "camera")
                    .font(.headline)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Sluiten")
            }
            .padding(24)
        }
        .onAppear { feed.startLive() }
        .onDisappear { feed.stopLive() }
    }
}
