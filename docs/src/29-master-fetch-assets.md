# FYLIO — PROJET COMPLET V2 (master file à donner à l'agent de compilation)
**Ce document contient l'intégralité du projet. L'agent de compilation doit :**
1. Créer le dossier `Fylio/` et recopier chaque fichier ci-dessous (chemins indiqués).
2. Exécuter `python3 scripts/fetch_assets.py` → télécharge AUTOMATIQUEMENT tous les personnages/illustrations depuis les URLs fournies et les range dans `Assets.xcassets` (rien à faire à la main).
3. Exécuter `python3 scripts/build_localizable.py` → génère les 7 langues.
4. Ouvrir `Fylio.xcodeproj` (créé par le script `scripts/make_project.py`) → Build → IPA.

## RÈGLES DESIGN (strictes, tirées de la maquette)
- Palette exacte : `#EFF7FD` `#D3EAFB` `#B2DAF7` `#8AC9F9` `#036FF8` `#31ACF2` `#09BDF5` `#071A68` `#4E7FC1` `#16C79A` `#FF5A5F`
- **Le fond n'est JAMAIS un bleu plat** : dégradé radial blanc→bleu glacier + 3-4 formes organiques translucides floues (rubans de verre) + halo cyan discret.
- Glassmorphism : `.ultraThinMaterial` + bordure blanche 0.6-1px + ombre douce (opacité 0.06, radius 10-14).
- Boutons Envoyer : dégradé `#036FF8 → #09BDF5` + lueur bleue (shadow electricBlue 0.35). Recevoir : blanc translucide.
- États : pressé = scale 0.96 + opacité 0.9 ; sélectionné = contour bleu 4px + fond bleu clair.
- **Système d'états vides dynamiques** : quand il n'y a AUCUN transfert/appareil → personnage vide apparaît ; dès qu'un transfert/appareil existe → le personnage DISPARAÎT et laisse la place à la vraie liste. Voir `FylioEmptyStateRegistry.swift` (§C).

---

## A) `scripts/fetch_assets.py` — télécharge TOUS les personnages automatiquement

