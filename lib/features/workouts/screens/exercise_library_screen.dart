import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opensport/core/database/app_database.dart';
import 'package:opensport/core/models/equipment.dart';
import 'package:opensport/core/models/muscle.dart';
import 'package:opensport/core/theme/app_theme.dart';

import '../data/exercise_filter.dart';
import '../data/workout_providers.dart';
import '../widgets/muscle_badge.dart';
import 'exercise_form_screen.dart';

/// Bibliothèque d'exercices : recherche, filtres et exercices perso.
///
/// Avec [selecting], sert de sélecteur : on coche plusieurs exercices, et
/// « Ajouter » renvoie la liste choisie dans l'ordre des appuis.
class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  const ExerciseLibraryScreen({super.key, this.selecting = false});

  final bool selecting;

  /// Ouvre le sélecteur ; renvoie les exercices choisis (vide si annulé).
  static Future<List<Exercise>> pick(BuildContext context) async {
    final picked = await Navigator.push<List<Exercise>>(
      context,
      MaterialPageRoute(
        builder: (_) => const ExerciseLibraryScreen(selecting: true),
      ),
    );
    return picked ?? const [];
  }

  @override
  ConsumerState<ExerciseLibraryScreen> createState() =>
      _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends ConsumerState<ExerciseLibraryScreen> {
  final _search = TextEditingController();
  var _filter = const ExerciseFilter();

  /// Ids cochés, dans l'ordre des appuis.
  final _selected = <int>[];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggle(Exercise exercise) => setState(() {
    if (!_selected.remove(exercise.id)) _selected.add(exercise.id);
  });

  Future<void> _create() async {
    final id = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseFormScreen(initialName: _search.text.trim()),
      ),
    );
    if (id == null || !mounted) return;
    _search.clear();
    setState(() {
      _filter = const ExerciseFilter();
      if (widget.selecting) _selected.add(id);
    });
  }

  void _finishSelection(List<Exercise> all) {
    final byId = {for (final e in all) e.id: e};
    Navigator.pop(context, [
      for (final id in _selected)
        if (byId[id] != null) byId[id]!,
    ]);
  }

  Future<void> _pickMuscle() async {
    final choice = await _showChoices<Muscle>(
      title: 'Muscle principal',
      allLabel: 'Tous les muscles',
      current: _filter.muscle,
      sections: {
        for (final region in MuscleRegion.values)
          region.label: [
            for (final m in Muscle.values)
              if (m.region == region) m,
          ],
      },
      label: (m) => m.label,
      leading: (m) => MuscleBadge(muscle: m, size: 34),
    );
    if (choice == null) return;
    setState(
      () => _filter = ExerciseFilter(
        query: _filter.query,
        muscle: choice.value,
        equipment: _filter.equipment,
      ),
    );
  }

  Future<void> _pickEquipment() async {
    final choice = await _showChoices<Equipment>(
      title: 'Matériel',
      allLabel: 'Tout le matériel',
      current: _filter.equipment,
      sections: {'': Equipment.values},
      label: (e) => e.label,
    );
    if (choice == null) return;
    setState(
      () => _filter = ExerciseFilter(
        query: _filter.query,
        muscle: _filter.muscle,
        equipment: choice.value,
      ),
    );
  }

  /// Liste de choix en bas de l'écran. Renvoie null si on la ferme sans
  /// choisir, et `(value: null)` pour « Tous ».
  Future<({T? value})?> _showChoices<T>({
    required String title,
    required String allLabel,
    required T? current,
    required Map<String, List<T>> sections,
    required String Function(T) label,
    Widget Function(T)? leading,
  }) {
    Widget tile(T? value, String text, Widget? icon) => ListTile(
      leading: icon,
      title: Text(text),
      trailing: value == current
          ? const Icon(Icons.check_rounded, color: AppColors.accent)
          : null,
      onTap: () => Navigator.pop(context, (value: value)),
    );

    return showModalBottomSheet<({T? value})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        builder: (context, controller) => ListView(
          controller: controller,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            tile(null, allLabel, null),
            for (final MapEntry(key: section, value: values)
                in sections.entries) ...[
              if (section.isNotEmpty) _SectionTitle(section),
              for (final v in values) tile(v, label(v), leading?.call(v)),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _showDetails(Exercise exercise) async {
    final edit = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (context) => _ExerciseDetails(exercise: exercise),
    );
    if (edit != true || !mounted) return;
    await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => ExerciseFormScreen(exercise: exercise)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exercises = ref.watch(exercisesProvider);
    final all = exercises.value ?? const <Exercise>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selecting ? 'Ajouter des exercices' : 'Exercices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Créer un exercice',
            onPressed: _create,
          ),
        ],
      ),
      body: exercises.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erreur : $error')),
        data: (list) {
          final shown = _filter.apply(list);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un exercice',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded),
                            tooltip: 'Effacer',
                            onPressed: () => setState(() {
                              _search.clear();
                              _filter = ExerciseFilter(
                                muscle: _filter.muscle,
                                equipment: _filter.equipment,
                              );
                            }),
                          ),
                    filled: true,
                    fillColor: AppColors.surfaceHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (text) => setState(
                    () => _filter = ExerciseFilter(
                      query: text,
                      muscle: _filter.muscle,
                      equipment: _filter.equipment,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _FilterButton(
                      label: _filter.muscle?.label ?? 'Muscle',
                      active: _filter.muscle != null,
                      onPressed: _pickMuscle,
                    ),
                    const SizedBox(width: 8),
                    _FilterButton(
                      label: _filter.equipment?.label ?? 'Matériel',
                      active: _filter.equipment != null,
                      onPressed: _pickEquipment,
                    ),
                    const Spacer(),
                    Text(
                      shown.length < 2
                          ? '${shown.length} exercice'
                          : '${shown.length} exercices',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: shown.isEmpty
                    ? _NoResult(query: _search.text.trim(), onCreate: _create)
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: shown.length,
                        itemBuilder: (context, i) {
                          final exercise = shown[i];
                          return _ExerciseTile(
                            exercise: exercise,
                            selected: widget.selecting
                                ? _selected.contains(exercise.id)
                                : null,
                            onTap: widget.selecting
                                ? () => _toggle(exercise)
                                : () => _showDetails(exercise),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: widget.selecting && _selected.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: () => _finishSelection(all),
                  child: Text(
                    _selected.length == 1
                        ? 'Ajouter 1 exercice'
                        : 'Ajouter ${_selected.length} exercices',
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.active,
    required this.onPressed,
  });

  final String label;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: active ? AppColors.accent : Colors.white,
        backgroundColor: active
            ? AppColors.accent.withValues(alpha: 0.12)
            : null,
        side: BorderSide(color: active ? AppColors.accent : AppColors.outline),
        padding: const EdgeInsets.only(left: 14, right: 8),
        visualDensity: VisualDensity.compact,
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Text(label), const Icon(Icons.arrow_drop_down_rounded)],
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({
    required this.exercise,
    required this.selected,
    required this.onTap,
  });

  final Exercise exercise;

  /// Coché ou non en mode sélection ; null hors sélection.
  final bool? selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final custom = exercise.catalogKey == null;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: MuscleBadge(muscle: exercise.primaryMuscle),
      title: Text(
        exercise.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        [
          exercise.primaryMuscle.label,
          exercise.equipment.label,
          if (custom) 'Perso',
        ].join(' · '),
        style: const TextStyle(color: AppColors.textMuted),
      ),
      trailing: switch (selected) {
        null => null,
        true => const Icon(Icons.check_circle_rounded, color: AppColors.accent),
        false => const Icon(
          Icons.radio_button_unchecked_rounded,
          color: AppColors.textFaint,
        ),
      },
      onTap: onTap,
    );
  }
}

class _NoResult extends StatelessWidget {
  const _NoResult({required this.query, required this.onCreate});

  final String query;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Aucun exercice trouvé.',
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: Text(
                query.isEmpty
                    ? 'Créer un exercice'
                    : 'Créer «\u00A0$query\u00A0»',
              ),
              onPressed: onCreate,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

/// Fiche rapide d'un exercice ; se ferme avec `true` pour le modifier.
/// Historique et records viendront avec Muscu · 9.
class _ExerciseDetails extends StatelessWidget {
  const _ExerciseDetails({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final custom = exercise.catalogKey == null;
    final secondary = exercise.secondaryMuscles;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                MuscleBadge(muscle: exercise.primaryMuscle, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    exercise.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _DetailRow('Muscle principal', exercise.primaryMuscle.label),
            if (secondary.isNotEmpty)
              _DetailRow(
                'Muscles secondaires',
                secondary.map((m) => m.label).join(', '),
              ),
            _DetailRow('Matériel', exercise.equipment.label),
            _DetailRow('Mesure', exercise.type.label),
            if (custom) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Modifier'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
