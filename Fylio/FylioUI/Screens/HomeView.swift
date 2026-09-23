import SwiftUI

/// ACCUEIL FYLIO — reproduction fidèle de la maquette « 0-pages d'accueil » :
/// header (avatar 90px + nom + "toujours connecté" + cloche/paramètres) →
/// message d'accueil → MASCOTTE À DROITE, BOUTONS ENVOYER/RECEVOIR À GAUCHE.
struct HomeView: View {
    @EnvironmentObject var app: AppViewModel
    @State private var toast: String?

    var body: some View {
        ZStack {
            FylioBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: FylioTokens.spacingSection) {
                    header
                    greeting
                    actionZone          // ← mascotte à DROITE, boutons à GAUCHE
                    devicesCard
                    historyCard
                }
            .padding(.horizontal, FylioTokens.screenMargin)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .fylioToast($toast)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            Button { app.route = .settings } label: {
                FylioAvatarView(avatarID: app.identity.avatarID,
                                photoData: app.avatarPhotoData,
                                size: FylioTokens.avatarHeader)
            }
            .buttonStyle(FylioPressStyle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(app.identity.displayName)
                        .font(.system(size: 37, weight: .heavy))
                        .foregroundStyle(FylioPalette.nightText)
                    Button { app.route = .settings } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(FylioPalette.secondaryBlue)
                    }
                }
                HStack(spacing: 6) {
                    Circle().fill(FylioPalette.statusGreen).frame(width: 9, height: 9)
                    Text(String(localized: "home.alwaysConnected"))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(FylioPalette.secondaryText)
                }
            }
            Spacer(minLength: 12)

            // Loupe → navigateur interne (YouTube, Google, tout site — Palier 2 spec)
            FylioIconButton("magnifyingglass") {
                app.route = .browser
            }
            FylioIconButton("bell.badge", showsRedDot: app.hasUnreadNotifications) {
                app.route = .notifications
            }
            FylioIconButton("gearshape") {
                app.route = .settings
            }
        }
    }

    // MARK: Message d'accueil

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(format: String(localized: "home.hello"), app.identity.displayName))
                .font(.system(size: 48, weight: .heavy))
                .foregroundStyle(FylioPalette.nightText)
            Text(String(localized: "home.greeting"))
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(FylioPalette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: ★ ZONE D'ACTION — CORRECTION DE PLACEMENT ★
    // Maquette : les BOUTONS Envoyer/Recevoir sont à GAUCHE, la MASCOTTE est
    // à DROITE (elle regarde les boutons, chevauche légèrement leur bord droit).

    private var actionZone: some View {
        HStack(alignment: .bottom, spacing: 0) {
            VStack(spacing: 16) {
                FylioSendButton { app.route = .send }
                FylioReceiveButton { app.route = .receive }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                app.playMascottGuide()
            } label: {
                Image("mascotte_fylio")
                    .resizable().scaledToFit()
                    .frame(width: 170, height: 200)
            }
            .buttonStyle(FylioPressStyle())
            .offset(x: -18, y: 10)
        }
    }

    // MARK: Carte Appareils récents (personnage si vide, liste si contenu)

    private var devicesCard: some View {
        FylioGlassCard {
            VStack(alignment: .leading, spacing: 14) {
                FylioSectionHeader("home.recentDevices") {
                    app.route = .devices
                }
                FylioEmptyStateSlot(registry: .recentDevices,
                                    isEmpty: app.recentDevices.isEmpty)
                ForEach(app.recentDevices.prefix(3)) { peer in
                    FylioDeviceRow(peer: peer,
                                   onTransfer: { app.startTransfer(to: peer) },
                                   onRename: { app.renameDevice(peer) },
                                   onDelete: { app.deleteDevice(peer) })
                }
            }
        }
    }

    // MARK: Carte Historique (personnage si vide, entrées si contenu)

    private var historyCard: some View {
        FylioGlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    FylioSectionHeader("home.transferHistory") {
                        app.route = .history
                    }
                    if !app.history.isEmpty {
                        Button {
                            app.clearHistory { toast = String(localized: "history.cleared") }
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(FylioPalette.secondaryBlue)
                        }
                        .buttonStyle(FylioPressStyle())
                    }
                }
                FylioEmptyStateSlot(registry: .transferHistory,
                                    isEmpty: app.history.isEmpty)
                ForEach(app.history.prefix(4)) { entry in
                    HStack(spacing: 12) {
                        FylioDeviceIcon(entry.platform, size: 26)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(FylioPalette.nightText)
                            Text("\(entry.count) · \(entry.formattedSize) · \(entry.relativeDate)")
                                .font(.system(size: 12))
                                .foregroundStyle(FylioPalette.secondaryText)
                        }
                        Spacer()
                        Image(systemName: entry.direction == .sent
                              ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(entry.direction == .sent
                                             ? FylioPalette.secondaryBlue
                                             : FylioPalette.statusGreen)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }
}