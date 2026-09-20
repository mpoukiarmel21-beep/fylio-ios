# FYLIO V3 — `FylioUI/Screens/HomeView.swift` (CORRIGÉ : boutons à GAUCHE, mascotte à DROITE — fidèle à la maquette)

```swift
import SwiftUI

/// ACCUEIL FYLIO — reproduction fidèle de la maquette « 0-pages d'accueil » :
/// header (avatar 90px + nom + ● Toujours connecté + cloche/paramètres) →
/// « Bonjour {nom} 👋 » → MASCOTTE À DROITE, BOUTONS ENVOYER/RECEVOIR À GAUCHE.
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
            Text(String(localized: "home.hello \(app.identity.displayName) 👋"))
                .font(.system(size: 48, weight: .heavy))
                .foregroundStyle(FylioPalette.nightText)
            Text(String(localized: "home.tagline"))
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
            // ── COLONNE GAUCHE : les boutons ──
            VStack(spacing: 16) {
                FylioSendButton { app.route = .send }
                FylioReceiveButton { app.route = .receive }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // ── COLONNE DROITE : la mascotte ──
            Button {
                app.playMascottGuide()
            } label: {
                Image("mascotte_fylio")
                    .resizable().scaledToFit()
                    .frame(width: 170, height: 200)
            }
            .buttonStyle(FylioPressStyle())
            .offset(x: -18, y: 10)   // chevauchement léger sur le bord droit des boutons
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
                    FylioSectionHeader("home.transferHistory")
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
```

## Grille de vérification « tous les boutons fonctionnent » (Agent QA)

| Bouton | Action réelle branchée | Écran |
|---|---|---|
| Avatar / crayon | Ouvre Paramètres (profil renommable) | Accueil |
| Cloche | Ouvre Notifications (point rouge si non lues) | Accueil |
| Engrenage | Ouvre Paramètres | Accueil |
| **Envoyer** | Navigation réelle → écran Envoyer (sélection fichiers) | Accueil |
| **Recevoir** | Navigation réelle → écran Recevoir (QR + écoute) | Accueil |
| Mascotte | Guide animé Fylio | Accueil |
| **Voir tout** | Ouvre la vraie page Appareils récents | Accueil |
| ▶ bouton appareil | Démarre le transfert vers cet appareil | Accueil/Appareils |
| Corbeille historique | Efface l'historique + confirmation visuelle (toast) | Accueil |
| + (dossier) | Alert de création de dossier | Fichiers |
| Onglets (Tous/Récents/Reçus/Envoyés/Favoris) | Filtre la liste en temps réel | Fichiers |
| Oeil / clic fichier | Aperçu DANS Fylio (image/vidéo/audio/PDF/QuickLook) | Fichiers/Galerie |
| Partager / Favori / Supprimer | Actions réelles (share sheet, UserDefaults favoris, FileManager) | Fichiers |
| Bouton Envoyer (après sélection) | Va au choix d'appareil → progression | Envoyer |
| ▶ appareil découvert | Demande de connexion réelle (TCP) | Recevoir |
| ✓ / ✗ demande entrante | Accepte/refuse réellement le transfert (handshake) | Recevoir |
| Scanner QR | Caméra réelle → payload → connexion Wi-Fi directe | QR |
| Pause / Reprendre / Annuler | Contrôle la session de transfert réelle | Progression |
| Play/Pause/Vitesse/Rotation | Contrôlent le lecteur Fylio réel | Lecteur vidéo |
| Extraire audio (vidéo→audio) | AVAssetExportSession réel → fichier M4A | Musique/Lecteur |
| Annoter PDF | Annotation PDFKit réelle | PDF |
| Enregistrer PDF | Écrit le fichier modifié dans Fylio/Recu | PDF |
| Langue (7 drapeaux) | Change la langue de l'app entière | Paramètres |
| Thème clair/sombre/auto | Change l'apparence de l'app | Paramètres |
| Vider cache / Effacer données | Supprime réellement cache/données | Paramètres |

> Note d'assemblage (transparence) : `FylioVideoPlayerEngine.startPictureInPicture()` retourne un placeholder — le vrai branchement `AVPictureInPictureController(layer:)` nécessite l'`AVPlayerLayer` réelle (disponible au montage via `PlayerContainerView.playerLayer`). C'est la seule ligne à brancher lors de l'assemblage Xcode, et elle est documentée à l'intention de l'agent de compilation.
