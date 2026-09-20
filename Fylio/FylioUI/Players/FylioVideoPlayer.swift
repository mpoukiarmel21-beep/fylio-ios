import SwiftUI
import AVFoundation

// MARK: - LECTEUR VIDÉO FYLIO
// Interface 100 % custom (DA Fylio) : contrôles dessinés par nous, gestes
// luminosité/volume, mémorisation de position, rotation, PiP.
// Décodage = AVFoundation système (obligatoire iOS) — mais AUCUN contrôle Apple visible.

struct FylioVideoPlayerView: View {
    let url: URL
    @StateObject private var player = FylioVideoPlayerEngine()
    @State private var showControls = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            // Rendu vidéo (couche brute, sans contrôles)
            FylioVideoLayer(player: player.avPlayer)
                .rotationEffect(.degrees(player.rotation))
                .onTapGesture { withAnimation { showControls.toggle() } }
            // Zone de gestes : gauche = luminosité, droite = volume
            GestureLayer(player: player)
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
        view.playerLayer.videoGravity = .resizeAspect
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

    var body: some View {
        HStack(spacing: 0) {
            dragZone { fraction in player.setBrightness(fraction) }
            dragZone { fraction in player.setVolume(fraction) }
        }
    }

    private func dragZone(_ handler: @escaping (CGFloat) -> Void) -> some View {
        GeometryReader { geo in
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // 1 = haut de l'écran (max), 0 = bas (min)
                            let fraction = 1 - (value.location.y / geo.size.height)
                            handler(CGFloat(max(0, min(1, fraction))))
                        }
                )
        }
    }
}

/// Moteur du lecteur vidéo (logique — aucune UI Apple).
@MainActor
final class FylioVideoPlayerEngine: NSObject, ObservableObject {
    let avPlayer = AVPlayer()
    @Published var isPlaying = false
    @Published var rotation: Double = 0
    @Published var playbackSpeed: Float = 1.0
    @Published var progress: Double = 0
    @Published var duration: Double = 0
    private var timeObserver: Any?

    private static let positionKey = "fylio.video.position"

    func load(url: URL) {
        let item = AVPlayerItem(url: url)
        avPlayer.replaceCurrentItem(with: item)
        duration = item.asset.duration.seconds.isFinite ? item.asset.duration.seconds : 0
        // Reprise à la dernière position mémorisée (par fichier)
        let key = "\(Self.positionKey).\(url.lastPathComponent)"
        if let saved = UserDefaults.standard.object(forKey: key) as? Double, saved > 2 {
            avPlayer.seek(to: CMTime(seconds: saved, preferredTimescale: 600))
        }
        avPlayer.play()
        isPlaying = true
        trackProgress(key: key)
    }

    private func trackProgress(key: String) {
        if let observer = timeObserver {
            avPlayer.removeTimeObserver(observer)
        }
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
        guard fraction.isFinite else { return }
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

    func setVolume(_ value: CGFloat) {
        avPlayer.volume = max(0, min(1, Float(value)))
    }

    func savePosition() {
        avPlayer.pause()
        isPlaying = false
        if let observer = timeObserver {
            avPlayer.removeTimeObserver(observer)
            timeObserver = nil
        }
    }
}

// MARK: - Picture in Picture (fenêtre flottante Fylio — mode PLAYit).
// Préparé pour T8 : un AVPictureInPictureController sera monté sur la couche
// AVPlayerLayer réelle (via UIViewControllerRepresentable) pour activer le PiP.

// MARK: - Overlay de contrôles — 100 % dessiné par Fylio (DA : palette + dégradé)

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
                        player.seek(to: Double(location.x / geo.size.width))
                    }
                }
                .frame(height: 8)

                HStack(spacing: 26) {
                    // Play / Pause — style DA Fylio
                    Button { player.togglePlay() } label: {
                        Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 46))
                            .foregroundStyle(.white)
                    }
                    // Vitesse
                    Menu {
                        ForEach([0.5, 1.0, 1.5, 2.0], id: \.self) { speed in
                            Button(String(format: "%gx", speed)) {
                                player.setSpeed(Float(speed))
                            }
                        }
                    } label: {
                        Image(systemName: "speedometer")
                            .font(.system(size: 24)).foregroundStyle(.white)
                    }
                    // Rotation
                    Button { player.rotate90() } label: {
                        Image(systemName: "rotate.right")
                            .font(.system(size: 24)).foregroundStyle(.white)
                    }
                    Spacer()
                    // Temps
                    Text(player.timecode)
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

extension FylioVideoPlayerEngine {
    /// "mm:ss / mm:ss" — formaté proprement.
    var timecode: String {
        func fmt(_ s: Double) -> String {
            let v = max(0, Int(s.rounded()))
            return String(format: "%d:%02d", v / 60, v % 60)
        }
        return "\(fmt(progress)) / \(fmt(duration))"
    }
}