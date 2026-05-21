//
//  NFCManager.swift
//  vaultd
//
//  Handles NFC tag writing (programming a sticker) and reading (scanning to find a box).
//  Both operations encode/decode the same payload used by the QR code: "VAULTD-BOX-001-<uuid>"
//
//  Usage:
//    Write:  nfcManager.writeTag(payload: box.qrCodeID) { success in ... }
//    Read:   nfcManager.readTag()  →  observe nfcManager.scannedPayload
//

import CoreNFC
import Observation

// NFC is unavailable in Simulator — all public methods are no-ops there.

@Observable
final class NFCManager: NSObject {

    // MARK: - Published state

    /// Set after a successful read. Observe this to navigate to the matching box.
    var scannedPayload: String? = nil
    /// Set when something goes wrong so the UI can show an alert.
    var errorMessage: String? = nil
    /// True while a session is active.
    var isActive: Bool = false

    // MARK: - Private

    private enum Mode {
        case read
        case write(payload: String, completion: (Bool) -> Void)
    }

    private var session: NFCNDEFReaderSession?
    private var mode: Mode = .read

    // MARK: - Public API

    /// Start a read session. When a valid Vaultd tag is found `scannedPayload` is set.
    func readTag() {
        #if targetEnvironment(simulator)
        errorMessage = "NFC is not available in the Simulator. Use a real device."
        #else
        guard NFCNDEFReaderSession.readingAvailable else {
            errorMessage = "NFC is not supported on this device."
            return
        }
        mode = .read
        startSession(alert: "Hold your iPhone near the Vaultd NFC tag on the box.")
        #endif
    }

    /// Start a write session. The `payload` (box.qrCodeID) is written as an NDEF Text record.
    /// `completion` is called on the main thread with `true` on success.
    func writeTag(payload: String, completion: @escaping (Bool) -> Void) {
        #if targetEnvironment(simulator)
        errorMessage = "NFC is not available in the Simulator. Use a real device."
        completion(false)
        #else
        guard NFCNDEFReaderSession.readingAvailable else {
            errorMessage = "NFC is not supported on this device."
            completion(false)
            return
        }
        mode = .write(payload: payload, completion: completion)
        startSession(alert: "Hold your iPhone near a blank NFC sticker to program it.")
        #endif
    }

    // MARK: - Private helpers

    private func startSession(alert: String) {
        session = NFCNDEFReaderSession(delegate: self, queue: .main, invalidateAfterFirstRead: false)
        session?.alertMessage = alert
        session?.begin()
        isActive = true
    }

    /// Build an NDEF Text record (type "T", language "en", UTF-8).
    private func makeTextRecord(_ text: String) -> NFCNDEFPayload {
        let lang     = Data("en".utf8)
        let textData = Data(text.utf8)
        // Status byte: bit7=0 (UTF-8), bits5-0 = language length
        var payload  = Data([UInt8(lang.count)])
        payload.append(lang)
        payload.append(textData)
        return NFCNDEFPayload(
            format:     .nfcWellKnown,
            type:       Data("T".utf8),
            identifier: Data(),
            payload:    payload
        )
    }

    /// Extract the text string from an NDEF Text record payload.
    private func extractText(from payload: NFCNDEFPayload) -> String? {
        guard payload.typeNameFormat == .nfcWellKnown,
              let type = String(data: payload.type, encoding: .utf8), type == "T",
              payload.payload.count > 1 else { return nil }
        let statusByte  = payload.payload[0]
        let langLength  = Int(statusByte & 0x3F)
        let startIndex  = 1 + langLength
        guard payload.payload.count > startIndex else { return nil }
        let textData    = payload.payload.subdata(in: startIndex ..< payload.payload.count)
        return String(data: textData, encoding: .utf8)
    }
}

// MARK: - NFCNDEFReaderSessionDelegate

extension NFCManager: NFCNDEFReaderSessionDelegate {

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        isActive = false
        let nfcError = error as? NFCReaderError
        // Ignore expected cancellations
        if nfcError?.code == .readerSessionInvalidationErrorUserCanceled ||
           nfcError?.code == .readerSessionInvalidationErrorFirstNDEFTagRead { return }
        errorMessage = error.localizedDescription
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // Not called when invalidateAfterFirstRead = false — handled in didDetectTags.
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let tag = tags.first else { return }

        session.connect(to: tag) { [weak self] error in
            guard let self else { return }
            if let error {
                session.invalidate(errorMessage: "Could not connect to tag: \(error.localizedDescription)")
                return
            }

            switch self.mode {

            // ── READ ──────────────────────────────────────────────────────
            case .read:
                tag.readNDEF { message, error in
                    if let error {
                        session.invalidate(errorMessage: "Could not read tag: \(error.localizedDescription)")
                        return
                    }
                    guard let message else {
                        session.invalidate(errorMessage: "Tag is empty.")
                        return
                    }
                    for record in message.records {
                        if let text = self.extractText(from: record),
                           text.hasPrefix("VAULTD-") {
                            session.alertMessage = "Box found!"
                            session.invalidate()
                            self.scannedPayload = text
                            return
                        }
                    }
                    session.invalidate(errorMessage: "This tag doesn't belong to a Vaultd box.")
                }

            // ── WRITE ─────────────────────────────────────────────────────
            case .write(let payload, let completion):
                tag.queryNDEFStatus { status, _, error in
                    if let error {
                        session.invalidate(errorMessage: error.localizedDescription)
                        completion(false)
                        return
                    }
                    switch status {
                    case .notSupported:
                        session.invalidate(errorMessage: "This tag doesn't support NDEF.")
                        completion(false)
                    case .readOnly:
                        session.invalidate(errorMessage: "This tag is read-only and can't be programmed.")
                        completion(false)
                    case .readWrite:
                        let message = NFCNDEFMessage(records: [self.makeTextRecord(payload)])
                        tag.writeNDEF(message) { error in
                            if let error {
                                session.invalidate(errorMessage: "Write failed: \(error.localizedDescription)")
                                completion(false)
                            } else {
                                session.alertMessage = "NFC tag programmed! Stick it on Box \(payload.components(separatedBy: "-")[2])."
                                session.invalidate()
                                completion(true)
                            }
                        }
                    @unknown default:
                        session.invalidate(errorMessage: "Unknown tag status.")
                        completion(false)
                    }
                }
            }
        }
    }
}
