import 'package:geolocator/geolocator.dart';

/// Où en est l'accès au GPS.
enum GpsAccess {
  granted,

  /// Jamais demandé : expliquer d'abord, puis demander.
  needsRequest,

  /// Refusé définitivement : seul le passage par les réglages débloque.
  deniedForever,

  /// La localisation est coupée sur le téléphone.
  serviceOff,
}

GpsAccess _fromPermission(LocationPermission permission) =>
    switch (permission) {
      LocationPermission.always ||
      LocationPermission.whileInUse => GpsAccess.granted,
      LocationPermission.deniedForever => GpsAccess.deniedForever,
      LocationPermission.denied ||
      LocationPermission.unableToDetermine => GpsAccess.needsRequest,
    };

Future<GpsAccess> checkGpsAccess() async {
  if (!await Geolocator.isLocationServiceEnabled()) return GpsAccess.serviceOff;
  return _fromPermission(await Geolocator.checkPermission());
}

/// Affiche la demande du système. À n'appeler qu'après avoir expliqué
/// pourquoi on en a besoin.
Future<GpsAccess> requestGpsAccess() async =>
    _fromPermission(await Geolocator.requestPermission());
