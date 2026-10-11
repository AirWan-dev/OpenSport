import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:opensport/core/theme/app_theme.dart';
import 'package:opensport/core/widgets/glass.dart';
import 'package:opensport/features/activities/models/track.dart';

import 'map_style.dart';

/// Candidate B : MapLibre, moteur natif dessiné par la carte graphique,
/// avec bâtiments en 3D et caméra inclinable.
class MapLibreView extends StatefulWidget {
  const MapLibreView({super.key, required this.track});

  final Track track;

  @override
  State<MapLibreView> createState() => _MapLibreViewState();
}

class _MapLibreViewState extends State<MapLibreView> {
  late final Future<String> _style = _load();
  ml.MapLibreMapController? _controller;
  bool _tilted = true;

  /// Même style que la candidate A, plus une couche de bâtiments en relief
  /// que seul MapLibre sait dessiner.
  Future<String> _load() async {
    final style = await loadDarkStyle();
    final layers = style['layers'] as List;
    final index = layers.indexWhere((l) => l['id'] == 'building');
    layers.insert(index + 1, {
      'id': 'building-3d',
      'type': 'fill-extrusion',
      'source': 'openmaptiles',
      'source-layer': 'building',
      'minzoom': 14,
      'paint': {
        'fill-extrusion-color': '#1A2029',
        'fill-extrusion-height': ['get', 'render_height'],
        'fill-extrusion-base': ['get', 'render_min_height'],
        'fill-extrusion-opacity': 0.85,
      },
    });
    return jsonEncode(style);
  }

  ml.LatLng _ml(int i) {
    final p = widget.track.points[i].position;
    return ml.LatLng(p.latitude, p.longitude);
  }

  Future<void> _addRoute() async {
    final c = _controller!;
    final track = widget.track;
    String hex(Color color) =>
        '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

    await c.addGeoJsonSource('route', {
      'type': 'FeatureCollection',
      'features': [
        for (final s in paceSegments(track))
          {
            'type': 'Feature',
            'properties': {'color': hex(s.color)},
            'geometry': {
              'type': 'LineString',
              'coordinates': [
                for (var i = s.start; i <= s.end; i++)
                  [
                    track.points[i].position.longitude,
                    track.points[i].position.latitude,
                  ],
              ],
            },
          },
      ],
    });
    await c.addLineLayer(
      'route',
      'route-glow',
      const ml.LineLayerProperties(
        lineColor: ['get', 'color'],
        lineWidth: 16,
        lineOpacity: 0.25,
        lineBlur: 4,
      ),
    );
    await c.addLineLayer(
      'route',
      'route-line',
      const ml.LineLayerProperties(
        lineColor: ['get', 'color'],
        lineWidth: 5,
        lineCap: 'round',
        lineJoin: 'round',
      ),
    );

    final start = track.points.first.position;
    await c.addGeoJsonSource('start', {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': <String, dynamic>{},
          'geometry': {
            'type': 'Point',
            'coordinates': [start.longitude, start.latitude],
          },
        },
      ],
    });
    await c.addCircleLayer(
      'start',
      'start-dot',
      const ml.CircleLayerProperties(
        circleRadius: 8,
        circleColor: '#22C55E',
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 3,
      ),
    );
  }

  ml.LatLngBounds get _bounds {
    final lats = widget.track.points.map((p) => p.position.latitude);
    final lngs = widget.track.points.map((p) => p.position.longitude);
    return ml.LatLngBounds(
      southwest: ml.LatLng(
        lats.reduce((a, b) => a < b ? a : b),
        lngs.reduce((a, b) => a < b ? a : b),
      ),
      northeast: ml.LatLng(
        lats.reduce((a, b) => a > b ? a : b),
        lngs.reduce((a, b) => a > b ? a : b),
      ),
    );
  }

  void _toggleTilt() {
    setState(() => _tilted = !_tilted);
    _controller?.animateCamera(
      ml.CameraUpdate.newCameraPosition(
        ml.CameraPosition(
          target: _ml(0),
          zoom: _tilted ? 15.2 : 13.2,
          tilt: _tilted ? 60 : 0,
          bearing: _tilted ? -30 : 0,
        ),
      ),
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _style,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return Stack(
          children: [
            ml.MapLibreMap(
              styleString: snapshot.data!,
              initialCameraPosition: ml.CameraPosition(
                target: _ml(0),
                zoom: 15.2,
                tilt: 60,
                bearing: -30,
              ),
              compassEnabled: false,
              attributionButtonPosition:
                  ml.AttributionButtonPosition.bottomLeft,
              onMapCreated: (controller) => _controller = controller,
              onStyleLoadedCallback: _addRoute,
            ),
            Positioned(
              right: 12,
              top: 12,
              child: Column(
                children: [
                  GlassButton(
                    icon: Icons.threed_rotation_rounded,
                    tooltip: _tilted ? 'Vue de dessus' : 'Vue 3D',
                    active: _tilted,
                    onPressed: _toggleTilt,
                  ),
                  const SizedBox(height: 10),
                  GlassButton(
                    icon: Icons.fit_screen_rounded,
                    tooltip: 'Voir tout le parcours',
                    onPressed: () {
                      setState(() => _tilted = false);
                      _controller?.animateCamera(
                        ml.CameraUpdate.newLatLngBounds(
                          _bounds,
                          left: 40,
                          top: 60,
                          right: 40,
                          bottom: 60,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Positioned(
              left: 12,
              top: 12,
              child: _Badge(text: 'Bâtiments 3D · inclinaison'),
            ),
          ],
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
    );
  }
}
