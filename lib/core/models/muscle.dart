/// Groupes musculaires (repris de free-exercise-db). Le nom de chaque valeur
/// est stocké en base et dans la bibliothèque fournie : ne pas renommer une
/// valeur existante sans migration.
enum Muscle {
  chest('Pectoraux'),
  shoulders('Épaules'),
  triceps('Triceps'),
  biceps('Biceps'),
  forearms('Avant-bras'),
  lats('Grand dorsal'),
  middleBack('Milieu du dos'),
  lowerBack('Lombaires'),
  traps('Trapèzes'),
  abdominals('Abdominaux'),
  quadriceps('Quadriceps'),
  hamstrings('Ischio-jambiers'),
  glutes('Fessiers'),
  calves('Mollets'),
  adductors('Adducteurs'),
  abductors('Abducteurs'),
  neck('Cou');

  const Muscle(this.label);

  final String label;
}
