//
//  MainView.swift
//  thecode-macos
//

import SwiftUI
import LocalAuthentication
import AppKit

let appGroupID = "group.fr.julsql.thecode.params"

// MARK: - Localisation (FR si système en français, EN sinon)

enum L10n {
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
    @AppStorage("darkMode", store: UserDefaults(suiteName: appGroupID)) var darkMode: String = "SYSTEM"

    @State private var siteName: String = ""
    @State private var generatedValue: String = ""
    @State private var securityLabel: String = ""
    @State private var securityColor: Color = .primary
    /// Brouillon de saisie du champ longueur. Nécessaire car un binding qui
    /// n'accepte que des valeurs déjà valides rend le champ inutilisable :
    /// taper « 30 » commence par « 3 », rejeté, donc le champ revenait
    /// aussitôt à sa valeur précédente.
    @State private var lengthDraft: String = String(PasswordSettings.defaultLength)
    @FocusState private var lengthFieldFocused: Bool
    @State private var showRealKey: Bool = false
    // Auth biométrique valide pour la session : autorise l'édition de la
    // clé (en mode masqué ou révélé) ET la génération de mots de passe.
    // L'état réel de référence est `SessionLock` (horodatage persistant) : ce
    // @State n'en est que le reflet, réévalué à chaque activation de l'app.
    @State private var unlocked: Bool = false

    // UI
    @State private var showInfoSheet: Bool = false
    @State private var showNoPasswordAlert: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Barre supérieure (titre + actions)
            HStack(spacing: 12) {
                Text("TheCode")
                    .font(.title2.bold())

                Spacer()

                Button(action: toggleTheme) {
                    Image(systemName: themeIconName)
                }
                .buttonStyle(.borderless)
                .help(L10n.t("Thème", "Theme"))

                Button(action: tapShare) {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(.borderless)
                .help(L10n.t("Partager", "Share"))

                Button(action: { showInfoSheet = true }) {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.borderless)
                .help(L10n.t("Information", "Information"))
            }
            .font(.title3)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.bar)

            Divider()

            // Contenu principal
            Form {
                Section(header: Text(L10n.t("Paramètres de l'application", "App settings"))) {
                    KeyFieldView(encodingKey: $encodingKey,
                                 showRealKey: $showRealKey,
                                 unlocked: $unlocked)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.t("Longueur du mot de passe", "Password length"))
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

                Section(header: Text(L10n.t("Remplissage automatique", "AutoFill"))) {
                    Text(L10n.t(
                        "TheCode peut remplir vos mots de passe dans Safari et les apps. Activez-le dans Réglages Système → Mots de passe → Options, puis cochez TheCode.",
                        "TheCode can fill your passwords in Safari and apps. Enable it in System Settings → Passwords → Options, then tick TheCode."))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(action: openAutoFillSettings) {
                        HStack {
                            Image(systemName: "key.fill")
                            Text(L10n.t("Ouvrir les réglages de mots de passe",
                                        "Open password settings"))
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

                                    Button(action: copyGeneratedValue) {
                                        Image(systemName: "doc.on.doc")
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                    .padding(.leading, 8)
                                }
                                Text(L10n.t("Sécurité : ", "Security: ") + localizedSecurityLabel(securityLabel))
                                    .foregroundColor(securityColor)
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
            .formStyle(.grouped)
        }
        .frame(minWidth: 520, minHeight: 600)
        .preferredColorScheme(preferredScheme)
        .onAppear {
            applyAppAppearance()
            restoreSession()
            lengthDraft = String(lengthNumber)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            // Dès qu'on bascule sur une autre app : re-masquage de la clé
            // pour qu'elle ne reste pas en clair dans une fenêtre visible en
            // arrière-plan, et effacement du mot de passe affiché. La session
            // d'auth n'est plus révoquée : on ré-horodate la fenêtre de grâce
            // pour qu'elle courre à partir de maintenant.
            showRealKey = false
            generatedValue = ""
            if unlocked { SessionLock.stamp() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            restoreSession()
        }
        .onChange(of: darkMode) { _ in applyAppAppearance() }
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
        // Valide la saisie partielle ou hors bornes à la perte du focus.
        .onChange(of: lengthFieldFocused) { focused in
            if !focused { commitLengthDraft() }
        }
        .onChange(of: minState) { _ in generatePassword() }
        .onChange(of: majState) { _ in generatePassword() }
        .onChange(of: symState) { _ in generatePassword() }
        .onChange(of: chiState) { _ in generatePassword() }
        .onChange(of: siteName) { _ in generatePassword() }
        .sheet(isPresented: $showInfoSheet) {
            InfoSheet(isPresented: $showInfoSheet)
        }
        .alert(L10n.t("Aucun mot de passe à partager", "No password to share"), isPresented: $showNoPasswordAlert) {
            Button("OK", role: .cancel) { }
        }
    }

    // MARK: - Réglages AutoFill

    /// Ouvre le volet Mots de passe des Réglages Système (où l'utilisateur
    /// active TheCode comme source de remplissage). Le deep-link direct n'est
    /// pas garanti selon les versions de macOS : on retombe sinon sur
    /// l'ouverture des Réglages Système.
    private func openAutoFillSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.Passwords-Settings.extension",
            "x-apple.systempreferences:com.apple.preferences.password",
        ]
        for string in candidates {
            if let url = URL(string: string), NSWorkspace.shared.open(url) {
                return
            }
        }
        if let settings = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.systempreferences") {
            NSWorkspace.shared.open(settings)
        }
    }

