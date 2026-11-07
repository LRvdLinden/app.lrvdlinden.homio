import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var settings: SettingsStore

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var error: String?
    @State private var appeared = false

    private var compact: Bool { sizeClass == .compact }

    var body: some View {
        ZStack {
            AmbientBackground()

            ScrollView {
                VStack(spacing: 34) {
                    HomioLogo(size: compact ? 112 : 140)
                        .scaleEffect(appeared ? 1 : 0.7)
                        .opacity(appeared ? 1 : 0)

                    VStack(spacing: 10) {
                        Text("Welkom bij Homio")
                            .font(.system(size: compact ? 36 : 50, weight: .bold, design: .rounded))
                        Text("Het warme scherm voor je slimme huis.")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 20) {
                        FeatureRow(icon: "house.fill",
                                   title: "Je hele woning",
                                   text: "Lampen, thermostaat, sloten en scènes via HomeKit en Matter.")
                        FeatureRow(icon: "video.fill",
                                   title: "Camera's",
                                   text: "Tot negen camerabeelden tegelijk in beeld.")
                        FeatureRow(icon: "rectangle.stack.fill",
                                   title: "Faces",
                                   text: "Klok, foto's, weer, agenda en interactieve kunst.")
                        FeatureRow(icon: "person.2.fill",
                                   title: "Voor het hele huis",
                                   text: "Elk gezinslid een eigen profiel met favorieten.")
                    }
                    .padding(28)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()

                    VStack(spacing: 14) {
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName]
                        } onCompletion: { result in
                            error = auth.handle(result)
                            if auth.isSignedIn {
                                settings.ensureProfile(named: auth.displayName)
                            }
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 58)
                        .clipShape(Capsule())

                        if let error {
                            Text(error)
                                .font(.callout)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }

                        Text("Je Apple-account wordt alleen gebruikt om jou te herkennen. Je gegevens blijven op dit apparaat en in je eigen iCloud.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: 560)
                .padding(compact ? 22 : 40)
                .frame(maxWidth: .infinity)
                .offset(y: appeared ? 0 : 30)
                .opacity(appeared ? 1 : 0)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.8)) { appeared = true }
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Theme.amber)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Theme.amber.opacity(0.15)))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.white.opacity(0.65))
            }
        }
    }
}
