# Tasks: outilVizMd — installation locale et icône

**Entrées** : `specs/003-installer-app-icone/{spec,plan,research,data-model,quickstart}.md`, `contracts/deployment-cli.md`, `contracts/launch-and-icon.md` et constitution 1.0.0.

**Prérequis** : lecteur 001 existant ; aucune dépendance à 002. Swift en mode 5, concurrence stricte, macOS 14+, Xcode complet compatible Swift 6.2 minimum, Python 3 standard ; Foundation/AppKit/Darwin pour l’outil, aucune nouvelle dépendance tierce.

**Organisation** : les trois stories sont P1. À priorité égale, l’ordre technique est **US3 → US1 → US2** : embarquer l’icône, produire/installer la Release, puis publier le raccourci. Les identifiants US restent ceux de la spécification. Le contrôle visuel US3 sur le Bureau est un contrôle d’intégration différé jusqu’à US2, pas une dépendance bloquant la préparation de l’icône.

**Tests** : les tâches de tests matérialisent les scénarios et critères SC-001 à SC-005 de la spécification, les tests prévus au plan et les obligations de préservation/non-régression de la constitution. Écrire les tests automatisés avant le comportement correspondant et constater l’échec pertinent ; les recettes système suivent l’implémentation. Aucun test destructif sur Applications ou le Bureau réels.

## Format et chemins

- Chaque tâche suit `- [ ] Txxx [P?] [USn?] Description avec chemin`.
- `[P]` désigne des travaux sur des fichiers distincts, exécutables ensemble lorsque leurs prérequis de phase sont terminés ; les groupes exacts sont indiqués plus bas.
- Tous les chemins sont relatifs à la racine, sauf la destination contractuelle `/Applications/outilVizMd.app`.
- `tools/LocalDeployment/` est un paquet ponctuel extérieur à la sandbox du lecteur, sans quatrième cible Xcode. Les destinations injectables et pannes simulées sont réservées aux tests.
- Les comptes rendus futurs vont dans `specs/003-installer-app-icone/validation.md` ; distinguer systématiquement prévu, réussi, échoué et non exécuté.

## Phase 1 : Setup — infrastructure de travail

**Objectif** : préparer le paquet et les sorties locales, sans installer l’application.

- [X] T001 Créer `tools/LocalDeployment/Package.swift` (Swift tools 5.9, macOS 14, exécutable `install-local-app`, cible de tests `InstallLocalAppTests`, Foundation/AppKit/Darwin sans dépendance tierce) et l’entrée minimale `tools/LocalDeployment/Sources/InstallLocalApp/Command.swift`, sans changer les trois cibles de `outilVizMd.xcodeproj/project.pbxproj`.
- [X] T002 [P] Compléter `.gitignore` pour exclure `build/` et les sorties du paquet `tools/LocalDeployment/.build/`, en conservant le suivi de `outilVizMd.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` et du futur `outilVizMd/Resources/AppIcon.icns`.

## Phase 2 : Fondations — contrats et isolation des opérations

**Objectif** : fournir les types et points d’injection communs. Cette phase bloque les trois stories.

