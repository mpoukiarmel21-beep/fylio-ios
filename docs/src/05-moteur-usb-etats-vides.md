# FYLIO V2 — `FylioCore/FylioUSBTransfer.swift` + `FylioUI/DesignSystem/FylioEmptyStateRegistry.swift`

```swift
import Foundation
import UniformTypeIdentifiers

/// TRANSFERT PAR CÂBLE USB iPhone ↔ PC (mécanisme Apple-sanctionné).
/// Info.plist doit contenir : UIFileSharingEnabled + LSSupportsOpeningDocumentsInPlace.
/// Le conteneur Documents de Fylio est alors visible du PC (Explorateur Windows
/// → iPhone → Fylio, ou Finder sur macOS). Le PC dépose les fichiers → iOS les
/// place dans Documents/Inbox → Fylio les détecte et les importe dans sa galerie.
/// C'est exactement le même mécanisme que SHAREit côté iPhone : iOS ne permet
/// pas d'accès USB direct au stockage complet (contrainte Apple documentée).
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
    public func scanForPCDrops() -> Int {
        let fm = FileManager.default
        let inbox = documentsURL.appendingPathComponent("Inbox", isDirectory: true)
        guard let files = try? fm.contentsOfDirectory(
            at: inbox, includingPropertiesForKeys: [.fileSizeKey]) else {
            state = .idle
            return 0
        }
        let newFiles = files.filter { !lastKnownFiles.contains($0.lastPathComponent) }
        lastKnownFiles = Set(files.map(\.lastPathComponent))
        state = newFiles.isEmpty ? .idle : .detected(count: newFiles.count)
        return newFiles.count
    }

    /// Import des fichiers déposés par le PC → galerie Fylio (dossier Reçu).
    public func importDroppedFiles() throws -> [FylioFileItem] {
        let fm = FileManager.default
        let inbox = documentsURL.appendingPathComponent("Inbox", isDirectory: true)
        guard let files = try? fm.contentsOfDirectory(
            at: inbox, includingPropertiesForKeys: [.fileSizeKey]) else { return [] }

        let received = documentsURL.appendingPathComponent("Fylio/Recu", isDirectory: true)
        try fm.createDirectory(at: received, withIntermediateDirectories: true)

        var imported: [FylioFileItem] = []
        var progress: Double = 0
        state = .importing(progress: 0)

        for url in files {
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
            progress += 1.0 / Double(max(1, files.count))
            state = .importing(progress: progress)
        }
        lastKnownFiles.removeAll()
        state = .done(imported: imported.count)
        return imported
    }
}
```

```swift
import SwiftUI

/// SYSTÈME D'ÉTATS VIDES DYNAMIQUES — registre centralisé.
/// Règle produit : dès qu'il n'y a NI transfert NI appareil, le personnage
/// d'état vide s'affiche (animé). Dès qu'un élément apparaît, le personnage
/// disparaît et laisse place à la vraie liste. Un seul registre pour toute
/// l'application → impossible d'utiliser le même personnage partout.
enum FylioEmptyStateRegistry {
    case recentDevices
    case transferHistory
    case files
    case gallery
    case music

    var character: String {
        switch self {
        case .recentDevices:   return "empty_recent_devices"   // asset 2
        case .transferHistory: return "empty_history_home"     // asset 3
        case .files:           return "empty_files"             // asset Fichiers
        case .gallery:         return "empty_gallery"           // asset Galerie 4
        case .music:           return "empty_music"             // asset Musique 5
        }
    }

    var titleKey: String {
        switch self {
        case .recentDevices:   return "devices.empty.title"
        case .transferHistory: return "history.empty.title"
        case .files:           return "files.empty.title"
        case .gallery:         return "gallery.empty.title"
        case .music:           return "music.empty.title"
        }
    }

    var subtitleKey: String {
        switch self {
        case .recentDevices:   return "devices.empty.subtitle"
        case .transferHistory: return "history.empty.subtitle"
        case .files:           return "files.empty.subtitle"
        case .gallery:         return "gallery.empty.subtitle"
        case .music:           return "music.empty.subtitle"
        }
    }
}

/// Wrapper SwiftUI : affiche l'état vide SI la collection est vide, sinon rien.
struct FylioEmptyStateSlot: View {
    let registry: FylioEmptyStateRegistry
    let isEmpty: Bool

    var body: some View {
        if isEmpty {
            FylioEmptyState(character: registry.character,
                            titleKey: registry.titleKey,
                            subtitleKey: registry.subtitleKey)
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
        }
    }
}
```
