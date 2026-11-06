/// Public business content that can be edited from the administrative portal.
///
/// Navigation labels, validation errors and other interface controls remain in
/// code so the application stays understandable and accessible.
abstract final class StorefrontText {
  static const brandName = 'brand.name';
  static const brandTagline = 'brand.tagline';

  static const homeEyebrow = 'home.eyebrow';
  static const homeTitle = 'home.title';
  static const homeSubtitle = 'home.subtitle';
  static const homeHeroImage = 'home.heroImage';
  static const homeSearchHint = 'home.searchHint';
  static const homeFeaturedTitle = 'home.featuredTitle';
  static const homeSidebarTitle = 'home.sidebarTitle';
  static const homeSidebarBody = 'home.sidebarBody';

  static const adminHomeDescription = 'admin.homeDescription';

  static const catalogSearchHint = 'catalog.searchHint';
  static const catalogEmptyTitle = 'catalog.emptyTitle';
  static const catalogEmptyBody = 'catalog.emptyBody';

  static const quoteEmptyTitle = 'quote.emptyTitle';
  static const quoteEmptyBody = 'quote.emptyBody';
  static const quoteNoticeTitle = 'quote.noticeTitle';
  static const quoteNoticeBody = 'quote.noticeBody';
  static const quotePriceNote = 'quote.priceNote';

  static const coordinationContactTitle = 'coordination.contactTitle';
  static const coordinationContactBody = 'coordination.contactBody';
  static const coordinationDeliveryTitle = 'coordination.deliveryTitle';
  static const coordinationDeliveryBody = 'coordination.deliveryBody';
  static const coordinationPickupTitle = 'coordination.pickupTitle';
  static const coordinationPickupBody = 'coordination.pickupBody';
  static const coordinationShalomTitle = 'coordination.shalomTitle';
  static const coordinationShalomBody = 'coordination.shalomBody';
  static const coordinationDateTitle = 'coordination.dateTitle';
  static const coordinationDateBody = 'coordination.dateBody';
  static const coordinationDetailsTitle = 'coordination.detailsTitle';
  static const coordinationDetailsBody = 'coordination.detailsBody';
  static const coordinationDetailsHint = 'coordination.detailsHint';
  static const coordinationCapacityTitle = 'coordination.capacityTitle';

  static const reviewTitle = 'review.title';
  static const reviewBody = 'review.body';
  static const reviewMessageTitle = 'review.messageTitle';
  static const reviewMessageBody = 'review.messageBody';
  static const reviewPaymentNote = 'review.paymentNote';
  static const reviewContactTitle = 'review.contactTitle';
  static const reviewContactBody = 'review.contactBody';

  static const paymentEyebrow = 'payment.eyebrow';
  static const paymentTitle = 'payment.title';
  static const paymentBody = 'payment.body';
  static const paymentDemoBadge = 'payment.demoBadge';
  static const paymentCardMethod = 'payment.cardMethod';
  static const paymentCardDescription = 'payment.cardDescription';
  static const paymentYapeMethod = 'payment.yapeMethod';
  static const paymentYapeDescription = 'payment.yapeDescription';
  static const paymentShippingPending = 'payment.shippingPending';
  static const paymentSubmitButton = 'payment.submitButton';
  static const paymentProcessing = 'payment.processing';
  static const paymentDisclaimer = 'payment.disclaimer';
  static const paymentRejectedTitle = 'payment.rejectedTitle';
  static const paymentRejectedBody = 'payment.rejectedBody';
  static const paymentRetryButton = 'payment.retryButton';

  static const successEyebrow = 'success.eyebrow';
  static const successTitle = 'success.title';
  static const successBody = 'success.body';
  static const successPaymentLabel = 'success.paymentLabel';
  static const successNoCharge = 'success.noCharge';
  static const successWhatsappButton = 'success.whatsappButton';
  static const successHomeButton = 'success.homeButton';
  static const successNewOrderButton = 'success.newOrderButton';

  static const helpEyebrow = 'help.eyebrow';
  static const helpTitle = 'help.title';
  static const helpBody = 'help.body';
  static const helpBannerTitle = 'help.bannerTitle';
  static const helpBannerBody = 'help.bannerBody';
  static const helpPrivacyButton = 'help.privacyButton';
  static const helpContactButton = 'help.contactButton';