- [X] T003 Définir dans `tools/LocalDeployment/Sources/InstallLocalApp/Command.swift` les requêtes et résultats Codable : « opération install/alias/status, source éventuelle, remplacement explicite, simulation, format JSON », « Destinations fixes en production ; injection interne pour tests seulement. », `schemaVersion=1`, `operation`, `outcome`, `applicationState`, `aliasState`, `applicationPath`, « aliasPath éventuellement nul », identité/version effective, `changed`, diagnostics français et chemins de récupération ; reprendre les outcomes « complete, partial, refused, failed, preview, status », sans contenu de document/préférence et avec `plannedActions` pour preview.
- [X] T004 Définir dans `tools/LocalDeployment/Sources/InstallLocalApp/Deployment.swift` les types PreparedRelease, InstalledApplication et Transaction ainsi que les opérations injectables de fichiers/processus/validation/pannes ; reprendre `canonicalURL=/Applications/outilVizMd.app`, `fileResourceIdentifier`, « état absent/valide/invalide/conflit », « UUID, identité des destinations précontrôlées, dossier privé de staging même volume, ancien bundle éventuel, alias sécurisé éventuel, reçu de dernière étape confirmée » ; garder identité de bundle stable et aucune propriété sur les documents utilisateur.
- [X] T005 [P] Définir dans `tools/LocalDeployment/Sources/InstallLocalApp/DesktopAlias.swift` le type et le contrat partagé d’inspection, sécurisation, restauration et publication : « desktopURL fourni par le système ; nom disque final outilVizMd – ouvrir ; type véritable alias Finder, pas symlink », champs URL/cible résolue/identité de fichier cible, « état absent/valide/ancien/conflit/inaccessible/nonVérifié », « Résoudre sans UI ni montage. », « Valide signifie chemin canonique ET identité de la version actuelle. » ; prévoir une implémentation injectée sans prétendre qu’un alias a été créé.
- [X] T006 Créer `tools/LocalDeployment/Tests/InstallLocalAppTests/DeploymentTestSupport.swift` avec dossiers temporaires, bundles de test distincts, inventaires avant/après, faux processus, simulation du Bureau et pannes ciblées (copie, commit, validation, alias, rollback, nettoyage) ; empêcher tout recours des tests aux destinations de production et ne supprimer au teardown que leurs objets identifiés.

**Point de contrôle** : paquet compilable, types communs disponibles, aucune écriture dans Applications, le Bureau, les documents ou les préférences.

## Phase 3 : US3 — Reconnaître l’application grâce à l’image fournie (P1)

**Objectif** : produire et embarquer une icône fidèle et autonome avant la Release d’installation.

**Test indépendant** : produire l’ICNS, vérifier les dix représentations, l’empreinte inchangée de l’original, la déclaration Info.plist et les ressources d’un bundle construit. Inspecter Finder/Dock/Cmd-Tab en clair/sombre ; compléter le contrôle du véritable alias Bureau après US2 en T040.

### Tests avant implémentation

- [X] T007 [P] [US3] Créer dans `scripts/tests/test_prepare_local_app.py` les tests de source absente, ambiguë en NFC, illisible, différente, faux PNG et mauvaises dimensions ; vérifier refus sans nouvelle sortie conforme, préservation byte-identique de l’original, dix tailles d’icône et erreurs 4/5/6/64 du contrat de préparation, avec outils Apple simulés pour les échecs.
- [X] T008 [P] [US3] Ajouter `scripts/tests/test_app_icon_project.py` pour vérifier que le générateur référence une seule ressource ICNS, utilise `image.icns`, fixe `CFBundleIconFile=AppIcon.icns` en Debug et Release et conserve identité, versions, droits et trois cibles ; lancer le générateur sur une copie temporaire du projet de test.

### Implémentation

- [X] T009 [US3] Créer le contrôle ImageSource dans `scripts/prepare-local-app.py` en reprenant « Icône Markdown personnalisable en couches.png, comparaison NFC, correspondance unique. », « PNG, 1254 × 1254, lisible. », SHA-256 `2f568a19b834a308bce6c9ec56194f6c1e4090a69e5d6381ac3a6c350ce05be7` « avant et après préparation. » ; refuser une source absente/ambiguë/modifiée/invalide même si un ancien ICNS existe, sans renommer ni écrire l’original.
- [X] T010 [US3] Implémenter dans `scripts/prepare-local-app.py` la génération temporaire par `sips` et `iconutil` de `outilVizMd/Resources/AppIcon.icns` avec la contrainte « AppIcon.icns, dix représentations ; jamais réécrire l’original. » : 16/32/128/256/512 points en 1× et 2× directement depuis la source, fond opaque, proportions, composition et couleurs conservés, sans recadrage ; ne publier le dérivé qu’après contrôles.
- [X] T011 [US3] Modifier `scripts/update-xcode-project.py` pour intégrer `outilVizMd/Resources/AppIcon.icns` avec le type `image.icns` et `INFOPLIST_KEY_CFBundleIconFile=AppIcon.icns` dans les deux configurations de l’app, sans toucher aux droits, à l’identité, aux versions ni aux dépendances ; régénérer `outilVizMd.xcodeproj/project.pbxproj` après génération du dérivé.
- [X] T012 [US3] Ajouter dans `scripts/prepare-local-app.py` les contrôles de l’ICNS dérivé et de l’icône embarquée (plist, présence, lecture, représentations, empreinte), interdire une conformité avec icône générique et toute modification du bundle après signature ; ne pas comparer binairement des ICNS générés par différentes versions des outils Apple.
- [ ] T013 [US3] Exécuter les tests d’icône et inspecter un bundle local construit dans Finder/Dock/Cmd-Tab aux tailles disponibles, en clair et sombre ; consigner empreinte source, version, surfaces et limites dans `specs/003-installer-app-icone/validation.md`, en laissant explicitement le contrôle Bureau à T040.

