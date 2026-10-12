import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:opensport/core/models/sport.dart';
import 'package:opensport/features/record/recording/gps_filter.dart';

void main() {
  const start = LatLng(48.8625, 2.2510);
  const distance = Distance(roundResult: false);
  final t0 = DateTime(2026, 10, 11, 8);

  GpsSample at(double metersNorth, int seconds, {double accuracy = 5}) =>
      GpsSample(
        position: distance.offset(start, metersNorth, 0),
        accuracy: accuracy,
        time: t0.add(Duration(seconds: seconds)),
      );

  test('accepte une course normale', () {
    final filter = GpsFilter(sport: Sport.run);
    expect(filter.check(at(0, 0)), isNull);
    expect(filter.check(at(3.5, 1)), isNull);
    expect(filter.check(at(7, 2)), isNull);
  });

  test('écarte une mesure trop imprécise', () {
    final filter = GpsFilter(sport: Sport.run);
    expect(filter.check(at(0, 0, accuracy: 60)), GpsRejection.inaccurate);
  });

  test('écarte le bruit à l\'arrêt', () {
    final filter = GpsFilter(sport: Sport.run);
    filter.check(at(0, 0));
    expect(filter.check(at(1, 1)), GpsRejection.tooClose);
  });

  test('écarte un saut impossible à pied, mais pas à vélo', () {
    final run = GpsFilter(sport: Sport.run)..check(at(0, 0));
    expect(run.check(at(60, 2)), GpsRejection.tooFast);

    final ride = GpsFilter(sport: Sport.ride)..check(at(0, 0));
    expect(ride.check(at(30, 2)), isNull);
  });

  test('après une pause, la position précédente est oubliée', () {
    final filter = GpsFilter(sport: Sport.run)..check(at(0, 0));
    filter.reset();
    // 500 m en 2 s serait rejeté sans la remise à zéro.
    expect(filter.check(at(500, 2)), isNull);
  });
}
