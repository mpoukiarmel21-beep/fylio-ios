import Foundation
import Network
import CryptoKit

/// Découverte des pairs (D05-bis).
/// 1) mDNS/Bonjour `_fylio._tcp` via NWBrowser (principal).
/// 2) Multicast UDP de secours sur `239.255.76.1:47827` (réseaux bloquant mDNS).
/// Aucune dépendance Internet. Les TXT records ne contiennent JAMAIS de secret.
/// (Bugs audit 00 corrigés : TXT "id", guard .service, guard .bonjour, _ = changer.)
public actor FylioDiscovery {
    public static let serviceType = "_fylio._tcp"
    public static let multicastGroup = "239.255.76.1"
    public static let multicastPort: UInt16 = 47827
    public static let announcePayloadSize = 512

    private var browser: NWBrowser?
    private var listener: NWListener?
    private var multicastConn: NWConnection?
    private var identity: FylioIdentity?
    private var onPeerFound: ((FylioPeer) -> Void)?
    private var onPeerLost: ((UUID) -> Void)?

    public init() {}

    public func configure(identity: FylioIdentity,
                          onFound: @escaping (FylioPeer) -> Void,
                          onLost: @escaping (UUID) -> Void) {
        self.identity = identity
        self.onPeerFound = onFound
        self.onPeerLost = onLost
    }

    /// Annonce locale : service Bonjour + listener TCP + beacon multicast.
    public func startAdvertising(port: UInt16) async throws {
        let params = NWParameters(tls: nil)   // TLS est établi par la session, pas ici
        params.allowLocalEndpointReuse = true
        let listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
        // TXT : métadonnées publiques uniquement + ID d'appareil (BUG #3 — indispensable).
        let txt: NWTXTRecord = [
            "v": "1",
            "id": identity?.deviceID.uuidString ?? "",
            "num": identity?.fylioNumber ?? "",
            "name": identity?.displayName ?? "",
            "pf": identity?.platform.rawValue ?? "",
            "fp": identity?.publicKeyFingerprint ?? "",
            "av": String(identity?.avatarID ?? 1)
        ]
        listener.service = NWListener.Service(name: identity?.fylioNumber,
                                              type: Self.serviceType,
                                              txtRecord: txt)
        listener.serviceRegistrationUpdateHandler = { _ in }
        self.listener = listener
        listener.start(queue: .global(qos: .utility))
        try await startMulticastBeacon()
    }

    /// Recherche des pairs Fylio sur le réseau local.
    public func startBrowsing() {
        let params = NWParameters()
        params.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: Self.serviceType, domain: nil), using: params)
        browser.browseResultsChangedHandler = { results, _ in
            Task { await self.handleResults(results) }
        }
        browser.stateUpdateHandler = { state in
            if case .failed(let err) = state {
                NSLog("[FylioDiscovery] browser failed: \(err)")
            }
        }
        self.browser = browser
        browser.start(queue: .global(qos: .utility))
    }

    /// (BUG #3 — syntaxe fantôme `result.metadata?[(.txt)]` supprimée.)
    private func handleResults(_ results: Set<NWBrowser.Result>) {
        for result in results {
            guard case .service = result.endpoint else { continue }
            guard case .bonjour(let txt) = result.metadata else { continue }
            guard let peer = peerFromTXT(txt: txt) else { continue }
            onPeerFound?(peer)
        }
    }

    /// (BUG #3 — lecture Data → String, l'UUID vient du champ "id".)
    private func peerFromTXT(txt: NWTXTRecord) -> FylioPeer? {
        func field(_ k: String) -> String? {
            guard let entry = txt[k] else { return nil }
            switch entry {
            case .string(let s): return s
            case .data(let d): return String(data: d, encoding: .utf8)
            }
        }
        guard let devID = UUID(uuidString: field("id") ?? ""),
              let num = field("num"), let fp = field("fp") else { return nil }
        return FylioPeer(id: devID, displayName: field("name") ?? num,
                         fylioNumber: num, avatarID: Int(field("av") ?? "1") ?? 1,
                         platform: FylioPlatform(rawValue: field("pf") ?? "ios") ?? .ios,
                         host: "bonjour", port: 0, fingerprint: fp)
    }

    // MARK: - Multicast fallback (réseaux sans mDNS)

    private func startMulticastBeacon() async throws {
        let params = NWParameters.udp
        let conn = NWConnection(host: NWEndpoint.Host(Self.multicastGroup),
                                port: NWEndpoint.Port(rawValue: Self.multicastPort)!,
                                using: params)
        self.multicastConn = conn
        conn.stateUpdateHandler = { [weak self] state in
            if case .ready = state {
                Task { await self?.sendBeacon(conn) }
            }
        }
        conn.start(queue: .global(qos: .utility))
    }

    private func sendBeacon(_ conn: NWConnection) {
        guard let identity else { return }
        // Beacon : JSON public uniquement (pas de secret) — M3 respecté.
        let beacon: [String: String] = [
            "v": "1", "num": identity.fylioNumber,
            "name": identity.displayName,
            "pf": identity.platform.rawValue,
            "fp": identity.publicKeyFingerprint,
            "av": String(identity.avatarID)
        ]
        if let data = try? JSONEncoder().encode(beacon) {
            conn.send(content: data, completion: .contentProcessed { _ in })
        }
    }

    public func stopAll() {
        browser?.cancel(); listener?.cancel(); multicastConn?.cancel()
        browser = nil; listener = nil; multicastConn = nil
    }
}