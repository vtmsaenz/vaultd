//
//  StorageVaultView.swift
//  vaultd
//
//  Storage Vault: boxes contain items.
//  • Open a box → see everything inside it
//  • Add an item → choose which box it goes in
//  • Reassign an item to a different box from its detail screen
//

import SwiftUI
import SwiftData
import UIKit

// MARK: - Main tab view

struct StorageVaultView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(NFCManager.self)  private var nfcManager
    @Query(sort: \StorageBox.boxNumber, order: .forward)  private var boxes: [StorageBox]
    @Query(sort: \VaultItem.updatedAt,  order: .reverse)  private var allItems: [VaultItem]

    @State private var segment: Segment = .boxes
    @State private var searchText        = ""
    @State private var showingAddBox     = false
    @State private var showingAddItem    = false
    @State private var navigationPath    = NavigationPath()

    enum Segment: String, CaseIterable {
        case boxes = "Boxes", items = "Items"
    }

    var filteredBoxes: [StorageBox] {
        guard !searchText.isEmpty else { return boxes }
        return boxes.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.location.localizedCaseInsensitiveContains(searchText) ||
            String($0.boxNumber).contains(searchText)
        }
    }

    var filteredItems: [VaultItem] {
        guard !searchText.isEmpty else { return allItems }
        return allItems.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.category.localizedCaseInsensitiveContains(searchText) ||
            $0.locationNote.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    Picker("View", selection: $segment) {
                        ForEach(Segment.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal).padding(.vertical, 10)
                    .background(Color.vaultWarm)

                    switch segment {
                    case .boxes: boxListView
                    case .items: itemListView
                    }
                }
                .navigationTitle("Storage Vault")
                .navigationBarTitleDisplayMode(.large)
                .searchable(text: $searchText,
                            prompt: segment == .boxes ? "Search boxes…" : "Search items…")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Image("digbyMascot")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 30)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { nfcManager.readTag() } label: {
                            Label("Scan NFC", systemImage: "wave.3.right.circle.fill")
                        }
                    }
                }
                .onChange(of: nfcManager.scannedPayload) { _, payload in
                    guard let payload,
                          let match = boxes.first(where: { $0.qrCodeID == payload }) else { return }
                    segment = .boxes
                    navigationPath.append(match)
                    nfcManager.scannedPayload = nil
                }
                .alert("NFC Error",
                       isPresented: .init(get: { nfcManager.errorMessage != nil },
                                         set: { if !$0 { nfcManager.errorMessage = nil } })) {
                    Button("OK", role: .cancel) { nfcManager.errorMessage = nil }
                } message: { Text(nfcManager.errorMessage ?? "") }

                // FAB
                Button {
                    segment == .boxes ? (showingAddBox = true) : (showingAddItem = true)
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.bold()).foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.vaultOrange)
                        .clipShape(Circle())
                        .shadow(color: .vaultOrange.opacity(0.4), radius: 8, y: 4)
                }
                .padding(.trailing, 20).padding(.bottom, 24)
            }
            .background(Color.vaultWarm.ignoresSafeArea())
            .navigationDestination(for: StorageBox.self) { BoxDetailView(box: $0) }
            .navigationDestination(for: VaultItem.self)  { ItemDetailView(item: $0) }
        }
        .sheet(isPresented: $showingAddBox) {
            AddBoxView(nextNumber: (boxes.map(\.boxNumber).max() ?? 0) + 1)
        }
        .sheet(isPresented: $showingAddItem) {
            AddItemView(preselectedBox: nil)
        }
    }

    // MARK: Boxes list

    private var boxListView: some View {
        Group {
            if filteredBoxes.isEmpty {
                emptyState(emoji: "📦",
                           title: "No boxes yet",
                           subtitle: "Tap + to create your first box.\nWrite its number on the physical box.")
            } else {
                List(filteredBoxes) { box in
                    NavigationLink(value: box) { BoxRowView(box: box) }
                        .listRowBackground(Color.white)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Color.vaultWarm)
            }
        }
    }

    // MARK: All-items list

    private var itemListView: some View {
        Group {
            if filteredItems.isEmpty {
                emptyState(emoji: "🏷️",
                           title: "No items yet",
                           subtitle: "Tap + to add an item and put it in a box.")
            } else {
                List(filteredItems) { item in
                    NavigationLink(value: item) { ItemRowView(item: item) }
                        .listRowBackground(Color.white)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Color.vaultWarm)
            }
        }
    }

    private func emptyState(emoji: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            Image("digbyMascot")
                .resizable()
                .scaledToFit()
                .frame(height: 120)
            Text(title).font(.title3.bold()).foregroundStyle(Color.vaultDark)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.vaultWarm)
    }
}

