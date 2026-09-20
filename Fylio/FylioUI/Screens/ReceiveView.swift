import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

/// RECEVOIR — nom + numéro Fylio, QR sécurisé, connexions, demandes entrantes,
/// animation d'attente, accepter/refuser (doc 15).
struct ReceiveView: View {
    @EnvironmentObject var app: AppViewModel
    @State private var qrCodeImage: UIImage?
    @State private var pulse = false

    var body: some View {
        ZStack {
            FylioBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 26) {
                    deviceIdentityCard
                    qrCard
                    availableConnectionsCard
                    incomingRequestsCard
                }
                .padding(.horizontal, FylioTokens.screenMargin)
                .padding(.vertical, 20)
            }
        }
        .navigationTitle(String(localized: "receive.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task { qrCodeImage = FylioQRGenerator.image(payload: app.qrPairingPayload(), scale: 10) }
    }

    // MARK: Identité (nom + numéro Fylio + avatar)

    private var deviceIdentityCard: some View {
        FylioGlassCard {
            HStack(spacing: 16) {
                FylioAvatarView(avatarID: app.identity.avatarID,
                                photoData: app.avatarPhotoData,
                                size: 64,
                                showsOnlineDot: false)
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.identity.displayName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(FylioPalette.nightText)
                    Text(app.identity.fylioNumber)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FylioPalette.secondaryText)
                }
                Spacer()
                Button {
                    UIPasteboard.general.string = app.identity.fylioNumber
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 17))
                        .foregroundStyle(FylioPalette.secondaryBlue)
                }
                .buttonStyle(FylioPressStyle())
            }
        }
    }

    // MARK: QR (personnage autour du code — asset unique qr_character)

    private var qrCard: some View {
        FylioGlassCard {
            VStack(spacing: 16) {
                Image("qr_character")
                    .resizable().scaledToFit().frame(height: 70)
                if let img = qrCodeImage {
                    Image(uiImage: img)
                        .interpolation(.none)
                        .resizable().scaledToFit()
                        .frame(width: 220, height: 220)
                        .padding(10)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
                } else {
                    ProgressView()
                }
                Text(String(localized: "receive.qr.hint"))
                    .font(.system(size: 14))
                    .foregroundStyle(FylioPalette.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: Connexions disponibles (recherche animée si aucune)

    private var availableConnectionsCard: some View {
        FylioGlassCard {
            VStack(alignment: .leading, spacing: 14) {
                FylioSectionHeader("receive.available")
                if app.discoveredDevices.isEmpty {
                    HStack(spacing: 14) {
                        Circle()
                            .trim(from: 0, to: pulse ? 1 : 0.1)
                            .stroke(FylioPalette.electricBlue,
                                    style: StrokeStyle(lineWidth: 3))
                            .frame(width: 46, height: 46)
                            .rotationEffect(.degrees(pulse ? 360 : 0))
                            .animation(.linear(duration: 1.6).repeatForever(autoreverses: false),
                                       value: pulse)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "receive.searching"))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(FylioPalette.nightText)
                            Text(String(localized: "receive.searching.subtitle"))
                                .font(.system(size: 13))
                                .foregroundStyle(FylioPalette.secondaryText)
                        }
                    }
                    .onAppear { pulse = true }
                } else {
                    ForEach(app.discoveredDevices) { peer in
                        FylioDeviceRow(peer: peer,
                                       onTransfer: { app.requestConnection(to: peer) },
                                       onRename: { app.renameDevice(peer) },
                                       onDelete: { app.forgetDevice(peer) })
                    }
                }
            }
        }
    }

    // MARK: Demandes entrantes (accepter / refuser)

    private var incomingRequestsCard: some View {
        FylioGlassCard {
            VStack(alignment: .leading, spacing: 14) {
                FylioSectionHeader("receive.incoming")
                if app.incomingRequests.isEmpty {
                    Text(String(localized: "receive.noIncoming"))
                        .font(.system(size: 14))
                        .foregroundStyle(FylioPalette.secondaryText)
                } else {
                    ForEach(app.incomingRequests) { request in
                        incomingRequestRow(request)
                    }
                }
            }
        }
    }

    private func incomingRequestRow(_ request: IncomingTransferRequest) -> some View {
        HStack(spacing: 14) {
            FylioAvatarView(avatarID: request.avatarID, size: 48, showsOnlineDot: false)
            VStack(alignment: .leading, spacing: 3) {
                Text(request.senderName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(FylioPalette.nightText)
                Text(String(format: String(localized: "receive.incoming.detail"),
                            request.fileCount,
                            ByteCountFormatter.string(fromByteCount: request.totalBytes,
                                                       countStyle: .file)))
                    .font(.system(size: 13))
                    .foregroundStyle(FylioPalette.secondaryText)
            }
            Spacer()
            Button {
                app.respondIncoming(request, accept: false)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(FylioPalette.alertRed.opacity(0.85))
            }
            .buttonStyle(FylioPressStyle())
            Button {
                app.respondIncoming(request, accept: true)
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(FylioPalette.statusGreen)
            }
            .buttonStyle(FylioPressStyle())
        }
        .padding(12)
        .background(FylioPalette.paleBlue.opacity(0.3),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// Générateur QR (CoreImage). Payload = données publiques uniquement.
enum FylioQRGenerator {
    static func image(payload: String, scale: CGFloat = 10) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}