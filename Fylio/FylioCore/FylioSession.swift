import Foundation
import CryptoKit
import Network

/// Session de transfert Fylio (D16) : orchestre un transfert complet de bout en bout.
/// Handshake 3 phases : announce → confirm → transfer.
/// Reprise à l'octet (le receveur annonce ses octets reçus dans le confirm).
/// Pause / reprise / annulation. Progression temps réel vers l'UI.
/// Zéro transfert sans acceptation (règle M6), sauf appareil de confiance.

public actor FylioSession {
    public enum SessionError: Error {
        case refused, badFingerprint, cryptoFailure(String)
        case ioFailure(String), manifestMismatch, cancelled
    }

    // MARK: - Configuration

    public struct Config: Sendable {
        public var blockSize: Int
        public var progressInterval: TimeInterval

        public init(blockSize: Int = 1 << 20,
                    progressInterval: TimeInterval = 0.25) {
            self.blockSize = blockSize
            self.progressInterval = progressInterval
        }
    }

    // MARK: - État

    private let config: Config
    private let crypto: FylioCrypto
    private let transport = FylioTransport()
    private let sessionID = UUID()

    /// Exposé pour dériver la clé de session côté émetteur (mDNS).
    public var sessionIdentifier: UUID { sessionID }

    /// Clé de session par défaut (mode mDNS) : déterministe par session, les
    /// deux extrémités la dérivent identiquement. La confidentialité réelle
    /// est portée par TLS 1.3 ; cette couche AEAD ajoute la vérification d'intégrité.
    public static func defaultSessionKey(sessionID: UUID) -> SymmetricKey {
        SymmetricKey(data: SHA256.hash(
            data: Data("fylio-session-v1:\(sessionID.uuidString)".utf8)))
    }

    private var identity: FylioIdentity
    private var state: FylioTransferState = .preparing
    private var paused = false
    private var cancelled = false

    private var receivedBytes: Int64 = 0
    private var totalBytes: Int64 = 0
    private var speedSamples: [(Double, Int64)] = []

    private var progressCallback: (@Sendable (FylioProgress) -> Void)?
    private var stateCallback: (@Sendable (FylioTransferState) -> Void)?

    public init(config: Config = .init(),
                crypto: FylioCrypto,
                identity: FylioIdentity) {
        self.config = config
        self.crypto = crypto
        self.identity = identity
    }

    public func configure(onProgress: @escaping @Sendable (FylioProgress) -> Void,
                          onState: @escaping @Sendable (FylioTransferState) -> Void) {
        self.progressCallback = onProgress
        self.stateCallback = onState
    }

    private func setState(_ s: FylioTransferState) {
        state = s
        stateCallback?(s)
    }

    // MARK: - ÉMETTEUR

    /// Envoie une liste de fichiers vers un pair (après connexion établie).
    public func send(files: [FylioFileItem],
                     to peer: FylioPeer,
                     sessionKey key: SymmetricKey) async throws {
        setState(.preparing)
        totalBytes = files.reduce(Int64(0)) { $0 + $1.sizeBytes }

        // 1. Manifestes avec SHA-256 par bloc (intégrité M8)
        let manifests = try files.map {
            try FylioCrypto.buildManifest(for: $0, blockSize: config.blockSize)
        }

        // 2. Announce (D16 : annonce complète avant tout octet de donnée)
        let announce = FylioAnnounceFrame(sender: identity,
                                           sessionID: sessionID,
                                           totalFiles: manifests.count,
                                           totalBytes: totalBytes,
                                           manifests: manifests)
        try await transport.send(try FylioFrameCodec.encodeControl(announce))

        // 3. Confirm (acceptation + carte de reprise)
        let confirmData = try await transport.receive()
        let confirm = try FylioFrameCodec.decodeControl(FylioConfirmFrame.self, from: confirmData)
        guard confirm.accepted else {
            setState(.refused)
            throw SessionError.refused
        }
        let resumeMap = confirm.receivedBytesByFile

        // 4. Transfert
        setState(.transferring)
        for (file, manifest) in zip(files, manifests) {
            if cancelled { setState(.cancelled); throw SessionError.cancelled }
            try await sendFile(file, manifest: manifest,
                               resumeFrom: resumeMap[file.id] ?? 0, key: key)
        }

        // 5. Done
        try await transport.send(try FylioFrameCodec.encodeControl(
            FylioDoneFrame(sessionID: sessionID, allVerified: true)))
        setState(.completed)
    }

    private func sendFile(_ file: FylioFileItem,
                          manifest: FylioFileManifest,
                          resumeFrom: Int64,
                          key: SymmetricKey) async throws {
        guard let url = file.fileURL else {
            throw SessionError.ioFailure("missing file URL")
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        for block in manifest.blocks where block.offset >= resumeFrom {
            if cancelled { throw SessionError.cancelled }
            while paused {
                try await Task.sleep(nanoseconds: 200_000_000)
            }
            try handle.seek(toOffset: UInt64(block.offset))
            let chunk = try handle.read(upToCount: block.length) ?? Data()
            let header = FylioBlockHeader(fileID: file.id,
                                          blockIndex: block.index,
                                          length: chunk.count,
                                          sha256: FylioCrypto.sha256(chunk))
            try await transport.sendBlock(header, payload: chunk, key: key)
            receivedBytes += Int64(chunk.count)
            reportProgress()
        }
    }

    // MARK: - RECEVEUR

    /// Accepte une session entrante sur une connexion déjà établie.
    /// `keyResolver` est évalué après réception de l'annonce (il connaît alors le
    /// sessionID émis par le pair) : mode mDNS → clé déterministe de session,
    /// mode QR → ECDH via la clé éphémère scannée.
    /// `onIncoming` = décision de l'utilisateur (ou auto si appareil de confiance).
    func acceptIncoming(on conn: NWConnection,
                               keyResolver: @escaping (UUID) throws -> SymmetricKey,
                               storage: FylioStorage,
onIncoming: @escaping @Sendable (
                        _ sender: FylioIdentity,
                        _ manifests: [FylioFileManifest],
                        _ totalBytes: Int64) async -> Bool) async throws {
        try await transport.adopt(conn)
        setState(.waitingAccept)

        // 1. Announce
        let announceData = try await transport.receive()
        let announce = try FylioFrameCodec.decodeControl(FylioAnnounceFrame.self, from: announceData)
        self.totalBytes = announce.totalBytes
        let key = try keyResolver(announce.sessionID)

        // 2. Décision (M6 : confirmation obligatoire sauf confiance)
        let accepted = await onIncoming(announce.sender, announce.manifests, announce.totalBytes)
        let confirm = FylioConfirmFrame(sessionID: announce.sessionID,
                                        accepted: accepted,
                                        receivedBytesByFile: storage.partialReceipts[announce.sessionID] ?? [:])
        try await transport.send(try FylioFrameCodec.encodeControl(confirm))
        guard accepted else { setState(.refused); return }

        // 3. Réception + vérification SHA-256 par bloc et globale (M8)
        setState(.transferring)
        var allVerified = true
        for manifest in announce.manifests {
            do {
                try await receiveFile(manifest: manifest, key: key, storage: storage)
            } catch {
                allVerified = false
                let err = FylioErrorFrame(sessionID: announce.sessionID,
                                          code: "receive-failed",
                                          message: String(describing: error))
                try? await transport.send(try FylioFrameCodec.encodeControl(err))
                break
            }
        }
        try await transport.send(try FylioFrameCodec.encodeControl(
            FylioDoneFrame(sessionID: announce.sessionID, allVerified: allVerified)))
        setState(allVerified ? .completed : .failed)
    }

    private func receiveFile(manifest: FylioFileManifest,
                             key: SymmetricKey,
                             storage: FylioStorage) async throws {
        let destination = try storage.prepareReceivedFile(for: manifest)
        let handle = try FileHandle(forWritingTo: destination)
        defer { try? handle.close() }

        for expected in manifest.blocks {
            let (header, payload) = try await transport.receiveBlock(key: key)
            guard header.fileID == manifest.fileID else { throw SessionError.manifestMismatch }
            guard FylioCrypto.sha256(payload) == expected.sha256 else {
                throw SessionError.manifestMismatch
            }
            try handle.seek(toOffset: UInt64(expected.offset))
            try handle.write(contentsOf: payload)
            receivedBytes += Int64(payload.count)
            reportProgress()
        }
        // Vérification du hash total du fichier
        guard try FylioCrypto.sha256OfFile(destination) == manifest.totalSHA256 else {
            throw SessionError.manifestMismatch
        }
        try storage.finalizeReceivedFile(manifest: manifest, at: destination)
    }

    // MARK: - Contrôles

    public func pause() { paused = true; setState(.paused) }
    public func resumeTransfer() { paused = false; setState(.transferring) }
    public func cancel() {
        cancelled = true; paused = false
        setState(.cancelled)
        Task { await transport.close() }
    }

    // MARK: - Progression

    private func reportProgress() {
        let now = Date().timeIntervalSince1970
        speedSamples.append((now, receivedBytes))
        while let first = speedSamples.first, now - first.0 > 2.0 {
            speedSamples.removeFirst()
        }
        var speed: Int64 = 0
        if let first = speedSamples.first {
            let dt = max(0.001, now - first.0)
            speed = Int64((Double(receivedBytes - first.1) / dt).rounded())
        }
        var eta: Int? = nil
        if speed > 0 { eta = Int((Double(totalBytes - receivedBytes) / Double(speed)).rounded()) }
        progressCallback?(FylioProgress(bytesTransferred: receivedBytes,
                                        totalBytes: totalBytes,
                                        speedBytesPerSec: speed,
                                        etaSeconds: eta))
    }
}