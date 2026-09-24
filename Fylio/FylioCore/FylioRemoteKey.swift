import Foundation

// MARK: - Palier 4A : Clé 8 alphanum + sessions éphémères (TTL 10 min)
// Spec : A3K9-X7P2 (8 chars 62^8 = 218T, tiret visuel). 1 table Supabase
// sessions_ephemeres(cle TEXT PK, cle_publique TEXT, expires_at +10min).
// Sur appareil : génération locale + persist Supabase (REST) + lookup 2s.

public enum FylioRemoteKey {
    private static let charset = Array("ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz0123456789")
    // Sans I/O/l/1/0 pour lisibilité à la voix/WhatsApp.

    public static func generate() -> String {
        var s = ""
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<8 {
            s.append(charset.randomElement(using: &rng)!)
        }
        // Affichage avec tiret : A3K9-X7P2 (stockage sans tiret)
        return s
    }

    public static func display(_ raw: String) -> String {
        guard raw.count == 8 else { return raw }
        let a = raw.prefix(4), b = raw.suffix(4)
        return "\(a)-\(b)"
    }

    public static func normalized(_ input: String) -> String {
        input.replacingOccurrences(of: "-", with: "")
             .replacingOccurrences(of: " ", with: "")
             .trimmingCharacters(in: .whitespacesAndNewlines)
             .uppercased()
             // On garde alphanum, on mappe variantes : O→0 etc. non — strict
    }

    public static func isValid(_ raw: String) -> Bool {
        let n = normalized(raw)
        guard n.count == 8 else { return false }
        return n.allSatisfy { $0.isLetter || $0.isNumber }
    }
}

// MARK: - Session éphémère (Supabase REST — table sessions_ephemeres)

public struct FylioRemoteSession: Codable, Sendable {
    public let cle: String              // PK, 8 alphanum sans tiret, upper
    public let clePublique: String      // Ed25519 pubkey base64 (FylioCrypto)
    public let expiresAt: Date
    public let createdAt: Date

    public var displayKey: String { FylioRemoteKey.display(cle) }
    public var isExpired: Bool { Date() > expiresAt }

    enum CodingKeys: String, CodingKey {
        case cle = "cle"
        case clePublique = "cle_publique"
        case expiresAt = "expires_at"
        case createdAt = "created_at"
    }
}

public actor FylioRemoteService {
    private let supabaseURL: URL?
    private let supabaseAnonKey: String?

    public init(supabaseURL: String? = ProcessInfo.processInfo.environment["SUPABASE_URL"],
                anonKey: String? = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"]) {
        self.supabaseURL = supabaseURL.flatMap(URL.init(string:))
        self.supabaseAnonKey = anonKey
    }

    public var isConfigured: Bool { supabaseURL != nil && supabaseAnonKey != nil }

    // Envoyeur : crée la session (clé + pubkey, TTL 10 min)
    public func createSession(key: String, publicKey: String) async throws {
        guard let base = supabaseURL, let keyHeader = supabaseAnonKey else { return }
        let url = base.appendingPathComponent("rest/v1/sessions_ephemeres")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(keyHeader, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(keyHeader)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("return=representation", forHTTPHeaderField: "Prefer")
        let body: [String: Any] = [
            "cle": FylioRemoteKey.normalized(key),
            "cle_publique": publicKey,
            "expires_at": ISO8601DateFormatter().string(from: Date().addingTimeInterval(600)),
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    // Receveur : lookup par clé (2s)
    public func lookup(key: String) async throws -> FylioRemoteSession? {
        guard let base = supabaseURL, let keyHeader = supabaseAnonKey else { return nil }
        let norm = FylioRemoteKey.normalized(key)
        var comps = URLComponents(url: base.appendingPathComponent("rest/v1/sessions_ephemeres"),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "cle", value: "eq.\(norm)"),
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "limit", value: "1"),
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue(keyHeader, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(keyHeader)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
        let list = try JSONDecoder().decode([FylioRemoteSession].self, from: data)
        return list.first
    }

    public func deleteSession(key: String) async {
        guard let base = supabaseURL, let keyHeader = supabaseAnonKey else { return }
        let norm = FylioRemoteKey.normalized(key)
        var comps = URLComponents(url: base.appendingPathComponent("rest/v1/sessions_ephemeres"),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "cle", value: "eq.\(norm)")]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "DELETE"
        req.setValue(keyHeader, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(keyHeader)", forHTTPHeaderField: "Authorization")
        _ = try? await URLSession.shared.data(for: req)
    }
}
