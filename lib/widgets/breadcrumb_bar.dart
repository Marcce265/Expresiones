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
            IconButton.outlined(
              onPressed: onBack,
              tooltip: 'Volver',
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
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
      fontSize: 13.5,
      color: isActive ? AppColors.ink : AppColors.muted,
      fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
      letterSpacing: 0.8,
    );

    final text = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Text(item.label.toUpperCase(), style: style),
    );

    if (isActive || item.onTap == null) return text;
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(4),
      child: text,
    );
  }
}
