import SwiftUI

/// SYSTÈME D'ÉTATS VIDES DYNAMIQUES — registre centralisé.
/// Règle produit : dès qu'il n'y a NI transfert NI appareil, le personnage
/// d'état vide s'affiche (animé). Dès qu'un élément apparaît, le personnage
/// disparaît et laisse place à la vraie liste. Un seul registre pour toute
/// l'application → impossible d'utiliser le même personnage partout.
enum FylioEmptyStateRegistry {
    case recentDevices
    case transferHistory
    case files
    case gallery
    case music

    var character: String {
        switch self {
        case .recentDevices:   return "empty_recent_devices"   // asset 2
        case .transferHistory: return "empty_history_home"     // asset 3
        case .files:           return "files_character"        // asset Fichiers (BUG #13 : empty_files n'existe pas)
        case .gallery:         return "empty_gallery"          // asset Galerie 4
        case .music:           return "empty_music"            // asset Musique 5
        }
    }

    var titleKey: String {
        switch self {
        case .recentDevices:   return "devices.noDevices"
        case .transferHistory: return "history.empty.title"
        case .files:           return "files.empty"
        case .gallery:         return "gallery.empty"
        case .music:           return "music.empty"
        }
    }

    var subtitleKey: String {
        switch self {
        case .recentDevices:   return "devices.connectFirst"
        case .transferHistory: return "history.empty.subtitle"
        case .files:           return "files.character"
        case .gallery:         return "gallery.selectToShare"
        case .music:           return "music.empty"
        }
    }
}

/// Wrapper SwiftUI : affiche l'état vide SI la collection est vide, sinon rien.
struct FylioEmptyStateSlot: View {
    let registry: FylioEmptyStateRegistry
    let isEmpty: Bool

    var body: some View {
        if isEmpty {
            FylioEmptyState(character: registry.character,
                            titleKey: registry.titleKey,
                            subtitleKey: registry.subtitleKey)
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
        }
    }
}