// MARK: - Box row

struct BoxRowView: View {
    let box: StorageBox
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color.vaultOrange)
                    .frame(width: 44, height: 44)
                Text(String(format: "%03d", box.boxNumber))
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(box.name.isEmpty ? "Box \(box.boxNumber)" : box.name)
                    .font(.headline).foregroundStyle(Color.vaultDark)
                HStack(spacing: 8) {
                    // Item count
                    Label("\(box.items.count) item\(box.items.count == 1 ? "" : "s")",
                          systemImage: "shippingbox")
                        .font(.caption).foregroundStyle(.secondary)
                    if !box.location.isEmpty {
                        Label(box.location, systemImage: "location.fill")
                            .font(.caption).foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
            HStack(spacing: 6) {
                if box.hasNFCTag {
                    Image(systemName: "wave.3.right").font(.caption).foregroundStyle(Color.vaultOrange)
                }
                Image(systemName: "qrcode").foregroundStyle(Color.vaultOrange.opacity(0.5))
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Box detail  (shows items inside)

struct BoxDetailView: View {
    @Environment(NFCManager.self) private var nfcManager
    @Environment(\.modelContext)  private var modelContext
    @Bindable var box: StorageBox

    @State private var showQRFullscreen  = false
    @State private var showingAddItem    = false
    @State private var nfcWriteSuccess   = false
    @State private var showNFCAlert      = false

    var sortedItems: [VaultItem] {
        box.items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // ── QR + number ───────────────────────────────────────────
                VStack(spacing: 12) {
                    QRCodeImageView(content: box.qrCodeID, size: 180)
                        .padding(12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(spacing: 2) {
                        Text("BOX").font(.caption.bold()).foregroundStyle(.secondary).tracking(4)
                        Text(String(format: "%03d", box.boxNumber))
                            .font(.system(size: 44, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.vaultOrange)
                    }
                    Text("Write this number on your physical box")
                        .font(.caption).foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        Button { showQRFullscreen = true } label: {
                            Label("Print Label", systemImage: "arrow.up.left.and.arrow.down.right")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(Color.vaultOrange)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)

                        Button {
                            nfcManager.writeTag(payload: box.qrCodeID) { success in
                                nfcWriteSuccess = success
                                if success { box.hasNFCTag = true }
                                showNFCAlert = true
                            }
                        } label: {
                            Label(box.hasNFCTag ? "Re-write NFC" : "Write NFC",
                                  systemImage: "wave.3.right")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(Color.vaultOrange.opacity(0.12))
                                .foregroundStyle(Color.vaultOrange)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.06), radius: 8)
                .padding(.horizontal)

                // ── Items in this box ─────────────────────────────────────
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Items")
                            .font(.headline).foregroundStyle(Color.vaultDark)
                        Text("\(box.items.count)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.vaultOrange)
                            .clipShape(Capsule())
                        Spacer()
                        Button {
                            showingAddItem = true
                        } label: {
                            Label("Add Item", systemImage: "plus")
                                .font(.subheadline.bold())
                                .foregroundStyle(Color.vaultOrange)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)

                    Divider().padding(.horizontal)

                    if sortedItems.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "shippingbox")
                                .font(.system(size: 36))
                                .foregroundStyle(Color.vaultOrange.opacity(0.4))
                            Text("Nothing in this box yet")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Button("Add First Item") { showingAddItem = true }
                                .buttonStyle(.vaultPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(32)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(sortedItems) { item in
                                NavigationLink(value: item) {
                                    BoxItemRow(item: item)
                                }
                                .buttonStyle(.plain)
                                if item.id != sortedItems.last?.id {
                                    Divider().padding(.leading, 60)
                                }
                            }
                        }
                        .padding(.bottom, 8)
                    }
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 6)
                .padding(.horizontal)

                // ── Info ──────────────────────────────────────────────────
                if !box.location.isEmpty || !box.boxDescription.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        if !box.location.isEmpty {
                            infoRow("Location", value: box.location, icon: "location.fill")
                        }
                        if !box.boxDescription.isEmpty {
                            infoRow("Notes", value: box.boxDescription, icon: "note.text")
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.05), radius: 6)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(box.name.isEmpty ? "Box \(box.boxNumber)" : box.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.vaultWarm.ignoresSafeArea())
        .sheet(isPresented: $showQRFullscreen) { BoxQRPrintView(box: box) }
        .sheet(isPresented: $showingAddItem)   { AddItemView(preselectedBox: box) }
        .alert(nfcWriteSuccess ? "NFC Tag Programmed!" : "Write Failed",
               isPresented: $showNFCAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(nfcWriteSuccess
                 ? "Stick the NFC sticker on Box \(String(format: "%03d", box.boxNumber)). Scanning it will open this box."
                 : (nfcManager.errorMessage ?? "Something went wrong. Try again."))
        }
    }

    private func infoRow(_ label: String, value: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(Color.vaultOrange).frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.body).foregroundStyle(Color.vaultDark)
            }
        }
    }
}

