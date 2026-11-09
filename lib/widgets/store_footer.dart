import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/catalog_models.dart';
import '../models/storefront_settings.dart';
import '../theme/app_theme.dart';

/// Franja de sellos de confianza con estilo Rosatel adaptado a Expresiones.
class TrustBadgesStrip extends StatelessWidget {
  const TrustBadgesStrip({
    super.key,
    this.onContact,
    this.whatsappNumber,
  });

  final VoidCallback? onContact;
  final String? whatsappNumber;

  Future<void> _openWhatsapp(BuildContext context) async {
    if (onContact != null) {
      onContact!();
      return;
    }
    final number = whatsappNumber ?? StorefrontSettings.defaultWhatsappNumber;
    final clean = number.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.https('wa.me', '/$clean', {
      'text': '¡Hola Expresiones! Quisiera información sobre sus productos.',
    });
    await launchUrl(
      uri,
      mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        final badges = [
          _BadgeItem(
            icon: Icons.verified_outlined,
            title: 'Calidad premium',
            subtitle: 'Artesanía y acabados impecables',
          ),
          _BadgeItem(
            icon: Icons.inventory_2_outlined,
            title: 'Productos seleccionados',
            subtitle: 'Insumos importados duraderos',
          ),
          _BadgeItem(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Atención personalizada',
            subtitle: 'Escríbenos directamente',
            action: OutlinedButton(
              onPressed: () => _openWhatsapp(context),
              style: OutlinedButton.styleFrom(
                shape: const StadiumBorder(),
                side: const BorderSide(color: AppColors.ink, width: 1.2),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Contáctanos', style: TextStyle(fontSize: 12)),
            ),
          ),
        ];

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 16 : 28,
            vertical: compact ? 20 : 24,
          ),
          decoration: BoxDecoration(
            color: AppColors.pinkSoft,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: compact
              ? Column(
                  children: [
                    for (int i = 0; i < badges.length; i++) ...[
                      badges[i],
                      if (i < badges.length - 1) const SizedBox(height: 18),
                    ],
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < badges.length; i++) ...[
                      Expanded(child: badges[i]),
                      if (i < badges.length - 1)
                        Container(
                          width: 1,
                          height: 70,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          color: AppColors.border.withValues(alpha: 0.6),
                        ),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class _BadgeItem extends StatelessWidget {
  const _BadgeItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: AppColors.ink,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
                fontSize: 12,
              ),
        ),
        if (action != null) ...[
          const SizedBox(height: 10),
          action!,
        ],
      ],
    );
  }
}

/// Banner de fotos referenciales y pedidos artesanales.
class StoreDisclaimerBanner extends StatelessWidget {
  const StoreDisclaimerBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.camera_alt_outlined, color: AppColors.ink, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fotos referenciales',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Cada producto y arreglo floral es elaborado artesanalmente. Los tonos o texturas pueden presentar ligeras variaciones naturales que los hacen únicos.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner de pedidos personalizados y WhatsApp.
class StoreSpecialOrderBanner extends StatelessWidget {
  const StoreSpecialOrderBanner({
    super.key,
    this.onContact,
    this.whatsappNumber,
  });

  final VoidCallback? onContact;
  final String? whatsappNumber;

  Future<void> _openWhatsapp(BuildContext context) async {
    if (onContact != null) {
      onContact!();
      return;
    }
    final number = whatsappNumber ?? StorefrontSettings.defaultWhatsappNumber;
    final clean = number.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.https('wa.me', '/$clean', {
      'text': '¡Hola Expresiones! Quisiera cotizar un pedido especial personalizado.',
    });
    await launchUrl(
      uri,
      mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(24),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 640;
          final content = Column(
            crossAxisAlignment:
                compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              Text(
                '¿Buscas un diseño o pedido a medida?',
                textAlign: compact ? TextAlign.center : TextAlign.start,
                style: const TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Elaboramos ramos de rosas eternas, coronas y manualidades para celebraciones especiales.',
                textAlign: compact ? TextAlign.center : TextAlign.start,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          );

          final button = FilledButton.icon(
            onPressed: () => _openWhatsapp(context),
            icon: const Icon(Icons.chat_outlined, size: 18),
            label: const Text('Escríbenos por WhatsApp'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.whatsapp,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            ),
          );

          if (compact) {
            return Column(
              children: [
                content,
                const SizedBox(height: 18),
                button,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: content),
              const SizedBox(width: 24),
              button,
            ],
          );
        },
      ),
    );
  }
}

/// Pie de página integral de la tienda Expresiones con estilo Rosatel.
class StoreFooter extends StatelessWidget {
  const StoreFooter({
    super.key,
    this.onSelectCategory,
    this.onContact,
    this.whatsappNumber,
  });

