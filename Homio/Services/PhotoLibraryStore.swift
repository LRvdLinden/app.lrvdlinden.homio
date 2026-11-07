import PhotosUI
import SwiftUI

/// Foto's voor de fotolijst-face, verkleind bewaard in de app zelf.
@MainActor
final class PhotoLibraryStore: ObservableObject {
    @Published private(set) var urls: [URL] = []
    @Published private(set) var isImporting = false

    private let folder: URL
    private let cache = NSCache<NSURL, UIImage>()

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        folder = base.appendingPathComponent("Photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        cache.countLimit = 12
        reload()
    }

    func reload() {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        urls = files.filter { $0.pathExtension == "jpg" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    func add(_ items: [PhotosPickerItem]) async {
        isImporting = true
        defer { isImporting = false }
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { continue }
            let scaled = image.scaledDown(maxSide: 2400)
            guard let jpeg = scaled.jpegData(compressionQuality: 0.85) else { continue }
            let name = "\(Int(Date().timeIntervalSince1970 * 1000))-\(UUID().uuidString.prefix(6)).jpg"
            try? jpeg.write(to: folder.appendingPathComponent(name))
        }
        reload()
    }

    func image(for url: URL) -> UIImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        cache.setObject(image, forKey: url as NSURL)
        return image
    }

    func removeAll() {
        for url in urls { try? FileManager.default.removeItem(at: url) }
        cache.removeAllObjects()
        reload()
    }
}

extension UIImage {
    func scaledDown(maxSide: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxSide else { return self }
        let factor = maxSide / longest
        let newSize = CGSize(width: size.width * factor, height: size.height * factor)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