// MARK: - Compact item row inside a box

struct BoxItemRow: View {
    let item: VaultItem
    var body: some View {
        HStack(spacing: 12) {
            // Photo thumbnail or category icon
            if let data = item.photoData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable().scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.vaultOrange.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: categoryIcon(for: item.category))
                        .foregroundStyle(Color.vaultOrange)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name.isEmpty ? "Unnamed Item" : item.name)
                    .font(.subheadline.bold()).foregroundStyle(Color.vaultDark)
                if !item.category.isEmpty {
                    Text(item.category)
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption).foregroundStyle(Color.secondary.opacity(0.5))
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }
}

// MARK: - Item row (all-items list)

struct ItemRowView: View {
    let item: VaultItem
    var body: some View {
        HStack(spacing: 12) {
            if let data = item.photoData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable().scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.vaultOrange.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: categoryIcon(for: item.category))
                        .foregroundStyle(Color.vaultOrange)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name.isEmpty ? "Unnamed Item" : item.name)
                    .font(.headline).foregroundStyle(Color.vaultDark)
                // Show which box this item is in
                if let box = item.box {
                    Label("Box \(String(format: "%03d", box.boxNumber))\(box.name.isEmpty ? "" : " · \(box.name)")",
                          systemImage: "archivebox.fill")
                        .font(.caption).foregroundStyle(Color.vaultOrange)
                } else {
                    Text("Not assigned to a box")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if item.hasNFCTag {
                Image(systemName: "wave.3.right").font(.caption).foregroundStyle(Color.vaultOrange)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Item detail

struct ItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: VaultItem
    @Query(sort: \StorageBox.boxNumber) private var allBoxes: [StorageBox]

    @State private var showingBoxPicker = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // Photo
                if let data = item.photoData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable().scaledToFill()
                        .frame(maxWidth: .infinity).frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.08), radius: 8)
                        .padding(.horizontal)
                }

                // Box assignment card
                VStack(alignment: .leading, spacing: 10) {
                    Text("Stored In").font(.caption).foregroundStyle(.secondary)

                    if let box = item.box {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8).fill(Color.vaultOrange)
                                    .frame(width: 40, height: 40)
                                Text(String(format: "%03d", box.boxNumber))
                                    .font(.system(.caption, design: .monospaced).bold())
                                    .foregroundStyle(.white)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(box.name.isEmpty ? "Box \(box.boxNumber)" : box.name)
                                    .font(.headline).foregroundStyle(Color.vaultDark)
                                if !box.location.isEmpty {
                                    Text(box.location).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button("Change") { showingBoxPicker = true }
                                .font(.subheadline).foregroundStyle(Color.vaultOrange)
                        }
                    } else {
                        HStack {
                            Image(systemName: "archivebox")
                                .foregroundStyle(.secondary)
                            Text("Not in any box")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Spacer()
                            Button("Assign to Box") { showingBoxPicker = true }
                                .font(.subheadline.bold()).foregroundStyle(Color.vaultOrange)
                        }
                    }
                }
                .padding()
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.06), radius: 8)
                .padding(.horizontal)

                // QR code
                VStack(spacing: 8) {
                    QRCodeImageView(content: item.qrCodeID, size: 160)
                        .padding(12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Text("Scan to look up this item")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.06), radius: 8)
                .padding(.horizontal)

                // Details
                VStack(alignment: .leading, spacing: 12) {
                    if !item.itemDescription.isEmpty {
                        detailRow("Description", value: item.itemDescription)
                    }
                    if !item.category.isEmpty {
                        detailRow("Category", value: item.category)
                    }
                    if !item.locationNote.isEmpty {
                        detailRow("Location note", value: item.locationNote)
                    }
                    detailRow("Added", value: item.createdAt.formatted(date: .abbreviated, time: .omitted))
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 6)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle(item.name.isEmpty ? "Item" : item.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.vaultWarm.ignoresSafeArea())
        .sheet(isPresented: $showingBoxPicker) {
            BoxPickerView(selectedBox: $item.box)
        }
    }

    private func detailRow(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.body).foregroundStyle(Color.vaultDark)
        }
    }
}