  static String helpFaqTitle(int index) => 'help.faq$index.title';
  static String helpFaqBody(int index) => 'help.faq$index.body';

  static const privacyTitle = 'privacy.title';
  static const privacySubtitle = 'privacy.subtitle';
  static const privacyUpdatedAt = 'privacy.updatedAt';
  static const privacyControlTitle = 'privacy.controlTitle';
  static const privacyControlBody = 'privacy.controlBody';
  static const privacyClearButton = 'privacy.clearButton';

  static String privacySectionTitle(int index) => 'privacy.section$index.title';
  static String privacySectionBody(int index) => 'privacy.section$index.body';

  static const defaults = <String, String>{
    brandName: 'Expresiones',
    brandTagline: 'Materiales para crear y expresar más',
    homeEyebrow: 'Catálogo de materiales para manualidades',
    homeTitle: 'Encuentra lo que necesitas para crear y expresar más.',
    homeSubtitle: 'Limpiapipas premium, cintas finas, coronas y envolturas seleccionadas. Prepara tu lista y cotiza al instante sin registros engorrosos.',
    homeHeroImage: 'assets/images/catalog_hero.webp',
    homeSearchHint: 'Buscar por material, color o código (ej: CAT-076)...',
    homeFeaturedTitle: 'Más consultados',
    homeSidebarTitle: 'Tu cuenta te acompaña',
    homeSidebarBody:
        'Tus datos y compras quedan disponibles cuando vuelvas a ingresar.',
    adminHomeDescription: 'Administra el catálogo, el carrito, las entregas y el contenido de la tienda desde un solo lugar.',
    catalogSearchHint: 'Buscar por color o modelo',
    catalogEmptyTitle: 'No encontramos productos',
    catalogEmptyBody: 'Prueba otro término o elige un filtro diferente.',
    quoteEmptyTitle: 'Tu carrito está vacío',
    quoteEmptyBody:
        'Explora el catálogo y agrega los materiales que quieras consultar.',
    quoteNoticeTitle: 'Los precios son orientativos',
    quoteNoticeBody:
        'Revisa productos y cantidades antes de continuar con tus datos.',
    quotePriceNote:
        'Los precios pueden variar según disponibilidad y personalización.',
    coordinationContactTitle: 'Tus datos de contacto',
    coordinationContactBody:
        'Tu nombre y celular se completan automáticamente desde tu cuenta.',
    coordinationDeliveryTitle: 'Forma de entrega',
    coordinationDeliveryBody:
        'Elige recojo en Huancayo o una agencia Shalom de destino.',
    coordinationPickupTitle: 'Recojo en Huancayo',
    coordinationPickupBody: 'Coordinamos lugar y horario',
    coordinationShalomTitle: 'Envío por Shalom',
    coordinationShalomBody: 'Elige una agencia en cualquier ciudad',
    coordinationDateTitle: 'Fecha deseada',
    coordinationDateBody:
        'Consulta la primera fecha estimada y elige el día que prefieres.',
    coordinationDetailsTitle: 'Detalles finales',
    coordinationDetailsBody:
        'Añade colores, referencias, dedicatorias o indicaciones especiales.',
    coordinationDetailsHint: 'Escribe aquí cualquier detalle adicional…',
    coordinationCapacityTitle: 'Capacidad de producción',
    reviewTitle: 'Revisa antes de finalizar',
    reviewBody: 'Comprueba los productos, tus datos y la entrega antes del pago simulado.',
    reviewMessageTitle: 'Resumen de la cotización',
    reviewMessageBody: 'Este es el detalle que quedará guardado en tu cuenta',
    reviewPaymentNote: 'El siguiente paso es una demostración. No se realizará ningún cobro real.',
    reviewContactTitle: 'Datos de coordinación',
    reviewContactBody: 'Contacto, entrega y fecha elegida',
    paymentEyebrow: 'Pago de demostración',
    paymentTitle: 'Completa la demostración de tu cotización',
    paymentBody: 'Elige un método de prueba para finalizar la demostración.',
    paymentDemoBadge: 'ENTORNO DE DEMOSTRACIÓN',
    paymentCardMethod: 'Tarjeta de demostración',
    paymentCardDescription:
        'Simula una aprobación sin ingresar número, fecha ni CVV.',
    paymentYapeMethod: 'Yape de demostración',
    paymentYapeDescription:
        'Simula el pago sin abrir Yape ni solicitar credenciales.',
    paymentShippingPending: 'Tarifa de envío por confirmar',
    paymentSubmitButton: 'Simular pago',
    paymentProcessing: 'Procesando simulación…',
    paymentDisclaimer: 'No ingreses datos financieros. Esta demostración no realiza cargos ni transferencias.',
    paymentRejectedTitle: 'La simulación fue rechazada',
    paymentRejectedBody: 'No se realizó ningún cobro. Puedes elegir otro método y volver a intentarlo.',
    paymentRetryButton: 'Volver a intentar',
    successEyebrow: 'Paso 5 de 5 · ¡Listo!',
    successTitle: '¡Compra simulada completada!',
    successBody: 'El comprobante quedó guardado en tu cuenta y en el panel administrativo.',
    successPaymentLabel: 'Pago simulado aprobado',
    successNoCharge: 'Este comprobante es demostrativo. No acredita un pago ni produjo ningún cobro.',
    successWhatsappButton: 'Enviar cotización por WhatsApp',
    successHomeButton: 'Volver al inicio',
    successNewOrderButton: 'Hacer otra cotización',
    helpEyebrow: 'Estamos para ayudarte',
    helpTitle: 'Preguntas frecuentes',
    helpBody: 'Jashy te acompaña para elegir, revisar y completar cada paso.',
    helpBannerTitle: 'Acceso protegido',
    helpBannerBody:
        'Tu cuenta permite completar tus datos y consultar tu historial.',
    helpPrivacyButton: 'Privacidad y mis datos',
    helpContactButton: 'Hablar con Expresiones',
    'help.faq1.title': '¿Cómo funciona la cotización?',
    'help.faq1.body': 'Elige productos y cantidades. La app calcula el subtotal y te guía hasta el pago simulado.',
    'help.faq2.title': 'Stock y precio final',
    'help.faq2.body': 'Expresiones confirma disponibilidad y precio antes de cualquier pago. Agregar productos no reserva stock.',
    'help.faq3.title': 'Recojo en Huancayo',
    'help.faq3.body': 'La dirección aparece en el mapa interno y eliges una fecha y horario disponibles.',
    'help.faq4.title': 'Envíos nacionales',
    'help.faq4.body': 'Los envíos se coordinan mediante Shalom. La tarifa se confirma según destino, tamaño y peso.',
    'help.faq5.title': 'Fechas de entrega',
    'help.faq5.body':
        'Elige una fecha habilitada para recojo o para envío por Shalom.',
    'help.faq6.title': 'Pago',
    'help.faq6.body': 'La app incluye un pago simulado para completar la demostración de la cotización. No solicita datos financieros ni realiza cobros reales.',
    privacyTitle: 'Privacidad',
    privacySubtitle: 'Política de privacidad de Expresiones',
    privacyUpdatedAt: 'Última actualización: 3 de noviembre de 2026',
    'privacy.section1.title': 'Datos guardados en tu dispositivo',
    'privacy.section1.body': 'El carrito, el nombre, el teléfono, el DNI cuando eliges Shalom, la forma de entrega, la agencia elegida, la fecha, el horario de recojo y la nota se guardan localmente para que puedas continuar después. Expresiones no recibe esos datos mientras permanecen guardados localmente.',
    'privacy.section2.title': 'Cuenta de cliente',
    'privacy.section2.body': 'Al registrarte se guardan tu nombre y celular. La contraseña es administrada de forma segura por Supabase Auth y Expresiones no puede verla.',
    'privacy.section3.title': 'Catálogo y días de entrega',
    'privacy.section3.body': 'Supabase almacena el catálogo, las cuentas y el historial de compras simuladas para que puedas consultarlas desde otro dispositivo.',
    'privacy.section4.title': 'Medición anónima',
    'privacy.section4.body': 'Se registran conteos agregados de productos vistos, agregados y completados para ordenar recomendaciones. Esos conteos no incluyen el nombre ni el teléfono.',
    'privacy.section5.title': 'Archivos exportados',
    'privacy.section5.body': 'Los archivos PDF y Excel se generan en el dispositivo. Quedan bajo tu control en la carpeta de descargas y no se suben a un servidor de Expresiones.',
    'privacy.section6.title': 'Directorio de Shalom',
    'privacy.section6.body': 'La lista de agencias es una copia local del directorio público de Shalom. Seleccionar una agencia no realiza una reserva ni comparte automáticamente tus datos con Shalom.',
    'privacy.section7.title': 'Conservación y contacto',
    'privacy.section7.body': 'Los datos locales pueden borrarse desde esta pantalla. El historial asociado a una cuenta permanece protegido en Supabase hasta que Expresiones atienda una solicitud de eliminación.',
    'privacy.section8.title': 'Pago simulado',
    'privacy.section8.body': 'La aplicación no solicita números de tarjeta, CVV, claves bancarias ni credenciales de Yape. Solo guarda el método, referencia y resultado simulados; no se realiza ningún cobro real.',
    privacyControlTitle: 'Control de tus datos',
    privacyControlBody: 'Puedes borrar ahora la información almacenada por Expresiones en este dispositivo.',
    privacyClearButton: 'Borrar mis datos locales',
  };
}

