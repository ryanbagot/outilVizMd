# US4 — préférences vérifiées

Suite complète du 2026-11-06 : 55 réussites, zéro échec (rapport `Test-outilVizMd-2026.11.06_22-32-44-+0100.xcresult`).

Le test UI utilise un identifiant de stockage isolé, sélectionne Sombre et Aéré, effectue trois vraies terminaisons/relances, vérifie les valeurs, puis réinitialise et relance une quatrième fois. Aucun document n’est restauré. Les réglages personnels ne sont pas modifiés par ce test.

Les tests de stockage vérifient l’aller-retour des valeurs contrôlées, trois réouvertures, reset durable, JSON invalide, version inconnue, taille hors limites, police absente, repli indépendant et erreur d’écriture. Le store écrit seulement son JSON par remplacement atomique dans Application Support. Les révisions empêchent une sauvegarde ancienne d’écraser une récente. Aucun chemin de document ni grant n’est sérialisé.

La présentation teste police locale, taille, style, palette sombre et changements rapides de thème avec recherche. Une erreur de stockage est visible dans les réglages ; les valeurs restent en mémoire. Les calculs de contraste et palettes système/claire/sombre ont des contrats dédiés. Les octets sources restent inchangés. La vérification humaine de tous les contrôles et VoiceOver appartient à T082 ; les mesures appartiennent à T077–T078.