```python
#!/usr/bin/env python3
"""Fylio — Télécharge tous les assets design (personnages, logo, objets animés)
depuis les URLs du projet et les installe dans Assets.xcassets. Aucune action manuelle."""
import os, ssl, json, urllib.request

BASE = "https://d3p662obnq9uz2.cloudfront.net/chat-uploads/chat/user/6aafbbf2b08d16b93c91afb4/6aafbcce07b4ff1556f74c13/"

# (URL du fichier, nom dans Assets.xcassets)
ASSETS = [
    ("ecafa228-LOGO___mettre_dans_l_application.png", "logo_fylio"),
    ("cabf683f-logo___mettre_sur_l_affiche___exterieur.png", "logo_fylio_exterior"),
    ("73459743-1-C_est_le_personnage_principal___utiliser___c_t__du_bouton_envoy__et_recevoir_faut_bien_le_redimensionner.png", "mascotte_fylio"),
    ("2af574b3-2-C_est_le_petit_personnage___utiliser_que_tu_vas_mettre_dans_le_bloc_appareil_r_cente_quand_il_y_aura_encore_aucun_appareil_r_.png", "empty_recent_devices"),
    ("5e2e7982-3-Personnages___utiliser_dans_la_page_d_accueil_dans_historique_de_transfert_c_est__cris_aux_cas_transfert_pour_le_moment._Donc.png", "empty_history_home"),
    ("382c2b8a-4-Tu_peux_le_mettre_en_grand_plan_d_s_l_ouverture_de_l_application.png", "mascotte_hero"),
    ("c33637a0-5-Element_appareil_androide.png", "device_android"),
    ("36c6f88e-6-Element_appareil_ordinateur.png", "device_computer"),
    ("f798b38d-7-Element_appareil_iphone.png", "device_iphone"),
    # Objets animés de progression (11)
    ("d8321b79-1-PERSONAGE_object___anime_.png", "progress_obj_1"),
    ("64493548-2-PERSONAGE_object___anime_.png", "progress_obj_2"),
    ("0be10a0d-3-PERSONAGE_object___anime_.png", "progress_obj_3"),
    ("de2ade5a-4-PERSONAGE_object___anime_.png", "progress_obj_4"),
    ("2f0c5bcd-5-PERSONAGE_object___anime_.png", "progress_obj_5"),
    ("5e834b66-6-PERSONAGE_object___anime_.png", "progress_obj_6"),
    ("2e5c0473-7-PERSONAGE_object___anime_.png", "progress_obj_7"),
    ("b60c831c-8-PERSONAGE_object___anime_.png", "progress_obj_8"),
    ("38babda9-9-PERSONAGE_object___anime_.png", "progress_obj_9"),
    ("7a35a4a8-10-PERSONAGE_object___anime_.png", "progress_obj_10"),
    ("04d770ac-11-PERSONAGE_object___anime_.png", "progress_obj_11"),
    # Page Fichiers
    ("60c1081b-2-C_est_si_le_personnage_que_tu_vas_mettre_en_haut.png", "files_character"),
    ("070dcc91-3-_l_ment__voici_l_ic_ne_des_dossiers_des_appareils_qui_va_s_afficher.png", "device_folder_icon"),
    # Page Galerie
    ("dfeba041-2-_a__c_est_le_personnage_que_tu_vas_mettre___droite_et_en_haut_et_la_page.png", "gallery_character_right"),
    ("f81d94b1-3-_a__c_est_le_personnage_que_tu_vas_mettre___gauche_et_en_haut_de_la_page.png", "gallery_character_left"),
    ("ca01f76e-4-_a__c_est_le_personnage_qui_doivent_s_afficher_quand_il_y_a_aucune_vid_o_et_Photos_d_tect_es.png", "empty_gallery"),
    # Page Historique
    ("e5985fb8-2-_a__c_est_le_personnage_que_tu_vas_mettre_quand_il_y_a_aucun_transfert_dans_l_historique_des_transferts.png", "empty_history"),
    # Page Musique
    ("33762b6f-2-__a__c_est_le_personnage_que_tu_vas_mettre_en_haut.png", "music_character"),
    ("87fd5f53-3-_l_ment__a__c_est_le_petit_widget_de_musique_quand_on_lance_la_musique_qui_appara_tre_dans_le_petit_panneau_de_contr_le_du_T_.png", "music_widget_lockscreen"),
    ("7064a41b-4-_l_ment__a__c_est_le_petit_widget_de_musique_quand_on_lance_la_musique_qui_appara_tre_dans_le_petit_panneau_de_contr_le_du_T_.png", "music_widget_control"),
    ("9bf8f356-5-_a_c_est_le_personnage_qui_va_s_afficher_quand_il_y_aura_aucune_musique__d_tect_e_dans_son_appareil.png", "empty_music"),
    ("1380e92d-6-_l_ment__a__c_est_l__l_ment_de_la_barre_de_recherche_le_style_que_tu_dois_mettre_et_le_DA.png", "searchbar_style"),
    ("7083fbc5-7-_l_ment__a__c_est_l__l_ment_qui_s_affiche_en_bas_Pour__par_exemple_quand_il_va_cliquer_pour_que__a_fasse_Play.png", "play_button_style"),
    ("5b4dc945-8-_l_ment__a_c_est_le_style_de_l__l_ment__il_va_cliquer_quand_c_est_en_play_quand_la_musique_passe.png", "pause_button_style"),
    ("bc2a4e3a-9-_l_ment___a_c_est_l__l_ment_des_playlists_qui_doit_s_afficher_bien_s_r__l_image_est_juste_repr_sentatif__a_veut_dire_que__a_v.png", "playlist_style"),
    # Page QR
    ("4c625848-2-Alors__a_c_est_le_personnage_que_tu_dois_mettre_en_haut_et_en_bas_sur_chaque_QR_code___scanner.png", "qr_character"),
    # 6 avatars onboarding
    ("519b19fa-personage1.png", "personage1"),
    ("6c224a6f-personage2.png", "personage2"),
    ("6d6638d5-personage3.png", "personage3"),
    ("03ee284b-personage4.png", "personage4"),
    ("919df18a-personage5.png", "personage5"),
    ("b5ec66ec-personage6.png", "personage6"),
]

def install(url: str, name: str):
    req = urllib.request.Request(BASE + url, headers={"User-Agent": "Fylio/1.0"})
    data = urllib.request.urlopen(req, timeout=60).read()
    folder = f"Fylio/Assets.xcassets/{name}.imageset"
    os.makedirs(folder, exist_ok=True)
    filename = f"{name}.png"
    with open(f"{folder}/{filename}", "wb") as f:
        f.write(data)
    contents = {"images": [{"filename": filename, "idiom": "universal", "scale": "1x"},
                           {"idiom": "universal", "scale": "2x"},
                           {"idiom": "universal", "scale": "3x"}],
                "info": {"author": "xcode", "version": 1}}
    with open(f"{folder}/Contents.json", "w") as f:
        json.dump(contents, f, indent=2)
    print(f"OK {name} ({len(data)//1024} KB)")

if __name__ == "__main__":
    os.makedirs("Fylio/Assets.xcassets", exist_ok=True)
    for url, name in ASSETS:
        install(url, name)
    # Contents.json racine obligatoire
    with open("Fylio/Assets.xcassets/Contents.json", "w") as f:
        json.dump({"info": {"author": "xcode", "version": 1}}, f)
    print(f"\nTERMINÉ : {len(ASSETS)} assets installés dans Assets.xcassets")
```
