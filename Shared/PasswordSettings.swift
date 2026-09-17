//
//  PasswordSettings.swift
//  Shared
//
//  Source de vérité des réglages de génération (longueur + classes de
//  caractères) et de leurs bornes. Les apps les écrivent dans les UserDefaults
//  du groupe d'app ; les extensions AutoFill les relisent. Centraliser la
//  lecture évite que chaque cible réinvente ses valeurs par défaut — et corrige
//  le cas où une clé absente donnait une longueur de 0 (UserDefaults.integer
//  renvoie 0, pas nil, donc un `?? 20` ne s'appliquait jamais).
//

import Foundation

enum PasswordSettings {

    // MARK: - Bornes

    static let minLength = 4
    static let maxLength = 40
    static let defaultLength = 20
    static var lengthRange: ClosedRange<Int> { minLength...maxLength }

    /// Ramène une longueur dans les bornes. Une valeur absente ou illisible
    /// retombe sur la longueur par défaut plutôt que sur 0.
    static func clampLength(_ value: Int?) -> Int {
        guard let value else { return defaultLength }
        return min(maxLength, max(minLength, value))
    }

    // MARK: - Clés de stockage

    enum Key {
        static let encodingKey  = "encodingKey"
        static let lengthNumber = "lengthNumber"
        static let minState     = "minState"
        static let majState     = "majState"
        static let symState     = "symState"
        static let chiState     = "chiState"
    }

    // MARK: - Lecture

    struct Values {
        var length: Int
        var minState: Bool
        var majState: Bool
        var symState: Bool
        var chiState: Bool

        /// Au moins une classe de caractères doit être active pour qu'un mot de
        /// passe puisse être généré.
        var hasCharset: Bool { minState || majState || symState || chiState }
    }

    /// Relit les réglages tels que l'utilisateur les a définis dans l'app. Une
    /// clé jamais écrite prend sa valeur par défaut (et non `false` / `0`).
    static func load(from defaults: UserDefaults?) -> Values {
        func bool(_ key: String, default fallback: Bool) -> Bool {
            guard let defaults, defaults.object(forKey: key) != nil else { return fallback }
            return defaults.bool(forKey: key)
        }
        let storedLength = defaults?.object(forKey: Key.lengthNumber) == nil
            ? nil
            : defaults?.integer(forKey: Key.lengthNumber)

        return Values(length: clampLength(storedLength),
                      minState: bool(Key.minState, default: true),
                      majState: bool(Key.majState, default: true),
                      symState: bool(Key.symState, default: true),
                      chiState: bool(Key.chiState, default: true))
    }
}
