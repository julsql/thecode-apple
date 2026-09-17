//
//  TheCodeApp.swift
//  thecode-extension-ios
//
//  Created by Juliette Debono on 27/09/2025.
//


import SwiftUI

let appGroupID = "group.fr.julsql.thecode.params"

@main
struct TheCodeApp: App {
    @AppStorage("darkMode", store: UserDefaults(suiteName: appGroupID)) var darkMode: String = "SYSTEM"

    init() {
        initializeSharedDefaults()
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .preferredColorScheme(preferredScheme)
        }
    }

    private var preferredScheme: ColorScheme? {
        switch darkMode {
        case "DARK":  return .dark
        case "LIGHT": return .light
        default:      return nil
        }
    }
}

func initializeSharedDefaults() {
    guard let defaults = UserDefaults(suiteName: appGroupID) else {
        print("❌ Impossible d'ouvrir UserDefaults avec \(appGroupID)")
        return
    }

    if defaults.string(forKey: "encodingKey") == nil {
        defaults.set("", forKey: "encodingKey")
    }
    if defaults.object(forKey: "lengthNumber") == nil {
        defaults.set(PasswordSettings.defaultLength, forKey: "lengthNumber")
    }
    if defaults.object(forKey: "minState") == nil {
        defaults.set(true, forKey: "minState")
    }
    if defaults.object(forKey: "majState") == nil {
        defaults.set(true, forKey: "majState")
    }
    if defaults.object(forKey: "symState") == nil {
        defaults.set(true, forKey: "symState")
    }
    if defaults.object(forKey: "chiState") == nil {
        defaults.set(true, forKey: "chiState")
    }

    defaults.synchronize()
}
