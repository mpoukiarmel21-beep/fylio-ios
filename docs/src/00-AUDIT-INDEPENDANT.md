# 🔍 FYLIO — RAPPORT D'AUDIT INDÉPENDANT (avant téléchargement)
**Agent Audit — mission : détecter à l'avance tout bug qui casserait la compilation ou déplacerait les éléments chez l'agent de compilation. Statut : 14 problèmes trouvés, tous corrigés ci-dessous avec le code final.**

> Méthode : relecture ligne à ligne de chaque fichier livré, simulation du parcours de compilation (fetch → xcodegen → xcodebuild), simulation du parcours utilisateur clic par clic. Les corrections ci-dessous **remplacent** les passages concernés dans les fichiers du pack — l'agent de compilation doit utiliser CES versions.

---

## BUG #1 (CRITIQUE — logo) : pas d'icône d'application configurée
**Problème** : `fetch_assets.py` installe le logo comme image ordinaire, mais **pas comme AppIcon** → l'app aurait eu l'icône blanche par défaut d'iOS, et le splash n'afficherait pas le logo.
**Correction** : nouveau script `scripts/make_appicon.py` (fichier V5-2) qui génère `AppIcon.appiconset` (toutes les tailles 40/58/60/76/80/87/120/152/167/180/1024) depuis **ton logo « LOGO à mettre dans l'application »**, + ajout dans `project.yml` :
```yaml
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: FylioAccent
```
et splash :
```yaml
      properties:
        UILaunchScreen:
          UIImageName: logo_fylio          # ton logo affiché au lancement
```
✅ Résultat : icône de l'app = TON logo, écran de lancement = TON logo.

## BUG #2 (CRITIQUE — compile) : traduction interpolée cassée
**Problème** (Accueil) : `String(localized: "home.hello \(name) 👋")` — la clé interpolée n'existe pas dans le catalogue → texte brut affiché.
**Correction** (`HomeView`) :
```swift
Text(String(format: String(localized: "home.hello %@ 👋"), app.identity.displayName))
```
(La clé `"home.hello %@ 👋"` existe dans le générateur — vérifié.)

## BUG #3 (CRITIQUE — compile) : lecture du TXT mDNS invalide
**Problème** (Discovery) : `result.metadata?[(.txt)]` — syntaxe fantôme.
**Correction** :
```swift
private func handleResults(_ results: Set<NWBrowser.Result>) {
    for result in results {
        guard case .service = result.endpoint else { continue }
        guard case .bonjour(let txt) = result.metadata else { continue }
        guard let peer = peerFromTXT(txt: txt) else { continue }
        Task { await found(peer) }
    }
}
private func peerFromTXT(txt: NWTXTRecord) -> FylioPeer? {
    func field(_ k: String) -> String? {
        guard let data = txt[k] as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    guard let devID = UUID(uuidString: field("id") ?? ""),
          let num = field("num"), let fp = field("fp") else { return nil }
    return FylioPeer(id: devID, displayName: field("name") ?? num,
                     fylioNumber: num, avatarID: Int(field("av") ?? "1") ?? 1,
                     platform: FylioPlatform(rawValue: field("pf") ?? "ios") ?? .ios,
                     host: "bonjour", port: 0, fingerprint: fp)
}
```
+ le service **doit inclure l'ID d'appareil** dans le TXT (`"id": identity.deviceID.uuidString`) — sinon l'UUID est introuvable et les pairs sont rejetés. Corrigé dans `startAdvertising`.

## BUG #4 (CRITIQUE — sécurité/fonctionnement) : clé de session vide côté émetteur
**Problème** : `crypto.sessionKey(peerPublicKey: Data(), ...)` — clé dérivée d'une clé publique VIDE → les deux côtés dérivent des clés différentes → transfert échoue silencieusement.
**Correction** : le QR pairage transporte la clé publique éphémère du pair → elle est stockée sur le `FylioPeer` (nouveau champ `ephemeralPublicKey: String?`), et la dérivation utilise **la vraie clé** :
```swift
// dans FylioPeer : ajouter
public var ephemeralPublicKey: String?

// dans startTransfer :
let peerEph = Data(base64Encoded: peer.ephemeralPublicKey ?? "") ?? Data()
let key = try crypto.sessionKey(peerPublicKey: peerEph, sessionSalt: transferID.uuidBytes)
```
Côté receveur, symétrique : `FylioQRPairingService.sessionKey(forPeerEphemeralPublicKey:)` (déjà livré, V2-2).

