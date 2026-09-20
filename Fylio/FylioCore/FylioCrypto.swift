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
        guard !peerPublicKey.isEmpty else {
            throw FylioCryptoError(code: "empty-peer-public-key")
        }
        let peerKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerPublicKey)
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
        guard let _ = sealed.combined else { throw FylioCryptoError(code: "seal-combined-nil") }
        return AEADBox(ciphertext: sealed.ciphertext, tag: sealed.tag,
                       nonce: nonce.withUnsafeBytes { Data($0) })
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
            blocks.append(.init(index: blocks.count, offset: offset,
                                length: chunk.count, sha256: Data(digest)))
            totalHasher.update(data: chunk)
            offset += Int64(chunk.count)
            if chunk.count < blockSize { break }
        }

        return FylioFileManifest(fileID: file.id, name: file.name,
                                 sizeBytes: file.sizeBytes,
                                 relativePath: file.relativePath,
                                 contentType: file.contentType,
                                 totalSHA256: Data(totalHasher.finalize()),
                                 blocks: blocks)
    }
}

// MARK: - Hachage de fichier complet

extension FylioCrypto {
    /// SHA-256 d'un fichier complet, lecture par morceaux de 1 MiB.
    public static func sha256OfFile(_ url: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return Data(hasher.finalize())
    }
}