import SwiftUI

/// Racine : onboarding à la première ouverture, sinon l'application tabulée.
struct RootView: View {
    @EnvironmentObject var app: AppViewModel

    var body: some View {
        ZStack {
            FylioBackground()
            if app.isOnboarded {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: app.isOnboarded)
    }
}

/// Onglets principaux : Accueil, Fichiers, Musique, Galerie + câble détaché.
/// DA vitrée : bottom custom FylioBottomNav 4+1 (pas de TabView système).
struct MainTabView: View {
    @EnvironmentObject var app: AppViewModel
    @State private var selectedTab: FylioTab = .home
    @State private var pendingIncoming: IncomingTransferRequest?
    @State private var showCableSheet = false

    // Détection câble : Network path (côté fiable) + FileManager iTunes (fallback)
    // Ici on s'appuie sur FylioUSBTransfer.isCableConnected (actor) via published
    private var isCableConnected: Bool { app.isCableConnected }

    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationStack(path: $app.path) {
                currentTabView
                    .navigationDestination(for: FylioRoute.self) { route in
                        FylioRouteScreen(route: route)
                    }
            }
            // Bottom custom vitré (au-dessus du contenu, flottante)
            FylioBottomBar(selected: $selectedTab,
                           isCableConnected: isCableConnected) {
                showCableSheet = true
            }
        }
        .ignoresSafeArea(.keyboard)
        .sheet(item: $app.deviceToRename) { peer in
            RenameDeviceSheet(peer: peer)
        }
        .sheet(isPresented: $app.showMascotGuide) {
            MascotGuideSheet()
        }
        .sheet(isPresented: $showCableSheet) {
            CableStatusSheet(isConnected: isCableConnected)
        }
        .fullScreenCover(item: $app.fileToPreview) { file in
            FylioFilePreviewSheet(file: file)
        }
        .sheet(item: $app.fileToShare) { file in
            if let url = file.fileURL {
                ShareSheet(items: [url])
            }
        }
        .onChange(of: app.incomingRequests.count) { count in
            guard count > 0, pendingIncoming == nil else { return }
            pendingIncoming = app.incomingRequests.first
        }
        .alert(item: $pendingIncoming) { request in
            Alert(
                title: Text(String(localized: "notif.incoming.title")),
                message: Text("\(request.senderName) · \(request.fileCount) · \(request.totalBytes)"),
                primaryButton: .default(Text(String(localized: "receive.confirm"))) {
                    app.respondIncoming(request, accept: true)
                },
                secondaryButton: .destructive(Text(String(localized: "common.cancel"))) {
                    app.respondIncoming(request, accept: false)
                })
        }
    }

    @ViewBuilder
    private var currentTabView: some View {
        switch selectedTab {
        case .home: HomeView()
        case .files: FilesView()
        case .music: MusicView()
        case .gallery: GalleryView()
        }
    }
}

// Sheet diagnostic câble (Palier 3)
private struct CableStatusSheet: View {
    let isConnected: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: isConnected ? "cable.connector.slash" : "cable.connector")
                    .font(.system(size: 48))
                    .foregroundStyle(isConnected ? FylioPalette.statusGreen : FylioPalette.secondaryText)
                Text(isConnected ? "Câble connecté" : "Aucun câble")
                    .font(.system(size: 22, weight: .heavy)).foregroundStyle(FylioPalette.nightText)
                Text(isConnected
                     ? "Le transfert par câble est actif. Débranche pour revenir au Wi-Fi."
                     : "Branche un câble USB entre ton iPhone et l'appareil cible pour un transfert direct.")
                    .font(.system(size: 15)).foregroundStyle(FylioPalette.secondaryText)
                    .multilineTextAlignment(.center).padding(.horizontal, 24)
                Button(String(localized: "common.done")) { dismiss() }
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 40).padding(.vertical, 14)
                    .background(FylioTokens.sendGradient, in: Capsule())
                    .buttonStyle(FylioPressStyle())
            }
            .padding(32)
            .navigationTitle("Câble")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "common.close")) { dismiss() }
            }}
        }
        .presentationDetents([.medium])
    }
}

/// Guide animé de la mascotte (consignes doc. guide.*).
struct MascotGuideSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image("mascotte_fylio")
                .resizable().scaledToFit()
                .frame(height: 180)
            Text(String(localized: "guide.title"))
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(FylioPalette.nightText)
            Text(String(localized: "guide.subtitle"))
                .font(.system(size: 16))
                .foregroundStyle(FylioPalette.secondaryText)
                .multilineTextAlignment(.center)
            Button(String(localized: "common.done")) { dismiss() }
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 40).padding(.vertical, 14)
                .background(FylioTokens.sendGradient, in: Capsule())
                .buttonStyle(FylioPressStyle())
        }
        .padding(32)
        .presentationDetents([.medium])
    }
}