# FYLIO V4 — `FylioUI/DesignSystem/FylioUX.swift` (améliorations UX à chaque clic)

**Principe : chaque clic donne une réponse physique + visuelle. Aucun clic mort, aucun écran figé.**

```swift
import SwiftUI
import UIKit

// MARK: - Haptique Fylio (retour physique à CHAQUE clic)

enum FylioHaptics {
    /// Clic normal (navigation, sélection).
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    /// Clic d'action importante (Envoyer, Accepter).
    static func action() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    /// Succès (transfert terminé).
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    /// Erreur / refus.
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
    /// Tick de progression (tous les 10 %).
    static func progressTick() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

// MARK: - Style de bouton avec haptique intégrée (remplace FylioPressStyle partout)

struct FylioPressStyle: ButtonStyle {
    var haptic: Bool = true

    init(haptic: Bool = true) { self.haptic = haptic }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7),
                       value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { pressed in
                if pressed && haptic { FylioHaptics.tap() }
            }
    }
}

// MARK: - Transitions de navigation (glissement + fondu, jamais de saut sec)

struct FylioRouteTransition: ViewModifier {
    func body(content: Content) -> some View {
        content
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)))
    }
}
extension View {
    /// Applique la transition standard Fylio dans les NavigationStack.
    func fylioRoute() -> some View { modifier(FylioRouteTransition()) }
}

// MARK: - Squelettes de chargement (les listes ne sont JAMAIS vides pendant le chargement)

struct FylioSkeletonRow: View {
    @State private var shimmer = false

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12)
                .fill(FylioPalette.paleBlue)
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(FylioPalette.paleBlue)
                    .frame(width: 160, height: 12)
                RoundedRectangle(cornerRadius: 4)
                    .fill(FylioPalette.paleBlue.opacity(0.7))
                    .frame(width: 90, height: 10)
            }
            Spacer()
        }
        .padding(14)
        .background(.ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .opacity(shimmer ? 0.45 : 1)
        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                   value: shimmer)
        .onAppear { shimmer = true }
    }
}

struct FylioSkeletonList: View {
    var count: Int = 5
    var body: some View {
        VStack(spacing: 10) {
            ForEach(0..<count, id: \.self) {                _ in
                FylioSkeletonRow()
            }
        }
    }
}

// MARK: - Célébration de succès (transfert terminé : mascotte + confettis)

struct FylioSuccessCelebration: View {
    let title: String
    let subtitle: String
    @State private var confettiSeeds: [ConfettiSeed] = []
    @State private var mascotBounce = false

    struct ConfettiSeed: Identifiable {
        let id = UUID()
        let x: CGFloat
        let color: Color
        let delay: Double
    }

    var body: some View {
        VStack(spacing: 18) {
            Image("mascotte_hero")
                .resizable().scaledToFit().frame(height: 150)
                .scaleEffect(mascotBounce ? 1.08 : 0.96)
                .animation(.spring(response: 0.5, dampingFraction: 0.55)
                            .repeatForever(autoreverses: true), value: mascotBounce)
            Text(title)
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(FylioPalette.nightText)
            Text(subtitle)
                .font(.system(size: 15))
                .foregroundStyle(FylioPalette.secondaryText)
            Button {
                // Retour accueil
            } label: {
                Text(String(localized: "common.done"))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(FylioTokens.sendGradient, in: Capsule())
            }
            .buttonStyle(FylioPressStyle())
        }
        .overlay(alignment: .top) {
            ZStack {
                ForEach(confettiSeeds) { seed in
                    FylioConfettiPiece(seed: seed)
                }
            }
            .allowsHitTesting(false)
        }
        .onAppear {
            FylioHaptics.success()
            mascotBounce = true
            let palette: [Color] = [FylioPalette.electricBlue, FylioPalette.secondaryBlue,
                                     FylioPalette.statusGreen, FylioPalette.brightBlue]
            confettiSeeds = (0..<18).map { i in
                ConfettiSeed(x: .random(in: 20...320),
                             color: palette[i % palette.count],
                             delay: Double(i) * 0.05)
            }
        }
    }
}

struct FylioConfettiPiece: View {
    let seed: FylioSuccessCelebration.ConfettiSeed
    @State private var fallen = false

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(seed.color)
            .frame(width: 8, height: 14)
            .rotationEffect(.degrees(fallen ? 720 : 0))
            .offset(x: seed.x, y: fallen ? 620 : -40)
            .opacity(fallen ? 0 : 1)
            .animation(.easeIn(duration: 1.8).delay(seed.delay), value: fallen)
            .onAppear { fallen = true }
    }
}

// MARK: - État d'erreur avec bouton réessayer (jamais d'écran figé)

struct FylioErrorState: View {
    let messageKey: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 42))
                .foregroundStyle(FylioPalette.secondaryText)
            Text(String(localized: String.LocalizationValue(messageKey)))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(FylioPalette.secondaryText)
                .multilineTextAlignment(.center)
            Button(action: onRetry) {
                Label(String(localized: "common.retry"), systemImage: "arrow.clockwise")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22).padding(.vertical, 12)
                    .background(FylioTokens.sendGradient, in: Capsule())
            }
            .buttonStyle(FylioPressStyle())
        }
        .onAppear { FylioHaptics.error() }
    }
}

// MARK: - Guide de première utilisation (mascotte qui pointe les zones)

struct FylioMascotGuideOverlay: View {
    let onDismiss: () -> Void
    @State private var bobbing = false

    var body: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom, spacing: 12) {
                Image("mascotte_fylio")
                    .resizable().scaledToFit().frame(height: 120)
                    .offset(y: bobbing ? -6 : 4)
                    .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                               value: bobbing)
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "guide.title"))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(FylioPalette.nightText)
                    Text(String(localized: "guide.subtitle"))
                        .font(.system(size: 13))
                        .foregroundStyle(FylioPalette.secondaryText)
                }
                .padding(16)
                .background(.ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(FylioPalette.secondaryText)
                }
            }
            .padding(20)
        }
        .onAppear { bobbing = true }
    }
}

// MARK: - Progression : tick haptique tous les 10 %

struct ProgressHaptifier: ViewModifier {
    let fraction: Double
    @State private var lastTickBucket = 0

    func body(content: Content) -> some View {
        content.onChange(of: fraction) { newValue in
            let bucket = Int(newValue * 10)
            if bucket > lastTickBucket {
                lastTickTick = bucket
                FylioHaptics.progressTick()
            }
        }
    }
    @State private var lastTickTick = 0
}
```

