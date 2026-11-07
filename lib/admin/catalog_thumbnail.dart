/// Builds catalog thumbnails with the platform's fastest available encoder.
///
/// On the web the browser decodes and scales the photo natively (canvas), so
/// the Flutter UI thread never runs a multi-megabyte pixel conversion. Other
/// platforms return `null` and keep using the isolate-based Dart encoder.
library;

export 'catalog_thumbnail_stub.dart'
    if (dart.library.js_interop) 'catalog_thumbnail_web.dart';
