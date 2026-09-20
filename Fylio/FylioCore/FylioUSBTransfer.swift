import Foundation
import UniformTypeIdentifiers

/// TRANSFERT PAR CÂBLE USB iPhone ↔ PC (mécanisme Apple-sanctionné).
/// Info.plist doit contenir : UIFileSharingEnabled + LSSupportsOpeningDocumentsInPlace.
/// Le conteneur Documents de Fylio est alors visible du PC (Explorateur Windows
/// → iPhone → Fylio, ou Finder sur macOS). Le PC dépose les fichiers dans Documents
/// (racine du conteneur) → Fylio les détecte et les importe dans sa galerie Reçu.
/// (BUG #5 corrigé : scan de la racine Documents, PAS Inbox.)
public actor FylioUSBTransfer {
    public enum USBState: Equatable, Sendable {
        case idle
        case detected(count: Int)      // fichiers détectés venant du PC
        case importing(progress: Double)
        case done(imported: Int)
        case failed(String)
    }

    private(set) public var state: USBState = .idle
    private let documentsURL: URL
    private var lastKnownFiles: Set<String> = []

    public init() {
        self.documentsURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Scan du conteneur : détecte les fichiers déposés par le PC via câble.
    /// (BUG #5 — source = racine Documents, dossier Fylio/ et Inbox/ exclus.)
    public func scanForPCDrops() -> Int {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: documentsURL, includingPropertiesForKeys: [.isDirectoryKey]) else {
            state = .idle
            return 0
        }
        let candidates = files.filter {
            $0.lastPathComponent != "Fylio" && $0.lastPathComponent != "Inbox"
                && !$0.hasDirectoryPath
        }
        let new = candidates.filter { !lastKnownFiles.contains($0.lastPathComponent) }
        lastKnownFiles = Set(candidates.map(\.lastPathComponent))
        state = new.isEmpty ? .idle : .detected(count: new.count)
        return new.count
    }

    /// Import des fichiers déposés par le PC → galerie Fylio (dossier Reçu).
    /// (BUG #5 — source = racine Documents, destination = Fylio/Recu.)
    public func importDroppedFiles() throws -> [FylioFileItem] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: documentsURL, includingPropertiesForKeys: [.isDirectoryKey]) else { return [] }

        let received = documentsURL.appendingPathComponent("Fylio/Recu", isDirectory: true)
        try fm.createDirectory(at: received, withIntermediateDirectories: true)

        let candidates = files.filter {
            $0.lastPathComponent != "Fylio" && $0.lastPathComponent != "Inbox"
                && !$0.hasDirectoryPath
        }

        var imported: [FylioFileItem] = []
        var progress: Double = 0
        state = .importing(progress: 0)
        let total = Double(max(1, candidates.count))

        for url in candidates {
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            let destination = received.appendingPathComponent(url.lastPathComponent)
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.moveItem(at: url, to: destination)
            imported.append(FylioFileItem(
                name: url.lastPathComponent,
                sizeBytes: Int64(size),
                relativePath: "",
                contentType: UTType(filenameExtension: url.pathExtension)?
                    .identifier ?? "public.data",
                fileURL: destination))
            progress += 1.0 / total
            state = .importing(progress: progress)
        }
        lastKnownFiles.removeAll()
        state = .done(imported: imported.count)
        return imported
    }
}