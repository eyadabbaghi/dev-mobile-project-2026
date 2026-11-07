# FitTrack AI

Application mobile Flutter de suivi nutritionnel. Cette branche implemente uniquement le **module 2 : Produits alimentaires et catalogue**.

## Module 2

- Catalogue local SQLite avec recherche par nom ou marque et filtres par categorie.
- Onglets Tous, Favoris et Mes aliments ; favoris affiches en tete de liste.
- Fiches nutritionnelles pour 100 g/ml.
- Creation, modification et suppression de ses produits personnels.
- Scanner de codes-barres avec recherche Open Food Facts et saisie manuelle de secours.
- Calculateur de portions et transfert vers un creneau repas sous forme de copie independante.
- Interface francaise sombre avec accents vert citron, cartes arrondies et panneaux de detail.

Les modules profil, journal complet/hydratation, evenements et communaute restent hors du perimetre de cette branche. Le profil local `local-user` sert de point d'integration avec une future authentification.

## Lancer sur Android

Prerequis : Flutter compatible Dart 3.13.5, SDK Android, Java et un telephone USB avec debogage active ou un emulateur demarre.

```powershell
flutter pub get
flutter devices
flutter run -d IDENTIFIANT_ANDROID
```

Le projet conserve l'identifiant Android `tn.esprit.fittrack_ai` du depot d'origine.

### Lanceur Windows du poste de developpement

```powershell
.\scripts\run-android.ps1 -Emulator
```

Ce helper cible le SDK `D:\AndroidSDK`, le cache `D:\GradleHome` et l'AVD `FitTrack_API29` dans `D:\AndroidAVDs`. Adapter ces chemins sur un autre poste, ou utiliser les commandes Flutter standard ci-dessus.

- La camera arriere de l'emulateur utilise `webcam0` ; une webcam disponible est necessaire. Les formes colorees du mode `emulated` sont une mire de simulation.
- L'AVD API 29 de ce poste exige le lancement sans Impeller : le script applique ce reglage uniquement sur emulateur.
- Si un APK debug existe, le script l'installe directement. Ajouter `-Rebuild` pour reconstruire apres modification du code.
- Pour un telephone, fermer l'emulateur puis lancer le script sans `-Emulator`, ou preciser `-Device IDENTIFIANT_ANDROID`.

Les APK, SDK, chemins locaux Gradle/Flutter, bases personnelles et caches ne sont pas versionnes.

## Utilisation

Toucher un aliment, ouvrir **Choisir ma portion**, saisir une quantite ou choisir un raccourci, puis selectionner le creneau repas et confirmer.

Le calcul est proportionnel : `valeur pour 100 g/ml x quantite / 100`. Exemple : 150 g de poulet a 165 kcal/100 g donnent 247,5 kcal. Une quantite nulle, negative ou non finie est refusee.

Le scanner attend le code-barres numerique d'un emballage, pas un QR code generique. Les produits locaux sont disponibles hors ligne. Un nouveau code-barres necessite Internet pour consulter Open Food Facts ; les produits absents peuvent etre crees manuellement. L'emulateur utilise une webcam ; un telephone utilise sa propre camera apres autorisation.

## Verification

```powershell
flutter analyze
flutter test
```

Les tests couvrent le catalogue sur ecran etroit avec clavier, l'etat Favoris vide, le recalcul des portions, les quantites invalides, la copie nutritionnelle vers le repas et la distinction entre energie par portion et energie pour 100 g dans les donnees externes.
