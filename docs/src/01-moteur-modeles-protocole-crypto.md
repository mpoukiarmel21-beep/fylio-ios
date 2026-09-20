# FYLIO — SOURCES BUNDLE 1 : MOTEUR DE TRANSFERT RÉEL (FylioCore)
**Projet : `Fylio/` (Xcode/VS Code) · Cible V1 : iOS (IPA) · Swift 6 / SwiftUI**
**Règle : 100 % code original. Zéro canal en clair. Protocole versionné. Reprise à l'octet. SHA-256 par bloc.**

Structure des fichiers dans le projet :
```
Fylio/
└── FylioCore/
    ├── FylioModels.swift        (§1)
    ├── FylioProtocol.swift      (§2)
    ├── FylioCrypto.swift        (§3)
    ├── FylioDiscovery.swift     (§4)
    ├── FylioTransport.swift     (§5)
    └── FylioSession.swift       (§6)
```

---

## §1 — `FylioCore/FylioModels.swift`

```swift
import Foundation

/// Plateformes supportées par le protocole Fylio.
public enum FylioPlatform: String, Codable, Sendable {
    case ios, android, windows, macos
}

/// Identité locale d'une installation Fylio.
public struct FylioIdentity: Codable, Sendable, Equatable {
    public let deviceID: UUID
    public var displayName: String          // ex. "iPhone d'Armel"
    public let fylioNumber: String          // ex. "Fylio-4827"
    public var avatarID: Int                // 1...6, ou -1 = photo perso
    public let platform: FylioPlatform
    public let publicKeyFingerprint: String // SHA-256 de la clé publique (hex, 8 octets affichés)

    public init(deviceID: UUID = UUID(),
                displayName: String,
                fylioNumber: String,
                avatarID: Int,
                platform: FylioPlatform,
                publicKeyFingerprint: String) {
        self.deviceID = deviceID
        self.displayName = displayName
        self.fylioNumber = fylioNumber
        self.avatarID = avatarID
        self.platform = platform
        self.publicKeyFingerprint = publicKeyFingerprint
    }
}

/// Un pair découvert sur le réseau (mDNS) ou via QR.
public struct FylioPeer: Identifiable, Hashable, Sendable {
    public let id: UUID                  // = deviceID du pair
    public var displayName: String
    public var fylioNumber: String
    public var avatarID: Int
    public var platform: FylioPlatform
    public var host: String              // hôte TCP (endpoint Network.framework)
    public var port: UInt16
    public var fingerprint: String       // empreinte clé publique (épinglage au 1er appairage)
    public var isTrusted: Bool           // appareil de confiance (auto-accept)
    public var lastSeen: Date

    public init(id: UUID, displayName: String, fylioNumber: String,
                avatarID: Int, platform: FylioPlatform,
                host: String, port: UInt16,
                fingerprint: String, isTrusted: Bool = false,
                lastSeen: Date = Date()) {
        self.id = id; self.displayName = displayName
        self.fylioNumber = fylioNumber; self.avatarID = avatarID
        self.platform = platform; self.host = host; self.port = port
        self.fingerprint = fingerprint; self.isTrusted = isTrusted
        self.lastSeen = lastSeen
    }
}

/// Un fichier à transférer, avec ses métadonnées.
public struct FylioFileItem: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var sizeBytes: Int64
    public var relativePath: String      // chemin relatif (dossiers) ou ""
    public var contentType: String       // UTI, ex. public.movie
    public var fileURL: URL?             // local uniquement (non codé sur le réseau)

    public init(id: UUID = UUID(), name: String, sizeBytes: Int64,
                relativePath: String = "", contentType: String,
                fileURL: URL? = nil) {
        self.id = id; self.name = name; self.sizeBytes = sizeBytes
        self.relativePath = relativePath; self.contentType = contentType
        self.fileURL = fileURL
    }
}

/// Un bloc du manifeste : index + empreinte SHA-256.
public struct FylioBlockManifest: Codable, Sendable {
    public let index: Int
    public let offset: Int64
    public let length: Int
    public let sha256: Data   // 32 octets
}

/// Manifeste complet d'un fichier (envoyé pendant le handshake, chiffré).
public struct FylioFileManifest: Codable, Sendable {
    public let fileID: UUID
    public let name: String
    public let sizeBytes: Int64
    public let relativePath: String
    public let contentType: String
    public let totalSHA256: Data
    public let blocks: [FylioBlockManifest]
}

/// État d'un transfert (UI + moteur).
public enum FylioTransferState: String, Codable, Sendable {
    case waitingAccept, preparing, transferring, paused
    case completed, failed, refused, cancelled
}

/// Progression consolidée d'une session.
public struct FylioProgress: Sendable, Equatable {
    public var bytesTransferred: Int64
    public var totalBytes: Int64
    public var speedBytesPerSec: Int64
    public var etaSeconds: Int?

    public var fraction: Double {
        totalBytes > 0 ? Double(bytesTransferred) / Double(totalBytes) : 0
    }
    public var percent: Int { Int((fraction * 100).rounded()) }

    public init(bytesTransferred: Int64 = 0, totalBytes: Int64 = 0,
                speedBytesPerSec: Int64 = 0, etaSeconds: Int? = nil) {
        self.bytesTransferred = bytesTransferred; self.totalBytes = totalBytes
        self.speedBytesPerSec = speedBytesPerSec; self.etaSeconds = etaSeconds
    }
}
```

