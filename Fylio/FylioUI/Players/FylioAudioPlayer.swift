import SwiftUI
import AVFoundation
import MediaPlayer

// MARK: - Session audio Fylio (lecture arrière-plan + écran verrouillé)

enum FylioAudioSession {
    static func activateBackgroundAudio() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .moviePlayback)
            try session.setActive(true)
        } catch {
            // Silencieux : la lecture continue même si la session n'est pas configurée.
        }
    }
}

// MARK: - LECTEUR AUDIO FYLIO
// Interface custom DA (mini-player bas d'écran, playlists). Lecture arrière-plan
// + écran verrouillé via MPNowPlayingInfoCenter + MPRemoteCommandCenter
// (widget système — non modifiable par Apple, obligatoire pour l'audio background).

@MainActor
final class FylioAudioPlayerEngine: NSObject, ObservableObject {
    let avPlayer = AVPlayer()
    @Published var isPlaying = false
    @Published var currentTrack: FylioFileItem?
    @Published var queue: [FylioFileItem] = []
    @Published var progress: Double = 0
    @Published var duration: Double = 0
    private var timeObserver: Any?

    func play(_ track: FylioFileItem, in queue: [FylioFileItem]) {
        guard let url = track.fileURL else { return }
        currentTrack = track
        self.queue = queue
        FylioAudioSession.activateBackgroundAudio()
        let item = AVPlayerItem(url: url)
        avPlayer.replaceCurrentItem(with: item)
        duration = item.asset.duration.seconds.isFinite ? item.asset.duration.seconds : 0
        avPlayer.play()
        isPlaying = true
        registerNowPlaying()
        trackProgress()
    }

    func toggle() {
        if avPlayer.timeControlStatus == .playing {
            avPlayer.pause(); isPlaying = false
        } else {
            avPlayer.play(); isPlaying = true
        }
        registerNowPlaying()
    }

    func next() {
        guard let current = currentTrack,
              let index = queue.firstIndex(where: { $0.id == current.id }),
              index + 1 < queue.count else { return }
        play(queue[index + 1], in: queue)
    }

    func previous() {
        guard let current = currentTrack,
              let index = queue.firstIndex(where: { $0.id == current.id }),
              index > 0 else { return }
        play(queue[index - 1], in: queue)
    }

    func seek(to fraction: Double) {
        guard duration > 0 else { return }
        avPlayer.seek(to: CMTime(seconds: fraction * duration, preferredTimescale: 600))
    }

    private func trackProgress() {
        if let observer = timeObserver { avPlayer.removeTimeObserver(observer) }
        timeObserver = avPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                self.progress = time.seconds
                self.registerPlayingTime()
            }
        }
    }

    private func registerNowPlaying() {
        let center = MPNowPlayingInfoCenter.default()
        center.nowPlayingInfo = [
            MPMediaItemPropertyTitle: currentTrack?.name ?? "Fylio",
            MPMediaItemPropertyArtist: "Fylio",
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: progress
        ]
        let command = MPRemoteCommandCenter.shared()
        command.playCommand.isEnabled = true
        command.pauseCommand.isEnabled = true
        command.nextTrackCommand.isEnabled = !queue.isEmpty
        command.previousTrackCommand.isEnabled = !queue.isEmpty
        command.playCommand.removeTarget(nil)
        command.pauseCommand.removeTarget(nil)
        command.nextTrackCommand.removeTarget(nil)
        command.previousTrackCommand.removeTarget(nil)
        command.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.avPlayer.play(); self?.isPlaying = true; self?.registerNowPlaying()
            }
            return .success
        }
        command.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.avPlayer.pause(); self?.isPlaying = false; self?.registerNowPlaying()
            }
            return .success
        }
        command.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.next() }
            return .success
        }
        command.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.previous() }
            return .success
        }
    }

    private func registerPlayingTime() {
        guard let current = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = current.merging(
            [MPNowPlayingInfoPropertyElapsedPlaybackTime: progress], uniquingKeysWith: { _, new in new }
        )
    }
}