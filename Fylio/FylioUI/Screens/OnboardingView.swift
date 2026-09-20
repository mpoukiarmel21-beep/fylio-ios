import SwiftUI
import PhotosUI

/// Première ouverture : bienvenue → avatar (6 personnages + photo) → nom →
/// permissions → méthodes → accueil.
struct OnboardingView: View {
    @EnvironmentObject var app: AppViewModel
    @State private var page = 0
    @State private var selectedAvatar = 1
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var showPhotoPicker = false
    @State private var name = ""

    private let totalPages = 5

    var body: some View {
        ZStack {
            FylioBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    content
                    controls
                }
                .padding(.horizontal, FylioTokens.screenMargin)
                .padding(.top, 40)
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
                .frame(width: 300, height: 300)
            Text(String(localized: "onboarding.welcome.title"))
                .font(.system(size: 40, weight: .heavy))
                .foregroundStyle(FylioPalette.nightText)
            Text(String(localized: "onboarding.welcome.subtitle"))
                .font(.system(size: 16))
                .foregroundStyle(FylioPalette.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    private var avatarPage: some View {
        VStack(spacing: 18) {
            Text(String(localized: "onboarding.avatar.title"))
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(FylioPalette.nightText)
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
        VStack(spacing: 18) {
            Text(String(localized: "onboarding.name.title"))
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(FylioPalette.nightText)
            Text(String(localized: "onboarding.name.subtitle"))
                .font(.system(size: 15))
                .foregroundStyle(FylioPalette.secondaryText)
            TextField(app.suggestedDeviceName, text: $name)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(FylioPalette.nightText)
                .padding(16)
                .background(Color.white.opacity(0.9),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .textInputAutocapitalization(.words)
        }
    }

    private var permissionsPage: some View {
        VStack(spacing: 18) {
            Text(String(localized: "onboarding.permissions.title"))
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(FylioPalette.nightText)
            ForEach(0..<3, id: \.self) { index in
                permissionRow(index)
            }
        }
    }

    private func permissionRow(_ index: Int) -> some View {
        let granted = index < app.permissionStates.count && app.permissionStates[index] == .granted
        let denied = index < app.permissionStates.count && app.permissionStates[index] == .denied
        return Button { app.requestPermission(index) } label: {
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
        case 0: return "dot.radiowaves.left.and.right"
        case 1: return "camera.on.rectangle"
        default: return "photo.on.rectangle.angled"
        }
    }

    private var methodsPage: some View {
        VStack(spacing: 18) {
            Image("mascotte_fylio")
                .resizable().scaledToFit()
                .frame(width: 130, height: 130)
            Text(String(localized: "onboarding.methods.title"))
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(FylioPalette.nightText)
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
                     : String(localized: "onboarding.next"))
                    .font(.system(size: 17, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(FylioTokens.sendGradient, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(FylioPressStyle())
        }
    }

    private func advance() {
        guard page < totalPages - 1 else {
            app.completeOnboarding(avatar: selectedAvatar,
                                   photo: photoData,
                                   name: name)
            return
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            page += 1
        }
    }
}