import Foundation

/// Plateformes supportées par le protocole Fylio.
public enum FylioPlatform: String, Codable, Sendable {
    case ios, android, windows, macos

    /// Nom d'asset image existant pour l'icône de plateforme (assets : device_iphone, device_android, device_computer).
    public var assetName: String {
        switch self {
        case .ios: return "device_iphone"
        case .android: return "device_android"
        case .windows: return "device_computer"
        case .macos: return "device_computer"
        }
    }
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
    /// Clé publique éphémère du pair transportée par le QR (BUG #4 — payable final).
    public var ephemeralPublicKey: String?

    public init(id: UUID, displayName: String, fylioNumber: String,
                avatarID: Int, platform: FylioPlatform,
                host: String, port: UInt16,
                fingerprint: String, isTrusted: Bool = false,
                lastSeen: Date = Date(),
                ephemeralPublicKey: String? = nil) {
        self.id = id; self.displayName = displayName
        self.fylioNumber = fylioNumber; self.avatarID = avatarID
        self.platform = platform; self.host = host; self.port = port
        self.fingerprint = fingerprint; self.isTrusted = isTrusted
        self.lastSeen = lastSeen
        self.ephemeralPublicKey = ephemeralPublicKey
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