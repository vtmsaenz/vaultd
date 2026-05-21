//
//  ImagePickerView.swift
//  vaultd
//
//  Reusable camera + photo library capture components.
//  - CameraPicker: wraps UIImagePickerController for live camera
//  - PhotoCaptureButton: drop-in button that offers Camera / Library / Remove
//

import SwiftUI
import PhotosUI
import UIKit

// MARK: - Camera picker (UIImagePickerController wrapper)

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject,
                              UIImagePickerControllerDelegate,
                              UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Photo capture button

/// Drop-in button that handles the full camera / library / remove flow.
/// Bind `imageData` to a `Data?` property on your model.
struct PhotoCaptureButton: View {
    @Binding var imageData: Data?

    @State private var showSourceMenu   = false
    @State private var showCamera       = false
    @State private var showLibrary      = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var capturedImage: UIImage? = nil

    var body: some View {
        VStack(spacing: 12) {
            // Preview — show image if one is attached
            if let data = imageData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(alignment: .topTrailing) {
                        Button {
                            imageData = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.vaultDark.opacity(0.7))
                                .padding(8)
                        }
                    }
            } else {
                // Placeholder tap target
                Button {
                    showSourceMenu = true
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(Color.vaultOrange)
                        Text("Add Photo")
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.vaultOrange)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .background(Color.vaultOrange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.vaultOrange.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                    )
                }
                .buttonStyle(.plain)
            }

            // Change button if photo already set
            if imageData != nil {
                Button {
                    showSourceMenu = true
                } label: {
                    Label("Change Photo", systemImage: "arrow.triangle.2.circlepath.camera")
                        .font(.subheadline)
                        .foregroundStyle(Color.vaultOrange)
                }
            }
        }
        // Source chooser
        .confirmationDialog("Add Photo", isPresented: $showSourceMenu, titleVisibility: .visible) {
            Button("Take Photo") { showCamera  = true }
            Button("Choose from Library") { showLibrary = true }
            if imageData != nil {
                Button("Remove Photo", role: .destructive) { imageData = nil }
            }
        }
        // Camera sheet
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(image: $capturedImage)
                .ignoresSafeArea()
        }
        // Library picker
        .photosPicker(isPresented: $showLibrary,
                      selection: $selectedPhotoItem,
                      matching: .images)
        // Handle camera result
        .onChange(of: capturedImage) { _, newImage in
            guard let ui = newImage else { return }
            imageData = ui.jpegData(compressionQuality: 0.8)
            capturedImage = nil
        }
        // Handle library result
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    imageData = data
                }
                selectedPhotoItem = nil
            }
        }
    }
}
