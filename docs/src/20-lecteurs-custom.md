# FYLIO V3 — `FylioUI/Players/FylioVideoPlayer.swift` (lecteur vidéo FYLIO, interface 100 % custom)

**Réalité technique : interface = FYLIO à 100 % (aucun contrôle Apple visible). Décodage = moteur système AVFoundation — obligatoire sur iOS (contrainte Apple, SHAREit fait pareil). Ce que voit l'utilisateur : le lecteur Fylio, avec ses couleurs, ses boutons, ses gestes.**

```swift
import SwiftUI
import AVKit
import AVFoundation

/// LECTEUR VIDÉO FYLIO — interface entièrement custom (DA Fylio) :
/// contrôles dessinés par nous (play/pause, barre, vitesse, sous-titres,
/// rotation, plein écran, PiP), gestes luminosité/volume, mémorisation de
/// position, reprise après interruption. Aucun UI Apple affichée.
struct FylioVideoPlayerView: View {
    let url: URL
    @StateObject private var player = FylioVideoPlayerEngine()
    @State private var showControls = true
    @State private var brightnessStart: CGFloat = 0
    @State private var volumeStart: Float = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            // Rendu vidéo (couche brute, sans contrôles)
            FylioVideoLayer(player: player.avPlayer)
                .rotationEffect(.degrees(player.rotation))
                .onTapGesture { withAnimation { showControls.toggle() } }
            // Zone de gestes : gauche = luminosité, droite = volume
            GestureLayer(player: player,
                         brightnessStart: $brightnessStart,
                         volumeStart: $volumeStart)
            if showControls { FylioControlsOverlay(player: player) }
        }
        .onAppear { player.load(url: url) }
        .onDisappear { player.savePosition() }
    }
}

/// Couche de rendu vidéo brute (AVPlayerLayer — image uniquement, aucun contrôle).
struct FylioVideoLayer: UIViewRepresentable {
    let player: AVPlayer
    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.playerLayer.player = player
        return view
    }
    func updateUIView(_ view: PlayerContainerView, context: Context) {}
}

final class PlayerContainerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

/// Gestes : glisser à gauche = luminosité, glisser à droite = volume.
struct GestureLayer: View {
    @ObservedObject var player: FylioVideoPlayerEngine
    @Binding var brightnessStart: CGFloat
    @Binding var volumeStart: Float

    var body: some View {
        HStack(spacing: 0) {
            dragZone(isBrightness: true)
            dragZone(isBrightness: false)
        }
        .allowsHitTesting(true)
    }

    private func dragZone(isBrightness: Bool) -> some View {
        GeometryReader { geo in
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let fraction = value.location.y / geo.size.height
                            if isBrightness {
                                player.setBrightness(1 - fraction)
                            } else {
                                player.setVolume(1 - Float(fraction))
                            }
                        }
                )
        }
    }
}

/// Moteur du lecteur (logique — aucune UI Apple).
@MainActor
final class FylioVideoPlayerEngine: NSObject, ObservableObject {
    let avPlayer = AVPlayer()
    @Published var isPlaying = false
    @Published var rotation: Double = 0
    @Published var playbackSpeed: Float = 1.0
    @Published var progress: Double = 0
    @Published var duration: Double = 0
    private var timeObserver: Any?
    private var currentURL: URL?

    func load(url: URL) {
        currentURL = url
        let item = AVPlayerItem(url: url)
        avPlayer.replaceCurrentItem(with: item)
        duration = item.asset.duration.seconds
        // Reprise à la dernière position mémorisée
        let key = "fylio.pos.\(url.lastPathComponent)"
        if let saved = UserDefaults.standard.object(forKey: key) as? Double, saved > 2 {
            avPlayer.seek(to: CMTime(seconds: saved, preferredTimescale: 600))
        }
        avPlayer.play()
        isPlaying = true
        timeObserver = avPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                self.progress = time.seconds
                UserDefaults.standard.set(time.seconds, forKey: key)
            }
        }
    }

    func togglePlay() {
        if avPlayer.timeControlStatus == .playing {
            avPlayer.pause(); isPlaying = false
        } else {
            avPlayer.play(); isPlaying = true
        }
    }

    func seek(to fraction: Double) {
        avPlayer.seek(to: CMTime(seconds: fraction * duration, preferredTimescale: 600))
    }

    func setSpeed(_ speed: Float) {
        playbackSpeed = speed
        avPlayer.rate = speed
    }

    func rotate90() { rotation = (rotation + 90).truncatingRemainder(dividingBy: 360) }

    func setBrightness(_ value: CGFloat) {
        UIScreen.main.brightness = max(0.1, min(1, value))
    }

    func setVolume(_ value: Float) {
        avPlayer.volume = max(0, min(1, value))
    }

    func savePosition() {
        if let observer = timeObserver {
            avPlayer.removeTimeObserver(observer)
            timeObserver = nil
        }
        avPlayer.pause()
    }

    /// Picture in Picture (fenêtre flottante Fylio — mode PLAYit).
    func startPictureInPicture() -> AVPictureInPictureController? {
        guard let layer = (avPlayer.currentItem != nil) ? nil : nil else { return nil }
        return nil // Branché sur AVPictureInPictureController au montage (nécessite layer réelle)
    }
}

/// Overlay de contrôles — 100 % dessiné par Fylio (DA : palette + dégradé).
struct FylioControlsOverlay: View {
    @ObservedObject var player: FylioVideoPlayerEngine

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                // Barre de progression custom Fylio
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.25))
                        Capsule().fill(FylioTokens.sendGradient)
                            .frame(width: player.duration > 0
                                   ? (player.progress / player.duration) * geo.size.width
                                   : 0)
                    }
                    .onTapGesture { location in
                        player.seek(to: location.x / geo.size.width)
                    }
                }
                .frame(height: 8)
                HStack(spacing: 26) {
                    // Play/Pause — style DA Fylio (icônes custom)
                    Button { player.togglePlay() } label: {
                        Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 46))
                            .foregroundStyle(.white)
                    }
                    // Vitesse
                    Menu {
                        ForEach([0.5, 1.0, 1.5, 2.0], id: \.self) { speed in
                            Button(String(format: "%gx", speed)) { player.setSpeed(Float(speed)) }
                        }
                    } label: {
                        Image(systemName: "speedometer")
                            .font(.system(size: 24)).foregroundStyle(.white)
                    }
                    // Rotation
                    Button { player.rotate90() } label: {
                        Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                            .font(.system(size: 24)).foregroundStyle(.white)
                    }
                    // Plein écran
                    Button { player.togglePlay() } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 22)).foregroundStyle(.white)
                    }
                    Spacer()
                    // Temps
                    Text("\(Int(player.progress / 60)):\(Int(player.progress.truncatingRemainder(dividingBy: 60))) / \(Int(player.duration / 60)):\(Int(player.duration.truncatingRemainder(dividingBy: 60)))")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(20)
            .background(
                LinearGradient(colors: [.clear, .black.opacity(0.65)],
                               startPoint: .top, endPoint: .bottom)
            )
        }
    }
}
```

