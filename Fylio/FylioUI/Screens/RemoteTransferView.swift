import SwiftUI

// MARK: - Palier 4C : Transfert à distance (clé 8 alphanum)
// Envoyer → génère clé + affiche + copie/WhatsApp + TTL 10:00
// Recevoir → saisie clé + recherche 2s + widget Accepter/Refuser

struct RemoteSendView: View {
    @EnvironmentObject var app: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var generatedKey: String = ""
    @State private var expiresIn: Int = 600
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            FylioBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    FylioGlassCard {
                        VStack(spacing: 16) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 36)).foregroundStyle(FylioPalette.electricBlue)
                            Text(String(localized: "remote.send.title"))
                                .font(.system(size: 22, weight: .heavy)).foregroundStyle(FylioPalette.nightText)
                            Text(String(localized: "remote.send.hint"))
                                .font(.system(size: 14)).foregroundStyle(FylioPalette.secondaryText)
                                .multilineTextAlignment(.center)
                            if !generatedKey.isEmpty {
                                Text(FylioRemoteKey.display(generatedKey))
                                    .font(.system(size: 28, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(FylioPalette.nightText)
                                    .padding(.horizontal, 20).padding(.vertical, 14)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.6), lineWidth: 1))
                                Text(String(format: String(localized: "remote.send.expires"), expiresIn / 60, expiresIn % 60))
                                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(FylioPalette.secondaryText)
                                HStack(spacing: 12) {
                                    Button {
                                        UIPasteboard.general.string = generatedKey
                                        FylioHaptics.tap()
                                    } label: {
                                        Label(String(localized: "common.copy"), systemImage: "doc.on.doc")
                                            .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                                            .padding(.horizontal, 18).padding(.vertical, 12)
                                            .background(FylioTokens.sendGradient, in: Capsule())
                                    }.buttonStyle(FylioPressStyle())
                                    ShareLink(item: generatedKey) {
                                        Label("WhatsApp", systemImage: "square.and.arrow.up")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(FylioPalette.electricBlue)
                                            .padding(.horizontal, 18).padding(.vertical, 12)
                                            .background(.ultraThinMaterial, in: Capsule())
                                    }
                                }
                            } else {
                                Button {
                                    let k = FylioRemoteKey.generate()
                                    generatedKey = k
                                    app.remoteKey = k
                                    Task { try? await app.remoteService.createSession(key: k, publicKey: app.identity.publicKeyFingerprint) }
                                    startTimer()
                                } label: {
                                    Text(String(localized: "remote.send.generate"))
                                        .font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                                        .background(FylioTokens.sendGradient, in: Capsule())
                                }.buttonStyle(FylioPressStyle())
                            }
                        }
                    }
                }
                .padding(.horizontal, FylioTokens.screenMargin).padding(.vertical, 24)
            }
        }
        .navigationTitle(String(localized: "remote.send.navTitle"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button(String(localized: "common.close")) { dismiss() } } }
        .onDisappear { timer?.invalidate() }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if expiresIn > 0 { expiresIn -= 1 } else { timer?.invalidate() }
        }
    }
}

struct RemoteReceiveView: View {
    @EnvironmentObject var app: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var inputKey = ""
    @State private var isSearching = false
    @State private var foundSession: FylioRemoteSession?
    @State private var errorKey: String?

    var body: some View {
        ZStack {
            FylioBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    FylioGlassCard {
                        VStack(spacing: 16) {
                            Image(systemName: "key.viewfinder")
                                .font(.system(size: 36)).foregroundStyle(FylioPalette.electricBlue)
                            Text(String(localized: "remote.receive.title"))
                                .font(.system(size: 22, weight: .heavy)).foregroundStyle(FylioPalette.nightText)
                            Text(String(localized: "remote.receive.hint"))
                                .font(.system(size: 14)).foregroundStyle(FylioPalette.secondaryText)
                                .multilineTextAlignment(.center)
                            TextField("A3K9-X7P2", text: $inputKey)
                                .font(.system(size: 22, weight: .heavy, design: .monospaced))
                                .multilineTextAlignment(.center)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .padding(.horizontal, 20).padding(.vertical, 14)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.6), lineWidth: 1))
                            Button {
                                Task { await search() }
                            } label: {
                                if isSearching {
                                    ProgressView().tint(.white).frame(maxWidth: .infinity).frame(height: 52)
                                        .background(FylioTokens.sendGradient, in: Capsule())
                                } else {
                                    Text(String(localized: "remote.receive.search"))
                                        .font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                                        .background(FylioTokens.sendGradient, in: Capsule())
                                }
                            }.buttonStyle(FylioPressStyle())
                            .disabled(!FylioRemoteKey.isValid(inputKey) || isSearching)
                            .opacity(FylioRemoteKey.isValid(inputKey) ? 1 : 0.45)
                            if let err = errorKey {
                                Text(err).font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(FylioPalette.alertRed).multilineTextAlignment(.center)
                            }
                            if let sess = foundSession {
                                FylioGlassCard(corner: 18) {
                                    VStack(spacing: 12) {
                                        Text(String(localized: "remote.receive.found"))
                                            .font(.system(size: 15, weight: .bold)).foregroundStyle(FylioPalette.statusGreen)
                                        Text(sess.displayKey)
                                            .font(.system(size: 16, design: .monospaced)).foregroundStyle(FylioPalette.nightText)
                                        HStack(spacing: 16) {
                                            Button(String(localized: "common.cancel")) {
                                                foundSession = nil
                                            }.font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(FylioPalette.secondaryText)
                                                .padding(.horizontal, 20).padding(.vertical, 10)
                                                .background(.ultraThinMaterial, in: Capsule())
                                            Button(String(localized: "receive.confirm")) {
                                                app.acceptRemoteSession(sess)
                                                dismiss()
                                            }.font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                                                .padding(.horizontal, 20).padding(.vertical, 10)
                                                .background(FylioTokens.sendGradient, in: Capsule())
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, FylioTokens.screenMargin).padding(.vertical, 24)
            }
        }
        .navigationTitle(String(localized: "remote.receive.navTitle"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button(String(localized: "common.close")) { dismiss() } } }
    }

    private func search() async {
        isSearching = true; errorKey = nil; foundSession = nil
        do {
            if let sess = try await app.remoteService.lookup(key: inputKey) {
                if sess.isExpired {
                    errorKey = String(localized: "remote.receive.expired")
                } else {
                    foundSession = sess
                }
            } else {
                errorKey = String(localized: "remote.receive.notFound")
            }
        } catch {
            errorKey = String(localized: "remote.receive.error")
        }
        isSearching = false
    }
}
