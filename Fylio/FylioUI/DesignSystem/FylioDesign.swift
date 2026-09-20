import SwiftUI

// MARK: - Palette (maquette d'accueil, source de vérité)

public enum FylioPalette {
    public static let whiteIce      = Color(hex: 0xEFF7FD)
    public static let paleBlue      = Color(hex: 0xD3EAFB)
    public static let lightBlue     = Color(hex: 0xB2DAF7)
    public static let brightBlue    = Color(hex: 0x8AC9F9)
    public static let electricBlue  = Color(hex: 0x036FF8)
    public static let secondaryBlue = Color(hex: 0x31ACF2)
    public static let nightText     = Color(hex: 0x071A68)
    public static let secondaryText = Color(hex: 0x4E7FC1)
    public static let statusGreen   = Color(hex: 0x16C79A)
    public static let alertRed      = Color(hex: 0xFF5A5F)
}

public extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

// MARK: - Tokens (rayons, ombres, espacements — maquette)

public enum FylioTokens {
    public static let screenMargin: CGFloat = 40          // 35–45 px
    public static let cornerCard: CGFloat = 28
    public static let cornerButtonBig: CGFloat = 38       // 35–40 px gros boutons
    public static let cornerButtonSmall: CGFloat = 22
    public static let avatarHeader: CGFloat = 90
    public static let spacingSection: CGFloat = 35
    public static let shadow = Color.black.opacity(0.06)

    public static let sendGradient = LinearGradient(
        colors: [FylioPalette.electricBlue, Color(hex: 0x09BDF5)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
}

// MARK: - Fond de l'application (dégradé radial + formes organiques, jamais bleu plat)

public struct FylioBackground: View {
    @Environment(\.colorScheme) private var scheme

    public init() {}

    public var body: some View {
        ZStack {
            (scheme == .dark
                ? LinearGradient(colors: [Color(hex: 0x061228), Color(hex: 0x0A1E40)],
                                 startPoint: .top, endPoint: .bottom)
                : LinearGradient(colors: [FylioPalette.whiteIce, FylioPalette.paleBlue],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            RadialGradient(colors: [Color.white.opacity(0.9), .clear],
                           center: UnitPoint(x: 0.5, y: 0.3), startRadius: 0, endRadius: 500)
            // Formes organiques translucides (rubans de verre discrets)
            Circle().fill(FylioPalette.brightBlue.opacity(0.18))
                .blur(radius: 60)
                .frame(width: 320, height: 320)
                .offset(x: -140, y: 120)
            Circle().fill(FylioPalette.secondaryBlue.opacity(0.12))
                .blur(radius: 80)
                .frame(width: 380, height: 380)
                .offset(x: 160, y: -180)
            RoundedRectangle(cornerRadius: 90)
                .fill(FylioPalette.lightBlue.opacity(0.10))
                .frame(width: 420, height: 160)
                .rotationEffect(.degrees(-12))
                .offset(y: 420)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Carte glassmorphism (panneaux translucides de la maquette)

public struct FylioGlassCard<Content: View>: View {
    private let content: Content
    private var corner: CGFloat = FylioTokens.cornerCard

    public init(corner: CGFloat = FylioTokens.cornerCard,
                @ViewBuilder content: () -> Content) {
        self.corner = corner
        self.content = content()
    }

    public var body: some View {
        content
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .stroke(Color.white.opacity(0.6), lineWidth: 1))
            .shadow(color: FylioTokens.shadow, radius: 12, y: 6)
    }
}

// MARK: - Bouton circulaire translucide (cloche / paramètres)

public struct FylioIconButton: View {
    private let systemIcon: String
    private let showsRedDot: Bool
    private let action: () -> Void

    public init(_ systemIcon: String, showsRedDot: Bool = false, action: @escaping () -> Void) {
        self.systemIcon = systemIcon
        self.showsRedDot = showsRedDot
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Circle().fill(.ultraThinMaterial)
                    Circle().stroke(Color.white.opacity(0.7), lineWidth: 1)
                    Image(systemName: systemIcon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(FylioPalette.nightText)
                }
                .frame(width: 62, height: 62)
                if showsRedDot {
                    Circle().fill(FylioPalette.alertRed)
                        .frame(width: 12, height: 12)
                        .offset(x: 3, y: -1)
                }
            }
        }
        .buttonStyle(FylioPressStyle())
    }
}

// MARK: - Bouton principal « Envoyer » (dégradé #036FF8 → #09BDF5)

public struct FylioSendButton: View {
    private let action: () -> Void

    public init(action: @escaping () -> Void) { self.action = action }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "home.send"))
                        .font(.system(size: 30, weight: .bold)).foregroundStyle(.white)
                    Text(String(localized: "home.send.subtitle"))
                        .font(.system(size: 17))
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
            .frame(height: 132)
            .background(FylioTokens.sendGradient, in: RoundedRectangle(cornerRadius: FylioTokens.cornerButtonBig, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: FylioTokens.cornerButtonBig, style: .continuous)
                        .stroke(Color.white.opacity(0.4), lineWidth: 1))
            .shadow(color: FylioPalette.electricBlue.opacity(0.35), radius: 14, y: 8)
        }
        .buttonStyle(FylioPressStyle())
    }
}

