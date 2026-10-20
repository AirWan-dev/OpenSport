/// Mise en forme des valeurs affichées (en français).
library;

const _months = [
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

/// Allure en minutes'secondes" à partir de secondes par kilomètre.
String formatPace(double secondsPerKm) {
  if (!secondsPerKm.isFinite || secondsPerKm <= 0) return '–';
  final s = secondsPerKm.round();
  return "${s ~/ 60}'${(s % 60).toString().padLeft(2, '0')}\"";
}

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// Distance en kilomètres avec deux décimales, sans l'unité.
String formatKm(double meters) => (meters / 1000).toStringAsFixed(2);

/// « 11 oct. · 8h42 »
String formatDateTime(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} · '
    '${date.hour}h${date.minute.toString().padLeft(2, '0')}';

/// Poids en kilos sans zéro inutile, virgule décimale : « 60 », « 62,5 ».
String formatWeight(double kg) {
  final rounded = (kg * 100).round() / 100;
  final text = rounded == rounded.roundToDouble()
      ? rounded.toInt().toString()
      : rounded.toString();
  return text.replaceAll('.', ',');
}

/// Lit un poids saisi avec une virgule ou un point ; null si vide ou invalide.
double? parseWeight(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));

/// Nombre entier avec une espace fine entre les milliers : « 12 340 ».
String formatThousands(num value) {
  final digits = value.round().abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('\u202F');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
