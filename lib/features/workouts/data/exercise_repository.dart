import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:opensport/core/database/app_database.dart';
import 'package:opensport/core/models/equipment.dart';
import 'package:opensport/core/models/exercise_type.dart';
import 'package:opensport/core/models/muscle.dart';
import 'package:opensport/core/search.dart';

import 'exercise_catalog.dart';

/// Lecture et écriture des exercices dans la base locale.
class ExerciseRepository {
  ExerciseRepository(this._db);

  final AppDatabase _db;

  /// Les exercices proposés (hors archivés), en direct, par ordre
  /// alphabétique sans tenir compte des accents (« Écarté » avec les E).
  Stream<List<Exercise>> watchExercises() {
    final query = _db.select(_db.exercises)
      ..where((e) => e.isArchived.equals(false));
    return query.watch().map(
      (list) => list
        ..sort(
          (a, b) =>
              normalizeForSearch(a.name).compareTo(normalizeForSearch(b.name)),
        ),
    );
  }

  /// Crée un exercice perso, ou modifie celui d'id [id]. Renvoie son id.
  Future<int> saveCustomExercise({
    int? id,
    required String name,
    required ExerciseType type,
    required Muscle primaryMuscle,
    required List<Muscle> secondaryMuscles,
    required Equipment equipment,
  }) async {
    final companion = ExercisesCompanion.insert(
      name: name.trim(),
      type: type,
      primaryMuscle: primaryMuscle,
      secondaryMuscles: secondaryMuscles,
      equipment: equipment,
    );
    if (id == null) return _db.into(_db.exercises).insert(companion);
    await (_db.update(
      _db.exercises,
    )..where((e) => e.id.equals(id) & e.catalogKey.isNull())).write(companion);
    return id;
  }

  /// Retire un exercice perso de la bibliothèque. S'il figure dans une
  /// séance ou une routine, il est seulement archivé pour garder l'historique.
  Future<void> deleteCustomExercise(int id) {
    return _db.transaction(() async {
      final inWorkout = await (_db.select(
        _db.workoutExercises,
      )..where((w) => w.exerciseId.equals(id))).get();
      final inRoutine = await (_db.select(
        _db.routineExercises,
      )..where((r) => r.exerciseId.equals(id))).get();
      if (inWorkout.isEmpty && inRoutine.isEmpty) {
        await (_db.delete(
          _db.exercises,
        )..where((e) => e.id.equals(id) & e.catalogKey.isNull())).go();
      } else {
        await (_db.update(_db.exercises)
              ..where((e) => e.id.equals(id) & e.catalogKey.isNull()))
            .write(const ExercisesCompanion(isArchived: Value(true)));
      }
    });
  }

  /// Aligne la base sur la bibliothèque fournie : ajoute les nouveaux
  /// exercices, met à jour ceux qui ont changé et archive ceux qui en ont
  /// disparu. Les exercices créés par l'utilisateur ne sont jamais touchés,
  /// et rien n'est écrit si tout est déjà à jour.
  Future<void> syncCatalog(List<CatalogExercise> catalog) {
    return _db.transaction(() async {
      final query = _db.select(_db.exercises)
        ..where((e) => e.catalogKey.isNotNull());
      final existing = {for (final e in await query.get()) e.catalogKey!: e};

      for (final exercise in catalog) {
        final row = existing.remove(exercise.key);
        if (row == null) {
          await _db.into(_db.exercises).insert(_companion(exercise));
        } else if (!_isUpToDate(row, exercise)) {
          await (_db.update(
            _db.exercises,
          )..where((e) => e.id.equals(row.id))).write(_companion(exercise));
        }
      }
      for (final removed in existing.values.where((e) => !e.isArchived)) {
        await (_db.update(_db.exercises)..where((e) => e.id.equals(removed.id)))
            .write(const ExercisesCompanion(isArchived: Value(true)));
      }
    });
  }

  static ExercisesCompanion _companion(CatalogExercise exercise) {
    return ExercisesCompanion.insert(
      catalogKey: Value(exercise.key),
      name: exercise.name,
      type: exercise.type,
      primaryMuscle: exercise.primaryMuscle,
      secondaryMuscles: exercise.secondaryMuscles,
      equipment: exercise.equipment,
      isArchived: const Value(false),
    );
  }

  static bool _isUpToDate(Exercise row, CatalogExercise exercise) {
    return !row.isArchived &&
        row.name == exercise.name &&
        row.type == exercise.type &&
        row.primaryMuscle == exercise.primaryMuscle &&
        listEquals(row.secondaryMuscles, exercise.secondaryMuscles) &&
        row.equipment == exercise.equipment;
  }
}
