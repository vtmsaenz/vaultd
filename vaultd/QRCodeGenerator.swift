//
//  QRCodeGenerator.swift
//  vaultd
//
//  Generates a UIImage QR code from any string using CoreImage.
//  No third-party dependencies needed.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

enum QRCodeGenerator {

    /// Returns a crisp UIImage QR code for the given string.
    /// - Parameter string: The payload to encode (e.g. "VAULTD-BOX-001-<uuid>")
    /// - Parameter size: Rendered pixel size (default 512 — good for printing)
    static func image(for string: String, size: CGFloat = 512) -> UIImage? {
        let context = CIContext()
        let filter  = CIFilter.qrCodeGenerator()

        filter.correctionLevel = "M"   // Medium error correction — good balance for print
        filter.message = Data(string.utf8)

        guard let outputImage = filter.outputImage else { return nil }

        // Scale up without blurring using nearest-neighbour transform
        let scale = size / outputImage.extent.width
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - SwiftUI wrapper

import SwiftUI

/// Drop-in SwiftUI view that renders a QR code for `content`.
struct QRCodeImageView: View {
    let content: String
    var size: CGFloat = 200

    var body: some View {
        if let uiImage = QRCodeGenerator.image(for: content, size: size * 3) {
            Image(uiImage: uiImage)
                .interpolation(.none)   // Keep pixels sharp — no smoothing
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            // Fallback placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: size, height: size)
                Image(systemName: "qrcode")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(Color.secondary)
            }
        }
    }
}
