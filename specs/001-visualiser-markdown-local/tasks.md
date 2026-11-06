# Tasks: outilVizMd — visualisation de Markdown local

**Entrées** : `specs/001-visualiser-markdown-local/{spec,plan,research,data-model,quickstart}.md`, `contracts/composants.md`, `contracts/interface-et-ressources.md` et `.specify/memory/constitution.md` v1.0.0.

**Organisation** : tâches groupées par parcours ; ordre de priorité US1 → US2 → US6 (P1), puis US3 → US4 → US5 (P2). US6 conserve son identifiant de la spécification. Les protections communes sont implémentées dès US1 ; US6 en vérifie les garanties adversariales avant toute démonstration du MVP.

**Tests** : explicitement demandés par la spécification (SC-001 à SC-008) et la constitution. Écrire les tests de chaque tranche avant son implémentation, constater leur échec pour le comportement attendu, puis les faire réussir. Les tests utilisent uniquement des copies temporaires et des stores isolés. Aucun test ni compilation n’a été exécuté par la génération de ce fichier.

## Format : `[ID] [P?] [Story] Description`

- `[P]` indique un travail possible en parallèle avec les autres tâches de la même vague, après ses prérequis indiqués ; les fichiers modifiés doivent être distincts.
- `[USn]` correspond au parcours de `spec.md` ; absent des tâches de préparation, de fondations et de finition.
- Tous les chemins sont relatifs à la racine du projet. La progression réelle figure dans les cases et les rapports `validation/`.
- Les fichiers partagés, notamment `ReadingCoordinator.swift`, `ReaderCommands.swift` et `ReaderWindow.swift`, se modifient séquentiellement ; les tests de parcours distincts utilisent des extensions Swift dans des fichiers séparés.

## Phase 1 : Setup — outillage et structure partagée

**But** : préparer le projet macOS natif et une validation reproductible, sans ajouter de serveur ni de paquet UI.

- [X] T001 Vérifier Xcode complet, Swift ≥ 6.2, SDK macOS et signature locale avec les commandes de `specs/001-visualiser-markdown-local/quickstart.md`, et consigner les versions ou le blocage réel dans `specs/001-visualiser-markdown-local/validation/toolchain.md` ; les Command Line Tools seuls ne suffisent pas et aucune compilation ne doit être annoncée sans résultat.
- [X] T002 Créer `outilVizMd.xcodeproj/project.pbxproj`, `outilVizMd.xcodeproj/xcshareddata/xcschemes/outilVizMd.xcscheme`, `outilVizMd/App/outilVizMdApp.swift` et `outilVizMd/outilVizMd.entitlements` avec les trois cibles app/XCTest/XCUITest, macOS 14 minimum, arm64/x86_64, mode Swift 5 et vérification complète de concurrence ; activer App Sandbox et `user-selected.read-only` sur les documents, sans read-write ni accès global aux dossiers ; ajouter seulement le droit réseau client requis pour initialiser WebKit, sans droit serveur, en conservant les blocages de chargements automatiques (décision corrigée et vérifiée dans `validation/webkit-feasibility.md`).
- [X] T003 Épingler le produit Markdown de `swiftlang/swift-markdown` à la version exacte 0.9.0 dans `outilVizMd.xcodeproj/project.pbxproj`, résoudre et conserver le graphe dans `outilVizMd.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`, puis vérifier le scheme et compiler le squelette ; ne pas remplacer la dépendance ou désactiver le sandbox pour contourner un échec.
- [X] T004 [P] Créer le corpus fonctionnel et malveillant sous `outilVizMdTests/Fixtures/` : CommonMark/tableaux/code/ancres/Unicode, documents homonymes, PNG/JPEG/GIF, vide, UTF-8 invalide, HTML actif, schémas dangereux et chemins encodés ; décrire les attendus dans `outilVizMdTests/Fixtures/README.md` et générer les gros fichiers et symlinks uniquement dans les répertoires temporaires des tests.
- [X] T005 [P] Créer `outilVizMdTests/Support/TemporaryCorpus.swift`, `outilVizMdTests/Support/SourcePreservationAssertions.swift` et `outilVizMdTests/Support/ControlledAsyncWork.swift` pour copier les fixtures, comparer octets/SHA-256/emplacements et piloter erreurs, délais et réponses hors ordre ; brancher ces supports et les fixtures aux cibles dans une modification séquentielle de `outilVizMd.xcodeproj/project.pbxproj` après T004.
- [X] T006 [P] Rédiger le socle français de `README.md` : prérequis, commandes build/test, organisation par dossiers, cible macOS 14, lecture seule, UTF-8/10 Mio, autorisations temporaires et absence de restauration de session ; distinguer commandes prévues et résultats effectivement obtenus.

**Checkpoint** : outillage vérifié ; projet et dépendance résolus et squelette compilable avant les vérifications WebKit. Si Xcode manque, poursuivre les préparations réalisables et garder les validations exécutables bloquées explicitement.

## Phase 2 : Foundational — contrats communs et preuve technique

**But** : fixer les frontières de données, les générations et le chargement WebKit sûr. Cette phase bloque toutes les histoires.

