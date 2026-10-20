import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../models/activity_status.dart';
import '../models/equipment.dart';
import '../models/exercise_type.dart';
import '../models/muscle.dart';
import '../models/set_kind.dart';
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

// Tables recréées en version 3 du schéma (jamais utilisées avant).

/// Un exercice : fourni avec l'app (bibliothèque) ou créé par l'utilisateur.
class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Clé stable d'un exercice de la bibliothèque (« bench-press-barbell »),
  /// nulle pour un exercice créé par l'utilisateur.
  TextColumn get catalogKey => text().nullable().unique()();
  TextColumn get name => text()();
  TextColumn get type => textEnum<ExerciseType>()();
  TextColumn get primaryMuscle => textEnum<Muscle>()();
  TextColumn get secondaryMuscles => text().map(const MuscleListConverter())();
  TextColumn get equipment => textEnum<Equipment>()();

  /// Masqué de la bibliothèque mais gardé pour l'historique des séances.
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
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

/// Un exercice dans une séance, dans l'ordre de [position]. Il existe dès
/// qu'on l'ajoute, même avant sa première série.
class WorkoutExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutId =>
      integer().references(Workouts, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get position => integer()();
  TextColumn get notes => text().nullable()();
  IntColumn get restSeconds => integer().withDefault(const Constant(90))();
}

/// Une série d'un exercice de la séance, dans l'ordre de [position]. Selon
/// le type d'exercice : [weightKg] × [reps], [reps] avec un lest facultatif
/// dans [weightKg], ou [durationSeconds].
class WorkoutSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutExerciseId => integer().references(
    WorkoutExercises,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get position => integer()();
  TextColumn get kind =>
      textEnum<SetKind>().withDefault(Constant(SetKind.normal.name))();
  RealColumn get weightKg => real().nullable()();
  IntColumn get reps => integer().nullable()();
  IntColumn get durationSeconds => integer().nullable()();

  /// Heure à laquelle la série a été cochée ; nulle tant qu'elle n'est pas faite.
  DateTimeColumn get completedAt => dateTime().nullable()();
}

/// Liste de muscles stockée en texte : « shoulders,triceps ».
class MuscleListConverter extends TypeConverter<List<Muscle>, String> {
  const MuscleListConverter();

  @override
  List<Muscle> fromSql(String fromDb) => [
    for (final name in fromDb.split(','))
      if (name.isNotEmpty) Muscle.values.byName(name),
  ];

  @override
  String toSql(List<Muscle> value) => value.map((m) => m.name).join(',');
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
    WorkoutExercises,
    WorkoutSets,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  @override
  int get schemaVersion => 3;

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
      if (from < 3) {
        // Les tables de musculation n'avaient jamais servi : elles sont
        // recréées sous leur nouvelle forme, sans données à reprendre.
        for (final name in [
          'workout_sets',
          'workouts',
          'routine_exercises',
          'routines',
          'exercises',
        ]) {
          await migrator.deleteTable(name);
        }
        for (final table in <TableInfo>[
          exercises,
          routines,
          routineExercises,
          workouts,
          workoutExercises,
          workoutSets,
        ]) {
          await migrator.createTable(table);
        }
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
