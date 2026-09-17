//
//  thecode_macosTests.swift
//  thecode-macosTests
//
//  Created by Juliette Debono on 29/09/2025.
//

import Foundation
import Testing
@testable import TheCode_for_Mac

struct thecode_macosTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

}

// MARK: - SessionLock

/// Fenêtre de grâce de l'authentification : on teste la logique pure
/// (`isWithinGrace`) plutôt que le stockage, pour ne pas dépendre des
/// UserDefaults du groupe d'app ni de l'horloge système.
struct SessionLockTests {

    private let grace = SessionLock.graceInterval

    @Test func rejectsWhenNeverAuthenticated() {
        #expect(SessionLock.isWithinGrace(stampedAt: 0, now: 1_000) == false)
    }

    @Test func acceptsImmediatelyAfterAuth() {
        #expect(SessionLock.isWithinGrace(stampedAt: 1_000, now: 1_000))
    }

    @Test func acceptsInsideGraceWindow() {
        #expect(SessionLock.isWithinGrace(stampedAt: 1_000, now: 1_000 + grace - 1))
    }

    @Test func acceptsExactlyAtGraceBoundary() {
        #expect(SessionLock.isWithinGrace(stampedAt: 1_000, now: 1_000 + grace))
    }

    @Test func rejectsPastGraceWindow() {
        #expect(SessionLock.isWithinGrace(stampedAt: 1_000, now: 1_000 + grace + 1) == false)
    }

    /// Horloge reculée : on préfère reverrouiller plutôt que de prolonger la
    /// session indéfiniment.
    @Test func rejectsStampInTheFuture() {
        #expect(SessionLock.isWithinGrace(stampedAt: 2_000, now: 1_000) == false)
    }
}

// MARK: - PasswordSettings

/// Réglages de génération : bornes de longueur et lecture depuis un store.
/// On utilise une suite UserDefaults dédiée pour ne pas toucher au groupe
/// d'app réel.
struct PasswordSettingsTests {

    /// Une suite distincte par test : Swift Testing exécute les cas en
    /// parallèle, une suite partagée serait écrasée d'un test à l'autre.
    private func makeStore() -> UserDefaults {
        let name = "fr.julsql.thecode.tests.settings.\(UUID().uuidString)"
        let store = UserDefaults(suiteName: name)!
        store.removePersistentDomain(forName: name)
        return store
    }

    // MARK: clampLength

    @Test func clampsBelowMinimum() {
        #expect(PasswordSettings.clampLength(1) == PasswordSettings.minLength)
    }

    @Test func clampsAboveMaximum() {
        #expect(PasswordSettings.clampLength(99) == PasswordSettings.maxLength)
    }

    @Test func keepsValueInsideBounds() {
        #expect(PasswordSettings.clampLength(30) == 30)
    }

    @Test func fallsBackToDefaultWhenNil() {
        #expect(PasswordSettings.clampLength(nil) == PasswordSettings.defaultLength)
    }

    // MARK: load

    @Test func loadWithoutStoreReturnsDefaults() {
        let values = PasswordSettings.load(from: nil)
        #expect(values.length == PasswordSettings.defaultLength)
        #expect(values.minState && values.majState && values.symState && values.chiState)
    }

    /// Régression : `UserDefaults.integer(forKey:)` renvoie 0 (et non nil) pour
    /// une clé absente, ce qui donnait une longueur de 0 dans les extensions.
    @Test func missingLengthFallsBackToDefaultNotZero() {
        let values = PasswordSettings.load(from: makeStore())
        #expect(values.length == PasswordSettings.defaultLength)
    }

    @Test func readsUserDefinedLength() {
        let store = makeStore()
        store.set(30, forKey: PasswordSettings.Key.lengthNumber)
        #expect(PasswordSettings.load(from: store).length == 30)
    }

    @Test func clampsStoredLengthOutOfBounds() {
        let store = makeStore()
        store.set(99, forKey: PasswordSettings.Key.lengthNumber)
        #expect(PasswordSettings.load(from: store).length == PasswordSettings.maxLength)
    }

    @Test func readsCharsetTogglesIncludingFalse() {
        let store = makeStore()
        store.set(false, forKey: PasswordSettings.Key.symState)
        store.set(false, forKey: PasswordSettings.Key.chiState)
        let values = PasswordSettings.load(from: store)
        #expect(values.symState == false)
        #expect(values.chiState == false)
        #expect(values.minState)          // clé absente → défaut à true
        #expect(values.hasCharset)
    }

    @Test func hasCharsetIsFalseWhenEverythingIsOff() {
        let store = makeStore()
        for key in [PasswordSettings.Key.minState, PasswordSettings.Key.majState,
                    PasswordSettings.Key.symState, PasswordSettings.Key.chiState] {
            store.set(false, forKey: key)
        }
        #expect(PasswordSettings.load(from: store).hasCharset == false)
    }
}
