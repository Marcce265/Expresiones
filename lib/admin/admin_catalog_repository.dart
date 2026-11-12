import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:image/image.dart' as image_lib;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/catalog_repository.dart';
import '../models/catalog_models.dart';
import 'catalog_thumbnail.dart';

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
    await _saveFamily({'id': id, ...data, 'sortOrder': await _nextSortOrder()});
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

  /// New products always land at the end. This keeps the merchant from having
  /// to invent a number and prevents a fresh product from jumping to the front.
  Future<int> _nextSortOrder() async {
    final row = await _client
        .from('families')
        .select('sort_order')
        .order('sort_order', ascending: false)
        .limit(1)
        .maybeSingle();
    final current = row?['sort_order'];
    final value = current is num
        ? current.toInt()
        : int.tryParse('$current') ?? 0;
    return value + 10;
  }

  /// Reordering only touches the moved row. The admin grid computes a value
  /// between its neighbours, so a normal move is one small request instead of
  /// rewriting every product in the catalog.
  Future<void> updateProductSortOrder(String productId, int sortOrder) {
    return _client
        .from('families')
        .update({'sort_order': sortOrder})
        .eq('slug', productId);
  }

  /// Used only when the integer gaps between neighbours are exhausted. Updates
  /// are sent in small batches so a rebalance does not flood Supabase.
  Future<void> updateProductSortOrders(Map<String, int> sortOrders) async {
    const batchSize = 8;
    final entries = sortOrders.entries.toList(growable: false);
    for (var start = 0; start < entries.length; start += batchSize) {
      final end = start + batchSize > entries.length
          ? entries.length
          : start + batchSize;
      await Future.wait([
        for (final entry in entries.sublist(start, end))
          updateProductSortOrder(entry.key, entry.value),
      ]);
    }
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
    Uint8List finalBytes = bytes;
    String finalContentType = contentType;
    if (kIsWeb) {
      final optimized = await buildBrowserThumbnail(
        bytes,
        contentType: contentType,
        maxEdge: 1200,
        quality: .88,
      );
      if (optimized != null) {
        finalBytes = optimized;
        finalContentType = 'image/webp';
      }
    }
    final path = buildCatalogImagePath(
      folder: folder,
      fileName: fileName,
      contentType: finalContentType,
      timestampMicros: DateTime.now().microsecondsSinceEpoch,
    );
    await _client.storage
        .from('catalog')
        .uploadBinary(
          path,
          finalBytes,
          fileOptions: FileOptions(
            cacheControl: catalogImageCacheSeconds,
            contentType: finalContentType,
            upsert: false,
          ),
        );
    return path;
  }

  /// Automatically optimizes camera photos and converts them to WebP.
  /// Large photos from phones are scaled down to max 1200px edge for detail
  /// and max 480px edge for thumbnails, preventing high memory usage and browser freezes.
  Future<CatalogImageUpload> uploadCatalogImageSet({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    String folder = 'uploads',
  }) async {
    validateCatalogImageUpload(bytes: bytes, contentType: contentType);
    final timestamp = DateTime.now().microsecondsSinceEpoch;

    if (kIsWeb) {
      final detailBytes = await buildBrowserThumbnail(
        bytes,
        contentType: contentType,
        maxEdge: 1200,
        quality: .88,
      );
      final thumbnailBytes = await buildBrowserThumbnail(
        bytes,
        contentType: contentType,
        maxEdge: 480,
        quality: .82,
      );

      final finalDetailBytes = detailBytes ?? bytes;
      final finalDetailContentType =
          detailBytes != null ? 'image/webp' : contentType;
      final detailPath = buildCatalogImagePath(
        folder: folder,
        fileName: fileName,
        contentType: finalDetailContentType,
        timestampMicros: timestamp,
      );

      final finalThumbnailBytes = thumbnailBytes ?? detailBytes ?? bytes;
      final finalThumbnailContentType =
          (thumbnailBytes != null || detailBytes != null)
              ? 'image/webp'
              : contentType;
      final thumbnailPath = buildCatalogImagePath(
        folder: '$folder/thumbnails',
        fileName: fileName,
        contentType: finalThumbnailContentType,
        timestampMicros: timestamp,
      );

      await Future.wait([
        _uploadCatalogObject(
          path: detailPath,
          bytes: finalDetailBytes,
          contentType: finalDetailContentType,
        ),
        _uploadCatalogObject(
          path: thumbnailPath,
          bytes: finalThumbnailBytes,
          contentType: finalThumbnailContentType,
        ),
      ]);
      return CatalogImageUpload(
        detailPath: detailPath,
        thumbnailPath: thumbnailPath,
      );
    }

    final detailBytes = await compute(_buildCatalogOptimizedDetail, bytes);
    final thumbnailBytes = await compute(_buildCatalogThumbnail, bytes);
    final detailPath = buildCatalogImagePath(
      folder: folder,
      fileName: fileName,
      contentType: 'image/jpeg',
      timestampMicros: timestamp,
    );
    final thumbnailPath = buildCatalogImagePath(
      folder: '$folder/thumbnails',
      fileName: fileName,
      contentType: 'image/jpeg',
      timestampMicros: timestamp,
    );
    await Future.wait([
      _uploadCatalogObject(
        path: detailPath,
        bytes: detailBytes,
        contentType: 'image/jpeg',
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
Uint8List _buildCatalogOptimizedDetail(Uint8List bytes) {
  final decoded = image_lib.decodeImage(bytes);
  if (decoded == null) return bytes;
  final oriented = image_lib.bakeOrientation(decoded);
  const maxEdge = 1200;
  if (oriented.width <= maxEdge && oriented.height <= maxEdge) {
    return Uint8List.fromList(image_lib.encodeJpg(oriented, quality: 88));
  }
  final image_lib.Image resized;
  if (oriented.width >= oriented.height) {
    resized = image_lib.copyResize(
      oriented,
      width: maxEdge,
      interpolation: image_lib.Interpolation.average,
    );
  } else {
    resized = image_lib.copyResize(
      oriented,
      height: maxEdge,
      interpolation: image_lib.Interpolation.average,
    );
  }
  return Uint8List.fromList(image_lib.encodeJpg(resized, quality: 88));
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
