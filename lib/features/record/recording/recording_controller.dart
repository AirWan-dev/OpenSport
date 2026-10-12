import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:opensport/core/models/sport.dart';
import 'package:opensport/features/activities/data/activity_providers.dart';
import 'package:opensport/features/activities/models/track.dart';

import 'gps_filter.dart';

enum RecordingPhase { idle, countdown, recording, paused }

@immutable
class RecordingState {
  const RecordingState({
    this.phase = RecordingPhase.idle,
    this.sport = Sport.run,
    this.activityId,
    this.countdown = 0,
    this.pointCount = 0,
    this.distance = 0,
    this.speed = 0,
    this.accuracy,
  });

  final RecordingPhase phase;
  final Sport sport;

  /// Activité en base, créée au départ réel (après le compte à rebours).
  final int? activityId;
  final int countdown;

  /// Nombre de points retenus ; change à chaque nouveau point.
  final int pointCount;

  /// Distance parcourue en mètres (pauses exclues).
  final double distance;

  /// Vitesse actuelle lissée, en m/s.
  final double speed;

  /// Précision du dernier signal GPS reçu, en mètres.
  final double? accuracy;

  bool get isActive =>
      phase == RecordingPhase.recording || phase == RecordingPhase.paused;

  RecordingState copyWith({
    RecordingPhase? phase,
    Sport? sport,
    int? activityId,
    int? countdown,
    int? pointCount,
    double? distance,
    double? speed,
    double? accuracy,
  }) {
    return RecordingState(
      phase: phase ?? this.phase,
      sport: sport ?? this.sport,
      activityId: activityId ?? this.activityId,
      countdown: countdown ?? this.countdown,
      pointCount: pointCount ?? this.pointCount,
      distance: distance ?? this.distance,
      speed: speed ?? this.speed,
      accuracy: accuracy ?? this.accuracy,
    );
  }
}

final recordingProvider = NotifierProvider<RecordingController, RecordingState>(
  RecordingController.new,
);

/// Pilote l'enregistrement d'une sortie : GPS, chronomètre, pauses et
/// écriture de chaque point en base au fil de l'eau.
class RecordingController extends Notifier<RecordingState> {
  StreamSubscription<Position>? _gps;
  Timer? _countdownTimer;
  final _moving = Stopwatch();
  GpsFilter? _filter;
  final List<TrackPoint> _points = [];
  int _segment = 0;

  /// Derniers points (heure, distance cumulée) pour l'allure actuelle.
  final List<({DateTime time, double distance})> _recent = [];

  static const _distance = Distance(roundResult: false);

  @override
  RecordingState build() {
    ref.onDispose(_stopGps);
    return const RecordingState();
  }

  /// Temps en mouvement (pauses exclues).
  Duration get elapsed => _moving.elapsed;

  /// Points retenus depuis le départ, dans l'ordre.
  List<TrackPoint> get points => List.unmodifiable(_points);

  void selectSport(Sport sport) {
    if (state.phase == RecordingPhase.idle) {
      state = state.copyWith(sport: sport);
    }
  }

