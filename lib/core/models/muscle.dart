/// Grandes zones du corps, pour regrouper et colorer les muscles.
enum MuscleRegion {
  chest('Pectoraux'),
  back('Dos'),
  shoulders('Épaules'),
  arms('Bras'),
  core('Abdos'),
  legs('Jambes');

  const MuscleRegion(this.label);

  final String label;
}

/// Groupes musculaires (repris de free-exercise-db). Le nom de chaque valeur
/// est stocké en base et dans la bibliothèque fournie : ne pas renommer une
/// valeur existante sans migration.
enum Muscle {
  chest('Pectoraux', 'PEC', MuscleRegion.chest),
  shoulders('Épaules', 'ÉPA', MuscleRegion.shoulders),
  triceps('Triceps', 'TRI', MuscleRegion.arms),
  biceps('Biceps', 'BIC', MuscleRegion.arms),
  forearms('Avant-bras', 'AVB', MuscleRegion.arms),
  lats('Grand dorsal', 'DOR', MuscleRegion.back),
  middleBack('Milieu du dos', 'DOS', MuscleRegion.back),
  lowerBack('Lombaires', 'LOM', MuscleRegion.back),
  traps('Trapèzes', 'TRA', MuscleRegion.back),
  abdominals('Abdominaux', 'ABS', MuscleRegion.core),
  quadriceps('Quadriceps', 'QUA', MuscleRegion.legs),
  hamstrings('Ischio-jambiers', 'ISC', MuscleRegion.legs),
  glutes('Fessiers', 'FES', MuscleRegion.legs),
  calves('Mollets', 'MOL', MuscleRegion.legs),
  adductors('Adducteurs', 'ADD', MuscleRegion.legs),
  abductors('Abducteurs', 'ABD', MuscleRegion.legs),
  neck('Cou', 'COU', MuscleRegion.shoulders);

  const Muscle(this.label, this.short, this.region);

  final String label;

  /// Abréviation de trois lettres affichée dans le picto.
  final String short;
  final MuscleRegion region;
}
