# Guide de compilation et de validation — outilVizMd

Ce guide décrit la validation de l’application **après implémentation**. Au 2026-11-06, T001–T013
sont terminées : projet Xcode, fixtures, supports et fondations créés ; compilation Debug arm64
réussie. Les 12 tests actuels passent après ajout du droit client requis au démarrage de WebKit.
T014 est validée sur le poste courant, mais reste non cochée pour sa vérification réelle macOS 14.
Voir `validation/webkit-feasibility.md` pour les preuves et la portée des essais réseau.
Les scénarios complets ci-dessous restent à exécuter après leur implémentation.

## Prérequis

- Xcode complet avec un compilateur Swift 6.2 ou ultérieur ; accepter sa licence et installer
  ses composants via l’interface Xcode. Sélectionner cette installation dans Settings → Locations
  → Command Line Tools. Les Command Line Tools seuls ne suffisent pas.
- macOS compatible avec cette version de Xcode pour construire ; cible de l’app macOS 14 minimum.
  Vérifier aussi le résultat sur un Mac macOS 14 et les architectures annoncées avant livraison.
- Pour la première résolution SwiftPM : accès aux dépôts du graphe de dépendances. Ensuite conserver
  Package.resolved et le cache ; l’app construite n’a aucune dépendance réseau à l’exécution.
- Signature locale configurée dans Xcode ; App Sandbox actif, user-selected.read-only seul droit
  sur les documents. Le droit réseau client est nécessaire au démarrage de WebKit, sans droit
  serveur. Les connexions automatiques restent interdites et contrôlées par le rendu, CSP,
  règles et politique native. Ne pas désactiver le sandbox pour faire passer les tests.

État actualisé le 2026-11-06 : Xcode 27.2 et Swift 6.4.2 disponibles dans `/Applications/Xcode.app`.
La sélection globale pointe encore vers les Command Line Tools ; utiliser `DEVELOPER_DIR` comme
ci-dessous sans modifier cette sélection. La signature ad hoc convient au développement local.
La validation d’exécution macOS 14 et Intel reste à faire.

## Compiler, tester et lancer

