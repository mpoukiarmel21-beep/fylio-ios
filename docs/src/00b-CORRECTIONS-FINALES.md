# FYLIO V5-2 — CORRECTIONS FINALES APPLIQUÉES (logo en icône, fond complexe exact, i18n complété)

## 1) `scripts/make_appicon.py` — TON logo devient l'icône de l'app + écran de lancement

```python
#!/usr/bin/env python3
"""Fylio — Génère AppIcon.appiconset (toutes tailles iOS) depuis TON logo.
Prérequis : pip install pillow — Usage : python3 scripts/make_appicon.py"""
from PIL import Image
from pathlib import Path
import json

LOGO = Path("Fylio/Assets.xcassets/logo_fylio.imageset/logo_fylio.png")
OUT = Path("Fylio/Assets.xcassets/AppIcon.appiconset")

SIZES = [
    ("icon-40.png", 40), ("icon-58.png", 58), ("icon-60.png", 60),
    ("icon-76.png", 76), ("icon-80.png", 80), ("icon-87.png", 87),
    ("icon-120.png", 120), ("icon-152.png", 152), ("icon-167.png", 167),
    ("icon-180.png", 180), ("icon-1024.png", 1024),
]

def make_icon():
    OUT.mkdir(parents=True, exist_ok=True)
    logo = Image.open(LOGO).convert("RGBA")
    # Fond : blanc bleuté de la DA (#EFF7FD) — jamais transparent (Apple le refuse)
    for filename, size in SIZES:
        canvas = Image.new("RGBA", (size, size), (239, 247, 253, 255))
        icon = logo.resize((size, size), Image.LANCZOS)
        canvas.alpha_composite(icon)
        canvas.save(OUT / filename)
    contents = {
        "images": [
            {"filename": "icon-40.png", "idiom": "iphone", "scale": "2x", "size": "20x20"},
            {"filename": "icon-58.png", "idiom": "iphone", "scale": "3x", "size": "20x20"},
            {"filename": "icon-60.png", "idiom": "iphone", "scale": "2x", "size": "29x29"},
            {"filename": "icon-87.png", "idiom": "iphone", "scale": "3x", "size": "29x29"},
            {"filename": "icon-80.png", "idiom": "iphone", "scale": "2x", "size": "40x40"},
            {"filename": "icon-120.png", "idiom": "iphone", "scale": "3x", "size": "40x40"},
            {"filename": "icon-120.png", "idiom": "ipad", "scale": "2x", "size": "60x60"},
            {"filename": "icon-152.png", "idiom": "ipad", "scale": "2x", "size": "76x76"},
            {"filename": "icon-167.png", "idiom": "ipad", "scale": "2x", "size": "83.5x83.5"},
            {"filename": "icon-1024.png", "idiom": "ios-marketing", "scale": "1x", "size": "1024x1024"},
        ],
        "info": {"author": "xcode", "version": 1},
    }
    (OUT / "Contents.json").write_text(json.dumps(contents, indent=2))
    print(f"OK — AppIcon généré depuis TON logo ({len(SIZES)} tailles) → {OUT}")

if __name__ == "__main__":
    make_icon()
```

**Ajouts à `project.yml` (make_project.py)** — remplace la section settings :
```yaml
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
    info:
      path: Fylio/Info.plist
      properties:
        CFBundleDisplayName: Fylio
        UILaunchScreen:
          UIImageName: logo_fylio
```

**Ordre des scripts dans la CI** (`.github/workflows/build-ipa.yml`) :
```yaml
      - name: Fetch design assets
        run: python3 scripts/fetch_assets.py
      - name: Generate app icon from logo
        run: |
          pip install pillow
          python3 scripts/make_appicon.py
      - name: Build localizations
        run: python3 scripts/build_localizable.py
      - name: Generate Xcode project
        run: python3 scripts/make_project.py
```

## 2) `FylioBackground` — VERSION FINALE EXACTE (fond complexe multi-couches)

