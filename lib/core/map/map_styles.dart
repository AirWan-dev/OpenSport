import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _openFreeMapFonts =
    'https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf';

/// Fonds de carte MapLibre : gratuits, sans clé d'API.
enum MapStyle {
  dark(label: 'Sombre', icon: Icons.dark_mode_rounded),
  light(label: 'Plan', icon: Icons.map_rounded),
  satellite(label: 'Satellite', icon: Icons.satellite_alt_rounded);

  const MapStyle({required this.label, required this.icon});

  final String label;
  final IconData icon;

  /// Style au format MapLibre : JSON brut ou adresse d'un style en ligne.
  Future<String> load() async => switch (this) {
    MapStyle.dark => _darkStyle(),
    MapStyle.light => 'https://tiles.openfreemap.org/styles/liberty',
    MapStyle.satellite => jsonEncode(_satelliteStyle),
  };
}

/// Style sombre fait maison, enrichi des bâtiments en relief.
Future<String> _darkStyle() async {
  final style = jsonDecode(
    await rootBundle.loadString('assets/map/opensport_dark.json'),
  ) as Map<String, dynamic>;
  final layers = style['layers'] as List;
  final index = layers.indexWhere((l) => l['id'] == 'building');
  layers.insert(index + 1, {
    'id': 'building-3d',
    'type': 'fill-extrusion',
    'source': 'openmaptiles',
    'source-layer': 'building',
    'minzoom': 14,
    'paint': {
      'fill-extrusion-color': '#1A2029',
      'fill-extrusion-height': ['get', 'render_height'],
      'fill-extrusion-base': ['get', 'render_min_height'],
      'fill-extrusion-opacity': 0.85,
    },
  });
  return jsonEncode(style);
}

/// Imagerie satellite Esri. Les polices servent aux bornes kilométriques.
const _satelliteStyle = {
  'version': 8,
  'glyphs': _openFreeMapFonts,
  'sources': {
    'esri': {
      'type': 'raster',
      'tiles': [
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      ],
      'tileSize': 256,
      'maxzoom': 19,
      'attribution': '© Esri, Maxar, Earthstar Geographics',
    },
  },
  'layers': [
    {'id': 'satellite', 'type': 'raster', 'source': 'esri'},
  ],
};
