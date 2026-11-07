# Feature Specification: outilVizMd — lancement depuis Applications et le Bureau, icône personnalisée

**Feature Branch**: `main` — branche courante ; aucune branche dédiée créée par cette commande.

**Created**: 2026-11-06

**Status**: Draft — spécification validée, prête pour la planification

**Input**: User description: « Je veux que l’application soit ouvrable depuis mon bureau ou
dans les apps, je veux aussi que tu mettes l’image qui est dans le dossier comme icône de
l’application. »

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ouvrir l’application depuis Applications (Priority: P1)

Une personne retrouve outilVizMd parmi ses applications et l’ouvre par un double-clic, sans
rechercher un résultat de compilation ni utiliser des commandes à chaque lancement.

**Why this priority**: L’application doit devenir accessible dans l’usage quotidien du Mac,
avec un emplacement stable indépendant de l’environnement de développement.

**Independent Test**: Installer une version locale préparée en suivant la procédure fournie,
fermer les outils de développement, puis ouvrir outilVizMd depuis Applications et consulter
un document local. Refaire ce parcours après redémarrage du Mac.

**Acceptance Scenarios**:

1. **Given** une version locale préparée, **When** l’utilisateur suit la procédure d’installation,
   **Then** une application nommée « outilVizMd » est disponible dans Applications et son
   emplacement final est indiqué clairement.
2. **Given** l’application installée et fermée, **When** l’utilisateur double-clique sur son
   icône dans Applications, **Then** la fenêtre habituelle du lecteur s’ouvre et permet de
   choisir puis consulter un document local, sans ouvrir Xcode ou Terminal.
3. **Given** le Mac redémarré et les dossiers temporaires de compilation indisponibles,
   **When** l’utilisateur ouvre l’application installée, **Then** elle fonctionne sans nouvelle
   compilation, sans accès au dossier du projet et sans connexion réseau.
4. **Given** une version déjà installée, **When** l’utilisateur effectue une mise à jour locale
   explicitement demandée, **Then** la version installée est remplacée à son emplacement stable,
   avec les préférences et documents de l’utilisateur préservés ; un échec avant remplacement
   effectif laisse la version précédente disponible.

---

### User Story 2 - Lancer la même application depuis le Bureau (Priority: P1)

Une personne utilise un raccourci visible sur son Bureau pour ouvrir la version installée
d’outilVizMd, sans maintenir une deuxième copie de l’application.

**Why this priority**: Le lancement depuis le Bureau est explicitement demandé et doit conduire
à la même application que le lancement depuis Applications.

**Independent Test**: À partir d’une application installée, créer l’accès au Bureau puis
l’utiliser pour ouvrir le lecteur et vérifier sa destination. Répéter après une mise à jour
locale de l’application installée.

**Acceptance Scenarios**:

1. **Given** outilVizMd installé, **When** l’accès au Bureau est mis en place par la procédure
   fournie, **Then** un raccourci clairement nommé « outilVizMd – ouvrir » pointe vers cette installation.
2. **Given** l’application fermée, **When** l’utilisateur double-clique sur ce raccourci,
   **Then** la même version s’ouvre que depuis Applications, sans dépendre du projet ou de
   dossiers temporaires.
3. **Given** cette version déjà en cours d’exécution, **When** l’utilisateur la sollicite depuis
   l’un des deux accès, **Then** sa fenêtre de lecture est présentée ; aucune seconde instance
   indépendante de cette installation n’est lancée pour ce seul geste.
4. **Given** une mise à jour de l’application à son emplacement stable, **When** le raccourci
   est utilisé, **Then** il ouvre la version mise à jour. Supprimer uniquement le raccourci
   ne supprime ni l’application installée ni les documents de l’utilisateur.

---

### User Story 3 - Reconnaître l’application grâce à l’image fournie (Priority: P1)

Une personne reconnaît outilVizMd grâce à l’illustration Markdown fournie, utilisée comme
icône de l’application dans les endroits habituels de macOS.

**Why this priority**: L’icône personnalisée fait partie de la demande et permet de distinguer
outilVizMd d’une application générique ou d’un simple document.

**Independent Test**: Comparer l’icône d’une application préparée à l’image source du projet,
puis vérifier son aspect dans le Finder, sur un raccourci du Bureau, dans le Dock et dans le
sélecteur d’applications pendant son exécution.

**Acceptance Scenarios**:

1. **Given** l’image « Icône Markdown personnalisable en couches.png » à la racine du projet,
   **When** l’application est préparée, **Then** son icône reprend cette illustration, avec
   son symbole Markdown et ses couches superposées, en conservant ses proportions et ses couleurs.
2. **Given** la version installée, **When** l’utilisateur la voit dans le Finder, sur le Bureau,
   dans le Dock ou dans le sélecteur d’applications, **Then** la même identité visuelle est
   reconnaissable, sans icône générique ; l’indicateur habituel de raccourci reste acceptable.
