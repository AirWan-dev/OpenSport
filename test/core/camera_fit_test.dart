import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opensport/core/map/camera_fit.dart';
import 'package:opensport/features/activities/data/demo_track.dart';

void main() {
  final points = buildDemoTrack().positions;

  test('cadre une sortie de ~13 km à un zoom de ville', () {
    final fit = fitPoints(points, const Size(400, 860), EdgeInsets.zero);
    expect(fit.zoom, inInclusiveRange(12, 14));
  });

  test('plus de marge en bas décale le centre vers le sud', () {
    final centered = fitPoints(points, const Size(400, 860), EdgeInsets.zero);
    final padded = fitPoints(
      points,
      const Size(400, 860),
      const EdgeInsets.only(bottom: 300),
    );
    expect(padded.center.latitude, lessThan(centered.center.latitude));
  });
}
