import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:opensport/core/format.dart';
import 'package:opensport/core/map/camera_fit.dart';
import 'package:opensport/core/map/map_styles.dart';
import 'package:opensport/core/theme/app_theme.dart';
import 'package:opensport/core/theme/pace_colors.dart';
import 'package:opensport/core/widgets/glass.dart';
import 'package:opensport/core/widgets/stat_value.dart';

import '../map/route_layers.dart';
import '../models/track.dart';
import '../widgets/elevation_profile.dart';

/// Écran de détail d'une activité : tracé coloré par allure, replay animé,
/// caméra embarquée en 3D et profil d'altitude.
class ActivityMapScreen extends StatefulWidget {
  const ActivityMapScreen({super.key, required this.track});

  final Track track;

  @override
  State<ActivityMapScreen> createState() => _ActivityMapScreenState();
}

class _ActivityMapScreenState extends State<ActivityMapScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _replay;
  late final RouteLayers _layers = RouteLayers(widget.track);
  late final double _slow = widget.track.speedPercentile(0.05);
  late final double _fast = widget.track.speedPercentile(0.95);
  final Future<String> _initialStyle = MapStyle.dark.load();

  ml.MapLibreMapController? _map;
  bool _layersReady = false;
  MapStyle _style = MapStyle.dark;
  Size _viewport = Size.zero;
  bool _follow = false;
  double _bearing = 0;

  // Animation du point de tête, cadencée indépendamment du replay.
  Timer? _pulseTimer;
  final _pulseClock = Stopwatch()..start();
  final _cameraClock = Stopwatch()..start();

  // Une seule mise à jour de la carte à la fois : la plus récente l'emporte.
  bool _pushing = false;
  bool _pushAgain = false;

  // Point de tête réellement affiché : la caméra se cale dessus pour ne
  // jamais devancer le tracé.
  int _shownHead = 0;

  Track get _track => widget.track;
  int get _head => (_replay.value * (_track.points.length - 1)).round();
  bool get _complete => _replay.value >= 0.999;

  @override
  void initState() {
    super.initState();
    _replay = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
      value: 1,
    )..addListener(_onReplayTick);
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 60), (_) {
      if (!_complete && !_replay.isAnimating) _pushFrame();
    });
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    _replay.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------------- Carte

  ml.LatLng _ml(int index) {
    final p = _track.points[index].position;
    return ml.LatLng(p.latitude, p.longitude);
  }

  EdgeInsets get _overviewPadding {
    final safe = MediaQuery.paddingOf(context);
    return EdgeInsets.fromLTRB(28, safe.top + 100, 76, safe.bottom + 320);
  }

  /// Vue de dessus cadrée sur tout le parcours, entre les panneaux.
  ml.CameraPosition _overviewCamera() {
    final fit = fitPoints(_track.positions, _viewport, _overviewPadding);
    return ml.CameraPosition(
      target: ml.LatLng(fit.center.latitude, fit.center.longitude),
      zoom: fit.zoom,
    );
  }

  ml.CameraPosition _followCamera() => ml.CameraPosition(
    target: _ml(_shownHead),
    zoom: 16.4,
    tilt: 62,
    bearing: _bearing,
  );

  Future<void> _onStyleLoaded() async {
    final map = _map;
    if (map == null) return;
    _layersReady = false;
    _layers.resetState();
    await _layers.addTo(map);
    _layersReady = true;
    _pushFrame();
  }

  Future<void> _pushFrame() async {
    final map = _map;
    if (map == null || !_layersReady) return;
    if (_pushing) {
      _pushAgain = true;
      return;
    }
    _pushing = true;
    try {
      do {
        _pushAgain = false;
        final head = _head;
        final pulse = (_pulseClock.elapsedMilliseconds % 1600) / 1600;
        await _layers.showProgress(
          map,
          head,
          complete: _complete,
          pulse: pulse,
        );
        _shownHead = head;
        if (_follow) _moveFollowCamera();
      } while (_pushAgain && mounted && _layersReady);
    } catch (_) {
      // Changement de fond en cours : les couches seront recréées.
    } finally {
      _pushing = false;
    }
  }

  void _onReplayTick() {
    if (_follow) {
      final target = _track.bearingAt(_head, lookAhead: 10);
      // Interpolation d'angle pour une rotation douce de la caméra.
      final delta = ((target - _bearing + 540) % 360) - 180;
      _bearing = (_bearing + delta * 0.08) % 360;
    }
    _pushFrame();
    setState(() {});
  }

  /// Une consigne toutes les 200 ms au plus, que MapLibre anime lui-même :
  /// bien plus léger qu'un déplacement à chaque image.
  void _moveFollowCamera() {
    if (_cameraClock.elapsedMilliseconds < 200) return;
    _cameraClock.reset();
    _map?.animateCamera(
      ml.CameraUpdate.newCameraPosition(_followCamera()),
      duration: const Duration(milliseconds: 300),
    );
  }

  /// Le replay ralentit en caméra embarquée pour profiter de la vue 3D.
  Duration get _replayDuration => Duration(seconds: _follow ? 45 : 16);

  void _togglePlay() {
    if (_replay.isAnimating) {
      _replay.stop();
    } else {
      if (_complete) _replay.value = 0;
      _bearing = _track.bearingAt(_head, lookAhead: 10);
      _replay.duration = _replayDuration;
      _replay.forward();
    }
    setState(() {});
  }

  void _toggleFollow() {
    setState(() => _follow = !_follow);
    if (_replay.isAnimating) {
      _replay.duration = _replayDuration;
      _replay.forward();
    }
    if (_follow) {
      _shownHead = _head;
      _bearing = _track.bearingAt(_head, lookAhead: 10);
      _map?.animateCamera(
        ml.CameraUpdate.newCameraPosition(_followCamera()),
        duration: const Duration(milliseconds: 1200),
      );
    } else {
      _fitRoute();
    }
  }

  void _fitRoute() {
    setState(() => _follow = false);
    _map?.animateCamera(
      ml.CameraUpdate.newCameraPosition(_overviewCamera()),
      duration: const Duration(milliseconds: 900),
    );
  }

  Future<void> _cycleStyle() async {
    final next = MapStyle.values[(_style.index + 1) % MapStyle.values.length];
    setState(() => _style = next);
    final style = await next.load();
    _layersReady = false;
    await _map?.setStyle(style);
  }

  @override
  Widget build(BuildContext context) {
    final head = _head;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              _viewport = constraints.biggest;
              return FutureBuilder(
                future: _initialStyle,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.expand();
                  return Listener(
                    // Toucher la carte reprend la main sur la caméra.
                    onPointerDown: (_) {
                      if (_follow) setState(() => _follow = false);
                    },
                    child: ml.MapLibreMap(
                      styleString: snapshot.data!,
                      initialCameraPosition: _overviewCamera(),
                      compassEnabled: false,
                      attributionButtonPosition:
                          ml.AttributionButtonPosition.topLeft,
                      attributionButtonMargins: math.Point(
                        8,
                        MediaQuery.paddingOf(context).top + 84,
                      ),
                      onMapCreated: (controller) => _map = controller,
                      onStyleLoadedCallback: _onStyleLoaded,
                    ),
                  );
                },
              );
            },
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
            onPressed: _fitRoute,
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
