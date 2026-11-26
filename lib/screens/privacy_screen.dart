import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/feature_flags.dart';
import '../models/storefront_settings.dart';
import '../security/input_sanitizer.dart';
import '../services/legal_consent_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/app_notice.dart';

enum LegalDocumentSection {
  privacy('Política de Privacidad'),
  terms('Términos y Condiciones'),
  refunds('Política de Reembolsos'),
  cookies('Política de Cookies'),
  claimsBook('Libro de Reclamaciones');

  const LegalDocumentSection(this.label);
  final String label;
}

Future<void> showLegalDocumentDialog(
  BuildContext context, {
  LegalDocumentSection initialSection = LegalDocumentSection.terms,
  StorefrontSettings settings = const StorefrontSettings(),
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880, maxHeight: 760),
        child: PrivacyScreen(
          initialSection: initialSection,
          settings: settings,
          onBack: () => Navigator.of(dialogContext).pop(),
          onClearLocalData: () async {},
        ),
      ),
    ),
  );
}

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({
    super.key,
    required this.onBack,
    required this.onClearLocalData,
    this.onAdminLogin,
    this.settings = const StorefrontSettings(),
    this.initialSection = LegalDocumentSection.privacy,
  });

  final VoidCallback onBack;
  final Future<void> Function() onClearLocalData;
  final VoidCallback? onAdminLogin;
  final StorefrontSettings settings;
  final LegalDocumentSection initialSection;

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  LegalDocumentSection get _section => widget.initialSection;
  bool _clearing = false;
  List<LegalConsentRecord> _consentRecords = const [];

  String _subtitleForSection(LegalDocumentSection section) {
    return switch (section) {
      LegalDocumentSection.privacy =>
        'Ley N° 29733 y Reglamento D.S. N° 016-2024-JUS · Perú (Versión $kCurrentLegalPolicyVersion)',
      LegalDocumentSection.terms =>
        'Condiciones de uso, precios, entregas y derechos de autor · Perú (Versión $kCurrentLegalPolicyVersion)',
      LegalDocumentSection.refunds => 'Garantía legal, cambios y devoluciones conforme a la Ley N° 29571 · INDECOPI',
      LegalDocumentSection.cookies =>
        'Transparencia sobre almacenamiento local estrictamente técnico · Perú',
      LegalDocumentSection.claimsBook => 'Hoja de Reclamación Virtual · D.S. N° 011-2011-PCM y Ley N° 31435 (INDECOPI)',
    };
  }

  // Campos del Libro de Reclamaciones Virtual (INDECOPI)
  final _claimNameController = TextEditingController();
  final _claimDniController = TextEditingController();
  final _claimPhoneController = TextEditingController();
  final _claimDetailController = TextEditingController();
  final _claimRequestController = TextEditingController();
  String _claimType = 'Reclamo';

  @override
  void initState() {
    super.initState();
    _loadConsents();
  }

  @override
  void dispose() {
    _claimNameController.dispose();
    _claimDniController.dispose();
    _claimPhoneController.dispose();
    _claimDetailController.dispose();
    _claimRequestController.dispose();
    super.dispose();
  }

  Future<void> _loadConsents() async {
    final records = await LegalConsentService.loadLocalHistory();
    if (!mounted) return;
    setState(() => _consentRecords = records);
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrar datos de este dispositivo'),
        content: Text(
          FeatureFlags.appEndToEnd
              ? 'Se eliminarán el carrito, los datos de coordinación, el último comprobante y los eventos anónimos que todavía no se hayan enviado. Esta acción no puede deshacerse.'
              : FeatureFlags.paymentsEnabled
              ? 'Se eliminarán el carrito, los datos de coordinación, el último comprobante de demostración y los eventos anónimos que todavía no se hayan enviado. Esta acción no puede deshacerse.'
              : 'Se eliminarán el carrito, los datos de coordinación y los eventos anónimos que todavía no se hayan enviado. Esta acción no puede deshacerse.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _clearing = true);
    await widget.onClearLocalData();
    if (!mounted) return;
    setState(() => _clearing = false);
    showAppNotice(context, 'Los datos locales fueron eliminados.');
  }

  Future<void> _submitClaimBook() async {
    final name = InputSanitizer.sanitizeText(
      _claimNameController.text,
      maxLength: 120,
    );
    final dni = InputSanitizer.sanitizeText(
      _claimDniController.text,
      maxLength: 15,
    );
    final phone = InputSanitizer.sanitizeText(
      _claimPhoneController.text,
      maxLength: 20,
    );
    final detail = InputSanitizer.sanitizeText(
      _claimDetailController.text,
      maxLength: 500,
      allowNewlines: true,
    );
    final request = InputSanitizer.sanitizeText(
      _claimRequestController.text,
      maxLength: 400,
      allowNewlines: true,
    );

    if (name.length < 3 ||
        dni.length < 8 ||
        phone.length < 9 ||
        detail.length < 10) {
      showAppNotice(
        context,
        'Completa tu nombre, DNI (8 dígitos), celular y el detalle del $_claimType.',
      );
      return;
    }

    final now = DateTime.now();
    final sheetCode =
        'LR-${now.year}-${now.millisecondsSinceEpoch.toString().substring(7)}';
    final text = [
      '📖 *HOJA DE RECLAMACIÓN VIRTUAL · EXPRESIONES*',
      'Código de Hoja: $sheetCode',
      'Fecha y hora: ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      'Tipo: $_claimType (Ley N° 29571 - INDECOPI)',
      'Consumidor: $name',
      'DNI/CE: $dni',
      'Teléfono: $phone',
      'Detalle: $detail',
      if (request.isNotEmpty) 'Pedido del consumidor: $request',
      'Plazo legal de atención: Máximo 15 días hábiles (Ley N° 31435).',
    ].join('\n');

    final digits = widget.settings.whatsappNumber.replaceAll(RegExp(r'\D'), '');
    final targetPhone = digits.isEmpty ? '51956744914' : digits;
    final uri = Uri.parse(
      'https://wa.me/$targetPhone?text=${Uri.encodeComponent(text)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
    }
    if (!mounted) return;
    showAppNotice(
      context,
      'Hoja de reclamación $sheetCode generada. Conserva tu constancia enviada.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsivePage(
            maxWidth: 860,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: widget.onBack,
                      tooltip: 'Volver',
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _section == LegalDocumentSection.privacy
                            ? widget.settings.text(StorefrontText.privacyTitle)
                            : _section.label,
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _subtitleForSection(_section),
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 24),
                if (_section == LegalDocumentSection.privacy)
                  _buildPrivacyContent(context),
                if (_section == LegalDocumentSection.terms)
                  _buildTermsContent(context),
                if (_section == LegalDocumentSection.refunds)
                  _buildRefundsContent(context),
                if (_section == LegalDocumentSection.cookies)
                  _buildCookiesContent(context),
                if (_section == LegalDocumentSection.claimsBook)
                  _buildClaimsBookContent(context),
                const SizedBox(height: 28),
                if (widget.onAdminLogin != null)
                  Center(
                    child: TextButton(
                      onPressed: widget.onAdminLogin,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.muted,
                        textStyle: const TextStyle(fontSize: 11),
                      ),
                      child: const Text('Iniciar sesión administrativa'),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.settings.text(StorefrontText.privacySubtitle),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          widget.settings.text(StorefrontText.privacyUpdatedAt),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        const _PrivacySection(
          title: 'Marco Legal Peruano (Ley N° 29733 y Nuevo Reglamento D.S. N° 016-2024-JUS)',
          body: 'Expresiones (Huancayo, Junín, Perú) garantiza la protección de tus datos personales conforme a la Ley N° 29733 — Ley de Protección de Datos Personales y su Reglamento aprobado por Decreto Supremo N° 016-2024-JUS. Aplicamos el principio de minimización de datos (Art. 7): únicamente solicitamos Nombre, Apellidos y Celular para coordinar recojos en tienda, y añadimos el número de DNI (8 dígitos) exclusivamente cuando eliges envío nacional por agencia Shalom (requisito legal de identificación exigido por la empresa de transporte para entregar encomiendas a mayores de edad). No solicitamos dirección domiciliaria privada ni datos de tarjetas bancarias o CVV.',
        ),
        const _PrivacySection(
          title: 'Ubicación para buscar agencias',
          body: 'Si tocas «Agencias cerca de mí», el navegador puede pedir permiso para usar tu ubicación. Se usa en tu dispositivo para ordenar las agencias y mostrar la distancia. Expresiones no recibe ni guarda esa ubicación.',
        ),
        const _PrivacySection(
          title: 'Consentimiento Libre, Expreso y Separado (Cero Casillas Pre-marcadas)',
          body: 'En cumplimiento del artículo 13.5 de la Ley N° 29733 y el D.S. N° 016-2024-JUS, ningún formulario de Expresiones utiliza casillas pre-marcadas ni agrupa autorizaciones en una sola casilla. El usuario otorga su consentimiento mediante dos casillas independientes: una para los Términos y Condiciones / Política de Reembolsos y otra para la Política de Privacidad, guardándose constancia auditable de la fecha, hora exacta, versión de la política y modalidad de aceptación.',
        ),
        const _PrivacySection(
          title: 'Ejercicio de Derechos ARCO y Notificación de Seguridad',
          body: 'Como titular de tus datos personales puedes ejercer gratuitamente tus derechos de Acceso, Rectificación, Cancelación y Oposición (Derechos ARCO), así como revocar tu consentimiento en cualquier momento escribiendo a nuestro canal oficial de atención en WhatsApp (+51 956 744 914) o eliminando directamente tus datos locales con el botón al final de esta sección.',
        ),
        for (final index
            in FeatureFlags.accountsEnabled
                ? List.generate(
                    FeatureFlags.paymentsEnabled ? 8 : 7,
                    (index) => index + 1,
                  )
                : const [1, 3, 4, 5, 6, 7])
          _PrivacySection(
            title: FeatureFlags.appEndToEnd && index == 8
                ? 'Pago'
                : widget.settings.text(
                    StorefrontText.privacySectionTitle(index),
                  ),
            body: FeatureFlags.appEndToEnd
                ? switch (index) {
                    3 => 'Supabase almacena el catálogo, las cuentas y el historial de compras para que puedas consultarlas desde otro dispositivo.',
                    5 => 'Los comprobantes se generan en el dispositivo y quedan bajo tu control. No se suben a un servidor de Expresiones.',
                    8 => 'La aplicación no solicita números de tarjeta, CVV, claves bancarias ni credenciales de Yape. Solo guarda el método, referencia e importe del pago.',
                    _ => widget.settings.text(
                      StorefrontText.privacySectionBody(index),
                    ),
                  }
                : !FeatureFlags.accountsEnabled && index == 3
                ? 'Supabase almacena el catálogo y los días de entrega para mantener la información actualizada.'
                : !FeatureFlags.accountsEnabled && index == 7
                ? 'Los datos locales pueden borrarse desde esta pantalla. Para otras solicitudes, comunícate con Expresiones.'
                : widget.settings.text(
                    StorefrontText.privacySectionBody(index),
                  ),
          ),
        if (_consentRecords.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registro auditable de tus consentimientos en este dispositivo',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final record in _consentRecords.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '• ${record.formattedSummary} · Contexto: ${record.context}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.pinkSoft,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.settings.text(StorefrontText.privacyControlTitle),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(widget.settings.text(StorefrontText.privacyControlBody)),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _clearing ? null : _clear,
                icon: _clearing
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline_rounded),
                label: Text(
                  widget.settings.text(StorefrontText.privacyClearButton),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTermsContent(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PrivacySection(
          title: '1. Identificación del Proveedor y Alcance Comercial (Perú)',
          body: 'El presente sitio web y catálogo digital es operado por Expresiones, con sede de atención comercial y taller en Huancayo, Junín, Perú (canal oficial WhatsApp +51 956 744 914, horario de atención de Lunes a Sábado de 11:00 a. m. a 5:00 p. m.). Estos Términos y Condiciones regulan el uso del catálogo, cotizador, carrito y coordinación de pedidos conforme al Código de Protección y Defensa del Consumidor (Ley N° 29571 - INDECOPI) y al Código Civil Peruano.',
        ),
        _PrivacySection(
          title: '2. Precios en Soles (S/), Escalas por Mayor y Cotizaciones',
          body: 'Todos los precios exhibidos en el catálogo están expresados en Soles Peruanos (S/). Las tarifas por mayor (por ejemplo, desde 3 unidades, docena o ciento) se calculan automáticamente según las reglas vigentes publicadas en cada ficha de producto y son verificadas en el servidor al registrar la solicitud. La emisión de una cotización en PDF o mensaje de WhatsApp constituye una orden de coordinación sujeta a confirmación de pago y disponibilidad de stock.',
        ),
        _PrivacySection(
          title: '3. Modalidades de Entrega: Recojo en Huancayo y Envíos por Shalom',
          body: '• Recojo en tienda (Huancayo): El cliente selecciona entre las fechas y bloques horarios habilitados en el calendario. No tiene costo de envío.\n• Envío nacional por agencia Shalom: El pedido se despacha a la agencia Shalom elegida por el cliente. Por disposición de seguridad de transporte en el Perú, el destinatario debe ser mayor de edad y presentar su DNI físico original coincidente con los datos registrados. El costo del flete de transporte de Shalom es asumido por el comprador al recoger en agencia destino, salvo acuerdo distinto por escrito.',
        ),
        _PrivacySection(
          title: '4. Propiedad Intelectual y Derechos de Imagen (D.L. N° 822)',
          body: 'Conforme al Decreto Legislativo N° 822 (Ley sobre el Derecho de Autor en el Perú) y la Decisión 486 sobre Propiedad Industrial, la marca Expresiones, las fotografías propias de productos (limpiapipas, cintas satinadas, papeles coreanos, coronas, accesorios y ramos), las ilustraciones originales de la asistente Jashy, el diseño de interfaz y el código fuente son titularidad exclusiva de Expresiones o cuentan con autorización comercial legítima. Queda estrictamente prohibida su reproducción, clonación, raspado automatizado (web scraping) o entrenamiento de modelos de inteligencia artificial sin autorización escrita.',
        ),
        _PrivacySection(
          title: '5. Uso Legítimo del Sitio y Seguridad',
          body: 'El usuario se compromete a consignar datos veraces en sus solicitudes y a no realizar intentos de alteración de precios, inyección de código ni sobrecarga automatizada de los servidores. Toda actividad maliciosa es bloqueada y auditada por nuestros sistemas de seguridad.',
        ),
      ],
    );
  }

  Widget _buildRefundsContent(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PrivacySection(
          title: '1. Garantía Legal y Derecho de Reposición o Reembolso (Ley N° 29571)',
          body: 'En estricto respeto al artículo 97 del Código de Protección y Defensa del Consumidor (Ley N° 29571 - INDECOPI), todo cliente tiene derecho a la reposición del producto, cambio por otro material o devolución íntegra del importe pagado cuando:\n• El producto entregado presente defectos de fabricación o daños de origen.\n• El material recibido no corresponda al modelo, color, medida o cantidad detallada en la cotización confirmada.',
        ),
        _PrivacySection(
          title:
              '2. Plazo y Procedimiento para Solicitar Cambios o Devoluciones',
          body: 'El cliente cuenta con un plazo de siete (7) días calendario contados desde la fecha de recojo en Huancayo o de retiro en la agencia Shalom para reportar cualquier incidencia a nuestro WhatsApp oficial (+51 956 744 914), adjuntando el número de cotización/comprobante y una fotografía o video breve del producto y su empaque sin haber sido utilizado ni alterado.',
        ),
        _PrivacySection(
          title: '3. Condiciones para Productos Personalizados o a Medida',
          body: 'Tratándose de arreglos florales eternos hechos a medida, ramos con dedicatorias personalizadas o cajas con nombres/frases específicas solicitadas por el cliente, una vez aprobada la personalización e iniciada su confección artesanal no procede la cancelación por simple cambio de opinión, manteniéndose intacta la garantía por cualquier defecto de elaboración.',
        ),
        _PrivacySection(
          title: '4. Plazos y Medios de Devolución de Dinero',
          body: 'Una vez verificado y aprobado el reembolso, Expresiones efectuará la devolución del dinero en un plazo máximo de tres (3) a cinco (5) días hábiles mediante el mismo canal utilizado por el cliente (Yape, Plin o transferencia bancaria), sin aplicar penalidades ni cobros ocultos. Si el error fue atribuible a Expresiones, nosotros asumimos íntegramente el costo de reenvío.',
        ),
      ],
    );
  }

  Widget _buildCookiesContent(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PrivacySection(
          title: '1. ¿Expresiones utiliza cookies publicitarias o de rastreo?',
          body: 'No. Expresiones NO utiliza cookies publicitarias, ni píxeles de seguimiento de redes sociales (Facebook Pixel, TikTok Pixel), ni Google Analytics, ni vende o comparte tu historial de navegación con terceros.',
        ),
        _PrivacySection(
          title: '2. Almacenamiento Local Estrictamente Técnico (Necesario)',
          body: 'Para que la tienda funcione correctamente en tu navegador o teléfono, utilizamos únicamente almacenamiento técnico local (localStorage / SharedPreferences) con cuatro finalidades indispensables:\n• Guardar temporalmente los productos que agregas a tu carrito para que no se pierdan al cambiar de pantalla.\n• Recordar tu borrador de datos de coordinación en tu propio dispositivo.\n• Mantener activa tu sesión segura (token JWT de Supabase Auth) si decides iniciar sesión.\n• Guardar la constancia técnica de que fuiste informado sobre nuestras políticas legales.',
        ),
        _PrivacySection(
          title: '3. ¿Se requiere consentimiento para cookies técnicas?',
          body: 'Conforme a los lineamientos de la Autoridad Nacional de Protección de Datos Personales del Perú (ANPD) y estándares internacionales de privacidad, el almacenamiento técnico estrictamente necesario para prestar el servicio solicitado por el usuario (como mantener el carrito de compras) está exento de bloqueo previo. Aun así, te informamos de forma transparente al ingresar y te permitimos vaciar todo el almacenamiento local en cualquier momento desde la pestaña "Política de Privacidad" → "Borrar datos de este dispositivo".',
        ),
      ],
    );
  }

  Widget _buildClaimsBookContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PrivacySection(
          title: 'Libro de Reclamaciones Virtual (D.S. N° 011-2011-PCM y Ley N° 31435)',
          body: 'Conforme al Código de Protección y Defensa del Consumidor (Ley N° 29571), ponemos a tu disposición nuestra Hoja de Reclamación Virtual:\n• RECLAMO: Disconformidad relacionada directamente con los productos o servicios adquiridos.\n• QUEJA: Disconformidad no relacionada a los bienes o servicios, o malestar respecto a la atención al público.\nLa formulación del reclamo no impide acudir a otras vías de solución de controversias ni es requisito previo para interponer una denuncia ante el INDECOPI. El proveedor debe dar respuesta en un plazo no mayor a quince (15) días hábiles improrrogables.',
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Registrar Hoja de Reclamación',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Reclamo', label: Text('Reclamo')),
                    ButtonSegment(value: 'Queja', label: Text('Queja')),
                  ],
                  selected: {_claimType},
                  onSelectionChanged: (val) =>
                      setState(() => _claimType = val.first),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _claimNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombres y Apellidos *',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _claimDniController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'DNI / CE *',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _claimPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono / WhatsApp para respuesta *',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _claimDetailController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Detalle del Reclamo o Queja *',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _claimRequestController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Pedido concreto del consumidor (opcional)',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _submitClaimBook,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Generar y enviar Hoja de Reclamación'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PrivacySection extends StatelessWidget {
  const _PrivacySection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
