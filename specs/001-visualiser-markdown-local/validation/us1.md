# US1 — suivi d’implémentation

Les contrats de lecture, parseur et rendu ont été écrits avant les services ; le premier cycle
échouait à la compilation pour les types encore absents. Les services sont maintenant branchés
à une fenêtre native avec commandes d’ouverture, fermeture et récupération.

La suite unitaire/intégration courante réussit avec `-only-testing:outilVizMdTests`. Elle vérifie
notamment BOM/CRLF, UTF-8 strict, NUL refusé, vide, 10 Mio inclus et dépassement, scopes de fichier
et dossier, liens symboliques descendants refusés, corpus Markdown, échappement du HTML,
ressources à jetons, décodage PNG/JPEG/GIF et préservation octet par octet.

La lecture effective est coordonnée dans l’acteur d’accès, via descripteurs O_RDONLY et O_NOFOLLOW.
Les images sont limitées à 16 Mio compressés, 16 777 216 pixels par image et 64 Mio de budget
par aperçu ; le GIF est réencodé en PNG à partir de sa première image. Aucun MIME du document
n’est utilisé. Les vues WebKit sont créées seulement après installation des protections.

T018 : deux parcours XCUITest réussis le 2026-11-06 (résultat 22-02-45) : accueil/annulation,
puis ouverture d’un fichier temporaire, titre et contenu WebKit visibles, Cmd+W, retour à
l’accueil et octets inchangés. Le panneau natif est ciblé par ses identifiants stables.
La vérification native a aussi confirmé les images indisponibles avec un grant de fichier seul,
puis leur affichage PNG/JPEG/GIF après choix explicite du dossier Fixtures.

T030 : les contrôles automatisés d’ouverture réussissent. Le test avec réseau physiquement
coupé reste à consigner dans la validation transversale ; aucune coupure de la connexion de
l’utilisateur n’a été effectuée. Cette vérification reste une condition de livraison.
Les mesures de délai et la validation complète du corpus hostile restent dans les phases prévues.
