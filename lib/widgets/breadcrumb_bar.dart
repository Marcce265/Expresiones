import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BreadcrumbItem {
  const BreadcrumbItem({
    required this.label,
    this.onTap,
  });

  final String label;
  final VoidCallback? onTap;
}

/// Barra de ruta uniforme para todos los módulos de la tienda (sin "INICIO").
/// Mantiene el botón de retroceso redondeado, tipografía en mayúsculas a 13.5px,
/// espaciado de 0.8 y separadores chevron consistentes en toda la aplicación.
class AppBreadcrumbBar extends StatelessWidget {
  const AppBreadcrumbBar({
    super.key,
    required this.items,
    this.onBack,
    this.trailing,
  });

  final List<BreadcrumbItem> items;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Row(
        children: [
          if (onBack != null) ...[
            IconButton.filledTonal(
              onPressed: onBack,
              tooltip: 'Volver',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.pinkSoft,
                foregroundColor: AppColors.roseDeep,
                minimumSize: const Size.square(40),
              ),
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0)
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.muted,
                      ),
                    _BreadcrumbSegment(
                      item: items[i],
                      isActive: i == items.length - 1,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _BreadcrumbSegment extends StatelessWidget {
  const _BreadcrumbSegment({
    required this.item,
    required this.isActive,
  });

  final BreadcrumbItem item;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 12.5,
      color: isActive ? AppColors.roseDeep : AppColors.muted,
      fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
      letterSpacing: 0.7,
    );

    final text = Container(
      padding: EdgeInsets.symmetric(
        horizontal: isActive ? 10 : 4,
        vertical: isActive ? 4 : 2,
      ),
      decoration: isActive
          ? BoxDecoration(
              color: AppColors.pinkSoft,
              borderRadius: BorderRadius.circular(99),
            )
          : null,
      child: Text(item.label.toUpperCase(), style: style),
    );

    if (isActive || item.onTap == null) return text;
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(6),
      child: text,
    );
  }
}