---

## §2 — `FylioCore/FylioProtocol.swift`

```swift
import Foundation

/// Version du protocole Fylio — champ `proto` présent dans chaque trame (D15).
public enum FylioProtocolVersion: Int, Codable, Sendable { case v1 = 1 }

// MARK: - Trames de contrôle (JSON, chiffrées après handshake)

public struct FylioAnnounceFrame: Codable, Sendable {
    public let proto: FylioProtocolVersion
    public let sender: FylioIdentity
    public let sessionID: UUID
    public let totalFiles: Int
    public let totalBytes: Int64
    public let manifests: [FylioFileManifest]

    public init(proto: FylioProtocolVersion = .v1, sender: FylioIdentity,
                sessionID: UUID, totalFiles: Int, totalBytes: Int64,
                manifests: [FylioFileManifest]) {
        self.proto = proto; self.sender = sender
        self.sessionID = sessionID; self.totalFiles = totalFiles
        self.totalBytes = totalBytes; self.manifests = manifests
    }
}

public struct FylioConfirmFrame: Codable, Sendable {
    public let proto: FylioProtocolVersion
    public let sessionID: UUID
    public let accepted: Bool
    public let receivedBytesByFile: [UUID: Int64]   // reprise : octets déjà reçus par fichier

    public init(proto: FylioProtocolVersion = .v1, sessionID: UUID,
                accepted: Bool, receivedBytesByFile: [UUID: Int64] = [:]) {
        self.proto = proto; self.sessionID = sessionID
        self.accepted = accepted; self.receivedBytesByFile = receivedBytesByFile
    }
}

public struct FylioDoneFrame: Codable, Sendable {
    public let proto: FylioProtocolVersion
    public let sessionID: UUID
    public let allVerified: Bool

    public init(proto: FylioProtocolVersion = .v1, sessionID: UUID, allVerified: Bool) {
        self.proto = proto; self.sessionID = sessionID; self.allVerified = allVerified
    }
}

public struct FylioErrorFrame: Codable, Sendable {
    public let proto: FylioProtocolVersion
    public let sessionID: UUID
    public let code: String
    public let message: String

    public init(proto: FylioProtocolVersion = .v1, sessionID: UUID,
                code: String, message: String) {
        self.proto = proto; self.sessionID = sessionID
        self.code = code; self.message = message
    }
}

// MARK: - Bloc de données (binaire)
// Format sur le fil : [u32 fileID-hi][u32 fileID-lo][u32 blockIdx][u32 len][32B sha256][payload]

public struct FylioBlockHeader: Sendable {
    public let fileID: UUID
    public let blockIndex: Int
    public let length: Int
    public let sha256: Data
}

public enum FylioFrameCodec {
    public enum CodecError: Error {
        case frameTooLarge, truncated, badJSON, badBlockHeader
    }

    public static let maxControlFrame = 1 << 20      // 1 MiB max par trame de contrôle
    public static let blockHeaderLength = 48          // 16 (uuid) + 4 + 4 + 32 − attention : voir ci-dessous
    // En-tête de bloc réel : 16 (UUID brut) + 4 (index) + 4 (longueur) + 32 (sha256) = 56 octets.
    public static let blockHeaderSize = 56

    // MARK: Trames de contrôle

    public static func encodeControl<T: Encodable>(_ frame: T) throws -> Data {
        let json = try JSONEncoder().encode(frame)
        guard json.count <= maxControlFrame else { throw CodecError.frameTooLarge }
        var out = Data(capacity: 4 + json.count)
        var len = UInt32(json.count).bigEndian
        withUnsafeBytes(of: &len) { out.append(contentsOf: $0) }
        out.append(json)
        return out
    }

    public static func decodeControl<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        guard data.count >= 5 else { throw CodecError.truncated }
        let lenBE = data.prefix(4)
        let len = lenBE.reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
        guard len <= maxControlFrame else { throw CodecError.frameTooLarge }
        let jsonStart = data.index(data.startIndex, offsetBy: 4)
        let jsonEnd = data.index(jsonStart, offsetBy: Int(len))
        guard data.distance(from: jsonEnd, to: data.endIndex) >= 0 else { throw CodecError.truncated }
        return try JSONDecoder().decode(type, from: data[jsonStart..<jsonEnd])
    }

    // MARK: En-têtes de blocs

    public static func encodeBlockHeader(_ h: FylioBlockHeader) -> Data {
        var out = Data(capacity: blockHeaderSize)
        out.append(h.fileID.uuidBytes)
        var idx = UInt32(h.blockIndex).bigEndian
        withUnsafeBytes(of: &idx) { out.append(contentsOf: $0) }
        var len = UInt32(h.length).bigEndian
        withUnsafeBytes(of: &len) { out.append(contentsOf: $0) }
        out.append(h.sha256)
        return out
    }

    public static func decodeBlockHeader(_ data: Data) throws -> FylioBlockHeader {
        guard data.count == blockHeaderSize else { throw CodecError.badBlockHeader }
        var pos = data.startIndex
        let uuidData = data[pos..<data.index(pos, offsetBy: 16)]
        let fileID = uuidData.toUUID()
        pos = data.index(pos, offsetBy: 16)
        let idx = readU32BE(data, &pos)
        let len = readU32BE(data, &pos)
        let sha = Data(data[pos..<data.index(pos, offsetBy: 32)])
        return FylioBlockHeader(fileID: fileID, blockIndex: Int(idx),
                                length: Int(len), sha256: sha)
    }

    private static func readU32BE(_ data: Data, _ pos: inout Data.Index) -> UInt32 {
        var v: UInt32 = 0
        for _ in 0..<4 {
            v = (v << 8) | UInt32(data[pos])
            pos = data.index(after: pos)
        }
        return v
    }
}

extension UUID {
    /// 16 octets bruts de l'UUID.
    var uuidBytes: Data { withUnsafeBytes(of: uuid) { Data($0) } }
}

extension Data {
    /// Reconstitue un UUID depuis ses 16 octets bruts.
    func toUUID() -> UUID {
        var bytes = [UInt8](self)
        while bytes.count < 16 { bytes.append(0) }
        bytes.withUnsafeBufferPointer { buf in
            let u = buf.baseAddress!.withMemoryRebound(to: uuid_t.self, capacity: 1) { $0.pointee }
            return UUID(uuid: u)
        }
    }
}
```

