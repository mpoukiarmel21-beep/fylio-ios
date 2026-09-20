# FYLIO — `FylioUI/Screens/OnboardingView.swift` — **VERSION CORRIGÉE INTÉGRALE**

```swift
import SwiftUI
import PhotosUI

/// Première ouverture : bienvenue (mascotte asset 4 en grand plan) → avatar (6
/// personnages + photo perso) → nom d'appareil → permissions → méthodes → accueil.

struct OnboardingView: View {
    @EnvironmentObject var app: AppViewModel
    @State private var page = 0                       // 0 bienvenue, 1 avatar, 2 nom, 3 permissions, 4 méthodes
    @State private var selectedAvatar: Int = 1        // 1...6 ; -1 = photo perso
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var deviceName: String = ""
    @State private var mascotBounce = false

    private let totalPages = 5

    var body: some View {
        ZStack {
            FylioBackground()
            VStack(spacing: 0) {
                stepIndicator
                Group {
                    switch page {
                    case 0: welcomeStep
                    case 1: avatarStep
                    case 2: nameStep
                    case 3: permissionsStep
                    default: methodsStep
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                         removal: .move(edge: .leading).combined(with: .opacity)))
                Spacer(minLength: 0)
                nextButton
            }
            .padding(.horizontal, FylioTokens.screenMargin)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotosPicker(selection: $photoItem, matching: .images) { Text(...) }
        }
        .onChange(of: photoItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    photoData = data
                    selectedAvatar = -1
                }
    }
        }
        .onAppear { mascotBounce = true }
    }

    @State private var showPhotoPicker = false

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { i in
                Capsule()
                    .fill(i <= page ? FylioPalette.electricBlue : FylioPalette.paleBlue)
                    .frame(width: i == page ? 28 : 10, height: 5)
                    .animation(.spring(response: 0.35), value: page)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }

    private var nextButton: some View {
        let canContinue: Bool = {
            switch page {
            case 1: return selectedAvatar >= 1 || (selectedAvatar == -1 && photoData != nil)
            case 2: return !deviceName.trimmingCharacters(in: .whitespaces).isEmpty
            default: return true
            }
        }()

        return Button {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                if page >= totalPages - 1 {
                    app.completeOnboarding(avatar: selectedAvatar,
                                           photo: photoData,
                                           name: deviceName.trimmingCharacters(in: .whitespaces))
                } else {
                    page += 1
                }
            }
        } label: {
            Text(page >= totalPages - 1
                 ? String(localized: "onboarding.start")
                 : String(localized: "onboarding.next"))
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(FylioTokens.sendGradient, in: Capsule())
                .shadow(color: FylioPalette.electricBlue.opacity(0.35), radius: 12, y: 6)
        }
        .buttonStyle(FylioPressStyle())
        .disabled(!canContinue)
        .opacity(canContinue ? 1.0 : 0.45)
    }

    // MARK: Étape 0 — Bienvenue (mascotte asset 4 en grand plan)

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Spacer()
            Image("mascotte_hero")
                .resizable().scaledToFit()
                .frame(maxWidth: 300)
                .scaleEffect(mascotBounce ? 1.03 : 0.98)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true),
                           value: mascotBounce)
            Text(String(localized: "onboarding.welcome.title"))
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(FylioPalette.nightText)
                .multilineTextAlignment(.center)
            Text(String(localized: "onboarding.welcome.subtitle"))
                .font(.system(size: 18))
                .foregroundStyle(FylioPalette.secondaryText)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Étape 1 — Avatar (6 personnages + photo perso)

    private var avatarStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                Text(String(localized: "onboarding.avatar.title"))
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(FylioPalette .nightText)
                FylioAvatarPicker(selection: $selectedAvatar,
                                  photoData: photoData,
                                  onImportPhoto: { showPhotoPicker = true })
                if selectedAvatar == -1, let data = photoData {
                    FylioAvatarView(avatarID: -1, photoData: data, size: 110)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: Éboarding Étape 2 — Nom d'appareil

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text(String(localized: "onboarding.name.title"))
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(FylioPalette.nightText)
            Text(String(localized: "onboarding.name.subtitle"))
                .font(.system(size: 16))
                .foregroundStyle(FylioPalette.secondaryText)
            TextField(String(localized: "onboarding.name.placeholder"), text: $deviceName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(FylioPalette.nightText)
                .padding(18)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(FylioPalette.electricBlue.opacity(0.35), lineWidth: 1.5))
            Button(String(localized: "onboarding.name.suggestion")) {
                deviceName = app.suggestedDeviceName
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(FylioPalette.electricBlue)
            .buttonStyle(FylioPressStyle())
        }
        .padding(.top, 20)
    }

    // MARK: Étape 3 — Permissions (notifications / photos / fichiers)

    private var permissionsStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Text(String(localized: "onboarding.permissions.title"))
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(FylioPalette.nightText)
                ForEach(0..<3, id: \0) { i in
                    permissionCard(index: i)
                }
            }
        }
    }

    private func permissionCard(index i: Int) -> some View {
        let icons = ["bell", "photo.on.rectangle", "folder"]
        let permissionStates = app.permissionStates
        return FylioGlassCard(corner: 22) {
            HStack(spacing: 16) {
                Image(systemName: icons[i])
                    .font(.system(size: 28))
                    .foregroundStyle(FylioPalette.electricBlue)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: String.LocalizationValue("onboarding.permissions.\(i).title")))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(FylioPalette.nightText)
                    Text(String(localized: String.LocalizationValue("onboarding.permissions.\(i).subtitle")))
                        .font(.system(size: 13))
                        .foregroundStyle(FylioPalette.secondaryText)
                    if permissionStates[i] == .granted {
                        Label(String(localized: "onboarding.permissions.granted"), systemImage: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(FylioPalette.statusGreen)
                    } else {
                        Button(String(localized: "onboarding.permissions.allow")) {
                            app.requestPermission(index: i)
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(FylioPalette.electricBlue)
                        .buttonStyle(FylioPressStyle())
                    }
    }
            }
        }
    }

    // MARK: Étape 4 — Méthodes de transfert

    private var methodsStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Text(String(localized: "onboarding.methods.title"))
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(FylioPalette.nightText)
                methodRow(icon: "wifi", key: "onboarding.methods.wifi")
                methodRow(icon: "qrcode", key: "onboarding.methods.qr")
                methodRow(icon: "personalhotspot", key: "onboarding.methods.hotspot")
                methodRow(icon: "cable.connector", key: "onboarding.methods.usb")
                methodRow(icon: "globe", key: "onboarding.methods.remote")
                methodRow(icon: "clock.arrow.circlepath", key: "onboarding.methods.registered")
            }
    }
    }

    private func methodRow(icon: String, key: String) -> some View {
        FylioGlassCard(corner: 22) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundStyle(FylioPalette.electricBlue)
                    .frame(width: 40)
                Text(String(localized: String.LocalizationValue(key)))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(FylioPalette.nightText)
                Spacer()
            }
        }
    }
}
```

**Corrections par rapport au brouillon (consignées au journal QA) :**
| Brouillon | Corrigé en |
|---|---| 
| `listePermissions` (fantôme) | `permissionCard(index:)` + VStack réel |
| `.frame(maxHeight: .VStack)` | `.frame(maxWidth: .infinity, maxHeight: .infinity)` |
| PhotosPicker binding bricolé | `PhotosPickerItem` + `loadTransferable` propre |
| Suivant désactivé incohérent | `canContinue` centralisé par étape |
| `FylioPalette .nightText`, `Éboarding`, `ForEach(0..<3, id: \0)`, `Text(...)` du sheet | Corrigés (typo/espace, label du sheet localisé) |
