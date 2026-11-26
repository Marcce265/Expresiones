import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class DeviceLocationService {
  const DeviceLocationService();

  Future<Position> currentPosition() async {
    if (kIsWeb) return _browserPosition();
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationPermissionException(
        'Activa la ubicación del dispositivo y vuelve a intentarlo.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationPermissionException(
        'Sin permiso de ubicación, puedes seguir buscando agencias por ciudad.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationPermissionException(
        'El permiso está bloqueado. Habilítalo en los ajustes del dispositivo.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }

  Future<Position> _browserPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } on PermissionDeniedException {
      throw const LocationPermissionException(
        'Permite la ubicación en tu navegador o busca por ciudad.',
      );
    }
  }
}

class LocationPermissionException implements Exception {
  const LocationPermissionException(this.message);

  final String message;

  @override
  String toString() => message;
}
