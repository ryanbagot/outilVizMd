# Vérification de l’outillage — 2026-11-06

T001 : vérification effectuée, sans modification de la sélection globale des outils.

| Contrôle | Résultat observé |
|----------|------------------|
| Système | macOS 26.6.2, build 25G83, arm64 |
| Sélection globale `xcode-select -p` | `/Library/Developer/CommandLineTools` |
| `xcodebuild -version` sans configuration | Échec : les Command Line Tools ne fournissent pas Xcode complet |
| Xcode présent | `/Applications/Xcode.app/Contents/Developer` |
| Xcode avec `DEVELOPER_DIR` | Xcode 27.2, build 27B52 |
| Compilateur avec `DEVELOPER_DIR` | Swift 6.4.2, cible arm64-apple-macosx26.0 |
| SDK des Command Line Tools | macOS 26.5 |
| Identités de signature de développement | 0 identité valide ; signature ad hoc locale prévue pour le squelette |

Commandes de projet : préfixer les commandes `xcodebuild`/`xcrun` par
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` lorsque la sélection globale reste
sur les Command Line Tools. Ce réglage ne vaut que pour le processus lancé.

La version minimale du produit reste macOS 14. Ce poste ne constitue pas une validation
d’exécution sur macOS 14 ni sur Intel. Les résultats de résolution, build, tests et signature
du bundle seront ajoutés après leur exécution ; la présence des outils ne les certifie pas.

T002 : projet et scheme partagés créés. `plutil -lint` valide le projet et les entitlements.
`xcodebuild -list -project outilVizMd.xcodeproj -scheme outilVizMd -derivedDataPath
/tmp/outilVizMd-derived` avec le `DEVELOPER_DIR` ci-dessus réussit et liste les trois cibles
`outilVizMd`, `outilVizMdTests`, `outilVizMdUITests`, Debug/Release et le scheme `outilVizMd`.
Les services et caches Xcode nécessitent l’exécution hors du bac à sable de l’agent ;
le sandbox de l’application reste activé.

T003 : résolution et compilation Debug arm64 réussies (code de sortie 0, `BUILD SUCCEEDED`).
Le fichier `Package.resolved` contient swift-markdown 0.9.0 (25cb61d3482054b09ae76ca4f281b1bfe7fe5a43)
et swift-cmark 0.9.0 (08ddb528923cc1a6527e02b7a1aee9e516ca749a). Le plugin documentaire cité
comme possibilité transitive dans la recherche n’apparaît pas dans ce graphe Xcode résolu.
Le SDK réellement utilisé par Xcode est macOS 27.2 ; le SDK 26.5 ci-dessus est celui des CLT.
Le bundle est signé localement ad hoc. Xcode signale que le hardened runtime est désactivé
avec cette signature ; l’App Sandbox et ses entitlements restent à vérifier sur le bundle signé.

T004–T006 : fixtures et supports créés, README rédigé. `sips` identifie PNG/JPEG 2×2 et GIF 1×1.
La copie de `Fixtures` dans les ressources conserve les sous-dossiers et les noms homonymes.
`xcodebuild -quiet … -destination 'platform=macOS,arch=arm64' build-for-testing` réussit
(code de sortie 0) après ajout des supports. Aucun test comportemental n’est encore exécuté.

Attention à la distinction des produits : Xcode ajoute automatiquement à l’hôte de tests
des exceptions de lecture et de communication avec testmanagerd lors de `build-for-testing`.
L’inspection de ce bundle ne certifie pas les droits du produit normal. Les vérifications
de sécurité du produit doivent utiliser un build ordinaire distinct et ses entitlements signés,
sans réutiliser comme preuve de sandbox le bundle instrumenté pour XCTest.

## Correctif WebKit après le diagnostic initial

Les droits décrits plus haut sont ceux du produit avant correction. Le droit client
`com.apple.security.network.client` est requis au démarrage des services WebKit ; il est
maintenant ajouté au sandbox et à la lecture seule, sans droit serveur ni exception globale.
Le build ordinaire signé est vérifié avec ces quatre clés, get-task-allow Debug inclus.
Les 12 tests actuels passent sur macOS 26.6.2 ; détails, sonde passive et limite macOS 14
dans `webkit-feasibility.md`.
