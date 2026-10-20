import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opensport/core/format.dart';
import 'package:opensport/core/theme/app_theme.dart';
import 'package:opensport/core/widgets/stat_value.dart';

import '../data/workout_providers.dart';
import '../models/workout_session.dart';
import '../widgets/elapsed_time.dart';
import '../widgets/muscle_badge.dart';
import '../widgets/set_row.dart';
import 'exercise_library_screen.dart';

const _danger = Color(0xFFEF4444);

/// Séance en cours : exercices, séries à saisir et à cocher. Fermer l'écran
/// ne l'arrête pas : elle reste accessible par le bandeau « Séance en cours ».
class WorkoutScreen extends ConsumerWidget {
  const WorkoutScreen({super.key, required this.workoutId});

  final int workoutId;

  static Future<void> open(BuildContext context, int workoutId) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WorkoutScreen(workoutId: workoutId)),
    );
  }

  Future<void> _addExercises(BuildContext context, WidgetRef ref) async {
    final picked = await ExerciseLibraryScreen.pick(context);
    if (picked.isEmpty) return;
    await ref.read(workoutRepositoryProvider).addExercises(workoutId, picked);
  }

  Future<void> _finish(
    BuildContext context,
    WidgetRef ref,
    WorkoutSession session,
  ) async {
    final sets = session.exercises.expand((e) => e.sets);
    final pending = sets.where((s) => s.completedAt == null).length;

    if (pending == sets.length) {
      final discard = await _confirm(
        context,
        title: 'Aucune série cochée',
        message:
            'Coche au moins une série pour enregistrer la séance, ou '
            'abandonne-la.',
        confirm: 'Abandonner',
        danger: true,
      );
      if (discard == true && context.mounted) {
        await _discard(context, ref, ask: false);
      }
      return;
    }

    final finish = await _confirm(
      context,
      title: 'Terminer la séance ?',
      message: switch (pending) {
        0 => 'Toutes les séries sont cochées.',
        1 => 'La série non cochée sera retirée.',
        _ => 'Les $pending séries non cochées seront retirées.',
      },
      confirm: 'Terminer',
    );
    if (finish != true) return;
    await ref.read(workoutRepositoryProvider).finishWorkout(workoutId);
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _discard(
    BuildContext context,
    WidgetRef ref, {
    bool ask = true,
  }) async {
    if (ask) {
      final confirmed = await _confirm(
        context,
        title: 'Abandonner la séance ?',
        message: 'Toutes les séries de cette séance seront perdues.',
        confirm: 'Abandonner',
        danger: true,
      );
      if (confirmed != true) return;
    }
    await ref.read(workoutRepositoryProvider).discardWorkout(workoutId);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(workoutSessionProvider(workoutId));
    final current = session.value;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          tooltip: 'Réduire',
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Séance'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: current == null
                  ? null
                  : () => _finish(context, ref, current),
              child: const Text('Terminer'),
            ),
          ),
        ],
      ),
      body: session.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erreur : $error')),
        data: (s) {
          if (s == null) return const SizedBox.shrink();
          return ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              _Summary(session: s),
              const SizedBox(height: 16),
              if (s.exercises.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'Ajoute un premier exercice pour commencer.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              for (final (i, item) in s.exercises.indexed) ...[
                _ExerciseCard(
                  key: ValueKey(item.entry.id),
                  item: item,
                  isFirst: i == 0,
                  isLast: i == s.exercises.length - 1,
                ),
                const SizedBox(height: 14),
              ],
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Ajouter des exercices'),
                onPressed: () => _addExercises(context, ref),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _discard(context, ref),
                child: const Text(
                  'Abandonner la séance',
                  style: TextStyle(color: _danger),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

Future<bool?> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirm,
  bool danger = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Continuer'),
        ),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(backgroundColor: _danger)
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
}

/// Durée, volume et nombre de séries, en haut de la séance.
class _Summary extends StatelessWidget {
  const _Summary({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElapsedTime(
            since: session.workout.startedAt,
            builder: (elapsed) => StatValue(label: 'Durée', value: elapsed),
          ),
        ),
        Expanded(
          child: StatValue(
            label: 'Volume',
            value: formatThousands(session.volumeKg),
            unit: 'kg',
          ),
        ),
        Expanded(
          child: StatValue(label: 'Séries', value: '${session.completedSets}'),
        ),
      ],
    );
  }
}

enum _ExerciseAction { up, down, remove }

class _ExerciseCard extends ConsumerWidget {
  const _ExerciseCard({
    super.key,
    required this.item,
    required this.isFirst,
    required this.isLast,
  });

  final SessionExercise item;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(workoutRepositoryProvider);
    final exercise = item.exercise;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 4),
              child: Row(
                children: [
                  MuscleBadge(muscle: exercise.primaryMuscle, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      exercise.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  PopupMenuButton<_ExerciseAction>(
                    tooltip: 'Options de l\'exercice',
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: (action) => switch (action) {
                      _ExerciseAction.up => repository.moveExercise(
                        item.entry,
                        -1,
                      ),
                      _ExerciseAction.down => repository.moveExercise(
                        item.entry,
                        1,
                      ),
                      _ExerciseAction.remove => repository.removeExercise(
                        item.entry,
                      ),
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: _ExerciseAction.up,
                        enabled: !isFirst,
                        child: const Text('Monter'),
                      ),
                      PopupMenuItem(
                        value: _ExerciseAction.down,
                        enabled: !isLast,
                        child: const Text('Descendre'),
                      ),
                      const PopupMenuItem(
                        value: _ExerciseAction.remove,
                        child: Text(
                          'Retirer l\'exercice',
                          style: TextStyle(color: _danger),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _NoteField(item: item),
            SetHeader(type: exercise.type),
            for (final (i, set) in item.sets.indexed)
              SetRow(
                key: ValueKey(set.id),
                set: set,
                type: exercise.type,
                label: item.labelFor(i),
                previous: switch (item.previousFor(i)) {
                  final last? => SetValues.of(last),
                  null => null,
                },
                hint: item.hintFor(i),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextButton.icon(
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Ajouter une série'),
                onPressed: () => repository.addSet(item.entry),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Note libre sur l'exercice (« siège cran 4 », « prise large »...).
class _NoteField extends ConsumerStatefulWidget {
  const _NoteField({required this.item});

  final SessionExercise item;

  @override
  ConsumerState<_NoteField> createState() => _NoteFieldState();
}

class _NoteFieldState extends ConsumerState<_NoteField> {
  late final _controller = TextEditingController(
    text: widget.item.entry.notes ?? '',
  );
  final _focus = FocusNode();

  @override
  void didUpdateWidget(_NoteField old) {
    super.didUpdateWidget(old);
    final text = widget.item.entry.notes ?? '';
    if (!_focus.hasFocus && _controller.text.trim() != text) {
      _controller.text = text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        minLines: 1,
        maxLines: 3,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(fontSize: 13),
        decoration: const InputDecoration(
          isDense: true,
          hintText: 'Ajouter une note…',
          hintStyle: TextStyle(color: AppColors.textFaint),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 6),
        ),
        onChanged: (text) => ref
            .read(workoutRepositoryProvider)
            .updateNote(widget.item.entry, text),
        onTapOutside: (_) => _focus.unfocus(),
      ),
    );
  }
}
