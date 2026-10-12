import 'package:flutter/material.dart';

/// Types d'activité GPS. Le nom de chaque valeur est stocké en base :
/// ne pas renommer une valeur existante sans migration.
enum Sport {
  run('Course à pied', 'Course', Icons.directions_run_rounded),
  ride('Vélo', 'Sortie vélo', Icons.directions_bike_rounded),
  walk('Marche', 'Marche', Icons.directions_walk_rounded),
  hike('Randonnée', 'Randonnée', Icons.hiking_rounded);

  const Sport(this.label, this.noun, this.icon);

  final String label;

  /// Nom d'une sortie, pour les titres automatiques (« Course du matin »).
  final String noun;
  final IconData icon;

  /// Titre proposé à la fin d'une sortie, selon l'heure de départ.
  String defaultTitle(DateTime start) {
    final moment = switch (start.hour) {
      < 5 => 'de nuit',
      < 11 => 'du matin',
      < 14 => 'du midi',
      < 18 => "de l'après-midi",
      < 22 => 'du soir',
      _ => 'de nuit',
    };
    return '$noun $moment';
  }
}
