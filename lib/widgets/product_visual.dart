import 'package:flutter/material.dart';

import '../models/catalog_models.dart';
import '../theme/app_theme.dart';
import 'skeleton_loader.dart';

String? productFamilyHeroAsset(CatalogProduct product) => switch (product.id) {
  'limpiapipas-premium-8mm' => 'assets/images/family_heroes/limpiapipas.webp',
  'cinta-satinada-100m' =>
    'assets/images/family_heroes/cinta_satinada_todos_colores.webp',
  'papel-coreano-impermeable' || 'papel-coreano' =>
    'assets/images/family_heroes/papel_coreano.webp',
  _ => product.category == ProductCategory.koreanPaper
      ? 'assets/images/family_heroes/papel_coreano.webp'
      : null,
};

/// Image shown for a family card or overview.
///
/// The administrator's current cover is authoritative. Editorial assets are
/// only offline fallbacks for seed products that do not publish a cover.
String? productFamilyCoverImage(CatalogProduct product) =>
    product.previewImageUrl ?? productFamilyHeroAsset(product);

BoxFit productImageFit(CatalogProduct product, {ProductVariant? variant}) {
  if (product.category == ProductCategory.koreanPaper) {
    return BoxFit.cover;
  }

  if (product.id == 'limpiapipas-premium-8mm' && variant != null) {
    return BoxFit.cover;
  }

  if (product.id == 'brochetas') {
    return BoxFit.contain;
  }

  if (product.id == 'floratape' && variant?.id == 'catalogo-134') {
    return BoxFit.contain;
  }

  final catalogIndex = int.tryParse(variant?.attributes['catalogIndex'] ?? '');
  if (product.id == 'frases-en-vinil' &&
      catalogIndex != null &&
      catalogIndex >= 157 &&
      catalogIndex <= 170) {
    return BoxFit.contain;
  }

  return BoxFit.cover;
}

double productImageCropBottom(
  CatalogProduct product, {
  ProductVariant? variant,
}) {
  if (product.id != 'cinta-satinada-100m') return 0;
  return double.tryParse(variant?.attributes['cropBottom'] ?? '') ?? 0;
}

Alignment productImageAlignment(CatalogProduct product) =>
    product.id == 'cinta-satinada-100m'
    ? Alignment.topCenter
    : Alignment.center;

class ProductVisual extends StatelessWidget {
  const ProductVisual({
    super.key,
    required this.label,
    this.imageAsset,
    this.colorHex,
    this.categoryKey = 'materials',
    this.fit = BoxFit.cover,
    this.cropBottomFraction = 0,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.medium,
    this.decodeToLayout = false,
  });

  final String label;
  final String? imageAsset;
  final String? colorHex;
  final String categoryKey;
  final BoxFit fit;
  final double cropBottomFraction;
  final Alignment alignment;
  final FilterQuality filterQuality;

  /// Decodes the photo near the size it occupies on screen instead of at its
  /// full camera resolution.
  ///
  /// A 12 MP phone photo needs about 48 MB of graphics memory when decoded in
  /// full, even if it is drawn 250 px wide. Bounding the decode keeps editors
  /// with many photos smooth. The stored file is never modified.
  final bool decodeToLayout;

  /// Longest decoded edge for the current layout, bucketed to 128 px so small
  /// layout changes reuse the cached decode. `cover` needs headroom because the
  /// short side of the photo must still fill the box.
  int? _decodeEdge(BoxConstraints constraints, double devicePixelRatio) {
    final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
    final height = constraints.maxHeight.isFinite ? constraints.maxHeight : 0.0;
    final edge = width > height ? width : height;
    if (edge <= 0) return null;
    final headroom = fit == BoxFit.cover ? 1.6 : 1.0;
    final pixels = edge * devicePixelRatio * headroom;
    final bucketed = ((pixels / 128).ceil() * 128).clamp(256, 2048);
    return bucketed;
  }

  Color get accent {
    final normalized = colorHex?.replaceAll('#', '');
    if (normalized != null &&
        (normalized.length == 6 || normalized.length == 8)) {
      final value = int.tryParse(normalized, radix: 16);
      if (value != null) {
        return Color(normalized.length == 6 ? 0xFF000000 | value : value);
      }
    }
    return switch (categoryKey) {
      'bouquets' => const Color(0xFFE9A3B3),
      'gifts' => const Color(0xFFD9B36D),
      _ => const Color(0xFF8BA17D),
    };
  }

  IconData get icon => switch (categoryKey) {
    'bouquets' => Icons.local_florist_outlined,
    'gifts' => Icons.card_giftcard_outlined,
    _ => Icons.auto_awesome_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final asset = imageAsset;
    if (asset != null && asset.isNotEmpty) {
      final ImageProvider provider =
          asset.startsWith('http://') || asset.startsWith('https://')
          ? NetworkImage(asset)
          : AssetImage(asset);

      Widget buildImage(ImageProvider imageProvider) => Image(
        image: imageProvider,
        fit: fit,
        alignment: alignment,
        // Medium keeps product textures crisper than the high-quality
        // bicubic filter when a large photo is scaled down on screen.
        filterQuality: filterQuality,
        gaplessPlayback: true,
        width: double.infinity,
        height: double.infinity,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return const ProductVisualSkeleton();
        },
        errorBuilder: (_, _, _) =>
            _Fallback(accent: accent, icon: icon, label: label),
      );

      final Widget image = decodeToLayout
          ? LayoutBuilder(
              builder: (context, constraints) {
                final edge = _decodeEdge(
                  constraints,
                  MediaQuery.devicePixelRatioOf(context),
                );
                return buildImage(
                  edge == null
                      ? provider
                      : ResizeImage(
                          provider,
                          width: edge,
                          height: edge,
                          policy: ResizeImagePolicy.fit,
                        ),
                );
              },
            )
          : buildImage(provider);

      final visual = cropBottomFraction > 0
          ? LayoutBuilder(
              builder: (context, constraints) {
                final visibleFraction = 1 - cropBottomFraction;
                return ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight / visibleFraction,
                      child: image,
                    ),
                  ),
                );
              },
            )
          : image;

      return Semantics(image: true, label: label, child: visual);
    }
    return _Fallback(accent: accent, icon: icon, label: label);
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({
    required this.accent,
    required this.icon,
    required this.label,
  });

  final Color accent;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(accent, Colors.white, .72)!,
              Color.lerp(accent, AppColors.canvas, .28)!,
            ],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              right: -22,
              top: -20,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .26),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: -18,
              bottom: -26,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .17),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Icon(icon, size: 52, color: Color.lerp(accent, AppColors.ink, .25)),
          ],
        ),
      ),
    );
  }
}
