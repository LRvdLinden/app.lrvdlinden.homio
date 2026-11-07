import SwiftUI
import AuthenticationServices

/// Inloggen met Apple. De Apple-gebruikers-ID staat in de sleutelhanger;
/// er is geen eigen server nodig.
@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var userID: String?
    @Published private(set) var displayName: String

    private let userKey = "appleUserID"
    private let nameKey = "displayName"

    init() {
        userID = KeychainStore.get(userKey)
        displayName = UserDefaults.standard.string(forKey: nameKey) ?? ""
    }

    var isSignedIn: Bool { userID != nil }

    /// Verwerkt de uitkomst van de knop. Geeft een foutmelding terug, of nil.
    func handle(_ result: Result<ASAuthorization, Error>) -> String? {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                return "Onbekend type login."
            }
            KeychainStore.set(credential.user, for: userKey)
            // Apple geeft de naam alleen bij de allereerste keer inloggen.
            if let given = credential.fullName?.givenName, !given.isEmpty {
                displayName = given
                UserDefaults.standard.set(given, forKey: nameKey)
            }
            withAnimation(.easeInOut(duration: 0.5)) { userID = credential.user }
            return nil
        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                return nil
            }
            return "Inloggen is niet gelukt: \(error.localizedDescription)"
        }
    }

    /// Controleert bij het starten of de koppeling met Apple nog geldig is.
    func verifyCredential() {
        guard let id = userID else { return }
        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: id) { state, _ in
            Task { @MainActor in
                if state == .revoked { self.signOut() }
            }
        }
    }

    func signOut() {
        KeychainStore.delete(userKey)
        withAnimation(.easeInOut(duration: 0.4)) { userID = nil }
    }
}
