import '../models/catalog_models.dart';

/// Keeps the image value saved by the admin separate from the image rendered
/// as its catalog preview.
///
/// Supabase can store a detail image and a smaller thumbnail for the same
/// product. Opening the editor should show the same thumbnail customers see,
/// while an unchanged save must preserve the detail image value. Selecting a
/// replacement intentionally unifies both values so the new asset is visible
/// immediately and can be persisted by the backend for every presentation.
class AdminImageDraft {
  AdminImageDraft({String? persistedValue, String? previewValue})
    : _persistedValue = canonicalStorageValue(persistedValue),
      _previewValue = _preferred(previewValue, persistedValue),
      _initialPersistedValue = canonicalStorageValue(persistedValue);

  factory AdminImageDraft.fromProduct(CatalogProduct? product) {
    return AdminImageDraft(
      persistedValue: product?.imageUrl ?? product?.thumbnailUrl,
      previewValue: product?.previewImageUrl,
    );
  }

  factory AdminImageDraft.fromVariant(ProductVariant variant) {
    return AdminImageDraft(
      persistedValue: variant.imageUrl ?? variant.thumbnailUrl,
      previewValue: variant.previewImageUrl,
    );
  }

  final String _initialPersistedValue;
  String _persistedValue;
  String _previewValue;

  String get persistedValue => _persistedValue;
  String get previewValue => _previewValue;
  bool get changed => _persistedValue != _initialPersistedValue;

  void replaceWith(String value) {
    final clean = canonicalStorageValue(value);
    _persistedValue = clean;
    _previewValue = clean;
  }

  /// Adds the image to a CRUD payload only after the administrator selected a
  /// replacement. Omitting the field lets the database preserve its canonical
  /// path and avoids writing a resolved public URL back into `cover_path` or
  /// `image_path` during an unrelated text/price edit.
  void writeReplacementTo(
    Map<String, dynamic> payload, {
    String key = 'imageUrl',
  }) {
    payload.remove(key);
    if (changed) payload[key] = _persistedValue;
  }

  /// Converts this project's public Supabase Storage URLs back to the
  /// bucket-relative value expected by the database. External URLs and bundled
  /// Flutter assets are deliberately preserved.
  static String canonicalStorageValue(String? value) {
    final clean = _clean(value);
    if (clean.isEmpty) return '';
    const storagePrefix = 'storage://catalog/';
    const bucketPrefix = 'catalog/';
    if (clean.startsWith(storagePrefix)) {
      return clean
          .substring(storagePrefix.length)
          .replaceFirst(RegExp(r'^/+'), '');
    }
    if (clean.startsWith(bucketPrefix)) {
      return clean
          .substring(bucketPrefix.length)
          .replaceFirst(RegExp(r'^/+'), '');
    }

    final uri = Uri.tryParse(clean);
    if (uri == null || !uri.hasScheme) return clean;
    final segments = uri.pathSegments;
    const marker = ['storage', 'v1', 'object', 'public', 'catalog'];
    for (var index = 0; index <= segments.length - marker.length; index++) {
      var matches = true;
      for (var offset = 0; offset < marker.length; offset++) {
        if (segments[index + offset] != marker[offset]) {
          matches = false;
          break;
        }
      }
      if (matches) {
        return segments.skip(index + marker.length).join('/');
      }
    }
    return clean;
  }

  static String _preferred(String? preview, String? persisted) {
    final cleanPreview = _clean(preview);
    return cleanPreview.isNotEmpty ? cleanPreview : _clean(persisted);
  }

  static String _clean(String? value) => value?.trim() ?? '';
}
