# FYLIO — `FylioUI/AppViewModel.swift` (bloc 2/3 : moteur + transferts + QR + appareils)

```swift
import SwiftUI
import Network
import CryptoKit
import UserNotifications
import Photos

@MainActor
final class AppViewModel: ObservableObject {
    @Published var identity: FylioIdentity
    @Published var avatarPhotoData: Data?
    @Published var path = NavigationPath()
    @Published var hasUnreadNotifications = false
    @Published var permissionStates: [PermissionState] = [.unknown, .unknown, .unknown]
    let suggestedDeviceName: String = UIDevice.current.name

    @Published var recentDevices: [FylioPeer] = []
    @Published var knownDevices: [FylioPeer] = []
    @Published var discoveredDevices: [FylioPeer] = []
    @Published var history: [HistoryEntry] = []
    @Published var allFileItems: [FylioFileItem] = []
    @Published var incomingRequests: [IncomingTransferRequest] = []
    @Published var activeTransfers: [ActiveTransfer] = []

    @Published var deviceToRename: FylioPeer?
    @Published var showMascotGuide = false

    private let crypto: FylioCrypto
    private let discovery = FylioDiscovery()
    private let storage: FylioStorage
    private var listener: NWListener?
    private var sessions: [UUID: FylioSession] = [:]
    private var qrEphemeral: Curve25519.KeyAgreement.PrivateKey?
    private var pendingFilesToSend: [FylioFileItem] = []

    init() {
        let crypto = FylioCrypto()
        self.crypto = crypto
        self.storage = FylioStorage()
        if let saved = FylioKeychain.loadIdentity() {
            self.identity = saved
            self.avatarPhotoData = FylioKeychain.loadAvatarPhoto()
        } else {
            let fingerprint = crypto.publicKeyFingerprint
            let digits = Int(fingerprint.prefix(4), radix: 16) % 10000
            self.identity = FylioIdentity(displayName: UIDevice.current.name,
                                          fylioNumber: String(format: "Fylio-%04d", digits),
                                          avatarID: 1,
                                          platform: .ios,
                                          publicKeyFingerprint: fingerprint)
            FylioKeychain.saveIdentity(self.identity)
        }
    }

    var isOnboarded: Bool { FylioKeychain.hasCompletedOnboarding() }

    // MARK: Onboarding

    func completeOnboarding(avatar: Int, photo: Data?, name: String) {
        identity.displayName = name.isEmpty ? suggestedDeviceName : name
        identity.avatarID = avatar
        avatarPhotoData = photo
        FylioKeychain.saveIdentity(identity)
        FylioKeychain.saveAvatarPhoto(photo)
        FylioKeychain.markOnboardingComplete()
        startEngine()
    }

    func requestPermission(index: Int) {
        switch index {
        case 0:
            UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
                    Task { @MainActor in
                        self?.permissionStates[0] = granted ? .granted : .denied
                    }
                }
        case 1:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
                Task { @MainActor in
                    self?.permissionStates[1] = status == .denied ? .denied : .granted
                }
            }
        default:
            permissionStates[2] = .granted
        }
    }

    // MARK: Moteur

    func startEngine() {
        Task {
            try? await discovery.configure(identity: identity) { [weak self] peer in
                Task { @MainActor in
                    guard let self else { return }
                    if !self.discoveredDevices.contains(where: { $0.id == peer.id }) {
                        self.discoveredDevices.append(peer)
                    }
                    if !self.knownDevices.contains(where: { $0.id == peer.id }) {
                        self.knownDevices.append(peer)
                        self.recentDevices.append(peer)
                    }
                }
            } onLost: { [weak self] id in
                Task { @MainActor in
                    self?.discoveredDevices.removeAll { $0.id == id }
                }
            }
            try? await discovery.startAdvertising(port: FylioDefaults.listenPort)
            discovery.startBrowsing()
        }
        startListener()
    }

    private func startListener() {
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            let newListener = try NWListener(using: params,
                                             on: NWEndpoint.Port(rawValue: FylioDefaults.listenPort)!)
            newListener.newConnectionHandler = { [weak self] connection in
                Task { await self?.handleIncoming(connection) }
            }
            newListener.start(queue: .global(qos: .utility))
            self.listener = newListener
        } catch {
            NSLog("[Fylio] listener error: \(error)")
        }
    }

    private func handleIncoming(_ conn: NWConnection) async {
        let session = FylioSession(crypto: crypto, identity: identity)
        do {
            try await session.acceptIncoming(
                on: conn,
                sessionKey: SymmetricKey(size: .bits256),
                storage: storage,
                onIncoming: { sender, manifests, totalBytes in
                    await withCheckedContinuation { continuation in
                        Task { @MainActor in
                            // Affiche la demande dans l'UI ; décision de l'utilisateur.
                            self.addIncomingRequest(sender: sender,
                                                     count: manifests.count,
                                                     totalBytes: totalBytes) { accepted in
                                continuation.resume(returning: accepted)
                            }
                        }
                    }
                })
            await MainActor.run { reloadFiles() }
        } catch {
            NSLog("[Fylio] incoming session error: \(error)")
        }
    }

    @Published private(set) var incomingDecisions: [UUID: (Bool) -> Void] = [:]

    private func addIncomingRequest(sender: FylioIdentity,
                                    count: Int,
                                    totalBytes: Int64,
                                    completion: @escaping (Bool) -> Void) {
        let request = IncomingTransferRequest(senderName: sender.displayName,
                                               avatarID: sender.avatarID,
                                               fileCount: count,
                                               totalBytes: totalBytes)
        incomingRequests.append(request)
        incomingDecisions[request.id] = completion
        sendLocalNotification(title: String(localized: "notif.incoming.title"),
                              body: String(localized: "notif.incoming.body"))
    }

    func respondIncoming(_ request: IncomingTransferRequest, accept: Bool) {
        incomingDecisions[request.id]?(accept)
        incomingDecisions[request.id] = nil
        incomingRequests.removeAll { $0.id == request.id }
    }

    // MARK: Envoi

    func startSendFlow(selected: Set<UUID>) {
        pendingFilesToSend = allFileItems.filter { selected.contains($0.id) }
        path.append(FylioRoute.devices)
    }

    func startTransfer(to peer: FylioPeer) {
        guard !pendingFilesToSend.isEmpty else { return }
        let files = pendingFilesToSend
        pendingFilesToSend = []
        let session = FylioSession(crypto: crypto, identity: identity)
        let transferID = UUID()
        let mascot = FylioProgressMascot.pick()
        activeTransfers.append(ActiveTransfer(
            peerName: peer.displayName,
            platform: peer.platform,
            currentFileName: files.first?.name ?? "",
            currentFileContentType: files.first?.contentType ?? "",
            fraction: 0,
            totalBytes: files.reduce(0) { $0 + $1.sizeBytes },
            speed: 0, etaSeconds: nil, paused: false,
            progressMascot: mascot,
            stateDescription: String(localized: "state.transferring")))
        sessions[transferID] = session
        path.append(FylioRoute.progress(transferID))

        session.configure(onProgress: { [weak self] progress in
            Task { @MainActor in self?.updateProgress(mascot: mascot, progress: progress) }
        }, onState: { [weak self] state in
            Task { @MainActor in self?.handleTransferState(state, mascot: mascot,
                                                           files: files, peer: peer) }
        })

        Task {
            do {
                let key = try crypto.sessionKey(peerPublicKey: Data(),
                                                sessionSalt: transferID.uuidBytes)
                try await session.send(files: files, to: peer, sessionKey: key)
            } catch {
                NSLog("[Fylio] send error: \(error)")
            }
        }
    }

    private func updateProgress(mascot: String, progress: FylioProgress) {
        guard let idx = activeTransfers.firstIndex(where: { $0.progressMascot == mascot }) else { return }
        activeTransfers[idx].fraction = progress.fraction
        activeTransfers[idx].speed = progress.speedBytesPerSec
        activeTransfers[idx].etaSeconds = progress.etaSeconds
    }

    private func handleTransferState(_ state: FylioTransferState,
                                     mascot: String,
                                     files: [FylioFileItem],
                                     peer: FylioPeer) {
        guard let idx = activeTransfers.firstIndex(where: { $0.progressMascot == mascot }) else { return }
        activeTransfers[idx].stateDescription = state.localizedDescription
        if state == .completed {
            history.insert(HistoryEntry(title: files.first?.name ?? "",
                                         count: files.count,
                                         sizeBytes: activeTransfers[idx].totalBytes,
                                         platform: peer.platform,
                                         direction: .sent,
                                         date: Date()), at: 0)
            activeTransfers.remove(at: idx)
            sendLocalNotification(title: String(localized: "notif.sent.title"),
                                  body: String(localized: "notif.sent.body"))
        }
    }

    // MARK: Contrôles

    func pauseTransfer(_ transfer: ActiveTransfer) { setPaused(transfer, paused: true) }
    func resumeTransfer(_ transfer: ActiveTransfer) { setPaused(transfer, paused: false) }

    private func setPaused(_ transfer: ActiveTransfer, paused: Bool) {
        for session in sessions.values {
            Task { paused ? await session.pause() : await session.resumeTransfer() }
        }
        if let idx = activeTransfers.firstIndex(where: { $0.id == transfer.id }) {
            activeTransfers[idx].paused = paused
            activeTransfers[idx].stateDescription = String(localized: paused ? "state.paused" : "state.transferring")
        }
    }

    func cancelTransfer(_ transfer: ActiveTransfer) {
        for session in sessions.values { Task { await session.cancel() } }
        activeTransfers.removeAll { $0.id == transfer.id }
        if !path.isEmpty { path.removeLast() }
    }

    // MARK: Appareils

    func renameDevice(_ peer: FylioPeer) { deviceToRename = peer }

    func forgetDevice(_ peer: FylioPeer) {
        knownDevices.removeAll { $0.id == peer.id }
        recentDevices.removeAll { $0.id == peer.id }
        storage.removeKnownDevice(peer)
    }

    func deleteDevice(_ peer: FylioIPeer) { forgetDevice(peer) }
    func requestConnection(to peer: FylioPeer) { startTransfer(to: peer) }

    // MARK: QR

    func qrPairingPayload() -> String {
        let privateKey = qrEphemeral ?? FylioCrypto.ephemeralPair().0
        qrEphemeral = privateKey
        let payload: [String: String] = [
            "proto": "1",
            "num": identity.fylioNumber,
            "name": identity.displayName,
            "fp": identity.publicKeyFingerprint,
            "eph": privateKey.publicKey.rawRepresentation.base64EncodedString(),
            "eph_priv": privateKey.rawRepresentation.base64EncodedString(),
            "port": String(FylioDefaults.listenPort),
            "ip": FylioDefaults.localIPAddress ?? ""
        ]
        return String(data: (try? JSONEncoder().encode(payload)) ?? Data(), encoding: .utf8) ?? "{}"
    }

    func connectViaQR(_ payload: String) {
        guard let data = payload.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: String].self, from: data),
              let num = dict["num"], let fp = dict["fp"],
              let host = dict["ip"], let portStr = dict["port"], let port = UInt16(portStr) else { return }
        let peer = FylioPeer(id: UUID(),
                              displayName: dict["name"] ?? num,
                              fylioNumber: num,
                              avatarID: 1,
                              platform: .ios,
                              host: host,
                              port: port,
                              fingerprint: fp)
        knownDevices.append(peer)
        path.append(FylioRoute.receive)
    }

    // MARK: Historique / fichiers

    func clearHistory(_ done: () -> Void) {
        history.removeAll()
        storage.clearHistory()
        done()
    }

    func allFiles(sortedBy order: FileSortOrder) -> [FylioFileItem] {
        switch order {
        case .recent: return allFileItems.sorted { $0.id.uuidString > $1.id.uuidString }
        case .name: return allFileItems.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .size: return allFileItems.sorted { $0.sizeBytes > $1.sizeBytes }
        }
    }

    func reloadFiles() { allFileItems = storage.loadAllFiles() }
    func registerImportedFiles(urls: [URL]) { storage.importFiles(urls); reloadFiles() }
    func playMascottGuide() { showMascotGuide = true }

    func sendLocalNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        UNUserNotificationCenter.current()
            .add(UNNotificationRequest(identifier: UUID().uuidString,
                                       content: content, trigger: nil))
        hasUnreadNotifications = true
    }
}
```
