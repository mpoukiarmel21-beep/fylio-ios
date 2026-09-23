import SwiftUI

/// Dispatch des routes poussées (doc 21 : FylioRoute).
struct FylioRouteScreen: View {
    @EnvironmentObject var app: AppViewModel
    let route: FylioRoute

    var body: some View {
        switch route {
        case .send:
            SendView()
        case .receive:
            ReceiveView()
        case .devices:
            RecentDevicesView()
        case .settings:
            SettingsView()
        case .notifications:
            FylioPlaceholderScreen(titleKey: "settings.notifications")
        case .files:
            FilesView()
        case .music:
            MusicView()
        case .gallery:
            GalleryView()
        case .history:
            HistoryView()
        case .qrScanner:
            QRScannerView()
        case .browser:
            BrowserView()
        case .progress(let id):
            if let transfer = app.activeTransfers.first(where: { $0.id == id }) {
                TransferProgressView(transfer: transfer)
            } else {
                FylioPlaceholderScreen(titleKey: "progress.transferring")
            }
        default:
            FylioPlaceholderScreen(titleKey: "feature.inProgress")
        }
    }
}

/// Écran « en cours de développement » (docs 19/20/23/24/25).
struct FylioPlaceholderScreen: View {
    let titleKey: String

    var body: some View {
        ZStack {
            FylioBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: FylioTokens.spacingSection) {
                    FylioSectionHeader(titleKey)
                    FylioEmptyStateSlot(registry: .files, isEmpty: true)
                }
                .padding(.horizontal, FylioTokens.screenMargin)
            }
        }
        .navigationTitle(String(localized: String.LocalizationValue(titleKey)))
        .navigationBarTitleDisplayMode(.inline)
    }
}