#!/usr/bin/env python3
"""Fylio — Génère project.yml puis Fylio.xcodeproj (xcodegen) et le CI GitHub Actions."""
import subprocess, sys
from pathlib import Path

PROJECT_YML = """name: Fylio
options:
  bundleIdPrefix: ai.fylio
  deploymentTarget:
    iOS: "17.0"
  createIntermediateGroups: true
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
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        ENABLE_ON_DEMAND_RESOURCES: "NO"
    info:
      path: Fylio/Info.plist
      properties:
        CFBundleDisplayName: Fylio
        UILaunchScreen:
          UIImageName: logo_fylio
        NSLocalNetworkUsageDescription: Fylio has to join the local network to send and receive files.
        NSBonjourServices:
          - _fylio._tcp
        NSCameraUsageDescription: Fylio uses the camera to scan pairing QR codes.
        NSPhotoLibraryUsageDescription: Fylio imports your photos and videos before sending them.
        NSPhotoLibraryAddUsageDescription: Fylio saves received photos and videos to your library.
        UIBackgroundModes:
          - audio
        UIFileSharingEnabled: true
        LSSupportsOpeningDocumentsInPlace: true
        ITSAppUsesNonExemptEncryption: false
schemes:
  Fylio:
    build:
      targets:
        Fylio: all
    run:
      config: Release
    archive:
      config: Release
"""

WORKFLOW_YML = """name: Build Fylio IPA
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
      - name: Install Pillow (génération icône)
        run: python3 -m pip install --quiet --user --break-system-packages pillow
      - name: Generate app icon (00b)
        run: python3 scripts/make_appicon.py
      - name: Build localizations (7 langues)
        run: python3 scripts/build_localizable.py
      - name: Generate Xcode project
        run: python3 scripts/make_project.py
      - name: Build archive (unsigned)
        run: |
          mkdir -p build
          xcodebuild archive \\
            -project Fylio.xcodeproj -scheme Fylio \\
            -configuration Release \\
            -destination 'generic/platform=iOS' \\
            -archivePath build/Fylio.xcarchive \\
            CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \\
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
"""

AGENT_INSTRUCTIONS = """# FYLIO — Instructions pour l'agent de compilation

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
2. `pip install pillow` puis `python3 scripts/make_appicon.py` → AppIcon généré depuis logo_fylio
3. `python3 scripts/build_localizable.py` → Localizable.xcstrings (7 langues)
4. `brew install xcodegen` (si absent)
5. `python3 scripts/make_project.py`     → Fylio.xcodeproj généré
6. Xcode → Open Fylio.xcodeproj → sélectionner un iPhone → **Build & Run**
   (ou ligne 7 pour l'IPA)
7. `xcodebuild archive -project Fylio.xcodeproj -scheme Fylio
   -configuration Release -destination 'generic/platform=iOS'
   -archivePath build/Fylio.xcarchive CODE_SIGNING_ALLOWED=NO` puis zipper
   le .app en Payload → Fylio-unsigned.ipa
8. Signer l'IPA avec Sideloadly (Apple ID gratuit) → installer sur l'iPhone.

## Sur GitHub (sans Mac)
Pousser ce dossier tel quel → GitHub Actions (workflow inclus) fait les étapes
1-7 automatiquement → IPA téléchargeable dans l'onglet **Actions** → artefact
`Fylio-unsigned-IPA`.

## Aucun secret dans le dépôt
Pas de certificat, clé, provisioning ou identifiant Apple — par conception.
"""

AGENT_INSTRUCTIONS_PATH = "docs/AGENT-INSTRUCTIONS.md"


def main():
    root = Path(__file__).resolve().parents[1]
    (root / "project.yml").write_text(PROJECT_YML, encoding="utf-8")
    (root / "docs").mkdir(exist_ok=True)
    (root / AGENT_INSTRUCTIONS_PATH).write_text(AGENT_INSTRUCTIONS, encoding="utf-8")
    workflow = root / ".github" / "workflows"
    workflow.mkdir(parents=True, exist_ok=True)
    (workflow / "build-ipa.yml").write_text(WORKFLOW_YML, encoding="utf-8")
    print("OK — project.yml, docs/AGENT-INSTRUCTIONS.md et .github/workflows/build-ipa.yml écrits.")
    try:
        subprocess.run(["xcodegen", "generate"], cwd=root, check=True)
        print("OK — Fylio.xcodeproj généré. Ouvre-le dans Xcode → Build (iOS device) → IPA.")
    except FileNotFoundError:
        print("Remarque : xcodegen absent de ce poste — le projet sera généré sur macOS (ou en CI via GitHub Actions).")
    return 0


if __name__ == "__main__":
    sys.exit(main())