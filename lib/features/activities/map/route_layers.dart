import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:opensport/core/theme/pace_colors.dart';

import '../models/track.dart';

String _hex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

Map<String, dynamic> _point(double lng, double lat, [Map? props]) => {
  'type': 'Feature',
  'properties': props ?? <String, dynamic>{},
  'geometry': {
    'type': 'Point',
    'coordinates': [lng, lat],
  },
};

const _emptyCollection = {'type': 'FeatureCollection', 'features': []};

/// Couches MapLibre d'une activité : tracé coloré par allure, halo, bornes
/// kilométriques, départ, arrivée et point de tête du replay.
///
/// Les données sont envoyées une seule fois ; pendant le replay, seuls des
/// filtres et le point de tête changent, pour rester fluide.
class RouteLayers {
  RouteLayers(this.track) {
    _slow = track.speedPercentile(0.05);
    _fast = track.speedPercentile(0.95);
  }

  final Track track;
  late final double _slow;
  late final double _fast;

  static const _step = 3;

  Color colorAt(int index) => paceColor(track.speeds[index], _slow, _fast);

  /// Données découpées jusqu'au zoom 12 seulement, puis agrandies : la
  /// caméra embarquée peut alors bouger sans que MapLibre doive redécouper
  /// le tracé à chaque image (sinon il disparaît pendant le mouvement).
  Future<void> _addGeoJson(
    ml.MapLibreMapController map,
    String id,
    Map<String, dynamic> data,
  ) => map.addSource(
    id,
    ml.GeojsonSourceProperties(data: data, maxzoom: 12, tolerance: 0.2),
  );

