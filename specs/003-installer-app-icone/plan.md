# Implementation Plan: outilVizMd — installation locale et icône

**Branch**: `main` (branche Git réelle) | **Date**: 2026-11-07 | **Spec**: [spec.md](spec.md)

**Input**: `specs/003-installer-app-icone/spec.md`. Identifiant retourné par Spec Kit : `003-installer-app-icone` ; aucune branche Git dédiée créée.

## Summary

Préparer une Release autonome avec l’image fournie intégrée en ICNS, installer une app de référence dans `/Applications/outilVizMd.app` et créer un véritable alias Finder « outilVizMd – ouvrir » au Bureau. Un outil Swift extérieur au lecteur réalise installation, remplacement explicite et réparation du raccourci. L’app conserve identité, sandbox, préférences et règles de lecture ; la réouverture présente la scène existante.

Le périmètre dépend de 001 et reste indépendant de 002. Aucun éditeur, service distant, installateur graphique, mise à jour automatique ou distribution publique.

## Technical Context

**Language/Version**: app Swift en mode 5, concurrence stricte ; compilateur compatible Swift Markdown 0.9.0 (Swift 6.2 minimum), Xcode local 27.2 / Swift 6.4.2. Outil Swift, manifeste SwiftPM 5.9 ; orchestration Python 3 standard.

**Primary Dependencies**: SwiftUI, AppKit, Foundation, Darwin, CryptoKit (SHA-256 natif) ; WebKit, Swift Markdown 0.9.0 et swift-cmark verrouillés inchangés. Outils Apple sips, iconutil, xcodebuild, codesign, ditto, lipo. Aucune dépendance tierce ajoutée.

**Storage**: original immuable, ICNS dérivé versionné, sorties ignorées `build/local/`, bundle Applications, alias Bureau trouvé par API. Staging privé UUID et reçu de récupération. L’outil n’écrit ni documents ni préférences.

**Testing**: XCTest du paquet local sur dossiers temporaires et pannes injectées ; tests Python de préparation ; tests Xcode concernés pour réouverture/lecture ; contrôle du bundle ; recette système dans [quickstart.md](quickstart.md).

**Target Platform**: app macOS 14+, arm64 et x86_64 ; outil compilé pour l’hôte macOS 14+. Reporter séparément les plateformes exécutées. Machine de conception : Apple Silicon, macOS 26.6.2.

**Project Type**: application native macOS et outil ponctuel de déploiement local.

**Performance Goals**: aucune compilation/conversion au lancement quotidien ; dix ouvertures fiables par accès (SC-001), trois installations répétées puis mise à jour sans doublon (SC-004). Aucun seuil de durée/mémoire ajouté ; objectifs existants du lecteur conservés.

**Constraints**: SHA-256 de l’original contrôlé ; destinations stables ; hors ligne après préparation ; aucune élévation automatique ; remplacement explicite ; conflits étrangers préservés ; commit atomique de bundle sur même volume, alias vérifié séparément ; protections du lecteur conservées.

**Scale/Scope**: un Mac, une installation canonique, un alias utilisateur, une image. Cache complet requis pour préparer hors ligne. Choix résolus dans [research.md](research.md).

## Constitution Check

Constitution 1.0.0. Avant recherche : conforme, sans dérogation. Après conception : conforme aux décisions ci-dessous. Contrôle du plan, pas recette exécutée.

| Principe | Avant recherche | Après conception : preuve prévue |
|---|---|---|
| I — natif | Conforme | SwiftUI conservé ; AppKit limité aux besoins macOS. |
| II — proportion | Conforme | Paquet local justifié par API Finder et tests d’écritures hors sandbox ; aucune dépendance du lecteur ou quatrième cible Xcode. |
| III — interface | Conforme | Scène reader unique ; recette clavier, fenêtres et icône clair/sombre. |
| IV — local | Conforme | Ressources embarquées, outil sans réseau ; cache en préparation hors ligne. |
| V — préservation | Conforme | Destinations explicites ; empreintes des documents, préférences et image avant/après. |
| VI — rendu sécurisé | Conforme | Politiques Markdown, JavaScript et ressources inchangées ; tests conservés. |
| VII — maintenabilité | Conforme | Erreurs typées/françaises, responsabilités distinctes, zéro dépendance tierce ajoutée. |
| VIII — tests | Conforme | Alias réel, remplacement avec sauvegarde présente, refus/pannes et réouverture ; recette système reproductible. |
| IX — documentation | Conforme | README/Aide français : commandes, mise à jour, réparation et limites. |

