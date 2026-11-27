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
/// Altura fija de 44px, botón de retroceso rosado suave y píldora activa en
/// rosado para mantener el mismo nivel vertical y tipografía en toda la web.
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
    return SizedBox(
      height: 44,
      child: Material(
        type: MaterialType.transparency,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (onBack != null) ...[
              IconButton.filledTonal(
                onPressed: onBack,
                tooltip: 'Volver',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.pinkSoft,
                  foregroundColor: AppColors.roseDeep,
                  minimumSize: const Size.square(40),
                  fixedSize: const Size.square(40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 2),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: AppColors.muted,
                          ),
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
      fontFamily: AppTheme.bodyFont,
      fontSize: 12.5,
      height: 1.1,
      color: isActive ? AppColors.roseDeep : AppColors.muted,
      fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
      letterSpacing: 0.7,
    );

    final text = Container(
      padding: EdgeInsets.symmetric(
        horizontal: isActive ? 12 : 4,
        vertical: isActive ? 7 : 4,
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
      borderRadius: BorderRadius.circular(99),
      child: text,
    );
  }
}
