import SwiftUI

/// ENVOYER — sélection de fichiers, recherche, tri, sélection multiple, aperçu,
/// bouton Envoyer visible après sélection (doc 14).
struct SendView: View {
    @EnvironmentObject var app: AppViewModel
    @State private var searchText = ""
    @State private var selectedFiles: Set<UUID> = []
    @State private var sortOrder: FileSortOrder = .recent
    @State private var previewItem: FylioFileItem?
    @State private var showImporter = false

    private var filteredFiles: [FylioFileItem] {
        let files = app.allFiles(sortedBy: sortOrder)
        guard !searchText.isEmpty else { return files }
        return files.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ZStack {
            FylioBackground()
            VStack(spacing: 0) {
                searchAndSortBar
                fileList
                sendBar
            }
        }
        .navigationTitle(String(localized: "send.title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $previewItem) { file in
            FylioFilePreviewSheet(file: file)
        }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.image, .movie, .audio, .pdf, .data],
                      allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                app.registerImportedFiles(urls: urls)
            }
        }
    }

    private var fileList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                if filteredFiles.isEmpty {
                    FylioEmptyState(character: "files_character",
                                    titleKey: "files.empty.title",
                                    subtitleKey: "files.empty.subtitle")
                } else {
                    ForEach(filteredFiles) { file in
                        fileRow(file)
                    }
                }
            }
            .padding(.horizontal, FylioTokens.screenMargin)
            .padding(.vertical, 16)
        }
    }

    private var searchAndSortBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(FylioPalette.secondaryText)
                TextField(String(localized: "common.search"), text: $searchText)
                    .autocorrectionDisabled()
            }
            .padding(12)
            .background(.ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.6), lineWidth: 1))

            Menu {
                ForEach(FileSortOrder.allCases) { order in
                    Button {
                        sortOrder = order
                    } label: {
                        if sortOrder == order {
                            Label(order.label, systemImage: "checkmark")
                        } else {
                            Text(order.label)
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(FylioPalette.electricBlue)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }

            Button {
                showImporter = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(FylioPalette.electricBlue)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(FylioPressStyle())
        }
        .padding(.horizontal, FylioTokens.screenMargin)
        .padding(.top, 12)
    }

    private func fileRow(_ file: FylioFileItem) -> some View {
        Button {
            if selectedFiles.contains(file.id) {
                selectedFiles.remove(file.id)
            } else {
                selectedFiles.insert(file.id)
            }
        } label: {
            HStack(spacing: 14) {
                FileIcon(contentType: file.contentType, size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(file.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(FylioPalette.nightText)
                        .lineLimit(1)
                    Text(ByteCountFormatter.string(fromByteCount: file.sizeBytes,
                                                    countStyle: .file))
                        .font(.system(size: 12))
                        .foregroundStyle(FylioPalette.secondaryText)
                }
                Spacer()
                selectionCircle(isSelected: selectedFiles.contains(file.id))
            }
            .padding(14)
            .background(selectedFiles.contains(file.id)
                        ? FylioPalette.paleBlue.opacity(0.35)
                        : Color.clear,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(selectedFiles.contains(file.id)
                                ? FylioPalette.electricBlue.opacity(0.5)
                                : Color.white.opacity(0.5),
                                lineWidth: 1))
        }
        .buttonStyle(FylioPressStyle())
        .contextMenu {
            Button {
                previewItem = file
            } label: {
                Label(String(localized: "common.preview"), systemImage: "eye")
            }
        }
    }

    private func selectionCircle(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isSelected ? FylioPalette.electricBlue : Color.white.opacity(0.4))
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .opacity(isSelected ? 1 : 0)
        }
        .frame(width: 26, height: 26)
        .animation(.spring(response: 0.25), value: isSelected)
    }

    private var sendBar: some View {
        VStack(spacing: 10) {
            // Palier 4 : Envoyer à distance (clé 8) — à côté du pick device
            if !selectedFiles.isEmpty {
                NavigationLink(value: FylioRoute.remoteSend) {
                    Label(String(localized: "remote.send.action"), systemImage: "key.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FylioPalette.electricBlue)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.55), lineWidth: 1))
                }
            }
            if !selectedFiles.isEmpty {
                Text(String(format: String(localized: "send.selectedCount"),
                            selectedFiles.count))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FylioPalette.secondaryText)
            }
            Button {
                app.startSendFlow(selected: selectedFiles)
            } label: {
                HStack {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                    Text(String(localized: "send.pickDevice"))
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(FylioTokens.sendGradient, in: Capsule())
                .shadow(color: FylioPalette.electricBlue.opacity(0.25), radius: 10, y: 6)
            }
            .buttonStyle(FylioPressStyle())
            .disabled(selectedFiles.isEmpty)
            .opacity(selectedFiles.isEmpty ? 0.45 : 1)
        }
        .padding(.horizontal, FylioTokens.screenMargin)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }
}