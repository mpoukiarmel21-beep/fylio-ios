import SwiftUI

/// ACCUEIL — Rebuild : header propre, greeting lisible, 2 boutons pleine largeur verticaux (texte horizontal), mascotte retaillée en dessous, pas de chevauchement.
struct HomeView: View {
    @EnvironmentObject var app: AppViewModel
    @State private var toast: String?

    var body: some View {
        ZStack {
            FylioBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    header
                    greeting
                    mascotteRow
                    actionButtons
                    devicesCard
                    historyCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 36)
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

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(app.identity.displayName)
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Button { app.route = .settings } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                HStack(spacing: 6) {
                    Circle().fill(FylioPalette.statusGreen).frame(width: 8, height: 8)
                    Text(String(localized: "home.alwaysConnected"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.82))
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

    // MARK: Message d'accueil — optimisé copywriting

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(format: String(localized: "home.hello"), app.identity.displayName))
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text(String(localized: "home.greeting"))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.88))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Mascotte retaillée (centrée, sous le greeting, ne chevauche plus les boutons)

    private var mascotteRow: some View {
        Button { app.playMascottGuide() } label: {
            Image("mascotte_fylio")
                .resizable().scaledToFit()
                .frame(width: 132, height: 132)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.14), radius: 10, y: 6)
        }
        .buttonStyle(FylioPressStyle())
        .frame(maxWidth: .infinity)
    }

    // MARK: Boutons Envoyer / Recevoir — pleine largeur, verticaux, texte HORIZONTAL (jamais vertical)

    private var actionButtons: some View {
        VStack(spacing: 14) {
            FylioSendButton { app.route = .send }
            FylioReceiveButton { app.route = .receive }
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