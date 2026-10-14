import 'package:flutter/material.dart';

import '../models/catalog_models.dart';
import '../theme/app_theme.dart';

BoxFit productImageFit(CatalogProduct product) =>
    product.id == 'limpiapipas-premium-8mm' ? BoxFit.contain : BoxFit.cover;

class ProductVisual extends StatelessWidget {
  const ProductVisual({
    super.key,
    required this.label,
    this.imageAsset,
    this.colorHex,
    this.categoryKey = 'materials',
    this.fit = BoxFit.cover,
  });

  final String label;
  final String? imageAsset;
  final String? colorHex;
  final String categoryKey;
  final BoxFit fit;

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
      if (asset.startsWith('http://') || asset.startsWith('https://')) {
        return Semantics(
          image: true,
          label: label,
          child: Image.network(
            asset,
            fit: fit,
            filterQuality: FilterQuality.high,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, _, _) =>
                _Fallback(accent: accent, icon: icon, label: label),
          ),
        );
      }
      return Semantics(
        image: true,
        label: label,
        child: Image.asset(
          asset,
          fit: fit,
          filterQuality: FilterQuality.high,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, _, _) =>
              _Fallback(accent: accent, icon: icon, label: label),
        ),
      );
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