**Point de contrôle** : l’icône et son intégration sont utilisables par US1 ; SC-003 complet reste à valider avec l’installation et l’alias.

## Phase 4 : US1 — Ouvrir l’application depuis Applications (P1)

**Objectif** : produire une Release autonome et installer/remplacer explicitement l’app canonique, avec récupération et préservation des données.

**Test indépendant** : depuis une Release validée, installer puis lancer par Finder, lire un Markdown local sans outils de développement ; répéter après redémarrage, hors ligne et sans accès au projet. Pour cet incrément, un alias non publié doit être signalé comme résultat partiel, jamais comme succès complet.

### Tests avant implémentation

- [X] T014 [P] [US1] Étendre `scripts/tests/test_prepare_local_app.py` pour couvrir cache offline incomplet sans téléchargement, construction Release universelle, rejet d’un bundle/manifeste/signature/droits/ressources invalide, compilation de l’outil hôte et publication cohérente des trois sorties ; injecter les échecs et vérifier qu’une préparation valide précédente reste intacte.
- [X] T015 [P] [US1] Créer `tools/LocalDeployment/Tests/InstallLocalAppTests/CommandTests.swift` pour le contrat CLI : commandes/options autorisées, aide française, source/manifeste adjacents, refus des destinations arbitraires, JSON unique sur stdout, diagnostics sur stderr, valeurs nulles légitimes, codes 0–8 et 64, status en lecture seule même si absent/conflit, dry-run sans verrou persistant/staging/alias ni lancement d’app ; tester alias avec le service injecté avant son intégration US2.
- [X] T016 [P] [US1] Créer `tools/LocalDeployment/Tests/InstallLocalAppTests/DeploymentTests.swift` couvrant installation exclusive, trois répétitions sans remplacement, digest différent refusé sans `--replace`, identité étrangère/symlink préservés, app active et processus ambigu refusés, copie de développement non arrêtée, digest vérifié contre le bundle, documents et préférences byte-identiques ; utiliser les destinations temporaires de T006.
- [X] T017 [P] [US1] Créer `tools/LocalDeployment/Tests/InstallLocalAppTests/DeploymentRecoveryTests.swift` couvrant verrou concurrent, permissions/espace, copie/commit refusés, conflit tardif, validation post-commit, rollback échoué, nettoyage échoué et interruption ; vérifier ancienne app disponible avant commit, restauration après erreur, reçus/chemins exacts et aucun écrasement d’objet inconnu, avec le service d’alias injecté.

### Implémentation

