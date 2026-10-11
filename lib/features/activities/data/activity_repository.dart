import 'package:drift/drift.dart';
import 'package:latlong2/latlong.dart';
import 'package:opensport/core/database/app_database.dart';

import '../models/track.dart';
import 'demo_track.dart';

/// Lecture et écriture des activités GPS dans la base locale.
class ActivityRepository {
  ActivityRepository(this._db);

  final AppDatabase _db;

  /// Toutes les activités, la plus récente en premier, mises à jour en direct.
  Stream<List<Activity>> watchActivities() {
    return (_db.select(
      _db.activities,
    )..orderBy([(a) => OrderingTerm.desc(a.startedAt)])).watch();
  }

  /// Recharge une activité complète, avec tous ses points GPS.
  Future<Track> loadTrack(int activityId) async {
    final activity = await (_db.select(
      _db.activities,
    )..where((a) => a.id.equals(activityId))).getSingle();
    final rows =
        await (_db.select(_db.trackPoints)
              ..where((p) => p.activityId.equals(activityId))
              ..orderBy([(p) => OrderingTerm.asc(p.seq)]))
            .get();

    return Track(
      id: activity.id,
      name: activity.name,
      sport: activity.sport,
      startedAt: activity.startedAt,
      points: [
        for (final r in rows)
          TrackPoint(
            LatLng(r.latitude, r.longitude),
            r.elevation ?? 0,
            Duration(milliseconds: r.elapsedMs),
          ),
      ],
    );
  }

  /// Enregistre une trace et ses statistiques ; renvoie l'id de l'activité.
  Future<int> saveTrack(Track track) {
    return _db.transaction(() async {
      final id = await _db
          .into(_db.activities)
          .insert(
            ActivitiesCompanion.insert(
              name: track.name,
              sport: track.sport,
              startedAt: track.startedAt,
              durationMs: track.duration.inMilliseconds,
              distanceM: track.distance,
              elevationGainM: Value(track.elevationGain),
            ),
          );
      await _db.batch((batch) {
        batch.insertAll(_db.trackPoints, [
          for (final (i, p) in track.points.indexed)
            TrackPointsCompanion.insert(
              activityId: id,
              seq: i,
              latitude: p.position.latitude,
              longitude: p.position.longitude,
              elevation: Value(p.elevation),
              elapsedMs: p.elapsed.inMilliseconds,
            ),
        ]);
      });
      return id;
    });
  }

  /// Ajoute la sortie de démonstration tant qu'aucune activité n'existe,
  /// pour que l'application ne soit pas vide au premier lancement.
  Future<void> ensureDemoData() async {
    final any = await (_db.select(_db.activities)..limit(1)).get();
    if (any.isEmpty) await saveTrack(buildDemoTrack());
  }
}
