import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opensport/core/database/app_database.dart';
import 'package:opensport/core/database/database_provider.dart';

import '../models/workout_session.dart';
import 'exercise_catalog.dart';
import 'exercise_repository.dart';
import 'workout_repository.dart';

final workoutRepositoryProvider = Provider<WorkoutRepository>(
  (ref) => WorkoutRepository(ref.watch(databaseProvider)),
);

/// La séance en cours, ou null : sert au bandeau visible depuis tous les
/// onglets.
final activeWorkoutProvider = StreamProvider<Workout?>(
  (ref) => ref.watch(workoutRepositoryProvider).watchActiveWorkout(),
);

/// Une séance et tout son contenu, en direct ; null si elle a été supprimée.
final workoutSessionProvider = StreamProvider.autoDispose
    .family<WorkoutSession?, int>(
      (ref, workoutId) =>
          ref.watch(workoutRepositoryProvider).watchSession(workoutId),
    );

final exerciseRepositoryProvider = Provider<ExerciseRepository>(
  (ref) => ExerciseRepository(ref.watch(databaseProvider)),
);

/// Exercices proposés, après mise à jour de la bibliothèque fournie avec
/// l'app (nouveaux exercices d'une nouvelle version, par exemple).
final exercisesProvider = StreamProvider<List<Exercise>>((ref) async* {
  final repository = ref.watch(exerciseRepositoryProvider);
  final catalog = parseCatalog(await rootBundle.loadString(catalogAsset));
  await repository.syncCatalog(catalog);
  yield* repository.watchExercises();
});
