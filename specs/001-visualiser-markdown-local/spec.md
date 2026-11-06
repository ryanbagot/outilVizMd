# Feature Specification: outilVizMd — visualisation de Markdown local

**Feature Branch**: Aucune branche dédiée créée ; fonctionnalité repérée par son dossier.

**Created**: 2026-11-06

**Status**: Draft — spécification validée, prête pour la planification

**Input**: User description: « Créer outilVizMd, une application de bureau macOS permettant de
parcourir, ouvrir et visualiser des fichiers Markdown locaux. L'utilisateur doit pouvoir naviguer
entre plusieurs documents, afficher les titres, listes, tableaux, liens, images et blocs de code,
rechercher du texte et personnaliser le rendu : thèmes clair/sombre, polices, tailles, couleurs et
styles. Les préférences sont conservées entre les sessions. Les modifications externes des fichiers
doivent être reflétées dans l'aperçu. L'interface doit être intuitive pour un débutant, rapide et
utilisable hors ligne. Pour le MVP, les fichiers sont en lecture seule. Définir des scénarios
utilisateur, les cas d'erreur et des critères d'acceptation vérifiables. »

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ouvrir et lire un document local (Priority: P1)

Une personne débutante ouvre un fichier Markdown depuis une action visible dans la fenêtre et
consulte son contenu mis en forme, sans apprendre de syntaxe ni risquer de modifier l’original.

**Why this priority**: L’ouverture et la lecture sûres constituent la valeur première du MVP.

**Independent Test**: Depuis une session sans document, ouvrir un fichier contenant tous les
éléments pris en charge, réseau coupé ; comparer le rendu au contenu attendu et les octets du
fichier avant et après consultation et fermeture.

**Acceptance Scenarios**:

1. **Given** une fenêtre sans document, **When** l’utilisateur la découvre, **Then** une action
   « Ouvrir un fichier » et une action « Ouvrir un dossier » sont visibles avec une explication courte.
2. **Given** un fichier valide, **When** il est sélectionné, **Then** son nom et son aperçu sont
   affichés, avec un indicateur de chargement si nécessaire ; annuler le choix ne change rien.
3. **Given** un document contenant titres de niveaux 1 à 6, paragraphes, emphase, listes ordonnées
   et non ordonnées imbriquées, citations, tableaux simples, liens, images locales et code,
   **When** il est affiché, **Then** les éléments sont distinguables, dans l’ordre du source ; les
   espaces et retours du code sont conservés et les tableaux larges restent consultables.
4. **Given** une image locale autorisée et un lien vers un titre du document, **When** l’utilisateur
   consulte l’image puis active le lien, **Then** l’image respecte la largeur disponible et le lien
   rejoint le titre sans quitter le document.
5. **Given** un document affiché, **When** l’utilisateur consulte, sélectionne, copie du texte,
   change le rendu puis ferme l’application, **Then** les octets et l’emplacement du source restent
   identiques ; aucune commande d’édition ou de sauvegarde du source n’est proposée.
6. **Given** un document vide ou une syntaxe Markdown incomplète, **When** il est ouvert,
   **Then** un état vide explicite ou un rendu lisible du contenu est présenté sans arrêt brutal.

---

### User Story 2 - Parcourir un dossier et naviguer entre documents (Priority: P1)

Une personne choisit un dossier de documentation, parcourt ses sous-dossiers et passe entre
plusieurs fichiers sans devoir les sélectionner à nouveau à chaque changement.

**Why this priority**: La consultation d’un ensemble de documents fait partie du besoin central.

**Independent Test**: Choisir un dossier comportant trois documents dont deux homonymes dans des
sous-dossiers, les ouvrir successivement puis revenir au premier et fermer un document.

**Acceptance Scenarios**:

1. **Given** un dossier choisi explicitement, **When** la navigation s’affiche, **Then** les dossiers
   sont dépliables à la demande, les fichiers `.md` et `.markdown` sont visibles sans distinction de
   casse, triés par nom dans chaque dossier ; les autres fichiers ne sont pas proposés comme documents.
