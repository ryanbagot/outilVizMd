# Contrat d’interface utilisateur et de ressources

## Commandes et états publics

| Action | Résultat attendu |
|--------|------------------|
| Ouvrir un fichier (Cmd+O) | Panneau natif, annulation sans changement ; lecture du fichier choisi |
| Ouvrir un dossier | Navigation dépliable dans le seul dossier autorisé |
| Sélectionner un document | Aperçu actif, chemin distinctif, position conservée si inchangé |
| Fermer le document (Cmd+W) | Fermer l’entrée active et libérer ses ressources ; aucun fichier effacé |
| Rechercher (Cmd+F) | Champ natif, total et position, actions précédent/suivant avec boucle |
| Fermer la recherche (Échap dans le champ) | Effacer requête et repères, rendre le focus à la lecture |
| Actualiser | Relire le document ou actualiser la liste selon l’action nommée |
| Préférences (Cmd+,) | Thème, police, taille, style, couleurs, contraste et réinitialisation |
| Aide | Guide français embarqué, sans ouverture réseau nécessaire |

États présentés : accueil avec actions visibles ; chargement annulable ; document vide ; aperçu
à jour ; dernier aperçu obsolète avec avertissement ; erreur sans aperçu ; dossier vide. Les actions
essentielles disposent d’un nom accessible ; la sélection et les erreurs ne dépendent pas uniquement
de la couleur. Les repères de recherche ne changent pas les octets du document.

## Documents et ressources locales

Le panneau autorise un fichier seul ou un dossier et ses descendants réels. Un fichier choisi
seul n’autorise pas les images voisines ; proposer de choisir explicitement leur dossier en cas de
besoin. Dans les descendants, les symlinks sont refusés ; leur cible peut être choisie directement.
Les URL du document sont décodées et validées avant lecture, les traversées ou encodages ambigus
sont refusés. Les erreurs incluent un texte alternatif lisible pour les images.

## Schéma privé du rendu

- Forme logique : `outilvizmd://preview/<previewToken>/document` et
  `outilvizmd://preview/<previewToken>/resource/<resourceID>` ; fragment séparé pour les ancres.
- Jetons aléatoires non devinables, ressources connues d’un seul aperçu. Ces URL sont uniquement
  internes ; aucune association Launch Services ni commande externe n’est installée pour ce schéma.
- Aucun segment ne représente un chemin sur disque. Query, hôte inconnu, ressource inconnue,
  séquence ambiguë ou jeton révoqué → refus ; aucun repli vers un accès fichier.
- MIME fermés : text/html, text/css, image/png, image/jpeg ; le GIF est décodé et sa première image
  réencodée en PNG. Aucune réponse HTML à une requête d’image.
- HTML et CSS générés, images autorisées validées et copiées dans l’instantané ; aucun SVG,
  iframe, script, objet, formulaire, @import, URL distante ou redirection de ressource.
- Les tâches annulées ne reçoivent plus de callbacks ; les ressources sont libérées une fois
  l’aperçu non utilisé et ses tâches terminées/annulées.

## Navigation et défense réseau

| Destination | Comportement |
|-------------|--------------|
| Fragment du document généré | Rejoindre l’ancre existante, sans chargement externe |
| Lien vers Markdown autorisé | Intercepter et ouvrir via ReadingCoordinator ; pas de navigation file:// |
| Lien local hors périmètre | Refuser ; offrir une sélection explicite, ne jamais lire avant autorisation |
| HTTP ou HTTPS | Clic explicite seulement, navigateur système après validation de l’URL |
| Tout autre schéma ou popup | Refuser ; message si action utilisateur, pas d’ouverture de fichier ou programme |

Les destinations originales des liens locaux peuvent être remplacées dans le HTML par des jetons
résolus côté natif. Ne jamais donner au HTML un lien file:// utilisable directement.
Avant toute page : JS désactivé, magasin non persistant, CSP et règles WebKit bloquant http/https.
Les règles doivent être installées avec succès ; sinon le lecteur refuse d’afficher plutôt que de
charger avec une protection absente. Refuser aussi les téléchargements et nouvelles fenêtres.
Le droit réseau client est requis pour initialiser WebKit même sur une page locale ; aucun droit
serveur n’est accordé. La présence de ce droit n’autorise aucun chargement automatique. Vérifier
les refus avant envoi et l’absence de connexions sur le corpus passif ; les règles seules ne
certifient pas l’absence de connexion spéculative lors d’une navigation réseau forcée.

## Contrats de test observables

Vérifier liens activés et non activés, requêtes de sous-ressources, encodages multiples, chemins
absolus/relatifs, symlinks permutés pendant une lecture, disparition et recréation d’un fichier,
annulation pendant chargement et jeton d’un autre aperçu. Une ouverture réseau par le navigateur
système après clic est distincte d’une connexion automatique de l’app. Mesurer cette dernière
avec la connexion disponible puis refaire les parcours hors ligne.
