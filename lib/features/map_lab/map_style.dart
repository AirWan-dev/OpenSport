import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:opensport/core/theme/pace_colors.dart';
import 'package:opensport/features/activities/models/track.dart';

const _stylePath = 'assets/map/opensport_dark.json';
const _tileJsonUrl = 'https://tiles.openfreemap.org/planet';

/// Style sombre maison, partagé par les deux candidates de l'essai.
Future<Map<String, dynamic>> loadDarkStyle() async =>
    jsonDecode(await rootBundle.loadString(_stylePath)) as Map<String, dynamic>;

/// OpenFreeMap versionne l'adresse de ses tuiles : on la lit dans son
/// descriptif TileJSON plutôt que de la figer dans le code.
Future<String> resolveTileUrl() async {
  final response = await http.get(Uri.parse(_tileJsonUrl));
  final json = jsonDecode(response.body) as Map<String, dynamic>;
  return (json['tiles'] as List).first as String;
}

/// Découpe le tracé en segments colorés selon l'allure.
List<({int start, int end, Color color})> paceSegments(
  Track track, {
  int step = 3,
}) {
  final slow = track.speedPercentile(0.05);
  final fast = track.speedPercentile(0.95);
  return [
    for (var i = 0; i < track.points.length - 1; i += step)
      (
        start: i,
        end: (i + step).clamp(0, track.points.length - 1),
        color: paceColor(track.speeds[i], slow, fast),
      ),
  ];
}
