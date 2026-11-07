# Validation — installation locale et icône

Date : 2026-11-07. Environnement exécuté : macOS 26.6.2 (25G83), Apple Silicon arm64, Xcode 27.2. Produit construit : macOS 14 minimum, arm64 + x86_64, version 0.1.0 (build 1). Une compilation universelle ne constitue pas une exécution Intel ou macOS 14.

## État de l’implémentation

Préparation Python, paquet Swift de déploiement, ICNS embarqué, installation/remplacement atomique, alias Finder, simulation/status et réouverture implémentés. Application installée dans `/Applications/outilVizMd.app` ; alias fixe `~/Desktop/outilVizMd – ouvrir` afin de préserver le dossier du projet `~/Desktop/outilVizMd`.

Le lot signé de préparation est hors du Bureau synchronisé et accessible par le lien `build/local`. L’app installée est une copie autonome ; elle ne dépend ni de ce lien ni du dossier temporaire. Les adaptations et la sérialisation du digest sont décrites dans `research.md`.

## Tests automatisés exécutés

- Python : **13 tests réussis**, zéro échec (`python3 -m unittest discover -s scripts/tests`). Source absente/ambiguë/modifiée/illisible, cache incomplet, génération du projet, refus des métadonnées de bundle invalides, architectures/ressources, échec de préparation préservant la sortie précédente et inventaire du bundle.
- SwiftPM : **22 tests réussis**, zéro échec, **1 test système opt-in ignoré** dans la suite isolée. Installation/répétition/mise à jour, conflit étranger/symlink/alias cassé, manifeste altéré, processus actif, simulation sans écriture, JSON, verrou concurrent, commit/rollback/nettoyage, conflit d’alias pendant rollback et alias visant la nouvelle identité avec ancienne app conservée. Le vecteur Unicode NFC du digest est commun à Python et Swift.
- Xcode, premier passage fonctionnel : **51 tests réussis**, zéro échec, **5 benchmarks opt-in ignorés**. Lecture, sécurité, filtrage réseau, isolation des ressources et préservation des documents.
- UI ciblée après correction : **3 parcours réussis**, zéro échec : ouverture/lecture/fermeture, annulation d’ouverture et réouverture. Cette dernière vérifie même PID, lecteur réduit/fermé, réglages/aide visibles, session en mémoire et document byte-identique.
- Passage Xcode complet final : **60 tests réussis**, zéro échec, **6 benchmarks opt-in ignorés**. Rapport : `/tmp/outilVizMd-tests-003/Logs/Test/Test-outilVizMd-2026.11.07_09-47-24-+0100.xcresult`. Le test de réouverture et tous les anciens parcours UI sont verts.

Total des trois suites finales : **95 réussites** (13 Python + 22 SwiftPM + 60 Xcode), zéro échec. Le test système opt-in SwiftPM reste ignoré ; les lancements Finder ci-dessous sont une vérification distincte.

Les journaux de cette session sont sous `/tmp/outilvizmd-python-tests.log`, `/tmp/outilvizmd-deployment-tests.log`, `/tmp/outilvizmd-final-xcode-tests.log`. Rapports XCTest dans `/tmp/outilVizMd-tests-003/Logs/Test/`. Ils sont locaux et temporaires ; les résultats synthétiques ci-dessus constituent la trace dans le dépôt.

## Produit final

Digest du bundle livré : `639cf7136ddc01165a74d5f279224dd22d6bc29431a6e05f63797084cb21d059`. SHA-256 ICNS : `a0d7d223e013557d3740d4dd10f4a87c4f0caf7acc0634e83fbe3347a580d92a`.

## Contrôles réels de préparation et installation

- Préparation exécutée avec `--offline --package-cache /tmp/outilVizMd-derived/SourcePackages`, paquets verrouillés disponibles localement.
- Signature stricte ad hoc avec runtime, architectures universelles, minimum macOS des deux binaires, chemins dynamiques, ressources et trois entitlements effectifs vérifiés par les deux validateurs.
- Original PNG SHA-256 avant/après : `2f568a19b834a308bce6c9ec56194f6c1e4090a69e5d6381ac3a6c350ce05be7`. Les dix représentations ICNS sont vérifiées par extraction ; ni recadrage ni modification du fichier original.
- Première installation : app valide, alias initialement refusé par une comparaison d’URL sensible à son indication de dossier. La commande `alias` a réparé l’accès sans modifier l’app. Le correctif compare chemin normalisé et identité de fichier ; un test reproduit l’URL créée avant l’existence de l’app.
- Trois répétitions réelles : trois codes 0, `complete`, `changed=false`, app et alias valides ; aucune copie supplémentaire. Résultats locaux : `/tmp/outilvizmd-install-repetitions.json`.
- Mise à jour réelle vers le bundle corrigé avec `--replace` : code 0, `complete`, app et alias valides, aucun chemin résiduel. Les préférences ont été comparées par SHA-256 avant/après, sans changement ni affichage de leur contenu.
- L’app installée a été ouverte et le panneau d’ouverture/annulation vérifié dans la vraie interface macOS. La recette finale des deux accès est consignée ci-dessous.

