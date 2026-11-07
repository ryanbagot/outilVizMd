# Feature Specification: outilVizMd — création de fichiers Markdown

**Feature Branch**: `main` — branche courante ; aucune branche dédiée créée par cette commande.

**Created**: 2026-11-06

**Status**: Draft — spécification validée, prête pour la planification

**Input**: User description: « Ajouter la création de fichiers Markdown dans outilVizMd.
L’utilisateur choisit “Nouveau document”, indique le nom et l’emplacement, puis confirme la
création. Le fichier vide est créé et ouvert dans l’aperçu. Annuler ne crée aucun fichier.
Aucun fichier existant ne doit être écrasé sans confirmation explicite. Prévoir les erreurs
de permissions, noms invalides et emplacement indisponible. Conserver le fonctionnement local
et hors ligne. L’édition du contenu reste hors périmètre. »

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Créer et consulter un document vide (Priority: P1)

Une personne crée un fichier Markdown à l’emplacement de son choix et retrouve immédiatement
ce document dans le lecteur, prêt à être rempli ultérieurement avec un autre outil.

**Why this priority**: Ce parcours apporte la nouvelle capacité demandée : produire un fichier
nommé et réellement présent sur le disque, puis le consulter.

**Independent Test**: Depuis l’accueil, choisir « Nouveau document », nommer le fichier dans un
dossier local disponible, confirmer et vérifier son emplacement, sa taille de zéro octet et
l’état « Document vide » dans l’aperçu.

**Acceptance Scenarios**:

1. **Given** l’accueil ou un document déjà ouvert, **When** l’utilisateur choisit « Nouveau
   document », **Then** il peut indiquer un nom et un dossier de destination ; aucun fichier
   n’est créé avant sa confirmation et le document actif reste inchangé pendant le choix.
2. **Given** un nom valide et une destination libre, **When** l’utilisateur confirme « Créer »,
   **Then** un seul fichier de zéro octet est créé au chemin annoncé et devient le document
   actif, avec son nom et l’aperçu « Document vide » ; les autres documents restent ouverts.
3. **Given** le nom « Compte rendu été » sans extension, **When** la destination est présentée
   pour confirmation, **Then** le nom final « Compte rendu été.md » est visible ; un nom se
   terminant déjà par `.md` ou `.markdown`, sans distinction de casse, conserve son extension.
4. **Given** un dossier affiché dans la navigation, **When** un fichier visible selon les règles
   existantes y est créé, **Then** il apparaît dans la liste correspondante sans relancer
   l’application ; une création ailleurs ne remplace pas le dossier actuellement parcouru.
5. **Given** une destination correspondant à un document déjà ouvert, y compris un document
   devenu introuvable, **When** la création ou le remplacement autorisé réussit, **Then** son
   entrée est réutilisée, devient active et présente le contenu courant sans doublon.

---

### User Story 2 - Annuler et protéger les fichiers existants (Priority: P1)

Une personne peut renoncer à la création ou choisir un autre nom sans modifier ses fichiers.
Si elle souhaite remplacer un fichier existant, elle confirme séparément cette opération en
sachant que son contenu deviendra vide.

**Why this priority**: La nouvelle capacité d’écriture doit préserver la maîtrise de
l’utilisateur sur ses documents et éviter toute perte involontaire.

**Independent Test**: Utiliser un dossier contenant un document non vide. Vérifier successivement
l’annulation du choix, le refus du remplacement, puis son acceptation explicite, en comparant
les fichiers et la session avant et après chaque action.

**Acceptance Scenarios**:

1. **Given** une création en cours de préparation, **When** l’utilisateur annule ou ferme le
   dialogue avant la confirmation de création, **Then** aucun fichier n’est créé, supprimé ou
   modifié et le document actif reste le même.
2. **Given** un fichier existant à la destination choisie, **When** l’utilisateur confirme
   « Créer », **Then** une confirmation distincte identifie le nom et l’emplacement et avertit
   que « Remplacer » effacera son contenu pour produire un fichier vide ; rien n’est encore écrit.
3. **Given** la confirmation de remplacement, **When** l’utilisateur choisit « Annuler »,
   **Then** le fichier et la session restent inchangés et il revient au choix du nom et de
   l’emplacement ; il peut choisir une autre destination ou abandonner toute la création.
4. **Given** cette confirmation distincte, **When** l’utilisateur choisit explicitement
   « Remplacer », **Then** seul le fichier désigné est remplacé par un fichier de zéro octet
   et son aperçu vide est ouvert ; cette décision ne vaut pour aucune autre opération.