- [X] T018 [US1] Compléter `scripts/prepare-local-app.py` pour les options `--offline` et `--package-cache` (défaut `build/SourcePackages`), le contrôle du cache verrouillé sans résolution/téléchargement offline, la régénération du projet et la Release dans un DerivedData distinct des tests via `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` ; conserver Swift 5/concurrence stricte et versions verrouillées, compiler aussi l’outil pour l’hôte sans installation implicite.
- [X] T019 [US1] Valider PreparedRelease et produire le manifeste dans `scripts/prepare-local-app.py` : « Bundle réel .app, non symlink à sa racine ; exécutable déclaré présent. », identité/type `com.outilvizmd.outilVizMd` / `APPL`, « Valeurs Info.plist existantes conservées ; pas d’incrément automatique requis. », « arm64 + x86_64 / macOS 14.0. », « ICNS présent et lisible ; empreinte issue de la préparation validée. », « Rendu, aide et licences embarqués ; aucun chemin dynamique vers le projet ou les temporaires. » ; imposer « Signature valide ad hoc avec runtime ; exactement les trois droits existants. Aucun get-task-allow, droit serveur ou bundle de tests. » avec sandbox, fichiers sélectionnés read-only et client réseau WebKit, vérifiés sur le produit signé.
- [X] T020 [US1] Définir dans `scripts/prepare-local-app.py` et vérifier indépendamment dans `tools/LocalDeployment/Sources/InstallLocalApp/Deployment.swift` le `bundleDigest` : « SHA-256 d’un inventaire trié des chemins relatifs, octets, cibles des symlinks et bits exécutables ; dates/inodes exclus. Les symlinks internes légitimes sont conservés et contrôlés. » ; fixer une sérialisation identique Python/Swift et un vecteur partagé `tools/LocalDeployment/Tests/InstallLocalAppTests/Fixtures/bundle-digest.json`, puis vérifier le manifeste adjacent schemaVersion 1 (identité/version, architectures, minimumOS, sourceSHA256, iconSHA256, bundleDigest) contre le bundle réel sans lui faire confiance seul.
- [X] T021 [US1] Publier de manière cohérente après validation l’app, `manifest.json` et l’outil sous `build/local/` depuis `scripts/prepare-local-app.py`, en conservant une sortie précédente valide lors des échecs ; indiquer chemins/version et diagnostics français avec récupération pour codes 4/5/6/64, sans installer implicitement.
- [X] T022 [US1] Implémenter dans `tools/LocalDeployment/Sources/InstallLocalApp/Deployment.swift` les précontrôles source/manifeste/app/droits/espace/processus et l’idempotence : « Une version de même identifiant mais de digest différent demande --replace. », « Un digest identique ne remplace pas le bundle ; seule la vérification/réparation du raccourci est nécessaire. » ; comparer URL canonique des processus, refuser identité ambiguë, distinguer les copies de développement, recontrôler avant commit et traiter les erreurs effectives sans arrêt forcé ni élévation automatique.
- [X] T023 [US1] Implémenter dans `tools/LocalDeployment/Sources/InstallLocalApp/Deployment.swift` verrou local, staging privé UUID sur le volume Applications, copie/validation, reçu de dernière étape confirmée et commit `renameatx_np` avec `RENAME_EXCL` ou `RENAME_SWAP` ; conserver l’ancien bundle jusqu’aux validations finales, intégrer les appels de sécurisation/restauration de l’alias via T005 et refuser une mise à jour dont l’alias connu ne peut être sécurisé, sans fallback par suppression préalable.
- [X] T024 [US1] Implémenter dans `tools/LocalDeployment/Sources/InstallLocalApp/Deployment.swift` validation canonique, échange inverse ou retrait exclusif de la nouvelle app propre, restauration d’alias sans écrasement concurrent et nettoyage des seuls objets identifiés ; appliquer « Seul alias échoué après validation de l’app : partial, application utilisable, raccourci absent/conflit précisément indiqué ; réparation séparée. », « Nettoyage échoué : app/alias restent décrits selon leurs états réels, résultat partial et chemin conservé indiqué. » et « Pas de reprise ou suppression automatique d’état ambigu ; inspection et récupération guidées. » ; retour arrière réussi reste un échec de mise à jour, récupération incomplète utilise le code 8.
- [X] T025 [US1] Relier parsing, aide française et rendu texte/JSON dans `tools/LocalDeployment/Sources/InstallLocalApp/Command.swift` aux opérations install/alias/status et aux codes exacts de `specs/003-installer-app-icone/contracts/deployment-cli.md` ; status inspecte processus/reçus sans écrire ni lancer, dry-run rapporte état réel et actions prévues sans mutation, et un Bureau inaccessible n’a pas de chemin inventé ; avant US2, un service d’alias indisponible ne peut annoncer complete.
- [X] T026 [US1] Faire passer les tests de préparation, CLI, déploiement et récupération, puis préparer réellement la Release offline et vérifier `codesign`, entitlements, `lipo`, plist, dépendances et ressources ; consigner les résultats et les limites de cache/OS/architecture dans `specs/003-installer-app-icone/validation.md`, sans prétendre valider une exécution Intel/macOS 14 par la seule compilation.
- [ ] T027 [US1] Réaliser le parcours Applications de `specs/003-installer-app-icone/quickstart.md` : installation de référence explicite, dix lancements Finder avec lecture locale, trois répétitions puis mise à jour identifiée avec documents/préférences inchangés ; consigner chemin/version/PID et résultats dans `specs/003-installer-app-icone/validation.md`, en distinguant l’absence provisoire d’alias du succès de l’installation.
- [ ] T028 [US1] Vérifier après redémarrage le lancement Applications et la lecture hors ligne dans une session de recette où projet/image/temporaires sont inaccessibles, sans déplacer le dépôt de travail ; consigner la preuve ou le contrôle non exécuté dans `specs/003-installer-app-icone/validation.md`, sans annoncer SC-002 complet avant le parcours Bureau.

