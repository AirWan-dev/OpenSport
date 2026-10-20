const _accents = {
  'à': 'a',
  'â': 'a',
  'ä': 'a',
  'á': 'a',
  'ç': 'c',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'î': 'i',
  'ï': 'i',
  'í': 'i',
  'ô': 'o',
  'ö': 'o',
  'ó': 'o',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ú': 'u',
  'ÿ': 'y',
  'œ': 'oe',
  'æ': 'ae',
};

/// Texte simplifié pour comparer ou trier : minuscules, sans accents.
/// « Développé Couché » devient « developpe couche ».
String normalizeForSearch(String text) {
  final buffer = StringBuffer();
  for (final char in text.toLowerCase().split('')) {
    buffer.write(_accents[char] ?? char);
  }
  return buffer.toString();
}

/// Vrai si chaque mot de [query] apparaît dans [text], sans tenir compte des
/// accents ni des majuscules : « dev couche » trouve « Développé couché ».
bool matchesSearch(String text, String query) {
  final haystack = normalizeForSearch(text);
  return normalizeForSearch(query)
      .split(' ')
      .where((word) => word.isNotEmpty)
      .every(haystack.contains);
}
