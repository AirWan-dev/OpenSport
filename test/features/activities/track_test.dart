import 'package:flutter_test/flutter_test.dart';
import 'package:opensport/features/activities/data/demo_track.dart';

void main() {
  test('la sortie de démonstration a des statistiques réalistes', () {
    final track = buildDemoTrack();
    expect(track.distance, inInclusiveRange(8000, 16000));
    expect(track.averagePace, inInclusiveRange(240, 420));
    expect(track.elevationGain, greaterThan(0));
  });

  test('indexAtDistance renvoie le premier point qui atteint la distance', () {
    final track = buildDemoTrack();
    final i = track.indexAtDistance(5000);
    expect(track.cumulativeDistance[i], greaterThanOrEqualTo(5000));
    expect(track.cumulativeDistance[i - 1], lessThan(5000));
  });
}