**Point de contrôle** : US1 utilisable depuis Applications. Le MVP technique comprend le socle icône US3 ; la demande complète exige encore US2 et la recette transversale.

## Phase 5 : US2 — Lancer la même application depuis le Bureau (P1)

**Objectif** : publier un véritable alias Finder vers l’app canonique, le maintenir après mise à jour et présenter le lecteur existant lors d’une nouvelle sollicitation.

**Test indépendant** : sur une installation valide, exécuter `alias`, ouvrir par double-clic et vérifier chemin/version/identité du processus ; répéter après remplacement avec l’ancien bundle encore en sauvegarde. Supprimer seulement l’alias doit préserver app et documents, puis la réparation doit fonctionner sans source de préparation.

### Tests avant implémentation

- [X] T029 [P] [US2] Créer `tools/LocalDeployment/Tests/InstallLocalAppTests/DesktopAliasTests.swift` pour création et résolution d’un véritable alias Finder, idempotence, suppression seule et réparation sans source ; couvrir fichier/répertoire/symlink/alias étranger, alias cassé sans preuve, ancien bundle reconnu par reçu, résolution sans UI/montage et identité courante alors qu’une sauvegarde de l’ancienne app existe encore.
- [X] T030 [P] [US2] Créer `tools/LocalDeployment/Tests/InstallLocalAppTests/AliasTransactionTests.swift` pour Bureau inaccessible à la première installation (partial) ou avant mise à jour (refus), conflit étranger préservé, mise à l’abri impossible, alias échoué après commit (partial), restauration avant/après rollback, conflit concurrent à la publication/restauration et nettoyage incomplet ; vérifier codes, états effectifs et octets des conflits.
- [X] T031 [P] [US2] Créer `outilVizMdUITests/ReopenJourneyTests.swift` pour sollicitation app déjà ouverte, lecteur fermé/réduit et seule aide/préférences visible ; vérifier présentation du lecteur et conservation de la session en mémoire, sans nouveau modèle ni instance indépendante, avec un lancement explicite du bundle de test.
- [X] T032 [P] [US2] Créer `tools/LocalDeployment/Tests/InstallLocalAppTests/InstalledLaunchTests.swift` comme harnais système opt-in pour une URL de bundle explicite : `createsNewApplicationInstance=false`, `allowsRunningApplicationSubstitution=false`, contrôle URL/version/PID ; ne jamais installer, remplacer ou lancer l’app personnelle dans la suite isolée par défaut, et ne pas considérer ce harnais comme une preuve du vrai double-clic Finder.

### Implémentation

