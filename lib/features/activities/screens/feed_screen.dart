import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opensport/core/database/app_database.dart';
import 'package:opensport/core/format.dart';
import 'package:opensport/core/theme/app_theme.dart';
import 'package:opensport/core/widgets/stat_value.dart';

import '../data/activity_providers.dart';
import '../widgets/route_preview.dart';
import 'activity_detail_screen.dart';

/// Fil des activités, la plus récente en haut.
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activities = ref.watch(activitiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Fil')),
      body: activities.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erreur : $error')),
        data: (list) => list.isEmpty
            ? const Center(
                child: Text(
                  'Aucune activité pour l\'instant.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, i) => _ActivityCard(activity: list[i]),
              ),
      ),
    );
  }
}

class _ActivityCard extends ConsumerWidget {
  const _ActivityCard({required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(trackProvider(activity.id));
    final pace = activity.durationMs / 1000 / (activity.distanceM / 1000);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ActivityDetailScreen(activityId: activity.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(activity.sport.icon, color: AppColors.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${activity.sport.label} · '
                          '${formatDateTime(activity.startedAt)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: StatValue(
                      label: 'Distance',
                      value: formatKm(activity.distanceM),
                      unit: 'km',
                    ),
                  ),
                  Expanded(
                    child: StatValue(
                      label: 'Durée',
                      value: formatDuration(
                        Duration(milliseconds: activity.durationMs),
                      ),
                    ),
                  ),
                  Expanded(
                    child: StatValue(
                      label: 'Allure',
                      value: formatPace(pace),
                      unit: '/km',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 170,
                  color: AppColors.surfaceHigh,
                  child: track.whenOrNull(data: (t) => RoutePreview(track: t)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
