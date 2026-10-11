import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Fonds de carte gratuits, sans clé d'API.
enum MapStyle {
  dark(
    label: 'Sombre',
    icon: Icons.dark_mode_rounded,
    url: _osm,
    attribution: '© OpenStreetMap',
    filter: _nightFilter,
  ),
  light(
    label: 'Plan',
    icon: Icons.map_rounded,
    url: _osm,
    attribution: '© OpenStreetMap',
  ),
  satellite(
    label: 'Satellite',
    icon: Icons.satellite_alt_rounded,
    url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    attribution: '© Esri, Maxar, Earthstar Geographics',
  );

  const MapStyle({
    required this.label,
    required this.icon,
    required this.url,
    required this.attribution,
    this.filter,
  });

  final String label;
  final IconData icon;
  final String url;
  final String attribution;

  /// Filtre appliqué aux tuiles (ex. mode nuit), ou null.
  final ColorFilter? filter;

  /// Habille chaque tuile avec [filter] quand il y en a un.
  TileBuilder? get tileBuilder => filter == null
      ? null
      : (context, tile, _) => ColorFiltered(colorFilter: filter!, child: tile);
}

// Tuiles OSM : pratiques pour prototyper, mais à remplacer par des tuiles
// vectorielles auto-hébergées avant une mise en production.
const _osm = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

// Inversion + rotation de teinte 180° + assombrissement : les fonds clairs
// deviennent sombres tout en gardant l'eau bleue et la végétation verte.
const _nightFilter = ColorFilter.matrix(<double>[
  0.488, -1.216, -0.122, 0, 228, //
  -0.362, -0.366, -0.122, 0, 232, //
  -0.362, -1.216, 0.728, 0, 240, //
  0, 0, 0, 1, 0,
]);
