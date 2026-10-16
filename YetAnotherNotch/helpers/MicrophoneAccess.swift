//
//  MicrophoneAccess.swift
//  YetAnotherNotch
//

import AVFoundation

/// The microphone permission check, used by live transcription.
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
