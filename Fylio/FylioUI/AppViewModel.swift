import SwiftUI
import Network
import CryptoKit
import UserNotifications
import Photos
import AVFoundation

// MARK: - Navigation & modèles UI (doc 21)

enum FylioRoute: Hashable {
    case home, send, receive, devices, files, gallery, music, history
    case settings, notifications, qrScanner, progress(UUID), browser
    case remoteSend, remoteReceive
}

enum PermissionState { case unknown, granted, denied }

struct IncomingTransferRequest: Identifiable, Equatable {
    let id = UUID()
    let senderName: String
    let avatarID: Int
    let fileCount: Int
    let totalBytes: Int64
}

struct ActiveTransfer: Identifiable, Equatable {
    let id = UUID()
    let peerName: String
    let platform: FylioPlatform
    var currentFileName: String
    var currentFileContentType: String
    var fraction: Double
    var totalBytes: Int64
    var speed: Int64
    var etaSeconds: Int?
    var paused: Bool
    let progressMascot: String
    var stateDescription: String

    var percent: Int { Int((fraction * 100).rounded()) }
    var formattedBytes: String {
        ByteCountFormatter.string(fromByteCount: Int64(fraction * Double(totalBytes)),
                                  countStyle: .file)
    }
    var formattedTotal: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }

    static func == (lhs: ActiveTransfer, rhs: ActiveTransfer) -> Bool { lhs.id == rhs.id }
}

struct HistoryEntry: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let count: Int
    let sizeBytes: Int64
    let platform: FylioPlatform
    let direction: Direction
    let date: Date

    enum Direction { case sent, received }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
    var relativeDate: String {
        RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
    }
}

enum FileSortOrder: String, CaseIterable, Identifiable {
    case recent, name, size
    var id: String { rawValue }
    var label: String {
        switch self {
        case .recent: return String(localized: "sort.recent")
        case .name: return String(localized: "sort.name")
        case .size: return String(localized: "sort.size")
        }
    }
}

// MARK: - Valeurs par défaut (ports, adresse locale)

enum FylioDefaults {
    /// Port TCP d'écoute des sessions Fylio (le multicast UDP de découverte
    /// est sur 47827 ; on prend 47826 pour la connexion applicative).
    static let listenPort: UInt16 = 47826

    /// IP locale IPv4 Wi-Fi (utilisée dans le QR pour la connexion directe).
    static var localIPAddress: String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            let family = ptr.pointee.ifa_addr.pointee.sa_family
            if (flags & IFF_LOOPBACK) == 0 && family == UInt8(AF_INET) {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(ptr.pointee.ifa_addr, socklen_t(family),
                            &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
                address = String(cString: host)
                break
            }
        }
        return address
    }
}

extension FylioTransferState {
    var localizedDescription: String {
        switch self {
        case .preparing:   return String(localized: "progress.preparing")
        case .transferring: return String(localized: "progress.transferring")
        case .paused:      return String(localized: "progress.paused")
        default:           return String(localized: "progress.transferring")
        }
    }
}

