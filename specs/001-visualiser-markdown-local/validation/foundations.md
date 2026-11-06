# Fondations — suivi de validation

T007–T010 : modèles créés et compilation Debug arm64 réussie sur le poste décrit dans
`toolchain.md`. Les types de swift-markdown ne sont pas exposés par les modèles de l’app.
Les instantanés conservent les octets bruts, les préférences valident tailles et couleurs,
et les erreurs transportent des messages français sans contenu source.

T011 : six tests écrits avant le contrôle des générations. Premier cycle du 2026-11-06 :
`xcodebuild … -only-testing:outilVizMdTests/GenerationGateTests test` échoue à la compilation,
code 65, car `GenerationGate` et `ReadingCoordinator` ne sont pas encore définis. Il s’agit
d’un échec de compilation initial, pas d’un test comportemental déjà exécuté.

T012 : après implémentation, les six tests passent sans échec ni avertissement d’exécution.
Preuve extraite via `xcresulttool get test-results summary` du résultat
`/tmp/outilVizMd-derived/Logs/Test/Test-outilVizMd-2026.11.06_18-56-29-+0100.xcresult`.
Les générations sont monotones sur toute la session, y compris après fermeture/réouverture
d’un identifiant ; les réponses inactives ne sont pas affichées comme celles de l’actif.

T013 : configuration compilée avec JS désactivé, magasin éphémère, règles réseau bloquantes,
CSP à nonce contrôlé et refus si compilation de règles échouée. La preuve d’exécution WebKit
est suivie séparément dans `webkit-feasibility.md` (T014).

Après correction du droit client requis pour WebKit, les 12 tests actuels passent sur macOS
26.6.2. T014 attend encore son essai réel macOS 14. Voir `webkit-feasibility.md` pour la portée
de la preuve et la sonde réseau d’affichage passif.
