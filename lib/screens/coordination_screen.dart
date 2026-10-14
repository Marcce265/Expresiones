import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/coordination_details.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';

class CoordinationScreen extends StatefulWidget {
  const CoordinationScreen({
    super.key,
    required this.initial,
    required this.earliestDate,
    required this.productionPoints,
    required this.onSubmit,
  });

  final CoordinationDetails initial;
  final DateTime earliestDate;
  final int productionPoints;
  final ValueChanged<CoordinationDetails> onSubmit;

  @override
  State<CoordinationScreen> createState() => _CoordinationScreenState();
}

class _CoordinationScreenState extends State<CoordinationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _destinationController;
  late final TextEditingController _noteController;
  late DeliveryMethod _deliveryMethod;
  DateTime? _desiredDate;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial.name);
    _phoneController = TextEditingController(text: initial.phone);
    _destinationController = TextEditingController(text: initial.destination);
    _noteController = TextEditingController(text: initial.note);
    _deliveryMethod = initial.deliveryMethod;
    _desiredDate = initial.desiredDate == null
        ? null
        : _dateOnly(initial.desiredDate!);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _destinationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  DateTime get _firstDate {
    final today = _dateOnly(DateTime.now());
    final earliest = _dateOnly(widget.earliestDate);
    return earliest.isBefore(today) ? today : earliest;
  }

  DateTime get _firstSelectableDate {
    var date = _firstDate;
    while (date.weekday == DateTime.sunday) {
      date = date.add(const Duration(days: 1));
    }
    return date;
  }

  bool _isSelectable(DateTime date) {
    final value = _dateOnly(date);
    return !value.isBefore(_firstDate) && value.weekday != DateTime.sunday;
  }

  Future<void> _pickDate() async {
    final current = _desiredDate;
    final initialDate = current != null && _isSelectable(current)
        ? current
        : _firstSelectableDate;
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

  void _submit() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;

    widget.onSubmit(
      CoordinationDetails(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        deliveryMethod: _deliveryMethod,
        destination: _deliveryMethod == DeliveryMethod.shalom
            ? _destinationController.text.trim()
            : '',
        desiredDate: _desiredDate,
        note: _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ResponsivePage(
        maxWidth: 820,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Heading(onBack: () => Navigator.maybePop(context)),
              const SizedBox(height: 18),
              const StepProgress(current: 2),
              const SizedBox(height: 24),
              Text(
                'Solo pedimos lo necesario para preparar el mensaje y revisar la fecha contigo.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 22),
              const _FieldLabel('Nombre'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                maxLength: 80,
                decoration: const InputDecoration(
                  hintText: '¿Cómo te llamas?',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                  counterText: '',
                ),
                validator: _validateName,
              ),
              const SizedBox(height: 18),
              const _FieldLabel('Teléfono'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
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
                validator: _validatePhone,
              ),
              const SizedBox(height: 22),
              const _FieldLabel('¿Cómo lo recibirás?'),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final horizontal = constraints.maxWidth >= 560;
                  final pickup = _DeliveryOption(
                    title: 'Recojo en Huancayo',
                    subtitle: 'Coordinamos lugar y horario',
                    icon: Icons.storefront_outlined,
                    selected: _deliveryMethod == DeliveryMethod.pickup,
                    onTap: () =>
                        setState(() => _deliveryMethod = DeliveryMethod.pickup),
                  );
                  final shipping = _DeliveryOption(
                    title: 'Envío por Shalom',
                    subtitle: 'La tarifa se confirma después',
                    icon: Icons.local_shipping_outlined,
                    selected: _deliveryMethod == DeliveryMethod.shalom,
                    onTap: () =>
                        setState(() => _deliveryMethod = DeliveryMethod.shalom),
                  );

                  if (horizontal) {
                    return Row(
                      children: [
                        Expanded(child: pickup),
                        const SizedBox(width: 12),
                        Expanded(child: shipping),
                      ],
                    );
                  }
                  return Column(
                    children: [pickup, const SizedBox(height: 10), shipping],
                  );
                },
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _deliveryMethod == DeliveryMethod.shalom
                    ? Padding(
                        key: const ValueKey('destination'),
                        padding: const EdgeInsets.only(top: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FieldLabel('Ciudad o agencia de destino'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _destinationController,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              maxLength: 100,
                              decoration: const InputDecoration(
                                hintText:
                                    'Ej. Lima, agencia San Juan de Lurigancho',
                                prefixIcon: Icon(Icons.location_on_outlined),
                                counterText: '',
                              ),
                              validator: _validateDestination,
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('pickup')),
              ),
              const SizedBox(height: 22),
              const _FieldLabel('Fecha deseada'),
              const SizedBox(height: 8),
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
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: _desiredDate == null
                          ? AppColors.muted
                          : AppColors.ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Primera fecha estimada: ${_formatDate(_firstSelectableDate)}. Los domingos no están disponibles.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (widget.productionPoints > 0) ...[
                const SizedBox(height: 16),
                InfoBanner(
                  title: 'Revisaremos la capacidad de producción',
                  message:
                      'Tu selección requiere ${widget.productionPoints} ${widget.productionPoints == 1 ? 'punto' : 'puntos'} de producción. La fecha queda confirmada por WhatsApp.',
                  icon: Icons.schedule_outlined,
                  color: AppColors.canvas,
                ),
              ],
              const SizedBox(height: 22),
              const _FieldLabel('Nota para Expresiones'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteController,
                minLines: 3,
                maxLines: 6,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText:
                      'Color, referencia, dedicatoria o detalle adicional…',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('Revisar mi cotización'),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Todavía no se realizará ningún pago.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
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

  String? _validateDestination(String? value) {
    if (_deliveryMethod != DeliveryMethod.shalom) return null;
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Indica la ciudad o agencia de destino.';
    if (text.length < 3) return 'Escribe un destino válido.';
    return null;
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
