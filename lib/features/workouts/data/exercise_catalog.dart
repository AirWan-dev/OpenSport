import 'dart:convert';

import 'package:opensport/core/models/equipment.dart';
import 'package:opensport/core/models/exercise_type.dart';
import 'package:opensport/core/models/muscle.dart';

/// Bibliothèque d'exercices fournie avec l'app.
const catalogAsset = 'assets/exercises/catalog.json';

/// Un exercice de la bibliothèque fournie, tel qu'écrit dans [catalogAsset].
class CatalogExercise {
  const CatalogExercise({
    required this.key,
    required this.name,
    required this.type,
    required this.primaryMuscle,
    required this.secondaryMuscles,
    required this.equipment,
  });

  factory CatalogExercise.fromJson(Map<String, dynamic> json) {
    return CatalogExercise(
      key: json['key'] as String,
      name: json['name'] as String,
      type: ExerciseType.values.byName(json['type'] as String),
      primaryMuscle: Muscle.values.byName(json['primaryMuscle'] as String),
      secondaryMuscles: [
        for (final name in json['secondaryMuscles'] as List)
          Muscle.values.byName(name as String),
      ],
      equipment: Equipment.values.byName(json['equipment'] as String),
    );
  }

  /// Identifiant stable : il relie l'historique, ne jamais le changer.
  final String key;
  final String name;
  final ExerciseType type;
  final Muscle primaryMuscle;
  final List<Muscle> secondaryMuscles;
  final Equipment equipment;
}

/// Lit le contenu de [catalogAsset].
List<CatalogExercise> parseCatalog(String source) {
  final json = jsonDecode(source) as Map<String, dynamic>;
  return [
    for (final exercise in json['exercises'] as List)
      CatalogExercise.fromJson(exercise as Map<String, dynamic>),
  ];
}
