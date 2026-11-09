import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Creates a lightweight JPEG thumbnail using the browser's native image
/// pipeline.
///
/// The original upload is never modified: this only produces the small copy
/// used by catalog cards and the admin editor. Decoding happens off the main
/// thread (`HTMLImageElement.decode`) and EXIF orientation is honoured by the
/// browser. Large photos are halved step by step before the final resize so the
/// thumbnail stays sharp instead of aliased. Returns `null` when the browser
/// cannot read the image, letting the caller fall back gracefully.
Future<Uint8List?> buildBrowserThumbnail(
  Uint8List bytes, {
  required String contentType,
  int maxEdge = 640,
  double quality = .84,
}) async {
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: contentType),
  );
  final url = web.URL.createObjectURL(blob);
  try {
    final image = web.HTMLImageElement()
      ..decoding = 'async'
      ..src = url;
    await image.decode().toDart;

    final width = image.naturalWidth;
    final height = image.naturalHeight;
    if (width <= 0 || height <= 0) return null;

    final scale = math.min(1.0, maxEdge / math.max(width, height));
    final targetWidth = math.max(1, (width * scale).round());
    final targetHeight = math.max(1, (height * scale).round());

    web.CanvasImageSource source = image;
    var sourceWidth = width;
    var sourceHeight = height;
    while (sourceWidth > targetWidth * 2 && sourceHeight > targetHeight * 2) {
      final halfWidth = (sourceWidth / 2).round();
      final halfHeight = (sourceHeight / 2).round();
      source = _draw(source, sourceWidth, sourceHeight, halfWidth, halfHeight);
      sourceWidth = halfWidth;
      sourceHeight = halfHeight;
    }
    final canvas = _draw(
      source,
      sourceWidth,
      sourceHeight,
      targetWidth,
      targetHeight,
    );

    final encoded = Completer<web.Blob?>();
    canvas.toBlob(
      ((web.Blob? webpBlob) {
        if (webpBlob != null) {
          encoded.complete(webpBlob);
        } else {
          canvas.toBlob(
            ((web.Blob? jpegBlob) => encoded.complete(jpegBlob)).toJS,
            'image/jpeg',
            quality.toJS,
          );
        }
      }).toJS,
      'image/webp',
      quality.toJS,
    );
    final thumbnail = await encoded.future;
    if (thumbnail == null) return null;
    final buffer = await thumbnail.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  } catch (_) {
    return null;
  } finally {
    web.URL.revokeObjectURL(url);
  }
}

web.HTMLCanvasElement _draw(
  web.CanvasImageSource source,
  int sourceWidth,
  int sourceHeight,
  int width,
  int height,
) {
  final canvas = web.HTMLCanvasElement()
    ..width = width
    ..height = height;
  final context = canvas.context2D
    ..imageSmoothingEnabled = true
    ..imageSmoothingQuality = 'high'
    // JPEG has no alpha: paint white so transparent PNGs don't turn black.
    ..fillStyle = '#FFFFFF'.toJS;
  context
    ..fillRect(0, 0, width, height)
    ..drawImage(source, 0, 0, sourceWidth, sourceHeight, 0, 0, width, height);
  return canvas;
}
