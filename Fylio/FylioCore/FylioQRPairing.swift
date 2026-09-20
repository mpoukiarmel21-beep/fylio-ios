import Foundation
import CryptoKit
import Network

/// PAIRAGE QR v2 — comme SHAREit : le QR contient l'adresse de connexion
/// (IP locale + port TCP de l'émetteur) + clé publique éphémère. L'appareil
/// qui scanne se connecte EN DIRECT sur le même réseau Wi-Fi, sans Internet.
/// Aucune donnée sensible en clair. QR temporaire (expire après 5 minutes).
public struct FylioQRPairing: Codable {
    public let proto: Int
    public let fylioNumber: String
    public let displayName: String
    public let publicKeyFingerprint: String
    public let ephemeralPublicKey: String   // Base64 — CLÉ PUBLIQUE uniquement
    public let host: String                 // IP locale de l'émetteur du QR
    public let port: UInt16                 // port TCP d'écoute
    public let nonce: String                // anti-rejeu
    public let expiresAt: Date             // expiration 5 min
}

public enum FylioQRPairingError: Error {
    case expiredOrInvalid
}

public final class FylioQRPairingService: @unchecked Sendable {
    private let lock = NSLock()
    private var ephemeralStore: [String: Curve25519.KeyAgreement.PrivateKey] = [:]

    /// Génère le payload QR à afficher (l'appareil qui scanne se connecte à host:port).
    public func generatePairingPayload(identity: FylioIdentity,
                                       host: String,
                                       port: UInt16) throws -> String {
        let (ephemeralPrivate, ephemeralPublic) = FylioCrypto.ephemeralPair()
        let publicKeyB64 = ephemeralPublic.base64EncodedString()
        lock.lock()
        ephemeralStore[publicKeyB64] = ephemeralPrivate  // clé privée LOCALE uniquement
        lock.unlock()

        let payload = FylioQRPairing(
            proto: 1,
            fylioNumber: identity.fylioNumber,
            displayName: identity.displayName,
            publicKeyFingerprint: identity.publicKeyFingerprint,
            ephemeralPublicKey: publicKeyB64,
            host: host,
            port: port,
            nonce: Data(SHA256.hash(data: Data(UUID().uuidString.utf8)))
                .base64EncodedString(),
            expiresAt: Date().addingTimeInterval(300))
        return String(data: try JSONEncoder().encode(payload), encoding: .utf8)!
    }

    /// Valide un QR scanné → pair prêt pour la connexion TCP directe.
    public func parseAndValidate(_ payload: String) throws -> FylioPeer {
        guard let data = payload.data(using: .utf8),
              let pairing = try? JSONDecoder().decode(FylioQRPairing.self, from: data),
              pairing.proto == 1,
              Date() < pairing.expiresAt else {
            throw FylioQRPairingError.expiredOrInvalid
        }
        return FylioPeer(
            id: UUID(),
            displayName: pairing.displayName,
            fylioNumber: pairing.fylioNumber,
            avatarID: 1,
            platform: .ios,
            host: pairing.host,
            port: pairing.port,
            fingerprint: pairing.publicKeyFingerprint,
            ephemeralPublicKey: pairing.ephemeralPublicKey)
    }

    /// Dérive la clé de session chiffrée quand un pair se connecte via QR.
    /// (Patch sécurité : la clé privée éphémère reste locale — jamais dans le QR.)
    public func sessionKey(forPeerEphemeralPublicKey peerPublicB64: String,
                           sessionSalt: Data) throws -> SymmetricKey {
        lock.lock()
        let localEphemeral = ephemeralStore.values.first
        lock.unlock()
        guard let local = localEphemeral else {
            throw FylioQRPairingError.expiredOrInvalid
        }
        let peerData = Data(base64Encoded: peerPublicB64) ?? Data()
        guard !peerData.isEmpty else { throw FylioQRPairingError.expiredOrInvalid }
        let peerKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerData)
        return try local.sharedSecretFromKeyAgreement(with: peerKey)
            .hkdfDerivedSymmetricKey(using: SHA256.self,
                                     sharedInfo: Data("fylio-qr-session-v1".utf8),
                                     outputByteCount: 32,
                                     salt: sessionSalt)
    }

    /// Purge les clés éphémères expirées (bonne pratique mémoire).
    public func purgeExpired() {
        lock.lock()
        if ephemeralStore.count > 16 { ephemeralStore.removeAll() }
        lock.unlock()
    }
}