# Module 5 — Publications & Commentaires

Ce module ajoute un espace communautaire à FitTrack AI **sans modifier les bases de
données ni le code des autres modules**. Il est isolé dans `lib/community/` et
branché comme 5ᵉ onglet de la barre de navigation.

## Couverture fonctionnelle

| Réf.  | Fonctionnalité | Implémentation |
|-------|----------------|----------------|
| PUB01 | Création de publication (texte + photo facultative + thème Repas / Nutrition / Sport / Progrès) | `PostComposerSheet`, `CommunityRepository.createPost` |
| PUB02 | Fil d'actualité chronologique avec nombre d'interactions (j'aime + commentaires) | `CommunityFeedScreen`, `PostCard`, requête `getFeed` |
| PUB03 | Modification / suppression de ses propres publications | Menu « … » du `PostCard` → `updatePost` / `deletePost` |
| PUB04 | Ajout, lecture, modification et suppression de ses propres commentaires | `CommentsSheet` → `addComment`, `getComments`, `updateComment`, `deleteComment` |
| PUB05 | Filtrage thématique du fil | Chips de thème dans `CommunityFeedScreen` → `getFeed(theme:)` |
| RG08  | Paternité des contenus | Toutes les écritures SQL filtrent sur `user_id = ?` |

## Fichiers du module

```
lib/community/
├── data/
│   ├── community_database.dart    # SQLite dédiée : fittrack_community.db
│   └── community_repository.dart  # CRUD + RG08 + compteurs
├── models/
│   ├── post.dart                  # Post + PostTheme
│   └── post_comment.dart          # PostComment
├── screens/
│   └── community_feed_screen.dart # Fil + filtres + actions
├── utils/
│   └── community_formatters.dart  # Thèmes, dates, initiales
└── widgets/
    ├── post_card.dart             # Carte du fil
    ├── post_composer_sheet.dart   # Formulaire création / édition
    └── comments_sheet.dart        # Espace commentaires
```

Tests ajoutés :

- `test/community_repository_test.dart` — CRUD, compteurs, filtrage, RG08.
- `test/community_feed_screen_test.dart` — affichage du fil et filtrage par thème.

## Base de données

Base séparée `fittrack_community.db` (comme `fittrack_events.db`), schéma v1 :

- `posts(id, user_id, author_name, author_avatar_path, content, image BLOB, theme, created_at, updated_at)`
- `comments(id, post_id → posts ON DELETE CASCADE, user_id, author_name, author_avatar_path, content, created_at, updated_at)`
- `post_likes(post_id → posts ON DELETE CASCADE, user_id, created_at, PRIMARY KEY(post_id, user_id))`

La photo est stockée en `BLOB` (et non comme chemin de fichier) pour fonctionner
aussi bien sur mobile que sur le Web.

## Lancer l'application

Prérequis : Flutter stable (Dart ≥ 3.13.5).

```powershell
cd C:\Users\Afnen\Desktop\dev-mobile-project-2026
flutter pub get

# Une seule fois : ajoute les assets SQLite nécessaires au Web
dart run sqflite_common_ffi_web:setup

# Copier la configuration locale (si absente)
Copy-Item env.example.json env.json

flutter run -d chrome --dart-define-from-file=env.json
```

Sur émulateur / téléphone Android :

```powershell
flutter run -d Nexus_5 --dart-define-from-file=env.json
```

### Démo du module seul (sans inscription)

Pour voir directement le fil communautaire (données de démonstration) :

```powershell
flutter run -t lib/community/demo/main.dart -d chrome
```

## Vérifications

```powershell
flutter analyze
flutter test test/community_repository_test.dart test/community_feed_screen_test.dart
```

## Utilisation

1. Se connecter / créer un compte.
2. Onglet **Publications** dans la barre du bas.
3. **Publier** : texte + thème + photo facultative.
4. Filtrer avec les chips `Tout / Repas / Nutrition / Sport / Progrès`.
5. J'aime / commenter une publication.
6. Menu « … » : modifier ou supprimer **ses** publications ; dans les
   commentaires, même menu pour **ses** commentaires (RG08).
