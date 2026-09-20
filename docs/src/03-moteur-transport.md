## §5 — `FylioCore/FylioTransport.swift` — **VERSION CORRIGÉE**

```swift
import Foundation
import Network

/// Transport TCP chiffré (D06-bis).
/// Deux modes :
///  - mDNS appairé : TLS 1.3 natif via NWParameters(tls:) (empreinte épinglée
///    au premier appairage via sec_protocol_verify).
///  - QR : TCP + chiffrement AEAD maison par trame (clé de session ECDH).
/// Zéro canal en clair (M4). Reprise : le receveur annonce ses octets reçus (D16).

public actor FylioTransport {
    public enum TransportError: Error {
        case notConnected, connectionFailed(String)
        case protocolError(String), cancelled, streamClosed
    }

    private var connection: NWConnection?

    public init() {}

    // MARK: - Connexion

    /// Connexion sortante (émetteur → receveur).
    public func connect(to peer: FylioPeer,
                        parameters: NWParameters? = nil) async throws {
        let params = parameters ?? NWParameters.tls
        let conn = NWConnection(host: NWEndpoint.Host(peer.host),
                                 port: NWEndpoint.Port(rawValue: peer.port)!,
                                 using: params)
        try await establish(conn)
        self.connection = conn
    }

    /// Adopte une connexion entrante provenant d'un NWListener.
    public func adopt(_ conn: NWConnection) async throws {
        try await establish(conn)
        self.connection = conn
    }

    private func establish(_ conn: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            var resumed = false
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if !resumed { resumed = true; cont.resume() }
                case .failed(let err):
                    if !resumed {
                        resumed = true
                        cont.resume(throwing: TransportError.connectionFailed(err.localizedDescription))
                    }
                case .waiting(let err):
                    NSLog("[FylioTransport] waiting: \(err)")
                default:
                    break
                }
            }
            conn.start(queue: .global(qos: .userInitiated))
        }
    }

    // MARK: - Trames de contrôle (longueur + payload)

    /// Envoie une trame : [u32 longueur][payload].
    public func send(_ data: Data) async throws {
        var frame = Data(capacity: 4 + data.count)
        var len = UInt32(data.count).bigEndian
        withUnsafeBytes(of: &len) { frame.append(contentsOf: $0) }
        frame.append(data)
        try await sendRaw(frame)
    }

    /// Reçoit une trame complète : [u32 longueur][payload].
    public func receive() async throws -> Data {
        let lenData = try await receiveRaw(4)
        let len = lenData.reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
        guard len <= FylioFrameCodec.maxControlFrame else {
            throw TransportError.protocolError("frame too large: \(len)")
        }
        return try await receiveRaw(Int(len))
    }

    // MARK: - Blocs chiffrés (mode QR, AEAD par bloc)

    /// Envoie un bloc : [u32 taille totale][header(56)][nonce(12)][tag(16)][ciphertext].
    public func sendBlock(_ header: FylioBlockHeader,
                           payload: Data,
                           key: SymmetricKey) async throws {
        let hdr = FylioFrameCodec.encodeBlockHeader(header)
        let sealed = try FylioCrypto.seal(payload, key: key)

        let bodySize = hdr.count + sealed.nonce.count + sealed.tag.count + sealed.ciphertext.count
        var frame = Data(capacity: 4 + bodySize)
        var total = UInt32(bodySize).bigEndian
        withUnsafeBytes(of: &total) { frame.append(contentsOf: $0) }
        frame.append(hdr)
        frame.append(sealed.nonce)
        frame.append(sealed.tag)
        frame.append(sealed.ciphertext)
        try await sendRaw(frame)
    }

    /// Reçoit un bloc chiffré, vérifie le tag AEAD, retourne (header, payload clair).
    public func receiveBlock(key: SymmetricKey) async throws -> (FylioBlockHeader, Data) {
        let sizeData = try await receiveRaw(4)
        let size = sizeData.reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
        guard size > FylioFrameCodec.blockHeaderSize + 28,
              size <= UInt32(FylioFrameCodec.maxControlFrame) else {
            throw TransportError.protocolError("bad block frame size: \(size)")
        }
        let frame = try await receiveRaw(Int(size))

        let hdrData = frame.prefix(FylioFrameCodec.blockHeaderSize)
        let header = try FylioFrameCodec.decodeBlockHeader(Data(hdrData))

        let bodyStart = frame.index(frame.startIndex, offsetBy: FylioFrameCodec.blockHeaderSize)
        let nonceData = frame[bodyStart..<frame.index(bodyStart, offsetBy: 12)]
        let tagData   = frame[bodyStart+12..<frame.index(bodyStart, offsetBy: 28)]
        let ctData    = frame[frame.index(bodyStart, offsetBy: 28)...]

        let box = FylioCrypto.AEADBox(ciphertext: Data(ctData),
                                      tag: Data(tagData),
                                      nonce: Data(nonceData))
        let payload = try FylioCrypto.open(box, key: key)
        return (header, payload)
    }

    // MARK: - I/O brut

    public func sendRaw(_ data: Data) async throws {
        guard let conn = connection else { throw TransportError.notConnected }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            conn.send(content: data, completion: .contentProcessed { error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume() }
            })
        }
    }

    /// Reçoit exactement `count` octets (reconstitue au fil de l'eau).
    public func receiveRaw(_ count: Int) async throws -> Data {
        guard let conn = connection else { throw TransportError.notConnected }
        var buffer = Data(capacity: count)
        while buffer.count < count {
            let remaining = count - buffer.count
            let chunk: Data = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
                conn.receive(minimumIncompleteLength: 1, maximumLength: remaining) { data, _, isComplete, error in
                    if let error { cont.resume(throwing: error) }
                    else if let data, !data.isEmpty { cont.resume(returning: data) }
                    else if isComplete { cont.resume(throwing: TransportError.streamClosed) }
                    else { cont.resume(returning: Data()) }
                }
            }
            if chunk.isEmpty { throw TransportError.streamClosed }
            buffer.append(chunk)
        }
        return buffer
    }

    public func close() {
        connection?.cancel()
        connection = nil
    }
}
```

**Corrections apportées par rapport au brouillon précédent :**
1. `send()` : parenthèse rétablie, réutilise `sendRaw` (plus de duplication).
2. `receiveBlock()` : lecture par taille explicite + découpage par index sûr (plus de `+56` magiques en vrac), constantes via `FylioFrameCodec.blockHeaderSize`.
3. Erreurs de frappe éliminées : `key` (et non `keyKey`), `withCheckedThrowingContinuation` (et non « Coroutination »), `streamClosed` (et non `notContinued`).
4. `receive()` reçoit d'abord exactement 4 octets via `receiveRaw(4)` — plus de référence à une connexion non protégée par acteur.
5. Continuations typées explicitement pour éviter toute ambiguïté de surcharge Swift 6.
