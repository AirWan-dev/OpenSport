import 'package:opensport/core/database/app_database.dart';
import 'package:opensport/core/models/equipment.dart';
import 'package:opensport/core/models/muscle.dart';
import 'package:opensport/core/search.dart';

/// Recherche et filtres de la bibliothèque d'exercices.
class ExerciseFilter {
  const ExerciseFilter({this.query = '', this.muscle, this.equipment});

  final String query;

  /// Muscle principal recherché, ou null pour tous.
  final Muscle? muscle;

  /// Matériel recherché, ou null pour tous.
  final Equipment? equipment;

  /// La recherche porte sur le nom, le muscle principal et le matériel :
  /// « pec haltères » trouve les exercices de pectoraux aux haltères.
  bool matches(Exercise exercise) {
    if (muscle != null && exercise.primaryMuscle != muscle) return false;
    if (equipment != null && exercise.equipment != equipment) return false;
    final text =
        '${exercise.name} ${exercise.primaryMuscle.label} '
        '${exercise.equipment.label}';
    return matchesSearch(text, query);
  }

  List<Exercise> apply(List<Exercise> exercises) =>
      exercises.where(matches).toList();
}
