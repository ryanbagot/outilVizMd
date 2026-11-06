# US5 — suivi externe vérifié

Suite complète du 2026-11-06 : 55 réussites, zéro échec (rapport `Test-outilVizMd-2026.11.06_22-32-44-+0100.xcresult`).

Le support externe des tests produit les écritures attendues : directe, remplacement atomique, dix sauvegardes, suppression/recréation et modification d’un document inactif. Le lecteur reflète la dernière version stable ; la recherche existante est recalculée. Le parcours UI observe réellement les nouveaux titres WebKit, le message « Aperçu non à jour » après suppression, l’ancien aperçu conservé et le contenu recréé. Le lecteur ne recrée pas le fichier supprimé.

DispatchSource observe le fichier et seulement un parent déjà autorisé par un grant dossier. Un fichier choisi seul n’autorise aucune surveillance du parent. Contrôle actif toutes les 500 ms et à l’activation, débattement monotone 150 ms, revalidation via descripteurs, réarmement après remplacement et arrêt à la fermeture. Les lectures instables ont trois reprises bornées. Les versions et générations empêchent les publications inversées. Une ancre sémantique connue est réutilisée, la recherche explicite prime ; aucun état opaque n’est restauré après changement du contenu.

Les délais SC-004 restent à mesurer dans T077–T078. La révocation est couverte au niveau de l’accès ; une révocation réelle de powerbox sur différentes versions de macOS reste un contrôle de plateforme.

Le benchmark a révélé une notification tardive pouvant marquer obsolète une version déjà actuelle après bascule. La correction revalide les métadonnées avant la transition et rejette les inspections achevées hors ordre. Le test de régression sur dix cycles de rafales/bascules et la série de vingt mesures passent (rapport 22-52-54).
