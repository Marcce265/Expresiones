import 'package:flutter/material.dart';

import '../models/storefront_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/app_notice.dart';
import 'admin_site_settings_repository.dart';
import 'admin_ui.dart';

class AdminSiteSettingsScreen extends StatelessWidget {
  const AdminSiteSettingsScreen({super.key, required this.repository});

  final AdminSiteSettingsRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contenido de la web'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        shape: const Border(
          bottom: BorderSide(color: AppColors.border, width: .8),
        ),
      ),
      body: StreamBuilder<StorefrontSettings>(
        stream: repository.watch(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _SettingsMessage(
              title: 'No se pudo cargar la configuración',
              message: '${snapshot.error}',
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final settings = snapshot.data!;
          return _SiteSettingsEditor(
            key: ValueKey(settings.toMap().toString()),
            initial: settings,
            onSave: repository.save,
          );
        },
      ),
    );
  }
}

class _SiteSettingsEditor extends StatefulWidget {
  const _SiteSettingsEditor({
    super.key,
    required this.initial,
    required this.onSave,
  });

  final StorefrontSettings initial;
  final Future<void> Function(StorefrontSettings) onSave;

  @override
  State<_SiteSettingsEditor> createState() => _SiteSettingsEditorState();
}

class _SiteSettingsEditorState extends State<_SiteSettingsEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _whatsapp;
  late final Map<String, TextEditingController> _texts;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _whatsapp = TextEditingController(text: widget.initial.whatsappNumber);
    _texts = {
      for (final key in StorefrontText.defaults.keys)
        key: TextEditingController(text: widget.initial.text(key)),
    };
  }

  @override
  void dispose() {
    _whatsapp.dispose();
    for (final controller in _texts.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final texts = Map<String, String>.of(widget.initial.texts);
      for (final entry in _texts.entries) {
        texts[entry.key] = entry.value.text.trim();
      }
      await widget.onSave(
        widget.initial.copyWith(
          whatsappNumber: _whatsapp.text.trim(),
          texts: Map.unmodifiable(texts),
        ),
      );
      if (mounted) showAppNotice(context, 'Contenido actualizado.');
    } catch (error) {
      if (mounted) {
        showAppNotice(
          context,
          'No se pudo guardar: $error',
          tone: AppNoticeTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          ResponsivePage(
            maxWidth: 1120,
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AdminSectionIntro(
                  eyebrow: 'Configuración pública',
                  title: 'Edita lo que leen tus clientes',
                  description: 'Actualiza la marca, el contacto, los textos comerciales, las preguntas frecuentes y la política de privacidad. Los cambios se publican en la web y la aplicación.',
                ),
                const SizedBox(height: 18),
                const InfoBanner(
                  icon: Icons.visibility_outlined,
                  title: 'Contenido centralizado',
                  message: 'Los botones y mensajes técnicos conservan nombres claros; todo el contenido comercial y legal se administra aquí.',
                ),
                const SizedBox(height: 18),
                _BusinessCard(
                  whatsapp: _whatsapp,
                  brandName: _texts[StorefrontText.brandName]!,
                  brandTagline: _texts[StorefrontText.brandTagline]!,
                ),
                const SizedBox(height: 14),
                for (final section in _sections) ...[
                  _ContentSectionCard(section: section, controllers: _texts),
                  const SizedBox(height: 14),
                ],
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.cloud_upload_outlined),
                    label: const Text('Publicar cambios'),
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

class _BusinessCard extends StatelessWidget {
  const _BusinessCard({
    required this.whatsapp,
    required this.brandName,
    required this.brandTagline,
  });

  final TextEditingController whatsapp;
  final TextEditingController brandName;
  final TextEditingController brandTagline;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storefront_outlined),
                const SizedBox(width: 10),
                Text(
                  'Marca y contacto',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth >= 760
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 14,
                  children: [
                    SizedBox(
                      width: width,
                      child: TextFormField(
                        controller: brandName,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de la marca',
                        ),
                        validator: _required,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: TextFormField(
                        controller: whatsapp,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'WhatsApp',
                          helperText:
                              'Código de país y número. Ej. 51956744914.',
                        ),
                        validator: _validWhatsapp,
                      ),
                    ),
                    SizedBox(
                      width: constraints.maxWidth,
                      child: TextFormField(
                        controller: brandTagline,
                        decoration: const InputDecoration(
                          labelText: 'Descripción corta de la marca',
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentSectionCard extends StatelessWidget {
  const _ContentSectionCard({required this.section, required this.controllers});

  final _ContentSection section;
  final Map<String, TextEditingController> controllers;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: section.initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
        leading: CircleAvatar(
          backgroundColor: AppColors.pinkSoft,
          child: Icon(section.icon, size: 20, color: AppColors.ink),
        ),
        title: Text(
          section.title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        subtitle: Text(section.description),
        shape: const Border(),
        collapsedShape: const Border(),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final half = constraints.maxWidth >= 760
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 14,
                children: [
                  for (final field in section.fields)
                    SizedBox(
                      width: field.multiline ? constraints.maxWidth : half,
                      child: TextFormField(
                        controller: controllers[field.key],
                        minLines: field.multiline ? 3 : 1,
                        maxLines: field.multiline ? 6 : 1,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(labelText: field.label),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SettingsMessage extends StatelessWidget {
  const _SettingsMessage({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            SelectableText(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _TextFieldSpec {
  const _TextFieldSpec(this.key, this.label, {this.multiline = false});

  final String key;
  final String label;
  final bool multiline;
}

class _ContentSection {
  const _ContentSection({
    required this.title,
    required this.description,
    required this.icon,
    required this.fields,
    this.initiallyExpanded = false,
  });

  final String title;
  final String description;
  final IconData icon;
  final List<_TextFieldSpec> fields;
  final bool initiallyExpanded;
}

const _sections = <_ContentSection>[
  _ContentSection(
    title: 'Portada',
    description: 'Presentación, buscador y bloque lateral del inicio.',
    icon: Icons.home_outlined,
    initiallyExpanded: true,
    fields: [
      _TextFieldSpec(StorefrontText.homeEyebrow, 'Texto superior'),
      _TextFieldSpec(StorefrontText.homeTitle, 'Título principal'),
      _TextFieldSpec(
        StorefrontText.homeSubtitle,
        'Descripción principal',
        multiline: true,
      ),
      _TextFieldSpec(StorefrontText.homeSearchHint, 'Texto del buscador'),
      _TextFieldSpec(StorefrontText.homeFeaturedTitle, 'Título de destacados'),
      _TextFieldSpec(StorefrontText.homeSidebarTitle, 'Título lateral'),
      _TextFieldSpec(
        StorefrontText.homeSidebarBody,
        'Descripción lateral',
        multiline: true,
      ),
    ],
  ),
  _ContentSection(
    title: 'Catálogo',
    description: 'Buscador y mensaje cuando no hay coincidencias.',
    icon: Icons.grid_view_outlined,
    fields: [
      _TextFieldSpec(StorefrontText.catalogSearchHint, 'Texto del buscador'),
      _TextFieldSpec(StorefrontText.catalogEmptyTitle, 'Título sin resultados'),
      _TextFieldSpec(
        StorefrontText.catalogEmptyBody,
        'Descripción sin resultados',
        multiline: true,
      ),
    ],
  ),
  _ContentSection(
    title: 'Cotización',
    description: 'Mensajes del carrito y aviso antes de coordinar.',
    icon: Icons.shopping_bag_outlined,
    fields: [
      _TextFieldSpec(StorefrontText.quoteEmptyTitle, 'Título vacío'),
      _TextFieldSpec(
        StorefrontText.quoteEmptyBody,
        'Descripción vacía',
        multiline: true,
      ),
      _TextFieldSpec(StorefrontText.quoteNoticeTitle, 'Título del aviso'),
      _TextFieldSpec(
        StorefrontText.quoteNoticeBody,
        'Descripción del aviso',
        multiline: true,
      ),
      _TextFieldSpec(
        StorefrontText.quotePriceNote,
        'Nota sobre precios',
        multiline: true,
      ),
    ],
  ),
  _ContentSection(
    title: 'Coordinación y entrega',
    description: 'Datos solicitados, recojo, Shalom, fecha y notas.',
    icon: Icons.local_shipping_outlined,
    fields: [
      _TextFieldSpec(
        StorefrontText.coordinationContactTitle,
        'Título de contacto',
      ),
      _TextFieldSpec(
        StorefrontText.coordinationContactBody,
        'Descripción de contacto',
        multiline: true,
      ),
      _TextFieldSpec(
        StorefrontText.coordinationDeliveryTitle,
        'Título de entrega',
      ),
      _TextFieldSpec(
        StorefrontText.coordinationDeliveryBody,
        'Descripción de entrega',
        multiline: true,
      ),
      _TextFieldSpec(
        StorefrontText.coordinationPickupTitle,
        'Título de recojo',
      ),
      _TextFieldSpec(
        StorefrontText.coordinationPickupBody,
        'Descripción de recojo',
      ),
      _TextFieldSpec(
        StorefrontText.coordinationShalomTitle,
        'Título de Shalom',
      ),
      _TextFieldSpec(
        StorefrontText.coordinationShalomBody,
        'Descripción de Shalom',
      ),
      _TextFieldSpec(StorefrontText.coordinationDateTitle, 'Título de fecha'),
      _TextFieldSpec(
        StorefrontText.coordinationDateBody,
        'Descripción de fecha',
        multiline: true,
      ),
      _TextFieldSpec(
        StorefrontText.coordinationDetailsTitle,
        'Título de detalles',
      ),
      _TextFieldSpec(
        StorefrontText.coordinationDetailsBody,
        'Descripción de detalles',
        multiline: true,
      ),
      _TextFieldSpec(
        StorefrontText.coordinationDetailsHint,
        'Ayuda del campo de detalles',
      ),
    ],
  ),
  _ContentSection(
    title: 'Revisión y envío',
    description: 'Encabezado final, resumen y mensaje de WhatsApp.',
    icon: Icons.fact_check_outlined,
    fields: [
      _TextFieldSpec(StorefrontText.reviewTitle, 'Título principal'),
      _TextFieldSpec(
        StorefrontText.reviewBody,
        'Descripción principal',
        multiline: true,
      ),
      _TextFieldSpec(
        StorefrontText.reviewContactTitle,
        'Título de coordinación',
      ),
      _TextFieldSpec(
        StorefrontText.reviewContactBody,
        'Descripción de coordinación',
      ),
      _TextFieldSpec(StorefrontText.reviewMessageTitle, 'Título del mensaje'),
      _TextFieldSpec(
        StorefrontText.reviewMessageBody,
        'Descripción del mensaje',
      ),
      _TextFieldSpec(
        StorefrontText.reviewPaymentNote,
        'Nota sobre el pago',
        multiline: true,
      ),
    ],
  ),
  _ContentSection(
    title: 'Pago simulado y confirmación',
    description:
        'Presentación, métodos de demostración, errores y comprobante final.',
    icon: Icons.credit_card_outlined,
    fields: [
      _TextFieldSpec(StorefrontText.paymentEyebrow, 'Texto superior'),
      _TextFieldSpec(StorefrontText.paymentTitle, 'Título del pago'),
      _TextFieldSpec(
        StorefrontText.paymentBody,
        'Descripción del pago',
        multiline: true,
      ),
      _TextFieldSpec(
        StorefrontText.paymentDemoBadge,
        'Etiqueta de demostración',
      ),
      _TextFieldSpec(
        StorefrontText.paymentCardMethod,
        'Nombre de tarjeta demo',
      ),
      _TextFieldSpec(
        StorefrontText.paymentCardDescription,
        'Descripción de tarjeta demo',
        multiline: true,
      ),
      _TextFieldSpec(StorefrontText.paymentYapeMethod, 'Nombre de Yape demo'),
      _TextFieldSpec(
        StorefrontText.paymentYapeDescription,
        'Descripción de Yape demo',
        multiline: true,
      ),
      _TextFieldSpec(
        StorefrontText.paymentShippingPending,
        'Envío por confirmar',
      ),
      _TextFieldSpec(
        StorefrontText.paymentSubmitButton,
        'Botón para simular pago',
      ),
      _TextFieldSpec(
        StorefrontText.paymentProcessing,
        'Mensaje mientras procesa',
      ),
      _TextFieldSpec(
        StorefrontText.paymentDisclaimer,
        'Aviso de seguridad',
        multiline: true,
      ),
      _TextFieldSpec(
        StorefrontText.paymentRejectedTitle,
        'Título de pago rechazado',
      ),
      _TextFieldSpec(
        StorefrontText.paymentRejectedBody,
        'Descripción de pago rechazado',
        multiline: true,
      ),
      _TextFieldSpec(
        StorefrontText.paymentRetryButton,
        'Botón para reintentar',
      ),
      _TextFieldSpec(StorefrontText.successEyebrow, 'Comprobante · superior'),
      _TextFieldSpec(StorefrontText.successTitle, 'Comprobante · título'),
      _TextFieldSpec(
        StorefrontText.successBody,
        'Comprobante · descripción',
        multiline: true,
      ),
      _TextFieldSpec(
        StorefrontText.successPaymentLabel,
        'Estado del pago simulado',
      ),
      _TextFieldSpec(
        StorefrontText.successNoCharge,
        'Aviso de comprobante',
        multiline: true,
      ),
      _TextFieldSpec(StorefrontText.successWhatsappButton, 'Botón de WhatsApp'),
      _TextFieldSpec(
        StorefrontText.successHomeButton,
        'Botón para volver al inicio',
      ),
      _TextFieldSpec(
        StorefrontText.successNewOrderButton,
        'Botón para otra compra',
      ),
    ],
  ),
  _ContentSection(
    title: 'Ayuda y preguntas frecuentes',
    description: 'Presentación, aviso, botones y seis respuestas.',
    icon: Icons.help_outline_rounded,
    fields: [
      _TextFieldSpec(StorefrontText.helpEyebrow, 'Texto superior'),
      _TextFieldSpec(StorefrontText.helpTitle, 'Título'),
      _TextFieldSpec(StorefrontText.helpBody, 'Descripción', multiline: true),
      _TextFieldSpec(StorefrontText.helpBannerTitle, 'Título del aviso'),
      _TextFieldSpec(
        StorefrontText.helpBannerBody,
        'Descripción del aviso',
        multiline: true,
      ),
      _TextFieldSpec(StorefrontText.helpPrivacyButton, 'Botón de privacidad'),
      _TextFieldSpec(StorefrontText.helpContactButton, 'Botón de contacto'),
      _TextFieldSpec('help.faq1.title', 'Pregunta 1'),
      _TextFieldSpec('help.faq1.body', 'Respuesta 1', multiline: true),
      _TextFieldSpec('help.faq2.title', 'Pregunta 2'),
      _TextFieldSpec('help.faq2.body', 'Respuesta 2', multiline: true),
      _TextFieldSpec('help.faq3.title', 'Pregunta 3'),
      _TextFieldSpec('help.faq3.body', 'Respuesta 3', multiline: true),
      _TextFieldSpec('help.faq4.title', 'Pregunta 4'),
      _TextFieldSpec('help.faq4.body', 'Respuesta 4', multiline: true),
      _TextFieldSpec('help.faq5.title', 'Pregunta 5'),
      _TextFieldSpec('help.faq5.body', 'Respuesta 5', multiline: true),
      _TextFieldSpec('help.faq6.title', 'Pregunta 6'),
      _TextFieldSpec('help.faq6.body', 'Respuesta 6', multiline: true),
    ],
  ),
  _ContentSection(
    title: 'Privacidad',
    description: 'Encabezado, ocho secciones legales y control de datos.',
    icon: Icons.privacy_tip_outlined,
    fields: [
      _TextFieldSpec(StorefrontText.privacyTitle, 'Título'),
      _TextFieldSpec(StorefrontText.privacySubtitle, 'Subtítulo'),
      _TextFieldSpec(StorefrontText.privacyUpdatedAt, 'Fecha de actualización'),
      _TextFieldSpec('privacy.section1.title', 'Sección 1 · título'),
      _TextFieldSpec(
        'privacy.section1.body',
        'Sección 1 · contenido',
        multiline: true,
      ),
      _TextFieldSpec('privacy.section2.title', 'Sección 2 · título'),
      _TextFieldSpec(
        'privacy.section2.body',
        'Sección 2 · contenido',
        multiline: true,
      ),
      _TextFieldSpec('privacy.section3.title', 'Sección 3 · título'),
      _TextFieldSpec(
        'privacy.section3.body',
        'Sección 3 · contenido',
        multiline: true,
      ),
      _TextFieldSpec('privacy.section4.title', 'Sección 4 · título'),
      _TextFieldSpec(
        'privacy.section4.body',
        'Sección 4 · contenido',
        multiline: true,
      ),
      _TextFieldSpec('privacy.section5.title', 'Sección 5 · título'),
      _TextFieldSpec(
        'privacy.section5.body',
        'Sección 5 · contenido',
        multiline: true,
      ),
      _TextFieldSpec('privacy.section6.title', 'Sección 6 · título'),
      _TextFieldSpec(
        'privacy.section6.body',
        'Sección 6 · contenido',
        multiline: true,
      ),
      _TextFieldSpec('privacy.section7.title', 'Sección 7 · título'),
      _TextFieldSpec(
        'privacy.section7.body',
        'Sección 7 · contenido',
        multiline: true,
      ),
      _TextFieldSpec('privacy.section8.title', 'Sección 8 · título'),
      _TextFieldSpec(
        'privacy.section8.body',
        'Sección 8 · contenido',
        multiline: true,
      ),
      _TextFieldSpec(
        StorefrontText.privacyControlTitle,
        'Control de datos · título',
      ),
      _TextFieldSpec(
        StorefrontText.privacyControlBody,
        'Control de datos · descripción',
        multiline: true,
      ),
      _TextFieldSpec(
        StorefrontText.privacyClearButton,
        'Botón para borrar datos',
      ),
    ],
  ),
];

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'Este campo es obligatorio.' : null;

String? _validWhatsapp(String? value) {
  final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
  return digits.length >= 8 && digits.length <= 15
      ? null
      : 'Ingresa entre 8 y 15 dígitos.';
}
