# Corpus de référence

Ces fichiers sont des données de tests, jamais des documents personnels. Les tests en font
des copies dans un répertoire temporaire avant toute modification externe intentionnelle.

| Fichier | Attendu |
|---------|---------|
| CommonMark.md | Titres 1–6, listes imbriquées, emphase, citation, tableau, code, Unicode et ancres |
| Navigation/ | Trois documents, dont deux homonymes, extensions de casse variée ; ignored.txt exclu |
| Images/sample.png, sample.jpg, sample.gif | Raster valide ; GIF affiché sur sa première image |
| Empty.md | État Document vide, recherche à zéro résultat |
| InvalidUTF8.md | Refus explicite sans conversion |
| BOM-CRLF.md | BOM et CRLF acceptés ; octets source inchangés |
| Malformed.md | Rendu lisible sans crash |
| Malicious/active.md | HTML inerte, destinations non autorisées refusées, aucune connexion automatique |

Les ancres de titres dupliqués sont distinctes. Les images voisines d’un fichier autorisé seul
restent indisponibles jusqu’au choix explicite du dossier. La navigation ne suit aucun symlink.
Les liens `example.invalid` n’autorisent aucun accès réseau implicite.

Créer à l’exécution les fichiers de 10 Mio et 10 Mio + 1 octet, dossiers de 1 000 entrées,
liens symboliques (y compris cycles et permutations), fichiers spéciaux et cas de permissions.
Ne pas versionner de gros fichiers ni de liens pouvant viser un emplacement personnel.

Les recherches de caractères spéciaux sont littérales selon FR-006 ; US3.3 a été clarifiée en conséquence. Une requête vide ou absente produit zéro résultat.
