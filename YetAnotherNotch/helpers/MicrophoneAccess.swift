//
//  MicrophoneAccess.swift
//  YetAnotherNotch
//

import AVFoundation

/// The microphone permission check, in one place.
///
/// Two features need the mic — live transcription and song identification — and a second copy
/// of this would be the kind that quietly drifts from the first.
enum MicrophoneAccess {
    static func isAuthorized() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default:
            return false
        }
    }

    static let deniedMessage =
        "YetAnotherNotch needs the microphone. Enable it in System Settings › Privacy & Security › Microphone."
}
