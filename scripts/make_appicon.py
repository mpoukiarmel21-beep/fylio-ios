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
    # Fond bleu profond UNIQUEMENT pour l'icône/logo (app = blanc glacier, icône = bleu)
    for filename, size in SIZES:
        canvas = Image.new("RGBA", (size, size), (10, 61, 143, 255))  # #0A3D8F
        # Logo centré à 68% de la taille (marges bleues)
        pad = int(size * 0.16)
        inner = size - pad * 2
        icon = logo.resize((inner, inner), Image.LANCZOS)
        canvas.alpha_composite(icon, dest=(pad, pad))
        canvas = canvas.convert("RGB")  # pas de transparence (Apple refuse)
        canvas.save(OUT / filename, "PNG")
    contents = {
        "images": [
            {"filename": "icon-40.png", "idiom": "iphone", "scale": "2x", "size": "20x20"},
            {"filename": "icon-60.png", "idiom": "iphone", "scale": "3x", "size": "20x20"},
            {"filename": "icon-58.png", "idiom": "iphone", "scale": "2x", "size": "29x29"},
            {"filename": "icon-87.png", "idiom": "iphone", "scale": "3x", "size": "29x29"},
            {"filename": "icon-80.png", "idiom": "iphone", "scale": "2x", "size": "40x40"},
            {"filename": "icon-120.png", "idiom": "iphone", "scale": "3x", "size": "40x40"},
            {"filename": "icon-180.png", "idiom": "iphone", "scale": "3x", "size": "60x60"},
            {"filename": "icon-76.png", "idiom": "ipad", "scale": "1x", "size": "76x76"},
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