import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:opensport/core/format.dart';
import 'package:opensport/core/theme/app_theme.dart';
import 'package:opensport/core/theme/map_styles.dart';
import 'package:opensport/core/theme/pace_colors.dart';
import 'package:opensport/core/widgets/glass.dart';
import 'package:opensport/core/widgets/stat_value.dart';

import '../models/track.dart';
import '../widgets/elevation_profile.dart';

/// Écran de détail d'une activité : tracé coloré par allure, replay animé,
/// caméra embarquée et profil d'altitude.
class ActivityMapScreen extends StatefulWidget {
  const ActivityMapScreen({super.key, required this.track});

  final Track track;

  @override
  State<ActivityMapScreen> createState() => _ActivityMapScreenState();
}

typedef _Segment = ({int start, int end, Color color});

class _ActivityMapScreenState extends State<ActivityMapScreen>
    with TickerProviderStateMixin {
  final _map = MapController();
  late final AnimationController _replay;
  late final AnimationController _pulse;

  late final double _slow = widget.track.speedPercentile(0.05);
  late final double _fast = widget.track.speedPercentile(0.95);
  late final List<_Segment> _segments = _buildSegments();
  late final List<int> _kmIndexes = [
    for (var km = 1; km * 1000 < widget.track.distance; km++)
      widget.track.indexAtDistance(km * 1000.0),
  ];

  MapStyle _style = MapStyle.dark;
  bool _follow = false;
  double _bearing = 0;

  Track get _track => widget.track;
  int get _head => (_replay.value * (_track.points.length - 1)).round();

  @override
  void initState() {
    super.initState();
    _replay = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
      value: 1,
    )..addListener(_onReplayTick);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _replay.dispose();
    _pulse.dispose();
    super.dispose();
  }

  List<_Segment> _buildSegments() {
    const step = 3;
    return [
      for (var i = 0; i < _track.points.length - 1; i += step)
        (
          start: i,
          end: math.min(i + step, _track.points.length - 1),
          color: paceColor(_track.speeds[i], _slow, _fast),
        ),
    ];
  }

  void _onReplayTick() {
    if (_follow) {
      final target = _track.bearingAt(_head, lookAhead: 10);
      // Interpolation d'angle pour une rotation douce de la caméra.
      final delta = ((target - _bearing + 540) % 360) - 180;
      _bearing = (_bearing + delta * 0.08) % 360;
      _map.moveAndRotate(_track.points[_head].position, 16.3, -_bearing);
    }
    setState(() {});
  }

  void _togglePlay() {
    if (_replay.isAnimating) {
      _replay.stop();
    } else {
      if (_replay.value >= 1) _replay.value = 0;
      _bearing = _track.bearingAt(_head, lookAhead: 10);
      _replay.forward();
    }
    setState(() {});
  }

  void _toggleFollow() {
    setState(() => _follow = !_follow);
    if (_follow) {
      _bearing = _track.bearingAt(_head, lookAhead: 10);
      _map.moveAndRotate(_track.points[_head].position, 16.3, -_bearing);
    } else {
      _fitRoute();
    }
  }

  void _fitRoute() {
    _map.rotate(0);
    _map.fitCamera(_routeFit(context));
  }

  CameraFit _routeFit(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(_track.positions),
      padding: EdgeInsets.fromLTRB(
        32,
        padding.top + 110,
        32,
        padding.bottom + 330,
      ),
    );
  }

  void _cycleStyle() {
    final styles = MapStyle.values;
    setState(() => _style = styles[(_style.index + 1) % styles.length]);
  }

  @override
  Widget build(BuildContext context) {
    final head = _head;
    final complete = _replay.value >= 0.999;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCameraFit: _routeFit(context),
              backgroundColor: const Color(0xFF0E1116),
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture && _follow) setState(() => _follow = false);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _style.url,
                tileBuilder: _style.tileBuilder,
                userAgentPackageName: 'org.opensport.opensport',
                maxNativeZoom: 19,
              ),
              ..._routeLayers(head),
              MarkerLayer(
                rotate: true,
                markers: [
                  ..._kmMarkers(head),
                  _startMarker(complete),
                  if (!complete) _headMarker(head),
                ],
              ),
              RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                showFlutterMapAttribution: false,
                attributions: [TextSourceAttribution(_style.attribution)],
              ),
            ],
          ),
          _topBar(context),
          _sideButtons(context),
          Positioned(
            left: 12,
            right: 12,
            bottom: MediaQuery.paddingOf(context).bottom + 12,
            child: _bottomPanel(head),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Tracé

  List<Widget> _routeLayers(int head) {
    final positions = _track.positions;
    final done = positions.sublist(0, head + 1);
    final visible = _segments
        .where((s) => s.start < head)
        .map(
          (s) => (
            points: positions.sublist(s.start, math.min(s.end, head) + 1),
            color: s.color,
          ),
        );

    return [
      // Parcours complet en fantôme pendant le replay.
      PolylineLayer(
        polylines: [
          Polyline(
            points: positions,
            strokeWidth: 4,
            color: Colors.white.withValues(alpha: 0.22),
          ),
          if (done.length > 1)
            Polyline(
              points: done,
              strokeWidth: 9,
              color: Colors.black.withValues(alpha: 0.55),
            ),
        ],
      ),
      // Halo lumineux : segments opaques, transparence appliquée à la couche
      // entière pour éviter les surépaisseurs aux jointures.
      Opacity(
        opacity: 0.25,
        child: PolylineLayer(
          polylines: [
            for (final s in visible)
              Polyline(points: s.points, strokeWidth: 16, color: s.color),
          ],
        ),
      ),
      // Trait principal coloré par allure.
      PolylineLayer(
        polylines: [
          for (final s in visible)
            Polyline(points: s.points, strokeWidth: 5, color: s.color),
        ],
      ),
    ];
  }

  // ------------------------------------------------------------- Marqueurs

  Marker _startMarker(bool complete) {
    return Marker(
      point: _track.points.first.position,
      width: 34,
      height: 34,
      child: Container(
        decoration: BoxDecoration(
          color: complete ? Colors.white : const Color(0xFF22C55E),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black54)],
        ),
        child: Icon(
          complete ? Icons.sports_score_rounded : Icons.play_arrow_rounded,
          size: 18,
          color: complete ? Colors.black : Colors.white,
        ),
      ),
    );
  }

  List<Marker> _kmMarkers(int head) {
    return [
      for (var k = 0; k < _kmIndexes.length; k++)
        if (_kmIndexes[k] <= head)
          Marker(
            point: _track.points[_kmIndexes[k]].position,
            width: 24,
            height: 24,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF11151C),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white70, width: 1.5),
              ),
              child: Text(
                '${k + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
    ];
  }

  Marker _headMarker(int head) {
    final color = paceColor(_track.speeds[head], _slow, _fast);
    return Marker(
      point: _track.points[head].position,
      width: 70,
      height: 70,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final t = _pulse.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 18 + 50 * t,
                height: 18 + 50 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.35 * (1 - t)),
                ),
              ),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [BoxShadow(blurRadius: 14, color: color)],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------ Interface

  Widget _topBar(BuildContext context) {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 10,
      left: 12,
      right: 12,
      child: Row(
        children: [
          if (Navigator.canPop(context)) ...[
            GlassButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Retour',
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(child: _titleCard()),
        ],
      ),
    );
  }

  Widget _titleCard() {
    return Glass(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_track.sport.icon, color: AppColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _track.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_track.sport.label} · ${formatDateTime(_track.startedAt)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sideButtons(BuildContext context) {
    return Positioned(
      right: 12,
      top: MediaQuery.paddingOf(context).top + 90,
      child: Column(
        children: [
          GlassButton(
            icon: _style.icon,
            tooltip: 'Fond : ${_style.label}',
            onPressed: _cycleStyle,
          ),
          const SizedBox(height: 10),
          GlassButton(
            icon: Icons.navigation_rounded,
            tooltip: 'Caméra embarquée',
            active: _follow,
            onPressed: _toggleFollow,
          ),
          const SizedBox(height: 10),
          GlassButton(
            icon: Icons.fit_screen_rounded,
            tooltip: 'Voir tout le parcours',
            onPressed: () {
              setState(() => _follow = false);
              _fitRoute();
            },
          ),
        ],
      ),
    );
  }

  Widget _bottomPanel(int head) {
    final playing = _replay.isAnimating;
    final complete = _replay.value >= 0.999;
    final point = _track.points[head];

    // Pendant le replay, les stats suivent le curseur ; sinon le total.
    final distanceKm =
        (complete ? _track.distance : _track.cumulativeDistance[head]) / 1000;
    final elapsed = complete ? _track.duration : point.elapsed;
    final pace = complete ? _track.averagePace : 1000 / _track.speeds[head];

    return Glass(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    StatValue(
                      label: 'Distance',
                      value: distanceKm.toStringAsFixed(2),
                      unit: 'km',
                    ),
                    StatValue(label: 'Durée', value: formatDuration(elapsed)),
                    StatValue(
                      label: complete ? 'Allure moy.' : 'Allure',
                      value: formatPace(pace),
                      unit: '/km',
                    ),
                    StatValue(
                      label: complete ? 'D+' : 'Altitude',
                      value: complete
                          ? _track.elevationGain.toStringAsFixed(0)
                          : point.elevation.toStringAsFixed(0),
                      unit: 'm',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              _PlayButton(
                icon: playing
                    ? Icons.pause_rounded
                    : complete
                    ? Icons.replay_rounded
                    : Icons.play_arrow_rounded,
                onPressed: _togglePlay,
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 84,
            child: ElevationProfile(
              track: _track,
              progress: _track.cumulativeDistance[head] / _track.distance,
              slowSpeed: _slow,
              fastSpeed: _fast,
              onScrub: (fraction) {
                _replay.stop();
                final index = _track.indexAtDistance(
                  fraction * _track.distance,
                );
                _replay.value = index / (_track.points.length - 1);
              },
            ),
          ),
          const SizedBox(height: 10),
          _PaceLegend(slow: _slow, fast: _fast),
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accent,
      shape: const CircleBorder(),
      elevation: 6,
      shadowColor: AppColors.accent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(icon, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}

class _PaceLegend extends StatelessWidget {
  const _PaceLegend({required this.slow, required this.fast});

  final double slow;
  final double fast;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: Colors.white.withValues(alpha: 0.55),
      fontSize: 10.5,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Row(
      children: [
        Text('${formatPace(1000 / slow)} /km', style: style),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 5,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: const LinearGradient(colors: paceStops),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('${formatPace(1000 / fast)} /km', style: style),
      ],
    );
  }
}
