import Foundation

// MARK: - Palier 4B : Pack invisible (TAR STORE) — qualidade bit-perfect
// Vidéo/mp4 déjà compressée → on ne recompresse pas (STORE, pas DEFLATE).
// Flux : fichiers → header TAR 512B par fichier + données → chunks ChaCha20.
// À la réception : dé-TAR en mémoire, dossiers recréés, fichiers écrits.

public enum FylioPack {

    // Header TAR ustar 512B minimal (POSIX) — suffisant pour reconstitution.
    private static func tarHeader(name: String, size: Int64) -> Data {
        var h = Data(count: 512)
        func write(_ s: String, at offset: Int, length: Int) {
            let b = Array(s.utf8.prefix(length))
            for (i, c) in b.enumerated() { h[offset + i] = c }
        }
        func writeOctal(_ v: Int64, at offset: Int, length: Int) {
            let s = String(format: "%0\(length - 1)lo", v)
            write(s, at: offset, length: length - 1)
        }
        let safeName = String(name.prefix(100))
        write(safeName, at: 0, length: 100)
        writeOctal(0o644, at: 100, length: 8)
        writeOctal(0, at: 108, length: 8)
        writeOctal(0, at: 116, length: 8)
        writeOctal(size, at: 124, length: 12)
        writeOctal(Int64(Date().timeIntervalSince1970), at: 136, length: 12)
        h[156] = UInt8(ascii: "0") // type regular file
        write("ustar", at: 257, length: 6)
        // checksum
        var sum: Int = 0
        for i in 0..<512 { sum += Int(h[i]) }
        // champ checksum = 8 bytes "      \0" pendant calcul, on remplace
        let chk = String(format: "%06o", sum)
        write(chk, at: 148, length: 6)
        h[154] = 32; h[155] = 32
        return h
    }

    /// Packe plusieurs fichiers en un seul Data TAR (STORE). Appelé en arrière-plan.
    public static func pack(files: [FylioFileItem]) throws -> Data {
        var out = Data()
        for file in files {
            guard let url = file.fileURL,
                  let fh = try? FileHandle(forReadingFrom: url) else { continue }
            defer { try? fh.close() }
            let size = Int64(try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int ?? 0)
            let name = file.relativePath.isEmpty ? file.name : "\(file.relativePath)/\(file.name)"
            out.append(tarHeader(name: name, size: size))
            // Données
            if size > 0 {
                let data = fh.readDataToEndOfFile()
                out.append(data)
                let pad = (512 - (Int(size) % 512)) % 512
                if pad > 0 { out.append(Data(count: pad)) }
            }
        }
        out.append(Data(count: 1024)) // 2 blocs nuls fin TAR
        return out
    }

    /// Dépaquète un Data TAR vers un dossier (reconstitution invisible).
    @discardableResult
    public static func unpack(data: Data, to destination: URL) throws -> [URL] {
        var urls: [URL] = []
        var offset = 0
        let fm = FileManager.default
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)

        while offset + 512 <= data.count {
            let header = data[offset..<(offset + 512)]
            if header.allSatisfy({ $0 == 0 }) { break } // fin
            let nameData = header[0..<100]
            let nameEnd = nameData.firstIndex(of: 0) ?? nameData.endIndex
            let name = String(bytes: nameData[..<nameEnd], encoding: .utf8) ?? ""
            if name.isEmpty { offset += 512; continue }
            // size octal à 124, 12 bytes
            let sizeStr = String(bytes: header[124..<136], encoding: .ascii)?
                .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\0"))) ?? "0"
            let size = Int64(sizeStr, radix: 8) ?? 0
            offset += 512
            if name.hasSuffix("/") {
                try fm.createDirectory(at: destination.appendingPathComponent(name), withIntermediateDirectories: true)
            } else if size >= 0, offset + Int(size) <= data.count {
                let fileData = data[offset..<(offset + Int(size))]
                let fileURL = destination.appendingPathComponent(name)
                try fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data(fileData).write(to: fileURL)
                urls.append(fileURL)
            }
            let blocks = (Int(size) + 511) / 512
            offset += blocks * 512
        }
        return urls
    }
}
