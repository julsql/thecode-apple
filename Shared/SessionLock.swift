//
//  SessionLock.swift
//  Shared (TheCode iOS / TheCode for Mac)
//
//  Fenêtre de grâce de l'authentification biométrique, partagée par les deux
//  apps. L'horodatage vit dans les UserDefaults du groupe d'app et non dans le
//  process : la session survit donc à une mise en arrière-plan comme à une
//  fermeture complète de l'app, tant que la fenêtre n'est pas écoulée. Même
//  principe que le gestionnaire de mots de passe d'Apple.
//

import Foundation

/// Identifiant du groupe d'app. Redéclaré ici (en `fileprivate`) plutôt que
/// réutilisé depuis les targets : ce fichier est aussi compilé dans le bundle
/// de tests iOS, qui n'embarque pas le code de l'app.
fileprivate let sessionStoreAppGroupID = "group.fr.julsql.thecode.params"

enum SessionLock {
    /// Durée de validité d'une auth après le dernier passage au premier plan.
    static let graceInterval: TimeInterval = 3 * 60

    private static let storageKey = "lastUnlockAt"
    private static var store: UserDefaults? {
        UserDefaults(suiteName: sessionStoreAppGroupID)
    }

    /// Horodate l'instant de référence : à chaque auth réussie, et à chaque
    /// fois que l'app quitte le premier plan avec une session valide (c'est ce
    /// dernier point qui fait courir la fenêtre à partir de la mise en fond).
    static func stamp() {
        store?.set(Date().timeIntervalSince1970, forKey: storageKey)
    }

    /// Invalide la session : la prochaine ouverture exigera une auth.
    static func invalidate() {
        store?.removeObject(forKey: storageKey)
    }

    /// `true` si la dernière auth est encore dans la fenêtre de grâce.
    static var isValid: Bool {
        guard let stamped = store?.object(forKey: storageKey) as? Double else { return false }
        return isWithinGrace(stampedAt: stamped, now: Date().timeIntervalSince1970)
    }

    /// Logique pure du verrou, isolée du stockage et de l'horloge pour être
    /// testable. Un horodatage nul/négatif (jamais authentifié) ou situé dans
    /// le futur (horloge reculée) n'est pas valide : on préfère reverrouiller
    /// plutôt que prolonger la session indéfiniment.
    static func isWithinGrace(stampedAt: TimeInterval, now: TimeInterval) -> Bool {
        guard stampedAt > 0 else { return false }
        let elapsed = now - stampedAt
        return elapsed >= 0 && elapsed <= graceInterval
    }
}
