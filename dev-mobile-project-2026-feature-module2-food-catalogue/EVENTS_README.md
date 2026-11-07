# Module Événements

Ce document décrit le fonctionnement du module Events intégré à l'application
FitTrack AI. La base du projet intégré est le dossier
`dev-mobile-project-2026-feature-module2-food-catalogue`.

## Utilisation

- L'onglet **Événements** est accessible depuis la navigation principale après
  connexion.
- Le bouton **Créer** permet à l'utilisateur connecté de publier un événement.
- Les événements présentiels et hybrides nécessitent de choisir leur point
  exact sur la carte avant publication. Le titre, la ville et l'adresse restent
  des informations textuelles distinctes des coordonnées GPS.
- Un événement en ligne n'a pas de point cartographique et n'apparaît donc pas
  sur la carte.
- Dans la fiche d'un événement, l'utilisateur peut s'inscrire ou rejoindre la
  liste d'attente si la capacité est atteinte. Le créateur peut aussi gérer les
  présences, ajuster la position sur la carte et annuler son événement.
- **Ajouter à mon agenda** ouvre une application calendrier compatible avec
  l'événement prérempli. L'utilisateur doit confirmer l'enregistrement dans
  cette application. **Copier l'invitation iCal** est une autre option.

## Données et persistance

- Les événements et inscriptions sont stockés dans SQLite sur l'appareil, dans
  la base `fittrack_events.db`.
- Ces données ne sont pas synchronisées avec les autres appareils ou comptes.
  Chaque téléphone a donc sa propre liste d'événements.
- Le module ne précharge plus d'événements d'exemple. Une migration supprime
  les anciens événements de démonstration connus, tout en conservant les
  événements créés par l'utilisateur.
- Les photos d'événements sont copiées dans le stockage local de l'application.
  Elles ne sont pas téléversées vers un serveur.

## Carte

- La carte utilise `flutter_map` et les tuiles OpenStreetMap. Une connexion
  Internet est nécessaire pour charger le fond de carte.
- Les marqueurs des événements physiques visibles sont cadrés automatiquement.
- À la création, utiliser **Choisir le point sur la carte** pour placer le
  marqueur au bon endroit. Pour corriger un événement existant, ouvrir sa fiche
  et toucher **Ajuster le point sur la carte**.
- Respecter l'attribution OpenStreetMap affichée sur la carte et sa politique
  d'utilisation des tuiles.

## Recommandations Gemini (facultatif)

Les recommandations locales fonctionnent sans clé API. Pour activer Gemini en
développement :

1. Créer une clé dans [Google AI Studio](https://aistudio.google.com/).
2. Copier `env.example.json` vers `env.json` à la racine du projet intégré.
3. Renseigner `GEMINI_API_KEY` dans `env.json`.
4. Lancer avec F5 dans VS Code, ou :

   ```powershell
   flutter run --dart-define-from-file=env.json
   ```

`env.json` est ignoré par Git : ne pas le committer ni partager la clé. Sans
clé, en cas de problème réseau ou de quota atteint, le module retombe sur ses
suggestions locales. Une clé incluse dans une application mobile reste
extractible ; cette intégration directe est destinée au développement, pas à
une publication publique. Une version distribuée devrait appeler un serveur
qui protège la clé.

## Profil et rôles

Le module reçoit actuellement l'identifiant, le nom et le niveau d'activité du
compte User. Le modèle User intégré ne fournit pas encore la ville, les
centres d'intérêt ou un rôle Coach : Events utilise donc Tunis comme centre
provisoire, sans préférences personnalisées. La création est ouverte à tout
utilisateur connecté ; les actions de gestion d'un événement sont réservées à
son créateur.

## Lancer le projet

Depuis le dossier intégré :

```powershell
flutter pub get
flutter devices
flutter run
```

Le téléphone Android doit être visible par `flutter devices` avec le débogage
USB autorisé. Gemini n'est pas nécessaire pour lancer le module. La carte
requiert Internet.
