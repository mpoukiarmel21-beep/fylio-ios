# FYLIO V2 — SCRIPTS D'ASSEMBLAGE (projet Xcode généré automatiquement) + INDEX DU PROJET

## `scripts/make_project.py` — génère le projet Xcode complet (zéro manipulation)

```python
#!/usr/bin/env python3
"""Fylio — Génère Fylio.xcodeproj automatiquement avec XcodeGen.
Prérequis : brew install xcodegen (une seule fois). Ensuite : python3 scripts/make_project.py"""
import subprocess, sys
from pathlib import Path

PROJECT_YML = """
name: Fylio
options:
  bundleIdPrefix: ai.fylio
  deploymentTarget:
    iOS: "17.0"
targets:
  Fylio:
    type: application
    platform: iOS
    sources:
      - path: Fylio
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: ai.fylio.app
        MARKETING_VERSION: "1.0"
        CURRENT_PROJECT_VERSION: "1"
        INFOPLIST_FILE: Fylio/Info.plist
        SWIFT_VERSION: "5.9"
        TARGETED_DEVICE_FAMILY: "1,2"
        CODE_SIGNING_ALLOWED: "NO"
    info:
      path: Fylio/Info.plist
      properties:
        CFBundleDisplayName: Fylio
        UILaunchScreen: {}
        NSLocalNetworkUsageDescription: "Fylio discovers nearby devices to transfer files directly over your local network."
        NSBonjourServices: ["_fylio._tcp"]
        NSCameraUsageDescription: "Fylio uses the camera to scan QR codes for pairing."
        NSPhotoLibraryUsageDescription: "Fylio shows and sends your photos and videos."
        NSPhotoLibraryAddUsageDescription: "Fylio saves received photos to your library."
        UIBackgroundModes: ["audio"]
        UIFileSharingEnabled: true
        LSSupportsOpeningDocumentsInPlace: true
        ITSAppUsesNonExemptEncryption: false
"""

def main():
    root = Path(__file__).resolve().parents[1]
    (root / "project.yml").write_text(PROJECT_YML, encoding="utf-8")
    subprocess.run(["xcodegen", "generate"], cwd=root, check=True)
    print("OK — Fylio.xcodeproj généré. Ouvre-le dans Xcode → Build (iOS device) → IPA.")

if __name__ == "__main__":
    sys.exit(main())
```

## `.github/workflows/build-ipa.yml` (compilation GitHub Actions → IPA)

```yaml
name: Build Fylio IPA
on:
  push: { branches: [main] }
  workflow_dispatch:

jobs:
  build:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - uses: maxim-lobanov/setup-xcode@v1
        with: { xcode-version: "16.1" }
      - name: Install xcodegen
        run: brew install xcodegen
      - name: Fetch design assets (personnages, logos, objets animés)
        run: python3 scripts/fetch_assets.py
      - name: Build localizations (7 langues)
        run: python3 scripts/build_localizable.py
      - name: Generate Xcode project
        run: python3 scripts/make_project.py
      - name: Build archive (unsigned)
        run: |
          mkdir -p build
          xcodebuild archive \
            -project Fylio.xcodeproj -scheme Fylio \
            -configuration Release \
            -destination 'generic/platform=iOS' \
            -archivePath build/Fylio.xcarchive \
            CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
            CODE_SIGN_IDENTITY="" CODE_SIGN_ENTITLEMENTS=""
      - name: Package IPA
        run: |
          mkdir -p build/Payload
          cp -r build/Fylio.xcarchive/Products/Applications/Fylio.app build/Payload/
          cd build && zip -r Fylio-unsigned.ipa Payload
      - name: Upload IPA artifact
        uses: actions/upload-artifact@v4
        with:
          name: Fylio-unsigned-IPA
          path: build/Fylio-unsigned.ipa
          retention-days: 90
```

## `docs/AGENT-INSTRUCTIONS.md` — à donner à l'agent de compilation

