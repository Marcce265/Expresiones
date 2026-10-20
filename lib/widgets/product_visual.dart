import 'package:flutter/material.dart';

import '../models/catalog_models.dart';
import '../theme/app_theme.dart';

String? productFamilyHeroAsset(CatalogProduct product) => switch (product.id) {
  'limpiapipas-premium-8mm' => 'assets/images/family_heroes/limpiapipas.webp',
  'cinta-satinada-100m' => 'assets/images/family_heroes/cinta_satinada.webp',
  _ => null,
};

BoxFit productImageFit(CatalogProduct product, {ProductVariant? variant}) {
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
  });

  final String label;
  final String? imageAsset;
  final String? colorHex;
  final String categoryKey;
  final BoxFit fit;
  final double cropBottomFraction;
  final Alignment alignment;

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
      final Widget image;
      if (asset.startsWith('http://') || asset.startsWith('https://')) {
        image = Image.network(
          asset,
          fit: fit,
          alignment: alignment,
          filterQuality: FilterQuality.high,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, _, _) =>
              _Fallback(accent: accent, icon: icon, label: label),
        );
      } else {
        image = Image.asset(
          asset,
          fit: fit,
          alignment: alignment,
          filterQuality: FilterQuality.high,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, _, _) =>
              _Fallback(accent: accent, icon: icon, label: label),
        );
      }

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