- [X] T007 [P] Définir `AccessGrant`, `DocumentHandle` et `DocumentSnapshot` dans `outilVizMd/Documents/DocumentModels.swift` avec les champs de `data-model.md` et les contraintes « Temporaire ; jamais plus large que le choix explicite ; libération équilibrée », « Un même fichier ouvert ne crée pas deux entrées ; chemin réévalué après remplacement » et « Immuable, lecture bornée ; aucune méthode de sauvegarde » ; conserver les octets de référence et des valeurs immuables transmissibles entre tâches.
- [X] T008 [P] Définir les nœuds internes, `ParsedDocument`, `PreviewSnapshot` et `ResourceSnapshot` dans `outilVizMd/Markdown/ParsedDocument.swift` et `outilVizMd/Rendering/PreviewSnapshot.swift`, avec « Aucun HTML brut réinjecté ; types swift-markdown confinés à l’adaptateur », « Source, recherche et thème versionnés ; seul le dernier résultat attendu peut être affiché » et « Pas de chemin reçu de WebKit ; ressources immuables et isolées entre aperçus » ; représenter titres, ancres, projection visible et identifiants opaques sans exporter les types du moteur.
- [X] T009 [P] Définir `ReaderFailure` dans `outilVizMd/App/ReaderFailure.swift` avec catégorie, message français, récupération et document éventuel ; respecter « Aucun octet source dans les journaux ; ne change pas le document actif sans action » et couvrir accès refusé/révoqué, absent, encodage/type/taille, lecture instable, ressource, rendu et préférences.
- [X] T010 [P] Définir `RenderPreferences` et les valeurs initiales dans `outilVizMd/Preferences/RenderPreferences.swift` avec « Seule entité persistante ; écriture dans le conteneur de l’app » ; appliquer littéralement « Police identifiée parmi les polices locales ; disparition → police de repli. Taille finie de 12 à 32 points ; style parmi standard/compact/aéré ; couleurs sRGB finies dans 0…1. » ; prévoir schemaVersion 1, thème système et palettes claire/sombre distinctes, sans stockage de session.
- [X] T011 [P] Écrire `outilVizMdTests/Unit/GenerationGateTests.swift` pour publication hors ordre, changement de document et fermeture pendant un await ; vérifier que l’annulation seule ne suffit pas et qu’un résultat doit correspondre au document, à la source et à la présentation attendus (après T007–T009).
- [X] T012 Créer le squelette injectable de `outilVizMd/Documents/ReadingCoordinator.swift` et le filtre `outilVizMd/Documents/GenerationGate.swift`, après T007–T011 : état observable sur MainActor, services coûteux isolés hors MainActor, générations monotones, annulation et refus des publications tardives ; ne créer aucun protocole d’écriture ni pipeline d’édition.
- [X] T013 Créer `outilVizMd/Rendering/PreviewSecurityConfiguration.swift` et `outilVizMd/Resources/NetworkBlockRules.json` : JavaScript désactivé, magasin non persistant, aucun script/pont, CSP restrictive avec nonce neuf et règles WKContentRuleList bloquant HTTP(S) installées avant le chargement ; en cas d’échec d’installation, refuser le rendu ; exposer cette configuration à tous les futurs aperçus.
- [ ] T014 Valider les APIs publiques sur macOS 14 dans `outilVizMdTests/Integration/WebKitFeasibilityTests.swift` avec un gestionnaire de schéma de test : chargement `outilvizmd://preview/<jeton>/document`, tableau, fragment de titre, repères/compteur produits côté Swift et interactionState seulement pour une reconstruction identique ; consigner le résultat dans `specs/001-visualiser-markdown-local/validation/webkit-feasibility.md` et revoir la conception si impossible, sans JavaScript ni API privée.

**Checkpoint** : contrats communs et générations établis, preuve WebKit/tableaux/fragments obtenue. La preuve miniature ne remplace pas le moteur ni la recherche de production.

## Phase 3 : US1 — Ouvrir et lire un document local (P1) 🎯 première tranche

**But** : ouverture native, lecture bornée et rendu complet sûr, sans modifier le fichier.

**Test indépendant** : session vide et réseau coupé ; annuler puis ouvrir le corpus CommonMark, autoriser explicitement son dossier pour les images, consulter/copier/fermer et comparer octets et emplacement. Vérifier les états vide, chargement et erreur ainsi que les titres, tableaux, code et ancres.

### Tests avant implémentation

- [ ] T015 [P] [US1] Écrire `outilVizMdTests/Unit/DocumentAccessTests.swift` pour annulation, fichier seul sans accès aux voisins, périmètre par composants, lecture coordonnée, BOM/UTF-8 strict/fins de ligne, vide, 10 Mio exactement et +1 octet, croissance pendant lecture, fichier spécial, refus/absence et instabilité ; vérifier les octets et emplacements inchangés.
- [ ] T016 [P] [US1] Écrire `outilVizMdTests/Unit/MarkdownParserTests.swift` pour tous les éléments US1.3, Markdown incomplet, HTML brut échappé, titres dupliqués et correspondance projection/ordre du rendu ; n’imposer aucun type de la bibliothèque à l’interface interne.
- [ ] T017 [P] [US1] Écrire les tests de contrats `outilVizMdTests/Unit/RenderingContractTests.swift` pour échappement contextuel, images PNG/JPEG/GIF validées, alternatives d’erreur, schéma privé sans chemins, jetons isolés, MIME fermés et NavigationPolicy refusant toute destination sauf fragments contrôlés, routage local natif et clic HTTP(S) explicite.
- [ ] T018 [P] [US1] Écrire `outilVizMdTests/Integration/OpeningPreviewTests.swift` et l’extension `outilVizMdUITests/OpeningJourneyTests.swift` : panneau annulé sans changement, rendu utilisable, sélection/copie, absence de sauvegarde, crash WebKit récupérable et fermeture pendant chargement sans réapparition tardive ; utiliser les copies temporaires et l’observation du rendu plutôt qu’un simple test du parseur.

### Implémentation

