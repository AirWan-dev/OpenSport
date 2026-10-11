import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:opensport/core/theme/app_theme.dart';
import 'package:opensport/features/activities/models/track.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

import 'map_style.dart';

/// Candidate A : flutter_map + vector_map_tiles, dessiné en Dart.
class FlutterMapVectorView extends StatefulWidget {
  const FlutterMapVectorView({super.key, required this.track});

  final Track track;

  @override
  State<FlutterMapVectorView> createState() => _FlutterMapVectorViewState();
}

class _FlutterMapVectorViewState extends State<FlutterMapVectorView> {
  late final Future<(vtr.Theme, String)> _setup = _load();

  Future<(vtr.Theme, String)> _load() async {
    final style = await loadDarkStyle();
    return (vtr.ThemeReader().read(style), await resolveTileUrl());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _setup,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final (theme, tileUrl) = snapshot.data!;
        return _map(theme, tileUrl);
      },
    );
  }

  Widget _map(vtr.Theme theme, String tileUrl) {
    final track = widget.track;
    final positions = track.positions;
    final segments = paceSegments(track);

    return FlutterMap(
      options: MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(positions),
          padding: const EdgeInsets.fromLTRB(32, 120, 32, 140),
        ),
        backgroundColor: const Color(0xFF0B0E13),
        maxZoom: 19,
      ),
      children: [
        VectorTileLayer(
          theme: theme,
          tileProviders: TileProviders({
            'openmaptiles': NetworkVectorTileProvider(
              urlTemplate: tileUrl,
              maximumZoom: 14,
            ),
          }),
        ),
        Opacity(
          opacity: 0.25,
          child: PolylineLayer(
            polylines: [
              for (final s in segments)
                Polyline(
                  points: positions.sublist(s.start, s.end + 1),
                  strokeWidth: 16,
                  color: s.color,
                ),
            ],
          ),
        ),
        PolylineLayer(
          polylines: [
            for (final s in segments)
              Polyline(
                points: positions.sublist(s.start, s.end + 1),
                strokeWidth: 5,
                color: s.color,
              ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: positions.first,
              width: 22,
              height: 22,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
            ),
          ],
        ),
        const RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          showFlutterMapAttribution: false,
          attributions: [
            TextSourceAttribution('© OpenFreeMap · © OpenMapTiles'),
            TextSourceAttribution('© contributeurs OpenStreetMap'),
          ],
        ),
      ],
    );
  }
}