  /// À appeler après chaque chargement de style : changer de fond de carte
  /// efface toutes les couches ajoutées.
  Future<void> addTo(ml.MapLibreMapController map) async {
    final pts = track.points;
    List<double> coord(int i) => [
      pts[i].position.longitude,
      pts[i].position.latitude,
    ];

    // Toujours une FeatureCollection : sur Android, une source créée avec
    // des options n'accepte pas un élément isolé (plantage natif).
    await _addGeoJson(map, 'route-full', {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': <String, dynamic>{},
          'geometry': {
            'type': 'LineString',
            'coordinates': [for (var i = 0; i < pts.length; i++) coord(i)],
          },
        },
      ],
    });
    await _addGeoJson(map, 'route', {
      'type': 'FeatureCollection',
      'features': [
        for (var i = 0; i < pts.length - 1; i += _step)
          {
            'type': 'Feature',
            'properties': {'start': i, 'color': _hex(colorAt(i))},
            'geometry': {
              'type': 'LineString',
              'coordinates': [
                for (var j = i; j <= (i + _step).clamp(0, pts.length - 1); j++)
                  coord(j),
              ],
            },
          },
      ],
    });

    var km = 0;
    await _addGeoJson(map, 'km', {
      'type': 'FeatureCollection',
      'features': [
        for (var i = 1; i < pts.length; i++)
          if (track.cumulativeDistance[i] >= (km + 1) * 1000)
            _point(coord(i)[0], coord(i)[1], {'idx': i, 'label': '${++km}'}),
      ],
    });
    await _addGeoJson(map, 'ends', {
      'type': 'FeatureCollection',
      'features': [
        _point(coord(0)[0], coord(0)[1], {'kind': 'start'}),
        _point(coord(pts.length - 1)[0], coord(pts.length - 1)[1], {
          'kind': 'finish',
        }),
      ],
    });
    // Le point de tête démarre vide : MapLibre (Android) refuse une source
    // vide créée avec des options, d'où la création simple.
    await map.addGeoJsonSource('head', _emptyCollection);

    await map.addLineLayer(
      'route-full',
      'route-ghost',
      const ml.LineLayerProperties(
        lineColor: '#FFFFFF',
        lineOpacity: 0.22,
        lineWidth: 4,
        lineCap: 'round',
        lineJoin: 'round',
      ),
    );
    await map.addLineLayer(
      'route',
      'route-glow',
      const ml.LineLayerProperties(
        lineColor: ['get', 'color'],
        lineWidth: 20,
        lineBlur: 12,
        lineOpacity: 0.55,
        lineCap: 'round',
        lineJoin: 'round',
      ),
    );
    await map.addLineLayer(
      'route',
      'route-line',
      const ml.LineLayerProperties(
        lineColor: ['get', 'color'],
        lineWidth: 5,
        lineCap: 'round',
        lineJoin: 'round',
      ),
    );
    await map.addCircleLayer(
      'km',
      'km-dot',
      const ml.CircleLayerProperties(
        circleRadius: 11,
        circleColor: '#11151C',
        circleStrokeColor: '#D9DDE3',
        circleStrokeWidth: 1.5,
      ),
    );
    await map.addSymbolLayer(
      'km',
      'km-label',
      const ml.SymbolLayerProperties(
        textField: ['get', 'label'],
        textFont: ['Noto Sans Bold'],
        textSize: 11,
        textColor: '#FFFFFF',
        textAllowOverlap: true,
        textIgnorePlacement: true,
      ),
    );
    await map.addCircleLayer(
      'ends',
      'ends-dot',
      const ml.CircleLayerProperties(
        circleRadius: 9,
        circleColor: [
          'match',
          ['get', 'kind'],
          'start',
          '#22C55E',
          '#FFFFFF',
        ],
        circleStrokeColor: [
          'match',
          ['get', 'kind'],
          'start',
          '#FFFFFF',
          '#11151C',
        ],
        circleStrokeWidth: 3,
      ),
    );
    await map.addCircleLayer(
      'head',
      'head-pulse',
      const ml.CircleLayerProperties(
        circleRadius: ['get', 'pulse'],
        circleColor: ['get', 'color'],
        circleOpacity: ['get', 'fade'],
      ),
    );
    await map.addCircleLayer(
      'head',
      'head-dot',
      const ml.CircleLayerProperties(
        circleRadius: 9,
        circleColor: ['get', 'color'],
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 3,
      ),
    );
  }

  // Dernier état envoyé à la carte, pour n'envoyer que ce qui change.
  int? _lastUpTo;
  int? _lastKmUpTo;
  bool? _lastComplete;

  /// À appeler quand le style est rechargé : tout devra être renvoyé.
  void resetState() {
    _lastUpTo = null;
    _lastKmUpTo = null;
    _lastComplete = null;
  }

  /// Affiche le parcours jusqu'au point [head] ; [pulse] (0..1) anime le
  /// halo du point de tête. Avec [complete], tout le tracé est montré.
  Future<void> showProgress(
    ml.MapLibreMapController map,
    int head, {
    required bool complete,
    double pulse = 0,
  }) {
    final pts = track.points;
    final upTo = complete ? pts.length : head;
    // Les bornes ne changent qu'en franchissant un kilomètre.
    final kmUpTo = complete
        ? pts.length
        : (track.cumulativeDistance[head] / 1000).floor();
    final p = pts[head].position;

    final updates = <Future<void>>[
      if (upTo != _lastUpTo) ...[
        map.setFilter('route-glow', [
          '<',
          ['get', 'start'],
          upTo,
        ]),
        map.setFilter('route-line', [
          '<',
          ['get', 'start'],
          upTo,
        ]),
      ],
      if (kmUpTo != _lastKmUpTo) ...[
        map.setFilter('km-dot', [
          '<=',
          ['get', 'idx'],
          upTo,
        ]),
        map.setFilter('km-label', [
          '<=',
          ['get', 'idx'],
          upTo,
        ]),
      ],
      if (complete != _lastComplete)
        map.setFilter(
          'ends-dot',
          complete
              ? ['has', 'kind']
              : [
                  '==',
                  ['get', 'kind'],
                  'start',
                ],
        ),
      if (!complete || _lastComplete != true)
        map.setGeoJsonSource(
          'head',
          complete
              ? _emptyCollection
              : {
                  'type': 'FeatureCollection',
                  'features': [
                    _point(p.longitude, p.latitude, {
                      'color': _hex(colorAt(head)),
                      'pulse': 10 + 22 * pulse,
                      'fade': 0.45 * (1 - pulse),
                    }),
                  ],
                },
        ),
    ];
    _lastUpTo = upTo;
    _lastKmUpTo = kmUpTo;
    _lastComplete = complete;
    return Future.wait(updates);
  }
}
