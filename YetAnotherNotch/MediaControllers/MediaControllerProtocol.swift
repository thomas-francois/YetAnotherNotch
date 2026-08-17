//
//  MediaControllerProtocol.swift
//  YetAnotherNotch
//
//  Created by Alexander on 2025-03-29.
//

import AppKit
import Combine

protocol MediaControllerProtocol: ObservableObject {
    var playbackStatePublisher: AnyPublisher<PlaybackState, Never> { get }
    var supportsVolumeControl: Bool { get }
    var supportsFavorite: Bool { get }
    
    func setFavorite(_ favorite: Bool) async
    func play() async
    func pause() async
    func seek(to time: Double) async
    func nextTrack() async
    func previousTrack() async
    func togglePlay() async
    func toggleShuffle() async
    func toggleRepeat() async
    func setVolume(_ level: Double) async
    func isActive() -> Bool
    func updatePlaybackInfo() async

    /// Release anything that outlives this object, synchronously.
    ///
    /// `deinit` is not enough for a controller that owns a child process: the active
    /// controller is held by the `MusicManager` singleton, singletons are not deallocated at
    /// app exit, and so `deinit` may simply never run. Anything spawned would then outlive the
    /// app. Callers that drop a controller must call this first.
    func stop()
}

extension MediaControllerProtocol {
    /// Most controllers only talk to another app and have nothing to release.
    func stop() {}
}
