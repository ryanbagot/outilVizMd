# Implementation Plan: outilVizMd — visualisation de Markdown local

**Branch**: `001-visualiser-markdown-local` (identifiant retourné par setup-plan ; aucune branche Git
créée par cette commande) | **Date**: 2026-11-06 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/001-visualiser-markdown-local/spec.md`

## Summary

Construire un lecteur macOS natif en Swift et SwiftUI, en lecture seule. Une interface avec
navigation latérale, liste des documents ouverts et aperçu WKWebView permet de parcourir les
fichiers autorisés, rechercher du texte et régler le rendu. Les préférences survivent aux sessions,
les documents ouverts et autorisations restent temporaires. Aucun service distant ni serveur local.

Swift Markdown 0.9.0 analyse CommonMark et les tableaux ; un émetteur HTML propre à l’app produit
uniquement les éléments admis. Les images autorisées transitent par un gestionnaire de ressources
à jetons opaques. JavaScript reste désactivé. La recherche est calculée en Swift à partir du texte
visible, avec repères et ancres générés côté natif. Les décisions sont détaillées dans [research.md](research.md).

### Composants et flux

- **Navigation** : arbre paresseux des dossiers, documents ouverts, document actif, commandes clavier.
- **Documents** : autorisations de session, lecture bornée et coordonnée, surveillance et instantanés.
- **Markdown** : adaptateur du moteur, représentation interne, projection de texte recherchable.
- **Rendering** : HTML sûr, ressources, politique de navigation et adaptateur WKWebView.
- **Search** : requête et index temporaire, résultats, compteur, génération des repères de rendu.
- **Themes** : résolution de l’apparence, polices locales, couleurs sRGB, styles et contraste.
- **Preferences** : validation et JSON versionné dans le conteneur de l’app, écriture atomique.

Flux : choix explicite → autorisation → lecture seule → instantané versionné → analyse hors fil
principal → HTML et ressources sûrs → affichage sur MainActor. La recherche et les préférences
créent une nouvelle version de présentation sans modifier l’instantané source. Toute réponse
asynchrone porte l’identité du document et sa génération ; une réponse périmée est ignorée.

La future édition pourra alimenter le même pipeline avec un instantané en mémoire. Aucun éditeur,
service d’écriture, autosave, droit read-write ou abstraction de plugins n’est livré dans le MVP.

## Technical Context

**Language/Version**: Swift, compilateur 6.2 ou ultérieur fourni par Xcode, mode de langage Swift 5
pour ce MVP ; vérification complète de concurrence activée et isolation explicite.

**Primary Dependencies**: SwiftUI, AppKit, Foundation, WebKit, ImageIO et CryptoKit du système ;
SwiftPM `swiftlang/swift-markdown` exact 0.9.0 (swift-cmark et plugin de documentation transitifs).
Aucun paquet UI, serveur, bibliothèque JavaScript ou service externe.

**Storage**: documents externes uniquement lus ; préférences Codable JSON dans Application Support
du conteneur ; instantanés, index et autorisations en mémoire. Aucun bookmark persistant ni base de données.

**Testing**: XCTest, tests d’intégration WebKit et fichiers, XCUITest, fixtures CommonMark/tableaux
et malveillantes, mesures XCTest et contrôle manuel VoiceOver/hors ligne/apparences.

**Target Platform**: macOS 14 minimum, Apple Silicon et Intel ; mesures de référence sur Apple Silicon
8 Go minimum. Compilation avec Xcode complet ; validation réelle macOS 14 requise avant livraison.

**Project Type**: application de bureau native sandboxée, un projet Xcode et trois cibles : app,
tests unitaires/intégration, tests UI. Scheme partagé `outilVizMd`.

**Performance Goals**: SC-001 à SC-008 inchangés : aperçu 1 s/3 s pour 1/10 Mio ; recherche
300 ms/1 s ; rafraîchissement externe 2 s/5 s ; bascule 300 ms ; réglages 300 ms/1 s ; dossier
1 000 entrées sous 1 s. Vingt mesures par seuil, au moins dix-neuf conformes.

**Constraints**: UTF-8 strict, 10 Mio maximum ; JavaScript et réseau automatiques interdits ;
lecture seule des sources ; HTML brut non exécuté ; ressources contrôlées ; aide en français.
L’installation/résolution initiale des outils et paquets peut nécessiter le réseau de développement ;
l’app construite et ses parcours ne l’exigent jamais.

**Scale/Scope**: utilisateur unique, plusieurs documents ouverts, une fenêtre de lecture pour le MVP,
dossiers listés à la demande ; aucune recherche globale ni restauration de session. Mesurer la mémoire
avec dix documents ouverts ; une WKWebView est retenue par document, libérée à sa fermeture.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principe | Contrôle avant recherche | Contrôle après conception |
|----------|-------------------------|---------------------------|
| I. macOS natif | SwiftUI/AppKit, WKWebView intégrée | Conforme : aucun serveur ou shell web |
| II. Modularité | Responsabilités séparées | Conforme : dossiers et interfaces ciblées, un projet |
| III. Interface simple | Parcours natifs, états explicites | Conforme : clavier, VoiceOver, clair/sombre prévus |
| IV. Local et hors ligne | Pas de services ni ressources distantes | Conforme : CSP, règles WebKit, droits réseau absents |
| V. Sources préservées | Aucun scénario d’écriture | Conforme : lecture seule, empreintes avant/après dans les tests |
| VI. Rendu sûr | Entrées non fiables | Conforme : AST sûr, JS absent, ressources à jetons et périmètre strict |
| VII. Swift maintenable | Adaptateurs et erreurs typées | Conforme : travail coûteux isolé, MainActor pour la présentation |
| VIII. Tests essentiels | Couverture des comportements P1/P2 | Conforme : matrice ci-dessous et guide de validation |
| IX. Documentation française | Documents et aide en français | Conforme : guides et erreurs utilisateur prévus |
| MVP | Pas d’édition ni extensions anticipées | Conforme : extension par instantanés, aucune écriture implémentée |

Résultat avant phase 0 : PASS. Résultat après phase 1 : PASS de conception, aucune dérogation.
Ces résultats ne certifient ni compilation ni sécurité déjà testée : les contrôles d’exécution
restent des conditions de livraison. Aucun besoin de clarification ni conflit constitutionnel ouvert.

## Project Structure

### Documentation (this feature)

```text
specs/001-visualiser-markdown-local/
├── spec.md
├── checklists/requirements.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── composants.md
│   └── interface-et-ressources.md
└── tasks.md                       # prochaine phase ; non créé par ce plan
```

### Source Code (repository root)

Arborescence cible à créer pendant l’implémentation ; aucun fichier applicatif créé ici.

```text
outilVizMd.xcodeproj/               # scheme partagé, SwiftPM et Package.resolved
outilVizMd/
├── App/                           # composition, commandes, fenêtre, erreurs UI
├── Navigation/                    # arbre et documents ouverts
├── Documents/                     # accès, instantanés, surveillance
├── Markdown/                      # adaptateur Swift Markdown et représentation interne
├── Rendering/                     # HTML, WebKit, ressources et navigation
├── Search/                        # texte visible, plages et résultats
├── Themes/                        # palettes, styles, polices et contraste
├── Preferences/                   # validation et stockage JSON
├── Resources/                     # CSS de base, aide française, notices
└── outilVizMd.entitlements         # sandbox + user-selected.read-only
outilVizMdTests/
├── Unit/
├── Integration/
├── Performance/
└── Fixtures/                      # Markdown, images, corpus malveillant
outilVizMdUITests/
└── ReadingJourneysTests.swift
README.md                          # compilation, lancement, tests, limites en français
```

**Structure Decision**: un projet Xcode, un module applicatif, frontières par dossiers et contrats
Swift internes ; aucune extraction prématurée en packages. Les types internes du moteur ne sortent
pas de Markdown. Les tests importent l’app, sans devoir lancer l’interface pour tester lecture,
parseur, thèmes, préférences ou index.

### Séquencement de l’implémentation

1. Créer le projet Xcode et les cibles, configurer les droits minimaux, épingler le moteur et vérifier
   le chargement WebKit sans JS, les tableaux, les fragments et la recherche avec compteur sur macOS 14.
2. Livrer la tranche P1 : ouverture, navigation locale, rendu sûr, ressources autorisées, erreurs,
   absence d’écriture et protection contre les entrées malveillantes.
3. Ajouter les tranches P2 : recherche complète, thèmes/préférences et rafraîchissement externe,
   chacune avec tests ciblés et contrôle des générations.
4. Exécuter les parcours complets, mesures, vérification hors ligne et accessibilité ; ajuster les
   points coûteux sans relâcher les protections. Documenter limites et notices avant livraison.

La validation technique initiale est intégrée aux tâches à venir, pas exécutée par cette commande.
Si une API publique ne permet pas un comportement requis, revoir la conception avant de poursuivre ;
ne pas activer JavaScript ni utiliser d’API WebKit privée pour contourner le problème.

### Matrice de validation

| Domaine | Vérifications essentielles | Références |
|---------|---------------------------|------------|
| Lecture/navigation | UTF-8/BOM, 10 Mio, erreurs, identités, homonymes, dossiers paresseux, fermeture | FR-001–003, 015, 017 ; SC-002, 008 |
| Markdown/rendu | CommonMark pris en charge, tableaux, code, images, fragments, HTML brut | FR-004–005 ; SC-001 |
| Sécurité | schémas hostiles, encodages, scripts, CSS/HTML malveillant, traversées, symlinks et courses | FR-012–014 ; SC-005 |
| Recherche | Unicode/casse/accents, texte traversant les nœuds, tableaux/code, compteur et boucle | FR-006 ; SC-003 |
| Thèmes/préférences | polices, bornes, palettes, contraste, corruption, erreur de stockage, trois relances | FR-007–009 ; SC-006 |
| Suivi externe | écriture directe, remplacement atomique, suppression/recréation, rafales, activation | FR-010–011 ; SC-004 |
| UX/aide | annulation, clavier, VoiceOver, états, apparences, cinq débutants | FR-015–018 ; SC-007 |
| Non-régression | sources comparées octet par octet, absence réseau automatique, erreurs récupérables | US1–US6 ; SC-005, 008 |

### Risques et critères de résolution

- Recherche et thèmes sans JS : mesurer reconstruction sur 10 Mio et requêtes denses, vérifier
  ancres et correspondance texte/rendu. Ne jamais restaurer interactionState après un changement
  de HTML, ressources ou CSS ; il pourrait réintroduire une ancienne page.
- Mémoire : vues retenues uniquement pour les documents ouverts, ressources versionnées libérées
  après annulation/fin des tâches ; relever les pics sur dix documents et les erreurs de processus WebKit.
- Courses d’accès : lecture par descripteurs, refus des symlinks descendants et tests de remplacement
  pendant l’ouverture. Aucun élargissement d’autorisation lors d’une reprise.
- Chaîne d’outils : Xcode complet non disponible aux emplacements standards sur ce Mac ; ses Command
  Line Tools seuls ne compilent pas le projet Xcode. Voir les prérequis du quickstart.

## Complexity Tracking

Aucune violation constitutionnelle à justifier. Les composants supplémentaires Search et Documents
répondent à des exigences explicites ; le gestionnaire de ressources et l’index visible évitent
respectivement les accès disque WebKit larges et l’exécution de JavaScript.
