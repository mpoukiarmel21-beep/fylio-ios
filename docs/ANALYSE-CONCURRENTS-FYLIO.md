# ANALYSE CONCURRENTS — SHAREit / Blip → enseignements pour Fylio
**Version : 1.0 · Date : 2026-09-20 · Source : documents d'analyse fournis (BLIP_PROTOCOL_ANALYSIS, SHAREIT_PROTOCOL_ANALYSIS, METADATA, strings, CODE_STRUCTURE, INDEX, OVERVIEW)**
**Règle : aucun code n'est copié — uniquement des enseignements d'architecture et de sécurité. Le code Fylio est écrit de A à Z.**

---

## 1. Ce que font les concurrents (constats)

| Sujet | SHAREit | Blip | LocalSend (référence open-source, citée dans l'analyse Blip) |
|---|---|---|---|
| Langage / framework (Windows) | C++ / Qt (23,8 Mo, PE 32-bit) | C# / .NET UWP XAML (815 Ko = Store Installer seulement) | Flutter + Rust |
| Découverte locale | TCP 2999 + 55283 ; UDP 55526 (broadcast, non confirmé) ; soft-AP avec SSID encodé | LAN (mécanisme propriétaire non public) | Multicast UDP brut `224.0.0.167:53317` (PAS mDNS) |
| Transfert | HTTP non chiffré sur port 2999 (`/download?...`) | mTLS / TLS 1.3, E2E | HTTPS REST auto-signé RSA-2048, protocole v2.2 versionné |
| Sans Wi-Fi commun | Hotspot (soft-AP) créé par le receveur | — | — |
| Distant via Internet | — (historique) | Direct si possible, sinon relais chiffré (type WebRTC/TURN) | V3 en préparation (WebRTC) |
| Auth | Aucune → vulnérabilités | Compte e-mail vérifié | PIN optionnel + certificat par appareil |
| Reprise après interruption | Partielle | Oui | Oui (endpoints versionnés) |
| Sécurité documentée | **10 CVE** : hotspot ouvert (CVE-2016-1492), mot de passe codé en dur `12345678` (CVE-2016-1491), téléchargement arbitraire de fichiers (`?filetype=raw&metadataid=/data/...`), canal en clair | Bonne sur le papier (mTLS 1.3, relay aveugle) | Bonne (TLS + PIN) |
| Séparation des canaux | Canal de commandes (en-tête 6 octets + JSON) + canal de téléchargement | — | REST : `/prepare-upload`, `/upload`, `/cancel`… |

**Point clé sur les binaires fournis :** le `.exe` Blip analysé est le **StoreInstaller** (téléchargeur Microsoft Store), pas l'application Blip elle-même — les strings concernent l'infrastructure Store (Download*, Deploy*, httpClient). Le `.exe` SHAREit est l'application Qt complète. Le cœur de la valeur d'analyse réside donc dans les documents de protocole, pas dans les sections `.bin`.

---

## 2. Ce que Fylio DOIT reprendre (bonnes pratiques)

| # | Pratique observée | Application Fylio |
|---|---|---|
| B1 | Découverte multicast UDP simple et robuste (LocalSend) | mDNS `_fylio._tcp` en principal **+ fallback broadcast/multicast UDP** pour réseaux bloquant mDNS (hôtels, entreprises) |
| B2 | Protocole **versionné** dès le départ (LocalSend v2.2, `/api/localsend/v2/...`) | Trames Fylio avec champ `proto: 1` → évolution sans casser les anciens clients |
| B3 | Flux en 2 temps : annonce → confirmation → transfert (LocalSend `prepare-upload`) | Handshake Fylio : `announce → confirm/refuse → transfer` (déjà prévu, confirmé par l'analyse) |
| B4 | Reprise après interruption + endpoints annulables | Manifeste bloc par bloc (SHA-256), reprise à l'octet, `cancel` propre |
| B5 | Mode soft-AP quand aucun Wi-Fi commun (SHAREit) | Prévu Phase 3 — MAIS corrigé (voir §3) |
| B6 | Relais chiffré aveugle pour le distant (Blip) | Phase 6 : direct si possible, relais aveugle sinon |
| B7 | Identité par appareil (certificat/clé par appareil, tous) | Paire Curve25519 dans le Keychain + numéro `Fylio-XXXX` |
| B8 | Séparation canal de commandes / canal de données (SHAREit) | Contrôle (JSON chiffré) sur une connexion, données en flux AEAD sur flux parallèles |

## 3. Ce que Fylio NE DOIT PAS reproduire (erreurs SHAREit — 10 CVE)

| # | Défaut SHAREit | Règle Fylio (bloquante en QA) |
|---|---|---|
| M1 | Hotspot Android **sans mot de passe** (CVE-2016-1492) | Hotspot Fylio TOUJOURS WPA2 avec mot de passe aléatoire fort, jamais ouvert |
| M2 | Mot de passe codé en dur `12345678` (CVE-2016-1491) | Aucun secret en dur ; mot de passe dérivé aléatoirement par session, éphémère |
| M3 | SSID qui encode des données (type appareil, mot de passe recalculable) | Le SSID ne transporte AUCUNE donnée exploitable ; les paramètres voyagent chiffrés après connexion |
| M4 | HTTP en clair sur port 2999 | Tout le trafic chiffré (TLS 1.3 / AEAD), zéro canal en clair, même en LAN |
| M5 | Téléchargement arbitraire de fichiers (`?metadataid=/data/...` → path traversal, fuite de fichiers système) | Liste blanche stricte des fichiers annoncés ; accès par ID de manifeste uniquement, jamais par chemin brut ; aucun accès aux fichiers hors sandbox |
| M6 | Aucune confirmation obligatoire du receveur | Confirmation obligatoire, sauf appareil explicitement marqué « de confiance » par l'utilisateur |
| M7 | Scan de ports / signature réseau identifiable | Fylio répond uniquement aux pairs authentifiés ; les ports ne sont pas des canons publics documentés |
| M8 | Pas de vérification d'intégrité | SHA-256 par bloc + global, rejet silencieux impossible |

## 4. Décisions architecturales mises à jour (amendent le plan D05/D06)

| ID | Amendement |
|----|------------|
| D05-bis | Découverte : mDNS `_fylio._tcp` **prioritaire**, + multicast UDP `239.x` (port dédié, TTL faible) en fallback automatique, + QR direct (aucune découverte réseau nécessaire). Aucune des deux méthodes ne dépend d'Internet. |
| D06-bis | Transport : TLS 1.3 (NWConnection) avec identités autosignées par appareil (empreinte épinglée au premier appairage — modèle mTLS Blip simplifié), OU AEAD maison sur TCP pour le mode QR (clé dérivée ECDH de la session). Aucun canal en clair, jamais. |
| D15 | Le protocole Fylio est **publique et versionné** dans `docs/PROTOCOLE-FYLIO-v1.md` (inspiration LocalSend : protocole documenté = interopérabilité future desktop/Android sans réécrire l'app iOS). |
| D16 | Handshake 3 phases : `announce (JSON chiffré, proto, appareil, fichiers, empreinte)` → `confirm | refuse | auto-accept(si confiance)` → `transfer (flux multi-blocs AEAD + SHA-256)`. |
| D17 | Sécurité hotspot (Phase 3) : SSID neutre `Fylio-XXXX`, WPA2, mot de passe aléatoire affiché + QR, expiration à la fin de session. Interdiction de tout encodage de données dans le SSID. |

## 5. Différenciateurs Fylio confirmés par l'analyse

1. **Sécurité par défaut là où SHAREit a échoué** (E2E, PIN/confirmation, aucune CVE héritée).
2. **Écosystème interne complet** (lecteurs, galerie, PDF annotable, vidéo→audio) — ni SHAREit ni Blip ne l'ont proprement.
3. **DA premium 2026** avec mascotte et objets animés de progression (personnalité produit — SHAREit est daté, Blip est sobre).
4. **Numéro Fylio visible** + avatars : identité lisible sans compte e-mail obligatoire (plus simple que Blip).
5. **Protocole versionné documenté** : base desktop Windows/macOS et Android sans réécrire le cœur.

---
**Intégré au plan : voir PLAN-ARCHITECTURE-FYLIO.md (§ décisions amendées D15→D17).**