```markdown
# FYLIO — Instructions pour l'agent de compilation

## Contenu de ce projet (tout est inclus, rien à ajouter)
Le dossier contient l'application iOS complète : moteur de transfert chiffré,
écrans fidèles aux maquettes, lecteurs vidéo/audio/PDF (éditeur avec sauvegarde),
galerie native, 7 langues, CI GitHub Actions.

Les personnages/illustrations NE SONT PAS à ajouter manuellement :
`python3 scripts/fetch_assets.py` les télécharge et les installe dans
Assets.xcassets automatiquement (mascotte, 6 avatars, états vides, objets
animés, icônes appareils, widgets musique, logo).

## Étapes (machine avec Xcode 16 + macOS 15)
1. `python3 scripts/fetch_assets.py`     → assets design installés
2. `python3 scripts/build_localizable.py` → Localizable.xcstrings (7 langues)
3. `brew install xcodegen` (si absent)
4. `python3 scripts/make_project.py`     → Fylio.xcodeproj généré
5. Xcode → Open Fylio.xcodeproj → sélectionner un iPhone → **Build & Run**
   (ou ligne 6 pour l'IPA)
6. `xcodebuild archive -project Fylio.xcodeproj -scheme Fylio
   -configuration Release -destination 'generic/platform=iOS'
   -archivePath build/Fylio.xcarchive CODE_SIGNING_ALLOWED=NO` puis zipper
   le .app en Payload → Fylio-unsigned.ipa
7. Signer l'IPA avec Sideloadly (Apple ID gratuit) → installer sur l'iPhone.

## Sur GitHub (sans Mac)
Pousser ce dossier tel quel → GitHub Actions (workflow inclus) fait les étapes
1-6 automatiquement → IPA téléchargeable dans l'onglet **Actions** → artefact
`Fylio-unsigned-IPA`.

## Aucun secret dans le dépôt
Pas de certificat, clé, provisioning ou identifiant Apple — par conception.
```

---

## INDEX DU PROJET FYLIO V2 (où va chaque fichier)

```
Fylio/  (racine du dossier à donner à l'agent)
├── Fylio/
│   ├── FylioApp.swift / AppViewModel.swift / AppViewModel+Storage.swift / AppViewModel+Support.swift
│   │      → bundles livrés : "FylioUI_8_AppViewModel.swift.md" (blocs 1+2+patch sécurité)
│   │        + "FylioUI_9_StorageKeychain.swift.md" + "FylioUI_13_Support.swift.md" + bloc 3 (FylioApp/RootView/MainTabView)
│   ├── FylioCore/
│   │   ├── FylioModels.swift / FylioProtocol.swift / FylioCrypto.swift
│   │   │      → "FYLIOS-SOURCES-1-MOTEUR.md" (§1-§3) + "f5f38b94" (§3 fin + §4)
│   │   ├── FylioTransport.swift  → "FylioCore_FylioTransport.swift.md"
│   │   ├── FylioSession.swift    → "FylioCore_FylioSession.swift.md"
│   │   ├── FylioQRPairing.swift  → "FYLIO-V2-2-QRPairing.swift.md"  (NOUVEAU v2)
│   │   └── FylioUSBTransfer.swift → "FYLIO-V2-1-USB-EtatsDynamiques.swift.md" (NOUVEAU v2)
│   ├── FylioUI/
│   │   ├── DesignSystem/FylioDesign.swift      → "FylioUI_1_DesignSystem.swift.md"
│   │   ├── DesignSystem/FylioDesign2.swift     → "FylioUI_2_DesignSystem2.swift.md"
│   │   ├── DesignSystem/FylioEmptyStateRegistry.swift → "FYLIO-V2-1" (NOUVEAU v2)
│   │   ├── Screens/HomeView.swift              → "FylioUI_3_HomeScreen.swift.md"
│   │   ├── Screens/OnboardingView.swift         → "FylioUI_4_Onboarding.swift.md"
│   │   ├── Screens/SendView.swift              → "FylioUI_5_SendView.swift.md"
│   │   ├── Screens/ReceiveView.swift           → "FylioUI_6_ReceiveView.swift.md"
│   │   ├── Screens/QRScannerView.swift + TransferProgressView.swift + RecentDevicesView.swift → "FylioUI_7"
│   │   ├── Screens/FilesGalleryMusicViews.swift → "FylioUI_12"
│   │   ├── Screens/SettingsView.swift          → "FylioUI_10"
│   │   ├── Screens/FylioNativeGalleryView.swift → "FYLIO-V2-3" (NOUVEAU v2)
│   │   ├── Screens/FylioPDFEditorView.swift     → "FYLIO-V2-3" (NOUVEAU v2)
│   │   ├── Players/FylioPlayerView.swift        → "FylioUI_11"
│   │   └── Support/FileIcon.swift + FilePreviewSheet.swift + QuickLookView.swift → "FylioUI_13"
│   ├── Localizable.xcstrings   → généré par scripts/build_localizable.py
│   ├── Info.plist              → dans project.yml (généré par make_project.py)
│   └── Assets.xcassets/        → rempli par scripts/fetch_assets.py (personnages inclus automatiquement)
├── scripts/
│   ├── fetch_assets.py         → "FYLIO-PROJET-COMPLET.md" §A
│   ├── build_localizable.py    → livré précédemment (7 langues)
│   └── make_project.py         → ce fichier §scripts
├── .github/workflows/build-ipa.yml → ce fichier
├── project.yml                 → généré par make_project.py
└── docs/ (PLAN-ARCHITECTURE, ANALYSE-CONCURRENTS, AGENT-INSTRUCTIONS, SIDELOADLY)
```

