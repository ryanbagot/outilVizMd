# Recherche technique — outilVizMd

Date : 2026-11-06. Sources primaires consultées pendant la phase 0 ; aucun paquet installé.
Les décisions ci-dessous sont des choix de conception, sans mesure de performance à ce stade.

## 1. Moteur Markdown

**Décision** : `swiftlang/swift-markdown`, produit `Markdown`, version exacte 0.9.0 via Swift
Package Manager. Conserver le graphe résolu dans `Package.resolved`. Isoler la bibliothèque derrière
`MarkdownParser` ; n’exposer aucun type de la dépendance dans la présentation.

**Justification** : AST Swift, CommonMark et tableaux via cmark-gfm ; parcours typé pour générer
le HTML sûr et le texte recherchable. Le manifeste du tag demande Swift tools 6.2, utilise le mode
Swift 5 et référence swift-cmark et le plugin de documentation swift-docc-plugin. Le plugin n’est
pas une dépendance de service à l’exécution. Ni le poids final ni les performances ne sont établis.
Choisir une distribution Xcode fournissant Swift 6.2 ou ultérieur. Ne pas déduire du manifeste
alternatif Swift 5.7 une compatibilité garantie avec un ancien Xcode. macOS 14 reste la cible du
produit, à confirmer par compilation et exécution sur ce système.

**Alternatives** : cmark-gfm direct implique la gestion des pointeurs C et de leur durée de vie ;
Down n’apporte pas de preuve de prise en charge des tableaux requis dans les sources consultées
et ajoute des commodités de rendu inutiles ici. Aucun autre paquet applicatif n’est prévu.

