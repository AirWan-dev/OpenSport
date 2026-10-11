import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:opensport/core/models/sport.dart';

/// Un point GPS enregistré pendant une activité.
class TrackPoint {
  final LatLng position;

  /// Altitude en mètres.
  final double elevation;

  /// Temps écoulé depuis le début de l'activité.
  final Duration elapsed;

  const TrackPoint(this.position, this.elevation, this.elapsed);
}

/// Une activité GPS (course, vélo...) avec ses statistiques dérivées.
class Track {
  final String name;
  final Sport sport;
  final DateTime startedAt;
  final List<TrackPoint> points;

  /// Distance cumulée (m) à chaque point.
  final List<double> cumulativeDistance;

  /// Vitesse lissée (m/s) à chaque point.
  final List<double> speeds;

  /// Identifiant en base, nul pour une trace pas encore enregistrée.
  final int? id;

  Track._(
    this.id,
    this.name,
    this.sport,
    this.startedAt,
    this.points,
    this.cumulativeDistance,
    this.speeds,
  );

  factory Track({
    int? id,
    required String name,
    required Sport sport,
    required DateTime startedAt,
    required List<TrackPoint> points,
  }) {
    const distance = Distance(roundResult: false);
    final cumulative = <double>[0];
    final raw = <double>[0];
    for (var i = 1; i < points.length; i++) {
      final d = distance(points[i - 1].position, points[i].position);
      cumulative.add(cumulative.last + d);
      final dt =
          (points[i].elapsed - points[i - 1].elapsed).inMilliseconds / 1000;
      raw.add(dt > 0 ? d / dt : raw.last);
    }
    if (raw.length > 1) raw[0] = raw[1];

    // Moyenne glissante pour éviter le bruit GPS.
    const window = 4;
    final smoothed = List<double>.generate(raw.length, (i) {
      final from = math.max(0, i - window);
      final to = math.min(raw.length - 1, i + window);
      var sum = 0.0;
      for (var j = from; j <= to; j++) {
        sum += raw[j];
      }
      return sum / (to - from + 1);
    });

    return Track._(id, name, sport, startedAt, points, cumulative, smoothed);
  }

  List<LatLng> get positions => [for (final p in points) p.position];

  /// Distance totale en mètres.
  double get distance => cumulativeDistance.last;

  Duration get duration => points.last.elapsed;

  /// Allure moyenne en secondes par kilomètre.
  double get averagePace => duration.inSeconds / (distance / 1000);

  double get elevationGain {
    var gain = 0.0;
    for (var i = 1; i < points.length; i++) {
      final delta = points[i].elevation - points[i - 1].elevation;
      if (delta > 0) gain += delta;
    }
    return gain;
  }

  double get minElevation => points.map((p) => p.elevation).reduce(math.min);
  double get maxElevation => points.map((p) => p.elevation).reduce(math.max);

  /// Vitesse au percentile [p] (0..1), utile pour étalonner les couleurs.
  double speedPercentile(double p) {
    final sorted = [...speeds]..sort();
    return sorted[((sorted.length - 1) * p).round()];
  }

  /// Indice du premier point atteignant la distance [meters].
  int indexAtDistance(double meters) {
    var lo = 0, hi = cumulativeDistance.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (cumulativeDistance[mid] < meters) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// Cap (en degrés) au point [i], calculé un peu en avant pour être stable.
  double bearingAt(int i, {int lookAhead = 6}) {
    final a = points[math.max(0, i - lookAhead)].position;
    final b = points[math.min(points.length - 1, i + lookAhead)].position;
    return const Distance().bearing(a, b);
  }
}
