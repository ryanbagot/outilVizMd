# Recherche — installation locale et icône

Date : 2026-11-07. Périmètre : [spécification 003](spec.md), indépendant de 002.

## Icône embarquée

**Décision.** Générer `outilVizMd/Resources/AppIcon.icns` avec `sips` et `iconutil`, puis déclarer `CFBundleIconFile=AppIcon.icns`. Versionner le dérivé pour les builds ordinaires ; la préparation locale le régénère depuis l’original avant construction et signature.

**Motivation.** Le générateur `scripts/update-xcode-project.py` traite les ressources à plat : ajouter le type `image.icns` et le réglage Info.plist en Debug et Release suffit. Apple documente le repli sur cette clé en l’absence de `CFBundleIconName` dans sa [référence des clés](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CoreFoundationKeys.html).

Constats locaux : PNG RGB sans alpha, 1 254 × 1 254 pixels ; SHA-256 `2f568a19b834a308bce6c9ec56194f6c1e4090a69e5d6381ac3a6c350ce05be7`. Résoudre « Icône Markdown personnalisable en couches.png » par normalisation Unicode NFC, sans renommer le fichier dont le nom réel est décomposé ; exiger une seule correspondance. Conserver fond, proportions, couleurs et composition, sans recadrage ou détourage.