2. **Given** plusieurs documents ouverts, **When** l’utilisateur sélectionne l’un d’eux,
   **Then** il devient actif ; revenir à un document conserve sa position de lecture pour la session
   tant que son contenu n’a pas changé.
3. **Given** deux fichiers de même nom et un fichier déjà ouvert, **When** ils sont sélectionnés,
   **Then** leurs chemins permettent de les distinguer et rouvrir le même fichier ne le duplique pas.
4. **Given** un lien vers un autre Markdown dans le dossier autorisé, **When** il est activé,
   **Then** ce document devient actif ; hors du périmètre autorisé, son ouverture est bloquée et une
   action permet de sélectionner explicitement le fichier ou son dossier pour l’autoriser.
5. **Given** plusieurs documents ouverts, **When** le document actif est fermé,
   **Then** un autre document ouvert devient actif, ou l’état initial réapparaît s’il était le dernier.
   Aucun fichier n’est supprimé ni écrit.
6. **Given** un dossier affiché, **When** un fichier Markdown y est ajouté ou supprimé de l’extérieur,
   **Then** la navigation reflète le changement à la prochaine actualisation explicite ; aucun parcours
   ne sort du dossier autorisé par un lien symbolique.

---

### User Story 3 - Rechercher dans le document actif (Priority: P2)

Une personne retrouve un passage en recherchant du texte sans quitter la lecture.

**Why this priority**: La recherche évite le défilement manuel dans les documents longs.

**Independent Test**: Ouvrir directement un document avec des occurrences dans un titre, un tableau
et un bloc de code ; rechercher un terme, parcourir les résultats puis effacer la requête.

**Acceptance Scenarios**:

1. **Given** un document actif, **When** l’utilisateur ouvre la recherche par son action ou Cmd+F et
   saisit du texte, **Then** les occurrences du texte affiché sont repérées et leur nombre indiqué.
2. **Given** plusieurs résultats, **When** l’utilisateur choisit suivant ou précédent,
   **Then** la vue rejoint le résultat, indique sa position et boucle entre premier et dernier.
3. **Given** une requête absente du texte, vide ou composée de caractères spéciaux, **When** elle est saisie,
   **Then** la recherche indique zéro résultat si la requête est absente du texte ou vide, retire les repères si vide et traite les caractères
   spéciaux comme du texte littéral, y compris lorsqu’ils sont présents dans le document ; elle ne distingue pas majuscules et minuscules, mais distingue les accents.
4. **Given** une recherche active, **When** elle est fermée ou le document actif change,
   **Then** ses repères sont retirés et sa requête est réinitialisée, sans modifier le document.

---

### User Story 4 - Personnaliser et retrouver son confort de lecture (Priority: P2)

Une personne ajuste l’apparence du rendu et retrouve ses choix au prochain lancement.

**Why this priority**: Le confort de lecture est une fonction demandée, limitée à des réglages
simples pour contenir le périmètre du MVP.

**Independent Test**: Ouvrir un fichier directement, modifier chaque réglage, relancer l’application
et rouvrir ce fichier ; vérifier les valeurs conservées puis rétablir les valeurs initiales.

**Acceptance Scenarios**:

1. **Given** un aperçu, **When** le thème clair, sombre ou système est sélectionné,
   **Then** les fonds et textes de l’interface et du rendu s’adaptent ; le mode système suit
   l’apparence macOS et le mode explicite reste inchangé quand celle du système change.
2. **Given** les réglages de lecture, **When** l’utilisateur choisit une famille de police locale,
   une taille de 12 à 32 points et le style « standard », « compact » ou « aéré »,
   **Then** l’aperçu reflète les choix ; le code conserve une police à chasse fixe.
3. **Given** les couleurs du thème actif, **When** les couleurs du texte, du fond ou des liens sont
   ajustées, **Then** l’aperçu s’actualise sans toucher au source ; une combinaison insuffisamment
   contrastée est signalée et un retour aux couleurs initiales est disponible.
4. **Given** des préférences modifiées, **When** l’application est quittée puis relancée,
   **Then** les mêmes valeurs sont restaurées pour les documents ouverts ensuite ; « Réinitialiser »
   rétablit et conserve les valeurs par défaut après un nouveau lancement.
