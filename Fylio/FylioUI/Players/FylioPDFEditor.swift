import SwiftUI
import PDFKit
import UniformTypeIdentifiers

// MARK: - PDF Fylio — éditeur intégré (annotation + sauvegarde)
// Simple, DA bleu vitrée : viewer PDFKit + barre d'outils vitrée + sauvegarde dans Fylio/Recu.

struct FylioPDFEditorView: View {
    let file: FylioFileItem
    @EnvironmentObject var app: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var pdfDocument: PDFDocument?
    @State private var saveMessage: String?
    @State private var isSaving = false

    var body: some View {
        ZStack {
            FylioBackground()
            VStack(spacing: 0) {
                toolbar
                if let doc = pdfDocument {
                    PDFKitView(document: doc)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 12).padding(.vertical, 10)
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .navigationTitle(file.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "common.close")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    save()
                } label: {
                    if isSaving { ProgressView() } else {
                        Text(String(localized: "pdf.saved")).font(.system(size: 15, weight: .bold))
                            .foregroundStyle(FylioPalette.electricBlue)
                    }
                }.disabled(isSaving)
            }
        }
        .fylioToast($saveMessage)
        .task { load() }
    }

    private var toolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                pill("pdf.tool.highlight", icon: "highlighter") { annotate(.highlight) }
                pill("pdf.tool.pen", icon: "pencil.tip") { annotate(.ink) }
                pill("pdf.tool.text", icon: "textformat") { annotate(.text) }
                pill("pdf.tool.signature", icon: "signature") { annotate(.signature) }
                pill("pdf.rotatePage", icon: "rotate.right") { rotatePage() }
                pill("pdf.deletePage", icon: "trash", color: FylioPalette.alertRed) { deletePage() }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .background(.ultraThinMaterial)
    }

    private func pill(_ key: String, icon: String, color: Color = FylioPalette.electricBlue, action: @escaping () -> Void) -> some View {
        Button(action: { FylioHaptics.tap(); action() }) {
            Label(String(localized: String.LocalizationValue(key)), systemImage: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.55), lineWidth: 1))
        }.buttonStyle(FylioPressStyle(haptic: false))
    }

    private func load() {
        guard let url = file.fileURL else { return }
        pdfDocument = PDFDocument(url: url)
    }

    private func annotate(_ type: PDFAnnotationSubtype) {
        guard let doc = pdfDocument, let page = doc.page(at: 0) else { return }
        let bounds = CGRect(x: 40, y: 40, width: 200, height: 24)
        let ann = PDFAnnotation(bounds: bounds, forType: type, withProperties: nil)
        ann.color = type == .highlight ? UIColor.systemYellow.withAlphaComponent(0.35) : UIColor.systemBlue
        ann.contents = type == .text ? "Texte" : nil
        page.addAnnotation(ann)
        pdfDocument = doc
        FylioHaptics.tap()
    }

    private func rotatePage() {
        guard let doc = pdfDocument, let page = doc.page(at: 0) else { return }
        page.rotation = (page.rotation + 90) % 360
        pdfDocument = doc
    }

    private func deletePage() {
        guard let doc = pdfDocument, doc.pageCount > 1, let page = doc.page(at: 0) else { return }
        doc.removePage(at: 0)
        pdfDocument = doc
    }

    private func save() {
        guard let doc = pdfDocument else { return }
        isSaving = true
        Task {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let dest = docs.appendingPathComponent("Fylio/Recu").appendingPathComponent(file.name)
            try? FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            if let data = doc.dataRepresentation() {
                try? data.write(to: dest)
                await MainActor.run {
                    app.reloadFiles()
                    saveMessage = String(localized: "pdf.saved")
                    isSaving = false
                    dismiss()
                }
            } else {
                await MainActor.run { isSaving = false; saveMessage = String(localized: "pdf.saveFailed") }
            }
        }
    }
}

private struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    func makeUIView(context: Context) -> PDFView {
        let v = PDFView()
        v.document = document
        v.autoScales = true
        v.displayMode = .singlePageContinuous
        v.backgroundColor = .clear
        return v
    }
    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
    }
}
