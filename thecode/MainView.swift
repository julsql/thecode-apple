//
//  MainView.swift
//  thecode-extension-ios
//
//  Created by Juliette Debono on 27/09/2025.
//

import SwiftUI
import LocalAuthentication
import AuthenticationServices

// MARK: - Localisation (FR si appareil en français, EN sinon par défaut)

enum L10n {
    // On lit `Locale.preferredLanguages` (la liste des langues choisies par
    // l'utilisateur dans Réglages → Général → Langue) plutôt que `Locale.current`,
    // qui est résolue contre les localizations déclarées par l'app : sans bundle
    // .lproj/CFBundleLocalizations, iOS retomberait toujours sur la langue de
    // développement (en) — d'où l'app en anglais sur un téléphone français.
    static let isFrench: Bool = {
        guard let primary = Locale.preferredLanguages.first else { return false }
        return primary.lowercased().hasPrefix("fr")
    }()

    static func t(_ fr: String, _ en: String) -> String {
        isFrench ? fr : en
    }
}

struct MainView: View {
    // Paramètres globaux
    @AppStorage("encodingKey", store: UserDefaults(suiteName: appGroupID)) var encodingKey: String = ""
    @AppStorage("lengthNumber", store: UserDefaults(suiteName: appGroupID)) var lengthNumber: Int = 20
    @AppStorage("minState", store: UserDefaults(suiteName: appGroupID)) var minState: Bool = true
    @AppStorage("majState", store: UserDefaults(suiteName: appGroupID)) var majState: Bool = true
    @AppStorage("symState", store: UserDefaults(suiteName: appGroupID)) var symState: Bool = true
    @AppStorage("chiState", store: UserDefaults(suiteName: appGroupID)) var chiState: Bool = true
    
    // UI state
    @State private var siteName: String = ""
    @State private var generatedValue: String = ""
    @State private var securityLabel: String = ""
    @State private var securityColor: Color = .black
    /// Brouillon de saisie du champ longueur. Nécessaire car un binding qui
    /// n'accepte que des valeurs déjà valides rend le champ inutilisable :
    /// taper « 30 » commence par « 3 », rejeté, donc le champ revenait
    /// aussitôt à sa valeur précédente.
    @State private var lengthDraft: String = String(PasswordSettings.defaultLength)
    @FocusState private var lengthFieldFocused: Bool
    
    // key editing / visibility
    @State private var showRealKey: Bool = false
    // Auth biométrique valide pour la session : autorise l'édition de la
    // clé (en mode masqué ou révélé) ET la génération de mots de passe.
    // L'état réel de référence est `SessionLock` (horodatage persistant) : ce
    // @State n'en est que le reflet, réévalué à chaque passage en .active.
    @State private var unlocked: Bool = false

    // Statut du remplissage automatique
    @State private var autofillEnabled: Bool = false

    // Réglages (thème, partage, information)
    @AppStorage("darkMode", store: UserDefaults(suiteName: appGroupID)) var darkMode: String = "SYSTEM"
    @State private var showShareSheet: Bool = false
    @State private var showInfoSheet: Bool = false
    @State private var showNoPasswordAlert: Bool = false

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            Form {
                // Paramètres globaux existants
                Section(header: Text(L10n.t("Paramètres de l'application", "App settings"))) {
                    
                    KeyFieldView(encodingKey: $encodingKey,
                                 showRealKey: $showRealKey,
                                 unlocked: $unlocked)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.t("Longueur du mot de passe", "Password length"))
                            .font(.headline)
                        
                        HStack {
                            Slider(value: Binding(
                                get: { Double(lengthNumber) },
                                set: { lengthNumber = Int($0) }
                            ),
                            in: Double(PasswordSettings.minLength)...Double(PasswordSettings.maxLength),
                            step: 1)

                            TextField("", text: $lengthDraft)
                                .frame(width: 50)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .focused($lengthFieldFocused)
                                .onSubmit { commitLengthDraft() }
                        }
                    }
                    
