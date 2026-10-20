import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opensport/core/theme/app_theme.dart';
import 'package:opensport/core/widgets/coming_soon.dart';

import 'data/workout_providers.dart';
import 'screens/exercise_library_screen.dart';
import 'screens/workout_screen.dart';

/// Séances de musculation (étape 2 de la feuille de route).
class WorkoutsScreen extends ConsumerWidget {
  const WorkoutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(exercisesProvider).value?.length;
    final active = ref.watch(activeWorkoutProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Muscu')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(
              active == null
                  ? 'Démarrer une séance'
                  : 'Reprendre la séance en cours',
            ),
            onPressed: () async {
              final id =
                  active?.id ??
                  await ref.read(workoutRepositoryProvider).startWorkout();
              if (context.mounted) await WorkoutScreen.open(context, id);
            },
          ),
          const SizedBox(height: 16),
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ExerciseLibraryScreen(),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Exercices',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            count == null
                                ? 'Bibliothèque et exercices perso'
                                : '$count exercices',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const ComingSoon(
            icon: Icons.timer_outlined,
            title: 'Bientôt',
            message:
                'Minuteur de repos, routines à lancer en un appui, '
                'historique des séances et records personnels.',
            step: 'Étape 2 · Musculation',
          ),
        ],
      ),
    );
  }
}
