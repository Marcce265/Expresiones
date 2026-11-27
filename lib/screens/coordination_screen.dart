import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/feature_flags.dart';
import '../models/catalog_models.dart';
import '../models/coordination_details.dart';
import '../models/production_capacity.dart';
import '../models/shalom_agency.dart';
import '../models/storefront_settings.dart';
import '../security/rate_limiter.dart';
import '../services/legal_consent_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/app_notice.dart';
import '../widgets/breadcrumb_bar.dart';
import '../widgets/checkout_field_icons.dart';
import '../widgets/legal_consent_checkboxes.dart';
import '../widgets/pickup_location_map.dart';
import '../widgets/shalom_embedded_map.dart';
import '../widgets/store_footer.dart';
import 'shalom_agency_picker.dart';
import 'shalom_destination_picker.dart';

class CoordinationScreen extends StatefulWidget {
  const CoordinationScreen({
    super.key,
    required this.initial,
    required this.earliestDate,
    required this.onSubmit,
    this.isDateAvailable,
    this.deliveryWeekdays,
    this.pickupTimeSlots = ProductionCapacitySnapshot.defaultPickupTimeSlots,
    this.pickupTimeSlotsForDate,
    this.onSelectCategory,
    this.onOpenHelp,
    this.settings = const StorefrontSettings(),
    this.cartQuantity = 0,
    this.useInlineAgencyPicker = false,
    this.now = DateTime.now,
  });

  final CoordinationDetails initial;
  final DateTime earliestDate;
  final ValueChanged<CoordinationDetails> onSubmit;
  final bool Function(DateTime date, DeliveryMethod method)? isDateAvailable;
  final Set<int> Function(DeliveryMethod method)? deliveryWeekdays;
  final List<String> pickupTimeSlots;
  final List<String> Function(DateTime date)? pickupTimeSlotsForDate;
  final ValueChanged<ProductCategory>? onSelectCategory;
  final VoidCallback? onOpenHelp;
  final StorefrontSettings settings;
  final int cartQuantity;
  final bool useInlineAgencyPicker;
  final DateTime Function() now;

  @override
  State<CoordinationScreen> createState() => _CoordinationScreenState();
}

