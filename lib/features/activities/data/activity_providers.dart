import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opensport/core/database/app_database.dart';
import 'package:opensport/core/database/database_provider.dart';

import '../models/track.dart';
import 'activity_repository.dart';

final activityRepositoryProvider = Provider<ActivityRepository>(
  (ref) => ActivityRepository(ref.watch(databaseProvider)),
);

/// Liste des activités pour le fil, mise à jour à chaque enregistrement.
final activitiesProvider = StreamProvider<List<Activity>>((ref) async* {
  final repository = ref.watch(activityRepositoryProvider);
  await repository.ensureDemoData();
  yield* repository.watchActivities();
});

/// Trace complète d'une activité (points GPS compris).
final trackProvider = FutureProvider.family<Track, int>(
  (ref, activityId) =>
      ref.watch(activityRepositoryProvider).loadTrack(activityId),
);
