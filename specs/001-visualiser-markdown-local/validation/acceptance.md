# Acceptation — état réel

La lecture, la navigation, la recherche, les préférences et le suivi externe sont implémentés. Le passage fonctionnel final du scheme partagé compte **59 réussites, zéro échec et six benchmarks explicites ignorés** (rapport `Test-outilVizMd-2026.11.06_23-27-23-+0100.xcresult`). Les benchmarks de lecture ont leurs séries de vingt séparées. Les rapports de validation ci-dessous distinguent les essais exécutés et les preuves manquantes. Ce document ne certifie pas encore la livraison.

| Exigence | Preuves | État |
|---|---|---|
| FR-001 ouverture/annulation | us1.md, OpeningJourneyTests | Automatisé réussi |
| FR-002 dossiers/filtre/homonymes | us2.md, DirectoryNavigatorTests, NavigationJourneyTests | Automatisé réussi |
| FR-003 session/position/fermeture | us2.md, ReadingSessionTests, DocumentSwitchingTests, WebKitFeasibilityTests | Automatisé réussi ; mesures finales séparées |
| FR-004 Markdown/tableaux/code | us1.md, MarkdownParserTests, RenderingContractTests | Automatisé réussi |
| FR-005 images/liens autorisés | us1.md, us2.md, LocalLinkContractTests, ResourceIsolationTests | Automatisé réussi et images vérifiées dans l’interface |
| FR-006 recherche | us3.md, SearchIndexerTests, SearchRenderingContractTests, SearchJourneyTests | Automatisé réussi ; mesures finales séparées |
| FR-007 apparences | us4.md, ThemeResolverTests, ThemePresentationTests | Automatisé réussi |
| FR-008 personnalisation/contraste | us4.md, PreferencesView, ThemeResolverTests | Automatisé réussi ; audit humain T082 restant |
| FR-009 persistance/reset/erreur | us4.md, PreferencesStoreTests, PreferencesJourneyTests | Trois relances réelles et reset réussis |
| FR-010 suivi externe | us5.md, DocumentMonitorTests, ExternalChangeTests, ExternalChangeJourneyTests | Automatisé réussi ; régression des notifications tardives ajoutée |
| FR-011 état obsolète/récupération | us5.md, ExternalChangeJourneyTests | Suppression/recréation visibles, source non recréée par le lecteur |
| FR-012 lecture seule | us1–us5, ReadOnlyOfflineRegressionTests, comparaisons de sources | Essais fonctionnels réussis ; régression transversale locale finale réussie |
| FR-013 sécurité/scopes/liens actifs | us6-security.md, AccessRaceTests, UntrustedRenderingTests, ExternalNavigationTests | Essais adversariaux réussis ; périmètre décrit dans le rapport |
| FR-014 local/hors ligne | us6-security.md, network-probe.json | Zéro connexion à la sonde passive ; coupure physique encore non testée |
| FR-015 états/messages/récupération | us1.md, us5.md, ReaderStatusView, parcours UI | Automatisé réussi |
| FR-016 clavier/accessibilité | accessibility-usability.md, parcours UI | Clavier automatisé ; audit VoiceOver complet restant |
| FR-017 UTF-8/BOM/CRLF/10 Mio | us1.md, DocumentAccessTests | Automatisé réussi |
| FR-018 aide française locale | Aide.md, HelpView, HelpJourneyTests | Aide et licences ouvertes/fermées par le parcours UI réussi |

| Critère | Preuves | État |
|---|---|---|
| SC-001 restitution du corpus hors ligne | us1.md, us2.md, tests de rendu | Structure et images vérifiées ; coupure physique restante |
| SC-002 ouverture/bascule/réactivité | performance.md | Ouverture/bascule/annulation : 20/20 conformes ; limites dans performance.md |
| SC-003 recherche | us3.md, performance.md | Fonctionnel réussi ; vingt séries conformes |
| SC-004 suivi externe/dix sauvegardes | us5.md, performance.md | Fonctionnel réussi ; vingt séries conformes |
| SC-005 préservation/sécurité | us6-security.md, réseau et régression transversale | Essais exécutés, coupure physique restante |
| SC-006 réglages/latence | us4.md, performance.md | Persistance réussie, vingt séries de rendu conformes |
| SC-007 prise en main | accessibility-usability.md | Non validé : cinq débutants non disponibles |
| SC-008 parcours hors ligne/erreurs/dossier 1 000 entrées | us1–us6, performance.md | Erreurs exercées ; dossier mesuré et coupure physique à consigner |

## Conditions encore ouvertes

Les tâches T030/T050/T079 demandent une preuve avec réseau physiquement coupé. T078 exige les mesures complètes et l’observation de la mémoire app + WebKit. T082 exige VoiceOver et le parcours avec cinq débutants. T083 exige les plateformes réellement annoncées et le build/test hors ligne. Les résultats ne sont pas déduits d’un changement de cible de déploiement ou d’un simple build multi-architecture.

**77 tâches sur 84 sont terminées**. Restent T030, T050, T078, T079, T082, T083 et T084 : leurs preuves manquantes sont listées ici et dans les rapports dédiés. Le bundle produit compile pour arm64/x86_64 et sa signature/droits sont vérifiés ; les exécutions sur macOS 14/Intel, les essais physiquement hors ligne, VoiceOver/cinq débutants, la latence certifiée du dossier et l’observation complète de la mémoire WebKit restent ouverts.

T084 reste ouverte tant que ces preuves essentielles manquent. Le projet est utilisable pour la vérification locale dans Xcode ; la livraison finale n’est pas déclarée acceptée.
