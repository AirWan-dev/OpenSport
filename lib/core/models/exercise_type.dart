/// Ce qu'on note pour chaque série d'un exercice. Le nom de chaque valeur est
/// stocké en base et dans la bibliothèque fournie.
enum ExerciseType {
  /// Poids × répétitions : développé couché, curl...
  weightReps('Poids et répétitions'),

  /// Répétitions au poids du corps, avec un lest facultatif : tractions, dips...
  bodyweightReps('Poids du corps'),

  /// Temps de maintien : gainage...
  duration('Durée');

  const ExerciseType(this.label);

  final String label;
}
