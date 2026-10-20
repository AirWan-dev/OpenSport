import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opensport/core/database/app_database.dart';

import '../../generated_migrations/schema.dart';
import '../../generated_migrations/schema_v2.dart' as v2;

// Schémas de référence dans drift_schemas/. Après un changement de schéma :
//   dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/
//   dart run drift_dev schema generate --data-classes --companions drift_schemas/ test/generated_migrations/
void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('la version 2 passe à la version 3', () async {
    final db = AppDatabase(await verifier.startAt(2));
    await verifier.migrateAndValidate(db, 3);
    await db.close();
  });

  test('les sorties GPS survivent au passage à la version 3', () async {
    final schema = await verifier.schemaAt(2);
    final old = v2.DatabaseAtV2(schema.newConnection());
    final id = await old
        .into(old.activities)
        .insert(
          v2.ActivitiesCompanion.insert(
            name: 'Course du matin',
            sport: 'run',
            startedAt: 1792483200,
            durationMs: 1800000,
            distanceM: 5000,
          ),
        );
    await old
        .into(old.trackPoints)
        .insert(
          v2.TrackPointsCompanion.insert(
            activityId: id,
            seq: 0,
            latitude: 48.86,
            longitude: 2.25,
            elapsedMs: 0,
          ),
        );
    await old.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 3);
    final activity = await db.select(db.activities).getSingle();
    expect(activity.name, 'Course du matin');
    expect(activity.distanceM, 5000);
    expect(await db.select(db.trackPoints).get(), hasLength(1));
    await db.close();
  });
}