class PickupLocationSettings {
  const PickupLocationSettings({
    this.name = 'Expresiones Eternas',
    this.address = 'Pje. Porvenir 149, Huancayo 12001',
    this.latitude = -12.0729918,
    this.longitude = -75.2000781,
  });

  final String name;
  final String address;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude! >= -90 &&
      latitude! <= 90 &&
      longitude! >= -180 &&
      longitude! <= 180;

  factory PickupLocationSettings.fromMap(Map<String, dynamic> map) {
    final rawName = map['name']?.toString().trim() ?? '';
    final rawAddress = map['address']?.toString().trim() ?? '';
    return PickupLocationSettings(
      name: rawName.isEmpty ? 'Expresiones Eternas' : rawName,
      address: rawAddress.isEmpty
          ? 'Pje. Porvenir 149, Huancayo 12001'
          : rawAddress,
      latitude: _settingDouble(map['latitude']) ?? -12.0729918,
      longitude: _settingDouble(map['longitude']) ?? -75.2000781,
    );
  }

  PickupLocationSettings copyWith({
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    bool clearCoordinates = false,
  }) => PickupLocationSettings(
    name: name ?? this.name,
    address: address ?? this.address,
    latitude: clearCoordinates ? null : latitude ?? this.latitude,
    longitude: clearCoordinates ? null : longitude ?? this.longitude,
  );