class _CoordinationScreenState extends State<CoordinationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _dniController;
  late final TextEditingController _noteController;
  final Map<String, TextEditingController> _customControllers = {};
  late DeliveryMethod _deliveryMethod;
  DateTime? _desiredDate;
  String? _pickupTimeSlot;
  late String _agencyId;
  late String _agencyName;
  late String _agencyAddress;
  late String _agencyLocality;
  double? _agencyLatitude;
  double? _agencyLongitude;
  bool _agencyError = false;
  bool _pickingAgency = false;
  bool _desiredDateError = false;
  bool _pickupTimeSlotError = false;
  bool _termsAccepted = false;
  bool _privacyAccepted = false;
  bool _consentError = false;
  late final Timer _scheduleTimer;

  DateTime get _limaNow => limaClockTime(widget.now());
  DateTime get _today => dateOnly(_limaNow);

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _termsAccepted = initial.termsAcceptedAt != null;
    _privacyAccepted = initial.privacyAcceptedAt != null;
    final savedLastName = _answerForLabel(initial.customFields, 'Apellidos');
    final savedFirstName = _answerForLabel(initial.customFields, 'Nombre');
    if (savedLastName.isNotEmpty || savedFirstName.isNotEmpty) {
      _nameController = TextEditingController(text: savedFirstName);
      _lastNameController = TextEditingController(text: savedLastName);
    } else if (initial.name.isNotEmpty) {
      final parts = initial.name.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        _nameController = TextEditingController(text: parts.first);
        _lastNameController = TextEditingController(
          text: parts.sublist(1).join(' '),
        );
      } else {
        _nameController = TextEditingController(text: initial.name);
        _lastNameController = TextEditingController();
      }
    } else {
      _nameController = TextEditingController();
      _lastNameController = TextEditingController();
    }
    _phoneController = TextEditingController(text: initial.phone);
    _dniController = TextEditingController(
      text: _answerForLabel(initial.customFields, 'DNI'),
    );
    _noteController = TextEditingController(text: initial.note);
    _syncCustomControllers(initialValues: initial.customFields);
    _deliveryMethod = initial.deliveryMethod;
    _agencyId = initial.shalomAgencyId;
    _agencyName = initial.shalomAgencyName;
    _agencyAddress = initial.shalomAgencyAddress;
    _agencyLocality = initial.shalomAgencyLocality;
    _agencyLatitude = initial.shalomAgencyLatitude;
    _agencyLongitude = initial.shalomAgencyLongitude;
    _desiredDate = initial.desiredDate == null
        ? null
        : _dateOnly(initial.desiredDate!);
    if (_desiredDate != null && !_isSelectable(_desiredDate!)) {
      _desiredDate = null;
    }
    final savedPickupTime = _answerForLabel(
      initial.customFields,
      'Horario de recojo',
    );
    _pickupTimeSlot = _availablePickupTimeSlots.contains(savedPickupTime)
        ? savedPickupTime
        : null;
    _scheduleTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => setState(_clearUnavailableSelection),
    );
  }

  @override
  void didUpdateWidget(covariant CoordinationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.checkoutFields != widget.settings.checkoutFields) {
      _syncCustomControllers(initialValues: widget.initial.customFields);
    }
    _clearUnavailableSelection();
  }

  void _clearUnavailableSelection() {
    final date = _desiredDate;
    if (date != null && !_isSelectable(date)) _desiredDate = null;
    if (!_availablePickupTimeSlots.contains(_pickupTimeSlot)) {
      _pickupTimeSlot = null;
    }
  }

  static bool _isStandardField(CheckoutCustomField field) {
    final lowerId = field.id.toLowerCase();
    final lowerLabel = field.label.toLowerCase();
    return lowerId == 'field_name' ||
        lowerId == 'name' ||
        lowerId == 'field_last_name' ||
        lowerId == 'last_name' ||
        lowerId == 'field_phone' ||
        lowerId == 'phone' ||
        lowerId == 'field_dni' ||
        lowerId == 'dni' ||
        lowerLabel == 'nombre' ||
        lowerLabel == 'nombres' ||
        lowerLabel == 'nombre completo' ||
        lowerLabel == 'apellidos' ||
        lowerLabel == 'apellido' ||
        lowerLabel == 'teléfono' ||
        lowerLabel == 'telefono' ||
        lowerLabel == 'dni';
  }

  List<CheckoutCustomField> get _orderedFields {
    final configured = widget.settings.checkoutFields
        .where((field) => !CheckoutCustomField.isReservedLabel(field.label))
        .toList();
    final hasName = configured.any(
      (f) =>
          f.id == 'field_name' ||
          f.id == 'name' ||
          (f.label.trim().toLowerCase().contains('nombre') &&
              !f.label.trim().toLowerCase().contains('apellido')),
    );
    final hasLastName = configured.any(
      (f) =>
          f.id == 'field_last_name' ||
          f.id == 'last_name' ||
          f.label.trim().toLowerCase().contains('apellido'),
    );
    final hasPhone = configured.any(
      (f) =>
          f.id == 'field_phone' ||
          f.id == 'phone' ||
          f.label.trim().toLowerCase().contains('teléfono') ||
          f.label.trim().toLowerCase().contains('telefono'),
    );
    final hasDni = configured.any(
      (f) =>
          f.id == 'field_dni' ||
          f.id == 'dni' ||
          f.label.trim().toLowerCase().contains('dni'),
    );

    final defaults = <CheckoutCustomField>[];
    if (!hasName) {
      defaults.add(
        const CheckoutCustomField(
          id: 'field_name',
          label: 'Nombre',
          icon: 'person',
          hint: '¿Cómo te llamas?',
          required: true,
          scope: CheckoutFieldScope.both,
          inputType: CheckoutFieldInputType.lettersOnly,
        ),
      );
    }
    if (!hasLastName) {
      defaults.add(
        const CheckoutCustomField(
          id: 'field_last_name',
          label: 'Apellidos',
          icon: 'person',
          hint: 'Tus apellidos',
          required: true,
          scope: CheckoutFieldScope.both,
          inputType: CheckoutFieldInputType.lettersOnly,
        ),
      );
    }
    if (!hasPhone) {
      defaults.add(
        const CheckoutCustomField(
          id: 'field_phone',
          label: 'Teléfono',
          icon: 'phone',
          hint: '+51 999 999 999',
          required: true,
          scope: CheckoutFieldScope.both,
          inputType: CheckoutFieldInputType.numbersOnly,
        ),
      );
    }
    if (!hasDni) {
      defaults.add(
        const CheckoutCustomField(
          id: 'field_dni',
          label: 'DNI',
          icon: 'badge',
          hint: '8 dígitos · titular mayor de edad',
          required: true,
          scope: CheckoutFieldScope.shalom,
          inputType: CheckoutFieldInputType.numbersOnly,
        ),
      );
    }
    return [...defaults, ...configured];
  }

  void _syncCustomControllers({required Map<String, String> initialValues}) {
    final activeIds = <String>{};
    for (final field in _orderedFields.where(
      (field) =>
          field.enabled &&
          !_isStandardField(field) &&
          !CheckoutCustomField.isReservedLabel(field.label),
    )) {
      activeIds.add(field.id);
      _customControllers.putIfAbsent(
        field.id,
        () => TextEditingController(
          text: initialValues[field.label] ?? initialValues[field.id] ?? '',
        ),
      );
    }
    for (final id in _customControllers.keys.toList()) {
      if (!activeIds.contains(id)) {
        _customControllers.remove(id)?.dispose();
      }
    }
  }

  @override
  void dispose() {
    _scheduleTimer.cancel();
    _nameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _dniController.dispose();
    _noteController.dispose();
    for (final controller in _customControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  DateTime get _firstDate {
    final today = _today;
    final earliest = _dateOnly(widget.earliestDate);
    return earliest.isBefore(today) ? today : earliest;
  }

  DateTime? get _firstSelectableDate {
    final lastDate = _firstDate.add(const Duration(days: 365));
    for (
      var date = _firstDate;
      !date.isAfter(lastDate);
      date = date.add(const Duration(days: 1))
    ) {
      if (_isSelectable(date)) return date;
    }
    return null;
  }

  Set<int> get _allowedWeekdays =>
      widget.deliveryWeekdays?.call(_deliveryMethod) ??
      ProductionCapacitySnapshot.defaultDeliveryWeekdays[_deliveryMethod
          .name] ??
      const {};

  List<String> get _availablePickupTimeSlots {
    final date = _desiredDate;
    if (date == null) return const [];
    return _pickupTimeSlotsFor(date);
  }

  List<String> _pickupTimeSlotsFor(DateTime date) {
    final slots =
        widget.pickupTimeSlotsForDate?.call(date) ?? widget.pickupTimeSlots;
    final now = _limaNow;
    if (!DateUtils.isSameDay(date, now)) return slots;

    final elapsedMinutes = now.hour * 60 + now.minute;
    return slots
        .where((slot) {
          final start = RegExp(r'^(\d{2}):(\d{2})').firstMatch(slot);
          if (start == null) return false;
          final startMinutes =
              int.parse(start.group(1)!) * 60 + int.parse(start.group(2)!);
          return startMinutes > elapsedMinutes;
        })
        .toList(growable: false);
  }

  bool _isSelectable(DateTime date) {
    final value = _dateOnly(date);
    return !value.isBefore(_firstDate) &&
        !value.isAfter(_firstDate.add(const Duration(days: 365))) &&
        _allowedWeekdays.contains(value.weekday) &&
        (widget.isDateAvailable?.call(value, _deliveryMethod) ?? true) &&
        (_deliveryMethod != DeliveryMethod.pickup ||
            _pickupTimeSlotsFor(value).isNotEmpty);
  }

  void _selectDeliveryMethod(DeliveryMethod method) {
    setState(() {
      _deliveryMethod = method;
      _agencyError = false;
      _pickupTimeSlotError = false;
      if (_desiredDate != null && !_isSelectable(_desiredDate!)) {
        _desiredDate = null;
      }
      if (!_availablePickupTimeSlots.contains(_pickupTimeSlot)) {
        _pickupTimeSlot = null;
      }
    });
  }

  List<CheckoutCustomField> get _activeCheckoutFields => _orderedFields
      .where(
        (field) =>
            field.enabled &&
            !_isStandardField(field) &&
            !CheckoutCustomField.isReservedLabel(field.label) &&
            field.appliesTo(_deliveryMethod.name),
      )
      .toList(growable: false);

  void _selectDate(DateTime date) {
    if (!_isSelectable(date)) return;
    setState(() {
      _desiredDate = date;
      _desiredDateError = false;
      _pickupTimeSlotError = false;
      if (!_availablePickupTimeSlots.contains(_pickupTimeSlot)) {
        _pickupTimeSlot = null;
      }
    });
  }

  Future<void> _pickAgency() async {
    if (_pickingAgency) return;
    if (!ClientRateLimiter.instance.tryAcquire(
      'shalom_picker_open',
      maxAttempts: 8,
      window: const Duration(seconds: 15),
    )) {
      showAppNotice(
        context,
        'Espera un momento antes de volver a cambiar la agencia.',
      );
      return;
    }
    _pickingAgency = true;
    try {
      final agency = await Navigator.of(context).push<ShalomAgency>(
        MaterialPageRoute(
          builder: (context) => ShalomAgencyPicker(selectedId: _agencyId),
        ),
      );
      if (agency == null || !mounted) return;
      _setAgency(agency);
    } finally {
      _pickingAgency = false;
    }
  }

  void _setAgency(ShalomAgency? agency) {
    if (agency == null && _agencyId.isEmpty) return;
    setState(() {
      _agencyId = agency?.id ?? '';
      _agencyName = agency?.displayName ?? '';
      _agencyAddress = agency?.address ?? '';
      _agencyLocality = agency?.localityLabel ?? '';
      _agencyLatitude = agency?.latitude;
      _agencyLongitude = agency?.longitude;
      _agencyError = false;
    });
  }

  void _submit() {
    FocusManager.instance.primaryFocus?.unfocus();
    final previousDate = _desiredDate;
    final previousSlot = _pickupTimeSlot;
    _clearUnavailableSelection();
    if (previousDate != _desiredDate ||
        (_deliveryMethod == DeliveryMethod.pickup &&
            previousSlot != _pickupTimeSlot)) {
      showAppNotice(
        context,
        previousDate != _desiredDate
            ? 'La fecha elegida ya no está disponible. Elige otra para continuar.'
            : 'El horario elegido ya no está disponible. Elige otro para continuar.',
        tone: AppNoticeTone.info,
      );
    }
    final formValid = _formKey.currentState!.validate();
    final needsShippingIdentity = _deliveryMethod == DeliveryMethod.shalom;
    setState(() {
      _desiredDateError = _desiredDate == null;
      _pickupTimeSlotError =
          _deliveryMethod == DeliveryMethod.pickup && _pickupTimeSlot == null;
      _agencyError = needsShippingIdentity && _agencyId.isEmpty;
      _consentError = !_termsAccepted || !_privacyAccepted;
    });
    if (!formValid ||
        _desiredDateError ||
        _pickupTimeSlotError ||
        _agencyError ||
        _consentError) {
      return;
    }
    if (!ClientRateLimiter.instance.tryAcquire(
      'coordination_submit',
      maxAttempts: 10,
      window: const Duration(seconds: 15),
    )) {
      showAppNotice(
        context,
        'Espera unos segundos antes de volver a enviar tus datos.',
      );
      return;
    }
    final fullName = [
      _nameController.text.trim(),
      _lastNameController.text.trim(),
    ].where((s) => s.isNotEmpty).join(' ');
    final cleanPhone = _phoneController.text.trim();
    final acceptedAt = DateTime.now().toUtc();
    final acceptedChannel = LegalConsentService.defaultChannel;

    unawaited(
      LegalConsentService.recordConsent(
        context: 'checkout_coordination',
        termsAccepted: _termsAccepted,
        privacyAccepted: _privacyAccepted,
        customerName: fullName,
        customerPhone: cleanPhone,
        acceptedVia: acceptedChannel,
        timestamp: acceptedAt,
      ),
    );

    widget.onSubmit(
      CoordinationDetails(
        name: fullName,
        phone: cleanPhone,
        deliveryMethod: _deliveryMethod,
        destination: _deliveryMethod == DeliveryMethod.shalom
            ? '$_agencyName · $_agencyLocality'
            : '',
        shalomAgencyId: _deliveryMethod == DeliveryMethod.shalom
            ? _agencyId
            : '',
        shalomAgencyName: _deliveryMethod == DeliveryMethod.shalom
            ? _agencyName
            : '',
        shalomAgencyAddress: _deliveryMethod == DeliveryMethod.shalom
            ? _agencyAddress
            : '',
        shalomAgencyLocality: _deliveryMethod == DeliveryMethod.shalom
            ? _agencyLocality
            : '',
        shalomAgencyLatitude: _deliveryMethod == DeliveryMethod.shalom
            ? _agencyLatitude
            : null,
        shalomAgencyLongitude: _deliveryMethod == DeliveryMethod.shalom
            ? _agencyLongitude
            : null,
        desiredDate: _desiredDate,
        note: _noteController.text.trim(),
        termsAcceptedAt: acceptedAt,
        privacyAcceptedAt: acceptedAt,
        legalPolicyVersion: kCurrentLegalPolicyVersion,
        legalAcceptedVia: acceptedChannel,
        customFields: Map.unmodifiable({
          if (_deliveryMethod == DeliveryMethod.shalom) ...{
            'DNI': _dniController.text.trim(),
          },
          if (_deliveryMethod == DeliveryMethod.pickup)
            'Horario de recojo': _pickupTimeSlot!,
          for (final field in _activeCheckoutFields)
            if (_customControllers[field.id]?.text.trim().isNotEmpty ?? false)
              field.label: _customControllers[field.id]!.text.trim(),
        }),
      ),
    );
  }

  Widget _buildUnifiedContactFields() {
    final activeFields = _orderedFields
        .where(
          (field) => field.enabled && field.appliesTo(_deliveryMethod.name),
        )
        .toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final half = constraints.maxWidth >= 650
            ? (constraints.maxWidth - 18) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 18,
          runSpacing: 18,
          children: [
            for (final field in activeFields)
              SizedBox(
                width: field.multiline ? constraints.maxWidth : half,
                child: _buildSingleContactField(field),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSingleContactField(CheckoutCustomField field) {
    final lowerId = field.id.toLowerCase();
    final lowerLabel = field.label.toLowerCase();

    if (lowerId == 'field_name' ||
        lowerId == 'name' ||
        (lowerLabel.contains('nombre') && !lowerLabel.contains('apellido'))) {
      final label = field.label.isNotEmpty ? '${field.label} *' : 'Nombre *';
      final hint = field.hint.isNotEmpty ? field.hint : '¿Cómo te llamas?';

      return _LabeledField(
        label: label,
        child: TextFormField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.givenName],
          maxLength: 80,
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp(r"[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s'-]"),
            ),
            LengthLimitingTextInputFormatter(80),
          ],
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(
              CheckoutFieldIcons.resolve(
                field.icon.isNotEmpty ? field.icon : 'person',
              ),
            ),
            counterText: '',
          ),
          validator: _validateName,
        ),
      );
    }

    if (lowerId == 'field_last_name' ||
        lowerId == 'last_name' ||
        lowerLabel.contains('apellido')) {
      final label = field.label.isNotEmpty ? '${field.label} *' : 'Apellidos *';
      final hint = field.hint.isNotEmpty ? field.hint : 'Tus apellidos';

      return _LabeledField(
        label: label,
        child: TextFormField(
          controller: _lastNameController,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.familyName],
          maxLength: 80,
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp(r"[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s'-]"),
            ),
            LengthLimitingTextInputFormatter(80),
          ],
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(
              CheckoutFieldIcons.resolve(
                field.icon.isNotEmpty ? field.icon : 'person',
              ),
            ),
            counterText: '',
          ),
          validator: _validateLastName,
        ),
      );
    }

    if (lowerId == 'field_phone' ||
        lowerId == 'phone' ||
        lowerLabel.contains('teléfono') ||
        lowerLabel.contains('telefono')) {
      return _LabeledField(
        label: '${field.label} *',
        child: TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.telephoneNumber],
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ()-]')),
            LengthLimitingTextInputFormatter(18),
          ],
          decoration: InputDecoration(
            hintText: field.hint.isNotEmpty ? field.hint : '+51 999 999 999',
            prefixIcon: Icon(
              CheckoutFieldIcons.resolve(
                field.icon.isNotEmpty ? field.icon : 'phone',
              ),
            ),
            counterText: '',
          ),
          validator: _validatePhone,
        ),
      );
    }

    if (lowerId == 'field_dni' ||
        lowerId == 'dni' ||
        lowerLabel.contains('dni')) {
      final dniField = _LabeledField(
        label: '${field.label} *',
        child: TextFormField(
          controller: _dniController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          maxLength: 8,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(8),
          ],
          decoration: InputDecoration(
            hintText: field.hint.isNotEmpty && !field.hint.contains('8 dígitos')
                ? field.hint
                : '8 dígitos',
            prefixIcon: Icon(
              CheckoutFieldIcons.resolve(
                field.icon.isNotEmpty ? field.icon : 'badge',
              ),
            ),
            counterText: '',
          ),
          validator: _validateDni,
        ),
      );

      return dniField;
    }

    final controller = _customControllers[field.id];
    final inputFormatters = <TextInputFormatter>[
      if (field.inputType == CheckoutFieldInputType.lettersOnly)
        FilteringTextInputFormatter.allow(
          RegExp(r"[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s'-]"),
        ),
      if (field.inputType == CheckoutFieldInputType.numbersOnly)
        FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(field.multiline ? 300 : 80),
    ];

    return _LabeledField(
      label: '${field.label} *',
      child: TextFormField(
        controller: controller,
        minLines: field.multiline ? 2 : 1,
        maxLines: field.multiline ? 4 : 1,
        maxLength: field.multiline ? 300 : 80,
        keyboardType: field.inputType == CheckoutFieldInputType.numbersOnly
            ? TextInputType.number
            : (field.multiline ? TextInputType.multiline : TextInputType.text),
        textCapitalization:
            field.inputType == CheckoutFieldInputType.lettersOnly
            ? TextCapitalization.words
            : TextCapitalization.sentences,
        textInputAction: field.multiline
            ? TextInputAction.newline
            : TextInputAction.next,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          hintText: field.hint.isEmpty ? 'Obligatorio' : field.hint,
          prefixIcon: Icon(CheckoutFieldIcons.resolve(field.icon)),
          counterText: '',
          alignLabelWithHint: field.multiline,
        ),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (text.isEmpty) {
            return 'Completa este campo.';
          }
          if (field.inputType == CheckoutFieldInputType.lettersOnly &&
              RegExp(r'\d').hasMatch(text)) {
            return 'No se permiten números.';
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    void onBack() {
      Navigator.maybePop(context);
    }

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FormSectionCard(
          number: '1',
          icon: Icons.local_shipping_outlined,
          title: widget.settings.text(StorefrontText.coordinationDeliveryTitle),
          description: widget.settings.text(
            StorefrontText.coordinationDeliveryBody,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final horizontal = constraints.maxWidth >= 620;
                  final pickup = _DeliveryOption(
                    title: widget.settings.text(
                      StorefrontText.coordinationPickupTitle,
                    ),
                    subtitle: widget.settings.text(
                      StorefrontText.coordinationPickupBody,
                    ),
                    icon: Icons.storefront_outlined,
                    selected: _deliveryMethod == DeliveryMethod.pickup,
                    onTap: () => _selectDeliveryMethod(DeliveryMethod.pickup),
                  );
                  final shipping = _DeliveryOption(
                    title: widget.settings.text(
                      StorefrontText.coordinationShalomTitle,
                    ),
                    subtitle: widget.settings.text(
                      StorefrontText.coordinationShalomBody,
                    ),
                    icon: Icons.local_shipping_outlined,
                    selected: _deliveryMethod == DeliveryMethod.shalom,
                    onTap: () => _selectDeliveryMethod(DeliveryMethod.shalom),
                  );

                  if (horizontal) {
                    return Row(
                      children: [
                        Expanded(child: pickup),
                        const SizedBox(width: 14),
                        Expanded(child: shipping),
                      ],
                    );
                  }
                  return Column(
                    children: [pickup, const SizedBox(height: 10), shipping],
                  );
                },
              ),
              if (!widget.useInlineAgencyPicker &&
                  _deliveryMethod == DeliveryMethod.shalom &&
                  widget.cartQuantity > 0) ...[
                const SizedBox(height: 12),
                Text(
                  'Embalaje: S/ ${shalomPackingFee(widget.cartQuantity).toStringAsFixed(2)}. Flete de Shalom por confirmar.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _deliveryMethod == DeliveryMethod.shalom
                    ? widget.useInlineAgencyPicker
                          ? ShalomDestinationPicker(
                              selectedId: _agencyId,
                              showError: _agencyError,
                              onSelected: _setAgency,
                            )
                          : _ShalomDestinationSection(
                              key: const ValueKey('destination'),
                              agencyId: _agencyId,
                              agencyName: _agencyName,
                              agencyAddress: _agencyAddress,
                              agencyLocality: _agencyLocality,
                              latitude: _agencyLatitude,
                              longitude: _agencyLongitude,
                              showError: _agencyError,
                              onChooseAgency: _pickAgency,
                            )
                    : _PickupDestinationSection(
                        key: const ValueKey('pickup'),
                        location: widget.settings.pickupLocation,
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _FormSectionCard(
          number: '2',
          icon: Icons.person_outline_rounded,
          title: widget.settings.text(StorefrontText.coordinationContactTitle),
          description: FeatureFlags.accountsEnabled
              ? widget.settings.text(StorefrontText.coordinationContactBody)
              : 'Usaremos estos datos solo para coordinar tu cotización.',
          child: _buildUnifiedContactFields(),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final dateSection = _FormSectionCard(
              number: '3',
              icon: Icons.calendar_month_outlined,
              title: _deliveryMethod == DeliveryMethod.pickup
                  ? 'Fecha de recojo'
                  : 'Fecha de envío',
              description:
                  widget.settings.texts[StorefrontText.coordinationDateBody]
                          ?.trim()
                          .isNotEmpty ==
                      true
                  ? widget.settings.text(StorefrontText.coordinationDateBody)
                  : _deliveryScheduleMessage(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DeliveryCalendar(
                    key: ValueKey(_deliveryMethod),
                    first: _firstDate,
                    last: _firstDate.add(const Duration(days: 365)),
                    initial: _desiredDate ?? _firstSelectableDate ?? _firstDate,
                    selected: _desiredDate,
                    today: _today,
                    isSelectable: _isSelectable,
                    onSelected: _selectDate,
                  ),
                  if (_desiredDateError) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Selecciona una fecha.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (_firstSelectableDate == null) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'No hay fechas disponibles para esta forma de entrega.',
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (_deliveryMethod == DeliveryMethod.pickup)
                    _PickupTimeSelector(
                      slots: _availablePickupTimeSlots,
                      selected: _pickupTimeSlot,
                      enabled: _desiredDate != null,
                      showError: _pickupTimeSlotError,
                      onSelected: (slot) => setState(() {
                        _pickupTimeSlot = slot;
                        _pickupTimeSlotError = false;
                      }),
                    )
                  else ...[
                    const _FieldLabel('Horario de envío'),
                    const SizedBox(height: 8),
                    const _ShalomDispatchNotice(),
                  ],
                ],
              ),
            );
            final noteSection = _FormSectionCard(
              number: '4',
              icon: Icons.notes_rounded,
              title: widget.settings.text(
                StorefrontText.coordinationDetailsTitle,
              ),
              description: widget.settings.text(
                StorefrontText.coordinationDetailsBody,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _noteController,
                    minLines: 4,
                    maxLines: 7,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: widget.settings.text(
                        StorefrontText.coordinationDetailsHint,
                      ),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  LegalConsentCheckboxes(
                    termsAccepted: _termsAccepted,
                    privacyAccepted: _privacyAccepted,
                    showError: _consentError,
                    settings: widget.settings,
                    onTermsChanged: (checked) => setState(() {
                      _termsAccepted = checked;
                      if (_termsAccepted && _privacyAccepted) {
                        _consentError = false;
                      }
                    }),
                    onPrivacyChanged: (checked) => setState(() {
                      _privacyAccepted = checked;
                      if (_termsAccepted && _privacyAccepted) {
                        _consentError = false;
                      }
                    }),
                  ),
                  const SizedBox(height: 18),
                  _SubmitArea(onPressed: _submit),
                ],
              ),
            );

            if (constraints.maxWidth < 900) {
              return Column(
                children: [
                  dateSection,
                  const SizedBox(height: 18),
                  noteSection,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: dateSection),
                const SizedBox(width: 18),
                Expanded(flex: 6, child: noteSection),
              ],
            );
          },
        ),
      ],
    );

    return SingleChildScrollView(
      child: Column(
        children: [
          ResponsivePage.storefront(
            top: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Heading(onBack: onBack),
                const SizedBox(height: 18),
                Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: details,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          StoreFooter(
            settings: widget.settings,
            onSelectCategory: widget.onSelectCategory,
            onOpenQuote: onBack,
            onOpenHelp: widget.onOpenHelp,
            whatsappNumber: widget.settings.whatsappNumber,
          ),
        ],
      ),
    );
  }

  String? _validateName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Escribe tu nombre.';
    if (RegExp(r'\d').hasMatch(text)) {
      return 'No se permiten números en el nombre.';
    }
    final letters = RegExp(r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]').allMatches(text).length;
    if (letters < 2) return 'Escribe un nombre válido.';
    return null;
  }

  String? _validateLastName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Escribe tus apellidos.';
    if (RegExp(r'\d').hasMatch(text)) {
      return 'No se permiten números en los apellidos.';
    }
    final letters = RegExp(r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]').allMatches(text).length;
    if (letters < 2) return 'Escribe un apellido válido.';
    return null;
  }

  String? _validateDni(String? value) {
    final digits = (value ?? '').trim();
    if (digits.isEmpty) return 'Escribe tu DNI.';
    if (!RegExp(r'^\d{8}$').hasMatch(digits)) {
      return 'El DNI debe tener 8 dígitos.';
    }
    return null;
  }

  String _deliveryScheduleMessage() {
    final days = _formatWeekdays(_allowedWeekdays);
    return _deliveryMethod == DeliveryMethod.shalom
        ? 'Los envíos por Shalom salen $days.'
        : 'Puedes elegir recojo $days.';
  }

  String? _validatePhone(String? value) {
    var digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('51') && digits.length == 11) {
      digits = digits.substring(2);
    }
    if (digits.isEmpty) return 'Escribe tu número de teléfono.';
    if (digits.length != 9) return 'Ingresa un número peruano de 9 dígitos.';
    return null;
  }
}