// MARK: - Box picker sheet  (assign / reassign an item to a box)

struct BoxPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedBox: StorageBox?
    @Query(sort: \StorageBox.boxNumber) private var boxes: [StorageBox]

    var body: some View {
        NavigationStack {
            List {
                // "No box" option
                Button {
                    selectedBox = nil
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "archivebox")
                            .foregroundStyle(.secondary).frame(width: 32)
                        Text("No box — unassigned")
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedBox == nil {
                            Image(systemName: "checkmark").foregroundStyle(Color.vaultOrange)
                        }
                    }
                }
                .listRowBackground(Color.white)

                ForEach(boxes) { box in
                    Button {
                        selectedBox = box
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8).fill(Color.vaultOrange)
                                    .frame(width: 32, height: 32)
                                Text(String(format: "%03d", box.boxNumber))
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(box.name.isEmpty ? "Box \(box.boxNumber)" : box.name)
                                    .font(.body).foregroundStyle(.primary)
                                if !box.location.isEmpty {
                                    Text(box.location).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if selectedBox?.id == box.id {
                                Image(systemName: "checkmark").foregroundStyle(Color.vaultOrange)
                            }
                        }
                    }
                    .listRowBackground(Color.white)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.vaultWarm)
            .navigationTitle("Choose a Box")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Add item sheet

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss
    @Query(sort: \StorageBox.boxNumber) private var boxes: [StorageBox]

    /// Pass a box to pre-select it (e.g. when tapping "Add Item" inside a box)
    var preselectedBox: StorageBox?

    @State private var name         = ""
    @State private var description  = ""
    @State private var category     = ""
    @State private var location     = ""
    @State private var photoData: Data? = nil
    @State private var selectedBox: StorageBox? = nil

    let categories = ["Electronics","Clothing","Books","Kitchen","Tools","Other"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Photo") {
                    PhotoCaptureButton(imageData: $photoData)
                        .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                }

                Section("Item Details") {
                    TextField("Name", text: $name)
                    TextField("Description (optional)", text: $description)
                    TextField("Location note (e.g. left side)", text: $location)
                }

                Section("Category") {
                    Picker("Category", selection: $category) {
                        Text("None").tag("")
                        ForEach(categories, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    if boxes.isEmpty {
                        Text("No boxes yet — create a box first.")
                            .foregroundStyle(.secondary).font(.subheadline)
                    } else {
                        Picker("Assign to box", selection: $selectedBox) {
                            Text("None").tag(Optional<StorageBox>.none)
                            ForEach(boxes) { box in
                                Text(box.name.isEmpty
                                     ? "Box \(String(format: "%03d", box.boxNumber))"
                                     : "Box \(String(format: "%03d", box.boxNumber)) · \(box.name)")
                                    .tag(Optional(box))
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color.vaultOrange)
                    }
                } header: {
                    Text("Box")
                } footer: {
                    if selectedBox != nil {
                        Text("This item will appear inside the selected box.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.vaultWarm)
            .navigationTitle("New Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.semibold).tint(Color.vaultOrange)
                }
            }
            .onAppear { selectedBox = preselectedBox }
        }
    }

    private func save() {
        let item = VaultItem(
            name:            name.trimmingCharacters(in: .whitespaces),
            itemDescription: description,
            category:        category,
            locationNote:    location
        )
        item.photoData = photoData
        item.box       = selectedBox
        modelContext.insert(item)
        dismiss()
    }
}

// MARK: - Add box sheet

struct AddBoxView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss

    let nextNumber: Int
    @State private var name        = ""
    @State private var description = ""
    @State private var location    = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Box Number")
                        Spacer()
                        Text(String(format: "%03d", nextNumber))
                            .font(.system(.body, design: .monospaced).bold())
                            .foregroundStyle(Color.vaultOrange)
                    }
                } footer: {
                    Text("Auto-assigned and embedded in the QR code + NFC tag. Write it on your physical box.")
                }

                Section("Label (optional)") {
                    TextField("e.g. Winter Clothes, Kitchen Gear", text: $name)
                    TextField("Location (e.g. Garage Shelf 2)", text: $location)
                    TextField("Notes", text: $description)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.vaultWarm)
            .navigationTitle("New Box")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold).tint(Color.vaultOrange)
                }
            }
        }
    }

    private func save() {
        let box = StorageBox(
            boxNumber:      nextNumber,
            name:           name.trimmingCharacters(in: .whitespaces),
            boxDescription: description,
            location:       location.trimmingCharacters(in: .whitespaces)
        )
        modelContext.insert(box)
        dismiss()
    }
}

