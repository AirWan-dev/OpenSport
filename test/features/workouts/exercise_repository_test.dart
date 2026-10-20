import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opensport/core/database/app_database.dart';
import 'package:opensport/core/models/equipment.dart';
import 'package:opensport/core/models/exercise_type.dart';
import 'package:opensport/core/models/muscle.dart';
import 'package:opensport/features/workouts/data/exercise_catalog.dart';
import 'package:opensport/features/workouts/data/exercise_repository.dart';

CatalogExercise _exercise(String key, String name) => CatalogExercise(
  key: key,
  name: name,
  type: ExerciseType.weightReps,
  primaryMuscle: Muscle.chest,
  secondaryMuscles: const [Muscle.shoulders, Muscle.triceps],
  equipment: Equipment.barbell,
);

void main() {
  late AppDatabase db;
  late ExerciseRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = ExerciseRepository(db);
  });

  tearDown(() => db.close());

  Future<Exercise> byKey(String key) => (db.select(
    db.exercises,
  )..where((e) => e.catalogKey.equals(key))).getSingle();

  test('la bibliothèque n\'est ajoutée qu\'une seule fois', () async {
    final catalog = [_exercise('bench', 'Développé couché (barre)')];
    await repository.syncCatalog(catalog);
    await repository.syncCatalog(catalog);

    final exercises = await repository.watchExercises().first;
    expect(exercises, hasLength(1));
    expect(exercises.single.secondaryMuscles, [
      Muscle.shoulders,
      Muscle.triceps,
    ]);
  });

  test(
    'un exercice renommé dans une nouvelle version est mis à jour',
    () async {
      await repository.syncCatalog([_exercise('bench', 'Développé couché')]);
      final before = await byKey('bench');
      await repository.syncCatalog([
        _exercise('bench', 'Développé couché (barre)'),
      ]);
      final after = await byKey('bench');

      expect(after.id, before.id);
      expect(after.name, 'Développé couché (barre)');
    },
  );

  test('un exercice retiré est archivé, puis restauré s\'il revient', () async {
    final bench = _exercise('bench', 'Développé couché (barre)');
    final squat = _exercise('squat', 'Squat (barre)');
    await repository.syncCatalog([bench, squat]);
    await repository.syncCatalog([bench]);

    expect((await byKey('squat')).isArchived, isTrue);
    expect(await repository.watchExercises().first, hasLength(1));

    await repository.syncCatalog([bench, squat]);
    expect((await byKey('squat')).isArchived, isFalse);
  });

  test('un exercice perso n\'est jamais touché', () async {
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: 'Mon exercice',
            type: ExerciseType.duration,
            primaryMuscle: Muscle.abdominals,
            secondaryMuscles: const [],
            equipment: Equipment.other,
          ),
        );
    await repository.syncCatalog([_exercise('bench', 'Développé couché')]);

    final custom = await (db.select(
      db.exercises,
    )..where((e) => e.catalogKey.isNull())).getSingle();
    expect(custom.name, 'Mon exercice');
    expect(custom.isArchived, isFalse);
  });

  test('la liste est triée sans tenir compte des accents', () async {
    await repository.syncCatalog([
      _exercise('squat', 'Squat (barre)'),
      _exercise('fly', 'Écarté couché (haltères)'),
      _exercise('bench', 'Développé couché (barre)'),
    ]);
    final names = (await repository.watchExercises().first).map((e) => e.name);
    expect(names, [
      'Développé couché (barre)',
      'Écarté couché (haltères)',
      'Squat (barre)',
    ]);
  });

  Future<int> createCustom() => repository.saveCustomExercise(
    name: '  Mon exercice ',
    type: ExerciseType.duration,
    primaryMuscle: Muscle.abdominals,
    secondaryMuscles: const [],
    equipment: Equipment.other,
  );

  test('un exercice perso se crée puis se modifie', () async {
    final id = await createCustom();
    await repository.saveCustomExercise(
      id: id,
      name: 'Gainage sur ballon',
      type: ExerciseType.duration,
      primaryMuscle: Muscle.abdominals,
      secondaryMuscles: const [Muscle.lowerBack],
      equipment: Equipment.other,
    );

    final exercise = (await repository.watchExercises().first).single;
    expect(exercise.id, id);
    expect(exercise.name, 'Gainage sur ballon');
    expect(exercise.secondaryMuscles, [Muscle.lowerBack]);
  });

  test('un exercice perso jamais utilisé est vraiment supprimé', () async {
    final id = await createCustom();
    await repository.deleteCustomExercise(id);
    expect(await db.select(db.exercises).get(), isEmpty);
  });

  test('un exercice perso utilisé dans une séance est archivé', () async {
    final id = await createCustom();
    final workoutId = await db
        .into(db.workouts)
        .insert(WorkoutsCompanion.insert(startedAt: DateTime(2026, 10, 20)));
    await db
        .into(db.workoutExercises)
        .insert(
          WorkoutExercisesCompanion.insert(
            workoutId: workoutId,
            exerciseId: id,
            position: 0,
          ),
        );
    await repository.deleteCustomExercise(id);

    expect(await repository.watchExercises().first, isEmpty);
    final row = await db.select(db.exercises).getSingle();
    expect(row.isArchived, isTrue);
  });

  test('un exercice de la bibliothèque ne peut pas être supprimé', () async {
    await repository.syncCatalog([_exercise('bench', 'Développé couché')]);
    final bench = await byKey('bench');
    await repository.deleteCustomExercise(bench.id);
    expect((await byKey('bench')).isArchived, isFalse);
  });

  test('une série supprime en cascade avec sa séance', () async {
    await repository.syncCatalog([_exercise('bench', 'Développé couché')]);
    final exercise = await byKey('bench');
    final workoutId = await db
        .into(db.workouts)
        .insert(WorkoutsCompanion.insert(startedAt: DateTime(2026, 10, 20)));
    final workoutExerciseId = await db
        .into(db.workoutExercises)
        .insert(
          WorkoutExercisesCompanion.insert(
            workoutId: workoutId,
            exerciseId: exercise.id,
            position: 0,
          ),
        );
    await db
        .into(db.workoutSets)
        .insert(
          WorkoutSetsCompanion.insert(
            workoutExerciseId: workoutExerciseId,
            position: 0,
            weightKg: const Value(60),
            reps: const Value(10),
          ),
        );

    await (db.delete(db.workouts)..where((w) => w.id.equals(workoutId))).go();
    expect(await db.select(db.workoutExercises).get(), isEmpty);
    expect(await db.select(db.workoutSets).get(), isEmpty);
  });
}