- [ ] T019 [P] [US1] Implémenter `outilVizMd/Documents/AccessBroker.swift` et `outilVizMd/Documents/AuthorizedFileAccess.swift` après les tests : panneau natif et usages de sécurité équilibrés ; « Autorisation vérifiée pour chaque lecture, y compris ressources et réouverture après remplacement. Les chemins sont comparés par composants ; un préfixe textuel commun ne vaut pas appartenance. » ; « Les descendants comportant un lien symbolique sont refusés. Une cible choisie directement dans le panneau natif reçoit son propre périmètre. Refuser fichiers spéciaux et boucles. » ; ouvrir les descendants par descripteurs relatifs, composant par composant sans suivi de symlinks, sans course contrôle/ouverture ni autorisation implicite du parent.
- [ ] T020 [US1] Implémenter `outilVizMd/Documents/LocalDocumentReader.swift` après T019 : NSFileCoordinator en lecture seule hors MainActor, descripteur read-only et contrôles avant/après ; respecter « Taille maximale document : 10 × 1 024 × 1 024 octets ; ne jamais lire sans borne après un simple stat. » et « Décodage UTF-8 strict ; BOM toléré pour le décodage, conservé dans les octets de référence. Aucune normalisation du fichier source. Les fins de ligne peuvent être normalisées en mémoire. » ; lire au plus limite +1 octet, rejeter l’instabilité avec reprises bornées et publier un instantané immuable.
- [ ] T021 [P] [US1] Implémenter `outilVizMd/Markdown/MarkdownParser.swift` après T016 : adaptateur Swift Markdown 0.9.0 CommonMark et tableaux simples, sans directives DocC ni substitutions typographiques ; produire arbre interne, projection visible et ancres stables suffixées pour doublons ; HTML brut rendu comme texte échappé, aucun AST de la dépendance ne franchissant sa tâche.
- [ ] T022 [US1] Implémenter `outilVizMd/Rendering/LocalImageLoader.swift` après T019 : « Images PNG/JPEG/GIF validées par signature et décodage ImageIO ; GIF rendu sur sa première image. Appliquer un budget de décodage et mémoire, arrêter proprement si dépassé ; ne pas servir un MIME fourni par le document. Le corpus de référence respecte le budget d’images défini dans spec.md. » ; définir des budgets bornés testables, vérifier dimensions/produits sans débordement avant allocation, réencoder le GIF en PNG et fournir texte alternatif/indisponibilité pour les refus.
- [ ] T023 [US1] Implémenter `outilVizMd/Rendering/PreviewResourceStore.swift` et `outilVizMd/Rendering/PreviewSchemeHandler.swift` après T022 : jetons aléatoires non devinables, instantanés en mémoire et grammaire exacte `outilvizmd://preview/<jeton>/document` ou `/resource/<id>`, fragments séparés ; rejeter query, hôte/segment ambigu, ressource inconnue et jeton expiré, sans repli fichier ; MIME uniquement text/html, text/css, image/png, image/jpeg ; sérialiser start/stop, ne plus émettre de callback après stop et libérer après fin/annulation des tâches.
- [ ] T024 [US1] Implémenter `outilVizMd/Rendering/SafeHTMLRenderer.swift` et `outilVizMd/Resources/ReaderBase.css` après T021–T023 : liste fermée de balises/attributs, échappement contextuel, CSS généré local avec nonce et configuration T013 ; titres 1–6, listes, citations, tableaux défilables, liens tokenisés, code préservé et images à largeur bornée ; ne générer aucun file://, SVG, iframe, script, formulaire, @import ou sous-ressource distante ; utiliser les valeurs initiales T010 sans attendre US4.
- [ ] T025 [P] [US1] Implémenter `outilVizMd/Rendering/NavigationPolicy.swift` après T017 : refus par défaut, ancres existantes uniquement, liens locaux reroutés via identifiants natifs et refus lisible hors périmètre ; HTTP(S) validé uniquement après action utilisateur via un ouvreur système injectable, jamais en affichage passif ; bloquer autres schémas, popups, téléchargements et nouvelles fenêtres.
- [ ] T026 [US1] Implémenter `outilVizMd/Rendering/PreviewWebView.swift` après T023–T025 : NSViewRepresentable/MainActor, application préalable de T013, fragments sans JavaScript, sélection/copie natives, erreurs de navigation et crash du processus avec récupération ; restaurer interactionState uniquement si URL/contenu/CSS/ressources identiques, jamais après modification ; un fragment explicite prime.
- [ ] T027 [US1] Relier autorisation → lecture → analyse → ressources → rendu → affichage dans `outilVizMd/Documents/ReadingCoordinator.swift` après T020–T026 : contrôles document/source/présentation après chaque await, chargement annulable, états vide/prêt/erreur et fermeture libérant vue, travaux, jetons et usages ; aucun travail coûteux sur MainActor ni écriture source.
- [ ] T028 [US1] Créer `outilVizMd/App/ReaderWindow.swift` et `outilVizMd/App/ReaderStatusView.swift`, puis composer la fenêtre unique dans `outilVizMd/App/outilVizMdApp.swift` : actions visibles Ouvrir un fichier/Ouvrir un dossier, explication courte, nom/chemin, chargement annulable, Document vide, erreurs françaises et récupération ; l’action dossier peut autoriser les images dès US1, son arbre arrive en US2.
- [ ] T029 [US1] Ajouter `outilVizMd/App/ReaderCommands.swift` avec Cmd+O, fermeture du document Cmd+W et focus/accessibilité nommés ; fermer le dernier document revient à l’accueil ; aucune commande d’édition, sauvegarde, export, autosave ou suppression du source.
- [ ] T030 [US1] Faire réussir T015–T018 et exécuter le parcours de lecture hors ligne dans `specs/001-visualiser-markdown-local/validation/us1.md` : rendu de chaque élément, images après autorisation, erreurs récupérables, annulation et préservation octet par octet ; signaler les validations impossibles sur le poste. La tranche reste soumise au contrôle de sécurité US6 avant démonstration.

**Checkpoint** : US1 consultable indépendamment, avec les protections actives et les sources intactes.

## Phase 4 : US2 — Parcourir un dossier et naviguer entre documents (P1)

**But** : arbre paresseux, documents multiples et bascule sans perdre la position d’une page inchangée.

**Test indépendant** : choisir un dossier avec trois documents, dont deux homonymes ; ouvrir, revenir au premier, suivre un lien local, fermer l’actif, puis ajouter/supprimer un fichier de l’extérieur et actualiser la liste. Vérifier refus des symlinks et absence de doublon/écriture.

### Tests avant implémentation

- [ ] T031 [P] [US2] Écrire `outilVizMdTests/Unit/DirectoryNavigatorTests.swift` pour lecture d’un seul niveau, tri, filtrage `.md`/`.markdown` insensible à la casse, sous-dossiers dépliés à la demande, vide/inaccessible, rafraîchissement explicite et descendants symlinks/cycles refusés.
- [ ] T032 [P] [US2] Écrire `outilVizMdTests/Unit/ReadingSessionTests.swift` pour actif unique, déduplication par identité, chemins homonymes, sélection et fermeture déterministes, suppression de la dernière entrée et libération des usages sans écriture ni persistance de session.
- [ ] T033 [P] [US2] Écrire `outilVizMdTests/Integration/LocalLinkContractTests.swift` pour lien Markdown autorisé, fragment de destination, cible hors périmètre/encodage ambigu refusés avant lecture et sélection explicite annulée sans changer l’actif ; instrumenter l’adaptateur d’accès pour vérifier l’absence de lecture interdite.
- [ ] T034 [P] [US2] Écrire `outilVizMdTests/Integration/DocumentSwitchingTests.swift` et `outilVizMdUITests/NavigationJourneyTests.swift` pour trois documents, deux homonymes, conservation de position via vues retenues, fermeture pendant chargement et refresh manuel du dossier, avec comparaison des sources.

