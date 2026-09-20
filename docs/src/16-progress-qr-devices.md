# FYLIO — `FylioUI/Screens/TransferProgressView.swift` + `QRScannerView.swift` + `RecentDevicesView.swift`

```swift
import SwiftUI
import AVFoundation

// MARK: - PROGRESSION DU TRANSFERT (objet animé qui avance avec la barre)

struct TransferProgressView: View {
    @EnvironmentObject var app: AppViewModel
    let transfer: ActiveTransfer

    var body: some View {
        ZStack {
            FylioBackground()
            VStack(spacing: 28) {
                header
                fileSummaryCard
                progressCard
                Spacer()
            }
            .padding(.horizontal, FylioTokens.screenMargin)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .navigationTitle(String(localized: "progress.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack(spacing: 14) {
            FylioDeviceIcon(transfer.platform, size: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(transfer.peerName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(FylioPalette.nightText)
                Text(transfer.stateDescription)
                    .font(.system(size: 13))
                    .foregroundStyle(FylioPalette.secondaryText)
            }
            Spacer()
        }
    }

    private var fileSummaryCard: some View {
        FylioGlassCard {
            HStack(spacing: 16) {
                FileIcon(contentType: transfer.currentFileContentType, size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(transfer.currentFileName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(FylioPalette.nightText)
                        .lineLimit(1)
                    Text("\(transfer.formattedBytes) / \(transfer.formattedTotal)")
                        .font(.system(size: 13))
                        .foregroundStyle(FylioPalette.secondaryText)
                }
                Spacer()
                Text("\(transfer.percent)%")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(FylioPalette.electricBlue)
            }
        }
    }

    private var progressCard: some View {
        FylioGlassCard {
            VStack(spacing: 16) {
                FylioProgressBar(fraction: transfer.fraction,
                                 objectName: transfer.progressMascot)
                HStack {
                    Text(String(format: String(localized: "progress.speed"),
                                 ByteCountFormatter.string(fromByteCount: transfer.speed,
                                                           countStyle: .file)))
                    Spacer()
                    if let eta = transfer.etaSeconds {
                        Text(String(format: String(localized: "progress.remaining"),
                                     TimeFormatter.string(seconds: eta)))
                    }
                }
                .font(.system(size: 14))
                .foregroundStyle(FylioPalette.secondaryText)

                HStack(spacing: 16) {
                    pauseResumeButton
                    cancelButton
                }
            }
        }
    }

    private var pauseResumeButton: some View {
        Button {
            if transfer.paused {
                app.resumeTransfer(transfer)
            } else {
                app.pauseTransfer(transfer)
            }
        } label: {
            Label(transfer.paused
                  ? String(localized: "progress.resume")
                  : String(localized: "progress.pause"),
                  systemImage: transfer.paused ? "play.fill" : "pause.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(FylioTokens.sendGradient, in: Capsule())
        }
        .buttonStyle(FylioPressStyle())
    }

    private var cancelButton: some View {
        Button {
            app.cancelTransfer(transfer)
        } label: {
            Label(String(localized: "progress.cancel"), systemImage: "xmark")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(FylioPalette.nightText)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.7), lineWidth: 1))
        }
        .buttonStyle(FylioPressStyle())
    }
}

enum TimeFormatter {
    static func string(seconds: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: TimeInterval(seconds)) ?? "—"
    }
}

// MARK: - SCANNER QR (cadre avec personnages haut/bas — maquette QR)

struct QRScannerView: View {
    @EnvironmentObject var app: AppViewModel
    @StateObject private var scanner = QRScannerController()
    @State private var scanPulse = false

    var body: some View {
        ZStack {
            ScannerRepresentable(controller: scanner)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(FylioPalette.electricBlue, lineWidth: 4)
                        .frame(width: 260, height: 260)
                    Image("qr_character_top")
                        .resizable().scaledToFit().frame(height: 64)
                        .offset(y: -150)
                    ScanLine()
                        .stroke(FylioPalette.electricBlue.opacity(0.8),
                                style: StrokeStyle(lineWidth: 3))
                        .frame(width: 240)
                        .offset(y: scanPulse ? -110 : 110)
                        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                                   value: scanPulse)
                    Image("qr_character_bottom")
                        .resizable().scaledToFit().frame(height: 64)
                        .offset(y: 150)
                }
                Spacer()
                Text(String(localized: "qr.scanner.hint"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            scanner.start()
            scanPulse = true
        }
        .onDisappear { scanner.stop() }
        .onChange(of: scanner.lastPayload) { payload in
            guard let payload else { return }
            app.connectViaQR(payload)
            scanner.stop()
        }
    }

    private struct ScanLine: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}

struct ScannerRepresentable: UIViewRepresentable {
    let controller: QRScannerController

    func makeUIView(context: Context) -> PreviewView { controller.previewView }
    func updateUIView(_ view: PreviewView, context: Context) {}
}

final class PreviewView: UIView {
    override func layoutSubviews() {
        super.layoutSubviews()
        if let previewLayer = layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = bounds
        }
    }
}

final class QRScannerController: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    enum State { case idle, running, unauthorized }

    @Published var lastPayload: String?
    @Published var state: State = .idle

    let previewView = PreviewView()
    private let session = AVCaptureSession()

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.configureAndRun()
                    } else {
                        self?.state = .unauthorized
                    }
                }
            }
        default:
            state = .unauthorized
        }
    }

    private func configureAndRun() {
        guard state != .running else { return }
        session.beginConfiguration()
        if session.inputs.isEmpty {
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                session.commitConfiguration()
                return
            }
            session.addInput(input)
            let output = AVCaptureMetadataOutput()
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]
            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewView.layer.insertSublayer(previewLayer, at: 0)
        }
        session.commitConfiguration()
        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.startRunning()
        }
        state = .running
    }

    func stop() {
        session.stopRunning()
        state = .idle
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              object.type == .qr,
              let value = object.stringValue,
              lastPayload == nil else { return }
        lastPayload = value
    }
}

// MARK: - APPAREILS RÉCENTS (page complète — destination du « Voir tout »)

struct RecentDevicesView: View {
    @EnvironmentObject var app: AppViewModel

    var body: some View {
        ZStack {
            FylioBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if app.knownDevices.isEmpty {
                        FylioEmptyState(character: "empty_recent_devices",
                                        titleKey: "devices.empty.title",
                                        subtitleKey: "devices.empty.subtitle")
                            .padding(.top, 60)
                    } else {
                        ForEach(app.knownDevices) { peer in
                            FylioGlassCard(corner: 22) {
                                FylioDeviceRow(peer: peer,
                                               onTransfer: { app.startTransfer(to: peer) },
                                               onRename: { app.renameDevice(peer) },
                                               onDelete: { app.forgetDevice(peer) })
                            }
                        }
                    }
                }
                .padding(.horizontal, FylioTokens.screenMargin)
                .padding(.vertical, 20)
            }
        }
        .navigationTitle(String(localized: "devices.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
```
