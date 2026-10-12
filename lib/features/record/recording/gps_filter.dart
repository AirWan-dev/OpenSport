import 'package:latlong2/latlong.dart';
import 'package:opensport/core/models/sport.dart';

/// Une mesure brute du GPS.
class GpsSample {
  const GpsSample({
    required this.position,
    required this.accuracy,
    required this.time,
    this.altitude,
  });

  final LatLng position;

  /// Précision horizontale annoncée, en mètres.
  final double accuracy;
  final DateTime time;
  final double? altitude;
}

/// Pourquoi une mesure a été écartée (utile pour les tests et le débogage).
enum GpsRejection { inaccurate, tooClose, tooFast, outOfOrder }

/// Écarte les mesures GPS qui fausseraient la distance : trop imprécises,
/// trop proches de la précédente (bruit à l'arrêt) ou physiquement
/// impossibles pour le sport pratiqué.
class GpsFilter {
  GpsFilter({required this.sport, this.maxAccuracy = 25, this.minDistance = 3});

  final Sport sport;

  /// Au-delà, la mesure est jugée trop imprécise (mètres).
  final double maxAccuracy;

  /// En deçà, on considère qu'on n'a pas bougé (mètres).
  final double minDistance;

  static const _distance = Distance(roundResult: false);

  GpsSample? _last;

  /// Vitesse maximale crédible pour le sport, en m/s.
  double get maxSpeed => switch (sport) {
    Sport.run => 9, // ~32 km/h, au-delà d'un sprint
    Sport.ride => 25, // 90 km/h, descente rapide
    Sport.walk || Sport.hike => 4,
  };

  /// Renvoie null si la mesure est acceptée, sinon la raison du rejet.
  GpsRejection? check(GpsSample sample) {
    if (sample.accuracy > maxAccuracy) return GpsRejection.inaccurate;

    final last = _last;
    if (last == null) {
      _last = sample;
      return null;
    }

    final seconds = sample.time.difference(last.time).inMilliseconds / 1000;
    if (seconds <= 0) return GpsRejection.outOfOrder;

    final meters = _distance(last.position, sample.position);
    if (meters < minDistance) return GpsRejection.tooClose;
    if (meters / seconds > maxSpeed) return GpsRejection.tooFast;

    _last = sample;
    return null;
  }

  /// Après une pause, la prochaine mesure repart de zéro : on ne compare
  /// pas avec la position d'avant la pause.
  void reset() => _last = null;
}
