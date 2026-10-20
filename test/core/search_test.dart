import 'package:flutter_test/flutter_test.dart';
import 'package:opensport/core/search.dart';

void main() {
  test('les accents et majuscules sont ignorés', () {
    expect(normalizeForSearch('Développé Couché'), 'developpe couche');
    expect(normalizeForSearch('Écarté à la poulie'), 'ecarte a la poulie');
  });

  test(
    'chaque mot de la recherche doit apparaître, dans n\'importe quel ordre',
    () {
      const name = 'Développé couché (haltères)';
      expect(matchesSearch(name, 'dev couche'), isTrue);
      expect(matchesSearch(name, 'HALTERES developpe'), isTrue);
      expect(matchesSearch(name, 'dev barre'), isFalse);
    },
  );

  test('une recherche vide trouve tout', () {
    expect(matchesSearch('Squat (barre)', ''), isTrue);
    expect(matchesSearch('Squat (barre)', '   '), isTrue);
  });
}
