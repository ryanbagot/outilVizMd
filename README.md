# outilVizMd

Lecteur natif macOS de documents Markdown locaux. L’implémentation suit les tâches de
`specs/001-visualiser-markdown-local/tasks.md` ; le projet courant est un squelette de préparation,
pas encore un lecteur utilisable.

## Prérequis

macOS 14 minimum pour le produit prévu, Apple Silicon et Intel. Pour compiler : Xcode complet
avec Swift ≥ 6.2, une connexion pour la première résolution SwiftPM, puis le cache des paquets.
Le projet utilise le mode Swift 5 et la vérification complète de concurrence.
Swift Markdown est épinglé à 0.9.0 ; `Package.resolved` conserve le graphe réellement résolu.

Sur ce poste, Xcode est installé dans `/Applications/Xcode.app` mais les outils globaux pointent
sur les Command Line Tools. Les commandes suivantes sélectionnent Xcode pour le processus seulement.
La signature ad hoc permet le développement local ; elle ne prépare pas une distribution notarifiée.

## Compiler et tester

```sh
python3 scripts/update-xcode-project.py
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -resolvePackageDependencies -project outilVizMd.xcodeproj -scheme outilVizMd -derivedDataPath /tmp/outilVizMd-derived
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project outilVizMd.xcodeproj -scheme outilVizMd -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/outilVizMd-derived build
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project outilVizMd.xcodeproj -scheme outilVizMd -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/outilVizMd-derived test
open outilVizMd.xcodeproj
```

Dans Xcode, choisir le scheme `outilVizMd`, My Mac, puis Cmd+R. Sur Intel, remplacer `arch=arm64`
par `arch=x86_64`. Le script Python ne télécharge rien ; il met à jour les références des sources
et ressources existantes dans le projet et son scheme partagé. Le relancer après ajout d’un fichier.

Ouvrir le fichier `outilVizMd.xcodeproj` lui-même, pas seulement le dossier du projet dans une
fenêtre « Files ». Le bon projet affiche le scheme `outilVizMd`, la destination `My Mac` et le
bouton ▶︎ dans sa barre d’outils. Cmd+U lance les tests ; le navigateur Tests affiche leurs résultats.

## Organisation

`outilVizMd/App` contient composition et présentation ; `Documents` gère lectures et générations ;
`Navigation` les documents ouverts et l’arbre ; `Markdown` l’adaptateur du moteur ; `Rendering`
WebKit/HTML/ressources ; `Search` les occurrences ; `Themes` les styles ; `Preferences` le JSON ;
`Resources` les fichiers embarqués. Ces dossiers seront alimentés selon les phases du plan.
`outilVizMdTests` accueille les tests et leurs fixtures, `outilVizMdUITests` les parcours XCUITest.

## Limites du MVP prévu

Lecture seule, documents UTF-8 avec ou sans BOM jusqu’à 10 Mio inclus. Aucun éditeur, export,
serveur, compte, télémétrie ou chargement automatique de ressources distantes. Un fichier choisi
seul n’autorise pas ses images voisines : leur dossier doit être choisi explicitement.
Les autorisations et documents ouverts restent temporaires ; seules les préférences sont persistées.
Les liens externes HTTP(S) ne s’ouvrent qu’après un clic explicite dans le navigateur système.

## État vérifié

La résolution SwiftPM et la compilation Debug arm64 des fondations ont réussi le 2026-11-06 sur
macOS 26.6.2 avec Xcode 27.2/Swift 6.4.2. Les **12 tests actuels passent**, y compris chargement
WebKit local, fragments et restauration de position. Le droit `com.apple.security.network.client`
est requis pour démarrer les services WebKit ; JS reste désactivé et CSP/règles WebKit bloquent
les chargements distants. Une sonde loopback mesure zéro connexion pendant l’affichage passif
du corpus local testé. Reproduction : `python3 scripts/verify-webkit-network.py`.
Le sandbox et la lecture seule des documents sont conservés, sans droit réseau serveur.
La cible UI, encore sans test, est exclue de l’exécution ; le générateur l’active dès le premier
`func test…` dans `outilVizMdUITests`. Cmd+U exécute actuellement les 12 tests disponibles.
T001–T013 sont terminées ; T014 reste non cochée pour la validation réelle macOS 14.
Les parcours utilisateur, macOS 14/Intel, la sécurité complète et les performances restent à valider.
Consulter `specs/001-visualiser-markdown-local/validation/toolchain.md` et le guide
`specs/001-visualiser-markdown-local/quickstart.md` pour les preuves et contrôles encore attendus.