- [X] T033 [US2] Implémenter dans `tools/LocalDeployment/Sources/InstallLocalApp/DesktopAlias.swift` la découverte `.desktopDirectory`, exclusion des symlinks par `lstat`, inspection sans UI/montage et propriété reconnue : « Reconnu signifie alias résolu vers l’installation vérifiée avant remplacement, ou vers un ancien bundle identifié par un reçu de transaction valide. » et « Un alias inconnu ou cassé sans preuve de propriété n’est jamais écrasé. » ; préserver les conflits même avec `--replace`.
- [X] T034 [US2] Implémenter dans `tools/LocalDeployment/Sources/InstallLocalApp/DesktopAlias.swift` bookmark `.suitableForBookmarkFile`, écriture temporaire `.alias`, publication exclusive sous le nom `outilVizMd – ouvrir`, vérification chemin canonique ET identité de fichier, sécurisation de l’ancien alias et restauration sans écrasement ; recréer depuis la nouvelle app après commit et ne pas laisser l’alias suivre l’ancien bundle en staging.
- [X] T035 [US2] Brancher le service réel dans `tools/LocalDeployment/Sources/InstallLocalApp/Deployment.swift` et `tools/LocalDeployment/Sources/InstallLocalApp/Command.swift` pour install/alias/status/dry-run ; autoriser première installation partielle si Bureau indisponible, refuser mise à jour avec Bureau invérifiable, préserver un conflit étranger et rapporter partial après app valide, réparer seulement l’alias sur digest identique même si l’app tourne ; une app canonique absente/invalide interdit la commande alias.
- [X] T036 [US2] Vérifier puis corriger si nécessaire `outilVizMd/App/outilVizMdApp.swift` pour présenter/restaurer `Window("outilVizMd", id: "reader")` via `openWindow(id:)` en conservant le `ReadingCoordinator` ; ajouter seulement si requis un pont AppKit minimal dans ce fichier, sans se fier à la seule présence d’une fenêtre aide/préférences, sans singleton interprocessus ni changement des autorisations documentaires.
- [X] T037 [US2] Régénérer `outilVizMd.xcodeproj/project.pbxproj` avec `scripts/update-xcode-project.py` pour inclure `outilVizMdUITests/ReopenJourneyTests.swift`, puis faire passer tests d’alias, transactions et réouverture ; consigner dans `specs/003-installer-app-icone/validation.md` le cas où la sauvegarde de l’ancien bundle reste présente et les contrôles de session/processus.
- [ ] T038 [US2] Exécuter dix lancements réels par l’alias Bureau, dont app quittée/déjà ouverte/lecteur fermé/réduit/aide ou préférences seule, avec copie de développement présente ; répéter après mise à jour, puis supprimer seulement l’alias et réparer par `alias` sans source ; consigner états, PID/chemin/version, absence de doublons et préservation dans `specs/003-installer-app-icone/validation.md`, sans lancement forcé pour masquer une substitution de copie.
- [ ] T039 [US2] Compléter dans `specs/003-installer-app-icone/validation.md` le parcours Bureau après redémarrage, hors ligne et sans accès au projet/temporaires, selon `specs/003-installer-app-icone/quickstart.md` ; vérifier la même installation que par Applications et signaler tout contrôle non exécuté.

**Point de contrôle** : les deux accès utilisent la même app ; alias réparable et mise à jour vérifiée sans duplication.

## Phase 6 : Finitions et validation transversale

**Objectif** : confirmer les cinq critères SC et livrer une procédure française exacte.

