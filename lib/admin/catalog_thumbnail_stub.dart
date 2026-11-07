import 'dart:typed_data';

/// Non-web fallback: native builds generate thumbnails in a worker isolate.
Future<Uint8List?> buildBrowserThumbnail(
  Uint8List bytes, {
  required String contentType,
  int maxEdge = 640,
  double quality = .84,
}) async => null;
