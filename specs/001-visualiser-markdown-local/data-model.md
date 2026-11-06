# Modèle de données — outilVizMd

Modèle interne en mémoire, sauf les préférences. Les noms indiquent les responsabilités, sans
imposer l’implémentation des types. Aucun contenu utilisateur n’est conservé dans une base.

## Entités et relations

| Entité | Données essentielles | Relations et invariants |
|--------|----------------------|-------------------------|
| AccessGrant | identifiant, URL choisie, type fichier/dossier, racine résolue, état, compteur d’usages | Temporaire ; jamais plus large que le choix explicite ; libération équilibrée |
| DocumentHandle | identifiant de session, emplacement, identité disque, grantID, nom et chemin affiché | Un même fichier ouvert ne crée pas deux entrées ; chemin réévalué après remplacement |
| DocumentSnapshot | documentID, génération, octets UTF-8, texte décodé, empreinte, métadonnées avant/après | Immuable, lecture bornée ; aucune méthode de sauvegarde |
| ReadingSession | documentIDs ordonnés, activeDocumentID, état par document | Un actif au maximum, fermeture sans écriture ; pas de persistance |
| NavigationEntry | identité, nom, URL autorisée, type, enfants chargés ou non, erreur éventuelle | Fichiers Markdown filtrés, dossiers paresseux, pas de suivi des symlinks descendants |
| ParsedDocument | snapshotGeneration, arbre interne, titres et ancres, projection visible | Aucun HTML brut réinjecté ; types swift-markdown confinés à l’adaptateur |
| VisibleTextIndex | texte visible canonique, plages vers nœuds et offsets, frontières de blocs | Même contenu que le rendu ; plages sur frontières Unicode valides |
| SearchState | documentID, génération de contenu, queryGeneration, requête, plages, index courant | Temporaire ; total = nombre d’occurrences logiques non chevauchantes |
| PreviewSnapshot | documentID, sourceGeneration, presentationGeneration, HTML, jeton, resourceIDs | Source, recherche et thème versionnés ; seul le dernier résultat attendu peut être affiché |
| ResourceSnapshot | identifiant opaque, previewToken, octets validés, MIME, dimensions, texte alternatif | Pas de chemin reçu de WebKit ; ressources immuables et isolées entre aperçus |
| RenderPreferences | schemaVersion, thème, police, taille, style, palettes claire/sombre | Seule entité persistante ; écriture dans le conteneur de l’app |
| ReaderFailure | catégorie, message français, action possible, documentID éventuel | Aucun octet source dans les journaux ; ne change pas le document actif sans action |

Un AccessGrant peut autoriser plusieurs documents et ressources lorsqu’il représente un dossier.
Un DocumentHandle possède zéro ou un dernier instantané lisible et zéro ou un aperçu conservé.
La session retient une WKWebView par document ouvert ; l’état technique de cette vue n’appartient
pas au contenu métier et disparaît à la fermeture du document.

## Validations

- Taille maximale document : 10 × 1 024 × 1 024 octets ; ne jamais lire sans borne après un simple stat.
- Décodage UTF-8 strict, octets NUL refusés comme contenu non textuel ; BOM toléré pour le décodage, conservé dans les octets de référence.
  Aucune normalisation du fichier source. Les fins de ligne peuvent être normalisées en mémoire.
- Autorisation vérifiée pour chaque lecture, y compris ressources et réouverture après remplacement.
  Les chemins sont comparés par composants ; un préfixe textuel commun ne vaut pas appartenance.
- Les descendants comportant un lien symbolique sont refusés. Une cible choisie directement dans
  le panneau natif reçoit son propre périmètre. Refuser fichiers spéciaux et boucles.
- Images PNG/JPEG/GIF validées par signature et décodage ImageIO ; GIF rendu sur sa première image.
  Appliquer un budget de décodage et mémoire, arrêter proprement si dépassé ; ne pas servir un MIME
  fourni par le document. Le corpus de référence respecte le budget d’images défini dans spec.md.
- Police identifiée parmi les polices locales ; disparition → police de repli. Taille finie de
  12 à 32 points ; style parmi standard/compact/aéré ; couleurs sRGB finies dans 0…1.
- Préférences invalides : repli champ par champ. JSON absent → valeurs initiales ; version inconnue
  → valeurs sûres et avertissement. Aucune donnée invalide n’est interpolée dans le CSS.
- Les noms de polices sont échappés comme valeurs CSS ; les couleurs et nombres sont sérialisés
  par l’app. Aucun texte utilisateur libre n’est interprété comme CSS.

## Transitions du document

1. Choix annulé → aucun changement.
2. Autorisé → chargement(génération N) → prêt(snapshot N) ou erreur sans aperçu initial.
3. Prêt → modification détectée → rafraîchissement(N+1), ancien aperçu conservé.
4. Rafraîchissement réussi → prêt(N+1), index/recherche recalculés, avertissement retiré.
5. Rafraîchissement échoué → obsolète(dernier aperçu, erreur) ; réessai → rafraîchissement.
6. Inactif → activation : revalider les métadonnées avant de déclarer l’aperçu à jour.
7. Toute étape → fermeture : annulation, fin de surveillance, révocation des jetons, libération
   des usages d’autorisation ; les réponses tardives ne peuvent pas rétablir le document.

Ne pas suivre silencieusement un déplacement hors périmètre. L’utilisateur peut sélectionner le
nouvel emplacement. Les événements de remplacement au même chemin déclenchent une réévaluation.

## Recherche et présentation

- Requête modifiée → incrément queryGeneration → recherche hors MainActor → résultats admis
  uniquement si documentID, génération source et génération de requête correspondent encore.
- Recherche fermée ou document changé → requête et repères effacés ; les autres préférences restent.
- Modification de thème → nouvelle presentationGeneration, même DocumentSnapshot.
- Fragments de titre : identifiant stable généré par l’app, suffixe déterministe pour doublons.
  Fragments de recherche : identifiant logique par occurrence, segments éventuels par nœud.
- Simple changement de document → vue retenue inchangée. Reconstruction identique → interactionState
  admissible. Changement de contenu, de CSS ou de ressources → jamais restaurer l’ancien état opaque ;
  ancre sémantique connue au mieux, sinon début valide. Une recherche explicite prime sur le défilement.

## Persistance des préférences

Un fichier `preferences.json` version 1 dans Application Support du conteneur contient les valeurs
validées. Écriture via fichier temporaire puis remplacement atomique dans le même conteneur ;
l’échec est remonté tout en conservant les choix en mémoire. Aucun chemin de document ni grant n’y
est enregistré. Réinitialiser restaure et persiste les valeurs initiales. Tests avec store isolé et
pannes injectées ; aucune modification des préférences réelles par les tests unitaires.
