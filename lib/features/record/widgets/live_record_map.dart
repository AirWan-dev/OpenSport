import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:opensport/core/map/map_styles.dart';
import 'package:opensport/core/widgets/glass.dart';
import 'package:opensport/features/activities/models/track.dart';

import '../recording/recording_controller.dart';

const _empty = {'type': 'FeatureCollection', 'features': []};

/// Carte pendant l'enregistrement : position actuelle et tracé qui
/// s'allonge, caméra qui suit le coureur.
class LiveRecordMap extends ConsumerStatefulWidget {
  const LiveRecordMap({super.key});

  @override
  ConsumerState<LiveRecordMap> createState() => _LiveRecordMapState();
}

class _LiveRecordMapState extends ConsumerState<LiveRecordMap> {
  final Future<String> _style = MapStyle.dark.load();
  ml.MapLibreMapController? _map;
  bool _ready = false;
  bool _follow = true;

  Future<void> _onStyleLoaded() async {
    final map = _map;
    if (map == null) return;
    await map.addGeoJsonSource('live', _empty);
    await map.addGeoJsonSource('me', _empty);
    await map.addLineLayer(
      'live',
      'live-glow',
      const ml.LineLayerProperties(
        lineColor: '#FC5200',
        lineWidth: 18,
        lineBlur: 12,
        lineOpacity: 0.5,
        lineCap: 'round',
        lineJoin: 'round',
      ),
    );
    await map.addLineLayer(
      'live',
      'live-line',
      const ml.LineLayerProperties(
        lineColor: '#FF7A3D',
        lineWidth: 5,
        lineCap: 'round',
        lineJoin: 'round',
      ),
    );
    await map.addCircleLayer(
      'me',
      'me-halo',
      const ml.CircleLayerProperties(
        circleRadius: 22,
        circleColor: '#FC5200',
        circleOpacity: 0.22,
      ),
    );
    await map.addCircleLayer(
      'me',
      'me-dot',
      const ml.CircleLayerProperties(
        circleRadius: 9,
        circleColor: '#FC5200',
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 3,
      ),
    );
    _ready = true;
    _refresh();
  }

  /// Envoie le tracé (un trait par tronçon) et la position actuelle.
  Future<void> _refresh() async {
    final map = _map;
    if (map == null || !_ready) return;
    final points = ref.read(recordingProvider.notifier).points;
    if (points.isEmpty) return;

    final segments = <int, List<List<double>>>{};
    for (final p in points) {
      segments.putIfAbsent(p.segment, () => []).add([
        p.position.longitude,
        p.position.latitude,
      ]);
    }
    final last = points.last.position;

    await map.setGeoJsonSource('live', {
      'type': 'FeatureCollection',
      'features': [
        for (final coords in segments.values)
          if (coords.length > 1)
            {
              'type': 'Feature',
              'properties': <String, dynamic>{},
              'geometry': {'type': 'LineString', 'coordinates': coords},
            },
      ],
    });
    await map.setGeoJsonSource('me', {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': <String, dynamic>{},
          'geometry': {
            'type': 'Point',
            'coordinates': [last.longitude, last.latitude],
          },
        },
      ],
    });
    if (_follow) _center(points.last);
  }

  void _center(TrackPoint point) {
    _map?.animateCamera(
      ml.CameraUpdate.newLatLngZoom(
        ml.LatLng(point.position.latitude, point.position.longitude),
        16,
      ),
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Chaque nouveau point redessine le tracé.
    ref.listen(recordingProvider.select((s) => s.pointCount), (_, _) {
      _refresh();
    });

    return FutureBuilder(
      future: _style,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.expand();
        return Stack(
          children: [
            Listener(
              onPointerDown: (_) {
                if (_follow) setState(() => _follow = false);
              },
              child: ml.MapLibreMap(
                styleString: snapshot.data!,
                initialCameraPosition: const ml.CameraPosition(
                  target: ml.LatLng(48.8566, 2.3522),
                  zoom: 12,
                ),
                compassEnabled: false,
                myLocationEnabled: false,
                attributionButtonPosition: ml.AttributionButtonPosition.topLeft,
                onMapCreated: (c) => _map = c,
                onStyleLoadedCallback: _onStyleLoaded,
              ),
            ),
            if (!_follow)
              Positioned(
                right: 12,
                top: MediaQuery.paddingOf(context).top + 64,
                child: GlassButton(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Recentrer',
                  onPressed: () {
                    setState(() => _follow = true);
                    final points = ref.read(recordingProvider.notifier).points;
                    if (points.isNotEmpty) _center(points.last);
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
