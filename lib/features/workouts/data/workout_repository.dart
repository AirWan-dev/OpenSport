import 'package:drift/drift.dart';
import 'package:opensport/core/database/app_database.dart';
import 'package:opensport/core/models/set_kind.dart';

import '../models/workout_session.dart';

/// Lecture et écriture des séances de musculation. Chaque saisie est écrite
/// aussitôt : une séance interrompue (app fermée) se reprend telle quelle.
class WorkoutRepository {
  WorkoutRepository(this._db);

  final AppDatabase _db;

  SimpleSelectStatement<$WorkoutsTable, Workout> _activeWorkout() {
    return _db.select(_db.workouts)
      ..where((w) => w.endedAt.isNull())
      ..orderBy([(w) => OrderingTerm.desc(w.startedAt)])
      ..limit(1);
  }

  /// La séance en cours (pas encore terminée), ou null, en direct.
  Stream<Workout?> watchActiveWorkout() => _activeWorkout().watchSingleOrNull();

  /// Démarre une séance vide, ou renvoie celle déjà en cours : une seule
  /// séance à la fois.
  Future<int> startWorkout({DateTime? at}) {
    return _db.transaction(() async {
      final active = await _activeWorkout().getSingleOrNull();
      if (active != null) return active.id;
      return _db
          .into(_db.workouts)
          .insert(WorkoutsCompanion.insert(startedAt: at ?? DateTime.now()));
    });
  }

  /// La séance [workoutId] et son contenu, rechargés à chaque modification ;
  /// null si elle a été supprimée.
  Stream<WorkoutSession?> watchSession(int workoutId) async* {
    final tables = TableUpdateQuery.onAllTables([
      _db.workouts,
      _db.workoutExercises,
      _db.workoutSets,
      _db.exercises,
    ]);
    yield await loadSession(workoutId);
    await for (final _ in _db.tableUpdates(tables)) {
      yield await loadSession(workoutId);
    }
  }

  Future<WorkoutSession?> loadSession(int workoutId) async {
    final workout = await (_db.select(
      _db.workouts,
    )..where((w) => w.id.equals(workoutId))).getSingleOrNull();
    if (workout == null) return null;

    final rows =
        await (_db.select(_db.workoutExercises).join([
                innerJoin(
                  _db.exercises,
                  _db.exercises.id.equalsExp(_db.workoutExercises.exerciseId),
                ),
              ])
              ..where(_db.workoutExercises.workoutId.equals(workoutId))
              ..orderBy([OrderingTerm.asc(_db.workoutExercises.position)]))
            .get();
    final entries = [
      for (final row in rows)
        (row.readTable(_db.workoutExercises), row.readTable(_db.exercises)),
    ];
    final sets =
        await (_db.select(_db.workoutSets)
              ..where(
                (s) => s.workoutExerciseId.isIn([
                  for (final (entry, _) in entries) entry.id,
                ]),
              )
              ..orderBy([(s) => OrderingTerm.asc(s.position)]))
            .get();

    return WorkoutSession(
      workout: workout,
      exercises: [
        for (final (entry, exercise) in entries)
          SessionExercise(
            entry: entry,
            exercise: exercise,
            sets: [
              for (final s in sets)
                if (s.workoutExerciseId == entry.id) s,
            ],
            previous: await previousSets(
              exercise.id,
              excludingWorkoutId: workoutId,
            ),
          ),
      ],
    );
  }

  /// Séries cochées sur [exerciseId] lors de la dernière séance terminée,
  /// sans compter la séance [excludingWorkoutId].
  Future<List<WorkoutSet>> previousSets(
    int exerciseId, {
    required int excludingWorkoutId,
  }) async {
    final last =
        await (_db.select(_db.workoutExercises).join([
                innerJoin(
                  _db.workouts,
                  _db.workouts.id.equalsExp(_db.workoutExercises.workoutId),
                ),
              ])
              ..where(
                _db.workoutExercises.exerciseId.equals(exerciseId) &
                    _db.workouts.endedAt.isNotNull() &
                    _db.workouts.id.equals(excludingWorkoutId).not(),
              )
              ..orderBy([
                OrderingTerm.desc(_db.workouts.startedAt),
                OrderingTerm.asc(_db.workoutExercises.position),
              ])
              ..limit(1))
            .getSingleOrNull();
    if (last == null) return const [];

    final entryId = last.readTable(_db.workoutExercises).id;
    return (_db.select(_db.workoutSets)
          ..where(
            (s) =>
                s.workoutExerciseId.equals(entryId) & s.completedAt.isNotNull(),
          )
          ..orderBy([(s) => OrderingTerm.asc(s.position)]))
        .get();
  }

  /// Ajoute des exercices à la fin de la séance, chacun avec autant de
  /// séries (et du même type) que la dernière fois, ou une seule.
  Future<void> addExercises(int workoutId, List<Exercise> exercises) {
    return _db.transaction(() async {
      var position = await _countEntries(workoutId);
      for (final exercise in exercises) {
        final previous = await previousSets(
          exercise.id,
          excludingWorkoutId: workoutId,
        );
        final entryId = await _db
            .into(_db.workoutExercises)
            .insert(
              WorkoutExercisesCompanion.insert(
                workoutId: workoutId,
                exerciseId: exercise.id,
                position: position++,
              ),
            );
        final kinds = previous.isEmpty
            ? const [SetKind.normal]
            : [for (final s in previous) s.kind];
        await _db.batch(
          (batch) => batch.insertAll(_db.workoutSets, [
            for (final (i, kind) in kinds.indexed)
              WorkoutSetsCompanion.insert(
                workoutExerciseId: entryId,
                position: i,
                kind: Value(kind),
              ),
          ]),
        );
      }
    });
  }

