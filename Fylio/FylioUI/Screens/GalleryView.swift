import SwiftUI
import Photos
import PhotosUI

// MARK: - GALERIE — Photos réelles via PhotoKit (PHAsset) + Fichiers Fylio
// Les images du système apparaissent dès l'autorisation Photos accordée.
// + Onglet fichiers transférés (Fylio). Pas de header perso — sobre.

struct GalleryView: View {
    @EnvironmentObject var app: AppViewModel
    @State private var photoItems: [GalleryPhoto] = []
    @State private var authStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @State private var selectedTab = 0 // 0=Photos système, 1=Fylio
    @State private var isLoading = true

    private var fylioImages: [FylioFileItem] {
        app.allFileItems.filter { $0.contentType.lowercased().contains("image") || ["jpg","jpeg","png","heic","heif","webp"].contains(($0.name as NSString).pathExtension.lowercased()) }
    }

    var body: some View {
        ZStack {
            FylioBackground()
            VStack(spacing: 0) {
                // Tabs vitrés (Photos système / Fylio)
                HStack(spacing: 10) {
                    pill("Photos", idx: 0, count: photoItems.count)
                    pill("Fylio", idx: 1, count: fylioImages.count)
                }
                .padding(.horizontal, 20).padding(.vertical, 10)

                if selectedTab == 0 {
                    systemPhotosSection
                } else {
                    fylioSection
                }
            }
        }
        .navigationTitle(String(localized: "gallery.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadPhotosIfNeeded() }
        .refreshable { await loadPhotosIfNeeded(force: true) }
    }

    private func pill(_ title: String, idx: Int, count: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.28)) { selectedTab = idx }
        } label: {
            HStack(spacing: 6) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text("\(count)").font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(selectedTab == idx ? Color.white.opacity(0.22) : FylioPalette.paleBlue, in: Capsule())
            }
            .foregroundStyle(selectedTab == idx ? .white : FylioPalette.nightText)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(selectedTab == idx ? AnyShapeStyle(FylioTokens.sendGradient) : AnyShapeStyle(.ultraThinMaterial), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(selectedTab == idx ? 0.25 : 0.55), lineWidth: 1))
        }.buttonStyle(FylioPressStyle(haptic: false))
    }

    // MARK: Photos système (PhotoKit)
    private var systemPhotosSection: some View {
        Group {
            if authStatus == .denied || authStatus == .restricted {
                VStack(spacing: 14) {
                    Image(systemName: "photo.on.rectangle.angled").font(.system(size: 44))
                        .foregroundStyle(.white.opacity(0.9))
                    Text("Autorise l'accès aux photos pour voir ta galerie ici.")
                        .font(.system(size: 15, weight: .medium)).foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center).padding(.horizontal, 24)
                    Button("Ouvrir les réglages") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(FylioPalette.nightText)
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(Color.white.opacity(0.92), in: Capsule())
                }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(.top, 40)
            } else if isLoading {
                ProgressView().tint(.white).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if photoItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "photo").font(.system(size: 44)).foregroundStyle(.white.opacity(0.85))
                    Text(String(localized: "gallery.empty.title")).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                    Text(String(localized: "gallery.empty.subtitle")).font(.system(size: 13)).foregroundStyle(.white.opacity(0.82))
                        .multilineTextAlignment(.center).padding(.horizontal, 24)
                }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(.top, 40)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                        ForEach(photoItems) { item in
                            GalleryPhotoCell(item: item) {
                                if let url = item.fileURL { app.openFile(FylioFileItem(name: item.id.uuidString, sizeBytes: 0, contentType: "public.image", fileURL: url)) }
                            }
                        }
                    }.padding(.horizontal, 12).padding(.vertical, 12)
                }
            }
        }
    }

    private var fylioSection: some View {
        Group {
            if fylioImages.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "photo").font(.system(size: 44)).foregroundStyle(.white.opacity(0.85))
                    Text("Aucune image Fylio pour le moment").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(.top, 40)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                        ForEach(fylioImages) { file in
                            if let url = file.fileURL, let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                                Image(uiImage: img).resizable().scaledToFill().frame(height: 120).clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .onTapGesture { app.openFile(file) }
                            }
                        }
                    }.padding(.horizontal, 12).padding(.vertical, 12)
                }
            }
        }
    }

    private func loadPhotosIfNeeded(force: Bool = false) async {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        authStatus = status
        if status == .notDetermined {
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            authStatus = newStatus
        }
        guard authStatus == .authorized || authStatus == .limited else { isLoading = false; return }
        isLoading = true
        let fetched = await GalleryPhotoLoader.load(limit: 120)
        photoItems = fetched
        isLoading = false
    }
}

struct GalleryPhoto: Identifiable {
    let id: UUID
    let asset: PHAsset
    var fileURL: URL? {
        // PHAsset → fichier temporaire via PHImageManager (pour preview)
        nil
    }
}

private struct GalleryPhotoCell: View {
    let item: GalleryPhoto
    var onTap: () -> Void
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.14))
            if let image {
                Image(uiImage: image).resizable().scaledToFill().frame(height: 120).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                ProgressView().tint(.white.opacity(0.7))
            }
        }
        .frame(height: 120)
        .onAppear { load() }
        .onTapGesture { onTap() }
    }

    private func load() {
        let manager = PHImageManager.default()
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .opportunistic
        opts.isSynchronous = false
        manager.requestImage(for: item.asset, targetSize: CGSize(width: 260, height: 260), contentMode: .aspectFill, options: opts) { img, _ in
            if let img { self.image = img }
        }
    }
}

private enum GalleryPhotoLoader {
    static func load(limit: Int) async -> [GalleryPhoto] {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let opts = PHFetchOptions()
                opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                opts.fetchLimit = limit
                let result = PHAsset.fetchAssets(with: .image, options: opts)
                var items: [GalleryPhoto] = []
                result.enumerateObjects { asset, _, _ in
                    items.append(GalleryPhoto(id: UUID(), asset: asset))
                }
                cont.resume(returning: items)
            }
        }
    }
}