Depuis la racine du dépôt, après création du projet et de son scheme partagé :

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcode-select -p
xcodebuild -version
xcrun swift --version
xcodebuild -resolvePackageDependencies -project outilVizMd.xcodeproj -scheme outilVizMd
xcodebuild -list -project outilVizMd.xcodeproj
xcodebuild -project outilVizMd.xcodeproj -scheme outilVizMd -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/outilVizMd-derived build
xcodebuild -project outilVizMd.xcodeproj -scheme outilVizMd -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/outilVizMd-derived test
open outilVizMd.xcodeproj
```

Résultats attendus à terme : cibles outilVizMd, outilVizMdTests et outilVizMdUITests ; build et tests
réussis. Les 12 tests disponibles passent ; T014 attend encore une exécution sur macOS 14.
La cible UI vide n’est pas lancée ; elle sera activée automatiquement avec son premier test.
Dans Xcode, choisir My Mac puis Product → Run (Cmd+R). Les prompts système de sélection
font partie du parcours normal. Ne pas faire pointer les tests vers les documents personnels.
Relancer build/test réseau déconnecté une fois les dépendances mises en cache.

Pour la sonde locale des sous-ressources : `python3 scripts/verify-webkit-network.py`.
Le script démarre temporairement un serveur sur 127.0.0.1:49183, vérifie qu’il est joignable,
exécute le test d’affichage passif, exige zéro connexion, puis ferme le serveur. Il ne fait
pas partie du produit livré et ne certifie pas encore tout le corpus de sécurité US6.

## Corpus de validation

Pendant l’implémentation, créer sous outilVizMdTests/Fixtures :

- Un document CommonMark avec titres 1–6, emphase, listes imbriquées, citations, code clôturé et
  indenté, caractères spéciaux, Unicode et fins de ligne différentes ; tableaux simples et ancres.
- Trois documents navigables, dont deux homonymes en sous-dossiers ; PNG/JPEG/GIF locaux, dossier
  vide et liens entre documents. Un fichier choisi seul doit échouer à lire ses images voisines
  avant sélection explicite du dossier.
- Fichiers vide, invalide UTF-8, de 10 Mio exactement et de 10 Mio + 1 octet, fichier supprimé et
  accès révoqué. Simuler les erreurs de permissions avec un adaptateur de test si nécessaire.
- Corpus malveillant : HTML actif, événements, javascript:, data:, file:, iframe, styles et images
  distantes, traversées encodées, symlinks sortants et changés pendant la lecture, jetons périmés.
- Documents de 1 et 10 Mio avec au plus 5 Mio d’images pour les mesures, requêtes nombreuses et
  traversant des nœuds inline ; dossier de 1 000 entrées. Conserver leurs empreintes et tailles.

Les tests travaillent sur des copies temporaires. Les comparaisons de source sont effectuées avant
et après les seules actions du lecteur ; les modifications externes intentionnelles sont comparées
à leur nouvelle version attendue, sans les attribuer au lecteur.

## Scénarios de bout en bout

| Parcours | Manipulation | Résultat attendu |
|----------|--------------|------------------|
| Première lecture | Lancer hors ligne, annuler une ouverture puis ouvrir le corpus | Accueil préservé après annulation ; structure correcte, fichier inchangé |
| Navigation | Choisir dossier, ouvrir trois fichiers, revenir au premier, fermer actif | Chemins distinguables, pas de doublon, position conservée, aucune suppression |
| Ressources | Ouvrir fichier seul puis autoriser son dossier ; tester ressources hors racine | Refus initial lisible, image admise après choix, aucun accès aux fichiers hors périmètre |
| Recherche | Cmd+F, requête avec casse variée, accents, caractères spéciaux, plusieurs nœuds | Total exact, repères cohérents, boucle, zéro/effacement corrects, pas d’exécution |
| Préférences | Modifier chaque réglage, quitter/relancer trois fois, réinitialiser | Choix conservés, palettes distinctes, contraste signalé, reset durable |
| Suivi externe | Écriture directe puis remplacement atomique, dix sauvegardes rapides | Dernière version seulement, délais SC-004, position valide et recherche recalculée |
| Indisponibilité | Supprimer ou déplacer le fichier puis recréer au même emplacement | Aperçu signalé obsolète, récupération sans recréation par le lecteur |
| Sécurité | Corpus malveillant avec réseau disponible, sans clic puis clic HTTP(S) | Aucun accès/chargement automatique ; lien validé ouvert seulement dans le navigateur |
| Accessibilité | Parcours au clavier puis VoiceOver, clair et sombre | Actions nommées, focus utilisable, états compréhensibles |

Pour la préservation, les tests comparent les octets, l’empreinte et l’emplacement avant/après
consultation, recherche, thèmes et fermeture. Pour le réseau, instrumenter les demandes reçues
par la couche WebKit et un serveur de test local utilisé uniquement par les tests, puis observer
les tentatives de connexion des processus app/WebKit ; une capture réseau seule ne prouve pas
qu’aucune tentative n’a été faite. Les tests vérifient le blocage avant envoi et le refus des
ressources. Le serveur n’est jamais livré ni requis par l’application.

## Performance et critères de sortie

Consigner Mac, mémoire, macOS, Xcode, build, tailles et empreintes du corpus. Les mesures respectent
[SC-001 à SC-008](spec.md#measurable-outcomes) : vingt répétitions, dix-neuf sous chaque seuil.
Mesurer de l’action utilisateur au rendu utilisable, pas seulement le temps du parseur.

Vérifier aperçu, recherche, bascule, thème, rafraîchissement et dossier. Observer aussi la mémoire
avec dix documents ouverts et sa libération après fermeture, la survie aux erreurs WebKit et les
requêtes de recherche denses. Faire le parcours d’initiation avec cinq débutants : quatre au moins
réussissent dans les cinq minutes avec l’aide intégrée seule. Ne pas déclarer ce critère validé
sur la seule base des tests automatisés.

Avant livraison : compilation et tests réussis, critères de sécurité et préservation tous satisfaits,
mesures consignées, tests sur macOS 14 effectués, aide et README en français à jour et notices de
licence embarquées. Échec essentiel → corriger avant livraison, sans désactiver les protections.

Références : [modèle](data-model.md), [composants](contracts/composants.md),
[interface et ressources](contracts/interface-et-ressources.md), [décisions](research.md).
