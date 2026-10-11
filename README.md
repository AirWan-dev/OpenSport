# OpenSport

Application de sport **libre et gratuite** pour Android et iPhone, qui réunit :

- **la musculation**, façon Hevy : séances, séries, routines, progression ;
- **les activités GPS**, façon Strava : enregistrer une course ou une sortie vélo, la revoir sur une belle carte, analyser son allure et son dénivelé.

Gratuite pour toujours, sans compte obligatoire : les données restent sur le téléphone.

*A free and open-source fitness app combining strength training logs and GPS activity tracking. Local-first, no account required.*

> **État : en construction.** Les fondations sont posées (base locale, navigation, thème) ; l'enregistrement GPS et la musculation arrivent.

## Feuille de route

0. **Fondations** : base de données locale, navigation, thème
1. **GPS et carte** : enregistrement en direct, historique, style de carte sombre fait maison
2. **Musculation** : exercices, séance en direct, minuteur de repos, routines, records
3. **Carte enrichie** : carte de chaleur, photos sur le parcours
4. **Partage** : image de la sortie à partager

## Lancer le projet

Prérequis : [Flutter](https://docs.flutter.dev/get-started/install) (canal stable), plus Android Studio pour Android et Xcode pour iOS.

```bash
flutter pub get
flutter run
```

Aperçu rapide dans le navigateur :

```bash
flutter run -d chrome
```

Tests et analyse :

```bash
flutter analyze
flutter test
```

## Structure du code

```
lib/
  app/            squelette de l'app (onglets)
  core/           base de données, thème, widgets et formats partagés
  features/
    activities/   activités GPS : fil, carte, replay
    record/       enregistrement GPS (à venir)
    workouts/     musculation (à venir)
    profile/      profil et informations
```

Après une modification du schéma de la base (`lib/core/database/app_database.dart`), régénérer le code :

```bash
dart run build_runner build
```

## Technologies

- [Flutter](https://flutter.dev) : un seul code pour Android et iOS
- [flutter_map](https://pub.dev/packages/flutter_map) : affichage de la carte
- [fl_chart](https://pub.dev/packages/fl_chart) : graphiques
- [Drift](https://drift.simonbinder.eu) : base SQLite locale
- [Riverpod](https://riverpod.dev) : gestion d'état
- Fonds de carte © [OpenStreetMap](https://www.openstreetmap.org/copyright), imagerie © Esri

## Contribuer

Le projet débute. Les issues et propositions sont les bienvenues.

## Licence

[GPL-3.0](LICENSE) : chacun peut utiliser, étudier, modifier et redistribuer l'application. Toute version modifiée qui est redistribuée doit rester sous la même licence, donc libre.
