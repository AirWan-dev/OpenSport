import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:opensport/core/theme/pace_colors.dart';

import '../models/track.dart';

/// Aperçu léger du tracé, sans fond de carte, pour les listes.
class RoutePreview extends StatelessWidget {
  const RoutePreview({super.key, required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _RoutePainter(track), size: Size.infinite);
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter(this.track);

  final Track track;

  @override
  void paint(Canvas canvas, Size size) {
    if (track.points.length < 2) return;

    // Projection équirectangulaire corrigée de la latitude : suffisant à
    // l'échelle d'une sortie.
    final latRef = track.points.first.position.latitude * math.pi / 180;
    final xs = [
      for (final p in track.points) p.position.longitude * math.cos(latRef),
    ];
    final ys = [for (final p in track.points) -p.position.latitude];
    final minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
    final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);

    const padding = 18.0;
    final scale = math.min(
      (size.width - 2 * padding) / math.max(maxX - minX, 1e-9),
      (size.height - 2 * padding) / math.max(maxY - minY, 1e-9),
    );
    final dx = (size.width - (maxX - minX) * scale) / 2;
    final dy = (size.height - (maxY - minY) * scale) / 2;
    Offset at(int i) =>
        Offset(dx + (xs[i] - minX) * scale, dy + (ys[i] - minY) * scale);

    final slow = track.speedPercentile(0.05);
    final fast = track.speedPercentile(0.95);
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.06);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < track.points.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(path, glow);

    for (var i = 1; i < track.points.length; i++) {
      line.color = paceColor(track.speeds[i], slow, fast);
      canvas.drawLine(at(i - 1), at(i), line);
    }

    canvas.drawCircle(at(0), 5, Paint()..color = Colors.white);
    canvas.drawCircle(at(0), 3, Paint()..color = const Color(0xFF22C55E));
  }

  @override
  bool shouldRepaint(_RoutePainter old) => old.track != track;
}
