# Guide de compilation et de validation — outilVizMd

Ce guide décrit la validation de l’application **après implémentation**. Le présent workflow ne
crée que les documents de conception : le projet Xcode, les fixtures et les tests cités ci-dessous
restent à créer. Aucune commande de compilation ou test de ce guide n’a réussi à ce stade.

## Prérequis

- Xcode complet avec un compilateur Swift 6.2 ou ultérieur ; accepter sa licence et installer
  ses composants via l’interface Xcode. Sélectionner cette installation dans Settings → Locations
  → Command Line Tools. Les Command Line Tools seuls ne suffisent pas.
- macOS compatible avec cette version de Xcode pour construire ; cible de l’app macOS 14 minimum.
  Vérifier aussi le résultat sur un Mac macOS 14 et les architectures annoncées avant livraison.
- Pour la première résolution SwiftPM : accès aux dépôts du graphe de dépendances. Ensuite conserver
  Package.resolved et le cache ; l’app construite n’a aucune dépendance réseau à l’exécution.
- Signature locale configurée dans Xcode ; App Sandbox actif, user-selected.read-only seul droit
  sur les documents. Ne pas désactiver le sandbox pour faire passer les tests.

État observé le 2026-11-06 sur ce poste : Swift 6.3.3 via Command Line Tools, mais pas de Xcode
aux emplacements standards ; xcodebuild demande une installation complète. Ce prérequis reste
à satisfaire pour la phase d’implémentation, sans bloquer l’usage des documents de planification.

## Compiler, tester et lancer

Depuis la racine du dépôt, après création du projet et de son scheme partagé :

```sh
xcode-select -p
xcodebuild -version
xcrun swift --version
xcodebuild -resolvePackageDependencies -project outilVizMd.xcodeproj -scheme outilVizMd
xcodebuild -list -project outilVizMd.xcodeproj
xcodebuild -project outilVizMd.xcodeproj -scheme outilVizMd -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/outilVizMd-derived build
xcodebuild -project outilVizMd.xcodeproj -scheme outilVizMd -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/outilVizMd-derived test
open outilVizMd.xcodeproj
```

Résultats attendus : cibles outilVizMd, outilVizMdTests et outilVizMdUITests ; build réussi, tests
réussis. Dans Xcode, choisir My Mac puis Product → Run (Cmd+R). Les prompts système de sélection
font partie du parcours normal. Ne pas faire pointer les tests vers les documents personnels.
Relancer build/test réseau déconnecté une fois les dépendances mises en cache.

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
