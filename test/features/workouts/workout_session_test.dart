import 'package:flutter_test/flutter_test.dart';
import 'package:opensport/core/database/app_database.dart';
import 'package:opensport/core/format.dart';
import 'package:opensport/core/models/equipment.dart';
import 'package:opensport/core/models/exercise_type.dart';
import 'package:opensport/core/models/muscle.dart';
import 'package:opensport/core/models/set_kind.dart';
import 'package:opensport/features/workouts/models/workout_session.dart';

WorkoutSet _set(
  int position, {
  SetKind kind = SetKind.normal,
  double? kg,
  int? reps,
}) => WorkoutSet(
  id: position,
  workoutExerciseId: 1,
  position: position,
  kind: kind,
  weightKg: kg,
  reps: reps,
);

SessionExercise _exercise(List<WorkoutSet> sets, List<WorkoutSet> previous) =>
    SessionExercise(
      entry: const WorkoutExercise(
        id: 1,
        workoutId: 1,
        exerciseId: 1,
        position: 0,
        restSeconds: 90,
      ),
      exercise: const Exercise(
        id: 1,
        name: 'Développé couché (barre)',
        type: ExerciseType.weightReps,
        primaryMuscle: Muscle.chest,
        secondaryMuscles: [],
        equipment: Equipment.barbell,
        isArchived: false,
      ),
      sets: sets,
      previous: previous,
    );

void main() {
  test('la série précédente se cherche parmi les séries du même type', () {
    final exercise = _exercise(
      [_set(0, kind: SetKind.warmup), _set(1), _set(2)],
      [
        _set(0, kind: SetKind.warmup, kg: 40, reps: 12),
        _set(1, kg: 60, reps: 10),
      ],
    );
    expect(exercise.previousFor(0)?.weightKg, 40);
    expect(exercise.previousFor(1)?.reps, 10);
    expect(exercise.previousFor(2), isNull);
  });

  test('sans précédent, la proposition reprend la série remplie au-dessus', () {
    final exercise = _exercise([
      _set(0, kg: 70, reps: 6),
      _set(1),
      _set(2),
    ], []);
    expect(exercise.hintFor(2).weightKg, 70);
    expect(exercise.hintFor(2).reps, 6);
    expect(exercise.hintFor(0).isEmpty, isTrue);
  });

  test('les séries normales sont numérotées, l\'échauffement est marqué É', () {
    final exercise = _exercise([
      _set(0, kind: SetKind.warmup),
      _set(1),
      _set(2, kind: SetKind.warmup),
      _set(3),
    ], []);
    expect(
      [for (var i = 0; i < 4; i++) exercise.labelFor(i)],
      ['É', '1', 'É', '2'],
    );
  });

  test('une série vide se complète avec la proposition', () {
    const typed = SetValues(reps: 8);
    final filled = typed.fillFrom(const SetValues(weightKg: 60, reps: 10));
    expect(filled.weightKg, 60);
    expect(filled.reps, 8);
    expect(filled.missingFor(ExerciseType.weightReps), isNull);
    expect(
      const SetValues(weightKg: 60).missingFor(ExerciseType.weightReps),
      'le nombre de répétitions',
    );
    expect(const SetValues().missingFor(ExerciseType.duration), 'la durée');
  });

  test('mise en forme des séries et des poids', () {
    expect(
      const SetValues(
        weightKg: 62.5,
        reps: 8,
      ).describe(ExerciseType.weightReps),
      '62,5 kg × 8',
    );
    expect(
      const SetValues(reps: 12).describe(ExerciseType.bodyweightReps),
      '12',
    );
    expect(
      const SetValues(
        weightKg: 10,
        reps: 8,
      ).describe(ExerciseType.bodyweightReps),
      '+10 kg × 8',
    );
    expect(
      const SetValues(durationSeconds: 75).describe(ExerciseType.duration),
      '01:15',
    );
    expect(parseWeight('62,5'), 62.5);
    expect(parseWeight(''), isNull);
    expect(formatThousands(12340), '12\u202F340');
  });
}
