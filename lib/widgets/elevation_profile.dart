import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/track.dart';
import '../theme/pace_colors.dart';

/// Profil d'altitude coloré par allure. Glisser le doigt dessus déplace
/// le curseur de replay sur la carte.
class ElevationProfile extends StatelessWidget {
  const ElevationProfile({
    super.key,
    required this.track,
    required this.progress,
    required this.onScrub,
    required this.slowSpeed,
    required this.fastSpeed,
  });

  final Track track;

  /// Position du curseur, de 0 à 1.
  final double progress;
  final ValueChanged<double> onScrub;
  final double slowSpeed;
  final double fastSpeed;

  @override
  Widget build(BuildContext context) {
    final totalKm = track.distance / 1000;
    final step = (track.points.length / 160).ceil();
    final spots = <FlSpot>[
      for (var i = 0; i < track.points.length; i += step)
        FlSpot(track.cumulativeDistance[i] / 1000, track.points[i].elevation),
    ];

    // Dégradé horizontal reprenant la couleur d'allure le long du parcours.
    final gradientColors = <Color>[];
    final gradientStops = <double>[];
    for (var i = 0; i < track.points.length; i += step * 2) {
      gradientColors.add(paceColor(track.speeds[i], slowSpeed, fastSpeed));
      gradientStops.add(track.cumulativeDistance[i] / track.distance);
    }

    final minY = (track.minElevation - 6).floorToDouble();
    final maxY = (track.maxElevation + 6).ceilToDouble();
    final cursorKm = progress * totalKm;

    return LayoutBuilder(builder: (context, constraints) {
      void scrub(double dx) =>
          onScrub((dx / constraints.maxWidth).clamp(0.0, 1.0));

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => scrub(d.localPosition.dx),
        onHorizontalDragUpdate: (d) => scrub(d.localPosition.dx),
        child: LineChart(
          duration: Duration.zero,
          LineChartData(
            minX: 0,
            maxX: totalKm,
            minY: minY,
            maxY: maxY,
            gridData: const FlGridData(show: false),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
            clipData: const FlClipData.all(),
            extraLinesData: ExtraLinesData(verticalLines: [
              VerticalLine(
                x: cursorKm,
                color: Colors.white,
                strokeWidth: 1.5,
                dashArray: [4, 3],
              ),
            ]),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.25,
                barWidth: 2.5,
                dotData: const FlDotData(show: false),
                gradient: LinearGradient(
                  colors: gradientColors,
                  stops: gradientStops,
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.18),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
