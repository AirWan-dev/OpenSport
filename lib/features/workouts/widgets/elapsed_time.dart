import 'dart:async';

import 'package:flutter/material.dart';
import 'package:opensport/core/format.dart';

/// Temps écoulé depuis [since], mis à jour chaque seconde.
class ElapsedTime extends StatefulWidget {
  const ElapsedTime({super.key, required this.since, required this.builder});

  final DateTime since;

  /// Construit l'affichage à partir du temps mis en forme (« 12:34 »).
  final Widget Function(String elapsed) builder;

  @override
  State<ElapsedTime> createState() => _ElapsedTimeState();
}

class _ElapsedTimeState extends State<ElapsedTime> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.since);
    return widget.builder(
      formatDuration(elapsed.isNegative ? Duration.zero : elapsed),
    );
  }
}
