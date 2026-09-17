//
//  thecodeTests.swift
//  thecodeTests
//
//  Created by Juliette Debono on 29/09/2025.
//

import Foundation
import Testing
import SwiftUI
import Testing
@testable import TheCode

struct PasswordUtilsTests {
    
    // MARK: - generatePassword
    @Test
    func testGeneratePasswordAllOptions() async throws {
        var utils: PasswordUtils {
            let u = PasswordUtils()
            u.minState = true
            u.majState = true
            u.symState = true
            u.chiState = true
            u.longueur = 20
            return u
        }
        
        let result = utils.generatePassword(input: "siteclef")

        #expect(result.code.count == 20)
        // Vecteur de référence : doit être identique à la sortie JS de
        // l'extension. Si ce test casse, l'algo Swift a divergé.
        #expect(result.code == "u8YfpdVdK*#Bpy6(9f*5")

        #expect(result.label == "Très Forte")
        #expect(result.bits > 0)
        
        // Vérifie qu’au moins un char de chaque groupe apparaît
        let groups = [
            "portezcviuxwhskyajgblndqfm",
            "THEQUICKBROWNFXJMPSVLAZYDG",
            "@#&!)-%;<:*$+=/?>(",
            "567438921"
        ]
        
        for g in groups {
            #expect(result.code.contains(where: { g.contains($0) }))
        }
    }
    
    // MARK: - buildCharset
    @Test
    func testBuildCharset() {
        var utils1: PasswordUtils {
            let u = PasswordUtils()
            u.minState = true
            u.majState = true
            u.symState = true
            u.chiState = true
            u.longueur = 20
            return u
        }
        
        let all = utils1.buildCharset()
        #expect(all == [
            "portezcviuxwhskyajgblndqfm",
            "THEQUICKBROWNFXJMPSVLAZYDG",
            "@#&!)-%;<:*$+=/?>(",
            "567438921"
        ])
        
        var utils2: PasswordUtils {
            let u = PasswordUtils()
            u.minState = true
            u.majState = false
            u.symState = true
            u.chiState = false
            u.longueur = 20
            return u
        }
        let some = utils2.buildCharset()
        #expect(some == [
            "portezcviuxwhskyajgblndqfm",
            "@#&!)-%;<:*$+=/?>("
        ])
        
        var utils3: PasswordUtils {
            let u = PasswordUtils()
            u.minState = false
            u.majState = false
            u.symState = false
            u.chiState = false
            u.longueur = 20
            return u
        }
        let none = utils3.buildCharset()
        #expect(none.isEmpty)
    }
    
    // MARK: - calculateEntropyBits
    @Test
    func testCalculateEntropyBits() {
        var utils: PasswordUtils {
            let u = PasswordUtils()
            u.minState = true
            u.majState = true
            u.symState = true
            u.chiState = true
            u.longueur = 20
            return u
        }

        let totalBase = [
            "portezcviuxwhskyajgblndqfm",
            "THEQUICKBROWNFXJMPSVLAZYDG",
            "@#&!)-%;<:*$+=/?>(",
            "567438921"
        ]

        #expect(utils.calculateEntropyBits(charsetGroups: totalBase, length: 20) == 126)
        #expect(utils.calculateEntropyBits(charsetGroups: totalBase, length: 10) == 63)
    }
    
    // MARK: - getSecurityLevel
    @Test
    func testGetSecurityLevel() {
        var utils: PasswordUtils {
            let u = PasswordUtils()
            u.minState = true
            u.majState = true
            u.symState = true
            u.chiState = true
            u.longueur = 20
            return u
        }
        // On ne compare plus les couleurs (Color hex ≠ Color.red brut),
        // seulement le label — c'est ce qui définit la classification.
        #expect(utils.getSecurityLevel(bits: 126).label == "Très Forte")
        #expect(utils.getSecurityLevel(bits: 63).label  == "Très Faible")
        #expect(utils.getSecurityLevel(bits: 0).label   == "Aucune")
    }
    
    // MARK: - convertToBase
    @Test
    func testConvertToBase() {
        let utils = PasswordUtils()

        #expect(utils.convertToBase(BInt(1), charsetGroups: ["abc"]) == "b")
        #expect(utils.convertToBase(BInt(0), charsetGroups: ["abc"]) == "a")
        #expect(utils.convertToBase(BInt(2), charsetGroups: ["01"]) == "00")
    }
    
    // MARK: - applyCharsetReplacement
    @Test
    func testApplyCharsetReplacement() throws {
        let utils = PasswordUtils()
        let seed = BInt(123456789)
        let groups = ["abc", "XYZ", "123"]
        let password = String(repeating: "a", count: 9)
        
        // Utiliser try pour appeler la fonction qui peut throw
        let result = try utils.applyCharsetReplacement(
            seed: seed,
            password: password,
            charsetGroups: groups
        )
        
        #expect(result.count == 9)
        
        for g in groups {
            #expect(result.contains { g.contains($0) })
        }
    }
    
    @Test
    func testApplyCharsetReplacementTooShort() {
        var utils: PasswordUtils {
            let u = PasswordUtils()
            u.minState = true
            u.majState = true
            u.symState = true
            u.chiState = true
            u.longueur = 20
            return u
        }
        let seed = BInt(1)
        let groups = ["abc", "XYZ", "123"]
        let password = "ab"
        
        #expect(throws: PasswordError.passwordTooShort(min: groups.count)) {
                _ = try utils.applyCharsetReplacement(
                    seed: seed,
                    password: password,
                    charsetGroups: groups
                )
            }
    }
    
    // MARK: - getUniquePosition
    @Test
    func testGetUniquePosition() {
        
        var utils: PasswordUtils {
            let u = PasswordUtils()
            u.minState = true
            u.majState = true
            u.symState = true
            u.chiState = true
            u.longueur = 20
            return u
        }
        let pos = utils.getUniquePosition(
            seed: BInt(5),
            used: [0, 1, 2],
            length: 5
        )
        
        #expect(pos >= 0 && pos < 5)
        #expect(![0, 1, 2].contains(pos))
        
        let pos2 = utils.getUniquePosition(
            seed: BInt(3),
            used: [0, 1, 2, 3],
            length: 5
        )
        
        #expect(pos2 == 4)
    }
    
    // MARK: - hashToBigInt
    @Test
    func testHashToBigInt() async throws {
        var utils: PasswordUtils {
            let u = PasswordUtils()
            u.minState = true
            u.majState = true
            u.symState = true
            u.chiState = true
            u.longueur = 20
            return u
        }
        let input = "test"
        let expectedHex =
        "9f86d081884c7d659a2feaa0c55ad015" +
        "a3bf4f1b2b0b822cd15d6c15b0f00a08"
        
        let expectedBigInt = BInt(expectedHex, radix: 16)
        
        let result = utils.hashToBInt(input)
        
        #expect(result == expectedBigInt)
        
        let h1 = utils.hashToBInt("hello")
        let h2 = utils.hashToBInt("world")
        #expect(h1 != h2)
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
