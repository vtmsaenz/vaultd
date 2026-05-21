//
//  Models.swift
//  vaultd
//
//  SwiftData models — all properties have defaults or are optional for CloudKit compatibility.
//

import SwiftData
import Foundation

// MARK: - VaultItem

@Model
final class VaultItem {
    var id: UUID = UUID()
    var name: String = ""
    var itemDescription: String = ""
    var category: String = ""
    var locationNote: String = ""
    var qrCodeID: String = UUID().uuidString
    var hasNFCTag: Bool = false
    var photoData: Data? = nil
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    /// The box this item lives in. Nil = unassigned.
    var box: StorageBox? = nil

    init(
        name: String = "",
        itemDescription: String = "",
        category: String = "",
        locationNote: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.itemDescription = itemDescription
        self.category = category
        self.locationNote = locationNote
        self.qrCodeID = UUID().uuidString
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - StorageBox

@Model
final class StorageBox: Hashable {
    static func == (lhs: StorageBox, rhs: StorageBox) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var id: UUID = UUID()
    /// Human-readable number, auto-assigned starting at 1. Write this on the physical box.
    var boxNumber: Int = 0
    var name: String = ""
    var boxDescription: String = ""
    var location: String = ""
    /// Encoded in both the QR code and NFC tag: "VAULTD-BOX-001-<uuid>"
    var qrCodeID: String = ""
    /// True once an NFC sticker has been successfully written for this box.
    var hasNFCTag: Bool = false
    var createdAt: Date = Date()

    /// All items stored in this box.
    @Relationship(deleteRule: .nullify, inverse: \VaultItem.box)
    var items: [VaultItem] = []

    init(
        boxNumber: Int,
        name: String = "",
        boxDescription: String = "",
        location: String = ""
    ) {
        self.id = UUID()
        self.boxNumber = boxNumber
        self.name = name
        self.boxDescription = boxDescription
        self.location = location
        let padded = String(format: "%03d", boxNumber)
        self.qrCodeID = "VAULTD-BOX-\(padded)-\(UUID().uuidString)"
        self.createdAt = Date()
    }
}

// MARK: - MemoryEntry

@Model
final class MemoryEntry {
    var id: UUID = UUID()
    var itemName: String = ""
    var story: String = ""
    var emotion: String = ""
    var photoData: Data? = nil
    var releasedAt: Date = Date()
    var createdAt: Date = Date()

    init(
        itemName: String = "",
        story: String = "",
        emotion: String = ""
    ) {
        self.id = UUID()
        self.itemName = itemName
        self.story = story
        self.emotion = emotion
        self.releasedAt = Date()
        self.createdAt = Date()
    }
}
