import PhotosUI
import SwiftUI

/// Rond profielplaatje: de foto, of de eerste letter op de profielkleur.
struct ProfileAvatar: View {
    let profile: Profile?
    var size: CGFloat = 52

    var body: some View {
        Group {
            if let data = profile?.photo, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(verbatim: profile?.initial ?? "H")
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(profile.map { AnyShapeStyle($0.color.gradient) } ?? AnyShapeStyle(Theme.blueGradient))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

/// Naam wijzigen en een profielfoto kiezen.
struct ProfileEditView: View {
    let profileID: UUID

    @EnvironmentObject private var settings: SettingsStore
    @State private var name = ""
    @State private var pick: PhotosPickerItem?
    @State private var loading = false

    private var profile: Profile? { settings.profiles.first { $0.id == profileID } }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 14) {
                    ZStack(alignment: .bottomTrailing) {
                        ProfileAvatar(profile: profile, size: 112)
                        PhotosPicker(selection: $pick, matching: .images, photoLibrary: .shared()) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Theme.accent))
                                .overlay(Circle().strokeBorder(Theme.background, lineWidth: 3))
                        }
                        .accessibilityLabel("Profielfoto kiezen")
                    }
                    if loading { ProgressView() }
                    if profile?.photo != nil {
                        Button("Foto verwijderen", role: .destructive) {
                            settings.updateProfile(profileID, photo: .some(nil))
                        }
                        .font(HomeyFont.small)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            Section {
                TextField("Naam", text: $name)
                    .textContentType(.givenName)
                    .submitLabel(.done)
                    .onSubmit { settings.updateProfile(profileID, name: name) }
            } header: {
                Text("Naam")
            } footer: {
                Text("Zo begroet Homio je op Home, bijvoorbeeld \"Goedenavond, \(name.isEmpty ? "Léon" : name)\".")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Profiel")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { name = profile?.name ?? "" }
        .onDisappear { settings.updateProfile(profileID, name: name) }
        .onChange(of: pick) { _, item in
            guard let item else { return }
            loading = true
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let small = Self.thumbnail(data) {
                    settings.updateProfile(profileID, photo: .some(small))
                }
                loading = false
                pick = nil
            }
        }
    }

    /// Vierkant uitsnijden en verkleinen tot 240 px, als JPEG.
    static func thumbnail(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let side = min(image.size.width, image.size.height)
        let crop = CGRect(x: (image.size.width - side) / 2, y: (image.size.height - side) / 2, width: side, height: side)
        let target = CGSize(width: 240, height: 240)
        let renderer = UIGraphicsImageRenderer(size: target)
        let result = renderer.image { _ in
            image.draw(in: CGRect(x: -crop.minX * 240 / side, y: -crop.minY * 240 / side,
                                  width: image.size.width * 240 / side, height: image.size.height * 240 / side))
        }
        return result.jpegData(compressionQuality: 0.75)
    }
}