- [ ] T040 Vérifier sur l’installation finale l’icône dans les quatre surfaces Finder/Bureau/Dock/Cmd-Tab aux tailles disponibles et en clair/sombre ; comparer l’original avant/après préparation et installation, et consigner observations/captures référencées dans `specs/003-installer-app-icone/validation.md` pour clore US3 et SC-003.
- [X] T041 [P] Mettre à jour `README.md` avec prérequis, préparation/cache offline, installation et destination exacte, deux accès, `--replace`, `alias`, `status`, dry-run, codes partiels, conflits/récupération, signature ad hoc locale et plateformes réellement exécutées ; expliquer le rafraîchissement local d’une icône ancienne sans purge globale, désactivation de Gatekeeper ni suppression de quarantaine.
- [X] T042 [P] Mettre à jour `outilVizMd/Resources/Aide.md` en français avec lancement Applications/Bureau, réouverture, mise à jour après fermeture normale, suppression/réparation du seul alias, conflits/Bureau indisponible et récupération d’une icône ancienne ; préciser qu’aucun outil de développement n’est requis au lancement quotidien et qu’aucun document/préférence n’est modifié par l’installation.
- [X] T043 Exécuter les tests Python, SwiftPM et les tests Xcode concernés par ouverture/lecture/réouverture/sécurité/hors ligne/préservation selon `specs/003-installer-app-icone/quickstart.md` ; vérifier notamment `outilVizMdTests/Integration/ReadOnlyOfflineRegressionTests.swift`, `outilVizMdTests/Integration/NoAutomaticNetworkTests.swift` et `outilVizMdTests/Unit/UntrustedRenderingTests.swift`, puis consigner résultats, exclusions optionnelles et plateformes dans `specs/003-installer-app-icone/validation.md`.
- [X] T044 Après la modification d’aide, reconstruire et revalider la Release finale avec `scripts/prepare-local-app.py`, installer explicitement cette version via l’outil et vérifier ses deux accès et son icône ; compléter `specs/003-installer-app-icone/validation.md` avec les 20 lancements de la version finale, trois répétitions et mise à jour, comparaison des documents/préférences, reçus et sorties exactes pour tous les cas d’erreur isolés, afin que les preuves correspondent à l’artefact livré.
- [X] T045 Actualiser `specs/003-installer-app-icone/quickstart.md` pour refléter les commandes réellement livrées et clore dans `specs/003-installer-app-icone/validation.md` la matrice FR-001–014/SC-001–005 avec preuves, échecs et non-exécutés ; contrôler la constitution, ne pas déclarer la livraison validée si un critère essentiel échoue ou si sa preuve manque, et documenter séparément les limites Intel/macOS 14.

## Dépendances et ordre d’exécution

```text
Phase 1 : T001 + T002
          ↓
Phase 2 : T003 → (T004 + T005) → T006
          ↓
US3 : (T007 + T008) → T009 → T010 → T011 → T012 → T013
          ↓ icône prête ; contrôle Bureau différé
US1 : (T014 + T015 + T016 + T017) → T018 → … → T028
          ↓ application installable et utilisable
US2 : (T029 + T030 + T031 + T032) → T033 → … → T039
          ↓
T040 + T041 + T042 → T043 → T044 → T045
```

- T004 et T005 consomment les résultats définis par T003 ; T006 attend leurs interfaces.
- T007/T008 ne modifient pas le code de préparation ni le générateur. Les implémentations d’une même story suivent leurs tests.
- T018–T021 construisent une Release avec l’icône de US3. T020 fixe explicitement la sérialisation commune avant la publication et l’utilisation du digest par T022.
- US1 teste la coordination d’alias par injection ; US2 apporte son implémentation système. Avant celle-ci, refuser une mise à jour si la sécurité de l’alias n’est pas démontrée, et signaler partial si sa création manque.
- Les tâches modifiant `scripts/prepare-local-app.py`, `Deployment.swift`, `Command.swift`, `DesktopAlias.swift` ou le projet généré sont séquentielles au sein de leur flux ; ne pas les lancer simultanément.
- T036 peut être développé après les tests de réouverture, séparément des fichiers de déploiement, mais T037 attend T035 et T036.
- T040 clôt le contrôle visuel US3 après US2 ; T042 modifie une ressource embarquée, donc T044 doit reconstruire/signer et vérifier la version finale. Aucun changement dans le bundle après signature.
- Les mesures système demandant redémarrage/session dédiée sont distinctes des suites automatisées isolées. Une étape indisponible reste non exécutée, elle n’est pas cochée comme réussie.

## Exemples de travaux parallèles

