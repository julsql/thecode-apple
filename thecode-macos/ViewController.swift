//
//  ViewController.swift
//  thecode-macos
//
//  Created by Juliette Debono on 29/09/2025.
//

import Cocoa
import SwiftUI

class ViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        initializeSharedDefaults()

        let hostingView = NSHostingView(rootView: MainView())
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: view.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func initializeSharedDefaults() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }

        if defaults.string(forKey: "encodingKey") == nil { defaults.set("", forKey: "encodingKey") }
        if defaults.object(forKey: "lengthNumber") == nil {
            defaults.set(PasswordSettings.defaultLength, forKey: "lengthNumber")
        }
        if defaults.object(forKey: "minState") == nil { defaults.set(true, forKey: "minState") }
        if defaults.object(forKey: "majState") == nil { defaults.set(true, forKey: "majState") }
        if defaults.object(forKey: "symState") == nil { defaults.set(true, forKey: "symState") }
        if defaults.object(forKey: "chiState") == nil { defaults.set(true, forKey: "chiState") }
    }
}
