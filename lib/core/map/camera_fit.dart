import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';

/// Taille d'une tuile MapLibre au zoom 0, en pixels logiques.
const _tileSize = 512.0;

double _x(double lng) => (lng + 180) / 360;

double _y(double lat) {
  final s = math.sin(lat * math.pi / 180);
  return 0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi);
}

double _lng(double x) => x * 360 - 180;

double _lat(double y) =>
    90 - 360 * math.atan(math.exp((y - 0.5) * 2 * math.pi)) / math.pi;

/// Centre et zoom pour faire tenir [points] dans la zone de [viewport]
/// laissée libre par [padding], en vue de dessus.
///
/// Calculé ici plutôt que par MapLibre : le résultat est identique sur
/// Android, iOS et le web, et ne dépend pas de l'inclinaison en cours.
({LatLng center, double zoom}) fitPoints(
  List<LatLng> points,
  Size viewport,
  EdgeInsets padding, {
  double maxZoom = 17,
}) {
  final xs = points.map((p) => _x(p.longitude));
  final ys = points.map((p) => _y(p.latitude));
  final minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
  final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);

  final width = math.max(viewport.width - padding.horizontal, 1.0);
  final height = math.max(viewport.height - padding.vertical, 1.0);
  final zoom = math
      .min(
        math.log(width / (math.max(maxX - minX, 1e-9) * _tileSize)) / math.ln2,
        math.log(height / (math.max(maxY - minY, 1e-9) * _tileSize)) / math.ln2,
      )
      .clamp(1.0, maxZoom);

  // Le tracé doit être centré dans la zone libre, pas dans tout l'écran.
  final scale = _tileSize * math.pow(2, zoom);
  final dx = padding.left + width / 2 - viewport.width / 2;
  final dy = padding.top + height / 2 - viewport.height / 2;
  final cx = (minX + maxX) / 2 - dx / scale;
  final cy = (minY + maxY) / 2 - dy / scale;

  return (center: LatLng(_lat(cy), _lng(cx)), zoom: zoom);
}
