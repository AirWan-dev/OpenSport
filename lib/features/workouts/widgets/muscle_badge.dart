import 'package:flutter/material.dart';
import 'package:opensport/core/models/muscle.dart';

/// Couleur de chaque zone du corps, pour les pictos et les filtres.
extension MuscleRegionColor on MuscleRegion {
  Color get color => switch (this) {
    MuscleRegion.chest => const Color(0xFFEF4444),
    MuscleRegion.back => const Color(0xFF3B82F6),
    MuscleRegion.shoulders => const Color(0xFFF59E0B),
    MuscleRegion.arms => const Color(0xFFA855F7),
    MuscleRegion.core => const Color(0xFF14B8A6),
    MuscleRegion.legs => const Color(0xFF22C55E),
  };
}

/// Picto d'un exercice : l'abréviation de son muscle principal sur la couleur
/// de sa zone. Provisoire, en attendant les pictos en pixel art.
class MuscleBadge extends StatelessWidget {
  const MuscleBadge({super.key, required this.muscle, this.size = 44});

  final Muscle muscle;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = muscle.region.color;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Text(
        muscle.short,
        style: TextStyle(
          color: color,
          fontSize: size * 0.3,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