### Implémentation

- [ ] T035 [P] [US2] Définir `ReadingSession` et `NavigationEntry` dans `outilVizMd/Navigation/ReadingSession.swift` et `outilVizMd/Navigation/NavigationEntry.swift` : champs de `data-model.md`, « Un actif au maximum, fermeture sans écriture ; pas de persistance » et « Fichiers Markdown filtrés, dossiers paresseux, pas de suivi des symlinks descendants » ; documentIDs ordonnés et erreurs de chargement par entrée.
- [ ] T036 [P] [US2] Implémenter `outilVizMd/Navigation/DirectoryNavigator.swift` après T031/T035 sur l’accès T019 : énumération autorisée hors MainActor d’un seul niveau, filtrage/tri, chargement paresseux, refresh explicite et états vide/inaccessible ; ne pas indexer récursivement ni surveiller toute l’arborescence.
- [ ] T037 [US2] Étendre `outilVizMd/Documents/ReadingCoordinator.swift` après T032/T035 pour gérer session ordonnée, identités physiques et réévaluation après remplacement, homonymes, déduplication, actif unique et choix du prochain actif à la fermeture ; retirer vues/travaux/autorisations et empêcher la réapparition d’une entrée fermée.
- [ ] T038 [US2] Créer `outilVizMd/Navigation/SidebarView.swift` et `outilVizMd/Navigation/OpenDocumentsList.swift` après T036–T037, puis les intégrer dans `outilVizMd/App/ReaderWindow.swift` : dossiers dépliables, chemins distinctifs, sélection, fermeture, erreurs locales et action Actualiser le dossier, accessibles au clavier et à VoiceOver.
- [ ] T039 [P] [US2] Créer `outilVizMd/Rendering/PreviewRegistry.swift` après T035 et l’intégrer séquentiellement dans `outilVizMd/Rendering/PreviewWebView.swift` : retenir exactement une WKWebView par document ouvert, réutiliser sans rechargement lors d’une simple bascule et libérer à la fermeture ; ne jamais restaurer un ancien état opaque sur un HTML/CSS/jeu de ressources différent.
- [ ] T040 [US2] Implémenter `outilVizMd/Navigation/LocalLinkRouter.swift` après T033/T037 et le brancher dans `outilVizMd/Rendering/NavigationPolicy.swift` : résoudre côté natif les jetons vers Markdown et ancres autorisés, ouvrir/activer sans navigation file://, proposer une sélection explicite pour un refus sans étendre silencieusement le grant.
- [ ] T041 [US2] Relier Ouvrir un dossier, navigation clavier, sélection et Actualiser le dossier dans `outilVizMd/App/ReaderCommands.swift` et `outilVizMd/Documents/ReadingCoordinator.swift` après T038–T040 ; annuler une sélection doit laisser l’actif et le dossier existants intacts.
- [ ] T042 [US2] Faire réussir T031–T034 et consigner le parcours indépendant ainsi que la libération après fermeture dans `specs/001-visualiser-markdown-local/validation/us2.md` ; mesurer la bascule et l’arbre ultérieurement dans la phase finale, sans annoncer SC-002/SC-008 sur une seule observation.

**Checkpoint** : navigation fonctionnelle après US1 ; recherche et préférences non nécessaires à sa validation.

## Phase 5 : US6 — Consulter un document non fiable en sécurité (P1)

**But** : prouver les protections déjà livrées dans les fondations/US1/US2 et rendre les refus récupérables. Cette phase est un verrou de livraison de toutes les tranches.

**Test indépendant** : corpus hostile et fichiers témoins hors périmètre, réseau disponible puis coupé ; observer exécution, accès et tentatives de chargement, tester clics autorisés/refusés et comparer les sources. Aucun résultat de sécurité n’est déduit de la seule absence de connexion observée.

### Tests et corpus avant intégration de la récupération

- [ ] T043 [P] [US6] Compléter `outilVizMdTests/Fixtures/Malicious/` et écrire `outilVizMdTests/Unit/UntrustedRenderingTests.swift` pour HTML/script/événements, styles/CSS, SVG/iframe/formulaire, javascript:/data:/file:, URL absolues/relatives, encodages multiples et Markdown mal formé ; vérifier échappement/refus et maintien d’un reste lisible avec alternative d’image.
- [ ] T044 [P] [US6] Écrire `outilVizMdTests/Integration/AccessRaceTests.swift` : liens symboliques descendants sortants et permutés pendant lecture, préfixes de dossiers trompeurs, boucles/fichiers spéciaux, remplacement d’identité et révocation ; instrumenter les descripteurs pour prouver qu’aucun octet hors grant n’est lu, y compris images et liens de documents.
- [ ] T045 [P] [US6] Écrire `outilVizMdTests/Integration/ResourceIsolationTests.swift` : grammaire exacte du schéma privé, MIME et signatures, images invalides/trop coûteuses, jeton d’un autre aperçu, expiré ou révoqué, annulation start/stop, fermeture pendant chargement et absence de callback après stop ; vérifier absence de chemin disque et de fallback.
- [ ] T046 [P] [US6] Créer `outilVizMdTests/Support/NetworkProbe.swift` et `outilVizMdTests/Integration/NoAutomaticNetworkTests.swift` : serveur local réservé à la cible de tests, instrumentation des demandes/rejets WebKit et observation des tentatives app/WebKit ; vérifier blocage des sous-ressources HTTP(S) avant envoi, échec fermé si règles indisponibles, JS sans exécution, magasin non persistant et aucun téléchargement/popup ; ne livrer ni serveur ni instrumentation sensible dans l’app.
- [ ] T047 [P] [US6] Écrire `outilVizMdTests/Integration/ExternalNavigationTests.swift` avec ouvreur système injectable : affichage passif sans ouverture, clic HTTP(S) validé exactement une fois, refus des autres schémas/redirections de ressources et absence de Launch Services pour le schéma interne ; couvrir sélection d’autorisation annulée sans accès ni changement d’actif.

### Intégration et validation

