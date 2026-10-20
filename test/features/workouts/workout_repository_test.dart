import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opensport/core/database/app_database.dart';
import 'package:opensport/core/models/equipment.dart';
import 'package:opensport/core/models/exercise_type.dart';
import 'package:opensport/core/models/muscle.dart';
import 'package:opensport/core/models/set_kind.dart';
import 'package:opensport/features/workouts/data/exercise_catalog.dart';
import 'package:opensport/features/workouts/data/exercise_repository.dart';
import 'package:opensport/features/workouts/data/workout_repository.dart';
import 'package:opensport/features/workouts/models/workout_session.dart';

void main() {
  late AppDatabase db;
  late WorkoutRepository workouts;
  late Exercise bench;
  late Exercise squat;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    workouts = WorkoutRepository(db);
    final exercises = ExerciseRepository(db);
    await exercises.syncCatalog([
      for (final (key, name) in [
        ('bench', 'Développé couché (barre)'),
        ('squat', 'Squat (barre)'),
      ])
        CatalogExercise(
          key: key,
          name: name,
          type: ExerciseType.weightReps,
          primaryMuscle: Muscle.chest,
          secondaryMuscles: const [],
          equipment: Equipment.barbell,
        ),
    ]);
    final all = await exercises.watchExercises().first;
    bench = all.firstWhere((e) => e.catalogKey == 'bench');
    squat = all.firstWhere((e) => e.catalogKey == 'squat');
  });

  tearDown(() => db.close());

  Future<WorkoutSession> session(int id) async =>
      (await workouts.loadSession(id))!;

  /// Une séance terminée de développé couché : échauffement 40×12, puis
  /// 60×10 et 60×8.
  Future<int> pastBenchWorkout() async {
    final id = await workouts.startWorkout(at: DateTime(2026, 10, 18, 18));
    await workouts.addExercises(id, [bench]);
    var entry = (await session(id)).exercises.single;
    await workouts.addSet(entry.entry);
    await workouts.addSet(entry.entry);
    entry = (await session(id)).exercises.single;
    await workouts.setKind(entry.sets[0], SetKind.warmup);
    const values = [
      SetValues(weightKg: 40, reps: 12),
      SetValues(weightKg: 60, reps: 10),
      SetValues(weightKg: 60, reps: 8),
    ];
    for (final (i, set) in entry.sets.indexed) {
      await workouts.setCompleted(set, done: true, values: values[i]);
    }
    await workouts.finishWorkout(id, at: DateTime(2026, 10, 18, 19));
    return id;
  }

  test('une seule séance en cours à la fois', () async {
    final first = await workouts.startWorkout();
    final second = await workouts.startWorkout();
    expect(second, first);
    expect((await workouts.watchActiveWorkout().first)?.id, first);

    await workouts.finishWorkout(first);
    expect(await workouts.watchActiveWorkout().first, isNull);
  });

  test(
    'un exercice déjà fait reprend le nombre et le type de séries',
    () async {
      await pastBenchWorkout();
      final id = await workouts.startWorkout();
      await workouts.addExercises(id, [bench, squat]);

      final current = await session(id);
      final benchNow = current.exercises[0];
      expect(benchNow.sets.map((s) => s.kind), [
        SetKind.warmup,
        SetKind.normal,
        SetKind.normal,
      ]);
      expect(benchNow.previous, hasLength(3));
      expect(
        benchNow.hintFor(2).describe(ExerciseType.weightReps),
        '60 kg × 8',
      );

      final squatNow = current.exercises[1];
      expect(squatNow.sets, hasLength(1));
      expect(squatNow.previous, isEmpty);
    },
  );

  test('la séance en cours n\'est pas sa propre « dernière fois »', () async {
    final id = await workouts.startWorkout();
    await workouts.addExercises(id, [bench]);
    final set = (await session(id)).exercises.single.sets.single;
    await workouts.setCompleted(
      set,
      done: true,
      values: const SetValues(weightKg: 50, reps: 10),
    );
    expect((await session(id)).exercises.single.previous, isEmpty);
  });

  test(
    'terminer retire les séries non cochées et les exercices vides',
    () async {
      final id = await workouts.startWorkout();
      await workouts.addExercises(id, [bench, squat]);
      final benchEntry = (await session(id)).exercises.first;
      await workouts.addSet(benchEntry.entry);
      final sets = (await session(id)).exercises.first.sets;
      await workouts.setCompleted(
        sets.first,
        done: true,
        values: const SetValues(weightKg: 60, reps: 10),
      );

      await workouts.finishWorkout(id);
      final done = await session(id);
      expect(done.workout.endedAt, isNotNull);
      expect(done.exercises.single.exercise.id, bench.id);
      expect(done.exercises.single.sets, hasLength(1));
      expect(done.exercises.single.entry.position, 0);
    },
  );

  test(
    'volume et séries ne comptent que les séries cochées hors échauffement',
    () async {
      final id = await pastBenchWorkout();
      final done = await session(id);
      expect(done.completedSets, 2);
      expect(done.volumeKg, 60 * 10 + 60 * 8);
    },
  );

  test('déplacer et retirer un exercice garde un ordre continu', () async {
    final id = await workouts.startWorkout();
    await workouts.addExercises(id, [bench, squat]);
    var entries = (await session(id)).exercises;

    await workouts.moveExercise(entries[1].entry, -1);
    entries = (await session(id)).exercises;
    expect(entries.map((e) => e.exercise.id), [squat.id, bench.id]);

    await workouts.removeExercise(entries[0].entry);
    entries = (await session(id)).exercises;
    expect(entries.single.exercise.id, bench.id);
    expect(entries.single.entry.position, 0);
  });

  test('supprimer une série renumérote les suivantes', () async {
    final id = await workouts.startWorkout();
    await workouts.addExercises(id, [bench]);
    var entry = (await session(id)).exercises.single;
    await workouts.addSet(entry.entry);
    await workouts.addSet(entry.entry);
    entry = (await session(id)).exercises.single;

    await workouts.deleteSet(entry.sets[0]);
    entry = (await session(id)).exercises.single;
    expect(entry.sets.map((s) => s.position), [0, 1]);
  });

  test('abandonner supprime la séance et son contenu', () async {
    final id = await workouts.startWorkout();
    await workouts.addExercises(id, [bench]);
    await workouts.discardWorkout(id);

    expect(await workouts.loadSession(id), isNull);
    expect(await db.select(db.workoutSets).get(), isEmpty);
  });
}