class _FormSectionCard extends StatelessWidget {
  const _FormSectionCard({
    required this.number,
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
  });

  final String number;
  final IconData icon;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < 600 ? 18 : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.pinkSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(icon, size: 22),
                      Positioned(
                        right: -9,
                        bottom: -9,
                        child: Container(
                          width: 19,
                          height: 19,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: AppColors.ink,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            number,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            child,
          ],
        ),
      ),
    );
  }
}

class _PickupDestinationSection extends StatelessWidget {
  const _PickupDestinationSection({super.key, required this.location});

  final PickupLocationSettings location;

  @override
  Widget build(BuildContext context) {
    final details = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.pinkSoft,
                child: Icon(Icons.storefront_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Punto de recojo',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      location.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              if (location.hasCoordinates)
                const Icon(Icons.check_circle_rounded),
            ],
          ),
          const SizedBox(height: 18),
          _AgencyDetail(icon: Icons.place_outlined, text: location.address),
          const SizedBox(height: 14),
          Text(
            location.hasCoordinates
                ? 'Revisa la ubicación directamente en el mapa y elige un horario disponible.'
                : 'La dirección y el horario se mostrarán antes de finalizar.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
    final map = PickupLocationMap(location: location, height: 320);

    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel('Ubicación de recojo'),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 880) {
                return Column(
                  children: [details, const SizedBox(height: 12), map],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: details),
                  const SizedBox(width: 18),
                  Expanded(flex: 7, child: map),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ShalomDestinationSection extends StatelessWidget {
  const _ShalomDestinationSection({
    super.key,
    required this.agencyId,
    required this.agencyName,
    required this.agencyAddress,
    required this.agencyLocality,
    required this.latitude,
    required this.longitude,
    required this.showError,
    required this.onChooseAgency,
  });

  final String agencyId;
  final String agencyName;
  final String agencyAddress;
  final String agencyLocality;
  final double? latitude;
  final double? longitude;
  final bool showError;
  final VoidCallback onChooseAgency;

  bool get hasAgency => agencyId.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final selector = _AgencySelectionCard(
      hasAgency: hasAgency,
      agencyName: agencyName,
      agencyAddress: agencyAddress,
      agencyLocality: agencyLocality,
      transitEstimate: ShalomAgency.estimateTransitFromHuancayo(
        locality: agencyLocality,
        latitude: latitude,
        longitude: longitude,
      ),
      showError: showError,
      onTap: onChooseAgency,
    );
    final map = ShalomEmbeddedMap(
      selectedAgencyId: agencyId,
      selectedAgencyName: agencyName,
      selectedAgencyLocality: agencyLocality,
      latitude: latitude,
      longitude: longitude,
      height: 330,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel('Agencia de destino'),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 880) {
                return Column(
                  children: [selector, const SizedBox(height: 12), map],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: selector),
                  const SizedBox(width: 18),
                  Expanded(flex: 7, child: map),
                ],
              );
            },
          ),
          const SizedBox(height: 9),
          Text(
            'La agencia y la fecha quedarán incluidas en tu resumen.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _AgencySelectionCard extends StatelessWidget {
  const _AgencySelectionCard({
    required this.hasAgency,
    required this.agencyName,
    required this.agencyAddress,
    required this.agencyLocality,
    required this.transitEstimate,
    required this.showError,
    required this.onTap,
  });

  final bool hasAgency;
  final String agencyName;
  final String agencyAddress;
  final String agencyLocality;
  final String transitEstimate;
  final bool showError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: hasAgency
          ? 'Cambiar agencia Shalom. $agencyName, $agencyLocality'
          : 'Elegir agencia Shalom',
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: double.infinity,
            constraints: hasAgency
                ? null
                : const BoxConstraints(minHeight: 330),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: showError ? AppColors.error : AppColors.border,
                width: showError ? 1.5 : 1,
              ),
            ),
            child: hasAgency
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: const BoxDecoration(
                              color: AppColors.pinkSoft,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.location_on_outlined),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Agencia elegida',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  agencyName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.ink,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (agencyLocality.isNotEmpty)
                        _AgencyDetail(
                          icon: Icons.place_outlined,
                          text: agencyLocality,
                        ),
                      if (agencyAddress.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _AgencyDetail(
                          icon: Icons.signpost_outlined,
                          text: agencyAddress,
                        ),
                      ],
                      if (transitEstimate.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _AgencyDetail(
                          icon: Icons.schedule_rounded,
                          text: transitEstimate,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: onTap,
                          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                          label: const Text('Cambiar agencia'),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: const BoxDecoration(
                          color: AppColors.pinkSoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_location_alt_outlined),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Elige la agencia donde recogerás tu envío',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Puedes buscar por ciudad, distrito o dirección.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: onTap,
                        icon: const Icon(Icons.search_rounded, size: 18),
                        label: const Text('Buscar agencia'),
                      ),
                      if (showError) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Selecciona una agencia para continuar.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.error),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _AgencyDetail extends StatelessWidget {
  const _AgencyDetail({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: AppColors.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}

class _DeliveryCalendar extends StatefulWidget {
  const _DeliveryCalendar({
    super.key,
    required this.first,
    required this.last,
    required this.initial,
    required this.selected,
    required this.today,
    required this.isSelectable,
    required this.onSelected,
  });

  final DateTime first, last, initial, today;
  final DateTime? selected;
  final bool Function(DateTime) isSelectable;
  final ValueChanged<DateTime> onSelected;

  @override
  State<_DeliveryCalendar> createState() => _DeliveryCalendarState();
}

class _DeliveryCalendarState extends State<_DeliveryCalendar> {
  late DateTime _month = DateTime(widget.initial.year, widget.initial.month);

  @override
  Widget build(BuildContext context) {
    final first = DateTime(widget.first.year, widget.first.month);
    final last = DateTime(widget.last.year, widget.last.month);
    final month = _month.isBefore(first)
        ? first
        : _month.isAfter(last)
        ? last
        : _month;
    final offset = month.weekday - DateTime.monday;
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('delivery-calendar'),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Mes anterior',
                onPressed: month.isAfter(first)
                    ? () => setState(
                        () => _month = DateTime(month.year, month.month - 1),
                      )
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    MaterialLocalizations.of(context).formatMonthYear(month),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Mes siguiente',
                onPressed: month.isBefore(last)
                    ? () => setState(
                        () => _month = DateTime(month.year, month.month + 1),
                      )
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          Row(
            children: [
              for (final (letter, name) in const [
                ('L', 'Lunes'),
                ('M', 'Martes'),
                ('M', 'Miércoles'),
                ('J', 'Jueves'),
                ('V', 'Viernes'),
                ('S', 'Sábado'),
                ('D', 'Domingo'),
              ])
                Expanded(
                  child: Semantics(
                    label: name,
                    excludeSemantics: true,
                    child: Text(
                      letter,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var row = 0; row < (offset + days + 6) ~/ 7; row++)
            Row(
              children: [
                for (var column = 0; column < 7; column++)
                  Expanded(
                    child: _dayCell(month, row * 7 + column - offset + 1, days),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _dayCell(DateTime month, int day, int monthLength) {
    if (day < 1 || day > monthLength) return const SizedBox.shrink();
    final date = DateTime(month.year, month.month, day);
    final enabled =
        !date.isBefore(widget.first) &&
        !date.isAfter(widget.last) &&
        widget.isSelectable(date);
    final selected = enabled && DateUtils.isSameDay(date, widget.selected);
    final today = enabled && DateUtils.isSameDay(date, widget.today);
    return Padding(
      padding: const EdgeInsets.all(1),
      child: Semantics(
        label: _formatDate(date),
        selected: selected,
        child: TextButton(
          onPressed: enabled ? () => widget.onSelected(date) : null,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 42),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: selected ? Colors.white : AppColors.ink,
            disabledForegroundColor: AppColors.muted,
            backgroundColor: selected ? AppColors.rose : AppColors.surface,
            side: today && !selected
                ? const BorderSide(color: AppColors.ink)
                : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: ExcludeSemantics(
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: selected ? 15 : null,
                fontWeight: selected ? FontWeight.w800 : null,
                decoration: enabled ? null : TextDecoration.lineThrough,
                decorationThickness: enabled ? null : 2.2,
                decorationColor: enabled ? null : AppColors.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PickupTimeSelector extends StatelessWidget {
  const _PickupTimeSelector({
    required this.slots,
    required this.selected,
    required this.enabled,
    required this.showError,
    required this.onSelected,
  });

  final List<String> slots;
  final String? selected;
  final bool enabled;
  final bool showError;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Horario de recojo'),
        const SizedBox(height: 10),
        if (!enabled) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('Elige primero el día de recojo.'),
          ),
          const SizedBox(height: 10),
        ],
        Column(
          children: [
            for (var i = 0; i < slots.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _PickupTimeCard(
                label: slots[i],
                selected: selected == slots[i],
                enabled: enabled,
                onTap: () => onSelected(slots[i]),
              ),
            ],
          ],
        ),
        if (showError) ...[
          const SizedBox(height: 8),
          Text(
            'Selecciona un horario de recojo.',
            style: textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}

class _PickupTimeCard extends StatelessWidget {
  const _PickupTimeCard({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bgColor = selected
        ? AppColors.pinkSoft.withValues(alpha: .5)
        : AppColors.surface;
    final borderColor = selected ? AppColors.rose : AppColors.border;

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: borderColor, width: selected ? 1.4 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? AppColors.ink : AppColors.muted,
                      width: 1.6,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: selected
                      ? Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.ink,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Gratis',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShalomDispatchNotice extends StatelessWidget {
  const _ShalomDispatchNotice();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.schedule_outlined, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Los envíos se llevan a la agencia Shalom los días habilitados entre las 5:00 p. m. y 6:00 p. m.; no necesitas elegir un horario.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_FieldLabel(label), const SizedBox(height: 8), child],
    );
  }
}

class _SubmitArea extends StatelessWidget {
  const _SubmitArea({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final hint = Text(
      FeatureFlags.appEndToEnd
          ? 'Revisa tus datos antes de continuar al pago.'
          : 'Revisa tus datos antes de continuar al resumen.',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall,
    );
    final button = FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_forward_rounded, size: 19),
      label: Text(
        FeatureFlags.appEndToEnd
            ? 'Continuar al pago'
            : 'Revisar mi cotización',
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            children: [
              SizedBox(width: double.infinity, child: button),
              const SizedBox(height: 10),
              hint,
            ],
          );
        }
        return Row(
          children: [
            Expanded(
              child: Align(alignment: Alignment.centerLeft, child: hint),
            ),
            const SizedBox(width: 20),
            SizedBox(width: 280, child: button),
          ],
        );
      },
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return AppBreadcrumbBar(
      onBack: onBack,
      items: [
        BreadcrumbItem(label: 'Carrito', onTap: onBack),
        const BreadcrumbItem(label: 'Datos'),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium
          ?.copyWith(letterSpacing: .8),
    );
  }
}

class _DeliveryOption extends StatelessWidget {
  const _DeliveryOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $subtitle',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 104),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? AppColors.pinkSoft : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.rose : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? AppColors.roseDeep : AppColors.ink),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selected ? AppColors.roseDeep : AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: selected ? AppColors.roseDeep : AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.roseDeep,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _answerForLabel(Map<String, String> answers, String label) {
  final expected = label.toLowerCase();
  for (final entry in answers.entries) {
    if (entry.key.trim().toLowerCase() == expected) return entry.value.trim();
  }
  return '';
}

String _formatDate(DateTime value) {
  const months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  return '${value.day} de ${months[value.month - 1]} de ${value.year}';
}

String _formatWeekdays(Set<int> weekdays) {
  const names = {
    DateTime.monday: 'lunes',
    DateTime.tuesday: 'martes',
    DateTime.wednesday: 'miércoles',
    DateTime.thursday: 'jueves',
    DateTime.friday: 'viernes',
    DateTime.saturday: 'sábado',
    DateTime.sunday: 'domingo',
  };
  final values = weekdays.toList()..sort();
  final labels = values.map((day) => names[day]!).toList(growable: false);
  if (labels.isEmpty) return 'según disponibilidad';
  if (labels.length == 1) return 'el ${labels.single}';
  return '${labels.take(labels.length - 1).join(', ')} y ${labels.last}';
}