```swift
import SwiftUI

/// FOND FYLIO — reproduction exacte de la maquette : dégradé radial blanc →
/// bleu glacier, zones lumineuses cyan, rubans de verre translucides, halo
/// supérieur. JAMAIS de fond bleu plat — la profondeur vient de la superposition
/// des dégradés radiaux + des formes organiques floues.
public struct FylioBackground: View {
    @Environment(\.colorScheme) private var scheme

    public init() {}

    public var body: some View {
        ZStack {
            // COUCHE 1 — base : blanc → bleu glacier (diagonale)
            (scheme == .dark
                ? LinearGradient(colors: [Color(hex: 0x061428), Color(hex: 0x0A2440)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing)
                : LinearGradient(colors: [FylioPalette.whiteIce, FylioPalette.paleBlue],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))

            // COUCHE 2 — dégradé radial central : blanc pur au milieu
            RadialGradient(colors: [Color.white.opacity(0.95), Color.white.opacity(0.0)],
                           center: UnitPoint(x: 0.5, y: 0.28),
                           startRadius: 40, endRadius: 480)
                .blendMode(.plusLighter)

            // COUCHE 3 — zones lumineuses cyan (gauche médium, droite haut)
            RadialGradient(colors: [FylioPalette.brightBlue.opacity(0.22), .clear],
                           center: UnitPoint(x: 0.08, y: 0.55), startRadius: 30, endRadius: 260)
            RadialGradient(colors: [FylioPalette.brightBlue.opacity(0.18), .clear],
                           center: UnitPoint(x: 0.94, y: 0.12), startRadius: 20, endRadius: 220)

            // COUCHE 4 — rubans de verre translucides (organiques, discrets)
            ribbon(width: 460, height: 170, rotation: -14, x: -60, y: 210,
                   color: FylioPalette.lightBlue.opacity(0.16), blur: 26)
            ribbon(width: 520, height: 190, rotation: 11, x: 120, y: -120,
                   color: FylioPalette.brightBlue.opacity(0.13), blur: 34)
            ribbon(width: 380, height: 140, rotation: -7, x: -150, y: 560,
                   color: FylioPalette.secondaryBlue.opacity(0.10), blur: 30)

            // COUCHE 5 — halo supérieur très léger
            LinearGradient(colors: [Color.white.opacity(0.35), .clear],
                           startPoint: .top, endPoint: .center)
                .frame(height: 200)
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea()
    }

    private func ribbon(width: CGFloat, height: CGFloat,
                        rotation: Double, x: CGFloat, y: CGFloat,
                        color: Color, blur: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(color)
            .frame(width: width, height: height)
            .rotationEffect(.degrees(rotation))
            .blur(radius: blur)
            .offset(x: x, y: y)
    }
}
```

**Vérification visuelle (Agent Design)** : 5 couches superposées = la profondeur complexe de la maquette, pas un aplat. En mode sombre : mêmes formes, base bleu nuit. Chaque écran utilise `FylioBackground()` — un seul endroit à ajuster si besoin.

## 3) Compléments i18n (à ajouter à TABLE dans `build_localizable.py`)

