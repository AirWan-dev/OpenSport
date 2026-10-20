import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:opensport/core/database/app_database.dart';

import 'exercise_catalog.dart';

/// Lecture et écriture des exercices dans la base locale.
class ExerciseRepository {
  ExerciseRepository(this._db);

  final AppDatabase _db;

  /// Les exercices proposés (hors archivés), en direct.
  Stream<List<Exercise>> watchExercises() {
    return (_db.select(_db.exercises)
          ..where((e) => e.isArchived.equals(false))
          ..orderBy([(e) => OrderingTerm.asc(e.name)]))
        .watch();
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
