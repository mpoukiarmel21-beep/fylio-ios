import SwiftUI
import UIKit

// MARK: - Aperçu interne FYLIO (remplace QuickLook — aucun renvoi vers le natif)
// T3 (lecteurs vidéo/audio/PDF) enrichira ce routeur ; la photos est déjà fonctionnelle.

struct FylioFilePreviewSheet: View {
    let file: FylioFileItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if isImage {
                    FylioPhotoViewer(url: file.fileURL)
                } else if isVideo, let url = file.fileURL {
                    FylioVideoPlayerView(url: url)
                } else if isAudio, let url = file.fileURL {
                    FylioAudioPlayerScreen(url: url, title: file.name)
                } else {
                    placeholder
                }
            }
            .navigationTitle(file.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.done")) { dismiss() }
                }
            }
        }
    }

    private var isImage: Bool {
        guard file.fileURL != nil else { return false }
        return file.contentType.contains("image")
    }

    private var isVideo: Bool {
        file.contentType.contains("movie") || file.contentType.contains("video")
    }

    private var isAudio: Bool {
        file.contentType.contains("audio")
    }

    private var placeholder: some View {
        VStack(spacing: 18) {
            FileIcon(contentType: file.contentType, size: 88)
            Text(file.name)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(FylioPalette.nightText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Text(String(localized: "feature.inProgress"))
                .font(.system(size: 14))
                .foregroundStyle(FylioPalette.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FylioBackground())
    }
}

// MARK: - Écran audio d'aperçu Fylio (lecteur DA + lever l'écoute depuis l'aperçu)

struct FylioAudioPlayerScreen: View {
    let url: URL
    let title: String
    @StateObject private var engine = FylioAudioPlayerEngine()

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "music.note")
                .font(.system(size: 64))
                .foregroundStyle(FylioPalette.electricBlue)
                .frame(width: 140, height: 140)
                .background(FylioPalette.paleBlue, in: Circle())
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(FylioPalette.nightText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 32)
            Text(engine.isPlaying
                 ? "\(engine.timecode)"
                 : String(localized: "audio.notPlaying"))
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(FylioPalette.secondaryText)
            Button { engine.toggle() } label: {
                Image(systemName: engine.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(FylioPalette.electricBlue)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FylioBackground())
        .onAppear {
            let track = FylioFileItem(name: title, sizeBytes: 0,
                                      contentType: "public.audio", fileURL: url)
            engine.play(track, in: [track])
        }
    }
}

private extension FylioAudioPlayerEngine {
    var timecode: String {
        func fmt(_ s: Double) -> String {
            let v = max(0, Int(s.rounded()))
            return String(format: "%d:%02d", v / 60, v % 60)
        }
        return "\(fmt(progress)) / \(fmt(duration))"
    }
}

/// Visionneuse photo plein écran Fylio (fond noir, zoom au centré) — aucun renvoi Photos.
struct FylioPhotoViewer: View {
    let url: URL?
    @State private var uiImage: UIImage?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Group {
                if let uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                } else {
                    ProgressView().tint(.white)
                }
            }
        }
        .task {
            guard let url, uiImage == nil else { return }
            if let data = try? Data(contentsOf: url) {
                uiImage = UIImage(data: data)
            }
        }
    }
}

// MARK: - Partage externe (sheet système — obligatoire iOS, SHAREit fait pareil)

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}