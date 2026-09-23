import SwiftUI

// MARK: - Palier 1 : Bottom 4 + 1 détaché (spec vitrée 52% + câble)

public enum FylioTab: Int, CaseIterable, Identifiable {
    case home = 0, files, music, gallery
    public var id: Int { rawValue }

    public var titleKey: String {
        switch self {
        case .home: return "tab.home"
        case .files: return "tab.files"
        case .music: return "tab.music"
        case .gallery: return "tab.gallery"
        }
    }
    public var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .files: return "folder.fill"
        case .music: return "music.note"
        case .gallery: return "photo.on.rectangle"
        }
    }
    public var systemImageOutline: String {
        switch self {
        case .home: return "house"
        case .files: return "folder"
        case .music: return "music.note"
        case .gallery: return "photo.on.rectangle.angled"
        }
    }
}

// MARK: - Bouton câble détaché (mini USB-C ⊂──⊃, 56×56, 2 états)

public struct FylioCableButton: View {
    public var isConnected: Bool
    public var action: () -> Void
    @State private var pulse = false

    public init(isConnected: Bool, action: @escaping () -> Void) {
        self.isConnected = isConnected
        self.action = action
    }

    public var body: some View {
        Button(action: {
            FylioHaptics.tap()
            action()
        }) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Circle()
                        .fill(isConnected
                              ? FylioPalette.statusGreen.opacity(0.14)
                              : Color.white.opacity(0.68))
                        .background(.ultraThinMaterial, in: Circle())
                    Circle()
                        .stroke(isConnected
                                ? FylioPalette.statusGreen.opacity(0.30)
                                : Color.white.opacity(0.55), lineWidth: 1)
                    // mini câble : SF Symbol (iOS 17) sinon fallback
                    Image(systemName: isConnected ? "cable.connector" : "cable.connector")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(isConnected
                                         ? FylioPalette.statusGreen
                                         : FylioPalette.secondaryText.opacity(0.85))
                        .scaleEffect(pulse && isConnected ? 1.06 : 1)
                }
                .frame(width: FylioTokens.cableButtonSize, height: FylioTokens.cableButtonSize)
                .shadow(color: isConnected
                        ? FylioPalette.statusGreen.opacity(0.32)
                        : FylioTokens.shadowGlass, radius: isConnected ? 12 : 10, y: 5)
                .overlay {
                    if isConnected {
                        Circle().fill(FylioPalette.statusGreen)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(.white, lineWidth: 1.5))
                            .offset(x: 4, y: -4)
                    }
                }
            }
        }
        .buttonStyle(FylioPressStyle())
        .onAppear { if isConnected { pulse = true } }
        .onChange(of: isConnected) { connected in
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                pulse = connected
            }
        }
        .accessibilityLabel(isConnected ? "Câble connecté" : "Câble")
    }
}

// MARK: - Barre du bas 4 + 1 détaché (pill vitrée flottante + bouton câble séparé 12px)

public struct FylioBottomBar: View {
    @Binding public var selected: FylioTab
    public var isCableConnected: Bool
    public var onCableTap: () -> Void

    public init(selected: Binding<FylioTab>, isCableConnected: Bool, onCableTap: @escaping () -> Void) {
        self._selected = selected
        self.isCableConnected = isCableConnected
        self.onCableTap = onCableTap
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Bloc principal 4 tabs
            HStack(spacing: 0) {
                ForEach(FylioTab.allCases) { tab in
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            selected = tab
                        }
                        FylioHaptics.tap()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: selected == tab ? tab.systemImage : tab.systemImageOutline)
                                .font(.system(size: 20, weight: selected == tab ? .bold : .medium))
                                .foregroundStyle(selected == tab
                                                 ? FylioPalette.electricBlue
                                                 : FylioPalette.secondaryText.opacity(0.85))
                            Text(String(localized: String.LocalizationValue(tab.titleKey)))
                                .font(.system(size: 11, weight: selected == tab ? .bold : .medium))
                                .foregroundStyle(selected == tab
                                                 ? FylioPalette.nightText
                                                 : FylioPalette.secondaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            if selected == tab {
                                Capsule()
                                    .fill(FylioPalette.electricBlue.opacity(0.10))
                                    .padding(.horizontal, 6)
                            }
                        }
                        .overlay(alignment: .bottom) {
                            if selected == tab {
                                Capsule()
                                    .fill(FylioPalette.electricBlue)
                                    .frame(width: 20, height: 3)
                                    .offset(y: 6)
                            }
                        }
                    }
                    .buttonStyle(FylioPressStyle(haptic: false))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(height: FylioTokens.bottomNavHeight)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: FylioTokens.radiusPill, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: FylioTokens.radiusPill, style: .continuous)
                .stroke(FylioTokens.glassBorder, lineWidth: 1))
            .shadow(color: FylioTokens.shadowGlass, radius: 16, y: 8)

            FylioCableButton(isConnected: isCableConnected, action: onCableTap)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}

#if DEBUG
#Preview {
    @Previewable @State var tab: FylioTab = .home
    ZStack {
        FylioBackground()
        VStack {
            Spacer()
            FylioBottomBar(selected: $tab, isCableConnected: true) {}
            FylioBottomBar(selected: $tab, isCableConnected: false) {}
        }
    }
}
#endif
