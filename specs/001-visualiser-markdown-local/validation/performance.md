# Performance — mesures locales en cours

Poste : MacBook Pro Apple M5 Pro, 24 Gio, macOS 26.6.2 (25G83), Xcode 27.2. Test host ad hoc Debug optimisé `-O`, sandbox et protections WebKit actifs ; Hardened Runtime désactivé uniquement pour permettre le chargement de XCTest dans ce test host. Le projet produit conserve sa configuration. Cette mesure ne certifie pas le build Release distribué.

Le corpus généré inclut titres, Unicode, paragraphes, emphase, listes, tableaux, code, lien local et PNG. Fichiers exacts 1 048 576 et 10 485 760 octets ; empreintes et séries brutes attachées à XCTest. La fenêtre est le vrai ReaderWindow ; le chronomètre attend didFinish de la nouvelle version puis une image WebKit avec afterScreenUpdates. L’ouverture commence au traitement de la sélection (autorisation incluse), sans compter le temps humain dans le panneau.

Première mesure après optimisation (une répétition, donc non certifiante) :

| Action | 1 Mio | 10 Mio |
|---|---:|---:|
| Ouverture visible | 0,317 s | 0,663 s |
| Recherche rendue | 0,096 s | 0,393 s |
| Thème rendu | 0,048 s | 0,349 s |
| Modification externe visible | 0,250 s | 0,896 s |

Optimisations : échappement HTML et normalisation UTF-8 en un parcours, offsets de projection incrémentaux, recherche parcourant les runs dans l’ordre, images locales identiques décodées une seule fois et ressources réutilisées entre présentations. La mise en page utilise content-visibility comme amélioration progressive ; le fallback reste le rendu ordinaire. [WebKit documente son support depuis Safari 18](https://webkit.org/blog/15865/webkit-features-in-safari-18-0/), donc l’effet sur les moteurs plus anciens doit être mesuré séparément.

La variable du runner doit être transmise avec le préfixe TEST_RUNNER_, conformément à la [documentation Apple](https://developer.apple.com/documentation/xcode/environment-variable-reference). Exemple :

```sh
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer TEST_RUNNER_OUTILVIZMD_PERFORMANCE=20 xcodebuild -project outilVizMd.xcodeproj -scheme outilVizMd -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/outilVizMd-derived SWIFT_OPTIMIZATION_LEVEL=-O ENABLE_HARDENED_RUNTIME=NO -only-testing:outilVizMdTests/ReadingPerformanceTests/testTwentyVisibleReadingMeasurements test
```

Une série initiale était invalide : le compteur pouvait être mis à jour avant que le nouvel HTML soit chargé. Le test exige maintenant une version différente pour chaque nouvelle recherche et conserve l’étape et les mesures partielles en cas d’échec. Une attente intermittente a révélé le défaut de notification tardive décrit plus bas. Les séries en échec ne sont pas comptées comme succès ; elles ont été remplacées par une série complète après correction.

T078 reste ouverte tant que vingt mesures valides et dix-neuf conformes par seuil, le dossier dans l’interface, le retour de navigation/annulation et la mémoire des processus WebKit n’ont pas leurs preuves. La mesure mémoire du seul processus applicatif ne représentera pas à elle seule le total app + WebKit.

## Série native validée

Rapport `Test-outilVizMd-2026.11.06_22-52-54-+0100.xcresult` : les deux tests de suivi externe, la mémoire à dix documents et les vingt répétitions réussissent. Les notifications tardives sont désormais comparées aux métadonnées de la dernière source publiée ; les contrôles achevés hors ordre sont ignorés. La régression teste dix cycles de rafales/bascules.

Les [séries brutes](performance-reading.json) contiennent vingt mesures par action et taille. **20/20 mesures sont sous chaque seuil ci-dessous**, y compris la recherche dense rendue (plus stricte que le seul compteur SC-003).

| Action | Maximum 1 Mio | Maximum 10 Mio | Seuil 1/10 Mio |
|---|---:|---:|---|
| Ouverture visible | 0,295 s | 0,727 s | 1 / 3 s |
| Recherche — compteur | 0,057 s | 0,096 s | 0,3 / 1 s |
| Recherche — rendu | 0,089 s | 0,390 s | 0,3 / 1 s |
| Recherche dense — compteur | 0,024 s | 0,136 s | 0,3 / 1 s |
| Recherche dense — rendu | 0,094 s | 0,831 s | 0,3 / 1 s |
| Thème visible | 0,045 s | 0,391 s | 0,3 / 1 s |
| Modification externe visible | 0,279 s | 0,962 s | 2 / 5 s |
| Dix sauvegardes — dernière version | 0,260 s | 0,889 s | 2 / 5 s |
| Bascule vers le document chargé | 0,022 s | 0,079 s | 0,3 s |

L’énumération du dossier de 1 000 entrées prend au maximum 0,043 s sur vingt essais ; cette mesure de service ne remplace pas le parcours UI final.

[Mémoire du processus applicatif seul](performance-memory-app-only.json) : environ 130 Mio avant, 253 Mio avec dix documents de 1 Mio, pic 254 Mio. Après fermeture, la session, les documents et versions rendues sont vides ; le RSS reste proche de 253 Mio (réservation de l’allocateur et caches possibles). Ce relevé ne prouve pas une restitution immédiate des pages au système et exclut les processus WebKit. Le contrôle mémoire complet et une récupération après arrêt réel de WebKit restent à effectuer.

La série de lecture a été répétée après l’unification des espaces entre nœuds (rapport `Test-outilVizMd-2026.11.06_23-14-03-+0100.xcresult`) : 20/20 restent conformes ; le tableau et le JSON pointent vers cette dernière série. L’échec du test d’aide dans ce rapport était un sélecteur AX trop spécifique ; son parcours corrigé réussit séparément.

## Limite du contrôle de dossier

La tentative XCUITest à vingt sélections a été interrompue après environ treize minutes : les saisies et recherches d’éléments rendaient la série excessivement lente. Une répétition ciblée avec collage temporaire du chemin (presse-papiers restauré) et firstMatch réussit, mais mesure 3,94 s d’annulation et 4,23 s de dossier, coût IPC/quiescence inclus. Cela ne certifie pas SC-002/008.

La mesure native expérimentale dessine la fenêtre en environ 0,1 s, mais la capture bitmap exclut des composants de liste et le host unitaire ne publie pas le sous-arbre AX de NSHostingView. Ces résultats sont explicitement non certifiants dans `performance-native-interface-experimental.json`. Le test correspondant est ignoré avec une raison explicite si cet arbre est absent ; il ne transforme pas l’absence de preuve en réussite. Le seuil du dossier utilisable reste à mesurer dans le host UI avec une trace de rendu adaptée.

Les vingt annulations pendant un chargement de 10 Mio ont aussi été répétées séparément : **20/20 sous 300 ms**, maximum **0,014 s** (arrondi supérieur). Le test confirme que la source est encore en chargement avant l’action, compare les images du chargement et de l’accueil réellement dessiné, puis vérifie les octets sources. Voir `performance-cancel-visible.json`, rapport `Test-outilVizMd-2026.11.06_23-26-41-+0100.xcresult`. Cette mesure commence dans le gestionnaire de commande ; elle n’inclut pas l’IPC du pilote de test.
