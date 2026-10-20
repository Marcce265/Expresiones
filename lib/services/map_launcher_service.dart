import 'package:url_launcher/url_launcher.dart';

/// Servicio de utilidad para abrir aplicaciones de mapas con coordenadas geográficas.
abstract final class MapLauncherService {
  /// Construye un URI con esquema `geo:` para aplicaciones nativas (Android/iOS).
  static Uri buildGeoUri({
    required double latitude,
    required double longitude,
    String? label,
  }) {
    final cleanLabel = label?.trim() ?? '';
    final query = cleanLabel.isNotEmpty
        ? '$latitude,$longitude(${Uri.encodeComponent(cleanLabel)})'
        : '$latitude,$longitude';
    return Uri.parse('geo:$latitude,$longitude?q=$query');
  }

  /// Construye un URI HTTPS de Google Maps como fallback web y de escritorio.
  static Uri buildWebMapUri({
    required double latitude,
    required double longitude,
  }) {
    return Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
  }

  /// Intenta abrir la app nativa de mapas con `geo:`, y si no está disponible
  /// (como en web o emulador sin Google Maps), recurre al enlace web en navegador.
  static Future<bool> openCoordinates({
    required double latitude,
    required double longitude,
    String? label,
  }) async {
    final geoUri = buildGeoUri(
      latitude: latitude,
      longitude: longitude,
      label: label,
    );
    final webUri = buildWebMapUri(
      latitude: latitude,
      longitude: longitude,
    );

    if (await canLaunchUrl(geoUri)) {
      return launchUrl(geoUri);
    }
    return launchUrl(webUri, mode: LaunchMode.externalApplication);
  }
}
