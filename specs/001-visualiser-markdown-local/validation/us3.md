# US3 — recherche vérifiée

Suite complète du 2026-11-06 : 55 tests réussis, zéro échec (rapport `Test-outilVizMd-2026.11.06_22-32-44-+0100.xcresult`). Le parcours UI vérifie Cmd+F, deux occurrences dont une traverse une emphase, compteur 1/2 puis 2/2, boucle, Échap et octets inchangés.

Les contrats vérifient Unicode composé/décomposé, limites des graphèmes, accents distincts, casse ignorée, caractères spéciaux littéraux, occurrences non chevauchantes, alternatives effectivement affichées et requête absente. Les marques proviennent de plages par nœud, jamais d’un remplacement dans le HTML. Les résultats sont versionnés et les générations sont revalidées après chaque await ; saisies rapides et fermeture ne republient pas un ancien résultat. Recherche, thème et changements externes sont aussi exercés ensemble.

Les images déjà décodées sont réutilisées pour les changements de présentation. Aucun JavaScript n’est appelé. Les seuils temporels et requêtes denses restent dans T077–T078.