// MARK: - Bouton « Recevoir » (blanc translucide, icône téléchargement bleue)

public struct FylioReceiveButton: View {
    private let action: () -> Void

    public init(action: @escaping () -> Void) { self.action = action }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(FylioPalette.electricBlue.opacity(0.12))
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(FylioPalette.electricBlue)
                }
                .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "home.receive"))
                        .font(.system(size: 28, weight: .bold)).foregroundStyle(FylioPalette.nightText)
                    Text(String(localized: "home.receive.subtitle"))
                        .font(.system(size: 16)).foregroundStyle(FylioPalette.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 22, weight: .bold)).foregroundStyle(FylioPalette.secondaryBlue)
            }
            .padding(.horizontal, 24)
            .frame(height: 120)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: FylioTokens.cornerButtonBig, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: FylioTokens.cornerButtonBig, style: .continuous)
                        .stroke(Color.white.opacity(0.65), lineWidth: 1))
            .shadow(color: FylioTokens.shadow, radius: 10, y: 6)
        }
        .buttonStyle(FylioPressStyle())
    }
}

// MARK: - Avatar (cercle fond bleu clair, contour blanc, point vert en ligne)

public struct FylioAvatarView: View {
    private let avatarID: Int          // 1...6, -1 = photo perso
    private let photoData: Data?
    private let size: CGFloat
    private let showsOnlineDot: Bool

    public init(avatarID: Int, photoData: Data? = nil,
                size: CGFloat = FylioTokens.avatarHeader, showsOnlineDot: Bool = true) {
        self.avatarID = avatarID
        self.photoData = photoData
        self.size = size
        self.showsOnlineDot = showsOnlineDot
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                Circle().fill(FylioPalette.lightBlue.opacity(0.5))
                if let data = photoData, let img = UIImage(data: data) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    Image("personage\(max(1, min(6, avatarID)))")
                        .resizable().scaledToFill()
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white, lineWidth: 3))
            .shadow(color: FylioTokens.shadow, radius: 8, y: 4)

            if showsOnlineDot {
                Circle().fill(FylioPalette.statusGreen)
                    .frame(width: size * 0.22, height: size * 0.22)
                    .overlay(Circle().stroke(.white, lineWidth: 3))
            }
        }
    }
}

// MARK: - Sélecteur d'avatar onboarding (cercle, contour bleu + fond bleu clair si sélectionné)

public struct FylioAvatarPicker: View {
    @Binding var selection: Int
    private let photoData: Data?
    private let onImportPhoto: () -> Void

    public init(selection: Binding<Int>, photoData: Data?,
                onImportPhoto: @escaping () -> Void) {
        self._selection = selection
        self.photoData = photoData
        self.onImportPhoto = onImportPhoto
    }

    public var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: 3), spacing: 18) {
            ForEach(1...6, id: \.self) { idx in
                Button { selection = idx } label: {
                    Image("personage\(idx)")
                        .resizable().scaledToFill()
                        .frame(width: 92, height: 92)
                        .clipShape(Circle())
                        .background(Circle().fill(selection == idx
                                ? FylioPalette.lightBlue
                                : FylioPalette.paleBlue.opacity(0.5)))
                        .overlay(Circle().stroke(selection == idx
                                ? FylioPalette.electricBlue : Color.white,
                                lineWidth: selection == idx ? 4 : 2))
                        .scaleEffect(selection == idx ? 1.05 : 1)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selection)
                }
                .buttonStyle(FylioPressStyle())
            }
            Button(action: onImportPhoto) {
                ZStack {
                    Circle().fill(FylioPalette.paleBlue.opacity(0.6))
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(FylioPalette.electricBlue)
                }
                .frame(width: 92, height: 92)
                .overlay(Circle().stroke(selection == -1 ? FylioPalette.electricBlue : Color.white,
                                         lineWidth: selection == -1 ? 4 : 2))
            }
            .buttonStyle(FylioPressStyle())
        }
    }
}

// MARK: - Icône appareil par plateforme (éléments 5/6/7 : Android / ordinateur / iPhone)

public struct FylioDeviceIcon: View {
    private let platform: FylioPlatform
    private let size: CGFloat

    public init(_ platform: FylioPlatform, size: CGFloat = 44) {
        self.platform = platform
        self.size = size
    }

    public var body: some View {
        Image(platform.assetName)
            .resizable().scaledToFit()
            .frame(width: size, height: size)
    }
}