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
        guard let decoded = try? JSONDecoder().decode(type, from: data[jsonStart..<jsonEnd]) else {
            throw CodecError.badJSON
        }
        return decoded
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
        return bytes.withUnsafeBufferPointer { buf in
            let u = buf.baseAddress!.withMemoryRebound(to: uuid_t.self, capacity: 1) { $0.pointee }
            return UUID(uuid: u)
        }
    }
}