- [ ] T048 [US6] Créer `outilVizMd/App/ResourceAccessNoticeView.swift` et l’intégrer dans `outilVizMd/App/ReaderStatusView.swift` et `outilVizMd/Navigation/LocalLinkRouter.swift` après T043–T047 : messages français pour contenu/lien/image refusés, texte alternatif et action de sélection explicite du fichier ou dossier nécessaire ; conserver le document actif en cas d’annulation et ne jamais autoriser le parent implicitement.
- [ ] T049 [US6] Exécuter les tests adversariaux T043–T047 et les cycles répétés ouvrir/annuler/fermer, puis corriger toute violation dans `outilVizMd/Documents/AuthorizedFileAccess.swift`, `outilVizMd/Rendering/PreviewSchemeHandler.swift`, `outilVizMd/Rendering/PreviewSecurityConfiguration.swift` ou `outilVizMd/Rendering/NavigationPolicy.swift` en conservant un test de régression ; aucune protection ne peut être relâchée pour faire passer le corpus.
- [ ] T050 [US6] Consigner les preuves observables de T043–T049 dans `specs/001-visualiser-markdown-local/validation/us6-security.md` : droits signés du bundle, source inchangée, aucun accès hors périmètre, aucune exécution/connexion automatique réseau disponible, puis lecture/navigation hors ligne ; réserver la répétition recherche/thèmes/relance au contrôle transversal T079 après US3–US5.

**Checkpoint** : US1 + US2 + US6 constituent la tranche P1 démontrable si tous les contrôles exécutables sont réussis. Un échec essentiel bloque la livraison.

## Phase 6 : US3 — Rechercher dans le document actif (P2)

**But** : recherche littérale du texte affiché avec compteur, repères et parcours sans JavaScript.

**Test indépendant** : ouvrir directement un document comportant titres/tableaux/code et termes répartis sur plusieurs nœuds ; Cmd+F, casse/accents/caractères spéciaux, boucle avant/arrière, zéro résultat, Échap puis changement de document. Vérifier total logique et source inchangée.

### Tests avant implémentation

- [ ] T051 [P] [US3] Écrire `outilVizMdTests/Unit/SearchIndexerTests.swift` pour projection commune au rendu, normalisation des séparations, recherche Unicode littérale sans casse mais avec accents, frontières valides, occurrences non chevauchantes et traversant plusieurs nœuds ; exclure href/balises invisibles et inclure titres/tableaux/code ainsi que les alternatives effectivement affichées.
- [ ] T052 [P] [US3] Écrire `outilVizMdTests/Unit/SearchRenderingContractTests.swift` pour un identifiant logique par occurrence, segments mark par nœud, ancres échappées, compteur cohérent, requête hostile inerte, requête vide retirant les repères et absence de remplacement textuel dans du HTML déjà généré.
- [ ] T053 [P] [US3] Écrire `outilVizMdTests/Integration/SearchJourneyTests.swift` et `outilVizMdUITests/SearchJourneyTests.swift` pour total/position, visibilité du résultat, boucle, Échap/focus, reset au changement de document et rejet de réponses hors ordre après saisie/changement/fermeture.

### Implémentation

- [ ] T054 [P] [US3] Définir `VisibleTextIndex` dans `outilVizMd/Search/VisibleTextIndex.swift` après T051 : texte canonique, plages vers nœuds/offsets et frontières de blocs avec « Même contenu que le rendu ; plages sur frontières Unicode valides » ; documenter la règle commune de normalisation et exploiter la projection créée en T021 sans modifier les sources.
- [ ] T055 [P] [US3] Définir `SearchState` dans `outilVizMd/Search/SearchState.swift` après T051 : documentID, génération source, queryGeneration, requête, plages et index courant ; respecter « Temporaire ; total = nombre d’occurrences logiques non chevauchantes » et réinitialisation à la fermeture/changement de document.
- [ ] T056 [US3] Implémenter `outilVizMd/Search/SearchIndexer.swift` après T054–T055 : recherche hors MainActor, littérale Unicode sans casse/sensible aux accents, plages non chevauchantes vers les nœuds et résultats versionnés ; aucun appel JavaScript, expression régulière de requête ou accès au DOM.
- [ ] T057 [P] [US3] Créer `outilVizMd/Search/SearchMarkup.swift` après T052/T054–T055 puis l’utiliser séquentiellement dans `outilVizMd/Rendering/SafeHTMLRenderer.swift` : marques échappées et fragments côté Swift, une occurrence logique pouvant avoir plusieurs segments ; retirer les repères avec requête vide sans restaurer un ancien interactionState après changement du HTML.
- [ ] T058 [US3] Créer `outilVizMd/Search/SearchController.swift` et le relier dans `outilVizMd/Documents/ReadingCoordinator.swift` après T056–T057 : incrémenter queryGeneration, revalider document/source/requête et présentation après chaque await, abandonner résultats périmés, parcourir avec boucle et reconstruire seulement la présentation ; un fragment explicite prime sur la position précédente.
- [ ] T059 [US3] Créer `outilVizMd/Search/SearchBar.swift` et intégrer Cmd+F, précédent/suivant, compteur/position, zéro résultat et Échap dans `outilVizMd/App/ReaderWindow.swift` et `outilVizMd/App/ReaderCommands.swift` après T058 ; rendre le focus à la lecture, effacer requête/repères en fermant ou en changeant de document, nommer les contrôles pour VoiceOver.
- [ ] T060 [US3] Faire réussir T051–T053 et consigner le parcours indépendant ainsi que les comparaisons de sources dans `specs/001-visualiser-markdown-local/validation/us3.md` ; inclure document vide, requêtes denses et occurrence traversant plusieurs nœuds ; mesurer les seuils SC-003 dans T077–T078.

**Checkpoint** : recherche validable par ouverture directe, sans navigation de dossier, thème personnalisé ni suivi externe.

## Phase 7 : US4 — Personnaliser et retrouver son confort de lecture (P2)

**But** : régler le rendu et conserver uniquement les préférences globales validées dans le conteneur.

**Test indépendant** : ouvrir un fichier directement, modifier chaque réglage et chaque palette ; trois cycles quitter/relancer/rouvrir, changement d’apparence système, valeurs invalides/police absente/échec de stockage, puis reset durable. Aucun document ni grant n’est restauré au lancement.

### Tests avant implémentation