5. **Given** des préférences absentes, invalides ou une police devenue indisponible, **When**
   l’application démarre, **Then** les valeurs concernées reviennent à une valeur utilisable sans
   empêcher l’ouverture d’un document ; les autres choix valides sont conservés.

---

### User Story 5 - Suivre les modifications externes (Priority: P2)

Une personne modifie un fichier dans un autre outil et consulte son aperçu à jour dans outilVizMd.

**Why this priority**: Le lecteur doit rester fiable pendant un travail réalisé dans un éditeur
externe ; aucune fonction d’édition n’est ajoutée au MVP.

**Independent Test**: Ouvrir un document, l’enregistrer de l’extérieur par écriture directe puis
remplacement du fichier, et vérifier les mises à jour sans rouvrir le lecteur.

**Acceptance Scenarios**:

1. **Given** un document actif, **When** une modification externe est terminée,
   **Then** son aperçu reflète la dernière version lisible sans action manuelle, au plus tard deux
   secondes après stabilisation du fichier jusqu’à 1 Mio, et cinq secondes jusqu’à 10 Mio,
   dans les conditions de référence.
2. **Given** un document ouvert mais inactif, **When** il change à l’extérieur puis devient actif,
   **Then** le lecteur vérifie son actualité avant de le présenter comme à jour.
3. **Given** une recherche et une position de lecture, **When** un rafraîchissement réussit,
   **Then** les résultats sont recalculés et la position est conservée si possible, sinon ramenée
   à une position valide ; la dernière version finit toujours par être affichée après une rafale.
4. **Given** un document déjà affiché, **When** il est supprimé, déplacé ou devient illisible,
   **Then** le dernier aperçu reste visible avec un avertissement « aperçu non à jour » et des actions
   pour réessayer, sélectionner un fichier ou fermer ; aucun fichier n’est recréé.
5. **Given** une indisponibilité temporaire, **When** le fichier redevient lisible au même emplacement,
   **Then** l’aperçu est actualisé et l’avertissement disparaît ; une action d’actualisation manuelle
   reste disponible si le suivi automatique ne peut pas fonctionner.

---

### User Story 6 - Consulter un document non fiable en sécurité (Priority: P1)

Une personne lit un fichier reçu d’un tiers sans accès réseau automatique, lecture de fichiers
non autorisés ni exécution de contenu actif.

**Why this priority**: La confidentialité et la préservation des documents sont des garanties
obligatoires dès la première version utilisable.

**Independent Test**: Ouvrir, hors ligne puis réseau disponible, un corpus contenant liens
exécutables, contenu actif, images distantes et chemins sortant du dossier autorisé ; observer
les refus et vérifier les sources et l’absence de connexions automatiques.

**Acceptance Scenarios**:

1. **Given** une image distante ou un contenu actif intégré, **When** le document est ouvert,
   **Then** aucun contenu distant n’est téléchargé, aucune action n’est exécutée et un remplacement
   lisible signale l’image indisponible ; le reste du document reste consultable.
2. **Given** un lien web http ou https, **When** le document est simplement affiché,
   **Then** aucun site n’est contacté ; un clic explicite ouvre le lien dans le navigateur système.
   Un lien à schéma non autorisé est bloqué avec un message compréhensible.
3. **Given** une image ou un document local situé hors du périmètre autorisé, y compris via un chemin
   relatif ou un lien symbolique, **When** le lecteur tente de l’afficher, **Then** aucun accès au
   contenu n’a lieu et l’utilisateur peut choisir explicitement le dossier nécessaire.
4. **Given** le réseau coupé, **When** l’utilisateur parcourt, lit, recherche, personnalise puis
   relance l’application, **Then** ces fonctions restent disponibles sans compte ni connexion.

### Edge Cases

- Accès refusé ou autorisation révoquée : message en français, sans source écrite ; nouvelle sélection
  proposée. L’annulation laisse le document actif intact.
- Fichier supprimé avant sa première lecture : erreur sans aperçu trompeur ; après lecture réussie,
  conservation du dernier aperçu explicitement signalé comme non à jour.
