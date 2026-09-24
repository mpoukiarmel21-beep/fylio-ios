import SwiftUI
import PhotosUI

/// Première ouverture : Langue → avatar/personnage → nom → permissions → méthodes → accueil.
/// Flow iOS : Splash bleu centré (via UILaunchScreen logo_fylio) → Language → Avatar → Nom → Permissions.

struct LanguageOnboardingView: View {
    @AppStorage("fylio.languageOverride") private var languageOverride: String = "auto"
    @Environment(\.dismiss) private var dismiss
    @State private var selected: String = Locale.current.language.languageCode?.identifier ?? "fr"

    private let languages: [(code: String, label: String, flag: String)] = [
        ("fr","Français","🇫🇷"), ("en","English","🇬🇧"), ("es","Español","🇪🇸"),
        ("pt","Português","🇵🇹"), ("ar","العربية","🇸🇦"), ("zh-Hans","中文","🇨🇳"),
        ("hi","हिन्दी","🇮🇳"), ("bn","বাংলা","🇧🇩"), ("ru","Русский","🇷🇺"),
    ]

    var body: some View {
        ZStack {
            FylioBackground()
            VStack(spacing: 20) {
                Image("logo_fylio").resizable().scaledToFit()
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.14), radius: 10, y: 6)
                Text("Choisis ta langue").font(.system(size: 26, weight: .heavy)).foregroundStyle(.white)
                Text("Cette app parle 9 langues — change à tout moment dans Réglages.")
                    .font(.system(size: 13)).foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center).padding(.horizontal, 24)
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(languages, id: \.code) { lang in
                            Button {
                                selected = lang.code
                                languageOverride = lang.code
                                UserDefaults.standard.set([lang.code], forKey: "AppleLanguages")
                                FylioHaptics.tap()
                            } label: {
                                HStack(spacing: 8) {
                                    Text(lang.flag).font(.system(size: 20))
                                    Text(lang.label).font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(selected == lang.code ? .white : FylioPalette.nightText)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(selected == lang.code ? FylioTokens.sendGradient : AnyShapeStyle(.ultraThinMaterial),
                                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.6), lineWidth: 1))
                            }.buttonStyle(FylioPressStyle(haptic: false))
                        }
                    }.padding(.horizontal, 20)
                }
                Button {
                    languageOverride = selected
                    dismiss()
                } label: {
                    Text("Continuer  →").font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(FylioTokens.sendGradient, in: Capsule())
                }.padding(.horizontal, 20).buttonStyle(FylioPressStyle())
            }
            .padding(.vertical, 24)
        }
    }
}

/// Première ouverture : bienvenue → avatar (6 personnages retaillés) → nom → permissions → méthodes → accueil.
struct OnboardingView: View {
    @EnvironmentObject var app: AppViewModel
    @State private var page = 0
    @State private var selectedAvatar = 1
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var showPhotoPicker = false
    @State private var name = ""
    @State private var showLanguage = false

    private let totalPages = 5

    var body: some View {
        ZStack {
            FylioBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    content
                    controls
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showLanguage) { LanguageOnboardingView() }
        .onAppear {
            // Auto-détection langue appareil → pré-sélection (override si pas encore choisi)
            let sys = Locale.current.language.languageCode?.identifier ?? "fr"
            if UserDefaults.standard.string(forKey: "fylio.languageOverride") == nil {
                // ne force pas, juste propose — l'utilisateur peut changer
                _ = sys
            }
            // Affiche la feuille langue au premier lancement si jamais choisie
            if UserDefaults.standard.string(forKey: "fylio.languageOverride") == nil {
                showLanguage = true
            }
        }
    }

    // MARK: - Contenu par page

    @ViewBuilder
    private var content: some View {
        switch page {
        case 0:
            welcomePage
        case 1:
            avatarPage
        case 2:
            namePage
        case 3:
            permissionsPage
        default:
            methodsPage
        }
    }

