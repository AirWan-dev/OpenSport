import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opensport/core/database/app_database.dart';
import 'package:opensport/core/models/equipment.dart';
import 'package:opensport/core/models/exercise_type.dart';
import 'package:opensport/core/models/muscle.dart';
import 'package:opensport/core/search.dart';
import 'package:opensport/core/theme/app_theme.dart';

import '../data/workout_providers.dart';

/// Création d'un exercice perso, ou modification de [exercise].
/// Se ferme en renvoyant l'id de l'exercice enregistré.
class ExerciseFormScreen extends ConsumerStatefulWidget {
  const ExerciseFormScreen({super.key, this.exercise, this.initialName = ''});

  final Exercise? exercise;

  /// Nom proposé à la création (ce qu'on cherchait sans le trouver).
  final String initialName;

  @override
  ConsumerState<ExerciseFormScreen> createState() => _ExerciseFormScreenState();
}

class _ExerciseFormScreenState extends ConsumerState<ExerciseFormScreen> {
  late final _name = TextEditingController(
    text: widget.exercise?.name ?? widget.initialName,
  );
  late var _type = widget.exercise?.type ?? ExerciseType.weightReps;
  late Muscle? _primary = widget.exercise?.primaryMuscle;
  late final _secondary = {...?widget.exercise?.secondaryMuscles};
  late Equipment? _equipment = widget.exercise?.equipment;
  var _saving = false;

  bool get _editing => widget.exercise != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Un autre exercice de la bibliothèque porte-t-il déjà ce nom ?
  bool _nameTaken(List<Exercise> exercises) {
    final name = normalizeForSearch(_name.text.trim());
    return exercises.any(
      (e) => e.id != widget.exercise?.id && normalizeForSearch(e.name) == name,
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final id = await ref
        .read(exerciseRepositoryProvider)
        .saveCustomExercise(
          id: widget.exercise?.id,
          name: _name.text,
          type: _type,
          primaryMuscle: _primary!,
          // Ordre de l'énumération, quel que soit l'ordre des appuis.
          secondaryMuscles: [
            for (final m in Muscle.values)
              if (_secondary.contains(m)) m,
          ],
          equipment: _equipment!,
        );
    if (mounted) Navigator.pop(context, id);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cet exercice\u00A0?'),
        content: const Text(
          'Il disparaîtra de la bibliothèque. Les séances où il figure le '
          'garderont dans leur historique.',
        ),
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
        .read(exerciseRepositoryProvider)
        .deleteCustomExercise(widget.exercise!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final exercises = ref.watch(exercisesProvider).value ?? const [];
    final taken = _nameTaken(exercises);
    final canSave =
        _name.text.trim().isNotEmpty &&
        !taken &&
        _primary != null &&
        _equipment != null &&
        !_saving;

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Modifier l\'exercice' : 'Nouvel exercice'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TextField(
            controller: _name,
            autofocus: !_editing && widget.initialName.isEmpty,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Nom',
              hintText: 'Ex. : Développé couché à la machine',
              errorText: taken ? 'Un exercice porte déjà ce nom.' : null,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const _Label('Ce qu\'on note à chaque série'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in ExerciseType.values)
                ChoiceChip(
                  label: Text(t.label),
                  selected: t == _type,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _type = t),
                ),
            ],
          ),
          const _Label('Muscle principal'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in Muscle.values)
                ChoiceChip(
                  label: Text(m.label),
                  selected: m == _primary,
                  showCheckmark: false,
                  onSelected: (_) => setState(() {
                    _primary = m;
                    _secondary.remove(m);
                  }),
                ),
            ],
          ),
          const _Label('Muscles secondaires (facultatif)'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in Muscle.values)
                if (m != _primary)
                  FilterChip(
                    label: Text(m.label),
                    selected: _secondary.contains(m),
                    onSelected: (on) => setState(
                      () => on ? _secondary.add(m) : _secondary.remove(m),
                    ),
                  ),
            ],
          ),
          const _Label('Matériel'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in Equipment.values)
                ChoiceChip(
                  label: Text(e.label),
                  selected: e == _equipment,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _equipment = e),
                ),
            ],
          ),
          const SizedBox(height: 28),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: canSave ? _save : null,
            child: Text(_editing ? 'Enregistrer' : 'Créer l\'exercice'),
          ),
          if (_editing) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _saving ? null : _delete,
              child: const Text(
                'Supprimer l\'exercice',
                style: TextStyle(color: Color(0xFFEF4444)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}