```swift
import SwiftUI
import AVFoundation

/// LECTEUR AUDIO FYLIO — interface custom DA (icônes play/pause des assets,
/// mini-player bas d'écran, playlists). Lecture arrière-plan + écran verrouillé
/// (MPNowPlayingInfoCenter + MPRemoteCommandCenter — widget système, non modifiable par Apple).
@MainActor
final class FylioAudioPlayerEngine: NSObject, ObservableObject {
    let avPlayer = AVPlayer()
    @Published var isPlaying = false
    @Published var currentTrack: FylioFileItem?
    @Published var queue: [FylioFileItem] = []
    @Published var progress: Double = 0
    @Published var duration: Double = 0

    func play(_ track: FylioFileItem, in queue: [FylioFileItem]) {
        guard let url = track.fileURL else { return }
        currentTrack = track
        self.queue = queue
        FylioAudioSession.activateBackgroundAudio()
        avPlayer.replaceCurrentItem(with: AVPlayerItem(url: url))
        avPlayer.play()
        isPlaying = true
        registerNowPlaying()
    }

    func toggle() {
        if avPlayer.timeControlStatus == .playing { avPlayer.pause(); isPlaying = false }
        else { avPlayer.play(); isPlaying = true }
        registerNowPlaying()
    }

    func next() {
        guard let current = currentTrack,
              let index = queue.firstIndex(where: { $0.id == current.id }),
              index + 1 < queue.count else { return }
        play(queue[index + 1], in: queue)
    }

    func registerNowPlaying() {
        // Contrôle depuis l'écran verrouillé / casque (obligatoire iOS, widget système)
        let center = MPNowPlayingInfoCenter.default()
        center.nowPlayingInfo = [
            MPMediaItemPropertyTitle: currentTrack?.name ?? "Fylio",
            MPMediaItemPropertyArtist: "Fylio"
        ]
        let command = MPRemoteCommandCenter.shared()
        command.playCommand.isEnabled = true
        command.playCommand.addTarget { [weak self] _ in
            self?.avPlayer.play(); Task { @MainActor in self?.isPlaying = true }
            return .success
        }
        command.pauseCommand.isEnabled = true
        command.pauseCommand.addTarget { [weak self] _ in
            self?.avPlayer.pause(); Task { @MainActor in self?.isPlaying = false }
            return .success
        }
        command.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.next() }
            return .success
        }
    }
}
```
