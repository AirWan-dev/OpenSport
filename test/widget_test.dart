import 'package:flutter_test/flutter_test.dart';
import 'package:opensport/data/demo_track.dart';

void main() {
  test('la sortie de démo fait environ 10 km', () {
    final track = buildDemoTrack();
    expect(track.distance, inInclusiveRange(8000, 14000));
    expect(track.averagePace, inInclusiveRange(240, 420));
  });
}
