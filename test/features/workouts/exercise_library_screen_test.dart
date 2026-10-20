import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opensport/core/database/app_database.dart';
import 'package:opensport/core/models/equipment.dart';
import 'package:opensport/core/models/exercise_type.dart';
import 'package:opensport/core/models/muscle.dart';
import 'package:opensport/features/workouts/data/workout_providers.dart';
import 'package:opensport/features/workouts/screens/exercise_library_screen.dart';

Exercise _exercise(int id, String name, Muscle muscle, Equipment equipment) =>
    Exercise(
      id: id,
      catalogKey: 'key-$id',
      name: name,
      type: ExerciseType.weightReps,
      primaryMuscle: muscle,
      secondaryMuscles: const [],
      equipment: equipment,
      isArchived: false,
    );

final _exercises = [
  _exercise(1, 'Curl haltères', Muscle.biceps, Equipment.dumbbell),
  _exercise(2, 'Développé couché (barre)', Muscle.chest, Equipment.barbell),
  _exercise(3, 'Développé couché (haltères)', Muscle.chest, Equipment.dumbbell),
  _exercise(4, 'Squat (barre)', Muscle.quadriceps, Equipment.barbell),
];

/// Ce que le sélecteur a renvoyé en se fermant.
class _Picked {
  List<Exercise>? exercises;
}

/// Ouvre le sélecteur depuis un bouton, comme le fera la séance.
Future<_Picked> _openPicker(WidgetTester tester) async {
  final picked = _Picked();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        exercisesProvider.overrideWith((ref) => Stream.value(_exercises)),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                picked.exercises = await ExerciseLibraryScreen.pick(context),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Ouvrir'));
  await tester.pumpAndSettle();
  return picked;
}

void main() {
  testWidgets('la recherche ignore les accents', (tester) async {
    await _openPicker(tester);
    expect(find.text('4 exercices'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'developpe halteres');
    await tester.pump();
    expect(find.text('1 exercice'), findsOneWidget);
    expect(find.text('Développé couché (haltères)'), findsOneWidget);
  });

  testWidgets('aucun résultat propose de créer l\'exercice', (tester) async {
    await _openPicker(tester);
    await tester.enterText(find.byType(TextField), 'tirage');
    await tester.pump();
    expect(find.text('Aucun exercice trouvé.'), findsOneWidget);
    expect(find.text('Créer «\u00A0tirage\u00A0»'), findsOneWidget);
  });

  testWidgets('le filtre de matériel ne garde que la barre', (tester) async {
    await _openPicker(tester);
    await tester.tap(find.text('Matériel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Barre').last);
    await tester.pumpAndSettle();

    expect(find.text('2 exercices'), findsOneWidget);
    expect(find.text('Curl haltères'), findsNothing);
  });

  testWidgets('le sélecteur renvoie les exercices dans l\'ordre des appuis', (
    tester,
  ) async {
    final picked = await _openPicker(tester);

    await tester.tap(find.text('Squat (barre)'));
    await tester.tap(find.text('Curl haltères'));
    await tester.pump();
    await tester.tap(find.text('Ajouter 2 exercices'));
    await tester.pumpAndSettle();

    expect(picked.exercises?.map((e) => e.name), [
      'Squat (barre)',
      'Curl haltères',
    ]);
  });
}
