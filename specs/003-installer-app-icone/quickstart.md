# Validation — installation et icône

Guide des commandes implémentées. Les résultats effectivement obtenus et les contrôles restant à faire sont dans [validation.md](validation.md). Voir [contrat CLI](contracts/deployment-cli.md) et [lancement/icône](contracts/launch-and-icon.md).

## Prérequis

Mac macOS 14+, Xcode complet compatible Swift 6.2 minimum (conception : Xcode 27.2), Python 3, image originale à la racine. Paquets du projet déjà en cache pour travailler hors ligne. Le dossier Applications doit être accessible en écriture au moment d’installer ; le Bureau doit être disponible pour une réussite complète. Aucune dépendance à ces outils après installation.

Depuis la racine du dépôt :

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
python3 -m unittest discover -s scripts/tests -p 'test_prepare_local_app.py'
swift test --package-path tools/LocalDeployment
python3 scripts/prepare-local-app.py --offline --package-cache /tmp/outilVizMd-derived/SourcePackages
build/local/install-local-app install --source build/local/outilVizMd.app --dry-run
```

Le chemin de cache montré correspond au cache de développement de ce Mac ; utiliser le cache local complet réel s’il diffère. Si aucun cache n’existe, faire une première préparation sans `--offline`, puis refaire hors ligne. Le mode offline doit échouer sans téléchargement si une dépendance manque.

Attendus : tests isolés sans modification des destinations réelles ; app universelle, manifeste et outil accessibles via `build/local/` (lien vers un lot temporaire privé hors du Bureau synchronisé) ; image originale identique ; simulation sans écriture. Vérifier par `codesign --verify --deep --strict build/local/outilVizMd.app`, `codesign -d --entitlements :- build/local/outilVizMd.app` et `plutil -p build/local/outilVizMd.app/Contents/Info.plist` la signature, les trois droits et l’icône déclarée. Conserver les résultats effectifs, y compris les échecs.

## Installation et usage

Cette étape écrit dans Applications et au Bureau. Ne pas la remplacer par une copie depuis DerivedData :

```sh
build/local/install-local-app install --source build/local/outilVizMd.app
build/local/install-local-app status --json
```

Attendu : `/Applications/outilVizMd.app` valide, un alias Bureau « outilVizMd – ouvrir » vers ce bundle, résultat complete. Si code 1, lire l’état réel et corriger le raccourci avant de valider le parcours complet. Si conflit/permission, suivre la récupération ci-dessous ; aucune élévation automatique.

Fermer Xcode et Terminal, ouvrir l’app par double-clic dans Applications puis au Bureau. Choisir et lire un Markdown local. Refaire dix fois par accès : inclure app quittée, déjà ouverte, lecteur réduit, lecteur fermé et seule aide/préférences visible. Attendu à chaque essai : lecteur utilisable, même version, pas de seconde instance indépendante de l’installation. Vérifier ouverture Cmd-O, navigation et apparences claire/sombre. Consigner les 20 résultats et le chemin/version du processus observé par le harnais de test.

Comparer Finder, alias Bureau, Dock et Cmd-Tab avec l’original, aux tailles disponibles et dans les deux apparences. L’illustration reste identifiable, non étirée/non coupée, sans icône générique. Un contrôle des ressources ne remplace pas cette inspection visuelle.

## Répétition et mise à jour

Relever les empreintes des documents de référence et du fichier de préférences existant, et les préférences affichées. Quitter normalement le lecteur avant toute mise à jour. Exécuter trois fois l’installation du même produit :

```sh
build/local/install-local-app install --source build/local/outilVizMd.app
```

Attendu : aucun remplacement de bundle identique, une seule installation canonique et un seul alias au nom attendu. Préparer ensuite une autre Release valide dont le contenu/version est identifiable. Sans `--replace`, le remplacement est refusé ; puis :

```sh
build/local/install-local-app install --source build/local/outilVizMd.app --replace
build/local/install-local-app status --json
```

Attendu : les deux accès ouvrent la nouvelle version ; documents et préférences de référence conservés. Le test automatisé d’alias doit laisser l’ancien bundle présent en sauvegarde pendant la résolution et vérifier que l’alias vise le nouveau chemin ET sa nouvelle identité de fichier. Supprimer ensuite seulement l’alias via Finder : app et documents restent ; réparer par :

```sh
build/local/install-local-app alias
```

## Erreurs et récupération

Exécuter les cas destructifs uniquement dans les dossiers isolés des tests, avec injection de pannes. Ne pas modifier les permissions d’Applications, remplir le disque ou remplacer un objet personnel pour simuler un échec.

| Cas à vérifier | Attendu / récupération |
|---|---|
| Image absente, différente, illisible ou invalide | Préparation refusée ; rétablir l’original identifié, ne pas accepter une icône générique. |
| Cache absent hors ligne | Échec sans téléchargement ; préparer le cache puis réessayer. |
| Permissions, manque d’espace, copie/commit refusé | Ancienne app conservée ou retour arrière contrôlé ; corriger les droits/espace avec le propriétaire puis relancer. |
| Fichier/répertoire/symlink/alias étranger au nom prévu | Élément inchangé ; déplacer/renommer soi-même le conflit après inspection. Jamais d’écrasement par `--replace`. |
| Installation canonique en cours d’exécution | Mise à jour refusée ; quitter par Cmd-Q puis réessayer. |
| Bureau inaccessible à la première installation | App utilisable, résultat partiel ; rendre le Bureau disponible puis commande alias. |
| Bureau invérifiable avant mise à jour | Refus avant commit ; rétablir l’accès et réessayer. |
| Création d’alias échouée après commit | Nouvelle app valide, état du raccourci exact, résultat partiel ; réparer par alias. |
| Validation post-commit échouée | Ancienne app et alias restaurés ; aucun succès de mise à jour annoncé. |
| Retour arrière/nettoyage/interruption | Objets de récupération conservés et chemins indiqués ; lancer status, inspecter les identités avant restauration manuelle ; ne rien supprimer aveuglément. |
| Conflit apparu pendant la transaction | Pas d’écrasement du nouvel objet inconnu ; récupération explicite, sauvegarde conservée si nécessaire. |
| Ancienne icône affichée | Quitter/relancer, rouvrir Finder ; vérifier version, cible et ICNS. Pas de purge globale ou désactivation de protection. |

Vérifier aussi accès simultanés (verrou), identité de processus ambiguë, alias cassé et réparation répétée. Les conflits inconnus doivent rester byte-identiques dans tous les cas.

## Autonomie et non-régression

Réseau désactivé, après redémarrage, refaire les deux lancements et lire un document local avec image autorisée. Pour prouver l’indépendance du projet et des temporaires sans déplacer le dépôt de travail ou effacer des données personnelles, utiliser une session de test dédiée où seule l’app installée et des documents de recette sont disponibles ; les dossiers source/préparation n’y sont pas accessibles. L’icône reste disponible, aucun outil de construction ne démarre.

Exécuter les tests fonctionnels Xcode du lecteur et les régressions de réouverture concernés :

```sh
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -quiet -project outilVizMd.xcodeproj -scheme outilVizMd -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/outilVizMd-tests-003 -clonedSourcePackagesDirPath /tmp/outilVizMd-derived/SourcePackages -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile test
```

Adapter l’architecture à l’hôte, consigner les mesures optionnelles ignorées selon la configuration existante. Comparer les octets des documents/préférences de référence et l’empreinte originale indiquée dans [data-model.md](data-model.md). Reporter OS, architecture, version construite, tests passés/échoués/non exécutés, 20 lancements, redémarrage, quatre surfaces visuelles et tous les cas d’erreur. Une compilation x86_64 seule ne valide pas une exécution Intel ; macOS 14 reste à tester sur un environnement correspondant. Un critère essentiel échoué bloque la livraison.
