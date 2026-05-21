//
//  ContentView.swift
//  vaultd
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            StorageVaultView()
                .tabItem {
                    Label("Storage", systemImage: "archivebox.fill")
                }

            MemoryVaultView()
                .tabItem {
                    Label("Memories", systemImage: "heart.fill")
                }
        }
        .tint(.vaultOrange)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [VaultItem.self, StorageBox.self, MemoryEntry.self], inMemory: true)
}