## Carte du parcours utilisateur (chaque clic → où il tombe)

| Clic | L'utilisateur tombe sur | Retour ressenti |
|---|---|---|
| Envoyer | Écran de sélection : fichiers triés par récence, squelettes 0,3 s pendant l'indexation, compteur de sélection animé | Haptique + zoom + glissement |
| Recevoir | QR visible immédiatement (pas d'attente) + liste découverte qui se remplit en direct avec apparition animée | Haptique + apparition en cascade |
| Voir tout | Page appareils complète, squelettes si chargement, personnage vide si 0 appareil | Haptique + glissement |
| ▶ appareil | Écran progression avec objet animé + tick haptique tous les 10 % + ETA temps réel | Vibration + mouvement continu |
| Fin de transfert | **Célébration : mascotte + confettis + haptique succès**, puis retour accueil avec l'entrée d'historique qui apparaît | Triple retour |
| ✓/✗ demande entrante | Accept → progression démarre instantanément ; Refus → haptique erreur + toast « refusé » | Réponse immédiate |
| Scanner QR | Cadre animé, ligne de balayage, vibration au scan, connexion automatique | Vibration scan |
| Fichier (clic) | Aperçu dans Fylio (image/vidéo/audio/PDF), squelette pendant l'ouverture | Haptique + fondu |
| Créer dossier | Alert avec suggestion de nom, le dossier apparaît animé en tête de liste | Haptique + apparition |
| Effacer historique | Confirmation, puis liste se vide avec animation + toast | Haptique |
| Paramètres → Langue | La langue change instantanément dans TOUTE l'app (redémarrage non requis pour la plupart des éléments) | Haptique |
| Transfert refusé/échoué | État d'erreur avec **bouton Réessayer** + proposition de méthode alternative (QR au lieu de Wi-Fi) | Haptique erreur |
