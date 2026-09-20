import Foundation
import Security
import UniformTypeIdentifiers

// MARK: - Stockage fichiers (conteneur app : Reçu / Envoyé + index)

final class FylioStorage: @unchecked Sendable {
    private let fileManager = FileManager.default
    private let receivedDir: URL
    private let sentDir: URL
    private let queue = DispatchQueue(label: "fylio.storage")

    /// sessionID → (fileID → octets reçus) — reprise à l'octet.
    var partialReceipts: [UUID: [UUID: Int64]] = [:]

    init() {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        receivedDir = docs.appendingPathComponent("Fylio/Recu", isDirectory: true)
        sentDir = docs.appendingPathComponent("Fylio/Envoye", isDirectory: true)
        try? fileManager.createDirectory(at: receivedDir, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: sentDir, withIntermediateDirectories: true)
    }

    var receivedDirectory: URL { receivedDir }
    var sentDirectory: URL { sentDir }

    // MARK: Fichiers

    func loadAllFiles() -> [FylioFileItem] {
        var items: [(item: FylioFileItem, date: Date?)] = []
        for dir in [receivedDir, sentDir] {
            guard let files = try? fileManager.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]) else { continue }
            for url in files {
                let values = try? url.resourceValues(forKeys: [.fileSizeKey,
                                                               .contentModificationDateKey])
                items.append((FylioFileItem(
                    name: url.lastPathComponent,
                    sizeBytes: Int64(values?.fileSize ?? 0),
                    relativePath: "",
                    contentType: UTType(filenameExtension: url.pathExtension)?
                        .identifier ?? "public.data",
                    fileURL: url),
                    values?.contentModificationDate))
            }
        }
        return items
            .sorted { ($0.date ?? Date.distantPast) > ($1.date ?? Date.distantPast) }
            .map(\.item)
    }

    func importFiles(_ urls: [URL]) {
        for url in urls {
            let destination = sentDir.appendingPathComponent(url.lastPathComponent)
            let secured = url.startAccessingSecurityScopedResource()
            defer { if secured { url.stopAccessingSecurityScopedResource() } }
            try? fileManager.copyItem(at: url, to: destination)
        }
    }

    func createFolder(named name: String) {
        let folder = receivedDir.appendingPathComponent(name, isDirectory: true)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    func deleteFile(_ file: FylioFileItem) {
        guard let url = file.fileURL else { return }
        try? fileManager.removeItem(at: url)
    }

    func deleteAllFiles() {
        for dir in [receivedDir, sentDir] {
            guard let files = try? fileManager.contentsOfDirectory(at: dir,
                                                                   includingPropertiesForKeys: nil) else { continue }
            for url in files { try? fileManager.removeItem(at: url) }
        }
    }

    // MARK: Réception (reprise à l'octet)

    func prepareReceivedFile(for manifest: FylioFileManifest) throws -> URL {
        let destination = receivedDir.appendingPathComponent(manifest.name)
        fileManager.createFile(atPath: destination.path, contents: nil)
        return destination
    }

    func finalizeReceivedFile(manifest: FylioFileManifest, at destination: URL) throws {
        partialReceipts[manifest.fileID] = nil
    }

    func removeKnownDevice(_ peer: FylioPeer) {}
    func clearHistory() {}
}

// MARK: - Keychain (identité, avatar, onboarding, clé privée — jamais sur GitHub)

enum FylioKeychain {
    private static let service = "ai.fylio.app"

    private static func set(_ data: Data, forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        SecItemAdd(attributes as CFDictionary, nil)
    }

    private static func get(_ key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    static func saveIdentity(_ identity: FylioIdentity) {
        if let data = try? JSONEncoder().encode(identity) { set(data, forKey: "identity") }
    }
    static func loadIdentity() -> FylioIdentity? {
        guard let data = get("identity") else { return nil }
        return try? JSONDecoder().decode(FylioIdentity.self, from: data)
    }

    static func saveAvatarPhoto(_ data: Data?) {
        set(data ?? Data(), forKey: "avatarPhoto")
    }
    static func loadAvatarPhoto() -> Data? {
        guard let data = get("avatarPhoto"), !data.isEmpty else { return nil }
        return data
    }

    static func markOnboardingComplete() { set(Data([1]), forKey: "onboarded") }
    static func hasCompletedOnboarding() -> Bool { (get("onboarded")?.first ?? 0) == 1 }

    static func savePrivateKey(_ keyData: Data) { set(keyData, forKey: "devicePrivateKey") }
    static func loadPrivateKey() -> Data? { get("devicePrivateKey") }
}