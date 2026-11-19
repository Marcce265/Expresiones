import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/catalog_models.dart';
import '../models/storefront_settings.dart';
import '../screens/privacy_screen.dart';
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
                  fontFamily: 'PlusJakartaSans',
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
    this.onOpenQuote,
    this.onOpenHelp,
    this.onContact,
    this.whatsappNumber,
    this.settings = const StorefrontSettings(),
  });

  final ValueChanged<ProductCategory>? onSelectCategory;
  final VoidCallback? onOpenQuote;
  final VoidCallback? onOpenHelp;
  final VoidCallback? onContact;
  final String? whatsappNumber;
  final StorefrontSettings settings;

  static const Color _footerBg = Color(0xFFFCEEEF);
  static const Color _footerDivider = Color(0xFFF0D5DC);

  Future<void> _openWhatsapp() async {
    if (onContact != null) {
      onContact!();
      return;
    }
    final number = whatsappNumber ?? settings.whatsappNumber;
    final clean = number.replaceAll(RegExp(r'\D'), '');
    final target = clean.isEmpty ? '51956744914' : clean;
    final uri = Uri.https('wa.me', '/$target', {
      'text': '¡Hola Expresiones! Quisiera información sobre sus productos.',
    });
    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _footerBg,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: _footerDivider)),
        ),
        child: Column(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 42, 24, 34),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 720) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _brandBlock(context),
                          const SizedBox(height: 28),
                          _catalogBlock(context),
                          const SizedBox(height: 24),
                          _policiesBlock(context),
                          const SizedBox(height: 24),
                          _infoBlock(context),
                          const SizedBox(height: 24),
                          _paymentsAndClaimsBlock(context),
                        ],
                      );
                    }
                    if (constraints.maxWidth < 1040) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 4, child: _brandBlock(context)),
                              const SizedBox(width: 28),
                              Expanded(flex: 3, child: _catalogBlock(context)),
                              const SizedBox(width: 24),
                              Expanded(flex: 3, child: _policiesBlock(context)),
                            ],
                          ),
                          const SizedBox(height: 28),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 5, child: _infoBlock(context)),
                              const SizedBox(width: 28),
                              Expanded(
                                flex: 5,
                                child: _paymentsAndClaimsBlock(context),
                              ),
                            ],
                          ),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 4, child: _brandBlock(context)),
                        const SizedBox(width: 28),
                        Expanded(flex: 2, child: _catalogBlock(context)),
                        const SizedBox(width: 24),
                        Expanded(flex: 3, child: _policiesBlock(context)),
                        const SizedBox(width: 24),
                        Expanded(flex: 3, child: _infoBlock(context)),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 3,
                          child: _paymentsAndClaimsBlock(context),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: _footerDivider),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: Text(
              'EXPRESIONES · Huancayo, Perú — Todos los derechos reservados 2026 (D.L. N° 822)',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.ink.withValues(alpha: 0.72),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _columnHeading(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: AppColors.pinkStrong,
      ),
    );
  }

  Widget _brandBlock(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Expresiones',
          image: true,
          child: Image.asset(
            'assets/images/brand/expresiones_wordmark.webp',
            height: 44,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            filterQuality: FilterQuality.medium,
            semanticLabel: 'Expresiones',
            errorBuilder: (context, error, stackTrace) => Text(
              'Expresiones',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w800,
                color: AppColors.pinkStrong,
                fontSize: 22,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Taller artesanal de rosas eternas, ramos de listón y materiales de alta calidad para manualidades y emprendedores en Huancayo. Envíos locales y a todo el Perú.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.ink.withValues(alpha: 0.78),
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _socialCircle(
              CustomPaint(
                size: const Size(17, 17),
                painter: FacebookBrandPainter(color: AppColors.ink),
              ),
              'Facebook: Expresiones',
              'https://www.facebook.com/profile.php?id=61574939932181',
            ),
            const SizedBox(width: 10),
            _socialCircle(
              CustomPaint(
                size: const Size(17, 17),
                painter: InstagramBrandPainter(color: AppColors.ink),
              ),
              'Instagram: @expreciones_eternas',
              'https://www.instagram.com/expreciones_eternas',
            ),
            const SizedBox(width: 10),
            _socialCircle(
              CustomPaint(
                size: const Size(17, 17),
                painter: TikTokBrandPainter(color: AppColors.ink),
              ),
              'TikTok: @expresiones_eternas',
              'https://www.tiktok.com/@expresiones_eternas',
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
        color: Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: () async {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(
                uri,
                mode: kIsWeb
                    ? LaunchMode.platformDefault
                    : LaunchMode.externalApplication,
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
              border: Border.all(color: _footerDivider),
            ),
            alignment: Alignment.center,
            child: SizedBox(width: 17, height: 17, child: iconWidget),
          ),
        ),
      ),
    );
  }

  Widget _catalogBlock(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _columnHeading('Catálogo'),
        const SizedBox(height: 12),
        _footerLink(
          'Materiales',
          onSelectCategory == null
              ? null
              : () => onSelectCategory!(ProductCategory.materials),
        ),
        const SizedBox(height: 8),
        _footerLink(
          'Papel Coreano',
          onSelectCategory == null
              ? null
              : () => onSelectCategory!(ProductCategory.koreanPaper),
        ),
        if (onOpenQuote != null) ...[
          const SizedBox(height: 8),
          _footerLink('Mi carrito', onOpenQuote),
        ],
        if (onOpenHelp != null) ...[
          const SizedBox(height: 8),
          _footerLink('Preguntas frecuentes', onOpenHelp),
        ],
      ],
    );
  }

  Widget _policiesBlock(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _columnHeading('Políticas'),
        const SizedBox(height: 12),
        _footerLink(
          'Términos y condiciones',
          () => showLegalDocumentDialog(
            context,
            initialSection: LegalDocumentSection.terms,
            settings: settings,
          ),
        ),
        const SizedBox(height: 8),
        _footerLink(
          'Política de privacidad',
          () => showLegalDocumentDialog(
            context,
            initialSection: LegalDocumentSection.privacy,
            settings: settings,
          ),
        ),
        const SizedBox(height: 8),
        _footerLink(
          'Políticas de entrega y devolución',
          () => showLegalDocumentDialog(
            context,
            initialSection: LegalDocumentSection.refunds,
            settings: settings,
          ),
        ),
        const SizedBox(height: 8),
        _footerLink(
          'Política de cookies',
          () => showLegalDocumentDialog(
            context,
            initialSection: LegalDocumentSection.cookies,
            settings: settings,
          ),
        ),
      ],
    );
  }

  Widget _infoBlock(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _columnHeading('Información'),
        const SizedBox(height: 12),
        _infoRow(Icons.location_on_outlined, 'Recojo en tienda · Huancayo'),
        const SizedBox(height: 9),
        InkWell(
          onTap: _openWhatsapp,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: _infoRow(
              Icons.phone_outlined,
              '+51 956 744 914 (WhatsApp)',
              bold: true,
            ),
          ),
        ),
        const SizedBox(height: 9),
        _infoRow(Icons.schedule_outlined, 'Lun a Sáb: 11:00 AM - 5:00 PM'),
        const SizedBox(height: 9),
        _infoRow(
          Icons.local_shipping_outlined,
          'Envíos a todo el Perú vía Shalom',
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String text, {bool bold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 16, color: AppColors.ink),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.ink.withValues(alpha: 0.85),
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _paymentsAndClaimsBlock(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 768;
    final logoSize = mobile ? 32.0 : 48.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _columnHeading('Formas de pago'),
        const SizedBox(height: 12),
        Wrap(
          spacing: mobile ? 8 : 10,
          runSpacing: mobile ? 8 : 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _paymentLogoCard(
              'assets/images/payments/yape_sq.webp',
              'Yape',
              width: logoSize,
              height: logoSize,
              padding: EdgeInsets.zero,
              fit: BoxFit.cover,
            ),
            _paymentLogoCard(
              'assets/images/payments/plin_sq.webp',
              'Plin',
              width: logoSize,
              height: logoSize,
              padding: EdgeInsets.zero,
              fit: BoxFit.cover,
            ),
            _paymentLogoCard(
              'assets/images/payments/interbank_sq.webp',
              'Interbank',
              width: logoSize,
              height: logoSize,
              padding: EdgeInsets.zero,
              fit: BoxFit.cover,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Tooltip(
          message: 'Libro de Reclamaciones',
          child: Semantics(
            button: true,
            label: 'Libro de Reclamaciones',
            child: InkWell(
              onTap: () => showLegalDocumentDialog(
                context,
                initialSection: LegalDocumentSection.claimsBook,
                settings: settings,
              ),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 178,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.pinkStrong, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/brand/libro_reclamaciones.webp',
                  height: 76,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  semanticLabel: 'Libro de Reclamaciones',
                  errorBuilder: (context, error, stackTrace) => const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Libro de\nReclamaciones',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0D6EFD),
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 6),
                      Icon(
                        Icons.menu_book_rounded,
                        size: 30,
                        color: AppColors.ink,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _paymentLogoCard(
    String asset,
    String label, {
    required double width,
    required double height,
    EdgeInsetsGeometry padding = const EdgeInsets.all(4),
    BoxFit fit = BoxFit.contain,
  }) {
    return Tooltip(
      message: label,
      child: Container(
        width: width,
        height: height,
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _footerDivider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(padding == EdgeInsets.zero ? 9 : 4),
          child: Image.asset(
            asset,
            fit: fit,
            filterQuality: FilterQuality.medium,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _footerDivider),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
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
            color: onTap != null
                ? AppColors.ink.withValues(alpha: 0.88)
                : AppColors.muted,
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