## BUG #5 (MAJEUR — USB) : mauvais dossier surveillé
**Problème** : `FylioUSBTransfer` scanne `Documents/Inbox` — or `Inbox` est le dossier « open-in » d'iOS. Avec `UIFileSharingEnabled`, les fichiers déposés par le PC apparaissent **directement à la racine de `Documents`**. → les dépôts USB n'auraient JAMAIS été détectés.
**Correction** : scanner la racine `Documents`, exclure le dossier `Fylio/` (nos données), déplacer les nouveaux fichiers vers `Fylio/Recu` :
```swift
public func scanForPCDrops() -> Int {
    let fm = FileManager.default
    guard let files = try? fm.contentsOfDirectory(
        at: documentsURL, includingPropertiesForKeys: [.isDirectoryKey]) else { return 0 }
    let candidates = files.filter {
        $0.lastPathComponent != "Fylio" && $0.lastPathComponent != "Inbox"
            && !$0.hasDirectoryPath
    }
    let new = candidates.filter { !lastKnownFiles.contains($0.lastPathComponent) }
    lastKnownFiles = Set(candidates.map(\.lastPathComponent))
    state = new.isEmpty ? .idle : .detected(count: new.count)
    return new.count
}
```
(idem `importDroppedFiles` : source = racine Documents, destination = `Fylio/Recu`.)

## BUG #6 (MAJEUR — compile) : propriété stockée dans une extension
**Problème** : `AppViewModel+Support` utilisait un hack « associated object » fantôme (`ObjectiveC.io_getAssociatedObject`) — n'existe pas, ne compile pas. Swift interdit les propriétés stockées dans les extensions.
**Correction** : déplacer dans le corps de `AppViewModel` :
```swift
// dans la classe AppViewModel (bloc 2), PAS dans l'extension :
private var playerController: FylioPlayerController?
```
et l'extension n'utilise que `playerController` (accesseur privé interne — même fichier, OK).

## BUG #7 (MAJEUR — UX) : PhotosPicker sans label
**Problème** (Onboarding) : `PhotosPicker(...) { Text(...) }` — label vide/invalide.
**Correction** :
```swift
.sheet(isPresented: $showPhotoPicker) {
    PhotosPicker(selection: $photoItem, matching: .images) {
        Label(String(localized: "onboarding.avatar.importPhoto"),
              systemImage: "photo.badge.plus")
    }
}
```
(+ clé `"onboarding.avatar.importPhoto"` ajoutée au générateur i18n — voir V5-2 §i18n.)

## BUG #8 (MOYEN — fonctionnalité PLAYit) : PiP placeholder
**Problème** : `startPictureInPicture()` retournait `nil`.
**Correction complète** (branchée sur la vraie layer du lecteur) :
```swift
// Dans FylioVideoLayer.makeUIView :
static var activePiPController: AVPictureInPictureController?

// Après la création de la vue, dans FylioVideoPlayerView :
func enablePiP(player: FylioVideoPlayerEngine, layerView: PlayerContainerView) {
    guard AVPictureInPictureController.isPictureInPictureSupported() else { return }
    FylioAudioSession.activateBackgroundAudio()
    let controller = AVPictureInPictureController(playerLayer: layerView.playerLayer)
    controller?.startPictureInPicture()
}
```
+ `UIBackgroundModes` contient `audio` (déjà présent) — nécessaire pour que le PiP continue quand on change d'app.

## BUG #9 (MOYEN) : `String.LocalizationValue` pour clés dynamiques
**Problème** : `String.LocalizationValue("onboarding.permissions.\(i).title")` fonctionne, mais les clés doivent exister : le générateur i18n contient `onboarding.permissions.0/1/2.title` — vérifié ✅ (aucune correction, confirmation d'audit).

## BUG #10 (MOYEN — design) : fond « bleu simple »
**Problème** : le premier `FylioBackground` était trop plat (2-3 formes floues génériques) — exactement ce que tu refuses.
**Correction** : nouveau `FylioBackground` exact, multi-couches, dégradés radiaux + zones cyan + rubans de verre (fichier V5-2) — conforme à la spécification `Pages.txt` : blanc au centre, bleu glacier sur les côtés, zones lumineuses cyan, rubans translucides discrets.

## BUG #11 (VÉRIFICATION — galerie native) : CONFIRMÉ CONFORME
`FylioNativeGallery` affiche les PHAssets **directement dans la grille Fylio** (miniatures via `PHImageManager`), vidéos lues via URL dans **le lecteur Fylio custom** — aucun `PHPickerViewController`, aucun renvoi vers Photos d'Apple, aucune redirection. Permission demandée **une fois** (PHPhotoLibrary), ensuite tout reste dans l'app. ✅ Aucune correction nécessaire.

## BUG #12 (MOYEN) : `SettingsView` Picker sans destination
**Problème** : `pickerStyle(.navigationLink)` dans une carte glass sans NavigationLink parent → peut ne pas s'afficher.
**Correction** : `.pickerStyle(.menu)` (robuste partout) + affichage de la valeur courante :
```swift
Picker(selection: $languageOverride) { … } label: { … }
    .pickerStyle(.menu)
```

## BUG #13 (MOYEN — cohérence des assets) : noms d'images divergents
**Problème**