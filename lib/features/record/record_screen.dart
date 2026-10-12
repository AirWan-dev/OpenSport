import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:opensport/core/database/app_database.dart';
import 'package:opensport/core/format.dart';
import 'package:opensport/core/models/sport.dart';
import 'package:opensport/core/theme/app_theme.dart';
import 'package:opensport/core/widgets/glass.dart';
import 'package:opensport/core/widgets/stat_value.dart';
import 'package:opensport/features/activities/data/activity_providers.dart';

import 'record_summary_screen.dart';
import 'recording/gps_access.dart';
import 'recording/recording_controller.dart';
import 'widgets/live_record_map.dart';

/// Onglet « Enregistrer » : préparation, compte à rebours, puis suivi en
/// direct d'une sortie GPS.
class RecordScreen extends ConsumerWidget {
  const RecordScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(recordingProvider.select((s) => s.phase));
    return switch (phase) {
      RecordingPhase.idle => const _ReadyView(),
      RecordingPhase.countdown => const _CountdownView(),
      RecordingPhase.recording || RecordingPhase.paused => const _LiveView(),
    };
  }
}

// ------------------------------------------------------------ Préparation

class _ReadyView extends ConsumerWidget {
  const _ReadyView();

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    var access = await checkGpsAccess();
    if (!context.mounted) return;

    if (access == GpsAccess.needsRequest) {
      final ok = await _explainGps(context);
      if (ok != true) return;
      access = await requestGpsAccess();
      if (!context.mounted) return;
    }

