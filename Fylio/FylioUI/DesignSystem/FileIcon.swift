import SwiftUI
import QuickLook

// MARK: - Icône de fichier (doc 25 : FileIcon) — SF Symbol selon l'UTI.

public struct FileIcon: View {
    public let contentType: String
    public let size: CGFloat

    public init(contentType: String, size: CGFloat) {
        self.contentType = contentType
        self.size = size
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(FylioPalette.paleBlue.opacity(0.5))
            Image(systemName: symbol)
                .font(.system(size: size * 0.46))
                .foregroundStyle(FylioPalette.electricBlue)
        }
        .frame(width: size, height: size)
    }

    private var symbol: String {
        switch contentType {
        case let t where t.contains("image"): return "photo"
        case let t where t.contains("movie") || t.contains("video"): return "film"
        case let t where t.contains("audio"): return "music.note"
        case let t where t.contains("pdf"): return "doc.richtext"
        case let t where t.contains("com.apple.iwork") || t.contains("microsoft")
            || t.contains("opendocument"): return "doc.text"
        default: return "doc"
        }
    }
}

// MARK: - Aperçu de fichier (QuickLook) — doc 14 : FilePreviewSheet

struct FilePreviewSheet: View {
    let file: FylioFileItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let url = file.fileURL {
                    PreviewController(url: url)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "questionmark.folder")
                            .font(.system(size: 48))
                            .foregroundStyle(FylioPalette.secondaryText)
                        Text(file.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(FylioPalette.nightText)
                    }
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
}

private struct PreviewController: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return UINavigationController(rootViewController: controller)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

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