# T014 — WebKit corrigé ; validation macOS 14 attendue

## Résultat actuel — 2026-11-06

**12 tests réussis, 0 échec, 0 ignoré**, avec le scheme complet (équivalent Cmd+U).
macOS 26.6.2 (25G83), arm64, Xcode 27.2 (27B52), Swift 6.4.2, SDK macOS 27.2,
deployment target macOS 14. Aucun essai réel macOS 14 ou Intel n’est certifié.

Preuve extraite avec xcresulttool :
`/tmp/outilVizMd-derived/Logs/Test/Test-outilVizMd-2026.11.06_19-19-00-+0100.xcresult`.
Ce chemin est un résultat local temporaire, pas une garantie de conservation.

```sh
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -quiet -project outilVizMd.xcodeproj -scheme outilVizMd -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/outilVizMd-derived test
python3 scripts/verify-webkit-network.py
```

## Cause et correction

Les services GPU et Networking journalisaient :
`Application does not have permission to communicate with network resources. rc=1 : errno=34`.
Sans droit client, ils se terminaient avant la première demande au gestionnaire de schéma.
Le même test passe après le seul ajout de `com.apple.security.network.client`.
Ce contrôle d’initialisation est visible dans
[XPCServiceInitializerDelegate::checkEntitlements](https://raw.githubusercontent.com/WebKit/WebKit/main/Source/WebKit/Shared/EntryPointUtilities/Cocoa/XPCService/XPCServiceEntryPoint.mm).

Le plan initial sous-estimait cette contrainte, y compris pour une page locale. Plan, tâches,
recherche et contrat ont été alignés sur le résultat d’exécution. La constitution reste inchangée :
les connexions automatiques demeurent interdites. Le rendu sûr, la CSP, les règles et la politique
native doivent les empêcher ; l’absence du droit client ne peut plus servir de protection.

| Contrôle | Résultat |
|----------|----------|
| Générations et réponses tardives après fermeture | PASS, 6 tests |
| Reconnaissance du tableau par Swift Markdown épinglé | PASS |
| Configuration JS désactivé, stockage éphémère, CSP et nonce | PASS |
| Règles invalides : refus de configuration partielle | PASS |
| Schéma privé, fragment et restauration strictement identique | PASS |
| Navigations HTTP/HTTPS forcées : refus du chargement par les règles | PASS, erreur WebKitErrorDomain 104 |
| Affichage local avec images HTTP/HTTPS, CSS et iframe distants | PASS |

Les deux captures jointes au test montrent le titre/tableau puis le résultat surligné après
navigation par fragment ; elles ont été inspectées. La restauration retrouve la même image
pour une reconstruction de contenu, CSS et ressources strictement identiques.

Le scheme exclut le runner UI encore vide, qui expirait lors de l’activation de l’automatisation
macOS. `scripts/update-xcode-project.py` l’active dès l’ajout du premier `func test…` dans la
cible UI. Aucun test WebKit ni test existant n’a été ignoré.

## Sonde réseau et limites de la preuve

`scripts/verify-webkit-network.py` démarre un serveur témoin temporaire sur 127.0.0.1:49183,
confirme son accessibilité (1 connexion de contrôle), remet son compteur à zéro puis lance
le test d’affichage passif. Résultat : **0 connexion**. Le serveur est ensuite fermé.
Les mesures sont conservées dans `network-probe.json`. La sonde n’appartient pas au produit
et n’accorde aucun droit serveur à l’application.

Un premier lot incluait aussi l’épreuve forçant volontairement HTTP/HTTPS avec un délégué
permissif : 5 connexions ont été reçues malgré l’erreur de blocage du chargement. Cette épreuve
vérifie le refus des réponses, pas l’absence de connexions spéculatives. La mesure d’absence de
connexion a donc été isolée sur l’affichage passif, où le compteur reste à zéro.

Le produit doit refuser/rerouter les destinations externes avant leur chargement natif et
ne jamais exposer les URL distantes comme sous-ressources issues du Markdown. Les règles seules
ne certifient pas l’absence de connexions spéculatives lors d’une navigation forcée.
La sonde locale ne certifie pas encore tout le corpus US6, les requêtes DNS ni toutes les
connexions des services système. Les contrôles complets T046/T050/T079 restent à réaliser.

## Droits du produit ordinaire

Après les tests, un build ordinaire réussit (code 0). L’inspection codesign confirme exactement :

- `com.apple.security.app-sandbox = true`
- `com.apple.security.files.user-selected.read-only = true`
- `com.apple.security.get-task-allow = true` (Debug)
- `com.apple.security.network.client = true`

Aucun droit serveur, écriture source ou exception globale de fichiers n’est ajouté.
JavaScript reste désactivé. Les droits injectés par Xcode dans l’hôte XCTest sont distincts
(voir `toolchain.md`) et ne servent pas de preuve des droits du produit ordinaire.

## Historique et reste à faire

Avant correction, 9 tests sur 10 passaient. Le chargement privé échouait : aucune demande au
scheme handler, timeout puis WKErrorDomain Code=1 pour la capture. Le test a ensuite détecté
explicitement webViewWebContentProcessDidTerminate ; corriger la signature du délégué ne
résolvait pas le refus d’initialisation des services. L’ajout du droit client résout ce défaut.

T001–T013 restent terminées. T014 demeure non cochée uniquement pour l’exigence d’exécution
réelle sur macOS 14 ; compiler avec deployment target 14 ne la remplace pas. T015–T084 n’ont
pas commencé. Le lecteur utilisateur reste à construire après le checkpoint. Les compléments
de l’analyse, notamment la contradiction A1 de recherche, restent à traiter dans leurs tranches.

## Réorganisation lors de la reprise

La preuve technique T014 sur le poste courant est terminée et permet de poursuivre les parcours.
La vérification sur une installation réelle macOS 14 est conservée dans T083 comme condition
de livraison ; elle ne se confond pas avec une compilation visant macOS 14. Aucun résultat
macOS 14 n’est annoncé. Ce changement de séquencement préserve les exigences du produit.
