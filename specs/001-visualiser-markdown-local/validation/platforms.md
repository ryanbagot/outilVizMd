# Plateformes — portée de validation

Poste courant : MacBook Pro Apple M5 Pro, 24 Gio, macOS 26.6.2 (25G83), Xcode 27.2, Swift 6.4.2. La cible de déploiement est macOS 14, mode Swift 5 et concurrence complète.

Les tests fonctionnels utilisent le test host ad hoc. Xcode injecte des droits temporaires propres au chargement XCTest (notamment accès aux fixtures) ; ils ne sont pas les droits du produit de distribution. Les garanties logiques des grants sont testées séparément par les accès ancrés. Le contrôle du bundle produit doit porter sur une compilation normale, après les tests.

Le chargement XCTest d’un build Release ad hoc a été refusé par la validation des bibliothèques (identités de signature). Les mesures utilisent donc Debug optimisé `SWIFT_OPTIMIZATION_LEVEL=-O`, avec `ENABLE_HARDENED_RUNTIME=NO` limité à la commande du test host. Le projet conserve Hardened Runtime pour le produit ; le sandbox, les accès en lecture seule et toutes les protections WebKit restent actifs pendant les tests. Aucun contournement n’est ajouté aux entitlements du produit.

Les exécutions sur macOS 14 et sur matériel Intel ne sont pas disponibles sur ce poste et ne sont pas certifiées. Une compilation x86_64 ne remplace pas un essai d’exécution. La recompilation avec cache et réseau physiquement déconnecté reste à effectuer sans modifier à distance les interfaces réseau de l’utilisateur.

T083 reste ouverte pour les preuves manquantes. Consigner ci-dessous les résultats finaux de compilation/signature du bundle produit quand ils sont disponibles.

## Bundle produit propre vérifié

Compilation Release réussie le 6 novembre 2026 avec cache imposé (`-disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile`) et Derived Data séparé : `/tmp/outilVizMd-product/Build/Products/Release/outilVizMd.app`. Cela ne remplace pas une compilation avec réseau physiquement débranché.

- Binaire universel : **x86_64 et arm64**, minimum macOS déclaré **14.0**. Les deux architectures compilent ; seule l’exécution arm64 sur le poste courant a été testée.
- Signature ad hoc avec **Hardened Runtime actif** ; `codesign --verify --deep --strict` réussit.
- Droits effectifs : **App Sandbox**, **user-selected.read-only**, **network.client**. Aucun `get-task-allow`, droit serveur, exception de lecture globale ou droit temporaire XCTest dans ce bundle Release. L’injection automatique des droits de débogage est réservée à Debug.
- Aucun dossier PlugIns de tests dans le bundle produit propre. Les quatre ressources Aide.md, ThirdPartyNotices.txt, ReaderBase.css et NetworkBlockRules.json sont présentes et identiques aux sources.
- SHA-256 du binaire : `7ba2ef2cdbe27e6210f2b9b44cb2d0102c5310af855dafe1f3453f337826bbbc`.

Le scheme normal exécute **59 tests fonctionnels avec succès, zéro échec, six benchmarks explicites ignorés par défaut** : `Test-outilVizMd-2026.11.06_23-27-23-+0100.xcresult`. Les benchmarks exécutés séparément et leurs limites sont consignés dans performance.md. Le produit n’est ni signé Developer ID ni notarifié ; aucune distribution n’est certifiée.