## Recette Finder finale

- Dix ouvertures réelles de l’alias Bureau : lecteur accessible 10/10, y compris après réduction et fermeture de sa fenêtre. Dix ouvertures depuis Applications : lecteur accessible 10/10. Les clics Applications ont utilisé les coordonnées de l’icône visible après un refus d’accessibilité « élément hors écran » ; ces tentatives de positionnement ne sont pas comptées dans la série finale.
- Processus canonique relevé avant/après : PID 98522, `/Applications/outilVizMd.app`, version 0.1.0 (build 1), app et alias valides, aucun reçu résiduel. Une autre copie de développement est restée intacte ; le double-clic Bureau a lancé l’installation canonique.
- `⌘O` puis sélection de `/tmp/outilvizmd-installation-validation.md` : titre « Installation validée », paragraphe et liste rendus par le WebKit embarqué dans l’app installée.
- Icône observée dans Finder/Applications (apparence sombre) et sur le Bureau, illustration reconnaissable et flèche d’alias standard. Le contrôle du Dock a expiré dans l’outil de contrôle UI ; Cmd-Tab, toutes les tailles et les deux apparences sur les quatre surfaces ne sont pas certifiés.
- Après une longue interruption, l’alias attendu était absent et un alias « outilVizMd – ouvrir 2 » était présent (origine du renommage non établie). Son identité cible a été vérifiée : même app canonique, même identité de fichier. Le raccourci attendu a été réparé avec `alias` ; le doublon de cette recette a ensuite été placé dans la corbeille via Finder, sans suppression définitive ni modification du dossier du projet. Le contrôle final montre un seul alias au nom attendu. La CLI ne crée jamais de nom suffixé et ne supprime aucun conflit inconnu.
- Xcode et Terminal, déjà ouverts dans la session personnelle, n’ont pas été quittés. Les vingt accès sont donc observés en usage Finder, sans commande de lancement ni compilation, mais ne certifient pas littéralement la condition « Xcode et Terminal fermés » de SC-001.

## Défauts rencontrés et corrigés

1. Xcode ne reprenait pas la clé d’icône dans son plist généré : plist source minimal fusionné, exclu des ressources.
2. Foundation et Python représentaient différemment les noms accentués : inventaire normalisé NFC et vecteur partagé.
3. Le File Provider du Bureau ajoutait FinderInfo, invalidant la signature : préparation hors dossier synchronisé, nettoyage ciblé du produit avant signature ; aucune suppression de quarantaine.
4. Le lecteur fermé n’était pas réouvert si les réglages restaient visibles : pont AppKit minimal vers la scène `reader`, même modèle de lecture.
5. La sonde NSView interceptait des clics SwiftUI : taille nulle, `allowsHitTesting(false)` et `hitTest` renvoyant nil. Les tests d’ouverture qui échouaient repassent après correction.
6. Le harnais initial choisissait une autre copie active : il sélectionne désormais exactement le produit de la cible UI ; la validation réelle du Finder demeure distincte.

Une tentative de test UI a aussi échoué avant démarrage (timeout du mode d’automatisation macOS) ; elle n’est pas comptée comme une réussite fonctionnelle.

## Critères de livraison et limites

| Critère | Preuve disponible | État / complément requis |
|---|---|---|
| SC-001 — dix lancements par accès | Réouverture automatisée, app installée utilisable | 20 ouvertures Finder réussies ; condition outils de développement fermés restant à confirmer. |
| SC-002 — redémarrage, projet inaccessible, réseau coupé | Ressources/dépendances embarquées, préparation offline, tests de blocage réseau | Redémarrage réel et session dédiée sans accès projet/temporaires non exécutés ; réseau physique non désactivé. |
| SC-003 — quatre surfaces et deux apparences | Source immuable, dix représentations, plist et ICNS validés | Finder et Bureau observés ; Dock/Cmd-Tab, toutes les tailles et les deux apparences restent à certifier. |
| SC-004 — répétition, mise à jour, préservation | Trois installations identiques, mise à jour réelle, alias valide, préférences identiques ; tests de documents byte-identiques | Deux accès après mise à jour vérifiés ; l’alias renommé pendant l’interruption a été réparé et le doublon vérifié retiré via Finder. |
| SC-005 — erreurs et conflits | Tests isolés des refus, pannes, rollback, concurrence, alias et résultats partiels | Aucun remplissage de disque ni changement de droits des destinations personnelles n’a été effectué pour simuler un échec. |

FR-001–003 : préparation et installation autonome ; FR-004–006 : alias/réouverture/idempotence ; FR-007–009 : image/ICNS immuabilité ; FR-010–011 : préservation/transactions ; FR-012–013 : offline/signature/sandbox et tests du lecteur ; FR-014 : README, aide, CLI et quickstart en français.

**La recette complète n’est pas certifiée tant que les contrôles non exécutés ci-dessus ne sont pas réalisés.** Les tâches de recette correspondantes restent décochées ; aucun redémarrage ni changement global de réseau/apparence n’est déclenché sur la session personnelle pour les faire artificiellement passer.