5. **Given** une destination initialement libre, **When** un autre outil y crée un fichier avant
   l’écriture, **Then** la simple confirmation « Créer » ne permet pas de l’écraser : la
   confirmation distincte de remplacement est présentée, avec possibilité d’annuler sans écriture.

---

### User Story 3 - Corriger un problème sans perdre sa session (Priority: P1)

Une personne comprend pourquoi la création n’a pas abouti et peut corriger le nom, choisir
un autre emplacement ou réessayer sans perdre ses documents déjà ouverts.

**Why this priority**: Noms invalides, droits insuffisants et destinations indisponibles sont
les erreurs explicitement prévues par le besoin ; elles ne doivent pas rendre la session inutilisable.

**Independent Test**: Essayer un nom invalide, un dossier non autorisé, un dossier devenu
indisponible et un stockage saturé, puis reprendre avec une destination valide. Vérifier
séparément une création réussie dont l’ouverture dans l’aperçu échoue.

**Acceptance Scenarios**:

1. **Given** un nom vide, composé uniquement d’espaces ou refusé dans le dossier choisi,
   **When** l’utilisateur tente de confirmer, **Then** une explication en français permet de
   corriger le nom ; aucun fichier n’est créé et l’emplacement choisi est conservé.
2. **Given** des permissions insuffisantes ou une autorisation refusée, **When** la création
   est tentée, **Then** aucun fichier existant n’est altéré ; un message propose de choisir un
   autre emplacement ou de réessayer après correction des droits.
3. **Given** un dossier supprimé, un support déconnecté ou un stockage sans espace disponible,
   **When** la création échoue, **Then** le problème est signalé avec une récupération appropriée,
   sans résidu de création ni perte des documents déjà ouverts.
4. **Given** un échec suivi d’une correction, **When** l’utilisateur confirme à nouveau,
   **Then** le nom et la destination sont revérifiés, y compris les éventuels conflits apparus
   depuis l’essai précédent, et le parcours normal peut aboutir.
5. **Given** un fichier effectivement créé mais un aperçu impossible à ouvrir, **When** l’erreur
   est présentée, **Then** le message distingue la création réussie de l’échec d’ouverture,
   indique l’emplacement et propose de réessayer l’ouverture du même fichier. Le fichier reste
   présent et le document précédemment actif reste affiché ; réessayer ne recrée ni ne vide le fichier.

---

### Edge Cases

- Le nom `.` ou `..`, un nom contenant un séparateur de chemin ou un caractère interdit, et un
  nom trop long pour la destination sont refusés ; les espaces internes et accents valides sont acceptés.
- Un nom composé uniquement de l’extension, tel que `.md` ou `.markdown`, est traité comme un
  nom vide. Un fichier caché valide reste accessible dans les documents ouverts, mais suit les
  règles existantes d’exclusion des fichiers cachés dans l’arbre du dossier.
- Une extension différente de `.md` ou `.markdown` est signalée pour correction ; elle n’est pas
  remplacée silencieusement. L’ajout automatique de `.md` ne concerne qu’un nom sans extension.
- Un conflit dû aux règles de casse ou à l’équivalence des noms du stockage est traité comme
  un fichier existant, même si la saisie semble différente.
- Un dossier, un raccourci ou un lien vers un autre fichier occupe le nom final : la création
  est refusée à cet emplacement sans modifier cette entrée ni le fichier vers lequel elle pointe.
- Un fichier apparaît pendant la préparation : il est traité comme un conflit et n’est pas
  écrasé par la simple confirmation de création. Un changement de nom ou d’emplacement invalide
  tout accord de remplacement portant sur l’ancienne destination.
- Plusieurs activations de « Créer » ou « Remplacer » pour la même demande ne doivent produire
  ni fichiers supplémentaires ni répétition destructive de l’opération.
- Le dossier choisi n’est pas celui de la navigation : le nouveau document est ouvert sans
  étendre implicitement l’accès aux autres fichiers de son dossier.
- Un autre outil remplit le fichier après sa création : l’aperçu suit son contenu courant selon
  les règles existantes ; l’application ne le vide pas à nouveau pour rétablir l’état initial.
- L’ouverture de l’aperçu échoue après l’écriture ou l’application est fermée après la création :
  le fichier confirmé reste présent ; aucune nouvelle création n’est lancée automatiquement.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: L’application DOIT proposer « Nouveau document » depuis l’accueil et le menu
  Fichier, ainsi que le raccourci `⌘N`, y compris lorsqu’un autre document est actif (US1.1).
- **FR-002**: L’utilisateur DOIT pouvoir choisir un nom et un dossier existant. Le nom final,
  extension comprise, et l’emplacement DOIVENT être identifiables avant « Créer » ; la préparation
  de la demande NE DOIT provoquer aucune écriture dans les documents (US1.1–3).
