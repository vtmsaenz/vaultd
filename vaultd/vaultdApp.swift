//
//  vaultdApp.swift
//  vaultd
//

import SwiftUI
import SwiftData
import UIKit

@main
struct vaultdApp: App {
    @State private var nfcManager = NFCManager()

    init() {
        // iOS 26's liquid-glass nav bar ignores SwiftUI's toolbarBackground,
        // so we configure UIKit appearance directly — this takes full effect.
        let orange = UIColor(red: 1.0, green: 0.498, blue: 0.0, alpha: 1.0) // #ff7f00

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = orange
        appearance.titleTextAttributes        = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes   = [.foregroundColor: UIColor.white]

        UINavigationBar.appearance().standardAppearance   = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance    = appearance
        UINavigationBar.appearance().tintColor            = .white  // back button + bar items
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            VaultItem.self,
            StorageBox.self,
            MemoryEntry.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(nfcManager)
        }
        .modelContainer(sharedModelContainer)
    }
}
