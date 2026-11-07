# Contrat — préparation et déploiement local

Interface implémentée. Commandes à lancer depuis la racine du dépôt pendant la préparation/installation ; aucun outil requis pour le lancement quotidien. Références : [modèle](../data-model.md), [recette](../quickstart.md).

## Préparation

```text
python3 scripts/prepare-local-app.py [--offline] [--package-cache PATH]
```

- Cache par défaut : `build/SourcePackages`. Versions issues de Package.resolved uniquement. En mode offline, refuser toute résolution/téléchargement si le cache est insuffisant.
- Vérifier la source identifiée dans le modèle, générer l’ICNS, régénérer le projet et construire une Release universelle isolée des tests. Compiler l’outil pour l’hôte.
- Sorties : `build/local/outilVizMd.app`, `build/local/manifest.json`, `build/local/install-local-app`. Indiquer les chemins et la version validée. Ne jamais installer implicitement.
- `build/local` est un lien publié atomiquement vers un lot temporaire privé hors Bureau synchronisé ; le bundle `.app` lui-même est réel. Il peut être supprimé après installation, qui reste autonome.
- Publier l’ensemble après contrôles ; conserver une précédente préparation valide si la nouvelle échoue. Un ICNS versionné ne permet pas de contourner le contrôle d’une source absente ou modifiée.
- La préparation peut modifier le dérivé ICNS et le projet généré, jamais l’image originale. Signer après intégration des ressources ; aucun changement de bundle après signature.
- Codes : 0 prêt ; 4 entrée/image invalide ; 5 accès/espace ; 6 outil de construction, cache ou validation échoué ; 64 usage invalide. Diagnostic français et commande de récupération ; pas de faux succès avec icône générique.

## Outil compilé

```text
build/local/install-local-app install --source PATH [--replace] [--dry-run] [--json]
build/local/install-local-app alias [--dry-run] [--json]
build/local/install-local-app status [--json]
```

`PATH` désigne la Release préparée ; `manifest.json` doit être adjacent. Aucun paramètre pour rediriger les écritures vers un chemin arbitraire en production. `--help` explique en français les destinations et effets.

### install

Destination fixe `/Applications/outilVizMd.app`, puis alias `outilVizMd – ouvrir` dans le Bureau fourni par macOS. Contrôler bundle source/manifeste, destination, processus, espace et droits ; copier/valider sur le volume final avant commit.

| Situation | Comportement |
|---|---|
| App absente | Création exclusive, puis alias. |
| Bundle identique | Aucun remplacement ; vérifier/réparer seulement l’alias. |
| Version différente, même identité | Refus sans `--replace` ; avec cette option, mise à jour après précontrôles. |
| App canonique active | Refuser le remplacement, indiquer PID/chemin et demander de quitter normalement. Une répétition sans remplacement peut seulement réparer l’alias. |
| Copie de développement active | Ne pas la terminer ni la remplacer ; diagnostic identifiant clairement les chemins. |
| Objet étranger dans Applications | Refus et objet inchangé, même avec `--replace`. |
| Objet étranger au nom de l’alias | Préservé ; première installation possible avec résultat partiel, ou mise à jour avec résultat partiel si aucun alias connu ne risque de suivre l’ancien bundle. |
| Bureau inaccessible | Première installation : partiel ; mise à jour : refus avant commit si l’ancien alias ne peut être sécurisé. |

`--replace` autorise uniquement le remplacement de l’app identifiée et la régénération d’un alias reconnu ; jamais l’écrasement d’un conflit inconnu. Aucun arrêt forcé d’app, `sudo`, modification de Gatekeeper ou suppression de quarantaine. Les échecs de commit ne déclenchent aucun fallback destructif.

### alias

Valider l’app canonique puis créer/réparer seulement le raccourci reconnu, sans source de préparation ni compilation. Une app manquante/invalide provoque un refus. Un fichier, répertoire, symlink ou alias inconnu au nom attendu reste inchangé. Le raccourci publié doit résoudre vers le chemin ET l’identité de fichier du bundle actuel, même si une ancienne app reste en sauvegarde.

### status et simulation

`status` ne modifie rien : identité et chemin de l’app, état de l’alias, processus concernés et reçus de transaction résiduels. Il ne lance pas l’app. Une inspection réussie retourne 0 même si elle constate une app absente ou un conflit ; les états indiquent ce constat. Une inspection impossible retourne une erreur.

`--dry-run` ne crée ni verrou persistant, ni staging, ni alias ; valide les entrées et décrit les changements prévus. Un résultat preview n’affirme pas qu’un futur commit réussira. Les erreurs de précontrôle gardent leurs codes normaux.

## Résultat et codes

Sortie par défaut française : emplacement canonique, version effectivement présente, état du raccourci, changement réalisé ou prévu, diagnostic et récupération. `--json` produit un objet JSON unique sur stdout, suivant le modèle schemaVersion 1 ; logs techniques éventuels sur stderr. Les champs optionnels sont null ou absents selon leur disponibilité ; ne pas inventer un chemin de Bureau inaccessible. Une simulation ajoute `plannedActions` et utilise outcome preview. `status` utilise outcome status.

| Code | Signification |
|---|---|
| 0 | Succès complet, simulation valide ou inspection effectuée. |
| 1 | Partiel : app valide mais alias non conforme ou nettoyage incomplet ; état précis fourni. |
| 2 | Refus : conflit ou remplacement non autorisé. |
| 3 | App active/identité de processus ambiguë empêchant la mise à jour. |
| 4 | Source, manifeste ou app à réparer invalide/absente. |
| 5 | Permissions, espace ou destination indisponible empêchant l’opération. |
| 6 | Copie/commit/validation échoué ; ancien état restauré si nécessaire. |
| 7 | Autre opération en cours, réessayer après sa fin. |
| 8 | Récupération nécessaire : retour arrière incomplet ou transaction interrompue bloquant une mutation sûre. |
| 64 | Arguments invalides. |

L’échec du seul Bureau après installation valide utilise 1, pas 5. En échec, toujours indiquer l’état réel de l’installation et les sauvegardes conservées. Les opérations ne touchent ni documents ni préférences du lecteur.
