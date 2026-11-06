<!--
Sync Impact Report — rapport temporaire à retirer avant le commit de la constitution.
Version : modèle non ratifié → 1.0.0 (première adoption).
Principes remplacés : les cinq emplacements du modèle, sans contenu normatif antérieur.
Principes ajoutés :
- I. Application native macOS
- II. Architecture modulaire et proportionnée
- III. Interface simple et esthétique
- IV. Fonctionnement local et hors ligne
- V. Documents préservés par défaut
- VI. Rendu Markdown sécurisé
- VII. Code Swift lisible et maintenable
- VIII. Tests des fonctionnalités essentielles
- IX. Documentation concise en français
Sections ajoutées : Priorité au MVP ; Processus de développement et validation ;
règles de gouvernance renseignées.
Sections supprimées : aucune section normative préexistante.
Modèles et commandes dépendants : non modifiés ; lecture de la constitution à l’exécution.
Suivi / TODO : aucun.
-->

# outilVizMd Constitution

## Core Principles

### I. Application native macOS

outilVizMd DOIT être une application native macOS écrite en Swift. L’interface DOIT utiliser
SwiftUI et, lorsqu’un besoin concret le justifie, AppKit. Les conventions macOS relatives
aux fenêtres, menus, raccourcis clavier et dialogues de fichiers DOIVENT être respectées.
Une vue de rendu web intégrée est autorisée pour Markdown, sans transformer l’application
en site distant ni imposer un serveur local. Cette base garantit une intégration cohérente
avec le système.

### II. Architecture modulaire et proportionnée

Le code DOIT séparer les responsabilités de présentation, d’accès aux documents et de rendu
Markdown. Les dépendances entre ces responsabilités DOIVENT être explicites ; la logique
métier et de rendu DOIT pouvoir être testée sans lancer l’interface complète. Un module peut
être un ensemble de types et de fichiers : aucun paquet séparé, système de plugins ou couche
abstraite supplémentaire ne DOIT être créé sans besoin démontré du MVP.

### III. Interface simple et esthétique

Chaque écran DOIT donner accès directement aux actions essentielles et présenter une
hiérarchie visuelle cohérente, des libellés compréhensibles et des états vide, chargement et
erreur explicites. L’interface DOIT privilégier les composants natifs, une typographie lisible,
des espacements réguliers et la prise en charge des apparences claire et sombre. Les actions
essentielles DOIVENT être utilisables au clavier et disposer de libellés d’accessibilité.
La validation visuelle et fonctionnelle de ces points DOIT précéder la livraison.

### IV. Fonctionnement local et hors ligne

L’ouverture, la lecture et le rendu des documents DOIVENT fonctionner sans connexion réseau,
sans compte et sans service distant. Les ressources nécessaires au rendu DOIVENT être
embarquées. L’application NE DOIT PAS envoyer le contenu des documents, charger des ressources
distantes intégrées au Markdown, ni émettre de télémétrie. Un lien externe ne peut être ouvert
dans le navigateur système que par une action explicite de l’utilisateur, après validation
de son schéma. Cette règle protège la confidentialité et rend le fonctionnement prévisible.

### V. Documents préservés par défaut

Ouvrir, afficher, recharger ou fermer un document NE DOIT modifier ni ses octets ni son
emplacement. Toute écriture, conversion, sauvegarde, suppression ou substitution d’un document
DOIT résulter d’une action explicite visant cette opération et une destination identifiée.
Une ouverture de fichier ou un changement de préférence ne constitue pas un consentement à
l’écriture. L’enregistrement automatique des documents est interdit dans le MVP. Les réglages
et caches internes DOIVENT rester séparés des documents sources. Une erreur d’accès ou de
rendu DOIT préserver le fichier original.

### VI. Rendu Markdown sécurisé

Tout document Markdown DOIT être traité comme une entrée non fiable. Le rendu DOIT neutraliser
le HTML brut dangereux, les scripts, gestionnaires d’événements, contenus embarqués actifs
et URL exécutables. Les schémas de liens et de ressources DOIVENT être validés par une liste
d’autorisation explicite ; toute navigation non autorisée DOIT être bloquée. Les ressources
locales ne peuvent être lues que dans le périmètre explicitement autorisé par l’utilisateur,
après résolution du chemin et des liens symboliques. Le rendu NE DOIT permettre ni lecture
arbitraire du disque ni exécution de commandes. Si une vue web est utilisée, JavaScript DOIT
être désactivé et les chargements et navigations DOIVENT être filtrés. Ces protections DOIVENT
être vérifiées avec des documents malveillants avant livraison.

### VII. Code Swift lisible et maintenable

