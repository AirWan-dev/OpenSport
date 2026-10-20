import 'package:opensport/core/database/app_database.dart';
import 'package:opensport/core/format.dart';
import 'package:opensport/core/models/exercise_type.dart';
import 'package:opensport/core/models/set_kind.dart';

/// Ce qu'on note pour une série : poids (ou lest), répétitions, durée.
class SetValues {
  const SetValues({this.weightKg, this.reps, this.durationSeconds});

  factory SetValues.of(WorkoutSet set) => SetValues(
    weightKg: set.weightKg,
    reps: set.reps,
    durationSeconds: set.durationSeconds,
  );

  final double? weightKg;
  final int? reps;
  final int? durationSeconds;

  bool get isEmpty =>
      weightKg == null && reps == null && durationSeconds == null;

  /// Complète les valeurs manquantes avec celles de [hint].
  SetValues fillFrom(SetValues hint) => SetValues(
    weightKg: weightKg ?? hint.weightKg,
    reps: reps ?? hint.reps,
    durationSeconds: durationSeconds ?? hint.durationSeconds,
  );

  /// Ce qui manque pour valider la série, ou null si elle est complète.
  /// Le poids peut rester vide (barre à vide, pas de lest).
  String? missingFor(ExerciseType type) => switch (type) {
    ExerciseType.duration when durationSeconds == null => 'la durée',
    ExerciseType.weightReps ||
    ExerciseType.bodyweightReps when reps == null => 'le nombre de répétitions',
    _ => null,
  };

  /// Résumé court : « 60 kg × 10 », « +10 kg × 8 », « 12 », « 1:00 ».
  String describe(ExerciseType type) {
    if (isEmpty) return '–';
    return switch (type) {
      ExerciseType.duration => formatDuration(
        Duration(seconds: durationSeconds ?? 0),
      ),
      ExerciseType.weightReps =>
        '${formatWeight(weightKg ?? 0)} kg × ${reps ?? 0}',
      ExerciseType.bodyweightReps =>
        weightKg == null || weightKg == 0
            ? '${reps ?? 0}'
            : '+${formatWeight(weightKg!)} kg × ${reps ?? 0}',
    };
  }
}

/// Un exercice de la séance, avec ses séries et celles de la dernière fois.
class SessionExercise {
  const SessionExercise({
    required this.entry,
    required this.exercise,
    required this.sets,
    required this.previous,
  });

  final WorkoutExercise entry;
  final Exercise exercise;
  final List<WorkoutSet> sets;

  /// Séries faites sur cet exercice lors de la dernière séance terminée.
  final List<WorkoutSet> previous;

  /// La même série la dernière fois : même rang parmi les séries du même
  /// type (la 2e série normale répond à la 2e série normale).
  WorkoutSet? previousFor(int index) {
    final kind = sets[index].kind;
    final rank = sets.take(index).where((s) => s.kind == kind).length;
    final same = previous.where((s) => s.kind == kind).toList();
    return rank < same.length ? same[rank] : null;
  }

  /// Valeurs proposées pour la série [index] : la même série la dernière
  /// fois, sinon la série remplie la plus proche au-dessus.
  SetValues hintFor(int index) {
    final last = previousFor(index);
    if (last != null) return SetValues.of(last);
    for (var i = index - 1; i >= 0; i--) {
      final above = SetValues.of(sets[i]);
      if (!above.isEmpty) return above;
    }
    return const SetValues();
  }

  /// Numéro affiché : 1, 2, 3… pour les séries normales, « É » pour
  /// l'échauffement.
  String labelFor(int index) {
    if (sets[index].kind == SetKind.warmup) return 'É';
    return '${sets.take(index + 1).where((s) => s.kind == SetKind.normal).length}';
  }
}

/// Une séance (en cours ou terminée) et tout son contenu.
class WorkoutSession {
  const WorkoutSession({required this.workout, required this.exercises});

  final Workout workout;
  final List<SessionExercise> exercises;

  /// Séries cochées hors échauffement.
  Iterable<WorkoutSet> get _workSets => exercises.expand(
    (e) =>
        e.sets.where((s) => s.completedAt != null && s.kind == SetKind.normal),
  );

  int get completedSets => _workSets.length;

  /// Total soulevé (poids × répétitions des séries cochées, hors
  /// échauffement), en kilos.
  double get volumeKg =>
      _workSets.fold(0, (sum, s) => sum + (s.weightKg ?? 0) * (s.reps ?? 0));
}