// MARK: - Full-screen QR print view

struct BoxQRPrintView: View {
    let box: StorageBox
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                VStack(spacing: 16) {
                    QRCodeImageView(content: box.qrCodeID, size: 260)
                    Divider().padding(.horizontal, 40)
                    VStack(spacing: 4) {
                        Text("BOX").font(.caption.bold()).foregroundStyle(.secondary).tracking(6)
                        Text(String(format: "%03d", box.boxNumber))
                            .font(.system(size: 72, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.vaultDark)
                        if !box.name.isEmpty {
                            Text(box.name).font(.title3).foregroundStyle(.secondary)
                        }
                        if !box.location.isEmpty {
                            Text(box.location).font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                    Text("vaultd · Store it. Find it. Remember it.")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
                .padding(32)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.08), radius: 16)
                .padding(.horizontal, 32)
                Spacer()
                Text("Take a screenshot to print this label")
                    .font(.footnote).foregroundStyle(.secondary).padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.vaultWarm.ignoresSafeArea())
            .navigationTitle("Print Label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

// MARK: - Shared helpers

func categoryIcon(for category: String) -> String {
    switch category.lowercased() {
    case "electronics": return "bolt.fill"
    case "clothing":    return "tshirt.fill"
    case "books":       return "books.vertical.fill"
    case "kitchen":     return "fork.knife"
    case "tools":       return "wrench.and.screwdriver.fill"
    default:            return "shippingbox.fill"
    }
}
