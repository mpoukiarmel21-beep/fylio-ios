import SwiftUI

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