# PLAN D'ARCHITECTURE — FYLIO
**Version : 1.0 · Date : 2026-09-20 · Statut : Phase 0 validée → Phase 1**
Application multiplateforme de transfert de fichiers — rapide, simple, professionnelle, style 2026.
**V1 cible : iOS (fichier IPA)**, puis Android → Windows → macOS.

---

## 0. Mission

Simplifier le transfert de fichiers entre iPhone, Android, Windows et macOS :
iPhone ↔ Windows · Android ↔ Windows · iPhone ↔ macOS · Android ↔ macOS · téléphone ↔ téléphone · ordinateur ↔ ordinateur.

Positionnement : la simplicité de SHAREit × l'esthétique moderne de Blip, avec une UX/UI premium épurée (glassmorphism, blanc + bleu électrique).

**Principes non négociables**
1. Rien ne démarre sans audit complet des ressources design (fait).
2. Aucun code copié : code original écrit de A à Z (ni depuis le PC, ni depuis GitHub, ni depuis les anciennes analyses Blip/SHAREit fournies — ces fichiers sont ignorés par principe).
3. L'utilisateur reste dans l'écosystème Fylio (lecteurs, galerie, navigateur de fichiers internes) ; sélecteur natif iOS uniquement si le système l'impose.
4. Aucun certificat, clé privée, provisioning profile ou identifiant Apple dans le dépôt GitHub.
5. Moteur de transfert séparé de l'interface, réutilisable sur toutes les plateformes.
6. Qualité maintenue de bout en bout : chaque phase est vérifiée par l'Agent Vérification avant passage à la suivante.

---

## 1. Équipe d'agents

| # | Agent | Responsabilité | Veto |
|---|-------|----------------|------|
| 1 | **Administrateur** (chef de projet) | Vision globale, audit des ressources, délégation, coordination design/technique/plateformes/QA, centralisation des livrables, validation de fin d'étape | — |
| 2 | **Vérification** (garant conformité) | Contrôle point par point du brief, DA, fonctionnalités, contraintes ; refuse toute livraison incomplète ; binôme de l'Administrateur | ✅ Oui |
| 3 | **Design / UX-UI** | Audit visuel, DA, design system, reproduction fidèle des maquettes, états vides animés, navigation réelle, animations | — |
| 4 | **Architecture Transfert** | Découverte Wi-Fi, QR, point d'accès, USB, distant, E2E, reprise, intégrité, multi-blocs parallèles, moteur séparé | — |
| 5 | **Compatibilité Plateformes** | Contraintes Apple/App Store, permissions iOS/Android, USB, notifications, PiP, arrière-plan, publication, installateurs, notarisation | — |
| 6 | **Innovation Produit** | Améliorations UX, nouvelles méthodes de transfert, différenciateurs, documentation des propositions sans validation préalable | — |
| 7 | **QA / Anti-bugs** | Tests boutons/pages/transferts, cas limites, permissions, performances, refus de toute fonctionnalité factice, refus de tout bug bloquant | ✅ Oui |

---

## 2. Phase 0 — Audit des ressources design (terminé)

### 2.1 Fichiers d'instructions lus
- `INSTRUCTION.txt` (personnage) : mascotte à côté des boutons Envoyer/Recevoir ; personnage qui avance avec la barre de progression ; icônes appareil selon la plateforme détectée (Android / ordinateur / iPhone).
- `Instruction.txt` (logo + objets animés) : personnage animé apparaît quand la barre commence à avancer et avance en même temps qu'elle ; éléments 5/6/7 = icônes d'appareils selon le modèle avec lequel l'utilisateur transfère.
- `Pages.txt` : spécification UX/UI complète de la page d'accueil (couleurs, dimensions, hiérarchie, glassmorphism).

### 2.2 Cartographie des assets (source de vérité design)