Le code DOIT utiliser des noms explicites, des types adaptés et des fonctions à responsabilité
limitée. Les erreurs attendues DOIVENT être traitées et présentées sans arrêt brutal ; les
déballages forcés et les erreurs ignorées sont interdits sur les chemins de traitement des
documents. Les traitements coûteux NE DOIVENT PAS bloquer le fil principal. Chaque dépendance
ajoutée DOIT répondre à un besoin concret et être évaluée pour sa maintenance, sa licence,
son fonctionnement hors ligne et son exposition aux entrées non fiables. Les commentaires
DOIVENT expliquer les décisions non évidentes, sans paraphraser le code.

### VIII. Tests des fonctionnalités essentielles

Le projet DOIT disposer de tests automatisés couvrant l’ouverture d’un document valide,
les erreurs de lecture, le rendu des éléments Markdown pris en charge, la préservation du
source et le rejet des contenus ou navigations dangereux. La préservation DOIT être vérifiée
par comparaison des octets avant et après les opérations de consultation. Le fonctionnement
hors ligne et les parcours essentiels de l’interface DOIVENT aussi faire l’objet d’une
vérification reproductible, automatisée lorsque possible, sinon décrite comme contrôle manuel.
Toute correction d’un défaut essentiel DOIT inclure un test de régression pertinent. Les tests
DOIVENT vérifier le comportement observable, sans imposer un objectif arbitraire de couverture.

### IX. Documentation concise en français

La documentation du projet DOIT être rédigée en français et expliquer au minimum les
prérequis macOS, la compilation, le lancement, l’exécution des tests, l’organisation des
modules et les limites connues du MVP. Toute modification d’un comportement documenté DOIT
mettre à jour le passage concerné dans le même changement. Les commandes DOIVENT être
reproductibles ; les explications DOIVENT rester courtes et centrées sur l’usage et la
maintenance. Les identifiants Swift et noms d’API peuvent conserver leur langue usuelle.

## Priorité au MVP

Le premier objectif est un parcours fonctionnel permettant d’ouvrir et de consulter un
document Markdown local avec un rendu lisible, sûr et sans altération du source. Chaque
fonctionnalité retenue DOIT contribuer à ce parcours ou satisfaire un principe de cette
constitution. Les fonctions complexes, extensions et abstractions anticipées DOIVENT être
reportées tant qu’aucun besoin du MVP ne les justifie dans la spécification.

La simplicité de livraison NE DOIT PAS réduire les exigences de sécurité, de préservation
des documents ou de fonctionnement hors ligne. Le périmètre DOIT être réduit avant de
compromettre ces garanties. La version minimale de macOS et les éléments Markdown pris en
charge DOIVENT être explicités dans la spécification et la documentation du MVP.

## Processus de développement et validation

Avant toute implémentation, la spécification et le plan DOIVENT identifier le parcours
utilisateur, les critères d’acceptation, les limites du MVP et les impacts sur ces principes.
Chaque changement DOIT rester de taille relisible et limité au besoin exprimé.

Avant intégration ou livraison, la revue DOIT vérifier la conformité à la constitution,
la compilation, la réussite des tests essentiels concernés et l’actualité de la documentation.
Les changements touchant le rendu ou les fichiers DOIVENT vérifier explicitement la sécurité,
le fonctionnement hors ligne et la préservation des sources. Les changements d’interface
DOIVENT inclure une vérification des parcours clavier, des apparences et des états d’erreur.
Les résultats et éventuelles limites de validation DOIVENT être consignés dans la revue.
Un échec d’un contrôle essentiel DOIT bloquer la livraison jusqu’à correction.

## Governance

Cette constitution prévaut sur les spécifications, plans, tâches et conventions du projet.
Toute incompatibilité DOIT être résolue avant implémentation, soit en adaptant le changement,
soit par un amendement explicite de la constitution ; aucune dérogation implicite n’est admise.

Tout amendement DOIT décrire sa motivation, les principes concernés, ses conséquences et les
adaptations nécessaires. Il DOIT être approuvé explicitement par le responsable du projet
avant adoption. La version et la date de dernière modification DOIVENT être mises à jour ;
la date de ratification initiale reste inchangée. Les décisions antérieures encore applicables
DOIVENT être conservées.

Le versionnement suit MAJOR.MINOR.PATCH : MAJOR pour une suppression ou redéfinition
incompatible d’une règle, MINOR pour un nouveau principe ou une extension substantielle,
PATCH pour une clarification sans changement d’obligation. Chaque revue de spécification,
de plan et de changement de code DOIT vérifier le respect de la version en vigueur.

**Version**: 1.0.0 | **Ratified**: 2026-11-06 | **Last Amended**: 2026-11-06