---

## §3 — `FylioCore/FylioCrypto.swift`

```swift
import Foundation
import CryptoKit

/// Couche cryptographique Fylio (D06-bis).
/// - Paire Curve25519 (Keychain) : identité de l'appareil + secret partagé ECDH.
/// - Handshake QR : clé éphémère dérivée via HKDF → AES-GCM par session.
/// - TLS 1.3 (NWConnection) pour le mode mDNS appairé.
/// Zéro canal en clair, jamais (règle M4 de l'analyse concurrents).
public struct FylioCryptoError: Error, Equatable {
    public let code: String
}

public final class FylioCrypto: @unchecked Sendable {
    private let queue = DispatchQueue(label: "fylio.crypto")
    private var privateKey: Curve25519.KeyAgreement.PrivateKey

    /// Crée ou charge la paire de clés de l'appareil.
    public init(existingPrivateKey: Curve25519.KeyAgreement.PrivateKey? = nil) {
        self.privateKey = existingPrivateKey ?? Curve25519.KeyAgreement.PrivateKey()
    }

    public var publicKeyData: Data { privateKey.publicKey.rawRepresentation }

    /// Empreinte SHA-256 de la clé publique, affichée à l'utilisateur (épinglage).
    public var publicKeyFingerprint: String {
        let digest = SHA256.hash(data: publicKeyData)
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    /// Dérive une clé symétrique de session (ECDH + HKDF).
    public func sessionKey(peerPublicKey: Data, sessionSalt: Data) throws -> SymmetricKey {
        let peerKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: peerPublicKey).publicKey
        let shared = try privateKey.sharedSecretFromKeyAgreement(with: peerKey)
        return shared.hkdfDerivedSymmetricKey(using: SHA256.self,
                                              sharedInfo: Data("fylio-session-v1".utf8),
                                              outputByteCount: 32,
                                              salt: sessionSalt)
    }

    /// Clé QR : la paire éphémère est transportée dans le QR (publiques seules).
    public static func ephemeralPair() throws -> (Curve25519.KeyAgreement.PrivateKey, Data) {
        let priv = Curve25519.KeyAgreement.PrivateKey()
        return (priv, priv.publicKey.rawRepresentation)
    }

    // MARK: - AES-GCM

    public struct AEADBox: Sendable {
        public let ciphertext: Data
        public let tag: Data
        public let nonce: Data
    }

    public static func seal(_ plaintext: Data, key: SymmetricKey) throws -> AEADBox {
        let nonce = AES.GCM.Nonce()
        let sealed = try AES.GCM.seal(plaintext, using: key, nonce: nonce)
        guard let ct = sealed.combined else { throw FylioCryptoError(code: "seal-combined-nil") }
        return AEADBox(ciphertext: sealed.ciphertext, tag: sealed.tag, nonce: nonce.withUnsafeBytes { Data($0) })
    }

    public static func open(_ box: AEADBox, key: SymmetricKey) throws -> Data {
        let nonce = try AES.GCM.Nonce(data: box.nonce)
        let sealed = try AES.GCM.SealedBox(nonce: nonce, ciphertext: box.ciphertext, tag: box.tag)
        return try AES.GCM.open(sealed, using: key)
    }

    // MARK: - Intégrité

    public static func sha256(_ data: Data) -> Data { Data(SHA256.hash(data: data)) }

    /// Découpe un fichier en manifeste de blocs de 1 MiB + SHA-256 par bloc + total.
    public static func buildManifest(for file: FylioFileItem,
                                     blockSize: Int = 1 << 20) throws -> FylioFileManifest {
        guard let url = file.fileURL else { throw FylioCryptoError(code: "missing-file-url") }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var blocks: [FylioBlockManifest] = []
        var offset: Int64 = 0
        var totalHasher = SHA256()
        let length = try handle.seekToEnd()

        while offset < length {
            try handle.seek(toOffset: UInt64(offset))
            let chunk = try handle.read(upToCount: blockSize) ?? Data()
            let digest = SHA256.hash(data: chunk)
            blocks.append(.init(index: blocks.count, offset: offset