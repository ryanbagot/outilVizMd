# Modèle de données — installation locale

Ce modèle décrit des fichiers locaux et des états de procédure ; aucune base de données ni migration des préférences du lecteur. Référence : [plan](plan.md).

## ImageSource

| Champ | Règle |
|---|---|
| relativeName | `Icône Markdown personnalisable en couches.png`, comparaison NFC, correspondance unique. |
| format / width / height | PNG, 1254 × 1254, lisible. |
| sha256 | `2f568a19b834a308bce6c9ec56194f6c1e4090a69e5d6381ac3a6c350ce05be7`, avant et après préparation. |
| derivedResource | `AppIcon.icns`, dix représentations ; jamais réécrire l’original. |

Une ImageSource produit l’icône de plusieurs PreparedRelease. Source absente, ambiguë, modifiée ou invalide : préparation refusée, aucun nouveau produit annoncé conforme.

## PreparedRelease

| Champ | Règle |
|---|---|
| bundleURL | Bundle réel `.app`, non symlink à sa racine ; exécutable déclaré présent. |
| bundleIdentifier / packageType | `com.outilvizmd.outilVizMd` / `APPL`. |
| version / build | Valeurs Info.plist existantes conservées ; pas d’incrément automatique requis. |
| architectures / minimumOS | arm64 + x86_64 / macOS 14.0. |
| iconFile / iconSHA256 / sourceSHA256 | ICNS présent et lisible ; empreinte issue de la préparation validée. |
| bundleDigest | SHA-256 d’un inventaire trié des chemins relatifs, octets, cibles des symlinks et bits exécutables ; dates/inodes exclus. Les symlinks internes légitimes sont conservés et contrôlés. |
| signature / entitlements | Signature valide ad hoc avec runtime ; exactement les trois droits existants. Aucun get-task-allow, droit serveur ou bundle de tests. |
| resources / dependencies | Rendu, aide et licences embarqués ; aucun chemin dynamique vers le projet ou les temporaires. |

Chemins/cibles de liens normalisés NFC pour un inventaire identique entre Foundation et Python (sérialisation et vecteur dans `research.md`).

Manifeste adjacent `manifest.json`, version de schéma 1 : identité/version, architectures, minimumOS, sourceSHA256, iconSHA256 et bundleDigest. Vérifier les valeurs contre le bundle, sans faire confiance au manifeste seul. Bundle et manifeste sont publiés après validation complète ; un échec de préparation ne remplace pas une sortie précédente valide. La signature contrôle l’intégrité, pas une autorisation de distribution publique.

## InstalledApplication

`canonicalURL=/Applications/outilVizMd.app`, identité PreparedRelease, `fileResourceIdentifier`, état absent/valide/invalide/conflit, processus actifs associés. L’identifiant reste stable pour conserver les préférences. Une installation correspond à zéro ou un raccourci attendu ; aucun document n’en devient la propriété.

Une app différente ou un objet étranger à la destination est un conflit. Une version de même identifiant mais de digest différent demande `--replace`. Un digest identique ne remplace pas le bundle ; seule la vérification/réparation du raccourci est nécessaire. Les contrôles refusent aussi une identité de processus ambiguë avant remplacement.

## DesktopAlias

`desktopURL` fourni par le système ; nom disque final `outilVizMd – ouvrir` ; type véritable alias Finder, pas symlink. Champs : URL, cible résolue, identité de fichier cible, état absent/valide/ancien/conflit/inaccessible/nonVérifié. Résoudre sans UI ni montage.

Valide signifie chemin canonique ET identité de la version actuelle. Reconnu signifie alias résolu vers l’installation vérifiée avant remplacement, ou vers un ancien bundle identifié par un reçu de transaction valide. Un alias inconnu ou cassé sans preuve de propriété n’est jamais écrasé. Une suppression du seul raccourci ne touche pas l’app.

## DeploymentRequest et DeploymentResult

Request : opération install/alias/status, source éventuelle, remplacement explicite, simulation, format JSON. Destinations fixes en production ; injection interne pour tests seulement.

Result : `schemaVersion=1`, `operation`, `outcome`, `applicationState`, `aliasState`, `applicationPath`, `aliasPath` éventuellement nul, identité/version effective, `changed`, diagnostics français et chemins de récupération éventuels. Pas de contenu de documents ou de préférences. Simulation : état constaté plus actions prévues, aucun staging créé.

Outcomes : complete, partial, refused, failed, preview, status. Les états effectifs restent présents même en échec : ne pas présenter un rollback réussi comme une nouvelle installation réussie. Le contrat [CLI](contracts/deployment-cli.md) fixe les codes et sorties.

## Transaction et transitions

Transaction : UUID, identité des destinations précontrôlées, dossier privé de staging même volume, ancien bundle éventuel, alias sécurisé éventuel, reçu de dernière étape confirmée. Aucun contenu de document utilisateur. Verrou local pour sérialiser cet outil ; recontrôles des destinations avant commit et publication sans écrasement pour les nouvelles entrées.

```text
précontrôle → copie privée → validation → ancien alias sécurisé
    → commit bundle → validation canonique → nouvel alias vérifié → nettoyage
```

- Avant commit : l’ancienne app reste en place ; après échec, restaurer l’alias sécurisé et nettoyer seulement les objets propres.
- Première installation : création exclusive. Mise à jour : échange atomique ; l’ancien bundle reste dans le staging jusqu’aux contrôles.
- Nouveau bundle invalide après commit : échange inverse (ou retrait exclusif de la nouvelle installation créée par cette transaction), puis restauration de l’alias. Échec de retour : conserver les objets et indiquer une récupération nécessaire.
- Seul alias échoué après validation de l’app : partial, application utilisable, raccourci absent/conflit précisément indiqué ; réparation séparée.
- Bureau inaccessible : première installation autorisée avec résultat partiel ; mise à jour refusée avant commit si l’état d’un ancien alias ne peut être sécurisé.
- Nettoyage échoué : app/alias restent décrits selon leurs états réels, résultat partial et chemin conservé indiqué.
- Interruption : `status` signale reçu/objets résiduels. Pas de reprise ou suppression automatique d’état ambigu ; inspection et récupération guidées.

Ne jamais restaurer par écrasement si un élément concurrent inconnu a pris la place de l’alias. Conserver la sauvegarde et signaler le conflit. Les garanties couvrent les opérations contrôlées ; elles ne prétendent pas empêcher toute modification externe pendant la procédure.