    // MARK: - Thème

    private var preferredScheme: ColorScheme? {
        switch darkMode {
        case "DARK":  return .dark
        case "LIGHT": return .light
        default:      return nil
        }
    }

    private var themeIconName: String {
        switch darkMode {
        case "DARK":  return "moon.fill"
        case "LIGHT": return "sun.max.fill"
        default:      return "circle.lefthalf.filled"
        }
    }

    private func toggleTheme() {
        // Cycle SYSTEM → DARK → LIGHT → SYSTEM
        switch darkMode {
        case "SYSTEM": darkMode = "DARK"
        case "DARK":   darkMode = "LIGHT"
        default:       darkMode = "SYSTEM"
        }
    }

    private func applyAppAppearance() {
        // Applique l'apparence au chrome de la fenêtre (titre, contrôles).
        switch darkMode {
        case "DARK":  NSApp.appearance = NSAppearance(named: .darkAqua)
        case "LIGHT": NSApp.appearance = NSAppearance(named: .aqua)
        default:      NSApp.appearance = nil
        }
    }

    // MARK: - Partage

    private var shareText: String {
        String(format: L10n.t("Mon mot de passe pour %@ est :\n%@",
                              "My password for %@ is:\n%@"),
               siteName, generatedValue)
    }

    private func tapShare() {
        if generatedValue.isEmpty {
            showNoPasswordAlert = true
            return
        }
        let picker = NSSharingServicePicker(items: [shareText])
        if let contentView = NSApp.keyWindow?.contentView {
            picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
        }
    }

    // MARK: - Sécurité

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

    // MARK: - Copie

    private func copyGeneratedValue() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(generatedValue, forType: .string)
    }

    // MARK: - Génération

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

    /// Réévalue la session à chaque activation : si la fenêtre de grâce court
    /// toujours on reste déverrouillé (et on régénère l'affichage effacé au
    /// passage en arrière-plan), sinon on repart d'un écran verrouillé propre.
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
        guard unlocked else { return }
        if siteName.isEmpty || encodingKey.isEmpty || (!minState && !majState && !symState && !chiState) {
            return
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
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("Information", "Information"))
                .font(.title2.bold())

            ScrollView {
                Text(L10n.t(Self.infoFR, Self.infoEN))
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }

            HStack {
                Spacer()
                Button("OK") { isPresented = false }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 520, minHeight: 480)
    }
}
