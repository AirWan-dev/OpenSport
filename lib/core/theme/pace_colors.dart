import 'package:flutter/material.dart';

/// Palette lent → rapide utilisée sur la carte et le profil d'altitude.
const paceStops = <Color>[
  Color(0xFF3B82F6), // lent
  Color(0xFF06B6D4),
  Color(0xFF22C55E),
  Color(0xFFFACC15),
  Color(0xFFF97316),
  Color(0xFFEF4444), // rapide
];

/// Couleur associée à [speed] (m/s), étalonnée entre [slow] et [fast].
Color paceColor(double speed, double slow, double fast) {
  final t = ((speed - slow) / (fast - slow)).clamp(0.0, 1.0);
  final scaled = t * (paceStops.length - 1);
  final i = scaled.floor().clamp(0, paceStops.length - 2);
  return Color.lerp(paceStops[i], paceStops[i + 1], scaled - i)!;
}