                    Toggle(L10n.t("Minuscules", "Lowercase"), isOn: $minState)
                    Toggle(L10n.t("Majuscules", "Uppercase"), isOn: $majState)
                    Toggle(L10n.t("Symboles", "Symbols"), isOn: $symState)
                    Toggle(L10n.t("Chiffres", "Digits"), isOn: $chiState)
                }

                Section(header: Text(L10n.t("Remplissage automatique", "Autofill"))) {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(autofillStatusColor)
                            .frame(width: 10, height: 10)
                        Text(autofillStatusText)
                            .foregroundColor(.primary)
                    }

                    Button(action: openAutofillSettings) {
                        HStack {
                            Image(systemName: "key.fill")
                            Text(autofillEnabled
                                 ? L10n.t("Ouvrir les paramètres", "Open settings")
                                 : L10n.t("Activer le remplissage automatique", "Enable autofill"))
                        }
                    }
                }

                Section(header: Text(L10n.t("Générer un mot de passe pour un site", "Generate a password for a website"))) {
                    if unlocked {
                        TextField(L10n.t("Nom du site", "Website name"), text: $siteName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                        if !generatedValue.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    TextField(L10n.t("Valeur générée", "Generated value"), text: $generatedValue)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .disabled(true)

                                    Button(action: {
                                        UIPasteboard.general.string = generatedValue
                                    }) {
                                        Image(systemName: "doc.on.doc") // icône “copier”
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                    .padding(.leading, 8)
                                }
                                Text(L10n.t("Sécurité : ", "Security: ") + localizedSecurityLabel(securityLabel))
                                    .foregroundColor(securityColor)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 4)
                        }
                    } else {
                        Button(action: authenticateForGeneration) {
                            HStack {
                                Image(systemName: "lock.fill")
                                Text(L10n.t("Authentifiez-vous pour générer un mot de passe",
                                            "Authenticate to generate a password"))
                            }
                        }
                    }
                }
            }
            .navigationTitle("TheCode")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: toggleTheme) {
                        Image(systemName: themeIconName)
                    }
                    .accessibilityLabel(L10n.t("Thème", "Theme"))

                    Button(action: tapShare) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel(L10n.t("Partager", "Share"))

                    Button(action: { showInfoSheet = true }) {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel(L10n.t("Information", "Information"))
                }
            }
            .onAppear {
                refreshAutofillStatus()
                restoreSession()
                lengthDraft = String(lengthNumber)
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    refreshAutofillStatus()
                    restoreSession()
                } else {
                    // L'utilisateur a quitté l'app (ou a juste ouvert le
                    // sélecteur d'apps). On masque la clé et le mot de passe
                    // pour que le snapshot ne les capture pas. La session
                    // d'auth n'est plus révoquée : on ré-horodate la fenêtre
                    // de grâce pour qu'elle courre à partir de maintenant.
                    showRealKey = false
                    generatedValue = ""
                    if unlocked { SessionLock.stamp() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ActivityView(activityItems: [shareText])
            }
            .sheet(isPresented: $showInfoSheet) {
                InfoSheet(isPresented: $showInfoSheet)
            }
            .alert(L10n.t("Aucun mot de passe à partager", "No password to share"), isPresented: $showNoPasswordAlert) {
                Button("OK", role: .cancel) { }
            }
        }
        .onChange(of: encodingKey) { _ in generatePassword() }
        .onChange(of: lengthNumber) { newVal in
            // Le slider (ou un clamp) a bougé la valeur : on réaligne le champ.
            if lengthDraft != String(newVal) { lengthDraft = String(newVal) }
            generatePassword()
        }
        .onChange(of: lengthDraft) { newVal in
            // Saisie complète et dans les bornes → appliquée immédiatement.
            if let val = Int(newVal), PasswordSettings.lengthRange.contains(val) {
                lengthNumber = val
            }
        }
        // Le pavé numérique n'a pas de touche retour : on valide la saisie
        // partielle ou hors bornes quand le champ perd le focus.
        .onChange(of: lengthFieldFocused) { focused in
            if !focused { commitLengthDraft() }
        }
        .onChange(of: minState) { _ in generatePassword() }
        .onChange(of: majState) { _ in generatePassword() }
        .onChange(of: symState) { _ in generatePassword() }
        .onChange(of: chiState) { _ in generatePassword() }
        .onChange(of: siteName) { _ in generatePassword() }
    }
    
    private var autofillStatusText: String {
        autofillEnabled
            ? L10n.t("Activé pour cet appareil", "Active on this device")
            : L10n.t("Désactivé — touchez pour configurer", "Disabled — tap to set up")
    }

    private func localizedSecurityLabel(_ frenchLabel: String) -> String {
        guard !L10n.isFrench else { return frenchLabel }
        switch frenchLabel {
        case "Aucune":      return "None"
        case "Très Faible": return "Very Weak"
        case "Faible":      return "Weak"
        case "Moyenne":     return "Medium"
        case "Forte":       return "Strong"
        case "Très Forte":  return "Very Strong"
        case "Erreur":      return "Error"
        default:            return frenchLabel
        }
    }

    private var autofillStatusColor: Color {
        autofillEnabled ? .green : .red
    }

    private func refreshAutofillStatus() {
        ASCredentialIdentityStore.shared.getState { state in
            DispatchQueue.main.async {
                self.autofillEnabled = state.isEnabled
            }
        }
    }

    // MARK: - Réglages (thème / partage / information)

    private var themeIconName: String {
        switch darkMode {
        case "DARK":  return "moon.fill"
        case "LIGHT": return "sun.max.fill"
        default:      return "circle.lefthalf.filled"
        }
    }

    private func toggleTheme() {
        // Cycle : SYSTEM → DARK → LIGHT → SYSTEM. On garde SYSTEM atteignable
        // pour permettre de revenir au mode par défaut (suivre le système).
        switch darkMode {
        case "SYSTEM": darkMode = "DARK"
        case "DARK":   darkMode = "LIGHT"
        default:       darkMode = "SYSTEM"
        }
    }

    private var shareText: String {
        String(format: L10n.t("Mon mot de passe pour %@ est :\n%@",
                              "My password for %@ is:\n%@"),
               siteName, generatedValue)
    }

    private func tapShare() {
        if generatedValue.isEmpty {
            showNoPasswordAlert = true
        } else {
            showShareSheet = true
        }
    }

    private func openAutofillSettings() {
        if #available(iOS 17.0, *) {
            Task { try? await ASSettingsHelper.openCredentialProviderAppSettings() }
        } else if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func authenticateForGeneration() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                        error: &error) else {
            return
        }
        let reason = L10n.t("Authentifiez-vous pour générer un mot de passe",
                            "Authenticate to generate a password")
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                               localizedReason: reason) { success, _ in
            DispatchQueue.main.async {
                if success {
                    SessionLock.stamp()
                    unlocked = true
                }
            }
        }
    }

    /// Réévalue la session à chaque passage au premier plan : si la fenêtre de
    /// grâce court toujours on reste déverrouillé (et on régénère l'affichage
    /// effacé lors de la mise en fond), sinon on repart d'un écran verrouillé.
    private func restoreSession() {
        if SessionLock.isValid {
            SessionLock.stamp()
            unlocked = true
            generatePassword()
        } else {
            SessionLock.invalidate()
            unlocked = false
            showRealKey = false
            siteName = ""
            generatedValue = ""
        }
    }

    /// Valide le brouillon : une saisie vide, partielle ou hors bornes est
    /// ramenée dans les limites plutôt que silencieusement ignorée.
    private func commitLengthDraft() {
        let clamped = PasswordSettings.clampLength(Int(lengthDraft) ?? lengthNumber)
        lengthNumber = clamped
        lengthDraft = String(clamped)
    }

    private func generatePassword() {
        // Verrou d'autorisation : pas de génération sans auth de session.
        // Les bindings @AppStorage continuent de notifier les onChange,
        // mais on s'arrête ici tant que l'utilisateur ne s'est pas
        // authentifié.
        guard unlocked else { return }
        if (siteName == "" || encodingKey == "" || (!minState && !majState && !symState && !chiState)) {
            return;
        }
        
        let utils = PasswordUtils()
        utils.minState = minState
        utils.majState = majState
        utils.symState = symState
        utils.chiState = chiState
        utils.longueur = lengthNumber
        
        let result = utils.generatePassword(input: siteName + encodingKey)
        generatedValue = result.code
        securityLabel = result.label
        securityColor = result.color
    }

}