- Fichier vide : état « Document vide », recherche à zéro résultat et navigation utilisable.
- Fichier non textuel (présence d’un octet NUL) ou encodage non pris en charge : refus explicite, aucune conversion implicite.
- Document supérieur à 10 Mio : refus explicite avec la limite et possibilité d’ouvrir un autre fichier.
- Markdown mal formé ou HTML brut : contenu traité comme texte ou neutralisé ; aucune exécution.
- Image absente, illisible, hors périmètre, distante ou de format non pris en charge : texte alternatif
  lorsqu’il existe et indication d’indisponibilité ; jamais de blocage du document entier.
- Dossier vide ou inaccessible : état explicite et possibilité de choisir un autre dossier.
- Arborescence cyclique via liens symboliques : pas de boucle et pas de sortie du périmètre autorisé.
- Modifications rapides, remplacement du fichier ou contenu transitoirement illisible : ne pas laisser
  un ancien résultat remplacer le plus récent ; conserver un aperçu signalé en cas d’échec.
- Erreur de conservation des préférences : réglages utilisables pour la session et avertissement
  indiquant qu’ils risquent de ne pas être restaurés ; aucune écriture dans les documents.
- Changement de document pendant une lecture ou une recherche : aucun résultat du document précédent
  ne doit être présenté comme appartenant au nouveau document.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: L’application DOIT proposer l’ouverture explicite d’un fichier local ou d’un dossier,
  sans compte, avec annulation sans effet de bord (US1.1–2, US2.1).
- **FR-002**: Elle DOIT parcourir les sous-dossiers autorisés à la demande, filtrer les extensions
  `.md` et `.markdown`, distinguer les homonymes et actualiser la liste à la demande (US2.1, 3, 6).
- **FR-003**: Elle DOIT conserver plusieurs documents ouverts, un seul actif, éviter les doublons,
  mémoriser leur position durant la session et permettre leur fermeture sans supprimer de fichier
  (US2.2–3, 5).
- **FR-004**: Elle DOIT restituer les éléments de US1.3, avec une interprétation cohérente de la syntaxe
  Markdown courante et l’extension des tableaux simples à colonnes séparées par des barres verticales.
  Les blocs de code clôturés et indentés sont pris en charge ; leur coloration n’est pas requise.
- **FR-005**: Elle DOIT afficher les images locales autorisées PNG, JPEG et GIF (première image
  suffisante), leur texte alternatif en cas d’échec, les liens internes vers des titres et les liens
  entre documents autorisés, sans chargement distant automatique (US1.4, US2.4, US6.1–3).
- **FR-006**: Elle DOIT proposer une recherche littérale dans tout le texte affiché du document actif,
  y compris titres, tableaux et code, avec repères, nombre, position et parcours bidirectionnel.
  Les destinations de liens et balises non affichées sont exclues ; les règles de casse, accents,
  effacement et changement de document sont celles de US3.1–4.
- **FR-007**: Elle DOIT proposer les thèmes clair, sombre et système ; le choix système est la valeur
  initiale (US4.1).
- **FR-008**: Elle DOIT proposer les polices locales, tailles, styles et couleurs de US4.2–3.
  Les couleurs sont conservées séparément pour les apparences claire et sombre ; un contraste
  texte/fond ou lien/fond inférieur à 4,5:1 déclenche un avertissement sans bloquer la personnalisation.
- **FR-009**: Elle DOIT conserver localement les préférences globales entre sessions, permettre la
  réinitialisation, gérer les valeurs invalides et signaler un échec de conservation (US4.4–5, cas limites).
- **FR-010**: Elle DOIT refléter les modifications externes des documents ouverts, y compris les
  sauvegardes par remplacement, rejeter les résultats obsolètes et offrir une actualisation manuelle
  (US5.1–3, 5).
- **FR-011**: Elle DOIT distinguer un aperçu à jour d’un dernier aperçu conservé après erreur ; un
  échec ne doit jamais masquer silencieusement l’obsolescence ni recréer le fichier (US5.4–5).
