import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opensport/core/theme/app_theme.dart';

import '../data/activity_providers.dart';
import 'activity_map_screen.dart';

/// Charge une activité depuis la base puis affiche son écran carte.
class ActivityDetailScreen extends ConsumerWidget {
  const ActivityDetailScreen({super.key, required this.activityId});

  final int activityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(trackProvider(activityId))
        .when(
          data: (track) => ActivityMapScreen(track: track),
          loading: () => const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Scaffold(
            appBar: AppBar(),
            body: Center(child: Text('Activité introuvable : $error')),
          ),
        );
  }
}
