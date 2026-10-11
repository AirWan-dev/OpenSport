import 'package:flutter/material.dart';

/// Types d'activité GPS. Le nom de chaque valeur est stocké en base :
/// ne pas renommer une valeur existante sans migration.
enum Sport {
  run('Course à pied', Icons.directions_run_rounded),
  ride('Vélo', Icons.directions_bike_rounded),
  walk('Marche', Icons.directions_walk_rounded),
  hike('Randonnée', Icons.hiking_rounded);

  const Sport(this.label, this.icon);

  final String label;
  final IconData icon;
}