- **FR-012**: Le MVP DOIT être intégralement en lecture seule : aucune édition, sauvegarde,
  normalisation, conversion, suppression ou modification de l’emplacement des sources. Les réglages
  internes DOIVENT être séparés des documents ; consulter ne vaut jamais autorisation d’écrire (US1.5).
- **FR-013**: Le lecteur DOIT neutraliser tout contenu actif, bloquer les liens exécutables, empêcher
  les lectures hors périmètre y compris via liens symboliques, et limiter les liens web ouvrables à
  http et https sur action explicite. Les autres schémas sont refusés (US6.1–3).
- **FR-014**: Toutes les fonctions de consultation DOIVENT fonctionner hors ligne, sans transfert de
  documents, télémétrie, ressources de rendu distantes ni connexion automatique (US6.4).
- **FR-015**: L’interface DOIT afficher les états initial, vide, chargement et erreur, avec messages
  compréhensibles en français et une action de récupération pour chaque erreur (US1.1–2, 6, cas limites).
- **FR-016**: Ouvrir, parcourir, sélectionner, fermer, rechercher et régler le rendu DOIVENT être
  accessibles au clavier et avoir des libellés lisibles par les outils d’accessibilité ; les apparences
  par défaut DOIVENT rester lisibles en clair et sombre. Aucun traitement long ne doit empêcher
  de changer de document ou d’annuler une ouverture (US1–4, SC-002, SC-007).
- **FR-017**: Les documents UTF-8, avec ou sans marque initiale et avec les fins de ligne courantes,
  DOIVENT être acceptés jusqu’à 10 Mio inclus ; les fichiers incompatibles ou au-delà de la limite
  DOIVENT être refusés sans conversion et sans interrompre la session (US1.6, cas limites).
- **FR-018**: Une aide concise en français DOIT expliquer comment ouvrir, naviguer, rechercher,
  personnaliser, autoriser les ressources locales et comprendre les limites de lecture seule et hors
  ligne ; elle DOIT être consultable sans réseau (US1, US6, SC-007).

### Key Entities *(include if feature involves data)*

- **Document local** : emplacement et identité du fichier, nom, contenu lu, état de disponibilité,
  dernière version connue ; associé à un périmètre d’accès et à un aperçu.
- **Périmètre autorisé** : fichier ou dossier choisi explicitement par l’utilisateur, ressources
  accessibles et état d’autorisation ; un fichier choisi seul n’autorise pas implicitement ses voisins.
- **Session de lecture** : ensemble des documents ouverts, document actif et position par document ;
  sa restauration après fermeture de l’application n’est pas requise dans le MVP.
- **Aperçu** : représentation consultable d’une version du document, état à jour ou obsolète,
  ressources indisponibles et position de lecture.
- **Recherche** : requête du document actif, résultats dans le texte affiché et résultat sélectionné ;
  donnée temporaire réinitialisée lors du changement de document.
- **Préférences de rendu** : thème, police, taille, style, couleurs par apparence ; communes aux
  documents, conservées localement jusqu’à modification ou réinitialisation explicite.

## Success Criteria *(mandatory)*

### Measurable Outcomes

Les mesures de temps sont réalisées sur un Mac Apple Silicon avec au moins 8 Go de mémoire,
un stockage local disponible et sans charge de fond importante. Le corpus et la configuration
exacte sont consignés avec les résultats. Chaque mesure de délai comporte 20 répétitions ;
le seuil indiqué doit être tenu pour au moins 19 d’entre elles, sauf mention « tous les cas ».

- **SC-001**: Le corpus de référence restitue correctement tous les éléments de US1.3 et les
  ressources locales autorisées, hors ligne, dans tous les cas ; les différences purement
  typographiques n’affectant pas la structure ne constituent pas un échec.
- **SC-002**: Pour un document jusqu’à 1 Mio, l’aperçu est lisible sous 1 seconde après sélection ;
  jusqu’à 10 Mio, sous 3 secondes. Le passage vers un document déjà chargé prend moins de 300 ms.
  Pendant ces opérations, une action de navigation ou d’annulation reçoit un retour sous 300 ms.
