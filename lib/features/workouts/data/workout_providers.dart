import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opensport/core/database/app_database.dart';
import 'package:opensport/core/database/database_provider.dart';

import 'exercise_catalog.dart';
import 'exercise_repository.dart';

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
