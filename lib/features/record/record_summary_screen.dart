import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opensport/core/format.dart';
import 'package:opensport/core/models/sport.dart';
import 'package:opensport/core/theme/app_theme.dart';
import 'package:opensport/core/widgets/stat_value.dart';
import 'package:opensport/features/activities/data/activity_providers.dart';
import 'package:opensport/features/activities/models/track.dart';
import 'package:opensport/features/activities/screens/activity_detail_screen.dart';
import 'package:opensport/features/activities/widgets/route_preview.dart';

/// Fin d'une sortie : récapitulatif, titre, sport et notes, puis
/// enregistrement ou suppression.
class RecordSummaryScreen extends ConsumerStatefulWidget {
  const RecordSummaryScreen({super.key, required this.activityId});

  final int activityId;

  @override
  ConsumerState<RecordSummaryScreen> createState() =>
      _RecordSummaryScreenState();
}

class _RecordSummaryScreenState extends ConsumerState<RecordSummaryScreen> {
  late final Future<Track> _track = ref
      .read(activityRepositoryProvider)
      .loadTrack(widget.activityId);
  final _title = TextEditingController();
  final _notes = TextEditingController();
  Sport? _sport;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save(Track track) async {
    setState(() => _saving = true);
    final sport = _sport ?? track.sport;
    final title = _title.text.trim();
    await ref
        .read(activityRepositoryProvider)
        .finishRecording(
          widget.activityId,
          name: title.isEmpty ? sport.defaultTitle(track.startedAt) : title,
          sport: sport,
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        );
    ref.invalidate(trackProvider(widget.activityId));
    ref.invalidate(interruptedRecordingProvider);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityDetailScreen(activityId: widget.activityId),
      ),
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette sortie ?'),
        content: const Text('Le tracé et les statistiques seront perdus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(activityRepositoryProvider)
        .deleteActivity(widget.activityId);
    ref.invalidate(interruptedRecordingProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sortie terminée'),
        automaticallyImplyLeading: false,
      ),
      body: FutureBuilder(
        future: _track,
        builder: (context, snapshot) {
          final track = snapshot.data;
          if (track == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final sport = _sport ?? track.sport;
          if (_title.text.isEmpty) {
            _title.text = sport.defaultTitle(track.startedAt);
          }
          final enoughPoints = track.points.length >= 2;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Card(
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: StatValue(
                              label: 'Distance',
                              value: formatKm(track.distance),
                              unit: 'km',
                            ),
                          ),
                          Expanded(
                            child: StatValue(
                              label: 'Durée',
                              value: formatDuration(track.duration),
                            ),
                          ),
                          Expanded(
                            child: StatValue(
                              label: 'Allure',
                              value: formatPace(track.averagePace),
                              unit: '/km',
                            ),
                          ),
                          Expanded(
                            child: StatValue(
                              label: 'D+',
                              value: track.elevationGain.toStringAsFixed(0),
                              unit: 'm',
                            ),
                          ),
                        ],
                      ),
                      if (enoughPoints) ...[
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            height: 180,
                            color: AppColors.surfaceHigh,
                            child: RoutePreview(track: track),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Titre',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in Sport.values)
                    ChoiceChip(
                      label: Text(s.label),
                      avatar: Icon(s.icon, size: 18),
                      selected: s == sport,
                      showCheckmark: false,
                      onSelected: (_) => setState(() {
                        // Le titre automatique suit le sport choisi.
                        if (_title.text ==
                            sport.defaultTitle(track.startedAt)) {
                          _title.text = s.defaultTitle(track.startedAt);
                        }
                        _sport = s;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notes,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Notes (facultatif)',
                  hintText: 'Sensations, météo, parcours…',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              if (!enoughPoints)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    "Pas assez de points GPS pour enregistrer cette sortie : "
                    "le signal n'a sans doute pas été trouvé.",
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: enoughPoints && !_saving ? () => _save(track) : null,
                child: const Text('Enregistrer'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _saving ? null : _delete,
                child: const Text(
                  'Supprimer',
                  style: TextStyle(color: Color(0xFFEF4444)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