  final ValueChanged<ProductCategory>? onSelectCategory;
  final VoidCallback? onContact;
  final String? whatsappNumber;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 960;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compact)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _brandBlock(context),
                    const SizedBox(height: 28),
                    _categoriesBlock(context),
                    const SizedBox(height: 24),
                    _attentionBlock(context),
                    const SizedBox(height: 24),
                    _paymentsBlock(context),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 4, child: _brandBlock(context)),
                    const SizedBox(width: 32),
                    Expanded(flex: 3, child: _categoriesBlock(context)),
                    const SizedBox(width: 24),
                    Expanded(flex: 3, child: _attentionBlock(context)),
                    const SizedBox(width: 24),
                    Expanded(flex: 3, child: _paymentsBlock(context)),
                  ],
                ),
              const SizedBox(height: 36),
              const Divider(color: AppColors.border),
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text(
                    '© 2026 Expresiones · Todos los derechos reservados',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                  ),
                  const Text('🌸 Huancayo, Perú', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _brandBlock(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌸', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text(
              'Expresiones',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontFamily: 'PlayfairDisplay',
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Taller artesanal de rosas eternas, ramos de listón y materiales de alta calidad para manualidades y emprendedores en Huancayo. Envíos locales y a todo el Perú.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
                height: 1.45,
              ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _socialCircle(
              CustomPaint(
                size: const Size(18, 18),
                painter: FacebookBrandPainter(color: AppColors.ink),
              ),
              'Facebook: Expresiones Huancayo',
              'https://facebook.com/expresioneshuancayo',
            ),
            const SizedBox(width: 8),
            _socialCircle(
              CustomPaint(
                size: const Size(18, 18),
                painter: InstagramBrandPainter(color: AppColors.ink),
              ),
              'Instagram: @expresiones_huancayo',
              'https://instagram.com/expresiones_huancayo',
            ),
            const SizedBox(width: 8),
            _socialCircle(
              CustomPaint(
                size: const Size(18, 18),
                painter: TikTokBrandPainter(color: AppColors.ink),
              ),
              'TikTok: @expresiones_huancayo',
              'https://tiktok.com/@expresiones_huancayo',
            ),
          ],
        ),
      ],
    );
  }

  Widget _socialCircle(Widget iconWidget, String tooltip, String url) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.canvas,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: () async {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(
                uri,
                mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
              );
            }
          },
          customBorder: const CircleBorder(),
          hoverColor: AppColors.pinkSoft,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            alignment: Alignment.center,
            child: SizedBox(
              width: 18,
              height: 18,
              child: iconWidget,
            ),
          ),
        ),
      ),
    );
  }

  Widget _categoriesBlock(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MÓDULOS',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
        ),
        const SizedBox(height: 12),
        _footerLink('✨ Materiales', () => onSelectCategory?.call(ProductCategory.materials)),
        const SizedBox(height: 8),
        _footerLink('🌸 Papel Coreano', () => onSelectCategory?.call(ProductCategory.koreanPaper)),
      ],
    );
  }

  Widget _attentionBlock(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ATENCIÓN',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Lun a Sáb: 11:00 AM - 5:00 PM',
          style: TextStyle(fontSize: 13, color: AppColors.ink, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        const Text('Huancayo · Envíos a todo el Perú', style: TextStyle(fontSize: 13, color: AppColors.muted)),
        const SizedBox(height: 8),
        _footerLink('Recojo en tienda Shalom', null),
      ],
    );
  }

  Widget _paymentsBlock(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FORMAS DE PAGO',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _paymentImage('assets/images/payments/yape.png', 'Yape', width: 72, height: 26),
            _paymentImage('assets/images/payments/plin.png', 'Plin', width: 72, height: 26),
            _paymentImage('assets/images/payments/interbank.png', 'Interbank', width: 84, height: 26),
          ],
        ),
      ],
    );
  }

  Widget _paymentImage(String asset, String label, {double width = 72, double height = 26}) {
    return Tooltip(
      message: label,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            asset,
            width: width,
            height: height,
            fit: BoxFit.contain,
            semanticLabel: label,
            errorBuilder: (context, error, stackTrace) => _paymentBadge(label),
          ),
        ),
      ),
    );
  }

  Widget _paymentBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.ink),
      ),
    );
  }

  Widget _footerLink(String text, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: onTap != null ? AppColors.ink : AppColors.muted,
            fontWeight: onTap != null ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class FacebookBrandPainter extends CustomPainter {
  const FacebookBrandPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);
    final path = Path()
      ..moveTo(13.5, 22.0)
      ..lineTo(13.5, 12.8)
      ..lineTo(16.4, 12.8)
      ..lineTo(16.8, 9.4)
      ..lineTo(13.5, 9.4)
      ..lineTo(13.5, 7.3)
      ..cubicTo(13.5, 6.35, 13.8, 5.7, 15.2, 5.7)
      ..lineTo(16.9, 5.7)
      ..lineTo(16.9, 2.7)
      ..cubicTo(16.6, 2.65, 15.6, 2.55, 14.4, 2.55)
      ..cubicTo(11.9, 2.55, 10.2, 4.05, 10.2, 6.8)
      ..lineTo(10.2, 9.4)
      ..lineTo(7.3, 9.4)
      ..lineTo(7.3, 12.8)
      ..lineTo(10.2, 12.8)
      ..lineTo(10.2, 22.0)
      ..close();

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FacebookBrandPainter oldDelegate) =>
      oldDelegate.color != color;
}