    private var welcomePage: some View {
        VStack(spacing: 18) {
            Image("mascotte_fylio")
                .resizable().scaledToFit()
                .frame(width: 180, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 12, y: 8)
            Text(String(localized: "onboarding.welcome.title"))
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(String(localized: "onboarding.welcome.subtitle"))
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.86))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
    }

    private var avatarPage: some View {
        VStack(spacing: 16) {
            Text(String(localized: "onboarding.avatar.title"))
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text("Choisis un personnage ou ajoute ta photo")
                .font(.system(size: 13)).foregroundStyle(.white.opacity(0.78))
            FylioAvatarPicker(selection: $selectedAvatar,
                              photoData: photoData) {
                showPhotoPicker = true
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem,
                          matching: .images)
            .onChange(of: photoItem) { item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        photoData = data
                        selectedAvatar = -1
                    }
                }
            }
        }
    }

    private var namePage: some View {
        VStack(spacing: 16) {
            Text(String(localized: "onboarding.name.title"))
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(.white)
            Text(String(localized: "onboarding.name.subtitle"))
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.82))
                .multilineTextAlignment(.center)
            TextField(app.suggestedDeviceName, text: $name)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(FylioPalette.nightText)
                .padding(16)
                .background(Color.white.opacity(0.94),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.6), lineWidth: 1))
                .textInputAutocapitalization(.words)
        }
    }

    private var permissionsPage: some View {
        VStack(spacing: 16) {
            Text(String(localized: "onboarding.permissions.title"))
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(String(localized: "onboarding.permissions.subtitle"))
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.82))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            Text("Appareil photo (QR) · Réseau local (découverte) · Photos (import)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
            ForEach(0..<3, id: \.self) { index in
                permissionRow(index)
            }
            if app.permissionStates.allSatisfy({ $0 == .granted }) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(FylioPalette.statusGreen)
                    Text(String(localized: "onboarding.permissions.allGranted"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FylioPalette.statusGreen)
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: app.permissionStates)
    }

    private func permissionRow(_ index: Int) -> some View {
        let granted = index < app.permissionStates.count && app.permissionStates[index] == .granted
        let denied = index < app.permissionStates.count && app.permissionStates[index] == .denied
        return Button { app.requestPermission(index: index) } label: {
            HStack(spacing: 14) {
                Image(systemName: permissionIcon(index))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(FylioPalette.electricBlue)
                    .frame(width: 34, height: 34)
                    .background(FylioPalette.secondaryBlue.opacity(0.15), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "onboarding.permissions.\(index).title"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(FylioPalette.nightText)
                    Text(String(localized: "onboarding.permissions.\(index).subtitle"))
                        .font(.system(size: 13))
                        .foregroundStyle(FylioPalette.secondaryText)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: iconFor(granted: granted, denied: denied))
                    .font(.system(size: 22))
                    .foregroundStyle(granted ? FylioPalette.statusGreen
                                    : denied ? Color.red
                                    : FylioPalette.secondaryText)
            }
            .padding(14)
            .background(.ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(FylioPressStyle())
    }

    private func iconFor(granted: Bool, denied: Bool) -> String {
        granted ? "checkmark.circle.fill" : denied ? "xmark.circle.fill" : "circle"
    }

    private func permissionIcon(_ index: Int) -> String {
        switch index {
        case 0: return "dot.radiowaves.left.and.right" // Réseau local (Bonjour)
        case 1: return "camera.on.rectangle"            // Appareil photo (QR)
        default: return "photo.on.rectangle.angled"     // Photothèque + sauvegarde (Photos + Add)
        }
    }

    private var methodsPage: some View {
        VStack(spacing: 16) {
            Image("mascotte_fylio")
                .resizable().scaledToFit()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            Text(String(localized: "onboarding.methods.title"))
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(.white)
            ForEach(0..<6, id: \.self) { index in
                methodRow(String(localized: "onboarding.methods.\(index).title"))
            }
        }
    }

    private func methodRow(_ title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(FylioPalette.secondaryBlue)
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(FylioPalette.nightText)
            Spacer()
        }
        .padding(14)
        .background(.ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Contrôles

    private var controls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? FylioPalette.electricBlue : Color.white.opacity(0.35))
                        .frame(width: index == page ? 22 : 8, height: 8)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8),
                                   value: page)
                }
            }
            Button {
                advance()
            } label: {
                Text(page == totalPages - 1
                     ? String(localized: "onboarding.done")
                     : page == 3
                     ? String(localized: "onboarding.permissions.continue")
                     : String(localized: "onboarding.next"))
                    .font(.system(size: 17, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(page == 3 && isBlockedByPermissions
                                ? AnyShapeStyle(Color.white.opacity(0.55))
                                : AnyShapeStyle(FylioTokens.sendGradient), in: Capsule())
                    .foregroundStyle(page == 3 && isBlockedByPermissions
                                     ? FylioPalette.nightText
                                     : .white)
                    .overlay(Capsule().stroke(Color.white.opacity(0.55), lineWidth: page == 3 && isBlockedByPermissions ? 1 : 0))
            }
            .buttonStyle(FylioPressStyle())
            .animation(.spring(response: 0.3), value: isBlockedByPermissions)
        }
    }

    private var isBlockedByPermissions: Bool {
        page == 3 && app.permissionStates.contains(where: { $0 != .granted })
    }

    private func advance() {
        guard page < totalPages - 1 else {
            app.completeOnboarding(avatar: selectedAvatar,
                                   photo: photoData,
                                   name: name)
            return
        }
        // Permissions : on encourage à tout accorder, mais on ne bloque pas (l'app reste utilisable en dégradé)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            page += 1
        }
    }
}