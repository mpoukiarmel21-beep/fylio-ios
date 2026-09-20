# PATCH — Corrections de sécurité sur `AppViewModel` (bloc 2, version 84e7aebb)

## Défaut 1 (CRITIQUE) : la clé privée éphémère était mise dans le payload QR

**❌ À supprimer dans `qrPairingPayload()` :**
```swift
"eph_priv": privateKey.rawRepresentation.base64EncodedString(),
```

**✅ Version corrigée (la clé privée reste en mémoire locale, JAMAIS dans le QR) :**
```swift
func qrPairingPayload() -> String {
    let privateKey = qrEphemeral ?? FylioCrypto.ephemeralPair().0
    qrEphemeral = privateKey
    let payload: [String: String] = [
        "proto": "1",
        "num": identity.fylioNumber,
        "name": identity.displayName,
        "fp": identity.publicKeyFingerprint,
        "eph": privateKey.publicKey.rawRepresentation.base64EncodedString(), // CLÉ PUBLIQUE uniquement
        "port": String(FylioDefaults.listenPort),
        "ip": FylioDefaults.localIPAddress ?? ""
    ]
    return String(data: (try? JSONEncoder().encode(payload)) ?? Data(), encoding: .utf8) ?? "{}"
}
```
**Règle respectée :** le QR ne contient que des données publiques (numéro, nom, empreinte, clé publique éphémère, IP:port). La clé privée éphémère reste en mémoire de l'appareil émetteur du QR et sert à dériver le secret partagé ECDH quand l'autre appareil se connecte. Aucune donnée sensible en clair.

## Défaut 2 : typo `FylioIPeer`

**❌** `func deleteDevice(_ peer: FylioIPeer) { forgetDevice(peer) }`
**✅** `func deleteDevice(_ peer: FylioPeer) { forgetDevice(peer) }`

## Défaut 3 (bonus, signalé) : auto-accept V1

Dans `handleIncoming`, la closure doit afficher la demande et attendre la décision utilisateur (déjà implémenté via `addIncomingRequest` + `respondIncoming`) — le transfert ne démarre **jamais** sans acceptation, sauf appareil de confiance (V2).