- **SC-003**: Une recherche dans un document jusqu’à 1 Mio affiche son nombre de résultats sous
  300 ms après la dernière saisie ; un document jusqu’à 10 Mio le fait sous 1 seconde. Parcourir
  un résultat le rend visible et actualise sa position sans erreur dans tous les cas du corpus.
- **SC-004**: Un document actif jusqu’à 1 Mio reflète un changement externe stabilisé sous 2 secondes ;
  jusqu’à 10 Mio, sous 5 secondes. Une rafale de dix sauvegardes terminée aboutit à la dernière
  version dans ces délais, sans inversion ni disparition silencieuse du dernier aperçu lisible.
- **SC-005**: Les tests de consultation, navigation, recherche, personnalisation, erreurs et fermeture
  conservent dans 100 % des cas les octets et emplacements des sources de référence. Le corpus
  malveillant ne provoque ni exécution, ni lecture hors autorisation, ni connexion automatique.
- **SC-006**: Chaque préférence modifiée est conservée à l’identique après trois cycles de fermeture
  et relance ; chaque valeur invalide déclenche le repli prévu. Une modification du rendu devient
  visible sous 300 ms sur un document jusqu’à 1 Mio et sous 1 seconde jusqu’à 10 Mio.
- **SC-007**: Au moins quatre personnes sur cinq ne connaissant pas l’application ouvrent un dossier,
  consultent deux documents, recherchent un terme et changent de thème en moins de cinq minutes,
  avec l’aide intégrée seule. Un contrôle distinct réalise ces actions intégralement au clavier,
  vérifie leurs libellés d’accessibilité et les apparences claire et sombre.
- **SC-008**: Tous les scénarios US1 à US5 sont exécutables réseau désactivé ; tous les cas d’erreur
  définis présentent un message et une récupération sans arrêt de l’application. La navigation
  dans un dossier de 1 000 entrées immédiates est utilisable sous 1 seconde après sélection.

## Assumptions

- Le MVP cible macOS 14 et versions ultérieures ; c’est une hypothèse de compatibilité produit
  à vérifier lors de la planification. Il vise une utilisation individuelle et des fichiers stockés
  sur un disque local accessible. Les emplacements nécessitant un téléchargement préalable ne sont
  pas garantis hors ligne ; les systèmes de fichiers réseau sortent des conditions de performance.
- Les limites UTF-8 et 10 Mio sont des choix initiaux du MVP. Le corpus de performance comprend
  documents représentatifs avec titres, listes, tableaux et code ; les images utilisées pour les
  mesures sont locales et leur poids total est limité à 5 Mio par document. Les images plus lourdes
  doivent échouer proprement si elles ne peuvent être affichées, sans garantie de délai de rendu.
- Choisir un dossier autorise ses descendants réels ; choisir un fichier seul autorise ce fichier.
  Afficher une image voisine peut donc nécessiter une sélection explicite du dossier parent.
  Les autorisations sont redemandées si elles ne sont plus disponibles ; restaurer les documents
  ouverts et leurs autorisations au lancement suivant est hors périmètre.
- La navigation automatique suit les changements des documents ouverts. Pour la liste des dossiers,
  une actualisation explicite suffit au MVP ; l’indexation globale et la recherche multi-document
  sont exclues. La recherche porte sur le texte rendu, sans expressions régulières.
- Les personnalisations restent globales et passent par des contrôles dédiés et trois styles
  prédéfinis ; l’import de thèmes, les feuilles de style libres et les réglages par document sont exclus.
- Les images distantes ne sont jamais chargées. Les images vectorielles, animations obligatoires,
  diagrammes, formules mathématiques, extensions actives et coloration syntaxique avancée sont exclus.
- L’édition Markdown, les exports, la synchronisation, le cloud, la collaboration, les plugins et
  la modification de fichiers sont hors MVP. Une évolution vers l’édition sera spécifiée séparément.
- L’application dépend uniquement des droits de lecture accordés par l’utilisateur et des polices
  disponibles localement pour ses parcours ; aucun compte ni service distant n’est nécessaire.
- Les choix de langage, composants de rendu, moteur et organisation du code demandés précédemment
  seront traités dans le plan technique, distinct de cette spécification fonctionnelle.