// MARK: - Share sheet (UIActivityViewController bridge pour iOS 15+)

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

// MARK: - Information sheet

private struct InfoSheet: View {
    @Binding var isPresented: Bool

    private static let infoFR: String = """
TheCode est un gestionnaire de mots de passe libre et open-source qui ne stocke aucun mot de passe : il les régénère à la volée à partir d'une seule clé secrète que vous mémorisez.

Choisissez votre clé, entrez le nom du site (par exemple « google.com » pour votre compte Google), ajustez la longueur et les options (minuscules, majuscules, chiffres, symboles), et le mot de passe est généré. Pour le retrouver, il vous suffit de revenir avec la même clé et le même nom de site.

En interne, TheCode combine votre clé avec le nom du site et applique une fonction cryptographique (SHA-256). Le résultat est converti en un mot de passe robuste qui respecte vos critères. Même clé + même site = même mot de passe, à chaque fois, de manière déterministe.

Aucun mot de passe n'est jamais sauvegardé ni transmis : tous les calculs ont lieu localement, sans connexion internet, sans compte, sans pistage.

TheCode vous suit partout : extensions navigateur (Chrome, Firefox, Safari, Edge, Opera) et applications natives iOS et Android. Avec la même clé, vous retrouvez les mêmes mots de passe sur toutes vos plateformes.
"""

    private static let infoEN: String = """
TheCode is a free and open-source password manager that stores no passwords: it regenerates them on the fly from a single secret key that you remember.

Choose your key, enter the website name (for example « google.com » for your Google account), tweak the length and the options (lowercase, uppercase, digits, symbols), and the password is generated. To find it again, just come back with the same key and the same website name.

Internally, TheCode combines your key with the website name and applies a cryptographic function (SHA-256). The result is converted into a strong password that matches your criteria. Same key + same website = same password, every time, deterministically.

No password is ever saved or transmitted: every computation happens locally, with no internet connection, no account, no tracking.

TheCode follows you everywhere: browser extensions (Chrome, Firefox, Safari, Edge, Opera) and native iOS and Android apps. With the same key, you find the same passwords across all your platforms.
"""

    var body: some View {
        NavigationView {
            ScrollView {
                Text(L10n.t(Self.infoFR, Self.infoEN))
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(L10n.t("Information", "Information"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("OK") { isPresented = false }
                }
            }
        }
    }
}
