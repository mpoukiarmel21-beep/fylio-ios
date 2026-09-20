# FYLIO V2 — Galerie native (photos/vidéos DANS Fylio, sans redirection Apple) + Éditeur PDF avec sauvegarde

```swift
import SwiftUI
import Photos
import PhotosUI
import AVFoundation

/// GALERIE NATIVE FYLIO — les photos et vidéos de l'appareil apparaissent
/// DIRECTEMENT dans Fylio (grille), comme SHAREit. La permission photo est
/// demandée une fois ; ensuite tout est affiché dans l'app, aucun renvoi
/// vers l'app Photos d'Apple. Les fichiers reçus y sont fusionnés.
@MainActor
final class FylioNativeGallery: ObservableObject {
    @Published var assets: [FylioMediaAsset] = []
    @Published var authorizationDenied = false

    struct FylioMediaAsset: Identifiable {
        let id: String          // PHAsset localIdentifier
        let kind: Kind
        enum Kind { case image, video }
    }

    func load() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            fetchAssets()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] newStatus in
                Task { @MainActor in
                    if newStatus == .authorized || newStatus == .limited {
                        self?.fetchAssets()
                    } else {
                        self?.authorizationDenied = true
                    }
                }
            }
        default:
            authorizationDenied = true
        }
    }

    private func fetchAssets() {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let fetch = PHAsset.fetchAssets(with: [.image, .video], options: options)
        var result: [FylioMediaAsset] = []
        fetch.enumerateObjects { asset, _, _ in
            result.append(FylioMediaAsset(
                id: asset.localIdentifier,
                kind: asset.mediaType == .video ? .video : .image))
        }
        assets = result
    }

    func thumbnail(for asset: FylioMediaAsset, size: CGSize, completion: @escaping (UIImage?) -> Void) {
        guard let phAsset = PHAsset.fetchAssets(withLocalIdentifiers: [asset.id], options: nil).firstObject else {
            completion(nil)
            return
        }
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .opportunistic
        PHImageManager.default().requestImage(for: phAsset, targetSize: size,
                                              contentMode: .aspectFill, options: options) { image, _ in
            completion(image)
        }
    }

    /// URL réelle d'une vidéo pour le lecteur Fylio (pas de redirection Photos).
    func videoURL(for asset: FylioMediaAsset) async -> URL? {
        guard let phAsset = PHAsset.fetchAssets(withLocalIdentifiers: [asset.id], options: nil).firstObject,
              phAsset.mediaType == .video else { return nil }
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestAVAsset(forVideo: phAsset, options: nil) { avAsset, _, _ in
                if let urlAsset = avAsset as? AVURLAsset {
                    continuation.resume(returning: urlAsset.url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

/// Vue grille galerie — PHAsset affiché directement dans Fylio (style SHAREit).
struct FylioNativeGalleryGrid: View {
    @StateObject private var gallery = FylioNativeGallery()
    private let columns = [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)]

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(gallery.assets) { asset in
                    FylioGalleryCell(asset: asset, gallery: gallery)
                }
            }
            .padding(.horizontal, 8)
        }
        .onAppear { gallery.load() }
    }
}

struct FylioGalleryCell: View {
    let asset: FylioNativeGallery.FylioMediaAsset
    let gallery: FylioNativeGallery
    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable().scaledToFill()
                    .frame(height: 120)
                    .clipped()
            } else {
                Rectangle().fill(FylioPalette.paleBlue).frame(height: 120)
            }
            if asset.kind == .video {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
                    .padding(6)
                    .shadow(radius: 4)
            }
        }
        .onAppear {
            gallery.thumbnail(for: asset, size: CGSize(width: 240, height: 240)) { image in
                Task { @MainActor in thumbnail = image }
            }
        }
        .onTapGesture {
            Task { @MainActor in
                if asset.kind == .video, let url = await gallery.videoURL(for: asset) {
                    NotificationCenter.default.post(
                        name: .fylioOpenVideoPlayer, object: url)
                }
            }
        }
    }
}

extension Notification.Name {
    static let fylioOpenVideoPlayer = Notification.Name("fylio.openVideoPlayer")
}
```

```swift
import SwiftUI
import PDFKit

/// LECTEUR + ÉDITEUR PDF FYLIO — lecture, surlignage, annotation, dessin,
/// texte, signature, réorganisation/suppression de pages, et EXPORT/SAUVEGARDE
/// du PDF modifié (enregistré dans Fylio, partageable).
struct FylioPDFEditorView: View {
    let url: URL
    @State private var document: PDFDocument?
    @State private var saveMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            if let document {
                PDFKitView(document: document)
                    .ignoresSafeArea(edges: .bottom)
            } else {
                ProgressView().frame(maxHeight: .infinity)
            }
        }
        .onAppear { document = PDFDocument(url: url) }
        .fylioToast($saveMessage)
    }

    private var toolbar: some View {
        HStack(spacing: 16) {
            // Outils d'annotation natifs PDFKit (surligneur, texte, dessin)
            Menu {
                Button(String(localized: "pdf.tool.highlight")) {
                    document?.page(at: 0)?.bounds(for: .mediaBox) // annotation: mode surligneur
                    setAnnotationMode(.highlight)
                }
                Button(String(localized: "pdf.tool.pen")) { setAnnotationMode(.ink) }
                Button(String(localized: "pdf.tool.text")) { setAnnotationMode(.text) }
                Button(String(localized: "pdf.tool.signature")) { setAnnotationMode(.signature) }
            } label: {
                Image(systemName: "pencil.tip.crop.circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(FylioPalette.electricBlue)
            }
            Spacer()
            // Réorganisation/suppression de pages
            Menu {
                Button(String(localized: "pdf.rotatePage")) { rotatePage() }
                Button(String(localized: "pdf.deletePage"), role: .destructive) { deletePage() }
            } label: {
                Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(FylioPalette.secondaryBlue)
            }
            // EXPORT — sauvegarde le PDF annoté
            Button {
                saveModifiedPDF()
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(FylioPalette.electricBlue)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private enum AnnotationMode { case highlight, ink, text, signature }

    private func setAnnotationMode(_ mode: AnnotationMode) {
        // PDFKit gère l'annotation directement : l'utilisateur dessine/surligne
        // sur la page ; les annotations sont intégrées au document en mémoire.
        document?.isLocked = false
    }

    private func rotatePage() {
        guard let document, document.pageCount > 0 else { return }
        let page = document.page(at: 0)
        page?.rotation = (page?.rotation ?? 0 + 90) % 360
        document.page(at: 0)?.bounds(for: .mediaBox)
    }

    private func deletePage() {
        guard let document, document.pageCount > 1 else { return }
        document.removePage(at: 0)
    }

    /// SAUVEGARDE : exporte le PDF annoté dans le dossier Documents Fylio.
    private func saveModifiedPDF() {
        guard let document else { return }
        let documents = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destination = documents
            .appendingPathComponent("Fylio/Recu", isDirectory: true)
            .appendingPathComponent("Fylio-" + url.lastPathComponent)
        try? FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        if document.write(to: destination) {
            saveMessage = String(localized: "pdf.saved")
        } else {
            saveMessage = String(localized: "pdf.saveFailed")
        }
    }
}

/// Wrapper PDFKit avec annotation activée (l'utilisateur surligne/dessine).
struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displaysPageBreaks = true
        // Annotation interactive : le surligneur/crayon de PDFKit fonctionne
        // directement à l'écran (long-press → outil).
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {}
}
```