- [ ] T061 [P] [US4] Écrire `outilVizMdTests/Unit/PreferencesStoreTests.swift` avec store temporaire : aller-retour exact et trois chargements après réouverture, absence/JSON corrompu/champs invalides/version inconnue, taille NaN/hors bornes, couleur non finie, police absente, erreur d’écriture/remplacement et reset durable ; vérifier repli champ par champ, choix valides conservés, aucun document/grant persisté ni préférence réelle modifiée.
- [ ] T062 [P] [US4] Écrire `outilVizMdTests/Unit/ThemeResolverTests.swift` pour clair/sombre/système, suivi de l’apparence, palettes séparées, polices locales/repli et code monospace, styles standard/compact/aéré, limites de taille/couleur, échappement des noms CSS et avertissement texte/fond ou lien/fond sous 4,5:1 sans bloquer le réglage.
- [ ] T063 [P] [US4] Écrire `outilVizMdUITests/PreferencesJourneyTests.swift` et `outilVizMdTests/Integration/ThemePresentationTests.swift` : chaque réglage appliqué, trois vrais cycles de relance avec conteneur de test isolé, reset suivi de relance, échec de stockage visible avec valeurs conservées en mémoire, changements rapides de thème/recherche sans présentation périmée ni écriture source.

### Implémentation

- [ ] T064 [P] [US4] Implémenter `outilVizMd/Preferences/PreferencesStore.swift` après T061 en réutilisant T010 : « Préférences invalides : repli champ par champ. JSON absent → valeurs initiales ; version inconnue → valeurs sûres et avertissement. Aucune donnée invalide n’est interpolée dans le CSS. » ; `preferences.json` version 1 dans Application Support du conteneur, temporaire puis remplacement atomique dans ce même conteneur, erreurs remontées et réglages gardés en mémoire ; aucune écriture en dehors du store ni persistance de chemins/grants.
- [ ] T065 [P] [US4] Implémenter `outilVizMd/Themes/ThemeResolver.swift`, `outilVizMd/Themes/LocalFontCatalog.swift` et `outilVizMd/Themes/ContrastCalculator.swift` après T062 : valeurs contrôlées, apparence système ou explicite, palettes distinctes, contraste 4,5:1, code monospace et styles prédéfinis ; respecter « Les noms de polices sont échappés comme valeurs CSS ; les couleurs et nombres sont sérialisés par l’app. Aucun texte utilisateur libre n’est interprété comme CSS. » ; aucune ressource distante ni import de thème/CSS libre.
- [ ] T066 [US4] Créer `outilVizMd/Preferences/PreferencesView.swift` après T064–T065 : contrôles natifs thème, police locale, taille 12–32, style, couleurs texte/fond/liens du thème actif, contraste, retour aux couleurs initiales et réinitialisation complète ; messages français et accès clavier/VoiceOver, sans bloquer une personnalisation peu contrastée.
- [ ] T067 [US4] Brancher chargement au lancement, sauvegarde/reset, résolution d’apparence et Settings/Cmd+, dans `outilVizMd/App/outilVizMdApp.swift`, `outilVizMd/App/ReaderCommands.swift` et `outilVizMd/Documents/ReadingCoordinator.swift` après T066 ; appliquer interface et rendu à tous les documents, incrémenter presentationGeneration sans toucher au snapshot source, exclure les réponses de thème périmées et ne pas restaurer l’état opaque d’une page au CSS changé.
- [ ] T068 [US4] Faire réussir T061–T063 et consigner trois cycles de relance, chaque valeur restaurée, reset, repli et erreur de stockage dans `specs/001-visualiser-markdown-local/validation/us4.md` ; vérifier octets/emplacements sources et les deux apparences, puis mesurer SC-006 dans T077–T078.

**Checkpoint** : personnalisation persistante vérifiable avec un fichier ouvert directement, sans dépendance à US2/US3/US5.

## Phase 8 : US5 — Suivre les modifications externes (P2)

**But** : refléter la dernière version stable, gérer suppression/remplacement et ne jamais faire passer un ancien aperçu pour actuel.

**Test indépendant** : ouvrir directement un document et le modifier depuis le support externe des tests par écriture directe puis remplacement atomique ; rafale de dix sauvegardes, suppression/recréation au même chemin, révocation et réactivation d’un document inactif. L’app ne recrée aucun fichier.

### Tests avant implémentation

- [ ] T069 [P] [US5] Écrire `outilVizMdTests/Unit/DocumentMonitorTests.swift` avec horloge/événements contrôlés : écriture/renommage/suppression/révocation, perte d’événement couverte par contrôle 500 ms, débattement 150 ms, reprises bornées, remplacement atomique et arrêt/libération à la fermeture ; aucune autorisation implicite du parent d’un fichier seul.
- [ ] T070 [P] [US5] Écrire `outilVizMdTests/Integration/ExternalChangeTests.swift` et `outilVizMdUITests/ExternalChangeJourneyTests.swift` : écriture directe/remplacement, dix sauvegardes, lecture instable/UTF-8 transitoire, suppression/déplacement/recréation, résultats hors ordre, document inactif puis actif, recherche recalculée et thème concurrent ; comparer aux nouvelles versions intentionnellement produites par le support externe, sans attribuer ces écritures au lecteur.

### Implémentation

- [ ] T071 [US5] Implémenter `outilVizMd/Documents/DocumentMonitor.swift` après T069 : DispatchSource du fichier, parent seulement s’il est déjà autorisé, métadonnées du document actif toutes les 500 ms et lors de l’activation, débattement 150 ms et reprises bornées ; revalider accès/identité à chaque réouverture, réarmer après remplacement et arrêter sources/timers/descripteurs à la fermeture, sans surveillance récursive.
- [ ] T072 [US5] Créer `outilVizMd/Documents/RefreshController.swift` et le brancher dans `outilVizMd/Documents/ReadingCoordinator.swift` après T071 : transitions prêt → rafraîchissement → prêt/obsolète, générations monotones, dernier aperçu conservé pendant lecture, relecture sûre T020 et publication de la seule dernière version ; « Ne pas suivre silencieusement un déplacement hors périmètre. L’utilisateur peut sélectionner le nouvel emplacement. Les événements de remplacement au même chemin déclenchent une réévaluation. »
- [ ] T073 [US5] Ajouter l’état « aperçu non à jour », Réessayer/Sélectionner/Fermer et Actualiser le document dans `outilVizMd/App/ReaderStatusView.swift` et `outilVizMd/App/ReaderCommands.swift` après T072 ; retirer l’avertissement seulement après succès, conserver l’ancien aperçu en cas d’échec et proposer la récupération sans recréer ni déplacer le fichier.
- [ ] T074 [US5] Relier réactivation, recherche et position dans `outilVizMd/Documents/ReadingCoordinator.swift`, `outilVizMd/Search/SearchController.swift` et `outilVizMd/Rendering/PreviewRegistry.swift` après T072–T073 : revérifier avant de déclarer l’inactif à jour, recalculer la requête existante sur la nouvelle source, réutiliser au mieux une ancre sémantique connue sinon le début valide, sans restaurer interactionState après changement de contenu/CSS/ressources ; la recherche explicite prime.
- [ ] T075 [US5] Faire réussir T069–T070 et consigner direct/remplacement/rafale/suppression/recréation/révocation dans `specs/001-visualiser-markdown-local/validation/us5.md`, avec absence d’inversion et comparaison aux sources attendues ; mesurer ensuite SC-004 dans T077–T078.

