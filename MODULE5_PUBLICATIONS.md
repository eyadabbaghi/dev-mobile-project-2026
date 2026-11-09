# Module 5 — Publications & Commentaires

Espace communautaire de **FitTrack AI**, isolé dans `lib/community/` et branché
comme onglet **Publications** de la barre de navigation principale.
Le module possède sa propre base SQLite (`fittrack_community.db`) et ne modifie
ni les bases ni le code des autres modules.

## Périmètre

- Aucun rôle, admin ou modérateur : uniquement l'utilisateur authentifié et la
  propriété des contenus (`user_id`).
- Design existant conservé (`FitTheme.dark`, cartes arrondies, accent lime).
- Les actions de modération sont limitées au **propriétaire** du contenu.

## Couverture fonctionnelle

| Domaine | Fonctionnalité |
|---------|----------------|
| Publications | Création, lecture, modification, suppression, brouillons, épinglage, partage, thèmes Repas / Nutrition / Sport / Progrès |
| Médias | Photo et vidéo facultatives (lecture mobile et Web, repli propre si non supporté) |
| Fil | Tri (récent, ancien, plus aimé, plus commenté, tendances), recherche, filtres thématiques, compteur d'interactions |
| Hashtags & mentions | Extraction automatique des `#hashtags`, saisie assistée des `@mentions`, notifications des membres mentionnés |
| Réactions | 6 réactions (J'aime, J'adore, Haha, Wow, Triste, En colère), compteurs par réaction, liste des réacteurs, changement/retrait |
| Sondages | Question + options, vote unique par membre, pourcentages, clôture par date, notification de clôture |
| Commentaires | Fil de discussion imbriqué, réponses, modification/suppression de ses commentaires, réactions de commentaire |
| Mise en avant | Épinglage de commentaire et choix d'une meilleure réponse par le propriétaire de la publication |
| Anonymat | Commentaires anonymes autorisés publication par publication, identité masquée mais auteur conservé en base |
| Enregistrements | Favoris et collections personnelles, filtre par collection |
| Signalements | Motifs, note, suivi de « mes signalements », réception sur « mon contenu », résolution et historique |
| Modération IA | Alertes sauvegardées pour le propriétaire, consultation et rejet, sans rôle de modérateur |
| Notifications | Notifications internes au module : réactions, commentaires, réponses, mentions, votes et clôtures de sondage ; lecture ciblée et « tout lire » |
| IA | Génération, amélioration, correction, hashtags, suggestions de réponses, traduction, résumé de discussion, analyse de sentiment, modération et détection de spam |

## IA — configuration et garanties

- Clé lue depuis `GEMINI_API_KEY` via `--dart-define-from-file=env.json` ou
  `--dart-define=GEMINI_API_KEY=...`. `env.json` est ignoré par Git.
- Aucune clé n'est affichée dans l'interface ni journalisée.
- Sans clé (ou en cas d'erreur réseau), le module bascule sur une **IA locale**
  déterministe : toutes les fonctions restent utilisables et testables.
- L'IA ne publie et ne supprime **jamais** automatiquement : l'utilisateur doit
  explicitement choisir « Utiliser », envoyer ou confirmer.
- Les alertes IA sont enregistrées séparément du contenu ; un commentaire peut
  être publié après confirmation, la moderation restant visible pour le
  propriétaire.

## Architecture

```
lib/community/
├── data/
│   ├── community_database.dart    # SQLite dédiée, schéma v2 + migration additive
│   ├── community_repository.dart  # CRUD, droits propriétaire, agrégats
│   └── community_ai_service.dart  # Gemini + repli local
├── models/
│   ├── post.dart
│   ├── post_comment.dart
│   ├── poll.dart
│   ├── community_reaction.dart
│   ├── community_notification.dart
│   ├── community_report.dart
│   ├── community_profile.dart
│   └── comment_insights.dart
├── screens/
│   ├── community_feed_screen.dart
│   ├── community_bookmarks_screen.dart
│   ├── community_drafts_screen.dart
│   └── community_moderation_screen.dart
├── utils/
│   └── community_formatters.dart
├── widgets/
│   ├── post_card.dart
│   ├── post_composer_sheet.dart
│   ├── comments_sheet.dart
│   ├── community_dialogs.dart
│   ├── community_notifications_sheet.dart
│   ├── reaction_picker.dart
│   ├── report_sheet.dart
│   └── video_attachment.dart (+ video_source_io/web/stub)
└── demo/
    └── main.dart                  # démo isolée du module
```

## Base de données (v2)

Tables créées/migrées de façon additive, sans perte des données v1 :

`posts`, `comments`, `post_likes` (compatibilité), `post_reactions`,
`comment_reactions`, `bookmark_collections`, `bookmarks`, `polls`,
`poll_options`, `poll_votes`, `post_shares`, `reports`, `content_flags`,
`moderation_actions`, `community_notifications`, `community_profiles`,
`community_settings`.

## Vérifications

```powershell
flutter analyze lib/community test/community_repository_test.dart test/community_feed_screen_test.dart
flutter test test/community_repository_test.dart test/community_feed_screen_test.dart
flutter test
```

Résultats :

- `flutter analyze` du module : **aucun problème**.
- Tests du module : **31/31** (26 tests dépôt + 5 tests widget).
- Suite complète du projet : **42/42**.
- Le reste de `flutter analyze` ne remonte que des avertissements préexistants
  hors module (`auth`, `dashboard`, `journal`, `profile`, widgets partagés).

## Lancer l'application

Prérequis : Flutter stable, puis :

```powershell
cd C:\Users\Afnen\Desktop\dev-mobile-project-2026
flutter pub get
Copy-Item env.example.json env.json   # si absent, renseigner GEMINI_API_KEY
flutter run -d chrome --dart-define-from-file=env.json
```

Application complète : créer un compte, terminer l'onboarding, puis ouvrir
l'onglet **Publications**.

Démo du module seul, avec données de démonstration (aucune inscription) :

```powershell
flutter run -t lib/community/demo/main.dart -d chrome --dart-define-from-file=env.json
```

## Scénario de démonstration

1. Créer un compte et terminer l'onboarding (3 étapes).
2. Onglet **Publications** : publier un texte, ajouter un thème, une photo ou
   une vidéo, éventuellement un sondage.
3. Ouvrir **Assistant IA** : Générer / Améliorer / Corriger / Hashtags, puis
   « Utiliser » pour insérer la proposition (jamais de publication automatique).
4. Réagir avec l'une des 6 réactions, ouvrir le compteur pour voir les réacteurs.
5. Commenter, répondre, réagir à un commentaire, trier les commentaires.
6. Tester les outils IA des commentaires : résumé, sentiments, traduction,
   suggestions de réponses.
7. Enregistrer une publication dans une collection, la partager.
8. Signaler un contenu, consulter **Modération de mon contenu**.
9. Publier un brouillon depuis **Brouillons**.
10. Vérifier les notifications du module et « Tout lire ».

## Notes

- Sur le Web sans permission presse-papiers, le partage enregistre quand même
  le compteur et affiche le lien interne en repli.
- Sans clé Gemini, l'interface indique « IA locale » ; c'est le mode utilisé
  par la démo fournie.
- La branche de livraison est `feature/community-publications-ai`.