```python
    "onboarding.avatar.importPhoto": {"en": "Import a photo", "zh-Hans": "导入照片", "hi": "फ़ोटो आयात करें", "es": "Importar una foto", "fr": "Importer une photo", "ar": "استيراد صورة", "pt": "Importar uma foto"},
    "guide.title":   {"en": "Welcome to Fylio!", "zh-Hans": "欢迎使用 Fylio！", "hi": "Fylio में आपका स्वागत है!", "es": "¡Bienvenido a Fylio!", "fr": "Bienvenue sur Fylio !", "ar": "مرحبا بك في Fylio!", "pt": "Bem-vindo ao Fylio!"},
    "guide.subtitle": {"en": "Tap Send or Receive to start a transfer.", "zh-Hans": "点击发送或接收开始传输。", "hi": "स्थानांतरण शुरू करने के लिए भेजें या प्राप्त करें दबाएँ।", "es": "Toca Enviar o Recibir para empezar.", "fr": "Touchez Envoyer ou Recevoir pour commencer.", "ar": "اضغط على إرسال أو استلام للبدء.", "pt": "Toque em Enviar ou Receber para começar."},
    "common.done":   {"en": "Done", "zh-Hans": "完成", "hi": "पूर्ण", "es": "Hecho", "fr": "Terminé", "ar": "تم", "pt": "Concluído"},
    "common.retry":  {"en": "Retry", "zh-Hans": "重试", "hi": "पुनः प्रयास करें", "es": "Reintentar", "fr": "Réessayer", "ar": "إعادة المحاولة", "pt": "Tentar novamente"},
    "pdf.saved":     {"en": "PDF saved", "zh-Hans": "PDF 已保存", "hi": "PDF सहेजा गया", "es": "PDF guardado", "fr": "PDF enregistré", "ar": "تم حفظ PDF", "pt": "PDF salvo"},
    "pdf.saveFailed": {"en": "Save failed", "zh-Hans": "保存失败", "hi": "सहेजना असफल", "es": "Error al guardar", "fr": "Échec de l'enregistrement", "ar": "فشل الحفظ", "pt": "Falha ao salvar"},
    "pdf.tool.highlight": {"en": "Highlight", "zh-Hans": "高亮", "hi": "हाइलाइट", "es": "Resaltar", "fr": "Surligner", "ar": "تمييز", "pt": "Destacar"},
    "pdf.tool.pen":  {"en": "Pen", "zh-Hans": "画笔", "hi": "कलम", "es": "Lápiz", "fr": "Stylo", "ar": "قلم", "pt": "Caneta"},
    "pdf.tool.text": {"en": "Text", "zh-Hans": "文本", "hi": "पाठ", "es": "Texto", "fr": "Texte", "ar": "نص", "pt": "Texto"},
    "pdf.tool.signature": {"en": "Signature", "zh-Hans": "签名", "hi": "हस्ताक्षर", "es": "Firma", "fr": "Signature", "ar": "توقيع", "pt": "Assinatura"},
    "pdf.rotatePage": {"en": "Rotate page", "zh-Hans": "旋转页面", "hi": "पेज घुमाएँ", "es": "Girar página", "fr": "Pivoter la page", "ar": "تدوير الصفحة", "pt": "Girar página"},
    "pdf.deletePage": {"en": "Delete page", "zh-Hans": "删除页面", "hi": "पेज मिटाएँ", "es": "Eliminar página", "fr": "Supprimer la page", "ar": "حذف الصفحة", "pt": "Excluir página"},
```

## 4) CHECKLIST ANTI-« ÉLÉMENTS BOULEVERSÉS » (pour l'agent de compilation)

Pour éviter le problème que tu as connu (éléments déplacés/reclassés par un autre agent), cette checklist verrouille l'emplacement de chaque chose :

| Élément | Emplacement VERROUILLÉ | Test visuel |
|---|---|---|
| Logo | `logo_fylio` = icône app + écran lancement + À propos | L'icône sur l'écran d'accueil de l'iPhone = ton logo |
| Mascotte accueil | DROITE des boutons Envoyer/Recevoir (gauche = boutons) | Maquette accueil |
| Personnage appareils vides | Bloc appareils récents quand 0 appareil | Asset 2 |
| Personnage historique vide | Bloc historique quand 0 transfert | Asset 3 |
| Personnages Galerie | Haut gauche + haut droite | Maquette Galerie |
| Personnage Musique | Haut de page | Maquette Musique |
| Personnage QR | Haut + bas du QR (même asset, 2 positions) | Maquette QR |
| Objets animés 1-11 | Barre de progression (1 tiré au sort par transfert) | Page Transfert |
| Icônes appareils | Assets 5/6/7 selon plateforme détectée | Lignes appareils |
| 6 avatars | Onboarding + header + demandes entrantes | Cercles contour bleu |
| Fond complexe | `FylioBackground()` sur CHAQUE écran (un seul composant) | Toutes pages |
| Palette | `FylioPalette` uniquement — aucune couleur codée en dur ailleurs | grep dans le code |
