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
            ForEach(0..<count, id: \.self) {