Sources : [projet](https://github.com/swiftlang/swift-markdown),
[release](https://github.com/swiftlang/swift-markdown/releases/tag/0.9.0),
[manifeste](https://raw.githubusercontent.com/swiftlang/swift-markdown/0.9.0/Package.swift),
[convertisseur](https://raw.githubusercontent.com/swiftlang/swift-markdown/0.9.0/Sources/Markdown/Parser/CommonMarkConverter.swift),
[Down](https://github.com/johnxnguyen/Down), [cmark-gfm](https://github.com/github/cmark-gfm).

## 2. HTML et ressources non fiables

**Décision** : produire soi-même le HTML depuis l’AST avec une liste fermée de balises et
attributs, textes et attributs échappés. Le HTML brut est affiché comme texte échappé ; aucune
sanitisation par expressions régulières. Ne pas activer les directives DocC ni les extensions
étrangères au périmètre. Les options du parseur n’ajoutent pas de substitutions typographiques.

WKWebView est encapsulée dans NSViewRepresentable. Utiliser `allowsContentJavaScript = false`,
un magasin de données non persistant, aucun script utilisateur ni pont de messages. Le rendu
reçoit une CSP restrictive : défaut, scripts, connexions, cadres, objets et formulaires interdits ;
images limitées au schéma interne et styles limités au style généré par l’app avec nonce.
Le nonce est renouvelé pour chaque rendu et n’est jamais dérivé du document. Ne jamais utiliser
`loadFileURL` en donnant accès à un dossier utilisateur. Ne pas exposer les chemins du disque.

Les ressources utilisent `outilvizmd://preview/<jeton>/…` via WKURLSchemeHandler : le jeton
référence un instantané en mémoire, jamais un chemin fourni par la requête. Le gestionnaire ne
sert que HTML, CSS contrôlé et images raster validées. Les URL externes du Markdown ne deviennent
jamais des sous-ressources. Une WKContentRuleList embarquée bloque aussi les requêtes http/https ;
son installation doit réussir avant le premier affichage, sinon le rendu échoue en mode fermé. Navigation et nouvelles fenêtres sont refusées par défaut ; un clic
utilisateur http/https est délégué au navigateur système, les autres destinations sont routées
par l’app. La CSP, l’émetteur et la politique de ressources se complètent ; le délégué de navigation
seul n’est pas une protection suffisante contre les téléchargements de sous-ressources.

**Alternatives** : HTML du moteur injecté directement, accès large à file://, rendu via CDN et
bibliothèque JavaScript écartés pour réduire les surfaces d’accès et respecter le hors ligne.

Sources : [préférences WebKit](https://developer.apple.com/documentation/webkit/wkwebpagepreferences),
[gestionnaire de schéma](https://developer.apple.com/documentation/webkit/wkurlschemehandler),
[magasin non persistant](https://developer.apple.com/documentation/webkit/wkwebsitedatastore/nonpersistent()),
[règles de contenu](https://developer.apple.com/documentation/webkit/wkcontentruleliststore).

## 3. Recherche et position sans JavaScript

**Décision** : construire une projection du texte visible pendant le parcours de l’AST, avec
correspondance entre plages de texte et nœuds HTML. Recherche littérale Unicode insensible à la
casse, sensible aux accents, occurrences non chevauchantes. Les espaces et séparations entre blocs
sont normalisés suivant une règle documentée et testée commune à l’index et au HTML généré.
Les attributs href, balises et contenus non affichés sont exclus. Produire les repères `mark`
et les ancres de résultats côté Swift ; suivant/précédent cible le fragment du résultat choisi.
Une occurrence traversant plusieurs nœuds conserve un seul identifiant logique et peut avoir
plusieurs segments surlignés. Échapper la requête comme du texte, jamais comme du code.

**Justification** : WKWebView.find peut rechercher et rejoindre un résultat, mais WKFindResult ne
fournit pas le total exigé. Aucun appel evaluateJavaScript ni API privée n’est admis. Compter dans
une représentation différente de celle affichée donnerait des résultats incohérents.

Conserver la WKWebView associée à chaque document ouvert pour préserver sa position lors d’un
simple changement de document ; libérer à la fermeture. Sauvegarder son interactionState avant
reconstruction et le restaurer lorsque l’URL et les versions du contenu, des ressources et du thème sont identiques. Un fragment
explicite de recherche prime sur cette restauration. En cas de changement externe, la conservation
est au mieux, avec repli à une position valide conformément à US5.3. Valider tôt les fragments du
schéma interne et l’interactionState sur macOS 14 : ce sont des points de validation d’implémentation,
pas des permissions pour activer JavaScript. Mesurer le coût d’un rendu riche en occurrences.

**Alternatives** : WKWebView.find seul insuffisant pour le compteur ; accès au DOM par JavaScript
contraire à la constitution ; parcours de sous-vues privées WebKit interdit.

Sources : [recherche WebKit](https://developer.apple.com/documentation/webkit/wkfindresult),
[état d’interaction](https://developer.apple.com/documentation/webkit/wkwebview/interactionstate).

## 4. Accès aux fichiers

**Décision actualisée après T014** : App Sandbox, droits `user-selected.read-only` sur les documents,
sans accès global aux dossiers usuels ni droit réseau serveur. Le droit réseau client est requis
par l’initialisation des services WebKit, même pour un schéma local. L’absence de connexions
automatiques demeure une obligation vérifiée via le rendu sûr, CSP, règles et politique native.
NSOpenPanel donne accès au fichier ou dossier choisi.
Conserver l’autorisation en session, libérer sa portée à la fin de son utilisation ; équilibrer
les acquisitions explicites sans doubler celles déjà obtenues par le panneau système.
Aucun bookmark persistant n’est nécessaire, la restauration des documents étant hors MVP.
Une autorisation système ne remplace jamais le périmètre plus strict de l’application.

L’essai comparatif T014 confirme : sans `com.apple.security.network.client`, WebKit termine
ses services avant lecture ; avec ce seul ajout, le même test passe. Le contrôle est visible
dans [XPCServiceInitializerDelegate::checkEntitlements](https://raw.githubusercontent.com/WebKit/WebKit/main/Source/WebKit/Shared/EntryPointUtilities/Cocoa/XPCService/XPCServiceEntryPoint.mm).
La sonde d’affichage passif relève zéro connexion vers le serveur local témoin. Un test
distinct forçant des navigations HTTP(S) avec délégué permissif obtient un refus de chargement
mais peut établir des connexions spéculatives : les règles seules ne suffisent pas comme preuve
d’absence de réseau. Voir `validation/webkit-feasibility.md` ; ne jamais transmettre ces URL
au chargement WebKit dans le produit et ne jamais les réinjecter comme ressources du Markdown.

L’adaptateur d’accès vérifie les composants du chemin puis lit via un descripteur en lecture seule.
Les descendants sont ouverts relativement au descripteur du dossier autorisé, composant par
composant, sans suivi de liens symboliques ; les liens symboliques rencontrés dans les descendants
sont refusés avec possibilité de choisir directement leur cible. Refuser chemins absolus non
autorisés, traversées hors racine, fichiers spéciaux et changement d’identité incohérent. Ne pas
se fier à un préfixe de chaîne ou à une unique canonicalisation suivie d’une ouverture par chemin,
qui laisserait une course entre contrôle et lecture. Pour un fichier autorisé seul, revalider
son identité et son autorisation après remplacement ; redemander l’accès si nécessaire.
Lecture bornée à 10 Mio + 1 octet, UTF-8 strict, contrôle avant/après lecture ; rejeter une lecture
instable et réessayer sans écriture. NSFileCoordinator coordonne uniquement des lectures hors du
fil principal ; il ne remplace pas les contrôles de périmètre.

**Alternatives** : autoriser automatiquement le parent d’un fichier ou demander accès disque complet
élargirait les droits sans action explicite ; exclu. Les écritures de l’app restent dans son conteneur.

Sources : [accès sandbox](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox),
[entitlements](https://developer.apple.com/documentation/security/app-sandbox).

## 5. Modifications externes

**Décision** : DispatchSource pour écriture, renommage, suppression et révocation du fichier.
Après remplacement, rouvrir sous les mêmes contrôles ; si le dossier parent a été autorisé,
le surveiller également. Ne jamais demander ce parent automatiquement pour un fichier seul.
Un contrôle de métadonnées toutes les 500 ms du document actif, et à l’activation d’un document
inactif, couvre les pertes d’événements ; aucune réindexation récursive. Débattement de 150 ms,
reprises bornées et génération monotone empêchant les résultats obsolètes. NSFileCoordinator
améliore la cohérence avec les éditeurs qui coopèrent ; les autres nécessitent aussi les contrôles
de stabilité. Conserver le dernier aperçu et signaler l’obsolescence en cas d’échec.

**Alternatives** : notification seule insuffisante après remplacement atomique ; surveillance de
toute l’arborescence excessive pour le MVP. La liste du dossier reste actualisée manuellement.

Source : [Dispatch Sources](https://developer.apple.com/library/archive/documentation/General/Conceptual/ConcurrencyProgrammingGuide/GCDWorkQueues/GCDWorkQueues.html).

## 6. Préférences, thèmes et évolution

**Décision** : préférences Codable versionnées dans un JSON du conteneur Application Support,
écriture atomique avec erreurs remontées. UserDefaults convient aux petits réglages mais ne fournit
pas le même contrat d’échec explicite ; ne pas multiplier les stockages. Préférences validées champ
par champ, couleurs sRGB, police locale par identifiant, repli sûr. ThemeResolver produit des valeurs
et CSS contrôlés, sans CSS libre ni URL injectée. Calcul du contraste et avertissement sous 4,5:1.

Le lecteur publie un DocumentSnapshot immuable ; aucun protocole d’écriture n’est créé. Un futur
éditeur pourra produire un instantané non sauvegardé puis utiliser le même moteur et aperçu. Ses
commandes de sauvegarde, son modèle de modifications et ses droits seront une spécification séparée.
Pas de système de plugins, de serveur ou de paquet interne supplémentaire dans le MVP.

## 7. Licences et environnement

Conserver les licences Apache 2.0 avec Runtime Library Exception de swift-markdown et les notices
BSD/MIT applicables à swift-cmark ; vérifier les textes du graphe réellement résolu avant distribution.
[Licence](https://raw.githubusercontent.com/swiftlang/swift-markdown/0.9.0/LICENSE.txt),
[notices transitives](https://raw.githubusercontent.com/swiftlang/swift-cmark/0.9.0/COPYING).

État constaté localement : `xcode-select -p` pointe vers `/Library/Developer/CommandLineTools`,
Swift 6.3.3 est disponible, mais `xcodebuild -version` échoue ; Xcode.app et Xcode-beta.app absents
aux emplacements standards. La conception est réalisable sans ces outils, mais compilation,
résolution SwiftPM par Xcode et tests de l’app restent à exécuter sur une installation Xcode complète.
Toutes les décisions de conception sont prises ; aucune clarification utilisateur ne reste ouverte.
