import SwiftUI

/// Tot negen camerabeelden tegelijk.
struct CameraFace: View {
    let openPanel: (AppPanel) -> Void
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            HomeStateGate {
                CameraGrid(maxCount: 9)
                    .facePadding(sizeClass == .compact)
            }
        }
        .foregroundStyle(.white)
    }
}
