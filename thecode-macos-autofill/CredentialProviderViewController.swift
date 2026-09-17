//
//  CredentialProviderViewController.swift
//  thecode-macos-autofill
//
//  Pendant macOS de l'extension AutoFill iOS (`thecode-autofill`).
//  Cycle de vie :
//    1. macOS instancie ce NSViewController et appelle prepareCredentialList(...)
//       ou prepareInterfaceToProvideCredential(...) avec le domaine cible.
//    2. Si une clé est définie : AutofillModel déclenche Touch ID, puis le mot
//       de passe est calculé et transmis à macOS après authentification.
//    3. Si aucune clé n'est définie : contrairement à iOS, macOS ne présente
//       pas l'UI custom de l'extension dans le flux Safari (la requête resterait
//       sans réponse et figerait le navigateur). On annule donc la requête
//       (pour libérer le navigateur) et on ouvre l'app principale pour que
//       l'utilisateur y définisse sa clé.
//

import AuthenticationServices
import AppKit
import SwiftUI

let appGroupID = "group.fr.julsql.thecode.params"

final class CredentialProviderViewController: ASCredentialProviderViewController {

    private let model = AutofillModel()

    override func loadView() {
        // Pas de nib : on fournit une vue conteneur, la vue SwiftUI est
        // ajoutée dans viewDidLoad.
        view = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 420))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        model.controller = self

        let host = NSHostingController(rootView: ContentView(model: model))
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.width, .height]
        view.addSubview(host.view)
    }

    // MARK: – macOS lifecycle

    /// On refuse systématiquement le remplissage sans interaction : la clé ne
    /// peut servir qu'après authentification de l'utilisateur.
    override func provideCredentialWithoutUserInteraction(
        for credentialIdentity: ASPasswordCredentialIdentity
    ) {
        extensionContext.cancelRequest(withError: NSError(
            domain: ASExtensionErrorDomain,
            code: ASExtensionError.userInteractionRequired.rawValue
        ))
    }

    override func prepareCredentialList(
        for serviceIdentifiers: [ASCredentialServiceIdentifier]
    ) {
        let domain: String
        if let first = serviceIdentifiers.first {
            domain = DomainNormalizer.normalize(first)
        } else {
            domain = ""
        }
        Task { @MainActor in self.present(domain: domain) }
    }

    override func prepareInterfaceToProvideCredential(
        for credentialIdentity: ASPasswordCredentialIdentity
    ) {
        let domain = DomainNormalizer.normalize(credentialIdentity.serviceIdentifier)
        Task { @MainActor in self.present(domain: domain) }
    }

    /// Si la clé est définie, on lance directement Touch ID. Sinon, on annule la
    /// requête (pour libérer le navigateur) puis on ouvre l'app.
    @MainActor
    private func present(domain: String) {
        model.domain = domain
        if isKeyDefined() {
            model.startBiometricIfNeeded()
        } else {
            openHostAppForKeySetup()
        }
    }

    /// Annule d'abord la requête — pour ne JAMAIS laisser le navigateur en
    /// attente, quelle que soit la suite — puis ouvre l'app (best-effort) afin
    /// que l'utilisateur définisse sa clé.
    private func openHostAppForKeySetup() {
        cancel()
        if let url = URL(string: "thecode://set-key") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: – Appelé par AutofillModel après auth

    func completeFill(domain: String) {
        let password = generatePassword(domainName: domain)
        guard !password.isEmpty else {
            // Cas pathologique : clé absente ou aucun charset coché dans l'app.
            extensionContext.cancelRequest(withError: NSError(
                domain: ASExtensionErrorDomain,
                code: ASExtensionError.failed.rawValue
            ))
            return
        }
        let credential = ASPasswordCredential(user: "", password: password)
        extensionContext.completeRequest(
            withSelectedCredential: credential,
            completionHandler: nil
        )
    }

    func cancel() {
        extensionContext.cancelRequest(withError: NSError(
            domain: ASExtensionErrorDomain,
            code: ASExtensionError.userCanceled.rawValue
        ))
    }

    // MARK: – Clé partagée

    /// Vrai si une clé a été définie dans l'app (lue depuis l'app group).
    func isKeyDefined() -> Bool {
        let defaults = UserDefaults(suiteName: appGroupID)
        let key = defaults?.string(forKey: "encodingKey") ?? ""
        return !key.isEmpty
    }

    // MARK: – Génération

    private func generatePassword(domainName: String) -> String {
        let defaults = UserDefaults(suiteName: appGroupID)
        // Lecture centralisée (cf. PasswordSettings) : une clé jamais écrite
        // prend sa valeur par défaut. Avant, `integer(forKey:)` renvoyait 0
        // pour une longueur absente — et `?? 20` ne s'appliquait jamais, car
        // `integer(forKey:)` ne renvoie pas nil.
        let settings = PasswordSettings.load(from: defaults)
        let encodingKey = defaults?.string(forKey: PasswordSettings.Key.encodingKey) ?? ""

        if domainName.isEmpty || encodingKey.isEmpty || !settings.hasCharset {
            return ""
        }

        let utils = PasswordUtils()
        utils.minState = settings.minState
        utils.majState = settings.majState
        utils.symState = settings.symState
        utils.chiState = settings.chiState
        utils.longueur = settings.length

        return utils.generatePassword(input: domainName + encodingKey).code
    }
}
