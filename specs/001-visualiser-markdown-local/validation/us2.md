# US2 — navigation vérifiée

27 tests unitaires/intégration réussis après correction du rafraîchissement de dossier :
les streams de répertoire sont désormais ouverts relativement au descripteur ancré au lieu
de partager un offset avec dup. Le test couvre ajout d’un fichier et réénumération du niveau.

Quatre parcours UI réussis (résultat XCTest 2026.11.06_22-09-48-+0100) : accueil/annulation,
ouverture/lecture/fermeture d’un fichier temporaire, annulation du choix de dossier, puis dossier
avec deux Guide.md homonymes, dépliage, lecture des deux contenus et fermeture revenant au premier.
Les octets sources sont comparés après consultation.

Le modèle de session garantit un actif, ordre stable et déduplication. Le registre garde une
WKWebView par document ; le test d’intégration vérifie son identité après bascule et sa suppression
à la fermeture. Les liens locaux sont résolus uniquement parmi les grants existants.
Les tests de navigation n’ont pas besoin des fonctions de recherche ni de préférences.

Les mesures de bascule/dossier restent dans T077–T078 ; les contrôles réseau déconnecté
transversaux et macOS 14 sont conservés avant livraison.