**Checkpoint** : US5 seule se vérifie après US1 ; T074 complète son intégration avec US2/US3/US4 quand ces tranches sont disponibles.

## Phase 9 : Polish — validation transversale et livraison

**But** : satisfaire les seuils mesurés, l’aide, l’accessibilité et les preuves de compatibilité. Dépend des six parcours.

- [ ] T076 [P] Créer `outilVizMdTests/Support/PerformanceCorpus.swift` et `outilVizMdTests/Fixtures/Performance/manifest.json` pour générer les documents représentatifs 1/10 Mio, images locales totalisant au plus 5 Mio par document, requêtes denses et dossier de 1 000 entrées ; enregistrer tailles/empreintes et générer les fichiers volumineux dans un répertoire temporaire.
- [ ] T077 Écrire `outilVizMdTests/Performance/ReadingPerformanceTests.swift` et `outilVizMdUITests/PerformanceJourneyTests.swift` après T076 : mesure de l’action utilisateur au rendu utilisable pour ouverture, bascule, navigation/annulation, recherche, thème, actualisation externe/rafale et dossier, avec vingt répétitions par seuil ; ne pas utiliser le seul temps du parseur pour certifier une latence utilisateur.
- [ ] T078 Exécuter T077 sur Apple Silicon ≥ 8 Go et consigner environnement/corpus/20 mesures/seuil dans `specs/001-visualiser-markdown-local/validation/performance.md` : 19/20 conformes pour ouverture 1 s/3 s (1/10 Mio), bascule et retour navigation/annulation < 300 ms, recherche 300 ms/1 s, thème 300 ms/1 s, changement externe et dix sauvegardes 2 s/5 s après stabilisation, dossier 1 000 entrées < 1 s ; mesurer aussi mémoire/pics avec dix documents, libération après fermeture et récupération WebKit, et corriger les points coûteux avant de refaire seulement les mesures affectées.
- [ ] T079 [P] Écrire et exécuter `outilVizMdTests/Integration/ReadOnlyOfflineRegressionTests.swift` après US1–US6 : tous les parcours US1–US5 hors ligne, recherche/thèmes/relance inclus, puis corpus hostile réseau disponible ; comparer octets/emplacements dans 100 % des cas, isoler les modifications externes intentionnelles, vérifier tous les messages/récupérations et compléter `specs/001-visualiser-markdown-local/validation/us6-security.md` sans masquer les validations non exécutées.
- [ ] T080 [P] Rédiger `outilVizMd/Resources/Aide.md`, créer `outilVizMd/App/HelpView.swift` et terminer `README.md` : ouvrir, naviguer, rechercher, personnaliser, autoriser les images et comprendre lecture seule/hors ligne/UTF-8/10 Mio, aide accessible par le menu sans réseau, architecture et commandes exactes ; intégrer séquentiellement les ressources/cible dans `outilVizMd.xcodeproj/project.pbxproj`.
- [ ] T081 [P] Vérifier les licences du graphe réellement résolu de T003 et embarquer les textes applicables dans `outilVizMd/Resources/ThirdPartyNotices.txt`, dont Apache 2.0 avec Runtime Library Exception et notices transitives swift-cmark ; rendre les notices consultables hors ligne et ajouter séquentiellement la ressource dans `outilVizMd.xcodeproj/project.pbxproj`.
- [ ] T082 Effectuer le contrôle clavier/VoiceOver/clair/sombre de chaque action et état, puis le parcours SC-007 avec cinq débutants et l’aide T080 seule ; consigner observations et durées dans `specs/001-visualiser-markdown-local/validation/accessibility-usability.md`, exiger au moins quatre réussites sous cinq minutes et corriger les obstacles ; ne pas déduire le résultat humain des tests UI et laisser ce contrôle non validé si les participants manquent.
- [ ] T083 Exécuter build/test du scheme partagé, validation réelle macOS 14, architectures arm64 et x86_64 annoncées, et nouvelle compilation/test hors ligne après cache des dépendances ; relever les résultats, signatures/droits et limites réelles dans `specs/001-visualiser-markdown-local/validation/platforms.md`, sans désactiver le sandbox ni certifier une plateforme non exécutée.
- [ ] T084 Exécuter les scénarios de `specs/001-visualiser-markdown-local/quickstart.md`, mettre ce guide et `README.md` à jour pour l’état réellement livré et créer `specs/001-visualiser-markdown-local/validation/acceptance.md` reliant FR-001–FR-018 et SC-001–SC-008 aux preuves US1–US6/performance/accessibilité/plateformes ; relever tout contrôle bloqué ou échoué, et n’autoriser une livraison que lorsque les contrôles essentiels sont réussis.

## Dépendances et ordre d’exécution

### Graphe des parcours

```text
Phase 1 Setup → Phase 2 Fondations → US1 (lecture sûre)
                                      ├── US2 (navigation) ──┐
                                      ├─────────────────────┴→ US6 (preuve sécurité P1)
                                      ├── US3 (recherche)
                                      ├── US4 (préférences)
                                      └── US5 (suivi externe)

US2 + US3 + US4 + US5 + US6 → Phase 9 validation finale
US2/US3/US4 → intégrations croisées de T074
US3/US4/US5 → répétition complète du contrôle hors ligne en T079
```

