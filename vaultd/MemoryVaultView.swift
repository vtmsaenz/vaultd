//
//  MemoryVaultView.swift
//  vaultd
//
//  The "Memory Vault" tab — preserve the stories of items you're letting go.
//

import SwiftUI
import SwiftData

struct MemoryVaultView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MemoryEntry.createdAt, order: .reverse) private var memories: [MemoryEntry]

    @State private var showingAddMemory = false

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if memories.isEmpty {
                        emptyStateView
                    } else {
                        memoryGridView
                    }
                }
                .navigationTitle("Memory Vault")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Image("digbyMascot")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 30)
                    }
                }

                // FAB
                Button {
                    showingAddMemory = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.vaultOrange)
                        .clipShape(Circle())
                        .shadow(color: .vaultOrange.opacity(0.4), radius: 8, y: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }
            .background(Color.vaultWarm.ignoresSafeArea())
        }
        .sheet(isPresented: $showingAddMemory) {
            AddMemoryView()
        }
    }

    // MARK: - Empty state

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image("digbyMascot")
                .resizable()
                .scaledToFit()
                .frame(height: 120)
            Text("No memories yet")
                .font(.title3.bold())
                .foregroundStyle(Color.vaultDark)
            Text("When you let go of something special,\nsave its story here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.vaultWarm)
    }

    // MARK: - Memory grid

    private var memoryGridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(memories) { memory in
                    NavigationLink(destination: MemoryDetailView(memory: memory)) {
                        MemoryCardView(memory: memory)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .background(Color.vaultWarm)
    }
}

// MARK: - Emotion helpers (shared)

func emotionEmoji(for emotion: String) -> String {
    switch emotion.lowercased() {
    case "happy":    return "😊"
    case "grateful": return "🙏"
    case "sad":      return "😢"
    case "nostalgic":return "🌅"
    case "relieved": return "😌"
    default:         return "💛"
    }
}

func emotionColor(for emotion: String) -> Color {
    switch emotion.lowercased() {
    case "happy":    return .yellow
    case "grateful": return .green
    case "sad":      return .blue
    case "nostalgic":return .purple
    case "relieved": return .mint
    default:         return .vaultOrange
    }
}

// MARK: - Memory Card

struct MemoryCardView: View {
    let memory: MemoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Photo thumbnail if available, otherwise emotion tile
            if let data = memory.photoData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(emotionColor(for: memory.emotion).opacity(0.15))
                        .frame(height: 90)
                    Text(emotionEmoji(for: memory.emotion))
                        .font(.system(size: 40))
                }
            }
            Text(memory.itemName.isEmpty ? "Untitled" : memory.itemName)
                .font(.headline)
                .foregroundStyle(Color.vaultDark)
                .lineLimit(1)
            if !memory.story.isEmpty {
                Text(memory.story)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Text(memory.createdAt.formatted(date: .abbreviated, time: .omitted))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }
}

// MARK: - Memory Detail

struct MemoryDetailView: View {
    let memory: MemoryEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Photo (if saved)
                if let data = memory.photoData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.08), radius: 8)
                        .padding(.horizontal)
                }

                // Emotion banner
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.vaultOrange.opacity(0.1))
                    VStack(spacing: 6) {
                        Text(emotionEmoji(for: memory.emotion))
                            .font(.system(size: 56))
                        if !memory.emotion.isEmpty {
                            Text(memory.emotion.capitalized)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(24)
                }
                .padding(.horizontal)

                // Story
                if !memory.story.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Story")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(memory.story)
                            .font(.body)
                            .foregroundStyle(Color.vaultDark)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.05), radius: 6)
                    .padding(.horizontal)
                }

                // Meta
                VStack(alignment: .leading, spacing: 8) {
                    metaRow(label: "Released", value: memory.releasedAt.formatted(date: .long, time: .omitted))
                    metaRow(label: "Saved", value: memory.createdAt.formatted(date: .long, time: .omitted))
                }
                .padding()
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 6)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle(memory.itemName.isEmpty ? "Memory" : memory.itemName)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.vaultWarm.ignoresSafeArea())
    }

    private func metaRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundStyle(Color.vaultDark)
        }
    }
}

// MARK: - Add Memory Sheet

struct AddMemoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var itemName = ""
    @State private var story = ""
    @State private var emotion = ""
    @State private var releasedAt = Date()
    @State private var photoData: Data? = nil

    let emotions = ["Happy", "Grateful", "Sad", "Nostalgic", "Relieved", "Other"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Photo") {
                    PhotoCaptureButton(imageData: $photoData)
                        .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                }
                Section("What are you letting go?") {
                    TextField("Item name", text: $itemName)
                }
                Section("How do you feel?") {
                    Picker("Emotion", selection: $emotion) {
                        Text("None").tag("")
                        ForEach(emotions, id: \.self) { e in
                            Text(e).tag(e)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Section("Its story") {
                    TextEditor(text: $story)
                        .frame(minHeight: 100)
                }
                Section {
                    DatePicker("Released on", selection: $releasedAt, displayedComponents: .date)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.vaultWarm)
            .navigationTitle("New Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(itemName.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.semibold)
                        .tint(Color.vaultOrange)
                }
            }
        }
    }

    private func save() {
        let entry = MemoryEntry(
            itemName: itemName.trimmingCharacters(in: .whitespaces),
            story: story,
            emotion: emotion
        )
        entry.releasedAt = releasedAt
        entry.photoData  = photoData
        modelContext.insert(entry)
        dismiss()
    }
}
