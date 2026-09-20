import SwiftUI

// MARK: - En-tête de section (titre + « Voir tout » fonctionnel)

public struct FylioSectionHeader: View {
    private let titleKey: String
    private let onSeeAll: (() -> Void)?

    public init(_ titleKey: String, onSeeAll: (() -> Void)? = nil) {
        self.titleKey = titleKey
        self.onSeeAll = onSeeAll
    }

    public var body: some View {
        HStack {
            Text(String(localized: String.LocalizationValue(titleKey)))
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(FylioPalette.nightText)
            Spacer()
            if let onSeeAll {
                Button(action: onSeeAll) {
                    HStack(spacing: 4) {
                        Text(String(localized: "common.seeAll"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(FylioPalette.electricBlue)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(FylioPalette.electricBlue)
                    }
                }
                .buttonStyle(FylioPressStyle())
            }
        }
    }
}

// MARK: - État vide animé (personnage dédié par page — jamais le même partout)

public struct FylioEmptyState: View {
    private let characterImage: String
    private let titleKey: String
    private let subtitleKey: String
    @State private var isBouncing = false

    public init(character: String, titleKey: String, subtitleKey: String) {
        self.characterImage = character
        self.titleKey = titleKey
        self.subtitleKey = subtitleKey
    }

    public var body: some View {
        VStack(spacing: 14) {
            Image(characterImage)
                .resizable().scaledToFit()
                .frame(height: 120)
                .scaleEffect(isBouncing ? 1.06 : 0.97)
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true),
                           value: isBouncing)
            Text(String(localized: String.LocalizationValue(titleKey)))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(FylioPalette.nightText)
            Text(String(localized: String.LocalizationValue(subtitleKey)))
                .font(.system(size: 14))
                .foregroundStyle(FylioPalette.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .onAppear { isBouncing = true }
    }
}

// MARK: - Ligne d'appareil récent (avatar + icône plateforme + date relative + actions)

public struct FylioDeviceRow: View {
    private let peer: FylioPeer
    private let onTransfer: () -> Void
    private let onRename: () -> Void
    private let onDelete: () -> Void

    public init(peer: FylioPeer,
                onTransfer: @escaping () -> Void,
                onRename: @escaping () -> Void,
                onDelete: @escaping () -> Void) {
        self.peer = peer
        self.onTransfer = onTransfer
        self.onRename = onRename
        self.onDelete = onDelete
    }

    private var isOnline: Bool {
        peer.lastSeen.timeIntervalSinceNow > -300   // vu il y a moins de 5 min
    }

    public var body: some View {
        HStack(spacing: 14) {
            FylioAvatarView(avatarID: peer.avatarID,
                            size: 52,
                            showsOnlineDot: isOnline)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(peer.displayName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(FylioPalette.nightText)
                    FylioDeviceIcon(peer.platform, size: 18)
                }
                Text(peer.fylioNumber)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FylioPalette.secondaryText)
                Text(RelativeDateTimeFormatter()
                    .localizedString(for: peer.lastSeen, relativeTo: Date()))
                    .font(.system(size: 12))
                    .foregroundStyle(FylioPalette.secondaryText)
            }
            Spacer()
            Button(action: onTransfer) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(FylioPalette.electricBlue)
            }
            .buttonStyle(FylioPressStyle())
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.6), lineWidth: 1))
        .contextMenu {
            Button(String(localized: "devices.rename")) { onRename() }
            Button(String(localized: "devices.delete"), role: .destructive) { onDelete() }
        }
    }
}

// MARK: - Objet animé de progression (parmi les 11 assets, tiré au sort par transfert)

public enum FylioProgressMascot {
    /// Choisit un objet aléatoirement UNE fois par transfert (cohérent toute la durée).
    public static func pick() -> String {
        "progress_obj_\(Int.random(in: 1...11))"
    }
}

public struct FylioProgressObject: View {
    private let objectName: String
    private let fraction: Double
    @State private var bobPhase = false

    public init(objectName: String, fraction: Double) {
        self.objectName = objectName
        self.fraction = fraction
    }

    public var body: some View {
        GeometryReader { geo in
            Image(objectName)
                .resizable().scaledToFit()
                .frame(width: 64, height: 64)
                .rotationEffect(.degrees(bobPhase ? 6 : -6))
                .offset(x: fraction * max(0, geo.size.width - 64),
                        y: bobPhase ? -3 : 3)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                           value: bobPhase)
        }
        .frame(height: 64)
        .onAppear { bobPhase = true }
    }
}

// MARK: - Barre de progression (dégradé bleu, l'objet avance avec elle)

public struct FylioProgressBar: View {
    private let fraction: Double
    private let objectName: String

    public init(fraction: Double, objectName: String) {
        self.fraction = fraction
        self.objectName = objectName
    }

    public var body: some View {
        VStack(spacing: 6) {
            FylioProgressObject(objectName: objectName, fraction: fraction)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(FylioPalette.paleBlue)
                    Capsule().fill(FylioTokens.sendGradient)
                        .frame(width: max(10, fraction * geo.size.width))
                }
            }
            .frame(height: 14)
        }
    }
}

// MARK: - Toast / notification interne Fylio (jamais de renvoi vers apps natives)

public struct FylioToast: ViewModifier {
    @Binding var message: String?
    @State private var workItem: DispatchWorkItem?

    public func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let message {
                Text(message)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FylioPalette.nightText)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.7), lineWidth: 1))
                    .shadow(color: FylioTokens.shadow, radius: 10, y: 5)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(nanoseconds: 2_200_000_000)
                        withAnimation { self.message = nil }
                    }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: message)
    }
}

public extension View {
    func fylioToast(_ message: Binding<String?>) -> some View {
        modifier(FylioToast(message: message))
    }
}