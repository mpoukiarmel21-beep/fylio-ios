# FYLIO — `FylioUI/AppViewModel.swift` (bloc 1/3 : navigation + modèles UI)

```swift
import SwiftUI
import Network
import UserNotifications
import Photos

enum FylioRoute: Hashable {
    case home, send, receive, devices, files, gallery, music, history
    case settings, notifications, qrScanner, progress(UUID)
}

enum PermissionState { case unknown, granted, denied }

struct IncomingTransferRequest: Identifiable, Equatable {
    let id = UUID()
    let senderName: String
    let avatarID: Int
    let fileCount: Int
    let totalBytes: Int64
}

struct ActiveTransfer: Identifiable, Equatable {
    let id = UUID()
    let peerName: String
    let platform: FylioPlatform
    var currentFileName: String
    var currentFileContentType: String
    var fraction: Double
    var totalBytes: Int64
    var speed: Int64
    var etaSeconds: Int?
    var paused: Bool
    let progressMascot: String
    var stateDescription: String

    var percent: Int { Int((fraction * 100).rounded()) }
    var formattedBytes: String {
        ByteCountFormatter.string(fromByteCount: Int64(fraction * Double(totalBytes)),
                                  countStyle: .file)
    }
    var formattedTotal: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }

    static func == (lhs: ActiveTransfer, rhs: ActiveTransfer) -> Bool { lhs.id == rhs.id }
}

struct HistoryEntry: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let count: Int
    let sizeBytes: Int64
    let platform: FylioPlatform
    let direction: Direction
    let date: Date

    enum Direction { case sent, received }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
    var relativeDate: String {
        RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
    }
}

enum FileSortOrder: String, CaseIterable, Identifiable {
    case recent, name, size
    var id: String { rawValue }
    var label: String {
        switch self {
        case .recent: return String(localized: "sort.recent")
        case .name: return String(localized: "sort.name")
        case .size: return String(localized: "sort.size")
        }
    }
}
```
