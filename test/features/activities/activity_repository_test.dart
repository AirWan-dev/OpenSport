import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opensport/core/database/app_database.dart';
import 'package:opensport/features/activities/data/activity_repository.dart';
import 'package:opensport/features/activities/data/demo_track.dart';

void main() {
  late AppDatabase db;
  late ActivityRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = ActivityRepository(db);
  });

  tearDown(() => db.close());

  test('une trace enregistrée se relit à l\'identique', () async {
    final original = buildDemoTrack();
    final id = await repository.saveTrack(original);
    final loaded = await repository.loadTrack(id);

    expect(loaded.id, id);
    expect(loaded.name, original.name);
    expect(loaded.sport, original.sport);
    expect(loaded.points.length, original.points.length);
    expect(loaded.distance, closeTo(original.distance, 0.01));
    expect(loaded.duration, original.duration);
  });

  test('la démo n\'est ajoutée qu\'une seule fois', () async {
    await repository.ensureDemoData();
    await repository.ensureDemoData();
    expect(await repository.watchActivities().first, hasLength(1));
  });

  test('supprimer une activité supprime ses points', () async {
    final id = await repository.saveTrack(buildDemoTrack());
    await (db.delete(db.activities)..where((a) => a.id.equals(id))).go();
    expect(await db.select(db.trackPoints).get(), isEmpty);
  });
}
