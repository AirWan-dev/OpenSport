import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opensport/core/database/app_database.dart';
import 'package:opensport/core/format.dart';
import 'package:opensport/core/models/exercise_type.dart';
import 'package:opensport/core/models/set_kind.dart';
import 'package:opensport/core/theme/app_theme.dart';

import '../data/workout_providers.dart';
import '../models/workout_session.dart';

/// Largeurs des colonnes, partagées avec l'en-tête.
abstract final class SetColumns {
  static const number = 34.0;
  static const weight = 64.0;
  static const reps = 52.0;
  static const duration = 72.0;
  static const check = 40.0;
  static const gap = 8.0;
}

/// En-tête des colonnes d'un exercice : SÉRIE, PRÉCÉDENT, KG, RÉPS.
class SetHeader extends StatelessWidget {
  const SetHeader({super.key, required this.type});

  final ExerciseType type;

  @override
  Widget build(BuildContext context) {
    Widget label(String text, double? width, {TextAlign? align}) {
      final child = Text(
        text,
        textAlign: align ?? TextAlign.center,
        style: const TextStyle(
          fontSize: 10,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
          color: AppColors.textFaint,
        ),
      );
      return width == null
          ? Expanded(child: child)
          : SizedBox(width: width, child: child);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          label('SÉRIE', SetColumns.number),
          const SizedBox(width: SetColumns.gap),
          label('PRÉCÉDENT', null, align: TextAlign.start),
          if (type == ExerciseType.duration)
            label('SEC', SetColumns.duration)
          else ...[
            label(
              type == ExerciseType.bodyweightReps ? '+KG' : 'KG',
              SetColumns.weight,
            ),
            const SizedBox(width: SetColumns.gap),
            label('RÉPS', SetColumns.reps),
          ],
          const SizedBox(width: SetColumns.gap + SetColumns.check),
        ],
      ),
    );
  }
}

/// Une série : numéro, valeurs de la dernière fois, saisie et case à cocher.
/// Chaque frappe est écrite en base aussitôt.
class SetRow extends ConsumerStatefulWidget {
  const SetRow({
    super.key,
    required this.set,
    required this.type,
    required this.label,
    required this.previous,
    required this.hint,
  });

  final WorkoutSet set;
  final ExerciseType type;

  /// « 1 », « 2 »… ou « É » pour l'échauffement.
  final String label;

  /// La même série la dernière fois, ou null.
  final SetValues? previous;

  /// Valeurs proposées en grisé, reprises si on coche une série vide.
  final SetValues hint;

  @override
  ConsumerState<SetRow> createState() => _SetRowState();
}

class _SetRowState extends ConsumerState<SetRow> {
  late final _weight = TextEditingController(text: _weightText);
  late final _reps = TextEditingController(text: _repsText);
  late final _duration = TextEditingController(text: _durationText);
  final _weightFocus = FocusNode();
  final _repsFocus = FocusNode();
  final _durationFocus = FocusNode();

  String get _weightText {
    final kg = widget.set.weightKg;
    return kg == null ? '' : formatWeight(kg);
  }

  String get _repsText => widget.set.reps?.toString() ?? '';
  String get _durationText => widget.set.durationSeconds?.toString() ?? '';

  bool get _done => widget.set.completedAt != null;

  SetValues get _typed => SetValues(
    weightKg: parseWeight(_weight.text),
    reps: int.tryParse(_reps.text),
    durationSeconds: int.tryParse(_duration.text),
  );

  @override
  void didUpdateWidget(SetRow old) {
    super.didUpdateWidget(old);
    // Ne jamais réécrire un champ en cours de saisie.
    void sync(TextEditingController c, FocusNode focus, String text) {
      if (!focus.hasFocus && c.text != text) c.text = text;
    }

    sync(_weight, _weightFocus, _weightText);
    sync(_reps, _repsFocus, _repsText);
    sync(_duration, _durationFocus, _durationText);
  }

  @override
  void dispose() {
    for (final c in [_weight, _reps, _duration]) {
      c.dispose();
    }
    for (final f in [_weightFocus, _repsFocus, _durationFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  void _save() =>
      ref.read(workoutRepositoryProvider).updateSetValues(widget.set, _typed);

  Future<void> _toggle() async {
    final repository = ref.read(workoutRepositoryProvider);
    if (_done) {
      await repository.setCompleted(widget.set, done: false);
      return;
    }
    final values = _typed.fillFrom(widget.hint);
    final missing = values.missingFor(widget.type);
    if (missing != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Indique $missing.')));
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.lightImpact();
    await repository.setCompleted(widget.set, done: true, values: values);
  }

  Future<void> _showMenu() async {
    final repository = ref.read(workoutRepositoryProvider);
    final warmup = widget.set.kind == SetKind.warmup;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                warmup ? Icons.fitness_center_rounded : Icons.whatshot_rounded,
              ),
              title: Text(
                warmup ? 'En faire une série normale' : 'Série d\'échauffement',
              ),
              subtitle: warmup
                  ? null
                  : const Text(
                      'Ne compte ni dans le volume ni dans les records',
                    ),
              onTap: () => Navigator.pop(context, 'kind'),
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFEF4444),
              ),
              title: const Text(
                'Supprimer la série',
                style: TextStyle(color: Color(0xFFEF4444)),
              ),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    switch (action) {
      case 'kind':
        await repository.setKind(
          widget.set,
          warmup ? SetKind.normal : SetKind.warmup,
        );
      case 'delete':
        await repository.deleteSet(widget.set);
    }
  }

  Widget _field({
    required TextEditingController controller,
    required FocusNode focus,
    required double width,
    required String hint,
    bool decimal = false,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        focusNode: focus,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            RegExp(decimal ? r'[0-9.,]' : r'[0-9]'),
          ),
        ],
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: const TextStyle(
            color: AppColors.textFaint,
            fontWeight: FontWeight.w500,
          ),
          filled: true,
          fillColor: _done ? Colors.transparent : AppColors.surfaceHigh,
          contentPadding: const EdgeInsets.symmetric(vertical: 9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (_) => _save(),
        onTapOutside: (_) => focus.unfocus(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final warmup = widget.set.kind == SetKind.warmup;
    final hint = widget.hint;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: _done ? AppColors.success.withValues(alpha: 0.14) : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: SetColumns.number,
            height: 36,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _showMenu,
              child: Center(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: warmup ? const Color(0xFFF59E0B) : Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: SetColumns.gap),
          Expanded(
            child: Text(
              widget.previous?.describe(widget.type) ?? '–',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          if (widget.type == ExerciseType.duration)
            _field(
              controller: _duration,
              focus: _durationFocus,
              width: SetColumns.duration,
              hint: hint.durationSeconds?.toString() ?? '',
            )
          else ...[
            _field(
              controller: _weight,
              focus: _weightFocus,
              width: SetColumns.weight,
              hint: hint.weightKg == null ? '' : formatWeight(hint.weightKg!),
              decimal: true,
            ),
            const SizedBox(width: SetColumns.gap),
            _field(
              controller: _reps,
              focus: _repsFocus,
              width: SetColumns.reps,
              hint: hint.reps?.toString() ?? '',
            ),
          ],
          const SizedBox(width: SetColumns.gap),
          SizedBox(
            width: SetColumns.check,
            height: 36,
            child: Material(
              color: _done ? AppColors.success : AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _toggle,
                child: Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: _done ? Colors.white : AppColors.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