### US3

Après les fondations, préparer ensemble T007 (`scripts/tests/test_prepare_local_app.py`) et T008 (`scripts/tests/test_app_icon_project.py`). Attendre les deux avant T009–T012. La recette Bureau n’est pas réalisable avant US2.

### US1

Après US3, préparer ensemble T014 (préparation Python), T015 (contrat CLI), T016 (déploiement) et T017 (récupération), chacun dans son fichier. Les implémentations qui partagent le script et `Deployment.swift` restent séquentielles.

### US2

Après US1, préparer ensemble T029 (alias), T030 (transactions), T031 (réouverture UI) et T032 (harnais de lancement opt-in). Après leurs tests, le travail T036 sur la scène SwiftUI peut avancer indépendamment du flux T033–T035 ; réunir les résultats avant T037.

### Finitions

Après US2, T040 (recette visuelle), T041 (`README.md`) et T042 (`Aide.md`) peuvent avancer ensemble. Attendre l’aide finale avant tests/reconstruction et recette de livraison T043–T045.

## Stratégie d’implémentation

1. Terminer Setup et fondations sans installation réelle.
2. Préparer l’icône US3 et vérifier son intégration ; conserver explicitement son contrôle Bureau en attente.
3. Livrer un **MVP technique US1 avec le socle US3** : Release autonome, installation Applications, remplacement et récupération testés. La création d’alias n’est pas annoncée complète à ce stade.
4. Ajouter US2, vérifier les alias réels et la réouverture, puis terminer les quatre surfaces d’icône.
5. Finaliser les documents, reconstruire l’artefact final et exécuter la recette complète. Les trois stories P1 sont nécessaires pour satisfaire toute la demande initiale.

## Traçabilité et complétude

| Périmètre | Tâches principales | Preuve indépendante / finale |
|---|---|---|
| US1 — Applications (15 tâches) | T014–T028 | Release contrôlée, lancement et lecture Applications, répétition/mise à jour, redémarrage hors ligne ; T044 final |
| US2 — Bureau (11 tâches) | T029–T039 | Vrai alias, chemin et identité courants malgré sauvegarde, même processus/lecteur, suppression/réparation ; T044 final |
| US3 — Icône (7 tâches) | T007–T013 | Dix représentations, original inchangé, intégration signée ; quatre surfaces en T040/T044 |
| FR-001–003 / SC-001–002 | T018–T028, T031–T032, T036–T039, T044 | Autonomie et deux accès, 10 essais par accès, redémarrage |
| FR-004–006 / SC-004 | T016, T022–T025, T029–T039, T044 | Alias unique, mise à jour explicite, pas de doublons |
| FR-007–009 / SC-003 | T007–T013, T019, T040, T044 | Original conservé, ICNS embarqué, inspection visuelle |
| FR-010–011 / SC-005 | T014–T017, T022–T025, T029–T030, T033–T035, T043–T045 | Pannes isolées, conflits inchangés, états exacts, données préservées |
| FR-012–013 | T018–T020, T026, T028, T039, T043–T045 | Hors ligne, signature/droits, sécurité du lecteur |
| FR-014 | T025, T041–T042, T045 | Aide CLI, README, aide embarquée et recette françaises |

**Total** : 45 tâches — 2 Setup, 4 fondations, 7 US3, 15 US1, 11 US2 et 6 finitions. Aucun travail de fonctionnalité n’est réputé exécuté par la génération de cette liste.

## État après exécution du 2026-11-07

L’implémentation est livrée et installée. Les preuves et adaptations sont dans `validation.md`. T013/T040 sont partiellement exécutées (Finder/Bureau validés ; quatre surfaces, tailles et apparences non toutes certifiées). T027/T038 sont partiellement exécutées (vingt accès Finder, lecture locale, répétitions, mise à jour et réparation ; toutes les conditions de recette manuelle ne sont pas réunies). T028/T039 restent non exécutées (redémarrage réel et session isolée hors ligne). Ces tâches restent décochées : les tests automatisés ne remplacent pas ces conditions.
