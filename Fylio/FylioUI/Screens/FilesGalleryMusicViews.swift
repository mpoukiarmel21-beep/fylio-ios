import SwiftUI
import UIKit
import AVFoundation

// MARK: - FICHIERS (doc 17) — onglet « Fichiers »

struct FilesView: View {
    @EnvironmentObject var app: AppViewModel
    @State private var selectedTab: Int = 0
    @State private var showNewFolder = false
    @State private var newFolderName = ""

    var body: some View {
        ZStack {
            FylioBackground()
            VStack(spacing: 0) {
                header
                categoryTabs
                fileList
            }
        }
        .navigationTitle(String(localized: "files.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showNewFolder = true } label: {
                    Image(systemName: "folder.badge.plus")
                        .foregroundStyle(FylioPalette.electricBlue)
                }
            }
        }
        .alert(String(localized: "files.newFolder"), isPresented: $showNewFolder) {
            TextField(String(localized: "files.newFolder.name"), text: $newFolderName)
            Button(String(localized: "common.create")) {
                app.createFolder(named: newFolderName)
                newFolderName = ""
            }
            Button(String(localized: "common.cancel"), role: .cancel) {}
        }
    }

    private var header: some View {
        HStack {
            Image("files_character")
                .resizable().scaledToFit().frame(height: 56)
            Spacer()
        }
        .padding(.horizontal, FylioTokens.screenMargin)
        .padding(.top, 8)
    }

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                tabItem("files.tab.all", 0)
                tabItem("files.tab.recent", 1)
                tabItem("files.tab.received", 2)
                tabItem("files.tab.sent", 3)
                tabItem("files.tab.favorites", 4)
            }
            .padding(.horizontal, FylioTokens.screenMargin)
        }
        .padding(.vertical, 10)
    }

    private func tabItem(_ key: String, _ idx: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) { selectedTab = idx }
        } label: {
            Text(String(localized: String.LocalizationValue(key)))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(selectedTab == idx ? .white : FylioPalette.nightText)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(selectedTab == idx
                            ? AnyShapeStyle(FylioTokens.sendGradient)
                            : AnyShapeStyle(.ultraThinMaterial),
                            in: Capsule())
        }
        .buttonStyle(FylioPressStyle())
    }

    private var fileList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                if filteredFiles.isEmpty {
                    FylioEmptyState(character: "files_character",
                                    titleKey: "files.empty.title",
                                    subtitleKey: "files.empty.subtitle")
                } else {
                    ForEach(filteredFiles) { file in
                        fileRow(file)
                    }
                }
            }
            .padding(.horizontal, FylioTokens.screenMargin)
            .padding(.vertical, 16)
        }
    }

    private var filteredFiles: [FylioFileItem] {
        switch selectedTab {
        case 1: return app.allFileItems.sorted {
            modificationDate($0) > modificationDate($1)
        }
        case 2: return app.allFileItems.filter { $0.fileURL?.path.contains("Recu") ?? false }
        case 3: return app.allFileItems.filter { $0.fileURL?.path.contains("Envoye") ?? false }
        case 4: return app.allFileItems.filter {
            UserDefaults.standard.bool(forKey: "fylio.fav.\($0.id.uuidString)")
        }
        default: return app.allFileItems
        }
    }

    private func modificationDate(_ file: FylioFileItem) -> Date {
        guard let path = file.fileURL?.path else { return .distantPast }
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        return (attrs?[.modificationDate] as? Date) ?? .distantPast
    }

    private func fileRow(_ file: FylioFileItem) -> some View {
        Button { app.openFile(file) } label: {
            HStack(spacing: 14) {
                FileIcon(contentType: file.contentType, size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(file.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(FylioPalette.nightText)
                        .lineLimit(1)
                    Text(ByteCountFormatter.string(fromByteCount: file.sizeBytes, countStyle: .file))
                        .font(.system(size: 12))
                        .foregroundStyle(FylioPalette.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(FylioPalette.secondaryText)
            }
            .padding(14)
            .background(.ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(FylioPressStyle())
        .contextMenu {
            Button { app.openFile(file) } label: {
                Label(String(localized: "files.open"), systemImage: "eye")
            }
            Button { app.shareFile(file) } label: {
                Label(String(localized: "files.share"), systemImage: "square.and.arrow.up")
            }
            Button { app.toggleFavorite(file) } label: {
                Label(String(localized: "files.favorite"), systemImage: "star")
            }
            Button(role: .destructive) { app.deleteFile(file) } label: {
                Label(String(localized: "files.delete"), systemImage: "trash")
            }
        }
    }
}

// MARK: - GALERIE (doc 17) — onglet « Galerie »

struct GalleryView: View {
    @EnvironmentObject var app: AppViewModel

    private var images: [FylioFileItem] {
        app.allFileItems.filter { $0.contentType.contains("image") }
    }

    var body: some View {
        ZStack {
            FylioBackground()
            VStack(spacing: 0) {
                HStack {
                    Image("gallery_character_left")
                        .resizable().scaledToFit().frame(height: 60)
                    Spacer()
                    Image("gallery_character_right")
                        .resizable().scaledToFit().frame(height: 60)
                }
                .padding(.horizontal, FylioTokens.screenMargin)
                .padding(.top, 8)

                if images.isEmpty {
                    VStack {
                        Spacer()
                        FylioEmptyState(character: "empty_gallery",
                                        titleKey: "gallery.empty.title",
                                        subtitleKey: "gallery.empty.subtitle")
                        Spacer()
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 4),
                                             GridItem(.flexible(), spacing: 4)], spacing: 4) {
                            ForEach(images) { file in
                                if let url = file.fileURL,
                                   let data = try? Data(contentsOf: url),
                                   let image = UIImage(data: data) {
                                    Image(uiImage: image)
                                        .resizable().scaledToFill()
                                        .frame(height: 120)
                                        .clipped()
                                        .onTapGesture { app.openFile(file) }
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                }
            }
        }
        .navigationTitle(String(localized: "gallery.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - MUSIQUE (doc 17) — onglet « Musique » avec mini-lecteur

struct MusicView: View {
    @EnvironmentObject var app: AppViewModel
    @State private var searchText = ""
    @State private var currentTrack: FylioFileItem?
    @State private var isPlaying = false

    private var audioFiles: [FylioFileItem] {
        let audio = app.allFileItems.filter { $0.contentType.contains("audio") }
        guard !searchText.isEmpty else { return audio }
        return audio.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ZStack {
            FylioBackground()
            VStack(spacing: 0) {
                header
                searchBar
                trackList
                if let track = currentTrack {
                    miniPlayer(track)
                }
            }
        }
        .navigationTitle(String(localized: "music.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack {
            Image("music_character")
                .resizable().scaledToFit().frame(height: 60)
            Spacer()
        }
        .padding(.horizontal, FylioTokens.screenMargin)
        .padding(.top, 8)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(FylioPalette.secondaryText)
            TextField(String(localized: "common.search"), text: $searchText)
        }
        .padding(12)
        .background(.ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, FylioTokens.screenMargin)
        .padding(.vertical, 10)
    }

    private var trackList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                if audioFiles.isEmpty {
                    FylioEmptyState(character: "empty_music",
                                    titleKey: "music.empty.title",
                                    subtitleKey: "music.empty.subtitle")
                } else {
                    ForEach(audioFiles) { file in
                        Button { playTrack(file) } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle().fill(FylioPalette.paleBlue)
                                    Image(systemName: "music.note")
                                        .foregroundStyle(FylioPalette.electricBlue)
                                }
                                .frame(width: 46, height: 46)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(file.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(FylioPalette.nightText)
                                        .lineLimit(1)
                                    Text(ByteCountFormatter.string(fromByteCount: file.sizeBytes,
                                                                    countStyle: .file))
                                        .font(.system(size: 12))
                                        .foregroundStyle(FylioPalette.secondaryText)
                                }
                                Spacer()
                                if currentTrack?.id == file.id, isPlaying {
                                    Image(systemName: "waveform")
                                        .foregroundStyle(FylioPalette.electricBlue)
                                }
                            }
                            .padding(14)
                            .background(.ultraThinMaterial,
                                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                        .buttonStyle(FylioPressStyle())
                    }
                }
            }
            .padding(.horizontal, FylioTokens.screenMargin)
            .padding(.vertical, 16)
        }
    }

    private func miniPlayer(_ track: FylioFileItem) -> some View {
        HStack(spacing: 14) {
            Button { togglePlay() } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(FylioPalette.electricBlue)
            }
            Text(track.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(FylioPalette.nightText)
                .lineLimit(1)
            Spacer()
            if track.contentType.contains("movie") || track.contentType.contains("video") {
                Button { extractAudioFromVideo(track) } label: {
                    Image(systemName: "waveform.badge.plus")
                        .font(.system(size: 22))
                        .foregroundStyle(FylioPalette.secondaryBlue)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private func playTrack(_ file: FylioFileItem) {
        currentTrack = file
        isPlaying = true
        app.playAudio(file)
    }

    private func togglePlay() {
        isPlaying.toggle()
        app.toggleAudioPlayback()
    }

    private func extractAudioFromVideo(_ file: FylioFileItem) {
        guard let url = file.fileURL else { return }
        FylioAudioExtractor.extractAudio(from: url, progress: { _ in }, completion: { _ in })
    }
}

// MARK: - HISTORIQUE (doc 17) — onglet « Historique »

struct HistoryView: View {
    @EnvironmentObject var app: AppViewModel

    var body: some View {
        ZStack {
            FylioBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if app.history.isEmpty {
                        FylioEmptyState(character: "empty_history",
                                        titleKey: "history.empty.title",
                                        subtitleKey: "history.empty.subtitle")
                            .padding(.top, 60)
                    } else {
                        ForEach(app.history) { entry in
                            FylioGlassCard(corner: 22) {
                                HStack(spacing: 14) {
                                    FylioDeviceIcon(entry.platform, size: 36)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(entry.title)
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(FylioPalette.nightText)
                                        Text("\(entry.count) · \(entry.formattedSize) · \(entry.relativeDate)")
                                            .font(.system(size: 12))
                                            .foregroundStyle(FylioPalette.secondaryText)
                                    }
                                    Spacer()
                                    Image(systemName: entry.direction == .sent
                                          ? "arrow.up.circle.fill"
                                          : "arrow.down.circle.fill")
                                        .font(.system(size: 26))
                                        .foregroundStyle(entry.direction == .sent
                                                        ? FylioPalette.secondaryBlue
                                                        : FylioPalette.statusGreen)
                                }
                            }
                        }
                        Button {
                            app.clearHistory { }
                        } label: {
                            Label(String(localized: "history.clearAll"), systemImage: "trash")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(FylioPalette.alertRed)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, FylioTokens.screenMargin)
                .padding(.vertical, 20)
            }
        }
        .navigationTitle(String(localized: "history.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Extraction audio (doc 20 : lecteurs) — version minimale AVFoundation

enum FylioAudioExtractor {
    static func extractAudio(from url: URL,
                             progress: @escaping (Double) -> Void,
                             completion: @escaping (Result<URL, Error>?) -> Void) {
        let asset = AVURLAsset(url: url)
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        guard let session = AVAssetExportSession(asset: asset,
                                                 presetName: AVAssetExportPresetAppleM4A) else {
            completion(nil)
            return
        }
        session.outputURL = destination
        session.outputFileType = .m4a
        session.exportAsynchronously {
            DispatchQueue.main.async {
                switch session.status {
                case .completed:
                    completion(.success(destination))
                default:
                    completion(nil)
                }
            }
        }
    }
}