  Map<String, dynamic> toMap() => {
    'name': name.trim(),
    'address': address.trim(),
    'latitude': latitude,
    'longitude': longitude,
  };
}

enum CheckoutFieldScope {
  both,
  pickup,
  shalom;

  String get label => switch (this) {
    both => 'Recojo y Shalom',
    pickup => 'Solo recojo',
    shalom => 'Solo Shalom',
  };
}

class CheckoutCustomField {
  const CheckoutCustomField({
    required this.id,
    required this.label,
    this.icon = 'edit',
    this.hint = '',
    this.required = false,
    this.multiline = false,
    this.enabled = true,
    this.scope = CheckoutFieldScope.both,
  });

  final String id;
  final String label;
  final String icon;
  final String hint;
  final bool required;
  final bool multiline;
  final bool enabled;
  final CheckoutFieldScope scope;

  bool appliesTo(String deliveryMethod) =>
      scope == CheckoutFieldScope.both || scope.name == deliveryMethod;

  static bool isReservedLabel(String label) {
    final normalized = label.trim().toLowerCase();
    return normalized == 'dni' ||
        normalized == 'fecha de nacimiento' ||
        normalized == 'horario de recojo';
  }

  factory CheckoutCustomField.fromMap(Map<String, dynamic> map) {
    return CheckoutCustomField(
      id: map['id']?.toString().trim() ?? '',
      label: map['label']?.toString().trim() ?? '',
      icon: map['icon']?.toString().trim() ?? 'edit',
      hint: map['hint']?.toString().trim() ?? '',
      required: map['required'] == true,
      multiline: map['multiline'] == true,
      enabled: map['enabled'] != false,
      scope: CheckoutFieldScope.values.firstWhere(
        (value) => value.name == map['scope']?.toString(),
        orElse: () => CheckoutFieldScope.both,
      ),
    );
  }

