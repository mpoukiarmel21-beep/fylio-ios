import SwiftUI

// MARK: - Palier 1 : Primitives vitrées épurées (52% + blur 22, iOS 26 Liquid Glass)

/// Container vitré générique — respecte la spec Palier 1 glass-52 / glass-68.
public struct FylioGlass<Content: View>: View {
    public var opacity: Double
    public var cornerRadius: CGFloat
    public var borderOpacity: Double
    private let content: Content

    public init(opacity: Double = 0.52,
                cornerRadius: CGFloat = 20,
                borderOpacity: Double = 0.55,
                @ViewBuilder content: () -> Content) {
        self.opacity = opacity
        self.cornerRadius = cornerRadius
        self.borderOpacity = borderOpacity
        self.content = content()
    }

    public var body: some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(borderOpacity), lineWidth: 1))
            .shadow(color: FylioTokens.shadowGlass, radius: 12, y: 6)
    }
}

/// Chip / pill vitrée (filtres, tags) — inactif vitré, actif gradient bleu.
public struct FylioPill: View {
    public var title: String
    public var isActive: Bool
    public var action: () -> Void

    public init(_ title: String, isActive: Bool, action: @escaping () -> Void) {
        self.title = title
        self.isActive = isActive
        self.action = action
    }

    public var body: some View {
        Button(action: {
            FylioHaptics.tap()
            action()
        }) {
            Text(title)
                .font(.system(size: 14, weight: isActive ? .bold : .semibold))
                .foregroundStyle(isActive ? .white : FylioPalette.secondaryText)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background {
                    if isActive {
                        Capsule().fill(FylioTokens.sendGradient)
                            .shadow(color: FylioPalette.electricBlue.opacity(0.28), radius: 10, y: 5)
                    } else {
                        Capsule().fill(Color.white.opacity(0.68))
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.55), lineWidth: 1))
                            .shadow(color: FylioTokens.shadowGlass, radius: 8, y: 4)
                    }
                }
                .scaleEffect(isActive ? 1.02 : 1)
                .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isActive)
        }
        .buttonStyle(FylioPressStyle(haptic: false))
    }
}

/// Barre de recherche vitrée (style Pages Musique element 6).
public struct FylioSearchBar: View {
    @Binding public var text: String
    public var placeholder: String

    public init(text: Binding<String>, placeholder: String = "") {
        self._text = text
        self.placeholder = placeholder
    }

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(FylioPalette.electricBlue)
            TextField(placeholder.isEmpty ? String(localized: "common.search") : placeholder,
                      text: $text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(FylioPalette.nightText)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(FylioPalette.secondaryText.opacity(0.6))
                }
                .buttonStyle(FylioPressStyle(haptic: false))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(Color.white.opacity(0.55), lineWidth: 1))
        .shadow(color: FylioTokens.shadowGlass, radius: 10, y: 4)
    }
}

#if DEBUG
#Preview {
    ZStack {
        FylioBackground()
        VStack(spacing: 16) {
            FylioGlass(opacity: 0.52, cornerRadius: 28) {
                Text("Card 52%").foregroundStyle(FylioPalette.nightText).padding(20)
            }
            HStack(spacing: 10) {
                FylioPill("Tous", isActive: true) {}
                FylioPill("Récents", isActive: false) {}
                FylioPill("Favoris", isActive: false) {}
            }
            FylioSearchBar(text: .constant(""), placeholder: "Rechercher…")
        }
        .padding()
    }
}
#endif