- **Ordre recommandé** : T001–T014 → US1 → US2 → US6 → US3 → US4 → US5 → phase finale. Les trois P1 précèdent les P2 ; aucune démonstration ne précède les preuves de sécurité.
- **US1** dépend des fondations ; aucun autre parcours requis. Son action dossier autorise les images, sans attendre l’arbre US2.
- **US2** réutilise les services lecture/rendu US1. Ses tests d’état/navigation ne requièrent pas les P2.
- **US6** peut préparer ses tests après US1 ; son contrôle complet des liens entre documents utilise US2. Ses protections ne sont pas différées : T019–T026 sont obligatoires dès US1.
- **US3 et US4** dépendent de US1 uniquement pour une validation indépendante. Leurs tests/services distincts peuvent être préparés en parallèle après le verrou P1. L’intégration dans les fichiers partagés reste séquentielle.
- **US5** dépend de US1 pour sa boucle de rafraîchissement ; ses intégrations T074 utilisent les autres P2 et US2. Son parcours minimal se teste sans recherche ni personnalisation.
- **Finalisation** : T076 → T077 → T078 ; T080 → T082 ; T078/T079/T081/T082/T083 → T084. T079/T080/T081 peuvent avancer dans des fichiers distincts après les parcours. Les modifications du projet Xcode restent sérialisées.

### À l’intérieur d’une tranche

1. Préparer les tests/fixtures, constater l’échec attendu, puis définir les modèles et implémenter les services.
2. Intégrer les services avant la présentation ; ne jamais publier un résultat asynchrone sans revalider les générations.
3. Faire réussir les tests ciblés et le test indépendant ; consigner les contrôles exécutés et les contrôles bloqués séparément.
4. Ne pas cocher une tâche dont la preuve d’exécution requise est absente. Un manque de Xcode bloque les builds/tests, pas la rédaction ou les tâches de préparation réalisables.

## Exemples d’exécution parallèle par parcours

Ces exemples décrivent des possibilités d’implémentation ; ils ne déclenchent aucun agent ni travail parallèle automatiquement. Les lots commencent seulement après leurs prérequis. Ne pas modifier un fichier partagé simultanément.

| Parcours | Lot indépendant possible | Synchronisation suivante |
|----------|--------------------------|--------------------------|
| US1 | T015 accès, T016 parseur, T017 rendu, T018 intégration/UI dans des fichiers distincts | Après les tests, T019 accès et T021 parseur ; T020/T022 attendent T019, puis pipeline T027 |
| US2 | T031 navigation, T032 session, T033 liens, T034 intégration/UI | T035 avant T036 ; T037 et intégrations T038–T041 séquentielles ; T039 peut créer son registre à part avant intégration |
| US6 | T043 corpus/rendu, T044 courses d’accès, T045 ressources, T046 réseau, T047 clics | T048 récupération puis T049 corrections partagées et T050 preuves |
| US3 | T051 index, T052 repères, T053 parcours ; ensuite T054 et T055 | Après les modèles, T056 indexeur et T057 générateur de repères ; T058–T059 intégration séquentielle |
| US4 | T061 stockage, T062 thèmes, T063 parcours ; ensuite T064 store et T065 resolver | T066 interface puis T067 intégration et T068 validation |
| US5 | T069 surveillance et T070 scénarios externes dans des fichiers distincts | T071 → T072 → T073 → T074 → T075 ; pas de parallélisation des modifications du coordinateur |

Autres possibilités : T004/T006 pendant la préparation des cibles, T007–T010 pour les modèles, et T079/T080/T081 en finition ; T005 attend les fixtures avant leur branchement. Chaque `[P]` est conditionnel aux dépendances de sa tâche, pas une permission de passer outre une fondation incomplète.

## Stratégie d’implémentation

### MVP d’abord

1. Préparer projet, dépendances et fondations ; prouver le schéma WebKit, les fragments et les tableaux sur macOS 14.
2. Implémenter US1 comme première tranche verticale avec accès sûr, rendu sûr, erreurs et préservation vérifiée.
3. Ajouter US2 et terminer US6 avant la démonstration de la tranche P1. Le cœur du MVP est US1 ; la navigation demandée et les garanties de sécurité rendent le lot P1 complet US1 + US2 + US6.
4. Livrer progressivement les P2 US3, US4 puis US5, chacun avec son propre test indépendant ; le MVP fonctionnel décrit dans la spécification comprend les six parcours.
5. Terminer les mesures et validations transversales avant livraison. Ne pas inclure édition, export, bookmarks persistants, serveur, plugins, recherche globale ou CSS libre.

### Traçabilité des exigences

| Exigences | Tâches principales | Preuves |
|-----------|--------------------|---------|
| FR-001, FR-004, FR-015, FR-017 | T015–T030 | T030 ; SC-001/002/008 via T077–T078 |
| FR-002–003 | T031–T042 | T042 ; bascule/dossier via T077–T078 |
| FR-005 | T017, T021–T026, T033, T040 | T030/T042/T045 |
| FR-006 | T051–T060 | T060 ; SC-003 via T077–T078 |
| FR-007–009 | T010, T061–T068 | T068 ; SC-006 via T077–T078 |
| FR-010–011 | T069–T075 | T075 ; SC-004 via T077–T078 |
| FR-012–014 | T002, T013, T015, T019–T026, T043–T050 | T050/T079 ; SC-005/008 |
| FR-016, FR-018 | T028–T029, T038, T041, T059, T066–T067, T080–T082 | T082 ; SC-007 et réactivité T078 |

## Notes de validation

- 84 tâches : Setup 6, fondations 8, US1 16, US2 12, US6 8, US3 10, US4 8, US5 7, finition 9.
- Les contraintes entre guillemets dans les tâches reprennent le modèle de données ; elles s’appliquent aux types et à tous leurs services consommateurs.
- Les rapports `validation/` sont des preuves à produire pendant l’implémentation, pas des validations déjà obtenues.
- État au 2026-11-06 après correction WebKit : T001–T013 terminées ; les 12 tests actuels passent sur macOS 26.6.2 et la sonde d’affichage passif relève zéro connexion. T014 reste non cochée uniquement pour la validation réelle macOS 14 ; T015–T084 non commencées. Voir `validation/webkit-feasibility.md`. Le checkpoint macOS 14 reste à satisfaire avant les parcours suivants.
