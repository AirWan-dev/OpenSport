import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:opensport/core/models/sport.dart';

import '../models/track.dart';

/// Génère une sortie de course réaliste (~10 km) autour du Bois de Boulogne,
/// en attendant les vraies données GPS du téléphone.
Track buildDemoTrack() {
  final rnd = math.Random(7);
  const center = LatLng(48.8625, 2.2510);
  const distance = Distance();
  const count = 700;

  final points = <TrackPoint>[];
  var elapsedMs = 0.0;
  LatLng? previous;
  double? previousElevation;

  for (var i = 0; i <= count; i++) {
    final theta = 2 * math.pi * i / count;

    // Boucle organique : un cercle déformé par plusieurs harmoniques.
    final radius =
        1450 +
        320 * math.sin(3 * theta + 0.6) +
        170 * math.sin(5 * theta + 1.3) +
        70 * math.sin(11 * theta) +
        rnd.nextDouble() * 6;
    final bearing = (theta * 180 / math.pi + 360) % 360;
    final stretched = radius * (1 + 0.25 * math.cos(theta).abs());
    final position = distance.offset(center, stretched, bearing);

    final elevation =
        38 +
        16 * math.sin(2 * theta + 1) +
        6 * math.sin(7 * theta) +
        rnd.nextDouble() * 0.6;

    if (previous != null) {
      final d = distance(previous, position);
      final slope = (elevation - previousElevation!) / math.max(d, 1);
      // Allure de base ~5'10"/km, ralentit en montée, accélère en fin de sortie.
      final speed =
          (3.2 +
                  0.35 * math.sin(4 * theta) +
                  (i > count * 0.82 ? 0.55 : 0) -
                  slope * 9 +
                  (rnd.nextDouble() - 0.5) * 0.25)
              .clamp(2.3, 4.6);
      elapsedMs += d / speed * 1000;
    }

    points.add(
      TrackPoint(
        position,
        elevation,
        Duration(milliseconds: elapsedMs.round()),
      ),
    );
    previous = position;
    previousElevation = elevation;
  }

  return Track(
    name: 'Sortie de démonstration',
    sport: Sport.run,
    startedAt: DateTime(2026, 10, 11, 8, 42),
    points: points,
  );
}
