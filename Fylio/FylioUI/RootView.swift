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

/// Onglets principaux : Accueil, Fichiers, Musique, Galerie.
/// (L'Historique n'est plus un onglet — accessible via l'Accueil « Voir tout ».)
struct MainTabView: View {
    @EnvironmentObject var app: AppViewModel
    @State private var pendingIncoming: IncomingTransferRequest?

    var body: some View {
        NavigationStack(path: $app.path) {
            TabView {
                HomeView()
                    .tag(FylioRoute.home)
                    .tabItem { Label(String(localized: "tab.home"), systemImage: "house.fill") }
                FilesView()
                    .tag(FylioRoute.files)
                    .tabItem { Label(String(localized: "tab.files"), systemImage: "folder.fill") }
                MusicView()
                    .tag(FylioRoute.music)
                    .tabItem { Label(String(localized: "tab.music"), systemImage: "music.note") }
                GalleryView()
                    .tag(FylioRoute.gallery)
                    .tabItem { Label(String(localized: "tab.gallery"), systemImage: "photo.on.rectangle") }
            }
            .tint(FylioPalette.electricBlue)
            .navigationDestination(for: FylioRoute.self) { route in
                FylioRouteScreen(route: route)
            }
        }
        .sheet(item: $app.deviceToRename) { peer in
            RenameDeviceSheet(peer: peer)
        }
        .sheet(isPresented: $app.showMascotGuide) {
            MascotGuideSheet()
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