import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opensport/core/theme/app_theme.dart';

import '../data/workout_providers.dart';
import '../screens/workout_screen.dart';
import 'elapsed_time.dart';

/// Bandeau « Séance en cours » au-dessus des onglets, pour revenir à la
/// séance depuis n'importe où (y compris après avoir fermé l'app).
class ActiveWorkoutBanner extends ConsumerWidget {
  const ActiveWorkoutBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workout = ref.watch(activeWorkoutProvider).value;
    if (workout == null) return const SizedBox.shrink();

    return Material(
      color: AppColors.surfaceHigh,
      child: InkWell(
        onTap: () => WorkoutScreen.open(context, workout.id),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.accent, width: 2)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(
                Icons.fitness_center_rounded,
                size: 20,
                color: AppColors.accent,
              ),
              const SizedBox(width: 10),
              const Text(
                'Séance en cours',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              ElapsedTime(
                since: workout.startedAt,
                builder: (elapsed) => Text(
                  elapsed,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const Spacer(),
              const Text(
                'Reprendre',
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}
