import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:image/image.dart' as image_lib;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/catalog_repository.dart';
import '../models/catalog_models.dart';

/// Supabase catalog access used exclusively by the authenticated admin portal.
///
/// RLS requires both an administrator account and an AAL2 (TOTP) session for
/// every mutation; hiding the portal URL is never considered authorization.
class AdminCatalogRepository {
  AdminCatalogRepository({required SupabaseClient client})
    : _client = client,
      _reader = CatalogRepository(client: client);

  final SupabaseClient _client;
  final CatalogRepository _reader;

  SupabaseClient get client => _client;

  Stream<List<CatalogProduct>> watchProducts() =>
      _reader.watchProducts(includeInactive: true);

  Future<void> createProduct({
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    final id = normalizedDocumentId(documentId);
    if (id.isEmpty) {
      throw const FormatException('El producto necesita un identificador.');
    }
    final existing = await _client
        .from('families')
        .select('id')
        .eq('slug', id)
        .maybeSingle();
    if (existing != null) {
      throw StateError('Ya existe un producto con el código $id.');
    }
    await _saveFamily({'id': id, ...data});
  }

  Future<void> updateProduct(
    String productId,
    Map<String, dynamic> completeProduct,
  ) {
    return _saveFamily({'id': productId, ...completeProduct});
  }

  Future<void> setProductActive(String productId, bool active) {
    return _client
        .from('families')
        .update({'active': active})
        .eq('slug', productId);
  }

  Future<void> deleteProduct(String productId) async {
    await _client.rpc(
      'admin_delete_catalog_family',
      params: {'family_slug': productId},
    );
  }

  Future<void> _saveFamily(Map<String, dynamic> payload) async {
    try {
      await _retryTransientSave(
        () => _client.rpc(
          'admin_save_catalog_family',
          params: {'payload': payload},
        ),
      );
      if (_containsImageDerivatives(payload)) {
        await _syncImageDerivatives(payload);
      }
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        throw FormatException(_duplicateSkuMessage(error));
      }
      rethrow;
    }
  }

  static bool _containsImageDerivatives(Map<String, dynamic> payload) {
    if (payload.containsKey('thumbnailUrl')) return true;
    final variants = payload['variants'];
    return variants is List &&
        variants.whereType<Map>().any(
          (variant) => variant.containsKey('thumbnailUrl'),
        );
  }

  /// Persists only derivatives that still match the canonical image written by
  /// the family RPC. The path equality guard prevents a slower concurrent save
  /// from attaching its thumbnail to a newer administrator's image.
  Future<void> _syncImageDerivatives(Map<String, dynamic> payload) async {
    final familySlug = '${payload['id'] ?? ''}'.trim();
    if (familySlug.isEmpty) return;
    final family = await _client
        .from('families')
        .select('id')
        .eq('slug', familySlug)
        .maybeSingle();
    final familyId = '${family?['id'] ?? ''}';
    if (familyId.isEmpty) return;

    final imagePath = '${payload['imageUrl'] ?? ''}'.trim();
    final thumbnailPath = '${payload['thumbnailUrl'] ?? ''}'.trim();
    if (imagePath.isNotEmpty && thumbnailPath.isNotEmpty) {
      await _retryTransientSave(
        () => _client
            .from('families')
            .update({
              'cover_detail_path': imagePath,
              'cover_thumb_path': thumbnailPath,
            })
            .eq('id', familyId)
            .eq('cover_path', imagePath),
      );
    }

    final variants = payload['variants'];
    if (variants is! List) return;
    for (final rawVariant in variants.whereType<Map>()) {
      final variant = rawVariant.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final variantSlug = '${variant['id'] ?? ''}'.trim();
      final variantImage = '${variant['imageUrl'] ?? ''}'.trim();
      final variantThumbnail = '${variant['thumbnailUrl'] ?? ''}'.trim();
      if (variantSlug.isEmpty ||
          variantImage.isEmpty ||
          variantThumbnail.isEmpty) {
        continue;
      }
      await _retryTransientSave(
        () => _client
            .from('variants')
            .update({
              'detail_path': variantImage,
              'thumb_path': variantThumbnail,
            })
            .eq('family_id', familyId)
            .eq('slug', variantSlug)
            .eq('image_path', variantImage),
      );
    }
  }

  /// Converts PostgreSQL's technical unique-index failure into an actionable
  /// message. A SKU identifies one catalog option globally, so silently
  /// weakening the database constraint would make carts and audit logs
  /// ambiguous.
  static String _duplicateSkuMessage(PostgrestException error) {
    final diagnostic = '${error.details ?? ''} ${error.message}';
    final match = RegExp(
      r'lower\(sku\)\)\s*=\s*\(([^)]+)\)',
      caseSensitive: false,
    ).firstMatch(diagnostic);
    final sku = match?.group(1)?.trim();
    final subject = sku == null || sku.isEmpty
        ? 'Ese código'
        : 'El código $sku';
    return '$subject ya está usado por otra opción del catálogo. '
        'Escribe un código diferente y vuelve a guardar.';
  }