    switch (access) {
      case GpsAccess.granted:
        HapticFeedback.mediumImpact();
        ref.read(recordingProvider.notifier).start();
      case GpsAccess.serviceOff:
        await _blocked(
          context,
          title: 'Localisation désactivée',
          message:
              'Active la localisation du téléphone pour enregistrer ta sortie.',
          action: 'Ouvrir les réglages',
          onAction: Geolocator.openLocationSettings,
        );
      case GpsAccess.deniedForever || GpsAccess.needsRequest:
        await _blocked(
          context,
          title: 'Accès au GPS refusé',
          message:
              'Sans le GPS, OpenSport ne peut pas tracer ta sortie. Tu peux '
              "l'autoriser dans les réglages de l'application.",
          action: 'Ouvrir les réglages',
          onAction: Geolocator.openAppSettings,
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sport = ref.watch(recordingProvider.select((s) => s.sport));
    final interrupted = ref.watch(interruptedRecordingProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Enregistrer')),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Column(
            children: [
              if (interrupted != null) ...[
                _InterruptedCard(activity: interrupted),
                const SizedBox(height: 16),
              ],
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  for (final s in Sport.values)
                    ChoiceChip(
                      avatar: Icon(
                        s.icon,
                        size: 18,
                        color: s == sport ? Colors.white : AppColors.textMuted,
                      ),
                      label: Text(s.label),
                      selected: s == sport,
                      showCheckmark: false,
                      selectedColor: AppColors.accent,
                      onSelected: (_) =>
                          ref.read(recordingProvider.notifier).selectSport(s),
                    ),
                ],
              ),
              const Spacer(),
              _StartButton(onPressed: () => _start(context, ref)),
              const SizedBox(height: 20),
              const Text(
                'Le GPS reste actif écran éteint.\n'
                "Ta sortie reste sur ton téléphone, rien n'est envoyé.",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, height: 1.4),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accent,
      shape: const CircleBorder(),
      elevation: 12,
      shadowColor: AppColors.accent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: const SizedBox(
          width: 150,
          height: 150,
          child: Center(
            child: Text(
              'DÉMARRER',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Une sortie interrompue (app fermée par le système, batterie vide...)
/// peut être terminée et enregistrée, ou supprimée.
class _InterruptedCard extends ConsumerWidget {
  const _InterruptedCard({required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.history_rounded, color: AppColors.accent),
                SizedBox(width: 10),
                Text(
                  'Sortie interrompue',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${activity.sport.label} du ${formatDateTime(activity.startedAt)}'
              " n'a pas été terminée. Ses points GPS sont conservés.",
              style: const TextStyle(color: AppColors.textMuted, height: 1.35),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () async {
                    await ref
                        .read(activityRepositoryProvider)
                        .deleteActivity(activity.id);
                    ref.invalidate(interruptedRecordingProvider);
                  },
                  child: const Text('Supprimer'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            RecordSummaryScreen(activityId: activity.id),
                      ),
                    );
                    ref.invalidate(interruptedRecordingProvider);
                  },
                  child: const Text('Terminer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool?> _explainGps(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.location_on_rounded,
            color: AppColors.accent,
            size: 36,
          ),
          const SizedBox(height: 12),
          const Text(
            'OpenSport a besoin du GPS',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          const Text(
            '• Pour tracer ta sortie et mesurer distance et allure.\n'
            '• Il reste actif écran éteint, tant que la sortie est en cours.\n'
            "• Ta position n'est jamais envoyée : tout reste sur ton "
            'téléphone.',
            style: TextStyle(color: AppColors.textMuted, height: 1.5),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuer'),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _blocked(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  required Future<bool> Function() onAction,
}) {
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Plus tard'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            onAction();
          },
          child: Text(action),
        ),
      ],
    ),
  );
}

// ------------------------------------------------------- Compte à rebours

class _CountdownView extends ConsumerWidget {
  const _CountdownView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(recordingProvider.select((s) => s.countdown));
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Text(
                '$count',
                key: ValueKey(count),
                style: const TextStyle(
                  fontSize: 140,
                  fontWeight: FontWeight.w900,
                  color: AppColors.accent,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const _GpsQuality(),
            const SizedBox(height: 40),
            TextButton(
              onPressed: () =>
                  ref.read(recordingProvider.notifier).cancelCountdown(),
              child: const Text('Annuler'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------- Vue en direct

class _LiveView extends ConsumerStatefulWidget {
  const _LiveView();

  @override
  ConsumerState<_LiveView> createState() => _LiveViewState();
}

class _LiveViewState extends ConsumerState<_LiveView> {
  // Rafraîchit la durée affichée, même sans nouveau point GPS.
  late final Timer _clock = Timer.periodic(
    const Duration(milliseconds: 500),
    (_) => setState(() {}),
  );

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  void _finish() {
    HapticFeedback.heavyImpact();
    // Le navigateur est récupéré avant l'arrêt : cette vue disparaît dès
    // que l'enregistrement s'arrête.
    final navigator = Navigator.of(context);
    final id = ref.read(recordingProvider.notifier).stop();
    if (id == null) return;
    navigator.push(
      MaterialPageRoute(builder: (_) => RecordSummaryScreen(activityId: id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordingProvider);
    final controller = ref.read(recordingProvider.notifier);
    final paused = state.phase == RecordingPhase.paused;
    final elapsed = controller.elapsed;
    final avgPace = state.distance > 20
        ? elapsed.inSeconds / (state.distance / 1000)
        : 0.0;
    final currentPace = state.speed > 0.3 ? 1000 / state.speed : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const LiveRecordMap(),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 10,
            left: 0,
            right: 0,
            child: Center(
              child: paused ? const _PausedBadge() : const _GpsQuality(),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Glass(
              radius: 26,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatDuration(elapsed),
                    style: const TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: StatValue(
                          label: 'Distance',
                          value: formatKm(state.distance),
                          unit: 'km',
                          size: 24,
                        ),
                      ),
                      Expanded(
                        child: StatValue(
                          label: 'Allure',
                          value: formatPace(currentPace),
                          unit: '/km',
                          size: 24,
                        ),
                      ),
                      Expanded(
                        child: StatValue(
                          label: 'Moyenne',
                          value: formatPace(avgPace),
                          unit: '/km',
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _RoundAction(
                        icon: paused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        label: paused ? 'Reprendre' : 'Pause',
                        color: paused ? AppColors.success : Colors.white,
                        foreground: paused ? Colors.white : Colors.black,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          paused ? controller.resume() : controller.pause();
                        },
                      ),
                      _RoundAction(
                        icon: Icons.stop_rounded,
                        label: 'Maintenir pour terminer',
                        color: AppColors.accent,
                        foreground: Colors.white,
                        onLongPress: _finish,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.foreground,
    this.onTap,
    this.onLongPress,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color foreground;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            onLongPress: onLongPress,
            child: SizedBox(
              width: 76,
              height: 76,
              child: Icon(icon, size: 40, color: foreground),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _PausedBadge extends StatelessWidget {
  const _PausedBadge();

  @override
  Widget build(BuildContext context) {
    return const Glass(
      radius: 20,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        'EN PAUSE',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          color: Color(0xFFFACC15),
        ),
      ),
    );
  }
}

/// Qualité du signal GPS : verte sous 10 m, orange sous 25 m, rouge au-delà.
class _GpsQuality extends ConsumerWidget {
  const _GpsQuality();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accuracy = ref.watch(recordingProvider.select((s) => s.accuracy));
    final (color, text) = switch (accuracy) {
      null => (AppColors.textMuted, 'Recherche du GPS…'),
      < 10 => (AppColors.success, 'GPS excellent'),
      < 25 => (const Color(0xFFF97316), 'GPS moyen'),
      _ => (const Color(0xFFEF4444), 'GPS faible'),
    };
    return Glass(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.gps_fixed_rounded, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            accuracy == null ? text : '$text · ±${accuracy.round()} m',
            style: TextStyle(fontSize: 13, color: color),
          ),
        ],
      ),
    );
  }
}