3. **Given** une taille d’affichage petite ou grande et une apparence claire ou sombre,
   **When** l’icône est affichée, **Then** l’image n’est ni étirée ni tronquée et le symbole
   principal reste identifiable.
4. **Given** l’application installée, **When** le projet et l’image source ne sont plus
   accessibles, **Then** l’icône reste disponible. Le fichier image original n’a pas été modifié
   par la préparation ou l’installation.

---

### Edge Cases

- Le dossier Applications n’est pas accessible en écriture ou l’espace disponible est insuffisant :
  l’installation indique l’échec et la récupération possible, sans annoncer un succès incomplet.
- Un autre élément occupe le nom prévu dans Applications ou sur le Bureau : il n’est ni supprimé
  ni remplacé s’il est sans rapport avec outilVizMd ; le conflit est expliqué pour permettre
  de corriger la destination ou le nom.
- L’application est déjà installée ou son raccourci existe : répéter la procédure ne doit pas
  multiplier les copies, les raccourcis ou les noms suffixés sans demande explicite.
- La version à mettre à jour est en cours d’exécution : la procédure indique comment la fermer
  avant remplacement et n’annonce pas une mise à jour qui n’a pas réellement abouti.
- L’installation dans Applications réussit mais le Bureau est indisponible : l’application reste
  utilisable, l’absence du raccourci est signalée et sa création peut être reprise séparément.
- L’image source est manquante, illisible ou n’est plus l’image identifiée : la préparation signale
  le problème et ne présente pas une version à icône générique comme conforme à la demande.
- Une ancienne icône est encore affichée après mise à jour : une procédure locale de
  réactualisation est documentée, sans exiger de remplacer manuellement l’image dans le Finder.
- D’autres copies de développement existent : la procédure et le raccourci désignent clairement
  l’installation de référence, sans démarrer volontairement une copie située dans un dossier temporaire.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Une version préparée d’outilVizMd DOIT pouvoir être installée à un emplacement
  durable dans Applications. La destination par défaut est `/Applications/outilVizMd.app`
  et le nom présenté à l’utilisateur est « outilVizMd » (US1.1).
- **FR-002**: L’application installée DOIT être ouvrable par double-clic depuis le Finder,
  sans lancer Xcode, Terminal ou une nouvelle compilation pour l’usage quotidien (US1.2).
- **FR-003**: Le lancement DOIT fonctionner après redémarrage, sans accès au dossier du projet,
  à l’image source ou aux dossiers temporaires ayant servi à préparer l’application (US1.3).
- **FR-004**: La procédure DOIT permettre de créer sur le Bureau de l’utilisateur un raccourci
  « outilVizMd – ouvrir » vers l’installation de référence. Ce raccourci NE DOIT PAS constituer une seconde
  copie indépendante de l’application (US2.1–2).
- **FR-005**: Les accès depuis Applications et le Bureau DOIVENT désigner la même version.
  Une sollicitation de l’installation déjà en cours d’exécution DOIT présenter sa fenêtre de
  lecture sans lancer une seconde instance indépendante pour ce seul geste (US2.2–3).
- **FR-006**: La mise à jour locale explicitement demandée DOIT conserver l’emplacement de
  référence et un raccourci fonctionnel. La répétition de l’installation ou de la création du
  raccourci NE DOIT PAS produire de copies supplémentaires non demandées (US1.4, US2.4).
- **FR-007**: L’icône de l’application DOIT provenir de l’[image fournie](<../../Icône Markdown personnalisable en couches.png>),
  nommée « Icône Markdown personnalisable en couches.png » à la racine du projet. Elle NE DOIT
  PAS être remplacée par un dessin différent ou une icône générique dans une version présentée
  comme conforme (US3.1–2).
- **FR-008**: Cette identité visuelle DOIT être visible pour l’application dans le Finder,
  pour son raccourci sur le Bureau, dans le Dock pendant son exécution et dans le sélecteur
  d’applications. Les variations de taille et les indicateurs standards du système sont admis,
  mais les proportions, la composition et le symbole principal DOIVENT rester reconnaissables
  en clair et en sombre (US3.2–3).
- **FR-009**: L’image originale DOIT rester inchangée. L’application installée DOIT disposer
  de son icône sans relire cette image dans le projet à chaque lancement et sans intervention
  manuelle de personnalisation dans le Finder (US3.4).
- **FR-010**: Installation et mises à jour NE DOIVENT PAS modifier les documents Markdown ni
  les préférences de lecture existantes. Supprimer le raccourci du Bureau NE DOIT PAS supprimer
  l’application installée ou les documents (US1.4, US2.4).