## RÉCAPITULATIF V2 — ce qui a été ajouté/rétravaillé dans cette itération

| Exigence de ton message | Statut | Fichier |
|---|---|---|
| Transfert par câble USB qui marche (iPhone ↔ PC) | ✅ `FylioUSBTransfer` : conteneur Documents exposé au PC (Explorateur Windows → iPhone → Fylio), scan de l'Inbox, import automatique dans la galerie Reçu — mécanisme Apple-sanctionné, le même que SHAREit utilise sur iPhone | FYLIO-V2-1 |
| Page QR qui génère de vrais QR de connexion Wi-Fi (mode SHAREit) | ✅ `FylioQRPairing` : IP+port+clé publique éphémère, expiration 5 min, connexion TCP directe sur le réseau local, clé de session ECDH dérivée — aucun secret en clair | FYLIO-V2-2 |
| Personnages et illustrations tous intégrés | ✅ `fetch_assets.py` télécharge les 42 assets (mascotte, 6 avatars, 11 objets animés, icônes appareils, états vides par page, widgets musique, QR, logo) directement dans Assets.xcassets — **rien à ajouter à la main** | FYLIO-PROJET-COMPLET §A |
| Couleurs fidèles (pas un bleu simple) | ✅ Palette exacte à 11 teintes + fond dégradé radial + formes organiques translucides floues + glassmorphism — règle « jamais de bleu plat » écrite noir sur blanc dans les règles design | FYLIO-PROJET-COMPLET (règles) + FylioUI_1 |
| Photos/vidéos apparaissent directement dans l'app (pas de redirection Apple) | ✅ `FylioNativeGallery` : PHAsset affiché dans la grille Fylio, miniatures et lecture vidéo via URL dans le lecteur Fylio — comme SHAREit | FYLIO-V2-3 |
| PDF modifiable + enregistré | ✅ `FylioPDFEditorView` : surlignage/encre/texte/signature PDFKit, rotation/suppression de pages, **export sauvegardé** dans Documents/Fylio/Recu | FYLIO-V2-3 |
| Personnages d'état vide qui apparaissent quand vide et disparaissent sinon | ✅ `FylioEmptyStateRegistry` + `FylioEmptyStateSlot` : logique centralisée (si vide → personnage animé ; si contenu → liste réelle), personnage différent par page | FYLIO-V2-1 |
| Un seul fichier/ensemble à télécharger, tout à l'intérieur | ✅ Ce master file + les 19 livrables indexés (liens fournis dans l'INDEX) | — |
| Fonctionne entre PC et iPhone | ✅ USB (conteneur partagé) + Wi-Fi local (mDNS + QR) — les deux chemins documentés | V2-1, V2-2 |
| Poids type SHAREit (~117 Mo) | ℹ️ Fylio restera plus léger (~40-60 Mo) : les gros lecteurs sont natifs Apple (AVFoundation/PDFKit) — pas de bundling de codecs tierces qui alourdit et risque le rejet App Store | — |
```
