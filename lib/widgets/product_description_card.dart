import 'package:flutter/material.dart';

import '../models/catalog_models.dart';
import '../theme/app_theme.dart';

/// Family-level description shared by every option of a product.
///
/// A family stores a single description in Supabase, so the card is rendered
/// once for all of its variants instead of repeating the same copy per color
/// or presentation. Products without variants keep using it on their detail
/// screen exactly as before.
class ProductDescriptionCard extends StatelessWidget {
  const ProductDescriptionCard({
    super.key,
    required this.product,
    this.compact = false,
  });

  final CatalogProduct product;

  /// Slightly denser padding and corners for the catalog family overview.
  final bool compact;

  static const _hiddenAttributeKeys = {
    'cropbottom',
    'catalogindex',
    'palettenumber',
    'sourceimage',
    'imagesource',
  };

  @override
  Widget build(BuildContext context) {
    final radius = compact ? 20.0 : 24.0;
    final padding = compact ? 18.0 : 24.0;
    final badges = _badges();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Descripción del producto',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontFamily: 'PlayfairDisplay',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Línea ${product.category.label} · Expresiones',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            product.description.isNotEmpty
                ? product.description
                : 'Elaborado artesanalmente con materiales seleccionados de la más alta calidad para garantizar acabados impecables.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.ink,
              height: 1.55,
            ),
          ),
          if (badges.isNotEmpty) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final badge in badges)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.canvas,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<String> _badges() {
    final entries = product.attributes.entries.where((entry) {
      final key = entry.key.toLowerCase();
      if (key.startsWith('merged') ||
          _hiddenAttributeKeys.contains(key)) {
        return false;
      }
      return entry.value.trim().isNotEmpty;
    });

    return [
      for (final entry in entries) _formatBadge(entry.key, entry.value),
    ];
  }

  String _formatBadge(String key, String value) {
    final normalizedKey = key.toLowerCase();
    if (normalizedKey == 'assetcount') {
      final count = product.variants.isNotEmpty
          ? product.variants.where((v) => v.isActive).length.toString()
          : value.trim();
      return 'OPCIONES: $count ${count == '1' ? 'TONO' : 'TONOS'}';
    }
    if (normalizedKey == 'cataloggroup') {
      return 'SECCIÓN: ${value.toUpperCase()}';
    }
    return '${key.toUpperCase()}: $value';
  }
}
