# Sécurité — preuves exécutées

Le 6 novembre 2026, macOS 26.6.2 arm64, Xcode 27.2, bundle sandboxé signé ad hoc.

- Suite unitaire/intégration : **38 réussites, 0 échec**, rapport `Test-outilVizMd-2026.11.06_22-23-16-+0100.xcresult` dans `/tmp/outilVizMd-derived/Logs/Test/`.
- Corpus HTML/script/événements, SVG, iframe, formulaire, styles et URL dangereuses : texte échappé, liens opaques, alternative d’image et reste lisible. Aucun script injecté par l’app.
- Descendants symlinks : refus, y compris substitutions atomiques concurrentes pendant les lectures. Une lecture retourne uniquement les octets autorisés ou une erreur. Le fichier extérieur témoin reste inchangé. Les ouvertures sont ancrées par `openat` et `O_NOFOLLOW` à chaque composant.
- Fichier spécial FIFO : refus avant `NSFileCoordinator`, puis deuxième contrôle du type sur le descripteur dans l’accès coordonné. Cette vérification corrige un blocage trouvé par le test.
- Grants libérés, jetons erronés/révoqués, chemins ambigus, ressource d’un autre aperçu, image SVG déguisée et image hors périmètre : refus sans fallback disque. Le handler répond synchroniquement sur MainActor ; aucun callback différé après stop.
- Ouvreur système injecté : aucune ouverture passive, HTTP(S) explicite validé une fois ; autres schémas refusés. Popups/téléchargements refusés par le contrôleur natif.
- Sonde TCP disponible : **1 connexion de contrôle positif, 0 pendant les tests d’affichage**. Voir `network-probe.json`. Inclut le renderer et le contrôleur de production ainsi que la page locale d’épreuve CSP/règles. Cela mesure cette destination loopback ; aucune certification globale DNS/services système n’en est déduite.
- Configuration : JavaScript désactivé, aucun user script/pont, magasin non persistant, CSP restrictive et règles compilées avant création de l’aperçu ; règles invalides = erreur bloquante.
- Droits : App Sandbox, fichiers sélectionnés en lecture seule et client réseau requis par les processus WebKit. Aucun droit serveur. Le droit client ne sert pas à charger les ressources distantes : aucun href/src distant n’est émis par le renderer.

## Contrôles restant à exécuter

La coupure physique du réseau, les parcours recherche/préférences/relance/suivi externe, macOS 14 et l’audit humain final ne sont pas encore validés. T050/T079 restent ouverts pour ces preuves ; les contrôles exécutés ci-dessus ne les remplacent pas.

## Régression finale

Le scheme partagé réussit avec 59 tests fonctionnels, zéro échec, six benchmarks ignorés par défaut (rapport `Test-outilVizMd-2026.11.06_23-27-23-+0100.xcresult`). La régression transversale parcourt le corpus local avec lecture, images, recherche, thèmes, trois réouvertures du store et comparaisons des sources ; les écritures intentionnelles des tests de suivi externe sont isolées. La coupure physique du réseau reste une preuve distincte non réalisée.

Le bundle Release propre est vérifié séparément : Hardened Runtime actif, signature valide, trois droits du produit seulement (sandbox, sélection en lecture seule, client réseau), sans droits temporaires de test. Voir `platforms.md`. La dernière sonde du 2026-11-06 à 22:30 UTC observe encore un contrôle positif réussi et zéro connexion pendant les deux pages locales ; `network-probe.json` contient le relevé.
