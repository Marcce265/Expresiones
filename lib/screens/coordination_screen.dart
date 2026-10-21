import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/coordination_details.dart';
import '../models/shalom_agency.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/app_notice.dart';
import '../widgets/shalom_embedded_map.dart';
import 'shalom_agency_picker.dart';

class CoordinationScreen extends StatefulWidget {
  const CoordinationScreen({
    super.key,
    required this.initial,
    required this.earliestDate,
    required this.productionPoints,
    required this.onSubmit,
    this.isDateAvailable,
  });

  final CoordinationDetails initial;
  final DateTime earliestDate;
  final int productionPoints;
  final ValueChanged<CoordinationDetails> onSubmit;
  final bool Function(DateTime date)? isDateAvailable;

  @override
  State<CoordinationScreen> createState() => _CoordinationScreenState();
}

class _CoordinationScreenState extends State<CoordinationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _noteController;
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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
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

  bool _isSelectable(DateTime date) {
    final value = _dateOnly(date);
    return !value.isBefore(_firstDate) &&
        value.weekday != DateTime.sunday &&
        (widget.isDateAvailable?.call(value) ?? true);
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
                title: 'Tus datos de contacto',
                description: 'Los usaremos únicamente para coordinar esta cotización contigo.',
                child: _ContactFields(
                  nameController: _nameController,
                  phoneController: _phoneController,
                  validateName: _validateName,
                  validatePhone: _validatePhone,
                ),
              ),
              const SizedBox(height: 18),
              _FormSectionCard(
                number: '2',
                icon: Icons.local_shipping_outlined,
                title: 'Entrega del pedido',
                description:
                    'Elige recojo en Huancayo o una agencia Shalom de destino.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final horizontal = constraints.maxWidth >= 620;
                        final pickup = _DeliveryOption(
                          title: 'Recojo en Huancayo',
                          subtitle: 'Coordinamos lugar y horario',
                          icon: Icons.storefront_outlined,
                          selected: _deliveryMethod == DeliveryMethod.pickup,
                          onTap: () => setState(() {
                            _deliveryMethod = DeliveryMethod.pickup;
                            _agencyError = false;
                          }),
                        );
                        final shipping = _DeliveryOption(
                          title: 'Envío por Shalom',
                          subtitle: 'Elige una agencia en cualquier ciudad',
                          icon: Icons.local_shipping_outlined,
                          selected: _deliveryMethod == DeliveryMethod.shalom,
                          onTap: () => setState(
                            () => _deliveryMethod = DeliveryMethod.shalom,
                          ),
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
                          : const SizedBox.shrink(key: ValueKey('pickup')),
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
                    title: 'Fecha deseada',
                    description: 'Consulta la primera fecha estimada y elige el día que prefieres.',
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
                              : 'Primera fecha estimada: ${_formatDate(_firstSelectableDate!)}. Los domingos no están disponibles.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (widget.productionPoints > 0) ...[
                          const SizedBox(height: 16),
                          InfoBanner(
                            title: 'Capacidad de producción',
                            message:
                                'Tu selección requiere ${widget.productionPoints} ${widget.productionPoints == 1 ? 'punto' : 'puntos'} de trabajo. Confirmaremos la fecha por WhatsApp.',
                            icon: Icons.schedule_outlined,
                            color: AppColors.pinkSoft,
                          ),
                        ],
                      ],
                    ),
                  );
                  final noteSection = _FormSectionCard(
                    number: '4',
                    icon: Icons.notes_rounded,
                    title: 'Detalles finales',
                    description: 'Añade colores, referencias, dedicatorias o indicaciones especiales.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _noteController,
                          minLines: 4,
                          maxLines: 7,
                          maxLength: 500,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText:
                                'Escribe aquí cualquier detalle adicional…',
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
      'Todavía no se realizará ningún pago.',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall,
    );
    final button = FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_forward_rounded, size: 19),
      label: const Text('Revisar mi cotización'),
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