| Asset | Rôle | Emplacement dans l'app |
|---|---|---|
| LOGO (dans l'application) | Identité Fylio | Splash, onboarding, en-tête à propos |
| Logo (affiche extérieure) | Communication | Stores, affichage externe |
| Maquette `0-pages d'accueil` | Référence à reproduire fidèlement | Page Accueil |
| Personnage principal (asset 1) | Mascotte (à redimensionner) | À côté des boutons Envoyer/Recevoir |
| Petit personnage (asset 2) | État vide appareils récents | Bloc « Appareils récents » quand vide (nouveau compte ou historique effacé) |
| Personnages (asset 3) | État vide historique | Bloc « Historique de transferts » quand vide |
| Personnage (asset 4) | Grand plan | Première ouverture de l'application |
| Éléments 5 / 6 / 7 | Icônes appareil Android / ordinateur / iPhone | Blocs appareils récents + transferts |
| Maquette + `1-11 PERSONAGE object à animé` | Page Transfert en cours ; objet animé qui avance avec la barre | Barre de progression — objet choisi aléatoirement au début du transfert, identique pendant tout le transfert, jamais immobile |
| Maquette + personnage haut / icône dossiers | Page Fichiers | En-tête de la page Fichiers + icônes dossiers d'appareils |
| Maquette Galerie + 4 personnages (droite, gauche, vide) | Page Galerie | Ornements en haut, état vide « aucune photo/vidéo » |
| Maquette Historique + personnage vide | Page Historique de transfert | État vide « aucun transfert » |
| Maquette Musique + personnage, widgets, barre de recherche, boutons play/pause, playlists | Page Musique | En-tête ; widget écran verrouillé/panneau contrôle ; barre de recherche ; lecteur bas de page ; playlists |
| Maquette QR + personnage haut/bas | Page QR code | Ornement autour du QR à scanner |
| `personage1` → `personage6` | Les 6 avatars proposés | Onboarding : choix d'avatar recadré en cercle, contour bleu + fond bleu léger à la sélection ; import photo perso possible |

### 2.3 Spécification visuelle extraite (page d'accueil)
- Palette : `#EFF7FD` blanc · `#D3EAFB` bleu très pâle · `#B2DAF7` bleu clair · `#8AC9F9` bleu lumineux · `#036FF8` bleu électrique · `#31ACF2` bleu secondaire · `#071A68` bleu nuit (texte) · `#4E7FC1` texte secondaire · `#16C79A` vert statut · rouge notification.
- Fond : dégradé radial blanc → bleu glacier, formes organiques translucides discrètes, jamais de bleu plat.
- Style : glassmorphism, coins très arrondis (35-40 px sur gros boutons), ombres très douces, bordures translucides, profondeur légère entre panneaux.
- Header : avatar circulaire 90 px (fond bleu clair, contour blanc, point vert en ligne), nom en 37 px très gras, « ● Toujours connecté » en bleu moyen, boutons circulaires translucides notification (point rouge) + paramètres.
- Titre « Bonjour {nom} 👋 » ~46-50 px très gras ; sous-titre « Vos fichiers, partout avec vous. » ~27-30 px.
- Mascotte ~280-320 px de large, chevauche légèrement les boutons d'action.
- Bouton Envoyer : ~450×140 px, dégradé `#036FF8 → #09BDF5`, icône avion papier blanche, titre 35-38 px, sous-titre 22 px, chevron, lueur bleue, ombre douce.
- Bouton Recevoir : même largeur, ~130-140 px, blanc translucide, icône téléchargement bleue.
- Système : 35-45 px de marges horizontales, contenu vertical.

---

## 3. Journal des décisions (Phase 0)

| ID | Décision | Justification |
|----|----------|---------------|
| D01 | Ignorer intégralement les fichiers d'analyse Blip/SHAREit (jadx, binaires, strings) fournis | Brief : code original de A à Z, aucune copie ni analyse de l'existant |
| D02 | V1 = iOS natif uniquement, IPA livré | Directive utilisateur ; Android/desktop ensuite |
| D03 | Stack iOS : Swift 6 + SwiftUI, architecture MVVM modulaire, modules SPM | Maintenabilité, évolutivité multiplateforme du cœur |
| D04 | Moteur de transfert = module `FylioCore` isolé (protocoles purs, zéro dépendance UI), réutilisable plus tard via Rust/FFI pour Windows/macOS | Séparation moteur/UI exigée par le brief |
| D05 | Découverte locale : Bonjour/mDNS via Network.framework ; transport : TCP via NWConnection ; QR : pairage clé éphémère | Fonctionne sans Internet, standard Apple, App Store-safe |
| D06 | Chiffrement : CryptoKit (Curve25519 + AES-GCM) ; intégrité : SHA-256 par bloc | E2E natif iOS, pas de dépendance tierce à auditer |
| D07 | Stockage/index : SQLite (GRDB) + fichiers dans conteneur app ; PhotoKit en lecture pour galerie | Indexation rapide, respect des permissions iOS |
| D08 | Lecteurs : AVFoundation (vidéo/audio, PiP, arrière-plan, geste, reprise position), PDFKit (annotation/export) | Écosystème interne Fylio sans dépendances lourdes |
| D09 | i18n : 7 langues (🇬🇧 Anglais, 🇨🇳 Mandarin, 🇫🇷 Français, 🇪🇸 Espagnol, 🇦🇷/🇲🇽 Espagnol LATAM via variantes, 🇷🇺 Russe, 🇵🇹🇵🇹 Portugais, plus Hindou 🇮🇳 et Arabe 🇸🇦 comme 8e/9e langues optionnelles V1.1 — les 7 obligatoires : Anglais, Mandarin, Hindi, Espagnol, Français, Arabe, Portugais). Détection automatique : `Locale.current` au premier lancement → langue appliquée sans action utilisateur ; drapeaux affichés dans Paramètres > Langue avec option manuelle | Exigence : traduction automatique selon la langue du téléphone, 7 langues les plus parlées au monde, icônes drapeaux |
| D10 | Numérotation : numéro Fylio `Fylio-XXXX` généré localement (4 chiffres dérivés de la clé publique), stocké dans Keychain | Identité visible exigée par le brief |
| D11 | Édition vidéo→audio (« système PLAYit ») : extraction audio depuis vidéo via AVAssetExportSession (piste sonore exportée en M4A/MP3-compatible AAC) — PAS de réenregistrement temps réel en V1 ; PiP natif AVKit ; arrière-plan via `AVAudioSession` catégorie playback + MPNowPlayingInfoCenter + MPRemoteCommandCenter ; extraction audio en arrière-plan via `BGProcessingTask` si permis | iOS interdit un vrai "screen-record" d'une vidéo pour en extraire l'audio ; l'export de la piste audio existante est la voie légale, fiable et rapide. Le réenregistrement audio (enregistrer le son d'une vidéo pendant qu'elle joue) est documenté comme limitation V1 et dépend des règles App Store |
| D12 | Notifications push entrantes : UNUserNotificationCenter local + discovery en premier plan ; background modes stricts Apple | Pas de serveur requis pour la V1 locale |
| D13 | Dépôt GitHub public neuf, CI via GitHub Actions : build IPA non signée (unsigned/ad-hoc pour Sideloadly) ; secrets jamais commités | Exigence : compilation sur GitHub, IPA téléchargeable |
| D14 | Design tokens centralisés (couleurs, rayons, ombres, espacements) dans un fichier Swift unique + mode sombre | DA cohérente, mode clair/sombre exigé |

---

## 4. Écosystème Fylio (règles produit)

L'utilisateur ne quitte jamais Fylio si une interface Fylio peut faire le travail :
- **Galerie Fylio** (photos/vidéos, via PhotoKit + fichiers reçus).
- **Navigateur de fichiers Fylio** (catégories, dossiers, récents, reçus, envoyés, favoris, recherche, tri, renommage, déplacement, création de dossier).
- **Lecteur vidéo Fylio** (formats AVFoundation, sous-titres, vitesse, rotation, plein écran, gestes luminosité/volume, mémorisation position, PiP, reprise après interruption).
- **Lecteur audio Fylio** (playlists, widget panneau de contrôle + écran verrouillé fourni par la DA, arrière-plan, reprise position).
- **Lecteur PDF Fylio** (lecture, recherche, surlignage, annotation, dessin, texte, signature, rotation/réorganisation/suppression de pages, fusion, export).
- **Aperçu Excel/Word V1** (QuickLook interne pour aperçu/partage/classement ; édition complète plus tard).
- Sélecteur natif iOS (document picker sécurisé) utilisé **uniquement** quand le système l'impose.

## 5. Système « PLAYit » (spécification technique)

| Fonction | Implémentation iOS | Statut V1 |
|---|---|---|
| Réduire la vidéo et utiliser d'autres apps | Picture in Picture natif (AVKit, `AVPictureInPictureController`) | ✅ V1 |
| Widget vidéo qui continue | PiP flottant natif iOS (contraintes Apple respectées : l'app ne peut pas dessiner de fenêtre libre par-dessus les autres apps, PiP est le mécanisme officiel) | ✅ V1 |
| Contrôle écran verrouillé / casque | MPRemoteCommandCenter + MPNowPlayingInfoCenter | ✅ V1 |
| Convertir vidéo → audio | AVAssetExportSession : export de la piste audio en M4A (AAC) ; conversion MP3 via encodeur si licence OK, sinon M4A/AAC natif | ✅ V1 (M4A), MP3 en option |
| « Enregistrer l'audio d'une vidéo » | Extraction de la piste sonore (résultat identique, plus rapide et fidèle qu'un réenregistrement) ; un mode réenregistrement micro est exclu V1 (règles App Store + perte qualité) | ✅ V1 |
| Lecture en arrière-plan avec écran éteint | `AVAudioSession` playback + `UIBackgroundModes: audio` | ✅ V1 |

## 6. Écrans V1 (iOS)

1. **Onboarding** : bienvenue animée (mascotte en grand plan — asset 4), présentation rapide, choix d'avatar parmi 6 personnages (cercles, contour bleu + fond bleu léger à la sélection) + import photo perso, création du nom d'appareil, demandes de permissions (notifications/photos/fichiers), présentation des méthodes de transfert, arrivée sur l'accueil.
2. **Accueil** : conforme à la maquette 0 — header avatar+nom+statut, boutons cloche/paramètres, « Bonjour {nom} 👋 », mascotte, Envoyer/Recevoir, bloc appareils récents (état vide = petit personnage asset 2), « Voir tout » → vraie page appareils récents, bloc historique (état vide = asset 3), bouton effacer historique, indicateurs de connexion.
3. **Envoyer** : sélection fichiers (photos, vidéos, musique, documents, dossiers), récents, recherche, tri, sélection multiple, aperçu, bouton Envoyer visible après sélection.
4. **Recevoir** : nom d'appareil + numéro Fylio, QR code, connexions disponibles, demandes entrantes, animation d'attente, accepter/refuser/pause/annuler.
5. **Appareils récents** : liste associée (avatar, plateforme, dernière connexion, méthode), transfert direct, renommer/supprimer/bloquer, en ligne/hors ligne, état vide animé.
6. **Progression** : nom, aperçu, taille, vitesse, temps restant, pourcentage, pause/reprise/annulation, objet animé (1 des 11 fournis) qui avance avec la barre — tiré au sort au début du transfert, jamais immobile, icônes appareils source/destination selon plateforme.
7. **Fichiers** : conforme à la maquette (personnage en haut, icônes dossiers d'appareils), catégories, dossiers, récents, reçus, envoyés, recherche, favoris, partage, suppression, renommage, déplacement, création de dossier.
8. **Galerie** : conforme à la maquette (personnages haut gauche/droite, état vide dédié).
9. **Musique** : conforme à la maquette (personnage en haut, widget DA, barre de recherche, boutons play/pause DA, playlists, état vide dédié).
10. **Historique de transfert** : conforme à la maquette (état vide dédié).
11. **QR code (scanner)** : conforme à la maquette (personnage haut/bas autour du cadre).
12. **Paramètres** : sections Profil (avatar, nom, numéro Fylio), Apparence (mode clair/sombre/auto), Langue (7 drapeaux 🇬🇧🇨🇳🇮🇳🇪🇸🇫🇷🇸🇦🇵🇹, auto selon le téléphone), Transferts (destination par défaut, auto-acceptation appareils de confiance, Wi-Fi uniquement, notifications), Appareils (liste, blocage, révocation à distance), Stockage (cache, nettoyage), Confidentialité & sécurité (journal, chiffrement, effacer données), Notifications (par type), Aide & à propos (version, licences, logos).
13. **Lecteurs** : vidéo, audio, PDF — internes Fylio.

## 7. Méthodes de transfert (V1 en gras)

**1. Wi-Fi local (même réseau, sans Internet requis)** — découverte mDNS/Bonjour, liste des appareils Fylio (nom, avatar, numéro), confirmation destinataire, transfert direct TCP chiffré.
**2. QR code** — QR temporaire contenant pairage + clé publique éphémère (jamais de donnée sensible en clair), scan → connexion directe.
3. Point d'accès local (hotspot) — V2.
4. Câble USB — V2 (contraintes pilotes Apple/Android documentées ; messages d'erreur clairs).
5. Distant via Internet (numéro Fylio, échange de clés, direct si possible, relais chiffré sinon, validation manuelle, révocation) — V2.
6. Appareil déjà enregistré — V1 (appairage persistant Keychain).
Si une méthode échoue → l'UI propose automatiquement une méthode alternative.

## 8. Moteur de transfert — architecture technique

```
FylioApp (SwiftUI, MVVM)
├── UI/            → écrans, composants, design system, animations
├── Features/      → Send, Receive, Devices, Progress, Files, Gallery, Music, History, Settings
├── FylioCore/     → moteur (zéro UI) :
│   ├── Discovery      (mDNS/Bonjour)
│   ├── Transport      (TCP NWConnection, multi-blocs parallèles)
│   ├── Crypto         (Curve25519 + AES-GCM, SHA-256)
│   ├── Session        (handshake, confirmation, reprise, journal)
│   └── Store          (SQLite index, fichiers, Keychain)
└── Players/       → AVKit vidéo (PiP), audio (arrière-plan), PDFKit
```
- Reprise après interruption : manifeste de transfert (taille, hash par bloc) → reprise à l'octet près.
- Vérification d'intégrité : SHA-256 par bloc + global.
- Multi-blocs parallèles : fenêtre de blocs simultanés adaptée à la qualité réseau.
- Protocole : trames JSON d'annonce/confirmation + flux binaire chiffré AEAD, versionné (`proto v1`) pour évolution future sans casser les anciens clients.

## 9. i18n — détection et langues

- Au premier lancement : lecture de `Locale.current` → si la langue est parmi les 7 prises en charge, l'application se traduit automatiquement (ex. : appareil en anglais aux États-Unis → interface anglaise, sans action de l'utilisateur).
- 7 langues V1 : 🇬🇧 Anglais · 🇨🇳 Chinois (simplifié) · 🇮🇳 Hindou · 🇪🇸 Espagnol · 🇫🇷 Français · 🇸🇦 Arabe (RTL) · 🇵🇹 Portugais.
- Fichiers `Localizable.xcstrings` ; API `String(localized:)` ; RTL natif pour l'arabe.
- Choix manuel possible dans Paramètres → Langue (avec drapeaux), option « Automatique (langue du téléphone) » par défaut.

## 10. Phases de développement

| Phase | Contenu | Sortie |
|---|---|---|
| 0 — Audit ✅ | Inventaire ressources, lecture .txt, analyse maquettes, plan, journal des décisions | Ce document |
| 1 — Prototype visuel | Accueil, onboarding, avatar, envoyer, recevoir, fichiers, appareils récents, galerie, musique, historique, QR, paramètres, états vides, animations, navigation 100 % fonctionnelle | App navigable iOS |
| 2 — Transfert local | Découverte Wi-Fi, QR, connexion, acceptation/refus, envoi/réception, progression animée, reprise, historique | Transferts réels iPhone↔iPhone/Windows |
| 3 — Transfert avancé | Multi-fichiers, dossiers, gros fichiers, chiffrement E2E, reprise après coupure, point d'accès | Moteur durci |
| 4 — USB | Android/iPhone → Windows/macOS, pilotes autorisés, messages d'erreur clairs | Parcours USB |
| 5 — Lecteurs & documents | Vidéo (PiP, arrière-plan, sous-titres), audio (widget, playlists), PDF (annotations, export), vidéo→audio (PLAYit) | Écosystème complet |
| 6 — Distant | Numéro Fylio, authentification, relais chiffré, règles de confiance, notifications distantes | Transfert Internet |
| 7 — Tests & distribution | Tests appareils physiques, réseau sans Internet, permissions, performance, sécurité ; GitHub Actions IPA ; instructions Sideloadly | IPA + guide |

**V1 (périmètre) :** iPhone ↔ Windows · Android ↔ Windows · Wi-Fi local · QR · envoi/réception · notifications · historique · avatars · fichiers/dossiers · animations de progression · lecteur vidéo/audio de base · PDF lecture+annotation · interface Fylio complète · 7 langues · paramètres · PLAYit (PiP + extraction audio).

## 11. QA — grille de contrôle (exécutée à chaque phase)

- [ ] Chaque bouton testé sur chaque écran (aucun bouton factice).
- [ ] Chaque état vide affiche le bon personnage animé.
- [ ] Reproduction des maquettes vérifiée pixel par pixel contre les images du dossier `Pages`.
- [ ] Transferts testés : petits, gros, multi-fichiers, dossiers, coupure réseau, reprise, refus destinataire.
- [ ] Permissions testées avec chaque combinaison (accordée, refusée, réinitialisée).
- [ ] Perf : liste 1000+ fichiers fluide, transfert stable, mémoire < limites.
- [ ] i18n : 7 langues, RTL arabe, texte tronqué vérifié.
- [ ] Aucun secret/identifiant Apple dans le dépôt GitHub.
- [ ] Lecteurs : vidéo/photo/PDF/audio apparaissent fluides dans l'app.

## 12. Déploiement GitHub & distribution iOS

- Nouveau dépôt GitHub public **`fylio`** (zéro historique antérieur) : code, design system, docs, CI.
- GitHub Actions : workflow `build-ipa.yml` — `xcodebuild -scheme Fylio -configuration Release -sdk iphoneos archive` + export **unsigned** (`CODE_SIGNING_ALLOWED=NO`) → artefact IPA téléchargeable depuis l'onglet Actions.
- Jamais de certificats/provisioning dans le repo ; signature locale uniquement.
- **Sideloadly** : guide fourni (`docs/SIDELOADLY.md`) — télécharger l'IPA depuis GitHub Actions, l'ouvrir dans Sideloadly avec un Apple ID, installer sur l'iPhone (limitation 7 jours, compte gratuit). Précision honnête : Sideloadly ne remplace pas une signature App Store ; c'est un moyen de test personnel.
- Publication App Store : étape finale (compte développeur Apple requis, revue Apple).

## 13. Livrables

| Livrable | Support |
|---|---|
| Plan d'architecture | `D:\FYLIO\docs\PLAN-ARCHITECTURE-FYLIO.md` (ce document) |
| Design system + tokens | `Fylio/DesignSystem/` |
| App iOS | Projet VS Code/Xcode `Fylio/` |
| Moteur de transfert | `Fylio/FylioCore/` |
| Lecteurs + PDF + vidéo→audio | `Fylio/Players/` |
| Dépôt GitHub public neuf | `github.com/{user}/fylio` |
| IPA compilé + lien de téléchargement | Artefact GitHub Actions |
| Guide Sideloadly | `docs/SIDELOADLY.md` |

---
**Prochaine étape : Phase 1 — Prototype visuel.** Découpage détaillé : design tokens → design system → écran par écran → navigation réelle → animations → QA Agent 7.
