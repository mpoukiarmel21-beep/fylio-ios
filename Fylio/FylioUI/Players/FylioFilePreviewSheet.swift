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