- **FR-003**: Les extensions `.md` et `.markdown` DOIVENT être acceptées sans distinction de
  casse. Un nom sans extension DOIT recevoir `.md`, visible avant confirmation. Une autre
  extension DOIT être signalée pour correction, sans modification silencieuse (US1.3, cas limites).
- **FR-004**: Les noms vides, composés uniquement d’espaces ou d’une extension sans nom,
  `.` ou `..`, contenant un séparateur de chemin ou refusés par la destination DOIVENT être
  rejetés avec une explication. Les noms valides avec espaces et accents DOIVENT être conservés
  tels que confirmés (US3.1, cas limites).
- **FR-005**: Après confirmation d’une destination libre et valide, l’application DOIT créer
  exactement un fichier de zéro octet à cet emplacement, sans titre, contenu initial ou autre
  texte ajouté. Aucune autre destination NE DOIT être modifiée par cette opération (US1.2).
- **FR-006**: Toute annulation acceptée avant l’écriture, y compris la fermeture du dialogue ou
  l’annulation du remplacement, DOIT laisser les fichiers et le document actif inchangés. Annuler
  le remplacement DOIT rendre possible la correction de la destination ou l’abandon (US2.1, 3).
- **FR-007**: Une destination occupée par un fichier NE DOIT être remplacée qu’après une
  confirmation distincte de « Créer », identifiant ce fichier et avertissant que son contenu
  deviendra vide. Seule l’action explicite « Remplacer » autorise cette opération, une seule
  fois et pour cette cible ; aucune acceptation globale ou mémorisée n’est admise (US2.2–4).
- **FR-008**: La protection contre l’écrasement DOIT rester applicable si un fichier apparaît
  entre le choix de la destination et l’écriture : une simple confirmation de création NE DOIT
  PAS permettre son écrasement sans confirmation distincte de remplacement. Tout changement de nom
  ou d’emplacement DOIT invalider un accord portant sur l’ancienne destination (US2.5, cas limites).
- **FR-009**: Une entrée existante qui est un dossier, un raccourci ou un lien vers un autre
  fichier NE DOIT être ni remplacée ni suivie pour écrire. L’application DOIT permettre de
  choisir une autre destination. L’autorisation de création NE DOIT pas autoriser l’écriture
  dans d’autres fichiers ou l’accès implicite au dossier entier (cas limites).
- **FR-010**: Un échec avant la création ou le remplacement effectif DOIT préserver le contenu
  des fichiers existants et NE DOIT laisser ni fichier partiellement créé ni résidu de cette
  opération. Les noms invalides, permissions insuffisantes, destinations indisponibles et manque
  d’espace DOIVENT avoir un message français et une action de récupération adaptée (US3.1–4).
- **FR-011**: Après création réussie et ouverture possible, le document DOIT devenir actif avec
  son nom et son aperçu vide, sans fermer les autres documents. Une entrée déjà ouverte au même
  emplacement DOIT être réutilisée et actualisée sans doublon (US1.2, 5).
- **FR-012**: Un fichier créé dans le dossier parcouru ou dans un de ses sous-dossiers déjà
  dépliés DOIT apparaître dans la navigation sans relancer l’application s’il respecte les règles
  de visibilité existantes, notamment l’exclusion des fichiers cachés. Une création en dehors
  de ce périmètre NE DOIT changer ni le dossier parcouru ni ses autorisations (US1.4).
- **FR-013**: Si l’ouverture échoue après création effective, l’application DOIT signaler que le
  fichier a été créé et où il se trouve, conserver le document précédemment actif et proposer
  une nouvelle tentative d’ouverture sans recréation ni effacement. Elle NE DOIT PAS supprimer
  le fichier créé pour masquer cet échec (US3.5).
- **FR-014**: Les écritures sur les documents DOIVENT rester limitées aux créations et
  remplacements explicitement confirmés dans ce parcours. Consulter, rechercher, changer le
  rendu, actualiser ou fermer un document NE DOIT pas en modifier les octets ou l’emplacement.
  Aucun éditeur de contenu ni enregistrement automatique n’est ajouté (US1–3, cas limites).
- **FR-015**: Le parcours complet DOIT fonctionner localement et hors ligne, sans compte,
  service distant, transfert de documents ni télémétrie. Les protections de lecture et de rendu
  existantes DOIVENT être conservées (US1–3).
- **FR-016**: Le choix, la confirmation, le conflit, la création en cours, le succès et les erreurs
  DOIVENT être compréhensibles en français, utilisables au clavier et nommés pour les outils
  d’accessibilité, dans les apparences claire et sombre. Pendant l’écriture effective, l’opération
  DOIT être signalée et aucune action « Annuler » ne DOIT être proposée (US1–3).