Signature, droits de lecture seule et filtrage WebKit restent bloquants. Ne pas désactiver Gatekeeper, supprimer la quarantaine ou ajouter un droit d’administration au lecteur.

## Project Structure

### Documentation (this feature)

```text
specs/003-installer-app-icone/
├── spec.md
├── checklists/requirements.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
└── contracts/
    ├── deployment-cli.md
    └── launch-and-icon.md
```

`tasks.md` sera produit par `$speckit-tasks`, hors de cette commande.

### Source Code (repository root)

Arborescence prévue ; aucun fichier applicatif créé pendant cette planification :

```text
Icône Markdown personnalisable en couches.png  # existant, immuable
scripts/
├── update-xcode-project.py                   # ICNS + Info.plist
├── prepare-local-app.py                      # préparation et contrôles Release
└── tests/test_prepare_local_app.py           # erreurs et original préservé
tools/LocalDeployment/
├── Package.swift                            # exécutable + tests
├── Sources/InstallLocalApp/
│   ├── Command.swift                        # CLI et résultat
│   ├── Deployment.swift                     # transaction et contrôles
│   └── DesktopAlias.swift                   # alias, identité et conflits
└── Tests/InstallLocalAppTests/               # aucun chemin de production
outilVizMd/
├── App/outilVizMdApp.swift                   # scène ; pont reopen si nécessaire
└── Resources/
    ├── AppIcon.icns                         # dérivé versionné
    └── Aide.md                              # usage et récupération
outilVizMdTests/                             # régressions concernées
outilVizMdUITests/                           # réouverture
outilVizMd.xcodeproj/project.pbxproj          # régénéré
README.md
.gitignore                                  # build et sorties SwiftPM
build/local/                                # ignoré : app, manifeste, outil
```

**Structure Decision**: conserver l’app et son générateur. Le paquet fournit un exécutable testable avec Foundation/AppKit hors de la sandbox du lecteur. Aucun framework, serveur ou outil persistant. Les tests injectent destinations temporaires et pannes ; aucune destination arbitraire dans la CLI de production.

## Déroulement retenu

1. **Phase 0 terminée — recherche.** ICNS, Release isolée, transaction, alias et réouverture dans [research.md](research.md).
2. **Phase 1 terminée — conception.** Entités dans [data-model.md](data-model.md), interfaces dans [deployment-cli.md](contracts/deployment-cli.md) et [launch-and-icon.md](contracts/launch-and-icon.md), recette dans [quickstart.md](quickstart.md).
3. **Implémentation future.** Valider avant installation ; contrôler conflits/processus, copier sur le volume final, sécuriser l’alias connu, effectuer le commit, vérifier puis publier l’alias. Retour arrière si le nouveau bundle est invalide ; résultat partiel si seul l’alias échoue. Aucun élément inconnu supprimé.
4. **Livraison future.** Faire passer les tests concernés et les cinq critères SC. Tout contrôle non exécuté reste signalé ; macOS 14 et Intel ne sont pas déclarés validés par une construction seule.

## Couverture des exigences

| Exigences | Conception et preuve |
|---|---|
| FR-001–003 | Release autonome, destination fixe ; lancement, redémarrage et indépendance du projet. |
| FR-004–006 | Alias réel, scène reader, mise à jour explicite et idempotence ; changement d’identité du bundle testé. |
| FR-007–009 | Empreinte de l’original, ICNS avant signature ; quatre surfaces contrôlées. |
| FR-010 | Identifiant stable, aucun document/préférence écrit ; empreintes comparées. |
| FR-011 | Erreurs effectives, résultats partiels, conflits et récupération testés. |
| FR-012–013 | Cache hors ligne, ressources embarquées, signature/droits et tests du lecteur. |
| FR-014 | README/Aide français et guide de récupération. |

## Complexity Tracking

Aucune violation à justifier. Le paquet local répond au besoin démontré de tester les écritures macOS hors sandbox (principe II), sans dépendance supplémentaire de l’app.

**Ajustements d’implémentation** : voir la dernière section de `research.md` pour le nom fixe d’alias préservant le dossier du projet, le plist minimal et le lot préparé hors Bureau synchronisé accessible via `build/local`.
