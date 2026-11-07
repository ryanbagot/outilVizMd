# Contrat — lancement et identité visuelle

## Accès utilisateur

| Accès | Cible et résultat attendus |
|---|---|
| Finder → Applications → outilVizMd | `/Applications/outilVizMd.app`, fenêtre de lecture utilisable. |
| Bureau → outilVizMd – ouvrir | Véritable alias vers la même app, même version et identité de bundle. |
| Nouveau double-clic quand l’app tourne | Même processus pour cette installation ; lecteur présenté, sans nouveau modèle de lecture. |
| Lecteur fermé ou réduit, aide/préférences seule visible | Réouvrir/restaurer et présenter la scène `reader`, préserver la session encore en mémoire. |
| Raccourci supprimé | App et documents préservés ; commande alias disponible pour recréer l’accès. |

Le lancement quotidien ne demande ni Terminal, Xcode, recompilation, compte ou réseau. L’app et son icône ne lisent pas le projet, le manifeste de préparation ou les temporaires. Un redémarrage ne nécessite pas de réinstallation. Conserver nom outilVizMd et identifiant `com.outilvizmd.outilVizMd` ; ne pas effacer préférences ou autorisations persistantes.

L’existence de copies de développement ne change pas la cible publiée. Ne pas lancer volontairement par identifiant seul ; le harnais contrôle URL du processus et version. Vérifier aussi le vrai double-clic Finder avec une copie de développement présente. Si une autre copie active perturbe le test, l’identifier et la quitter normalement avant de recommencer ; ne pas masquer ce résultat par un lancement forcé.

## Bundle et icône

- `CFBundleIconFile=AppIcon.icns` dans le plist construit, ressource dans `Contents/Resources`, intégrée avant signature.
- Illustration originale identifiée dans le [modèle](../data-model.md), proportions/composition/couleurs préservées. Le fond opaque fait partie de l’image.
- Identité reconnaissable dans Finder, sur l’alias Bureau, dans Dock et Cmd-Tab, aux tailles disponibles et en clair/sombre. Flèche d’alias standard acceptée.
- Original byte-identique après préparation et installation. Aucun remplacement manuel d’icône dans Finder.
- Ancienne icône en cache : quitter/relancer l’app puis fermer/rouvrir la fenêtre Finder ; vérifier cible, version, plist et ressource. Ne pas purger globalement les caches ou désactiver une protection pour annoncer une réussite.

## Protections et limites

Application macOS 14+, universelle ; mêmes droits sandbox/lecture sélectionnée/client réseau WebKit, même filtrage Markdown et navigation que 001. L’outil d’installation n’est pas inclus au runtime. Signature locale ad hoc : usage local, sans promesse de distribution publique acceptée sur d’autres Macs.

La recette comprend les commandes clavier existantes, consultation hors ligne et conservation des octets des documents. L’exécution sur une architecture/OS non testé reste une limite documentée. Les cinq critères SC et les erreurs du [contrat CLI](deployment-cli.md) conditionnent la livraison.
