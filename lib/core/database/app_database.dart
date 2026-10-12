import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../models/activity_status.dart';
import '../models/sport.dart';

part 'app_database.g.dart';

// ------------------------------------------------------------ Activités GPS

/// Une activité GPS enregistrée : course, vélo...
class Activities extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get sport => textEnum<Sport>()();
  DateTimeColumn get startedAt => dateTime()();
  IntColumn get durationMs => integer()();
  RealColumn get distanceM => real()();
  RealColumn get elevationGainM => real().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  // Version 2 du schéma.
  TextColumn get status => textEnum<ActivityStatus>().withDefault(
    Constant(ActivityStatus.finished.name),
  )();

  /// Sortie de démonstration, retirée dès la première vraie sortie.
  BoolColumn get isDemo => boolean().withDefault(const Constant(false))();
}

/// Les points GPS d'une activité, dans l'ordre de [seq].
@DataClassName('TrackPointRow')
@TableIndex(name: 'track_points_by_activity', columns: {#activityId, #seq})
class TrackPoints extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get activityId =>
      integer().references(Activities, #id, onDelete: KeyAction.cascade)();
  IntColumn get seq => integer()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  RealColumn get elevation => real().nullable()();
  IntColumn get elapsedMs => integer()();

  /// Précision horizontale annoncée par le GPS, en mètres.
  RealColumn get accuracyM => real().nullable()();

  /// Tronçon (version 2) : il change à chaque reprise après une pause, et
  /// la distance entre deux tronçons n'est pas comptée.
  IntColumn get segment => integer().withDefault(const Constant(0))();
}

/// Une photo rattachée à une activité, placée sur le tracé si possible.
class ActivityPhotos extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get activityId =>
      integer().references(Activities, #id, onDelete: KeyAction.cascade)();
  TextColumn get filePath => text()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  DateTimeColumn get takenAt => dateTime().nullable()();
}

// ------------------------------------------------------------- Musculation

/// Un exercice de la bibliothèque (fourni ou créé par l'utilisateur).
class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get primaryMuscle => text()();
  TextColumn get equipment => text().nullable()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
}

/// Un modèle de séance réutilisable (« Push », « Jambes »...).
class Routines extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Les exercices prévus dans une routine, dans l'ordre de [position].
class RoutineExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get routineId =>
      integer().references(Routines, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get position => integer()();
  IntColumn get targetSets => integer().withDefault(const Constant(3))();
  IntColumn get targetReps => integer().nullable()();
  IntColumn get restSeconds => integer().withDefault(const Constant(90))();
}

/// Une séance de musculation réalisée (ou en cours si [endedAt] est nul).
class Workouts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().nullable()();
  IntColumn get routineId => integer().nullable().references(
    Routines,
    #id,
    onDelete: KeyAction.setNull,
  )();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
}

/// Une série : [weightKg] × [reps] sur un exercice, pendant une séance.
class WorkoutSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutId =>
      integer().references(Workouts, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();

  /// Rang de l'exercice dans la séance, puis de la série dans l'exercice.
  IntColumn get exerciseOrder => integer()();
  IntColumn get setOrder => integer()();
  RealColumn get weightKg => real().nullable()();
  IntColumn get reps => integer().nullable()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
}

// ------------------------------------------------------------------- Base

/// Base SQLite locale : toutes les données restent sur le téléphone.
@DriftDatabase(
  tables: [
    Activities,
    TrackPoints,
    ActivityPhotos,
    Exercises,
    Routines,
    RoutineExercises,
    Workouts,
    WorkoutSets,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(activities, activities.status);
        await migrator.addColumn(activities, activities.isDemo);
        await migrator.addColumn(trackPoints, trackPoints.segment);
        // Seule la sortie de démonstration existait en version 1.
        await (update(activities)
              ..where((a) => a.name.equals('Sortie de démonstration')))
            .write(const ActivitiesCompanion(isDemo: Value(true)));
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  static QueryExecutor _open() => driftDatabase(
    name: 'opensport',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
