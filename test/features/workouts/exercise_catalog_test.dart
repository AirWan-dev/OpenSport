import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opensport/features/workouts/data/exercise_catalog.dart';

void main() {
  final catalog = parseCatalog(File(catalogAsset).readAsStringSync());

  test('la bibliothèque fournie se lit entièrement', () {
    expect(catalog.length, greaterThanOrEqualTo(150));
  });

  test('chaque clé et chaque nom sont uniques', () {
    expect(catalog.map((e) => e.key).toSet(), hasLength(catalog.length));
    expect(catalog.map((e) => e.name).toSet(), hasLength(catalog.length));
  });

  test('le muscle principal ne figure pas parmi les secondaires', () {
    for (final exercise in catalog) {
      expect(
        exercise.secondaryMuscles,
        isNot(contains(exercise.primaryMuscle)),
        reason: exercise.key,
      );
    }
  });
}
