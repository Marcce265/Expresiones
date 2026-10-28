import 'dart:typed_data';

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
    await _client.rpc(
      'admin_save_catalog_family',
      params: {'payload': payload},
    );
  }

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