  /// A per-product database lock serializes normal writes. This small retry
  /// only covers transient PostgreSQL contention, so successful saves still
  /// use exactly one request.
  Future<void> _retryTransientSave(Future<dynamic> Function() operation) async {
    for (var attempt = 0; ; attempt++) {
      try {
        await operation();
        return;
      } on PostgrestException catch (error) {
        if (attempt >= 2 || !_transientSaveCodes.contains(error.code)) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 120 << attempt));
      }
    }
  }

  static const _transientSaveCodes = {
    '40001', // serialization_failure
    '40P01', // deadlock_detected
    '55P03', // lock_not_available
  };

  /// Uploads a unique catalog asset and returns its bucket-relative path.
  Future<String> uploadCatalogImage({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    String folder = 'uploads',
  }) async {
    validateCatalogImageUpload(bytes: bytes, contentType: contentType);
    final path = buildCatalogImagePath(
      folder: folder,
      fileName: fileName,
      contentType: contentType,
      timestampMicros: DateTime.now().microsecondsSinceEpoch,
    );
    await _client.storage
        .from('catalog')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            cacheControl: catalogImageCacheSeconds,
            contentType: contentType,
            upsert: false,
          ),
        );
    return path;
  }

  /// Stores the untouched upload for product detail and a small derivative
  /// for catalog cards. Keeping the original bytes avoids an additional lossy
  /// encode on the image customers enlarge, while the thumbnail cuts normal
  /// catalog bandwidth substantially.
  Future<CatalogImageUpload> uploadCatalogImageSet({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    String folder = 'uploads',
  }) async {
    validateCatalogImageUpload(bytes: bytes, contentType: contentType);
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final detailPath = buildCatalogImagePath(
      folder: folder,
      fileName: fileName,
      contentType: contentType,
      timestampMicros: timestamp,
    );
    final thumbnailPath = buildCatalogImagePath(
      folder: '$folder/thumbnails',
      fileName: fileName,
      contentType: 'image/jpeg',
      timestampMicros: timestamp,
    );

    // `image` decodes and encodes pixels in Dart. Running that work while a
    // browser is handling a file-picker result made the administrative editor
    // feel frozen on phones. On native targets `compute` puts it in a worker
    // isolate. On the web we keep the original as the temporary card source:
    // this avoids a synchronous multi-megabyte conversion on the UI thread and
    // preserves the uploaded detail photo exactly.
    if (kIsWeb) {
      await _uploadCatalogObject(
        path: detailPath,
        bytes: bytes,
        contentType: contentType,
      );
      return CatalogImageUpload(
        detailPath: detailPath,
        thumbnailPath: detailPath,
      );
    }

    final thumbnailBytes = await compute(_buildCatalogThumbnail, bytes);
    await Future.wait([
      _uploadCatalogObject(
        path: detailPath,
        bytes: bytes,
        contentType: contentType,
      ),
      _uploadCatalogObject(
        path: thumbnailPath,
        bytes: thumbnailBytes,
        contentType: 'image/jpeg',
      ),
    ]);
    return CatalogImageUpload(
      detailPath: detailPath,
      thumbnailPath: thumbnailPath,
    );
  }

  Future<String> _uploadCatalogObject({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) {
    return _client.storage
        .from('catalog')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            cacheControl: catalogImageCacheSeconds,
            contentType: contentType,
            upsert: false,
          ),
        );
  }

  static const maximumCatalogImageBytes = 8 * 1024 * 1024;
  static const catalogImageCacheSeconds = '31536000';
  static const allowedCatalogImageTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
  };

  static void validateCatalogImageUpload({
    required Uint8List bytes,
    required String contentType,
  }) {
    if (bytes.isEmpty) throw const FormatException('La imagen está vacía.');
    if (bytes.length > maximumCatalogImageBytes) {
      throw const FormatException('La imagen no puede superar 8 MB.');
    }
    if (!allowedCatalogImageTypes.contains(contentType)) {
      throw const FormatException('Usa una imagen JPG, PNG o WebP.');
    }
  }

  /// Builds a deterministic, bucket-relative destination for an upload.
  /// Keeping folder separators makes assets easy to inspect and prevents a
  /// public Storage URL from ever being used as the database value.
  static String buildCatalogImagePath({
    required String folder,
    required String fileName,
    required String contentType,
    required int timestampMicros,
  }) {
    if (!allowedCatalogImageTypes.contains(contentType)) {
      throw const FormatException('Usa una imagen JPG, PNG o WebP.');
    }
    final safeFolder = folder
        .split(RegExp(r'[\\/]+'))
        .map(normalizedDocumentId)
        .where((segment) => segment.isNotEmpty)
        .join('/');
    final safeBase = normalizedDocumentId(
      fileName.replaceFirst(RegExp(r'\.[^.]+$'), ''),
    );
    final extension = switch (contentType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final directory = safeFolder.isEmpty ? 'uploads' : safeFolder;
    final base = safeBase.isEmpty ? 'imagen' : safeBase;
    return '$directory/$timestampMicros-$base.$extension';
  }

  static String normalizedDocumentId(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}

/// Top-level so Flutter can run it in a background isolate on native builds.
Uint8List _buildCatalogThumbnail(Uint8List bytes) {
  final decoded = image_lib.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('No se pudo leer la imagen seleccionada.');
  }
  final oriented = image_lib.bakeOrientation(decoded);
  const maximumThumbnailEdge = 640;
  final image_lib.Image thumbnail;
  if (oriented.width <= maximumThumbnailEdge &&
      oriented.height <= maximumThumbnailEdge) {
    thumbnail = oriented;
  } else if (oriented.width >= oriented.height) {
    thumbnail = image_lib.copyResize(
      oriented,
      width: maximumThumbnailEdge,
      interpolation: image_lib.Interpolation.average,
    );
  } else {
    thumbnail = image_lib.copyResize(
      oriented,
      height: maximumThumbnailEdge,
      interpolation: image_lib.Interpolation.average,
    );
  }
  return Uint8List.fromList(image_lib.encodeJpg(thumbnail, quality: 84));
}

class CatalogImageUpload {
  const CatalogImageUpload({
    required this.detailPath,
    required this.thumbnailPath,
  });

  final String detailPath;
  final String thumbnailPath;
}