Produire directement depuis la source les dix représentations : 16, 32, 128, 256 et 512 points, chacune en 1× et 2×, conformément au [guide Apple haute résolution](https://developer.apple.com/library/archive/documentation/GraphicsAnimation/Conceptual/HighResolutionOSX/Optimizing/Optimizing.html). Contrôler l’empreinte de l’original avant/après et les représentations ; ne pas exiger une égalité binaire entre ICNS issus de versions différentes des outils Apple.

**Alternatives.** Un catalogue Assets.xcassets imposerait de modifier le parcours du générateur pour traiter le conteneur et exclure ses descendants. Icon Composer ou une personnalisation Finder manuelle n’apportent rien à ce besoin d’image conservée et embarquée.

## Release autonome

**Décision.** Ajouter `scripts/prepare-local-app.py`, Python standard, pour vérifier l’image, préparer l’ICNS, régénérer le projet et construire une Release universelle dans un DerivedData distinct des tests. Produire sous `build/local/` l’app, un manifeste de contrôle et l’outil d’installation compilé pour l’hôte. Ignorer ces sorties de construction.

**Motivation.** Conserver `com.outilvizmd.outilVizMd`, macOS 14 minimum, arm64 et x86_64 pour l’app, signature locale ad hoc et Hardened Runtime. Conserver exactement les trois entitlements actuels : sandbox, fichiers sélectionnés en lecture seule, client réseau nécessaire au démarrage WebKit. Le filtrage des ressources distantes reste inchangé. Contrôler les droits effectifs, pas seulement le fichier source.

Valider Info.plist, exécutable, architectures, minimum système, ressources embarquées, icône et signature ; exclure bundles de tests et dépendances dynamiques vers le projet ou un dossier temporaire. Le manifeste adjacent permet validation et idempotence ; le lecteur installé n’en dépend pas.

Xcode présent : 27.2 (27B52), Swift 6.4.2 ; le sélecteur global pointe vers les Command Line Tools. Utiliser explicitement `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. Conserver mode Swift 5, concurrence stricte et versions de paquets verrouillées. `--offline` impose un cache complet et interdit téléchargement/résolution automatique ; sinon échec explicite.

**Alternatives.** Une app Debug issue des tests risque d’embarquer des artefacts de développement. Une compilation quotidienne contredit le besoin. Distribution publique, notarisation, compte Apple et mise à jour automatique sont hors périmètre. Ne jamais contourner un refus du système par désactivation de ses protections.

## Outil de déploiement

**Décision.** Petit paquet Swift local `tools/LocalDeployment` : une cible exécutable `install-local-app` et ses tests, sans dépendance tierce. Foundation, AppKit et Darwin uniquement ; aucune dépendance ajoutée à l’app et aucune quatrième cible Xcode.

**Motivation.** Les véritables alias, l’identification des apps actives et les opérations de remplacement nécessitent les API macOS. Ce paquet répond au besoin concret de tester ces écritures dans des dossiers isolés hors de la sandbox du lecteur. Il ne constitue pas un framework général.

Destination fixe `/Applications/outilVizMd.app`, Bureau trouvé par `FileManager` et `.desktopDirectory`. Destinations injectables réservées aux tests. Aucun privilège élevé automatique, `sudo`, agent persistant ou modification de quarantaine.

**Alternatives.** Shell seul : validation d’alias insuffisante. Python avec pont Swift : deux langages pour une même transaction. Installation depuis le lecteur : extension inutile de ses droits.

## Remplacement et récupération

**Décision.** Sérialiser les opérations, copier et valider le bundle dans un dossier privé UUID sous Applications. Utiliser `renameatx_np` avec `RENAME_EXCL` pour créer et `RENAME_SWAP` pour mettre à jour avec `--replace`. Garder l’ancienne app dans le staging jusqu’aux contrôles finaux ; aucun fallback par suppression préalable.

**Motivation.** Le manuel Apple local `man 2 renameatx_np` décrit l’échange atomique sur le même volume et l’échec sans modification des arguments. API disponible depuis macOS 10.12 selon le SDK. Recontrôler identité et processus avant commit ; traiter les erreurs effectives même après précontrôle satisfaisant de place/permissions. Le verrou coordonne cet outil, pas les modifications externes. Applications et Bureau ne forment pas une transaction atomique commune.

Détecter les processus par identifiant puis comparer leur URL canonique. Refuser la mise à jour d’une installation active ou d’identité ambiguë ; indiquer comment quitter normalement. Ne pas fermer les copies de développement. Références : [applications actives](https://developer.apple.com/documentation/appkit/nsrunningapplication/runningapplications(withbundleidentifier:)), [URL du bundle](https://developer.apple.com/documentation/appkit/nsrunningapplication/bundleurl).

Validation post-commit échouée : échange inverse et restauration de l’ancien alias. Retour arrière échoué : objets conservés, chemins exacts et résultat d’échec. Un reçu privé décrit transaction, objets et dernière étape confirmée ; `status` signale une interruption sans rejeu ni suppression automatique d’un état ambigu. Nettoyer seulement les objets créés et identifiés par l’outil ; un nettoyage échoué est signalé.

**Alternatives.** [FileManager.replaceItemAt](https://developer.apple.com/documentation/foundation/filemanager/replaceitemat(_:withitemat:backupitemname:options:)) préserve les données mais nécessite aussi une sauvegarde unique et la gestion de son emplacement après erreur. Déplacer d’abord l’ancienne app laisse un intervalle sans installation canonique. Si le système de fichiers refuse l’échange, échouer proprement.

## Alias Finder

**Décision.** Bookmark `.suitableForBookmarkFile`, écriture temporaire avec extension `.alias`, puis renommage sans écrasement en `outilVizMd – ouvrir` au Bureau. Résolution sans interface ni montage ; comparer chemin canonique et identité de fichier à l’app actuelle. Exclure les symlinks par `lstat`.

**Motivation.** Apple documente la [création de fichiers bookmark](https://developer.apple.com/documentation/foundation/nsurl/writebookmarkdata(_:to:options:)) et la [résolution d’alias](https://developer.apple.com/documentation/foundation/url/init(resolvingaliasfileat:options:)). Aucun bookmark à portée de sécurité : ce raccourci n’accorde pas de droit sur les documents. Un bookmark peut retrouver un objet déplacé ; nous en déduisons le risque de suivre l’ancien bundle en sauvegarde. Tester avec cette sauvegarde encore présente.

Avant mise à jour, mettre à l’abri l’alias reconnu ; après commit, recréer depuis l’URL canonique et vérifier. Ne jamais remplacer un élément étranger. Si l’alias connu ne peut pas être sécurisé, ou si le Bureau est invérifiable avant mise à jour, refuser avant commit. Une première installation peut réussir avec Bureau inaccessible : résultat partiel et commande `alias` pour réparer. Après commit, l’échec du seul alias laisse l’app utilisable et un diagnostic exact.

**Alternatives.** Copie au Bureau : divergence. Symlink : pas un alias Finder. Ancien alias conservé sans vérification : mauvaise version possible. `--replace` n’autorise pas un conflit étranger.

## Réouverture

**Décision.** Conserver `Window("outilVizMd", id: "reader")`. Vérifier fenêtre fermée, réduite et seule aide/préférences visible. La réouverture présente `reader` par `openWindow(id:)` sans nouveau modèle de lecture ; ajouter le pont AppKit minimal seulement si SwiftUI ne satisfait pas déjà ces cas.

**Motivation.** [SwiftUI décrit les fenêtres](https://developer.apple.com/documentation/SwiftUI/bringing-multiple-windows-to-your-swiftui-app) ; AppKit expose [applicationShouldHandleReopen](https://developer.apple.com/documentation/appkit/nsapplicationdelegate/applicationshouldhandlereopen(_:hasvisiblewindows:)). La visibilité globale ne suffit pas à identifier la fenêtre de lecture.

Le harnais lance une URL explicite avec `createsNewApplicationInstance=false` et `allowsRunningApplicationSubstitution=false`, puis contrôle l’URL du processus (API dans NSWorkspace.h du SDK). Ces options ne configurent pas Finder : une recette Finder réelle est obligatoire, avec une copie de développement présente. Ni lancement par identifiant seul, ni `open -n`.

**Alternatives.** Aucun système multi-fenêtres, singleton interprocessus, API privée ou changement général de restauration.

## État de la recherche

Tous les choix du plan sont résolus. Recherche documentaire en lecture seule : aucune conversion, compilation ou installation de cette fonctionnalité effectuée. Les essais restent des critères de livraison. Une construction universelle ne prouve pas une exécution Intel ou macOS 14 ; consigner les plateformes réellement exécutées.

## Ajustements constatés pendant l’implémentation

Le dossier du projet `~/Desktop/outilVizMd` occupe déjà le nom initialement prévu pour l’alias. Le raccourci fixe s’appelle donc **outilVizMd – ouvrir** ; le dossier reste intact. Aucun suffixe automatique variable ni destination arbitraire n’est ajouté à la CLI.

Xcode ignore ici `INFOPLIST_KEY_CFBundleIconFile` dans le plist généré : un `outilVizMd/Info.plist` minimal est fusionné à la génération. Le générateur exclut ce fichier des ressources copiées.

Le File Provider du Bureau synchronisé ajoute `com.apple.FinderInfo` aux bundles sous le dépôt, ce qui invalide leur signature stricte. La préparation copie le produit dans un dossier temporaire privé hors synchronisation, retire seulement FinderInfo/ResourceFork du produit puis le signe et le valide. `build/local` est un lien d’accès publié atomiquement vers ce lot (app réelle, manifeste, outil). Les préparations précédentes restent dans leurs dossiers temporaires ; elles peuvent être supprimées après inspection et installation. L’app canonique ne dépend pas de ces dossiers. Aucune quarantaine n’est supprimée.

Le digest utilise des chemins relatifs et cibles de symlink normalisés NFC, triés par octets UTF-8 ; chaque ligne contient chemin UTF-8 en base64, type D/F/L, bits exécutables décimaux (fichier seulement), SHA-256 des octets pour F ou cible UTF-8 en base64 pour L, séparés par tabulations et terminés par LF. Le SHA-256 de ces lignes est le digest. Le vecteur partagé couvre noms accentués, lien et exécution.
