# outilVizMd

Lecteur natif macOS de documents Markdown locaux, en lecture seule. Il permet d’ouvrir des fichiers et dossiers, naviguer entre les documents, chercher dans le texte, personnaliser la lecture et suivre les sauvegardes faites dans un éditeur externe.

## Lancer dans Xcode

Ouvrir **`outilVizMd.xcodeproj`**, puis choisir le scheme **outilVizMd**, la destination **My Mac** et **⌘R**. Ouvrir le projet lui-même, et non le dossier dans une fenêtre « Files ». **⌘U** lance les tests ; **⌘6** affiche le navigateur de tests et **⌘9** les rapports d’exécution. Les fichiers générés de compilation sont dans Derived Data.

Xcode complet est requis (Swift ≥ 6.2). La cible du produit est macOS 14 ; l’exécution vérifiée actuellement est macOS 26.6.2 sur Apple Silicon. Les validations réelles macOS 14 et Intel restent à faire. La signature ad hoc convient au développement local ; aucune distribution notarifiée n’est préparée.

```sh
python3 scripts/update-xcode-project.py
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -resolvePackageDependencies -project outilVizMd.xcodeproj -scheme outilVizMd -derivedDataPath /tmp/outilVizMd-derived
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project outilVizMd.xcodeproj -scheme outilVizMd -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/outilVizMd-derived build
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project outilVizMd.xcodeproj -scheme outilVizMd -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/outilVizMd-derived test
open outilVizMd.xcodeproj
```

Le générateur met à jour les références des sources et ressources sans téléchargement ; le relancer après ajout d’un fichier. Swift Markdown et swift-cmark sont épinglés à 0.9.0 dans `Package.resolved`. Le premier téléchargement nécessite une connexion ; l’application construite utilise ses ressources locales.

## Utiliser le lecteur

- **⌘O** : ouvrir un fichier ; **⇧⌘O** : choisir un dossier. Les sous-dossiers se déplient à la demande. Les documents ouverts restent accessibles dans la barre latérale.
- **⌘F** : rechercher littéralement dans le document actif, sans distinction de casse, avec distinction des accents. **⌘G / ⇧⌘G** : résultat suivant/précédent ; **Échap** : fermer la recherche.
- **⌘,** : apparence système/claire/sombre, police locale, taille, espacement et couleurs. Seuls ces réglages globaux sont enregistrés dans Application Support du conteneur. Les documents et autorisations ne sont pas restaurés au lancement.
- **⌘R** : relire le document ; **⇧⌘R** : actualiser le dossier ; **⌘W** : fermer le document actif. Les modifications faites par un autre éditeur sont surveillées. Une erreur conserve le dernier aperçu avec un avertissement d’obsolescence.
- **Aide → Aide outilVizMd** et **Licences des composants** restent accessibles localement.

Documents UTF-8 avec ou sans BOM, fins de ligne LF/CRLF, jusqu’à **10 Mio inclus**. CommonMark et tableaux simples. Un fichier choisi seul n’autorise pas les images voisines : choisissez explicitement leur dossier. PNG/JPEG/GIF sont décodés, bornés et réencodés ; une image refusée possède une alternative textuelle.

Aucun éditeur, export, compte, serveur, télémétrie ou téléchargement automatique. Le HTML brut est inerte, JavaScript désactivé, les ressources Web bloquées. Seul un clic explicite HTTP(S) peut ouvrir le navigateur habituel. Le sandbox et le droit `user-selected.read-only` sont conservés. Le droit client réseau est nécessaire au démarrage des processus WebKit ; aucun droit serveur n’est accordé.

## Vérification

Les rapports et limites exactes sont dans [validation](specs/001-visualiser-markdown-local/validation/) et le [guide de validation](specs/001-visualiser-markdown-local/quickstart.md). Le passage fonctionnel final compte **59 réussites, zéro échec** (six benchmarks explicites ignorés avec ⌘U), avec ouverture/annulation, dossier/homonymes, recherche, trois relances des préférences et suivi externe dans la vraie interface macOS.

La sonde `python3 scripts/verify-webkit-network.py` lance un serveur loopback temporaire réservé aux tests, vérifie qu’il est joignable, puis exige zéro connexion pendant l’affichage passif. Le serveur n’est pas embarqué. Cette mesure ne certifie pas toutes les connexions des services système.

Les benchmarks explicites se lancent en Debug optimisé avec les réglages `SWIFT_OPTIMIZATION_LEVEL=-O ENABLE_HARDENED_RUNTIME=NO` et la variable d’environnement `TEST_RUNNER_OUTILVIZMD_PERFORMANCE=20` avant `xcodebuild` et le filtre `-only-testing:outilVizMdTests/ReadingPerformanceTests/testTwentyVisibleReadingMeasurements`. Ils attendent le chargement et une image WebKit visible ; les résultats JSON sont attachés au rapport XCTest. Les benchmarks ne sont pas lancés par défaut avec ⌘U. Les vingt séries de lecture, recherche, thèmes, bascule, modifications externes et annulation sont sous leurs seuils ; le délai du dossier utilisable et la mémoire complète app + WebKit restent à certifier.

Les contrôles avec réseau physiquement coupé, les plateformes non disponibles et le parcours avec cinq débutants doivent être réalisés et consignés avant de certifier la livraison. Ne pas assimiler les tests automatisés à ces validations manuelles.

## Organisation

SwiftUI/AppKit pour l’interface ; acteurs pour accès, analyse, rendu, recherche, surveillance et stockage. `Documents` gère les accès et générations ; `Navigation` la session et l’arbre ; `Markdown` l’adaptateur ; `Rendering` WebKit/HTML/ressources ; `Search` les occurrences ; `Themes` et `Preferences` les réglages contrôlés. Les tests utilisent des copies temporaires et comparent les octets sources. Les préférences UI de test utilisent un espace isolé.