  /// Lance le GPS puis un compte à rebours de 3 secondes, le temps que le
  /// signal se stabilise. L'accès au GPS doit déjà être accordé.
  void start() {
    if (state.phase != RecordingPhase.idle) return;
    _filter = GpsFilter(sport: state.sport);
    _points.clear();
    _recent.clear();
    _segment = 0;
    _moving.reset();
    _startGps();

    state = RecordingState(
      phase: RecordingPhase.countdown,
      sport: state.sport,
      countdown: 3,
    );
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final next = state.countdown - 1;
      if (next > 0) {
        state = state.copyWith(countdown: next);
      } else {
        timer.cancel();
        _beginRecording();
      }
    });
  }

  /// Annule pendant le compte à rebours.
  void cancelCountdown() {
    _countdownTimer?.cancel();
    _stopGps();
    state = RecordingState(sport: state.sport);
  }

  Future<void> _beginRecording() async {
    final id = await ref
        .read(activityRepositoryProvider)
        .startRecording(state.sport, DateTime.now());
    _moving.start();
    state = state.copyWith(phase: RecordingPhase.recording, activityId: id);
  }

  void pause() {
    if (state.phase != RecordingPhase.recording) return;
    _moving.stop();
    state = state.copyWith(phase: RecordingPhase.paused, speed: 0);
  }

  void resume() {
    if (state.phase != RecordingPhase.paused) return;
    // Nouveau tronçon : le trajet fait pendant la pause ne comptera pas.
    _segment++;
    _filter?.reset();
    _recent.clear();
    _moving.start();
    state = state.copyWith(phase: RecordingPhase.recording);
  }

  /// Arrête l'enregistrement et renvoie l'activité à compléter (titre,
  /// notes), ou null si rien n'a démarré.
  int? stop() {
    final id = state.activityId;
    _moving.stop();
    _stopGps();
    state = RecordingState(sport: state.sport);
    return id;
  }

  /// Vitesse sur les 10 dernières secondes, calculée à partir des
  /// positions : la vitesse annoncée par le GPS est parfois fausse.
  double _recentSpeed() {
    final now = _recent.last.time;
    _recent.removeWhere(
      (r) => now.difference(r.time) > const Duration(seconds: 10),
    );
    if (_recent.length < 2) return state.speed;
    final seconds = now.difference(_recent.first.time).inMilliseconds / 1000;
    if (seconds <= 0) return state.speed;
    return (_recent.last.distance - _recent.first.distance) / seconds;
  }

  // ------------------------------------------------------------------ GPS

  LocationSettings get _settings {
    if (kIsWeb) {
      return const LocationSettings(accuracy: LocationAccuracy.best);
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSettings(
        accuracy: LocationAccuracy.best,
        intervalDuration: const Duration(seconds: 1),
        useMSLAltitude: true,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'OpenSport enregistre ta sortie',
          notificationText: 'Le GPS reste actif, même écran éteint.',
          notificationChannelName: 'Enregistrement GPS',
          enableWakeLock: true,
          setOngoing: true,
        ),
      ),
      TargetPlatform.iOS => AppleSettings(
        accuracy: LocationAccuracy.best,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      ),
      _ => const LocationSettings(accuracy: LocationAccuracy.best),
    };
  }

  void _startGps() {
    _gps?.cancel();
    _gps = Geolocator.getPositionStream(locationSettings: _settings)
        .listen(_onPosition, onError: (_) {});
  }

  void _stopGps() {
    _countdownTimer?.cancel();
    _gps?.cancel();
    _gps = null;
  }

  void _onPosition(Position p) {
    if (state.phase != RecordingPhase.recording) {
      // Avant le départ et en pause : on affiche seulement la qualité.
      state = state.copyWith(accuracy: p.accuracy);
      return;
    }

    final sample = GpsSample(
      position: LatLng(p.latitude, p.longitude),
      accuracy: p.accuracy,
      time: p.timestamp,
      altitude: p.altitude,
    );
    if (_filter!.check(sample) != null) {
      state = state.copyWith(accuracy: p.accuracy);
      return;
    }

    final point = TrackPoint(
      sample.position,
      p.altitude,
      _moving.elapsed,
      segment: _segment,
    );
    final previous = _points.isEmpty ? null : _points.last;
    var distance = state.distance;
    if (previous != null && previous.segment == _segment) {
      distance += _distance(previous.position, point.position);
    }
    _recent.add((time: p.timestamp, distance: distance));
    _points.add(point);
    final speed = _recentSpeed();

    ref
        .read(activityRepositoryProvider)
        .addPoint(
          state.activityId!,
          _points.length - 1,
          point,
          accuracy: p.accuracy,
        );

    state = state.copyWith(
      pointCount: _points.length,
      distance: distance,
      speed: speed,
      accuracy: p.accuracy,
    );
  }
}
