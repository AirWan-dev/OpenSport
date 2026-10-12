import 'package:drift/drift.dart';
import 'package:latlong2/latlong.dart';
import 'package:opensport/core/database/app_database.dart';
import 'package:opensport/core/models/activity_status.dart';
import 'package:opensport/core/models/sport.dart';

import '../models/track.dart';
import 'demo_track.dart';

/// Lecture et écriture des activités GPS dans la base locale.
class ActivityRepository {
  ActivityRepository(this._db);

  final AppDatabase _db;

  /// Les activités terminées, la plus récente en premier, en direct.
  Stream<List<Activity>> watchActivities() {
    return (_db.select(_db.activities)
          ..where((a) => a.status.equalsValue(ActivityStatus.finished))
          ..orderBy([(a) => OrderingTerm.desc(a.startedAt)]))
        .watch();
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
            segment: r.segment,
          ),
      ],
    );
  }

  /// Enregistre une trace et ses statistiques ; renvoie l'id de l'activité.
  Future<int> saveTrack(Track track, {bool isDemo = false}) {
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
              isDemo: Value(isDemo),
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
              segment: Value(p.segment),
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
    if (any.isEmpty) await saveTrack(buildDemoTrack(), isDemo: true);
  }

  // ----------------------------------------------------- Enregistrement

  /// Crée l'activité « en cours » dès le départ : chaque point y est écrit
  /// au fil de l'eau, rien n'est perdu si l'app s'arrête brutalement.
  Future<int> startRecording(Sport sport, DateTime startedAt) {
    return _db
        .into(_db.activities)
        .insert(
          ActivitiesCompanion.insert(
            name: sport.label,
            sport: sport,
            startedAt: startedAt,
            durationMs: 0,
            distanceM: 0,
            status: const Value(ActivityStatus.recording),
          ),
        );
  }

  Future<void> addPoint(
    int activityId,
    int seq,
    TrackPoint point, {
    double? accuracy,
  }) {
    return _db
        .into(_db.trackPoints)
        .insert(
          TrackPointsCompanion.insert(
            activityId: activityId,
            seq: seq,
            latitude: point.position.latitude,
            longitude: point.position.longitude,
            elevation: Value(point.elevation),
            elapsedMs: point.elapsed.inMilliseconds,
            accuracyM: Value(accuracy),
            segment: Value(point.segment),
          ),
        );
  }

  /// Une sortie restée « en cours » (app fermée par le système, plantage,
  /// batterie vide...), ou null.
  Future<Activity?> findInterruptedRecording() {
    return (_db.select(_db.activities)
          ..where((a) => a.status.equalsValue(ActivityStatus.recording))
          ..orderBy([(a) => OrderingTerm.desc(a.startedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Termine une sortie : ses statistiques sont recalculées à partir des
  /// points enregistrés, et la sortie de démonstration disparaît.
  Future<void> finishRecording(
    int activityId, {
    required String name,
    required Sport sport,
    String? notes,
  }) async {
    final track = await loadTrack(activityId);
    await _db.transaction(() async {
      await (_db.update(
        _db.activities,
      )..where((a) => a.id.equals(activityId))).write(
        ActivitiesCompanion(
          name: Value(name),
          sport: Value(sport),
          notes: Value(notes),
          durationMs: Value(track.duration.inMilliseconds),
          distanceM: Value(track.distance),
          elevationGainM: Value(track.elevationGain),
          status: const Value(ActivityStatus.finished),
        ),
      );
      await (_db.delete(
        _db.activities,
      )..where((a) => a.isDemo.equals(true))).go();
    });
  }

  /// Supprime une activité et ses points.
  Future<void> deleteActivity(int activityId) {
    return (_db.delete(
      _db.activities,
    )..where((a) => a.id.equals(activityId))).go();
  }
}
