# Contrats internes des composants

Ces contrats décrivent les opérations et garanties ; ils ne sont pas du code à copier.
Les interfaces nécessaires sont petites, internes à l’app, injectables dans les tests.

| Composant | Entrées → sorties | Erreurs et garanties |
|-----------|-------------------|----------------------|
| AccessBroker | résultat du panneau → AccessGrant ; libération d’un usage | Annulation sans effet ; équilibre des accès ; jamais de grant implicite au parent |
| DirectoryNavigator | grant dossier + chemin relatif → entrées d’un niveau | Tri par nom, filtrage Markdown, pas de parcours récursif initial ni symlinks |
| LocalDocumentReader | handle + génération → DocumentSnapshot | Lecture coordonnée seule, bornée, UTF-8 strict ; refus hors périmètre et fichiers spéciaux |
| DocumentMonitor | handle → événements modifié/indisponible/revérifier | Événements non considérés comme une preuve de contenu ; arrêt à la fermeture |
| ReadingCoordinator | commandes et événements → état de session | Autorité sur générations, actif, annulation et aperçu obsolète ; aucune écriture |
| MarkdownParser | snapshot → ParsedDocument | CommonMark + tableaux simples ; type du moteur non exposé ; HTML brut inerte |
| SearchIndexer | projection + requête + générations → occurrences | Texte littéral, sans casse, accents distincts ; compte cohérent et Unicode valide |
| ThemeResolver | préférences + apparence système → thème résolu | Valeurs contrôlées et contraste, pas de ressource distante ni CSS libre |
| SafeHTMLRenderer | document analysé + thème + recherche → PreviewSnapshot | Échappement contextuel ; liste fermée ; repères posés via plages de nœuds, jamais remplacement HTML |
| PreviewResourceStore | jeton + resourceID → octets/MIME connus | Pas d’URL disque arbitraire ; isolation des versions ; refus jeton expiré |
| PreviewWebView | preview + commande de fragment → événements de lecture | MainActor, JS désactivé, aucun téléchargement ; erreurs et crash du processus récupérables |
| NavigationPolicy | URL + type d’action + contexte → autoriser/rerouter/refuser | HTTP(S) seulement si clic explicite ; schéma interne contrôlé ; refus des popups et téléchargements |
| PreferencesStore | charger/sauver/réinitialiser → valeurs validées ou erreur | JSON atomique dans conteneur, erreurs visibles, session utilisable en cas d’échec |

## Concurrence et annulation

Les vues et la session observable sont sur MainActor. Lectures, analyse, génération HTML,
recherche, décodage d’images et accès aux préférences utilisent des tâches/services isolés hors
MainActor. La sérialisation d’un acteur ne suffit pas à garantir le bon ordre après un await :
toute publication revalide documentID, génération source et génération de présentation attendues.
Le parseur et ses nœuds restent confinés à leur tâche ; seules les valeurs internes immuables
franchissent les frontières. Annuler un travail ne vaut pas preuve qu’il n’achèvera jamais.

Les tâches WKURLSchemeHandler start/stop sont sérialisées. Après stop, aucune réponse, donnée ou
fin de tâche ne peut être envoyée. Une révocation de jeton invalide les futures lectures et n’expose
jamais les ressources d’un autre document. La suppression des vues ferme aussi leurs tâches.

## Erreurs communes

Catégories : accès refusé/révoqué, absent, type/encodage non pris en charge, taille dépassée,
lecture instable, ressource indisponible, rendu échoué, préférences non conservées. Chaque erreur
fournit un message français et une action appropriée : sélectionner, réessayer, réinitialiser ou
fermer. Un ancien aperçu conservé porte toujours l’avertissement d’obsolescence.

## Extension future à l’édition

Le moteur accepte un instantané de texte et non un service de fichiers. Un futur éditeur pourra
créer un instantané mémoire distinct du snapshot disque. Les écritures explicites, conflits,
annulation d’édition et droits supplémentaires feront l’objet d’un autre contrat. Le lecteur du
MVP ne possède aucune opération d’écriture latente ni bascule cachée vers read-write.
