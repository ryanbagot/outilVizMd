Lire vos documents Markdown

Ouvrir et fermer
Ouvrez un fichier .md ou .markdown avec Fichier → Ouvrir un fichier (⌘O). Le texte doit être en UTF-8 ; une marque BOM et les fins de ligne Windows sont acceptées. La limite est de 10 Mio par fichier. Un document vide possède son propre état d’accueil. Fermez le document actif avec ⌘W.

Naviguer
Ouvrez un dossier avec ⇧⌘O. La barre latérale montre ses documents Markdown et ses sous-dossiers. Dépliez seulement les dossiers utiles. Les fichiers cachés et les liens symboliques descendants sont exclus. Les documents déjà ouverts restent accessibles dans la même session. ⇧⌘R actualise la liste du dossier ; ⌘R relit le document.

Images et liens
Un fichier choisi seul n’autorise pas automatiquement son dossier. Pour afficher ses images locales PNG, JPEG ou GIF, choisissez explicitement le dossier qui les contient. Une image refusée est remplacée par un texte alternatif. Les images trop lourdes, SVG et ressources distantes restent indisponibles. Les liens Markdown locaux doivent rester dans un emplacement déjà autorisé. Un clic explicite sur un lien Web HTTP(S) ouvre votre navigateur habituel ; il peut alors utiliser le réseau.

Rechercher
⌘F ouvre la recherche du document actif. La recherche est littérale, sans distinction de casse, avec distinction des accents : « café » et « cafe » sont différents. Les caractères comme [ et * sont cherchés tels quels. Le compteur représente les occurrences, y compris lorsqu’un résultat traverse plusieurs éléments de mise en forme. Les flèches ou ⌘G / ⇧⌘G parcourent les résultats en boucle. Échap ferme la recherche et rend le focus à la lecture. Changer de document efface la recherche.

Personnaliser
⌘, ouvre les réglages. Choisissez l’apparence système, claire ou sombre, une police locale, une taille de 12 à 32 points et un espacement. Les couleurs du texte, du fond et des liens sont distinctes pour les deux apparences. Un avertissement indique un contraste inférieur à 4,5:1 ; votre choix reste appliqué. Vous pouvez rétablir les couleurs ou réinitialiser tous les réglages. Seuls ces réglages globaux sont enregistrés ; les documents et autorisations ne sont pas restaurés à la relance.

Suivre les modifications
Vous pouvez modifier le document dans votre éditeur habituel. Le lecteur vérifie les sauvegardes et remplacements au même emplacement. Une suppression, un déplacement ou une perte d’accès conserve le dernier aperçu avec « Aperçu non à jour ». Réessayez ou sélectionnez le nouvel emplacement. L’application ne recrée jamais le fichier. Une recréation au même emplacement autorisé déclenche une nouvelle vérification.

Lecture seule et fonctionnement local
Le lecteur ne possède aucune commande d’édition ou de sauvegarde du document. La lecture, la recherche, les thèmes, l’aide et les mentions de licences fonctionnent localement. JavaScript est désactivé ; le HTML brut des documents est affiché comme texte. Aucun contenu distant n’est chargé automatiquement. L’application demande explicitement les accès aux fichiers par le panneau macOS.

En cas de difficulté
Vérifiez l’encodage UTF-8 et la taille du fichier, puis utilisez Réessayer. Si l’accès manque, choisissez le fichier ou son dossier. Annuler une sélection conserve votre session. Les erreurs d’enregistrement des réglages ne bloquent pas la lecture : les valeurs restent appliquées pendant la session.
