# FYLIO — `FylioUI/Support/` (VERSION PROPRE — icônes, aperçu, audio, QuickLook, extensions AppViewModel)

```swift
import SwiftUI
import AVFoundation
import QuickLook

// MARK: - Icône de fichier par type

struct FileIcon: View {
    private let contentType: String
    private let size: CGFloat

    init(contentType: String, size: CGFloat = 48) {
        self.contentType = contentType
        self.size = size
    }

    private var systemName: String {
        if contentType.contains("image") { return "photo.fill" }
        if contentType.contains("movie") || contentType.contains("video") { return "video.fill" }
        if contentType.contains("audio") { return "music.note" }
        if contentType.contains("pdf") { return "doc.richtext" }
        if contentType.contains("spreadsheet") { return "tablecells" }
        if contentType.contains("word") || contentType.contains("text") { return "doc.text" }
        return "doc.fill"
    }

    private var tint: Color {
        if contentType.contains("image") { return FylioPalette.electricBlue }
        if contentType.contains("movie") || contentType.contains("video") { return FylioPalette.secondaryBlue }
        if contentType.contains("audio") { return FylioPalette.statusGreen }
        return FylioPalette.secondaryText
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(FylioPalette.paleBlue.opacity(0.6))
            Image(systemName: systemName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Aperçu de fichier (tout dans Fylio — écosystème interne)

struct FilePreviewSheet: View {
    let file: FylioFileItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let url = file.fileURL {
                    if file.contentType.contains("image") {
                        if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                            Image(uiImage: image).resizable().scaledToFit()
                        }
                    } else if file.contentType.contains("movie") || file.contentType.contains("video") {
                        FylioVideoPlayerView(url: url)
                    } else if file.contentType.contains("audio") {
                        FylioAudioPlayerView(url: url)
                    } else if file.contentType.contains("pdf") {
                        FylioPDFView(url: url)
                    } else {
                        QuickLookView(url: url)
                    }
                } else {
                    Text(String(localized: "preview.unavailable"))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.close")) { dismiss() }
                }
            }
        }
    }
}

// MARK: - Lecteur audio (mini-player style DA)

struct FylioAudioPlayerView: View {
    let url: URL
    @StateObject private var controller = FylioPlayerController()

    var body: some View {
        VStack(spacing: 24) {
            Image("music_character")
                .resizable().scaledToFit().frame(height: 140)
            Text(url.lastPathComponent)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(FylioPalette.nightText)
            HStack(spacing: 30) {
                Button { controller.player.play() } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(FylioPalette.electricBlue)
                }
                Button { controller.player.pause() } label: {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(FylioPalette.electricBlue)
                }
            }
        }
        .onAppear {
            FylioAudioSession.activateBackgroundAudio()
            controller.play(url: url)
        }
        .onDisappear {
            controller.savePosition()
            FylioAudioSession.deactivate()
        }
    }
}

// MARK: - QuickLook (aperçu Excel / Word — V1, édition plus tard)

struct QuickLookView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController,
                               previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}
```

```swift
import SwiftUI
import AVFoundation

// MARK: - Méthodes AppViewModel (fichiers, lecture, cache, effacement)

extension AppViewModel {
    @Published var fileToPreview: FylioFileItem?
    @Published var shareURL: URL?
    private var playerController: FylioPlayerController? {
        get { _playerControllerHolder }
        set { _playerControllerHolder = newValue }
    }
    private var _playerControllerHolder: FylioPlayerController? {
        get { ObjectiveC.io_getAssociatedObject(self) as? FylioPlayerController }
        set { ObjectiveC.io_setAssociatedObject(self, newValue) }
    }

    func openFile(_ file: FylioFileItem) {
        fileToPreview = file
    }

    func shareFile(_ file: FylioFileItem) {
        if let url = file.fileURL { shareURL = url }
    }

    func toggleFavorite(_ file: FylioFileItem) {
        let key = "fylio.fav.\(file.id.uuidString)"
        UserDefaults.standard.set(!UserDefaults.standard.bool(forKey: key), forKey: key)
    }

    func deleteFile(_ file: FylioFileItem) {
        if let url = file.fileURL { try? FileManager.default.removeItem(at: url) }
        reloadFiles()
    }

    func createFolder(named name: String) {
        guard !name.isEmpty else { return }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(
            at: docs.appendingPathComponent("Fylio/Recu/\(name)", isDirectory: true),
            withIntermediateDirectories: true)
        reloadFiles()
    }

    func playAudio(_ file: FylioFileItem) {
        guard let url = file.fileURL else { return }
        FylioAudioSession.activateBackgroundAudio()
        let controller = FylioPlayerController()
        controller.play(url: url)
        playerController = controller
    }

    func toggleAudioPlayback() {
        guard let controller = playerController else { return }
        if controller.player.timeControlStatus == .playing {
            controller.player.pause()
        } else {
            controller.player.play()
        }
    }

    func clearCache() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .allDomainsMask)
        for directory in caches {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    func eraseAllData() {
        for key in UserDefaults.standard.dictionaryRepresentation().keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        try? FileManager.default.removeItem(at: storage.receivedDirectory)
        try? FileManager.default.removeItem(at: storage.sentDirectory)
    }
}
```