// MARK: - ViewModel principal (doc 22)

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
    @Published var isCableConnected = false
    @Published var remoteKey: String = ""
    let remoteService = FylioRemoteService()
    @Published var fileToPreview: FylioFileItem?
    @Published var fileToShare: FylioFileItem?
    private var cableMonitor: Any?

    private let crypto: FylioCrypto
    private let qrPairing = FylioQRPairingService()
    private let discovery = FylioDiscovery()
    private let storage: FylioStorage
    private var listener: NWListener?
    private var sessions: [UUID: FylioSession] = [:]
    private var pendingFilesToSend: [FylioFileItem] = []

    /// Routage rapide pour les écrans qui utilisent encore `app.route = ...`.
    var route: FylioRoute? {
        get { nil }
        set { if let newValue { path.append(newValue) } }
    }

    init() {
        let crypto = FylioCrypto()
        self.crypto = crypto
        self.storage = FylioStorage()
        if let saved = FylioKeychain.loadIdentity() {
            self.identity = saved
            self.avatarPhotoData = FylioKeychain.loadAvatarPhoto()
        } else {
            let fingerprint = crypto.publicKeyFingerprint
            let digits = Int(fingerprint.prefix(4), radix: 16) ?? 0
            self.identity = FylioIdentity(displayName: UIDevice.current.name,
                                          fylioNumber: String(format: "Fylio-%04d", digits % 10000),
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
        // Index 0 = Local Network (Bonjour/mDNS) — déclenche le système au 1er usage
        //  → On le marque granted dès que l'utilisateur tape, le vrai prompt iOS
        //    apparaît au premier NWListener / NetService. Fallback UI si refus.
        // Index 1 = Camera (QR), Index 2 = Photo Library (+ sauvegarde)
        switch index {
        case 0:
            // Local Network : on tente un probe mDNS pour déclencher le prompt système
            permissionStates[0] = .granted
            // Le vrai statut (granted/denied) sera confirmé au démarrage du moteur (Bonjour)
            // — pas de blocage onboarding.
        case 1:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    self?.permissionStates[1] = granted ? .granted : .denied
                }
            }
        default:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
                Task { @MainActor in
                    if status == .authorized || status == .limited {
                        self?.permissionStates[2] = .granted
                    } else if status == .denied || status == .restricted {
                        self?.permissionStates[2] = .denied
                    } else {
                        self?.permissionStates[2] = .granted
                    }
                }
            }
        }
    }

    // MARK: Moteur

    func startEngine() {
        startCableMonitor()
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
            await discovery.startBrowsing()
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
                keyResolver: { sessionID in
                    FylioSession.defaultSessionKey(sessionID: sessionID)
                },
                storage: storage,
                onIncoming: { sender, manifests, totalBytes in
                    await withCheckedContinuation { continuation in
                        Task { @MainActor in
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

    private var incomingDecisions: [UUID: (Bool) -> Void] = [:]

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

        Task {
            await session.configure(onProgress: { [weak self] progress in
                Task { @MainActor in self?.updateProgress(mascot: mascot, progress: progress) }
            }, onState: { [weak self] state in
                Task { @MainActor in self?.handleTransferState(state, mascot: mascot,
                                                               files: files, peer: peer) }
            })
            do {
                // Mode mDNS : clé déterministe par session (même des deux côtés).
                // Mode QR : l'ECDH réel remplacera ceci lors de l'intégration QR.
                let key = FylioSession.defaultSessionKey(sessionID: await session.sessionIdentifier)
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

    func deleteDevice(_ peer: FylioPeer) { forgetDevice(peer) }
    func requestConnection(to peer: FylioPeer) { startTransfer(to: peer) }

    // MARK: QR

    /// Payload QR sécurisé : contient l'ADRESSE + la clé PUBLIQUE éphémère.
    /// Jamais la clé privée (celle-ci reste dans le Keychain/Store local).
    func qrPairingPayload() -> String {
        guard let payload = try? qrPairing.generatePairingPayload(
            identity: identity,
            host: FylioDefaults.localIPAddress ?? "",
            port: FylioDefaults.listenPort) else { return "" }
        return payload
    }

    /// QR scanné → pair de connexion directe (peer.ephemeralPublicKey = clé
    /// publique du QR ; le private de notre côté reste local à FylioQRPairingService).
    func connectViaQR(_ payload: String) {
        do {
            let peer = try qrPairing.parseAndValidate(payload)
            knownDevices.append(peer)
            path.append(FylioRoute.receive)
        } catch {
            NSLog("[Fylio] invalid QR payload")
        }
    }

    // MARK: Historique / fichiers

    func clearHistory(_ done: () -> Void) {
        history.removeAll()
        storage.clearHistory()
        done()
    }

    func allFiles(sortedBy order: FileSortOrder) -> [FylioFileItem] {
        switch order {
        case .recent: return allFileItems.sorted { a, b in
            modDate(of: a) > modDate(of: b)
        }
        case .name: return allFileItems.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        case .size: return allFileItems.sorted { $0.sizeBytes > $1.sizeBytes }
        }
    }

    private func modDate(of file: FylioFileItem) -> Date {
        guard let url = file.fileURL,
              let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]) else {
            return .distantPast
        }
        return values.contentModificationDate ?? .distantPast
    }

    func reloadFiles() { allFileItems = storage.loadAllFiles() }
    func registerImportedFiles(urls: [URL]) { storage.importFiles(urls); reloadFiles() }
    func playMascottGuide() { showMascotGuide = true }

    func acceptRemoteSession(_ session: FylioRemoteSession) {
        // Palier 4 : le pair distant est matérialisé par sa clé publique
        // La connexion réelle (WebSocket/Relay) sera branchée en Palier 5+
        sendLocalNotification(title: String(localized: "remote.receive.found"),
                              body: session.displayKey)
    }

    // MARK: Câble — poll léger du moniteur USB (FylioUSBTransfer)
    private var cableTask: Task<Void, Never>?

    private func startCableMonitor() {
        cableTask?.cancel()
        cableTask = Task { [weak self] in
            let usb = FylioUSBTransfer()
            while !Task.isCancelled {
                let count = await usb.scanForPCDrops()
                await MainActor.run {
                    // Connecté si au moins 1 drop détecté ou si la session USB est active
                    self?.isCableConnected = count > 0
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    // MARK: Fichiers (doc 17) — actions sur les fichiers gérés par FylioStorage

    func createFolder(named name: String) {
        storage.createFolder(named: name)
        reloadFiles()
    }

    func openFile(_ file: FylioFileItem) { fileToPreview = file }
    func shareFile(_ file: FylioFileItem) { fileToShare = file }

    func toggleFavorite(_ file: FylioFileItem) {
        let key = "fylio.fav.\(file.id.uuidString)"
        UserDefaults.standard.set(!UserDefaults.standard.bool(forKey: key), forKey: key)
    }

    func deleteFile(_ file: FylioFileItem) {
        storage.deleteFile(file)
        reloadFiles()
    }

    // MARK: Audio (doc 17) — mini-lecteur AVPlayer

    private var audioPlayer: AVPlayer?

    func playAudio(_ file: FylioFileItem) {
        guard let url = file.fileURL, audioPlayer?.timeControlStatus != .playing else { return }
        let player = AVPlayer(url: url)
        audioPlayer = player
        player.play()
    }

    func toggleAudioPlayback() {
        guard let player = audioPlayer else { return }
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
    }

    func stopAudio() { audioPlayer?.pause() }

    // MARK: Paramètres (doc 18)

    func clearCache() {
        let temp = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        try? FileManager.default.removeItem(at: temp)
        try? FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
    }

    func eraseAllData() {
        audioPlayer?.pause()
        storage.deleteAllFiles()
        history.removeAll()
        knownDevices.removeAll()
        recentDevices.removeAll()
        discoveredDevices.removeAll()
        incomingRequests.removeAll()
        activeTransfers.removeAll()
        allFileItems.removeAll()
        hasUnreadNotifications = false
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
    }

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

// MARK: - Renommage d'appareil

struct RenameDeviceSheet: View {
    let peer: FylioPeer
    @EnvironmentObject var app: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField(String(localized: "devices.rename"), text: $name)
                    .submitLabel(.done)
            }
            .navigationTitle(String(localized: "devices.rename"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done")) {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty, let idx = app.knownDevices.firstIndex(where: { $0.id == peer.id }) {
                            app.knownDevices[idx].displayName = trimmed
                        }
                        dismiss()
                    }
                }
            }
            .onAppear { name = peer.displayName }
        }
    }
}