import SwiftUI
import WebKit

// MARK: - Navigateur interne Fylio — ouvert par la loupe 🔎
// Simple, épuré, DA bleu vitrée : barre URL vitrée + WebView + barre nav en bas.

struct BrowserView: View {
    @State private var urlString: String = "https://www.google.com"
    @State private var inputText: String = "https://www.google.com"
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var isLoading = false

    var body: some View {
        ZStack {
            FylioBackground()
            VStack(spacing: 0) {
                addressBar
                webContent
                bottomBar
            }
        }
        .navigationTitle("Navigateur")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var addressBar: some View {
        HStack(spacing: 10) {
            FylioSearchBar(text: $inputText, placeholder: "Rechercher ou saisir une adresse")
                .onSubmit { navigate() }
            Button {
                navigate()
            } label: {
                Image(systemName: isLoading ? "xmark.circle.fill" : "arrow.right.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(FylioPalette.electricBlue)
            }
            .buttonStyle(FylioPressStyle())
        }
        .padding(.horizontal, FylioTokens.screenMargin)
        .padding(.vertical, 10)
    }

    private var webContent: some View {
        FylioWebView(urlString: $urlString,
                     canGoBack: $canGoBack,
                     canGoForward: $canGoForward,
                     isLoading: $isLoading,
                     onURLChange: { newURL in
                        inputText = newURL
                     })
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 8)
        .shadow(color: FylioTokens.shadowGlass, radius: 12, y: 4)
    }

    private var bottomBar: some View {
        HStack(spacing: 24) {
            Button { NotificationCenter.default.post(name: .fylioBrowserGoBack, object: nil) } label: {
                Image(systemName: "chevron.left").font(.system(size: 18, weight: .bold))
                    .foregroundStyle(canGoBack ? FylioPalette.electricBlue : FylioPalette.secondaryText.opacity(0.35))
            }.disabled(!canGoBack)
            Button { NotificationCenter.default.post(name: .fylioBrowserGoForward, object: nil) } label: {
                Image(systemName: "chevron.right").font(.system(size: 18, weight: .bold))
                    .foregroundStyle(canGoForward ? FylioPalette.electricBlue : FylioPalette.secondaryText.opacity(0.35))
            }.disabled(!canGoForward)
            Spacer()
            Button { urlString = "https://www.google.com"; inputText = urlString } label: {
                Image(systemName: "house").font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(FylioPalette.secondaryBlue)
            }
            Button {
                if let url = URL(string: urlString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Image(systemName: "safari").font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(FylioPalette.secondaryBlue)
            }
            Button {
                if let url = URL(string: urlString) {
                    let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let win = scene.windows.first, let root = win.rootViewController {
                        root.present(av, animated: true)
                    }
                }
            } label: {
                Image(systemName: "square.and.arrow.up").font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(FylioPalette.secondaryBlue)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.55), lineWidth: 1))
        .padding(.horizontal, 12).padding(.vertical, 10)
    }

    private func navigate() {
        var s = inputText.trimmingCharacters(in: .whitespaces)
        if !s.contains("://") {
            if s.contains(".") {
                s = "https://" + s
            } else {
                s = "https://www.google.com/search?q=" + (s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s)
            }
        }
        urlString = s
        inputText = s
    }
}

private extension Notification.Name {
    static let fylioBrowserGoBack = Notification.Name("fylio.browser.back")
    static let fylioBrowserGoForward = Notification.Name("fylio.browser.forward")
}

private struct FylioWebView: UIViewRepresentable {
    @Binding var urlString: String
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var isLoading: Bool
    var onURLChange: (String) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let v = WKWebView()
        v.navigationDelegate = context.coordinator
        v.allowsBackForwardNavigationGestures = true
        v.allowsLinkPreview = true
        if let url = URL(string: urlString) { v.load(URLRequest(url: url)) }
        context.coordinator.webView = v
        // Écoute nav externe (boutons bas)
        NotificationCenter.default.addObserver(context.coordinator,
            selector: #selector(Coord.goBack), name: .fylioBrowserGoBack, object: nil)
        NotificationCenter.default.addObserver(context.coordinator,
            selector: #selector(Coord.goForward), name: .fylioBrowserGoForward, object: nil)
        return v
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard let url = URL(string: urlString), uiView.url?.absoluteString != urlString else { return }
        uiView.load(URLRequest(url: url))
    }
    func makeCoordinator() -> Coord { Coord(parent: self) }

    final class Coord: NSObject, WKNavigationDelegate {
        var parent: FylioWebView
        weak var webView: WKWebView?
        init(parent: FylioWebView) { self.parent = parent }
        @objc func goBack() { webView?.goBack() }
        @objc func goForward() { webView?.goForward() }
        func webView(_ w: WKWebView, didStartProvisionalNavigation n: WKNavigation!) {
            parent.isLoading = true
        }
        func webView(_ w: WKWebView, didFinish n: WKNavigation!) {
            parent.isLoading = false
            parent.canGoBack = w.canGoBack; parent.canGoForward = w.canGoForward
            if let s = w.url?.absoluteString { parent.onURLChange(s) }
        }
        func webView(_ w: WKWebView, didFail n: WKNavigation!, withError e: Error) {
            parent.isLoading = false
        }
    }
}