- **FR-011**: Les erreurs de permissions, d’espace, de destination occupée, de Bureau indisponible
  ou d’image source invalide DOIVENT être signalées avec une récupération compréhensible.
  Le résultat DOIT distinguer une application installée d’un raccourci non créé ; aucun élément
  sans rapport avec outilVizMd NE DOIT être remplacé par cette procédure (cas limites).
- **FR-012**: Une fois la version locale préparée et les droits nécessaires accordés, son
  installation, son lancement, son icône et la lecture de documents locaux DOIVENT fonctionner
  hors ligne, sans compte, téléchargement d’image à l’exécution ni service distant (US1.3, US3.4).
- **FR-013**: L’application lancée depuis ces accès DOIT conserver les protections et règles
  d’accès aux documents de la version existante. L’installation NE DOIT PAS désactiver les protections
  de macOS pour faire fonctionner le lancement (US1–3).
- **FR-014**: Une documentation courte en français DOIT expliquer la préparation initiale,
  l’installation, les deux modes de lancement, la mise à jour locale et la récupération en cas
  de conflit ou de raccourci absent. L’emplacement final DOIT être indiqué sans demander à
  l’utilisateur de connaître les dossiers de compilation (US1–3).

### Key Entities *(include if feature involves data)*

- **Application installée** : version locale d’outilVizMd à un emplacement durable, contenant
  ce qui est nécessaire au lancement et à l’identité visuelle ; installation de référence.
- **Raccourci du Bureau** : accès nommé « outilVizMd – ouvrir » vers cette installation, sans copie indépendante de
  l’application ni possession des documents de l’utilisateur.
- **Image source de l’icône** : illustration fournie dans le projet ; référence visuelle à
  préserver, distincte de l’icône utilisable sans le projet après installation.
- **Résultat d’installation** : emplacement de l’application, état du raccourci et éventuel
  problème à corriger, afin de ne pas confondre réussite complète et réussite partielle.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: L’utilisateur peut ouvrir la version installée depuis Applications et depuis le
  Bureau dans dix essais successifs pour chaque accès, avec Xcode et Terminal fermés, sans
  commande à saisir ni nouvelle compilation ; la fenêtre de lecture est utilisable à chaque fois.
- **SC-002**: Les deux accès restent fonctionnels après un redémarrage du Mac et lorsque le
  projet, l’image source et les dossiers temporaires de préparation sont rendus indisponibles.
  L’ouverture et la consultation d’un document local réussissent aussi réseau désactivé.
- **SC-003**: Dans les quatre contextes — Finder, Bureau, Dock et sélecteur d’applications —
  l’icône est identifiable comme l’image fournie, sans icône générique ni déformation visible,
  aux tailles disponibles dans chaque contexte et dans les deux apparences. Le fichier source
  reste identique.
- **SC-004**: Après trois répétitions de la procédure et une mise à jour locale, il existe une
  installation de référence et un seul raccourci attendu ; les deux accès ouvrent la version
  mise à jour et tous les documents et préférences de référence sont préservés.
- **SC-005**: Chaque cas d’erreur prévu présente un résultat exact et une récupération
  documentée. Dans 100 % des conflits avec un élément non visé, cet élément reste inchangé ;
  l’échec du raccourci n’empêche pas l’usage d’une application correctement installée.

## Assumptions

- Le besoin concerne l’application macOS existante. « Dans les apps » désigne le dossier
  Applications du Mac. Le périmètre de compatibilité existant est conservé ; une plateforme
  non exécutée ne devient pas validée par cette seule fonctionnalité.
- Le choix retenu est une installation de référence dans `/Applications` et un raccourci sur
  le Bureau. Les éventuelles autorisations d’installation sont traitées au moment de cette
  opération ; elles ne sont pas nécessaires à chaque lancement quotidien.
- Le besoin est l’usage local sur le Mac de l’utilisateur. Une publication sur une boutique,
  une distribution publique, des mises à jour automatiques ou un programme d’installation
  complexe ne sont pas demandés.
- La préparation initiale de la version locale peut nécessiter les outils de construction du
  projet. L’application installée est ensuite autonome vis-à-vis de ces outils et du projet.
- L’image retenue est le fichier fourni de 1 254 × 1 254 pixels, représentant un symbole
  Markdown sur des couches superposées. Les adaptations aux tailles d’icônes conservent ce
  visuel ; aucune refonte graphique ni interface de personnalisation d’icône n’est ajoutée.
- Les dossiers de destination sont des emplacements locaux disponibles. Le mode dégradé avec
  Bureau inaccessible est signalé explicitement ; aucune synchronisation distante n’est requise.
- Cette fonctionnalité s’appuie sur le lecteur de [001-visualiser-markdown-local](../001-visualiser-markdown-local/spec.md)
  et peut être livrée indépendamment de [002-creer-fichier-markdown](../002-creer-fichier-markdown/spec.md).
  Elle n’ajoute pas de nouveau comportement d’édition ou de gestion des documents.
