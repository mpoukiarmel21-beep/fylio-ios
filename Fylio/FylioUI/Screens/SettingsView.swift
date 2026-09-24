import SwiftUI

/// Paramètres — Profil, Apparence, Langue (7 langues + drapeaux + auto), Transferts,
/// Appareils, Stockage, Notifications, Confidentialité & sécurité, À propos.
struct SettingsView: View {
    @EnvironmentObject var app: AppViewModel
    @AppStorage("fylio.languageOverride") private var languageOverride: String = "auto"
    @AppStorage("fylio.colorScheme") private var colorScheme: String = "auto"
    @AppStorage("fylio.autoAcceptTrusted") private var autoAcceptTrusted = false
    @AppStorage("fylio.wifiOnly") private var wifiOnly = true
    @AppStorage("fylio.notifyOnComplete") private var notifyOnComplete = true
    @AppStorage("fylio.notifyOnIncoming") private var notifyOnIncoming = true

    var body: some View {
        ZStack {
            FylioBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    profileSection
                    appearanceSection
                    languageSection
                    transferSection
                    devicesSection
                    notificationsSection
                    storageSection
                    privacySection
                    aboutSection
                }
                .padding(.horizontal, FylioTokens.screenMargin)
                .padding(.vertical, 20)
            }
        }
        .navigationTitle(String(localized: "settings.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section<Content: View>(_ titleKey: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: String.LocalizationValue(titleKey)))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(FylioPalette.secondaryText)
                .padding(.leading, 6)
            FylioGlassCard(corner: 22) {
                VStack(spacing: 0) { content() }
            }
        }
    }

    private func row<Label: View>(_ label: Label, value: String? = nil) -> some View {
        HStack {
            label
            Spacer()
            if let value { Text(value).foregroundStyle(FylioPalette.secondaryText) }
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FylioPalette.secondaryText.opacity(0.6))
        }
        .padding(.vertical, 10)
    }

    // MARK: Profil

    private var profileSection: some View {
        section("settings.profile") {
            Button { app.renameDevice(appPeer) } label: {
                row(HStack(spacing: 12) {
                    FylioAvatarView(avatarID: app.identity.avatarID,
                                    photoData: app.avatarPhotoData,
                                    size: 44, showsOnlineDot: false)
                    VStack(alignment: .leading) {
                        Text(app.identity.displayName)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(FylioPalette.nightText)
                        Text(app.identity.fylioNumber)
                            .font(.system(size: 13))
                            .foregroundStyle(FylioPalette.secondaryText)
                    }
                })
            }
        }
    }

    private var appPeer: FylioPeer {
        FylioPeer(id: app.identity.deviceID,
                  displayName: app.identity.displayName,
                  fylioNumber: app.identity.fylioNumber,
                  avatarID: app.identity.avatarID,
                  platform: .ios,
                  host: "", port: 0,
                  fingerprint: app.identity.publicKeyFingerprint)
    }

    // MARK: Apparence

    private var appearanceSection: some View {
        section("settings.appearance") {
            Picker(selection: $colorScheme) {
                Text(String(localized: "settings.appearance.auto")).tag("auto")
                Text(String(localized: "settings.appearance.light")).tag("light")
                Text(String(localized: "settings.appearance.dark")).tag("dark")
            } label: {
                row(Text(String(localized: "settings.appearance.theme")))
            }
            .pickerStyle(.navigationLink)
        }
    }

    // MARK: Langue (7 langues + auto selon la langue du téléphone)

    private var languageSection: some View {
        section("settings.language") {
            Picker(selection: $languageOverride) {
                Text(String(localized: "settings.language.auto")).tag("auto")
                Text("🇬🇧 English").tag("en")
                Text("🇨🇳 中文").tag("zh-Hans")
                Text("🇮🇳 हिन्दी").tag("hi")
                Text("🇪🇸 Español").tag("es")
                Text("🇫🇷 Français").tag("fr")
                Text("🇸🇦 العربية").tag("ar")
                Text("🇵🇹 Português").tag("pt")
            } label: {
                row(Text(String(localized: "settings.language")))
            }
            .pickerStyle(.navigationLink)
        }
    }

    // MARK: Transferts

    private var transferSection: some View {
        section("settings.transfers") {
            Toggle(isOn: $wifiOnly) {
                Text(String(localized: "settings.transfers.wifiOnly"))
            }
            .padding(.vertical, 6)
            Toggle(isOn: $autoAcceptTrusted) {
                Text(String(localized: "settings.transfers.autoAccept"))
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: Appareils

    private var devicesSection: some View {
        section("settings.devices") {
            NavigationLink(value: FylioRoute.devices) {
                row(Text(String(localized: "settings.devices.list")))
            }
        }
    }

    // MARK: Notifications

    private var notificationsSection: some View {
        section("settings.notifications") {
            Toggle(isOn: $notifyOnComplete) {
                Text(String(localized: "settings.notifications.complete"))
            }
            .padding(.vertical, 6)
            Toggle(isOn: $notifyOnIncoming) {
                Text(String(localized: "settings.notifications.incoming"))
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: Stockage

    private var storageSection: some View {
        section("settings.storage") {
            Button { app.clearCache() } label: {
                row(Text(String(localized: "settings.storage.clearCache")))
            }
        }
    }

    // MARK: Confidentialité & sécurité

    private var privacySection: some View {
        section("settings.privacy") {
            row(Text(String(localized: "settings.privacy.encryption")),
                 value: "TLS 1.3 · AES-GCM")
            Button { app.eraseAllData() } label: {
                row(Text(String(localized: "settings.privacy.erase")))
                    .foregroundStyle(FylioPalette.alertRed)
            }
        }
    }

    // MARK: À propos

    private var aboutSection: some View {
        section("settings.about") {
            HStack {
                Text("Fylio").font(.system(size: 16, weight: .bold)).foregroundStyle(FylioPalette.nightText)
                Spacer()
                if let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                   let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                    Text("\(v) (\(b))").font(.system(size: 13)).foregroundStyle(FylioPalette.secondaryText)
                } else {
                    Text("1.0 (6)").font(.system(size: 13)).foregroundStyle(FylioPalette.secondaryText)
                }
            }
            .padding(.vertical, 10)
            Image("logo_fylio")
                .resizable().scaledToFit().frame(height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            Text("Transfert local chiffré (TLS 1.3 · AES-GCM) — aucune donnée sur serveur.")
                .font(.system(size: 12)).foregroundStyle(FylioPalette.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 6)
        }
    }
}