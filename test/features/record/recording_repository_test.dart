import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:opensport/core/database/app_database.dart';
import 'package:opensport/core/models/sport.dart';
import 'package:opensport/features/activities/data/activity_repository.dart';
import 'package:opensport/features/activities/models/track.dart';

void main() {
  late AppDatabase db;
  late ActivityRepository repository;
  const start = LatLng(48.8625, 2.2510);
  const distance = Distance(roundResult: false);

  TrackPoint point(double metersNorth, int seconds, {int segment = 0}) =>
      TrackPoint(
        distance.offset(start, metersNorth, 0),
        35,
        Duration(seconds: seconds),
        segment: segment,
      );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = ActivityRepository(db);
  });

  tearDown(() => db.close());

  test(
    'une sortie en cours est invisible dans le fil, puis apparaît',
    () async {
      final id = await repository.startRecording(
        Sport.run,
        DateTime(2026, 10, 11, 8),
      );
      await repository.addPoint(id, 0, point(0, 0));
      await repository.addPoint(id, 1, point(100, 30));

      expect(await repository.watchActivities().first, isEmpty);
      expect((await repository.findInterruptedRecording())?.id, id);

      await repository.finishRecording(
        id,
        name: 'Course du matin',
        sport: Sport.run,
      );

      final list = await repository.watchActivities().first;
      expect(list.single.name, 'Course du matin');
      expect(list.single.distanceM, closeTo(100, 0.5));
      expect(await repository.findInterruptedRecording(), isNull);
    },
  );

  test('la distance parcourue pendant une pause ne compte pas', () async {
    final id = await repository.startRecording(
      Sport.run,
      DateTime(2026, 10, 11),
    );
    await repository.addPoint(id, 0, point(0, 0));
    await repository.addPoint(id, 1, point(100, 30));
    // Pause : 400 m parcourus à pied, puis reprise sur un nouveau tronçon.
    await repository.addPoint(id, 2, point(500, 31, segment: 1));
    await repository.addPoint(id, 3, point(600, 60, segment: 1));

    final track = await repository.loadTrack(id);
    expect(track.distance, closeTo(200, 0.5));
  });

  test('la démo disparaît à la première vraie sortie', () async {
    await repository.ensureDemoData();
    final id = await repository.startRecording(
      Sport.ride,
      DateTime(2026, 10, 11),
    );
    await repository.addPoint(id, 0, point(0, 0));
    await repository.addPoint(id, 1, point(500, 60));
    await repository.finishRecording(
      id,
      name: 'Sortie vélo',
      sport: Sport.ride,
    );

    final list = await repository.watchActivities().first;
    expect(list.map((a) => a.name), ['Sortie vélo']);
  });

  test('titre automatique selon l\'heure', () {
    expect(Sport.run.defaultTitle(DateTime(2026, 1, 1, 7)), 'Course du matin');
    expect(
      Sport.ride.defaultTitle(DateTime(2026, 1, 1, 19)),
      'Sortie vélo du soir',
    );
  });
}