  CheckoutCustomField copyWith({
    String? id,
    String? label,
    String? icon,
    String? hint,
    bool? required,
    bool? multiline,
    bool? enabled,
    CheckoutFieldScope? scope,
  }) => CheckoutCustomField(
    id: id ?? this.id,
    label: label ?? this.label,
    icon: icon ?? this.icon,
    hint: hint ?? this.hint,
    required: required ?? this.required,
    multiline: multiline ?? this.multiline,
    enabled: enabled ?? this.enabled,
    scope: scope ?? this.scope,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'label': label.trim(),
    'icon': icon.trim().isEmpty ? 'edit' : icon.trim(),
    'hint': hint.trim(),
    'required': required,
    'multiline': multiline,
    'enabled': enabled,
    'scope': scope.name,
  };
}

class StorefrontSettings {
  const StorefrontSettings({
    this.whatsappNumber = defaultWhatsappNumber,
    this.pickupLocation = const PickupLocationSettings(),
    this.checkoutFields = const [],
    this.texts = const {},
  });

  static const defaultWhatsappNumber = '51956744914';

  final String whatsappNumber;
  final PickupLocationSettings pickupLocation;
  final List<CheckoutCustomField> checkoutFields;
  final Map<String, String> texts;

  String text(String key) {
    final configured = texts[key]?.trim() ?? '';
    return configured.isNotEmpty
        ? configured
        : StorefrontText.defaults[key] ?? key;
  }

  String get normalizedWhatsappNumber {
    final digits = whatsappNumber.replaceAll(RegExp(r'\D'), '');
    return digits.isEmpty ? defaultWhatsappNumber : digits;
  }

  factory StorefrontSettings.fromMap(Map<String, dynamic> map) {
    final rawTexts = map['texts'];
    final parsedTexts = <String, String>{};
    if (rawTexts is Map) {
      for (final entry in rawTexts.entries) {
        final value = entry.value?.toString().trim() ?? '';
        if (value.isNotEmpty) parsedTexts[entry.key.toString()] = value;
      }
    }
    final rawNumber = map['whatsappNumber']?.toString().trim() ?? '';
    final rawPickup = map['pickupLocation'];
    final rawFields = map['checkoutFields'];
    final checkoutFields = <CheckoutCustomField>[];
    if (rawFields is Iterable) {
      final ids = <String>{};
      for (final item in rawFields.whereType<Map>()) {
        final field = CheckoutCustomField.fromMap(
          item.map((key, value) => MapEntry(key.toString(), value)),
        );
        if (field.id.isNotEmpty &&
            field.label.isNotEmpty &&
            ids.add(field.id)) {
          checkoutFields.add(field);
        }
      }
    }
    return StorefrontSettings(
      whatsappNumber: rawNumber.isEmpty ? defaultWhatsappNumber : rawNumber,
      pickupLocation: rawPickup is Map
          ? PickupLocationSettings.fromMap(
              rawPickup.map((key, value) => MapEntry(key.toString(), value)),
            )
          : const PickupLocationSettings(),
      checkoutFields: List.unmodifiable(checkoutFields),
      texts: Map.unmodifiable(parsedTexts),
    );
  }

  StorefrontSettings copyWith({
    String? whatsappNumber,
    PickupLocationSettings? pickupLocation,
    List<CheckoutCustomField>? checkoutFields,
    Map<String, String>? texts,
  }) => StorefrontSettings(
    whatsappNumber: whatsappNumber ?? this.whatsappNumber,
    pickupLocation: pickupLocation ?? this.pickupLocation,
    checkoutFields: checkoutFields == null
        ? this.checkoutFields
        : List.unmodifiable(checkoutFields),
    texts: texts == null ? this.texts : Map.unmodifiable(texts),
  );

  Map<String, dynamic> toMap() => {
    'whatsappNumber': normalizedWhatsappNumber,
    'pickupLocation': pickupLocation.toMap(),
    'checkoutFields': checkoutFields.map((field) => field.toMap()).toList(),
    'texts': {
      for (final key in StorefrontText.defaults.keys) key: text(key),
      for (final entry in texts.entries)
        if (!StorefrontText.defaults.containsKey(entry.key))
          entry.key: entry.value,
    },
  };
}

double? _settingDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().trim() ?? '');
}