- **FR-017**: Une demande confirmée NE DOIT produire qu’une seule opération de création ou de
  remplacement, même en cas d’activations répétées de la confirmation. Une reprise après erreur
  DOIT revérifier la destination et ne jamais réutiliser un consentement de remplacement devenu
  périmé (US3.4, cas limites).

### Key Entities *(include if feature involves data)*

- **Demande de création** : nom saisi, nom final avec extension, dossier choisi et décision de
  l’utilisateur ; sa préparation n’est pas encore un fichier sur le disque.
- **Destination** : emplacement exact du futur fichier et situation actuelle — libre, fichier
  existant, entrée non remplaçable ou emplacement inaccessible.
- **Confirmation de remplacement** : accord explicite lié au fichier désigné à un emplacement
  précis, avec avertissement de perte de contenu ; limité à une seule opération.
- **Document créé** : fichier effectivement présent, vide à l’issue de la création en l’absence
  de modification externe, et résultat distinct de son ouverture dans l’aperçu.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Pour chaque nom et destination valides du corpus, un seul fichier de zéro octet
  existe au chemin confirmé et l’aperçu vide est ouvert. Sur un stockage local disponible,
  l’aperçu est utilisable sous une seconde après la dernière confirmation dans au moins 19 essais
  sur 20, hors temps de saisie et sans modification externe concurrente.
- **SC-002**: Dans 100 % des annulations du corpus, aucun fichier n’est créé, supprimé ou modifié
  par la demande et le document actif reste inchangé.
- **SC-003**: Dans 100 % des conflits, y compris ceux apparus pendant la préparation ou la
  confirmation, aucun fichier n’est écrasé sans accord explicite portant sur la destination
  identifiée. Un remplacement confirmé n’affecte que la cible et aboutit à un fichier de zéro octet.
- **SC-004**: Chaque erreur prévue fournit une explication et une récupération sans arrêt de
  l’application. Les échecs avant écriture préservent tous les fichiers et la session ; un échec
  d’aperçu après écriture conserve le fichier créé et permet de réessayer sans nouvelle écriture.
- **SC-005**: Création, annulation, conflits, récupération et consultation du nouveau document
  présentent les mêmes résultats avec le réseau désactivé, sans transfert de contenu ; les
  fichiers non visés restent inchangés dans tous les parcours du corpus.
- **SC-006**: Le parcours de création, l’annulation, la décision de remplacement et chaque
  récupération sont réalisables entièrement au clavier dans les deux apparences. Toutes les
  actions ont un libellé accessible en français et les messages distinguent sans ambiguïté
  « fichier non créé » de « fichier créé, aperçu indisponible ».

## Assumptions

- Cette évolution s’appuie sur le lecteur de [001-visualiser-markdown-local](../001-visualiser-markdown-local/spec.md),
  ses documents ouverts, sa navigation et son état « Document vide ».
- Elle étend la règle de lecture seule de 001.FR-012 uniquement pour les créations et
  remplacements demandés ici. La consultation conserve ses garanties. Le principe V de la
  constitution autorise déjà une écriture visant explicitement une opération et une destination ;
  aucun amendement de la constitution n’est requis pour ce périmètre.
- Un nom initial « Nouveau document.md » peut être proposé et reste modifiable. Les extensions
  reconnues par le lecteur sont conservées ; les règles de validité et d’équivalence des noms du
  stockage choisi s’appliquent, sans interdire arbitrairement les accents ou espaces internes.
- Le dossier de destination existe déjà. Création de dossiers, modèles de documents, contenu
  initial, édition, duplication de contenu et enregistrement automatique sont hors périmètre.
- Le remplacement explicite fait partie du besoin retenu : il vide un fichier désigné après
  avertissement distinct. Aucune sauvegarde de secours ou fonction d’annulation après remplacement
  n’est promise par cette fonctionnalité.
- « Annuler » concerne les phases précédant l’écriture, notamment le choix et la confirmation
  de remplacement. Une fois l’écriture engagée, la création se termine ou signale son échec ;
  le parcours ne promet pas d’annuler une écriture déjà effectuée.
- La garantie hors ligne porte sur les dossiers locaux disponibles. Un emplacement déconnecté
  ou nécessitant un téléchargement est traité comme indisponible, sans téléchargement automatique.
- Les écritures concurrentes réalisées par un autre outil ne sont pas attribuées au lecteur.
  Après création, les modifications externes suivent le comportement de lecture existant.
- L’ouverture réussie applique les préférences globales de lecture. La création ne change pas
  les règles existantes de restauration de session et n’ajoute pas de persistance des autorisations.