  /// Retire un exercice et ses séries de la séance.
  Future<void> removeExercise(WorkoutExercise entry) {
    return _db.transaction(() async {
      await (_db.delete(
        _db.workoutExercises,
      )..where((e) => e.id.equals(entry.id))).go();
      await _renumberEntries(entry.workoutId);
    });
  }

  /// Déplace un exercice d'un cran vers le haut (-1) ou le bas (+1).
  Future<void> moveExercise(WorkoutExercise entry, int delta) {
    return _db.transaction(() async {
      final entries = await _entries(entry.workoutId);
      final from = entries.indexWhere((e) => e.id == entry.id);
      final to = from + delta;
      if (from < 0 || to < 0 || to >= entries.length) return;
      entries.insert(to, entries.removeAt(from));
      await _writeEntryPositions(entries);
    });
  }

  Future<void> updateNote(WorkoutExercise entry, String note) {
    final text = note.trim();
    return (_db.update(
      _db.workoutExercises,
    )..where((e) => e.id.equals(entry.id))).write(
      WorkoutExercisesCompanion(notes: Value(text.isEmpty ? null : text)),
    );
  }

  /// Ajoute une série normale à la fin de l'exercice.
  Future<void> addSet(WorkoutExercise entry) async {
    final count = await _countSets(entry.id);
    await _db
        .into(_db.workoutSets)
        .insert(
          WorkoutSetsCompanion.insert(
            workoutExerciseId: entry.id,
            position: count,
          ),
        );
  }

  Future<void> deleteSet(WorkoutSet set) {
    return _db.transaction(() async {
      await (_db.delete(
        _db.workoutSets,
      )..where((s) => s.id.equals(set.id))).go();
      final siblings =
          await (_db.select(_db.workoutSets)
                ..where(
                  (s) => s.workoutExerciseId.equals(set.workoutExerciseId),
                )
                ..orderBy([(s) => OrderingTerm.asc(s.position)]))
              .get();
      for (final (i, s) in siblings.indexed) {
        if (s.position == i) continue;
        await (_db.update(_db.workoutSets)..where((x) => x.id.equals(s.id)))
            .write(WorkoutSetsCompanion(position: Value(i)));
      }
    });
  }

  Future<void> setKind(WorkoutSet set, SetKind kind) {
    return (_db.update(_db.workoutSets)..where((s) => s.id.equals(set.id)))
        .write(WorkoutSetsCompanion(kind: Value(kind)));
  }

  Future<void> updateSetValues(WorkoutSet set, SetValues values) {
    return (_db.update(
      _db.workoutSets,
    )..where((s) => s.id.equals(set.id))).write(_valuesCompanion(values));
  }

  /// Coche la série (avec ses valeurs définitives) ou la décoche.
  Future<void> setCompleted(
    WorkoutSet set, {
    required bool done,
    SetValues? values,
    DateTime? at,
  }) {
    final companion = values == null
        ? const WorkoutSetsCompanion()
        : _valuesCompanion(values);
    return (_db.update(
      _db.workoutSets,
    )..where((s) => s.id.equals(set.id))).write(
      companion.copyWith(
        completedAt: Value(done ? (at ?? DateTime.now()) : null),
      ),
    );
  }

  /// Termine la séance : les séries non cochées sont retirées, puis les
  /// exercices restés sans série.
  Future<void> finishWorkout(int workoutId, {DateTime? at}) {
    return _db.transaction(() async {
      final entryIds = _db.selectOnly(_db.workoutExercises)
        ..addColumns([_db.workoutExercises.id])
        ..where(_db.workoutExercises.workoutId.equals(workoutId));
      await (_db.delete(_db.workoutSets)..where(
            (s) =>
                s.completedAt.isNull() &
                s.workoutExerciseId.isInQuery(entryIds),
          ))
          .go();
      await (_db.delete(_db.workoutExercises)..where(
            (e) =>
                e.workoutId.equals(workoutId) &
                notExistsQuery(
                  _db.select(_db.workoutSets)
                    ..where((s) => s.workoutExerciseId.equalsExp(e.id)),
                ),
          ))
          .go();
      await _renumberEntries(workoutId);
      await (_db.update(_db.workouts)..where((w) => w.id.equals(workoutId)))
          .write(WorkoutsCompanion(endedAt: Value(at ?? DateTime.now())));
    });
  }

  /// Supprime la séance et tout son contenu.
  Future<void> discardWorkout(int workoutId) {
    return (_db.delete(
      _db.workouts,
    )..where((w) => w.id.equals(workoutId))).go();
  }

  static WorkoutSetsCompanion _valuesCompanion(SetValues values) =>
      WorkoutSetsCompanion(
        weightKg: Value(values.weightKg),
        reps: Value(values.reps),
        durationSeconds: Value(values.durationSeconds),
      );

  Future<List<WorkoutExercise>> _entries(int workoutId) {
    return (_db.select(_db.workoutExercises)
          ..where((e) => e.workoutId.equals(workoutId))
          ..orderBy([(e) => OrderingTerm.asc(e.position)]))
        .get();
  }

  Future<int> _countEntries(int workoutId) async =>
      (await _entries(workoutId)).length;

  Future<int> _countSets(int entryId) async => (await (_db.select(
    _db.workoutSets,
  )..where((s) => s.workoutExerciseId.equals(entryId))).get()).length;

  Future<void> _renumberEntries(int workoutId) async =>
      _writeEntryPositions(await _entries(workoutId));

  Future<void> _writeEntryPositions(List<WorkoutExercise> entries) async {
    for (final (i, e) in entries.indexed) {
      if (e.position == i) continue;
      await (_db.update(_db.workoutExercises)..where((x) => x.id.equals(e.id)))
          .write(WorkoutExercisesCompanion(position: Value(i)));
    }
  }
}
