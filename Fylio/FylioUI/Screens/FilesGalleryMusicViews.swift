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

    // Plus de header perso — sobre : titre natif + search seulement

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
            FylioHaptics.tap()
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
        .buttonStyle(FylioPressStyle(haptic: false))
    }

    private var fileList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                if filteredFiles.isEmpty {
                    FylioEmptyState(character: "empty_history",
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
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 6),
                                             GridItem(.flexible(), spacing: 6)], spacing: 6) {
                            ForEach(images) { file in
                                if let url = file.fileURL,
                                   let data = try? Data(contentsOf: url),
                                   let image = UIImage(data: data) {
                                    Image(uiImage: image)
                                        .resizable().scaledToFill()
                                        .frame(height: 130)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        .onTapGesture { app.openFile(file) }
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                }
            }
        }
        .navigationTitle(String(localized: "gallery.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - MUSIQUE (Palier 2 — 3 sections DA bleu vitré, même maquette)

struct MusicView: View {
    @EnvironmentObject var app: AppViewModel
    @State private var searchText = ""
    @State private var currentTrack: FylioFileItem?
    @State private var isPlaying = false

    // Toutes les musiques/audio de l'appareil (public.audio, mp3, m4a, musique + audio général)
    private var allAudio: [FylioFileItem] {
        app.allFileItems.filter { item in
            let t = item.contentType.lowercased()
            return t.contains("audio") || t.contains("music")
               || ["mp3","m4a","aac","flac","wav","ogg","opus"].contains((item.name as NSString).pathExtension.lowercased())
        }
    }
    private var filteredAllAudio: [FylioFileItem] {
        guard !searchText.isEmpty else { return allAudio }
        return allAudio.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    // Section "Musique récente" : 8 plus récents (modificationDate)
    private var recentAudio: [FylioFileItem] {
        allAudio.sorted { modDate($0) > modDate($1) }.prefix(8).map { $0 }
    }

    private func modDate(_ f: FylioFileItem) -> Date {
        guard let u = f.fileURL, let v = try? u.resourceValues(forKeys: [.contentModificationDateKey]) else { return .distantPast }
        return v.contentModificationDate ?? .distantPast
    }

    var body: some View {
        ZStack {
            FylioBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    hero
                    FylioSearchBar(text: $searchText, placeholder: String(localized: "common.search"))
                        .padding(.horizontal, FylioTokens.screenMargin)

                    // ① En lecture — widget bleu vitré (DA maquette, même style bleu profond + vitré)
                    if let track = currentTrack {
                        nowPlayingCard(track)
                    }

                    // ② Musique récente (remplace "Playlists populaires")
                    musicSection(titleKey: "music.recentSection", files: recentAudio)

                    // ③ Toutes les musiques de l'appareil (remplace "Récemment écoutés" limité)
                    musicSection(titleKey: "music.allSection", files: filteredAllAudio)

                    // ④ Widget lecteur (barre flottante) — reste en bas, même DA
                    if let track = currentTrack {
                        miniPlayer(track)
                            .padding(.horizontal, FylioTokens.screenMargin)
                    }
                }
                .padding(.vertical, 16)
            }
        }
        .navigationTitle(String(localized: "music.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // Header : personnage re-cadré (60→72, padding réduit, bien centré)
    private var hero: some View {
        HStack {
            Image("music_character")
                .resizable().scaledToFit()
                .frame(height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(localized: "music.hero.title"))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(FylioPalette.nightText)
                Text(String(localized: "music.hero.subtitle"))
                    .font(.system(size: 13)).foregroundStyle(FylioPalette.secondaryText)
            }
        }
        .padding(.horizontal, FylioTokens.screenMargin)
        .padding(.top, 8)
    }

    // Carte "En lecture" — bleu profond + vitré + blur (même DA que maquette 1-Pages Musique)
    private func nowPlayingCard(_ track: FylioFileItem) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(FylioPalette.electricBlue.opacity(0.14))
                    .frame(width: 64, height: 64)
                FileIcon(contentType: track.contentType, size: 36)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "music.nowPlaying"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(FylioPalette.secondaryBlue)
                Text(track.name).font(.system(size: 16, weight: .bold))
                    .foregroundStyle(FylioPalette.nightText).lineLimit(1)
                Text(ByteCountFormatter.string(fromByteCount: track.sizeBytes, countStyle: .file))
                    .font(.system(size: 12)).foregroundStyle(FylioPalette.secondaryText)
            }
            Spacer()
            Button { togglePlay() } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 44)).foregroundStyle(FylioPalette.electricBlue)
            }.buttonStyle(FylioPressStyle())
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.60), lineWidth: 1))
        .shadow(color: FylioTokens.shadowGlass, radius: 14, y: 6)
        .padding(.horizontal, FylioTokens.screenMargin)
    }

    private func musicSection(titleKey: String, files: [FylioFileItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: String.LocalizationValue(titleKey)))
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(FylioPalette.nightText)
                .padding(.horizontal, FylioTokens.screenMargin)
            if files.isEmpty {
                FylioEmptyState(character: "empty_music", titleKey: "music.empty.title", subtitleKey: "music.empty.subtitle")
                    .padding(.horizontal, FylioTokens.screenMargin)
            } else {
                ForEach(files) { file in
                    Button { playTrack(file) } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle().fill(FylioPalette.paleBlue)
                                Image(systemName: "music.note").foregroundStyle(FylioPalette.electricBlue)
                            }.frame(width: 46, height: 46)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(file.name).font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(FylioPalette.nightText).lineLimit(1)
                                Text(ByteCountFormatter.string(fromByteCount: file.sizeBytes, countStyle: .file))
                                    .font(.system(size: 11)).foregroundStyle(FylioPalette.secondaryText)
                            }
                            Spacer()
                            if currentTrack?.id == file.id, isPlaying {
                                Image(systemName: "waveform").foregroundStyle(FylioPalette.electricBlue)
                            } else {
                                Image(systemName: "play.circle").foregroundStyle(FylioPalette.secondaryText.opacity(0.6))
                            }
                        }
                        .padding(13)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.55), lineWidth: 1))
                    }.buttonStyle(FylioPressStyle())
                    .padding(.horizontal, FylioTokens.screenMargin)
                }
            }
        }
    }

    private func miniPlayer(_ track: FylioFileItem) -> some View {
        HStack(spacing: 12) {
            Button { togglePlay() } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 40)).foregroundStyle(FylioPalette.electricBlue)
            }.buttonStyle(FylioPressStyle())
            Text(track.name).font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FylioPalette.nightText).lineLimit(1)
            Spacer()
            if track.contentType.contains("movie") || track.contentType.contains("video") {
                Button { extractAudioFromVideo(track) } label: {
                    Image(systemName: "waveform.badge.plus").font(.system(size: 20)).foregroundStyle(FylioPalette.secondaryBlue)
                }.buttonStyle(FylioPressStyle())
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.55), lineWidth: 1))
        .shadow(color: FylioTokens.shadowGlass, radius: 10, y: 4)
    }

    private func playTrack(_ file: FylioFileItem) {
        currentTrack = file; isPlaying = true; app.playAudio(file)
    }
    private func togglePlay() { isPlaying.toggle(); app.toggleAudioPlayback() }
    private func extractAudioFromVideo(_ file: FylioFileItem) {
        guard let url = file.fileURL else { return }
        FylioAudioExtractor.extractAudio(from: url, progress: { _ in }, completion: { _ in })
    }
}

// MARK: - HISTORIQUE (onglet Historique — via Accueil Voir tout)

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