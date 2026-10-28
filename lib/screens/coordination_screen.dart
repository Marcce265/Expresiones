import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/coordination_details.dart';
import '../models/production_capacity.dart';
import '../models/shalom_agency.dart';
import '../models/storefront_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/app_notice.dart';
import '../widgets/checkout_field_icons.dart';
import '../widgets/pickup_location_map.dart';
import '../widgets/shalom_embedded_map.dart';
import 'shalom_agency_picker.dart';

class CoordinationScreen extends StatefulWidget {
  const CoordinationScreen({
    super.key,
    required this.initial,
    required this.earliestDate,
    required this.onSubmit,
    this.isDateAvailable,
    this.deliveryWeekdays,
    this.settings = const StorefrontSettings(),
  });

  final CoordinationDetails initial;
  final DateTime earliestDate;
  final ValueChanged<CoordinationDetails> onSubmit;
  final bool Function(DateTime date, DeliveryMethod method)? isDateAvailable;
  final Set<int> Function(DeliveryMethod method)? deliveryWeekdays;
  final StorefrontSettings settings;

  @override
  State<CoordinationScreen> createState() => _CoordinationScreenState();
}

class _CoordinationScreenState extends State<CoordinationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _noteController;
  final Map<String, TextEditingController> _customControllers = {};
  late DeliveryMethod _deliveryMethod;
  DateTime? _desiredDate;
  late String _agencyId;
  late String _agencyName;
  late String _agencyAddress;
  late String _agencyLocality;
  double? _agencyLatitude;
  double? _agencyLongitude;
  bool _agencyError = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial.name);
    _phoneController = TextEditingController(text: initial.phone);
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
  }

  @override
  void didUpdateWidget(covariant CoordinationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.checkoutFields != widget.settings.checkoutFields) {
      _syncCustomControllers(initialValues: widget.initial.customFields);
    }
  }

  void _syncCustomControllers({required Map<String, String> initialValues}) {
    final activeIds = <String>{};
    for (final field in widget.settings.checkoutFields.where(
      (field) => field.enabled,
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
    _nameController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    for (final controller in _customControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  DateTime get _firstDate {
    final today = _dateOnly(DateTime.now());
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

  bool _isSelectable(DateTime date) {
    final value = _dateOnly(date);
    return !value.isBefore(_firstDate) &&
        _allowedWeekdays.contains(value.weekday) &&
        (widget.isDateAvailable?.call(value, _deliveryMethod) ?? true);
  }

  void _selectDeliveryMethod(DeliveryMethod method) {
    setState(() {
      _deliveryMethod = method;
      _agencyError = false;
      if (_desiredDate != null && !_isSelectable(_desiredDate!)) {
        _desiredDate = null;
      }
    });
  }

  Future<void> _pickDate() async {
    final current = _desiredDate;
    final initialDate = current != null && _isSelectable(current)
        ? current
        : _firstSelectableDate;
    if (initialDate == null) {
      if (mounted) {
        showAppNotice(
          context,
          'No hay fechas disponibles. Escríbenos por WhatsApp para coordinar.',
          tone: AppNoticeTone.info,
        );
      }
      return;
    }
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: _firstDate,
      lastDate: _firstDate.add(const Duration(days: 365)),
      selectableDayPredicate: _isSelectable,
      helpText: 'Fecha deseada',
      cancelText: 'Cancelar',
      confirmText: 'Elegir',
      fieldLabelText: 'Fecha deseada',
      errorFormatText: 'Ingresa una fecha válida',
      errorInvalidText: 'Elige otro día disponible',
    );
    if (selected != null && mounted) {
      setState(() => _desiredDate = _dateOnly(selected));
    }
  }

  Future<void> _pickAgency() async {
    final agency = await Navigator.of(context).push<ShalomAgency>(
      MaterialPageRoute(
        builder: (context) => ShalomAgencyPicker(selectedId: _agencyId),
      ),
    );
    if (agency == null || !mounted) return;
    setState(() {
      _agencyId = agency.id;
      _agencyName = agency.displayName;
      _agencyAddress = agency.address;
      _agencyLocality = agency.localityLabel;
      _agencyLatitude = agency.latitude;
      _agencyLongitude = agency.longitude;
      _agencyError = false;
    });
  }

  void _submit() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_desiredDate != null && !_isSelectable(_desiredDate!)) {
      setState(() => _desiredDate = null);
      showAppNotice(
        context,
        'La fecha elegida ya no está disponible. Elige una nueva fecha.',
        tone: AppNoticeTone.info,
      );
      return;
    }
    if (_deliveryMethod == DeliveryMethod.shalom && _agencyId.isEmpty) {
      setState(() => _agencyError = true);
      return;
    }

    widget.onSubmit(
      CoordinationDetails(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
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
        customFields: Map.unmodifiable({
          for (final field in widget.settings.checkoutFields)
            if (field.enabled &&
                (_customControllers[field.id]?.text.trim().isNotEmpty ?? false))
              field.label: _customControllers[field.id]!.text.trim(),
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ResponsivePage(
        maxWidth: 1480,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Heading(onBack: () => Navigator.maybePop(context)),
              const SizedBox(height: 18),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: const StepProgress(current: 2),
                ),
              ),
              const SizedBox(height: 26),
              _FormSectionCard(
                number: '1',
                icon: Icons.person_outline_rounded,
                title: widget.settings.text(
                  StorefrontText.coordinationContactTitle,
                ),
                description: widget.settings.text(
                  StorefrontText.coordinationContactBody,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ContactFields(
                      nameController: _nameController,
                      phoneController: _phoneController,
                      validateName: _validateName,
                      validatePhone: _validatePhone,
                    ),
                    if (widget.settings.checkoutFields.any(
                      (field) => field.enabled,
                    )) ...[
                      const Divider(height: 34),
                      _CustomCheckoutFields(
                        fields: widget.settings.checkoutFields
                            .where((field) => field.enabled)
                            .toList(growable: false),
                        controllers: _customControllers,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _FormSectionCard(
                number: '2',
                icon: Icons.local_shipping_outlined,
                title: widget.settings.text(
                  StorefrontText.coordinationDeliveryTitle,
                ),
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
                          onTap: () =>
                              _selectDeliveryMethod(DeliveryMethod.pickup),
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
                          onTap: () =>
                              _selectDeliveryMethod(DeliveryMethod.shalom),
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
                          children: [
                            pickup,
                            const SizedBox(height: 10),
                            shipping,
                          ],
                        );
                      },
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _deliveryMethod == DeliveryMethod.shalom
                          ? _ShalomDestinationSection(
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
              LayoutBuilder(
                builder: (context, constraints) {
                  final dateSection = _FormSectionCard(
                    number: '3',
                    icon: Icons.calendar_month_outlined,
                    title: widget.settings.text(
                      StorefrontText.coordinationDateTitle,
                    ),
                    description: widget.settings.text(
                      StorefrontText.coordinationDateBody,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(14),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.calendar_today_outlined),
                              suffixIcon: Icon(Icons.expand_more_rounded),
                            ),
                            child: Text(
                              _desiredDate == null
                                  ? 'Selecciona una fecha (opcional)'
                                  : _formatDate(_desiredDate!),
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: _desiredDate == null
                                        ? AppColors.muted
                                        : AppColors.ink,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _firstSelectableDate == null
                              ? 'No hay fechas disponibles dentro de los próximos 365 días.'
                              : 'Primera fecha estimada: ${_formatDate(_firstSelectableDate!)}. ${_deliveryScheduleMessage()}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
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
          ),
        ),
      ),
    );
  }

  String? _validateName(String? value) {
    final text = value?.trim() ?? '';
    final letters = RegExp(r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]').allMatches(text).length;
    if (text.isEmpty) return 'Escribe tu nombre.';
    if (letters < 2) return 'Escribe un nombre válido.';
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
      constraints: const BoxConstraints(minHeight: 320),
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
                ? 'Revisa la ubicación directamente en el mapa. El horario exacto se confirma por WhatsApp.'
                : 'La dirección y el horario exactos se confirmarán por WhatsApp.',
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
            'El envío y la disponibilidad se confirman contigo por WhatsApp.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _CustomCheckoutFields extends StatelessWidget {
  const _CustomCheckoutFields({
    required this.fields,
    required this.controllers,
  });

  final List<CheckoutCustomField> fields;
  final Map<String, TextEditingController> controllers;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final half = constraints.maxWidth >= 650
            ? (constraints.maxWidth - 18) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 18,
          runSpacing: 18,
          children: [
            for (final field in fields)
              SizedBox(
                width: field.multiline ? constraints.maxWidth : half,
                child: _LabeledField(
                  label: '${field.label}${field.required ? ' *' : ''}',
                  child: TextFormField(
                    controller: controllers[field.id],
                    minLines: field.multiline ? 3 : 1,
                    maxLines: field.multiline ? 5 : 1,
                    maxLength: field.multiline ? 500 : 160,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: field.hint.isEmpty ? null : field.hint,
                      prefixIcon: Icon(CheckoutFieldIcons.resolve(field.icon)),
                      counterText: field.multiline ? null : '',
                      alignLabelWithHint: field.multiline,
                    ),
                    validator: (value) {
                      if (field.required && (value?.trim().isEmpty ?? true)) {
                        return 'Completa este campo.';
                      }
                      return null;
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AgencySelectionCard extends StatelessWidget {
  const _AgencySelectionCard({
    required this.hasAgency,
    required this.agencyName,
    required this.agencyAddress,
    required this.agencyLocality,
    required this.showError,
    required this.onTap,
  });

  final bool hasAgency;
  final String agencyName;
  final String agencyAddress;
  final String agencyLocality;
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
            constraints: const BoxConstraints(minHeight: 330),
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
                        'Elige la agencia donde recogerás tu pedido',
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
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _ContactFields extends StatelessWidget {
  const _ContactFields({
    required this.nameController,
    required this.phoneController,
    required this.validateName,
    required this.validatePhone,
  });

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final FormFieldValidator<String> validateName;
  final FormFieldValidator<String> validatePhone;

  @override
  Widget build(BuildContext context) {
    final name = _LabeledField(
      label: 'Nombre',
      child: TextFormField(
        controller: nameController,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.name],
        maxLength: 80,
        decoration: const InputDecoration(
          hintText: '¿Cómo te llamas?',
          prefixIcon: Icon(Icons.person_outline_rounded),
          counterText: '',
        ),
        validator: validateName,
      ),
    );
    final phone = _LabeledField(
      label: 'Teléfono',
      child: TextFormField(
        controller: phoneController,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.telephoneNumber],
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ()-]')),
          LengthLimitingTextInputFormatter(18),
        ],
        decoration: const InputDecoration(
          hintText: '+51 999 999 999',
          prefixIcon: Icon(Icons.phone_outlined),
        ),
        validator: validatePhone,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 650) {
          return Column(children: [name, const SizedBox(height: 18), phone]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: name),
            const SizedBox(width: 18),
            Expanded(child: phone),
          ],
        );
      },
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
      'Después podrás completar un pago de demostración sin cobros reales.',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall,
    );
    final button = FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_forward_rounded, size: 19),
      label: const Text('Revisar mi compra'),
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
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            'Datos para coordinar',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
        ),
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
            color: selected ? AppColors.ink : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.ink : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? Colors.white : AppColors.ink),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selected ? Colors.white : AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: selected
                            ? Colors.white.withValues(alpha: .72)
                            : AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

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