class InstagramBrandPainter extends CustomPainter {
  const InstagramBrandPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.11
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.08,
        size.height * 0.08,
        size.width * 0.84,
        size.height * 0.84,
      ),
      Radius.circular(size.width * 0.26),
    );
    canvas.drawRRect(rect, strokePaint);

    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.5),
      size.width * 0.22,
      strokePaint,
    );

    canvas.drawCircle(
      Offset(size.width * 0.72, size.height * 0.28),
      size.width * 0.065,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant InstagramBrandPainter oldDelegate) =>
      oldDelegate.color != color;
}

class TikTokBrandPainter extends CustomPainter {
  const TikTokBrandPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);
    final path = Path()
      ..moveTo(19.3, 7.4)
      ..cubicTo(18.2, 7.4, 17.2, 6.8, 16.5, 6.0)
      ..cubicTo(15.8, 5.2, 15.4, 4.2, 15.3, 3.0)
      ..lineTo(12.3, 3.0)
      ..lineTo(12.3, 15.8)
      ..cubicTo(12.2, 17.3, 11.0, 18.5, 9.5, 18.5)
      ..cubicTo(7.9, 18.5, 6.7, 17.2, 6.7, 15.6)
      ..cubicTo(6.7, 14.1, 8.0, 12.8, 9.5, 12.8)
      ..cubicTo(9.9, 12.8, 10.3, 12.9, 10.6, 13.1)
      ..lineTo(10.6, 10.0)
      ..cubicTo(10.2, 9.9, 9.8, 9.8, 9.5, 9.8)
      ..cubicTo(6.3, 9.8, 3.7, 12.4, 3.7, 15.6)
      ..cubicTo(3.7, 18.8, 6.3, 21.4, 9.5, 21.4)
      ..cubicTo(12.6, 21.4, 15.2, 18.9, 15.3, 15.8)
      ..lineTo(15.3, 9.9)
      ..cubicTo(16.7, 10.9, 18.4, 11.4, 20.2, 11.4)
      ..lineTo(20.2, 8.4)
      ..cubicTo(19.9, 8.4, 19.6, 8.4, 19.3, 7.4)
      ..close();

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TikTokBrandPainter oldDelegate) =>
      oldDelegate.color != color;
}
