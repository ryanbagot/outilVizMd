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

## Installer dans Applications et au Bureau

La préparation locale nécessite Xcode complet et Python 3. Elle conserve l’image originale « Icône Markdown personnalisable en couches.png », embarque ses dix tailles d’icône et produit une Release arm64 + x86_64 signée ad hoc avec les droits existants. Les sorties sont accessibles via `build/local/` (lien vers un lot temporaire privé hors Bureau synchronisé, pour préserver la signature) ; la préparation n’installe rien.

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
python3 scripts/prepare-local-app.py --offline --package-cache /tmp/outilVizMd-derived/SourcePackages
build/local/install-local-app install --source build/local/outilVizMd.app --dry-run
build/local/install-local-app install --source build/local/outilVizMd.app
build/local/install-local-app status --json
```

Le chemin du cache est à adapter au Mac. Sans cache complet, effectuer une première préparation sans `--offline` (cache par défaut : `build/SourcePackages`), puis réutiliser ce cache. Le mode hors ligne échoue si les révisions verrouillées manquent ; aucun téléchargement n’y est autorisé.

L’installation de référence est **`/Applications/outilVizMd.app`**. Le Bureau reçoit un véritable alias Finder **outilVizMd – ouvrir**, sans deuxième copie. Double-cliquer sur l’un des deux accès présente le lecteur ; Xcode, Terminal et le projet ne sont plus nécessaires à l’usage quotidien. L’outil de préparation/installation n’est pas embarqué dans l’app.

Pour une mise à jour, quitter normalement l’app, préparer une nouvelle Release et exécuter :

```sh
build/local/install-local-app install --source build/local/outilVizMd.app --replace
```

Un produit identique n’est pas remplacé. Un produit différent exige `--replace`. Les documents, préférences et autres copies de développement ne sont pas modifiés. L’outil refuse une mise à jour si l’installation tourne, si un objet étranger occupe la destination ou si l’ancien alias ne peut être sécurisé. Aucune élévation de privilèges n’est déclenchée.

Supprimer uniquement l’alias laisse l’application et les documents intacts. Pour le recréer sans compiler ni fournir la source :

```sh
build/local/install-local-app alias
```

`--dry-run` simule sans écrire ; `status` inspecte sans lancer l’app. `--json` produit un seul objet sur stdout. Codes : **0** complet/simulation/inspection, **1** app utilisable mais alias ou nettoyage incomplet, **2** conflit/remplacement non autorisé, **3** app active/identité ambiguë, **4** source/manifeste/app invalide, **5** droits/espace/accès, **6** copie/commit/validation, **7** opération concurrente, **8** récupération nécessaire, **64** arguments invalides. La préparation utilise 4/5/6/64 pour ses erreurs.

En cas de conflit, inspecter l’objet puis le déplacer soi-même ; `--replace` ne l’écrase pas. Si seul le Bureau est indisponible, une première installation peut réussir partiellement : rétablir l’accès puis lancer `alias`. Après interruption ou retour arrière incomplet, `status` indique les dossiers privés `.outilVizMd-install-…` et leurs `receipt.json` ; conserver les sauvegardes, comparer les chemins/identités et restaurer manuellement seulement après inspection. Ne pas supprimer aveuglément ces dossiers. Le verrou `.outilVizMd-deployment.lock` est conservé pour coordonner les exécutions ; l’existence du fichier ne signifie pas qu’un processus détient le verrou.

Si une ancienne icône reste en cache, quitter/relancer l’app puis fermer/rouvrir la fenêtre Finder ; vérifier la cible du raccourci, la version et `Contents/Resources/AppIcon.icns`. Aucune purge globale, suppression de quarantaine ou désactivation de Gatekeeper n’est nécessaire à la procédure. La signature est destinée à ce Mac, sans promesse de distribution publique sur d’autres Macs.

Tests isolés : `python3 -m unittest discover -s scripts/tests` et `swift test --package-path tools/LocalDeployment`. Le harnais de lancement système est opt-in via `OUTILVIZMD_TEST_INSTALLED_APP=/Applications/outilVizMd.app`. Les preuves, plateformes réellement exécutées et contrôles restant à faire sont consignés dans [la validation de l’installation](specs/003-installer-app-icone/validation.md) ; une construction universelle ne certifie pas une exécution Intel ou macOS 14.

Validation de l’installation du 7 novembre 2026 : **95 tests automatisés réussis**, vingt accès Finder observés, app et alias installés. Les contrôles après redémarrage, en session sans projet/temporaires et sur les quatre surfaces d’icône restent détaillés dans le rapport 003 ; la recette complète n’est pas certifiée.
