import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opensport/core/format.dart';
import 'package:opensport/core/theme/app_theme.dart';
import 'package:opensport/core/widgets/stat_value.dart';
import 'package:opensport/features/activities/data/activity_providers.dart';

/// Profil : totaux, données personnelles et informations sur l'application.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activities = ref.watch(activitiesProvider).value ?? const [];
    final distance = activities.fold<double>(0, (sum, a) => sum + a.distanceM);
    final duration = activities.fold<int>(0, (sum, a) => sum + a.durationMs);

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _Section(
            title: 'Totaux',
            child: Row(
              children: [
                Expanded(
                  child: StatValue(
                    label: 'Activités',
                    value: '${activities.length}',
                  ),
                ),
                Expanded(
                  child: StatValue(
                    label: 'Distance',
                    value: formatKm(distance),
                    unit: 'km',
                  ),
                ),
                Expanded(
                  child: StatValue(
                    label: 'Temps',
                    value: formatDuration(Duration(milliseconds: duration)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _Section(
            title: 'Vos données',
            child: _InfoRow(
              icon: Icons.lock_outline_rounded,
              text:
                  'Tout est enregistré uniquement sur ce téléphone. '
                  'Pas de compte, pas de serveur, rien n\'est envoyé.',
            ),
          ),
          const SizedBox(height: 14),
          const _Section(
            title: 'À propos',
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.favorite_border_rounded,
                  text: 'OpenSport est libre et gratuit, pour toujours.',
                ),
                SizedBox(height: 12),
                _InfoRow(icon: Icons.gavel_rounded, text: 'Licence GPL-3.0'),
                SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.code_rounded,
                  text: 'Code source : github.com/AirWan-dev/OpenSport',
                ),
                SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.map_outlined,
                  text:
                      'Cartes © OpenFreeMap, © OpenMapTiles, © contributeurs '
                      'OpenStreetMap ; imagerie satellite © Esri',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.textMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppColors.textMuted, height: 1.35),
          ),
        ),
      ],
    );
  }
}
