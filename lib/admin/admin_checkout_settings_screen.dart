import 'package:flutter/material.dart';

import '../models/production_capacity.dart';
import '../models/storefront_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/app_notice.dart';
import '../widgets/checkout_field_icons.dart';
import '../widgets/pickup_location_map.dart';
import 'admin_operations_repository.dart';
import 'admin_site_settings_repository.dart';
import 'admin_ui.dart';

/// Administrative editor for the customer checkout experience.
class AdminCheckoutSettingsScreen extends StatelessWidget {
  const AdminCheckoutSettingsScreen({
    super.key,
    required this.repository,
    required this.operations,
  });

  final AdminSiteSettingsRepository repository;
  final AdminOperationsRepository operations;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<StorefrontSettings>(
      stream: repository.watch(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _AdminCheckoutMessage(
            title: 'No se pudo cargar la configuración',
            message: '${snapshot.error}',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final settings = snapshot.data!;
        return StreamBuilder<ProductionCapacitySnapshot>(
          stream: operations.watchCapacity(),
          builder: (context, scheduleSnapshot) {
            if (scheduleSnapshot.hasError) {
              return _AdminCheckoutMessage(
                title: 'No se pudieron cargar los días de entrega',
                message: '${scheduleSnapshot.error}',
              );
            }
            if (!scheduleSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final schedule = scheduleSnapshot.data!;
            return _CheckoutSettingsEditor(
              key: ValueKey(
                '${settings.toMap()}|${schedule.updatedAt?.millisecondsSinceEpoch ?? schedule.toMap()}',
              ),
              initial: settings,
              initialSchedule: schedule,
              onSave: repository.save,
              onSaveSchedule: operations.saveCapacity,
            );
          },
        );
      },
    );
  }
}

class _CheckoutSettingsEditor extends StatefulWidget {
  const _CheckoutSettingsEditor({
    super.key,
    required this.initial,
    required this.initialSchedule,
    required this.onSave,
    required this.onSaveSchedule,
  });

  final StorefrontSettings initial;
  final ProductionCapacitySnapshot initialSchedule;
  final Future<void> Function(StorefrontSettings) onSave;
  final Future<void> Function(ProductionCapacitySnapshot) onSaveSchedule;

  @override
  State<_CheckoutSettingsEditor> createState() =>
      _CheckoutSettingsEditorState();
}

class _CheckoutSettingsEditorState extends State<_CheckoutSettingsEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _locationAddress;
  late List<CheckoutCustomField> _fields;
  late final Set<int> _pickupWeekdays;
  late final Set<int> _shalomWeekdays;
  int? _fieldEditorIndex;
  bool _saving = false;

  static const _weekdayNames = {
    DateTime.monday: 'Lunes',
    DateTime.tuesday: 'Martes',
    DateTime.wednesday: 'Miércoles',
    DateTime.thursday: 'Jueves',
    DateTime.friday: 'Viernes',
    DateTime.saturday: 'Sábado',
    DateTime.sunday: 'Domingo',
  };

  @override
  void initState() {
    super.initState();
    final location = widget.initial.pickupLocation;
    _locationAddress = TextEditingController(text: location.address);
    _fields = List.of(widget.initial.checkoutFields);
    _pickupWeekdays = Set.of(
      widget.initialSchedule.weekdaysForDelivery('pickup'),
    );
    _shalomWeekdays = Set.of(
      widget.initialSchedule.weekdaysForDelivery('shalom'),
    );
  }

  @override
  void dispose() {
    _locationAddress.dispose();
    super.dispose();
  }

  PickupLocationSettings get _locationPreview => PickupLocationSettings(
    name: widget.initial.pickupLocation.name.trim().isEmpty
        ? 'Expresiones Eternas'
        : widget.initial.pickupLocation.name.trim(),
    address: _locationAddress.text.trim().isEmpty
        ? 'Pje. Porvenir 149, Huancayo 12001'
        : _locationAddress.text.trim(),
    latitude: widget.initial.pickupLocation.latitude ?? -12.0729918,
    longitude: widget.initial.pickupLocation.longitude ?? -75.2000781,
  );

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    if (_fieldEditorIndex != null) {
      showAppNotice(
        context,
        'Aplica o cancela el campo que estás editando antes de publicar.',
        tone: AppNoticeTone.error,
      );
      return;
    }
    if (_pickupWeekdays.isEmpty || _shalomWeekdays.isEmpty) {
      showAppNotice(
        context,
        'Selecciona al menos un día para cada forma de entrega.',
        tone: AppNoticeTone.error,
      );
      return;
    }
    final labels = <String>{};
    for (final field in _fields) {
      if (!labels.add(field.label.trim().toLowerCase())) {
        showAppNotice(
          context,
          'Cada campo adicional debe tener un nombre diferente.',
          tone: AppNoticeTone.error,
        );
        return;
      }
    }
    setState(() => _saving = true);
    try {
      await Future.wait([
        widget.onSave(
          widget.initial.copyWith(
            pickupLocation: _locationPreview,
            checkoutFields: List.unmodifiable(_fields),
          ),
        ),
        widget.onSaveSchedule(
          ProductionCapacitySnapshot(
            weeklyCapacityPoints: widget.initialSchedule.weeklyCapacityPoints,
            deliveryWeekdays: Map.unmodifiable({
              'pickup': Set.unmodifiable(_pickupWeekdays),
              'shalom': Set.unmodifiable(_shalomWeekdays),
            }),
            reservedPointsByDate: widget.initialSchedule.reservedPointsByDate,
            overridesByDate: widget.initialSchedule.overridesByDate,
            horizonDays: widget.initialSchedule.horizonDays,
            timezone: widget.initialSchedule.timezone,
          ),
        ),
      ]);
      if (mounted) {
        showAppNotice(
          context,
          'Entrega, días y formulario actualizados.',
          tone: AppNoticeTone.success,
        );
      }
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

  void _editField([int? index]) {
    setState(() => _fieldEditorIndex = index ?? -1);
  }

  void _applyField(CheckoutCustomField result) {
    final index = _fieldEditorIndex;
    if (index == null) return;
    final duplicate = _fields.asMap().entries.any(
      (entry) =>
          entry.key != (index < 0 ? null : index) &&
          entry.value.label.trim().toLowerCase() ==
              result.label.trim().toLowerCase(),
    );
    if (duplicate) {
      showAppNotice(
        context,
        'Ya existe un campo con ese nombre.',
        tone: AppNoticeTone.error,
      );
      return;
    }
    setState(() {
      if (index < 0) {
        _fields.add(result);
      } else {
        _fields[index] = result;
      }
      _fieldEditorIndex = null;
    });
  }

  void _moveField(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _fields.length) return;
    setState(() {
      final item = _fields.removeAt(index);
      _fields.insert(target, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          ResponsivePage(
            maxWidth: 1280,
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AdminSectionIntro(
                  eyebrow: 'Carrito y coordinación',
                  title: 'Entrega y formulario',
                  description: 'Configura los datos que solicitarás, la ubicación del recojo y las fechas disponibles para cada forma de entrega.',
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final twoColumns = constraints.maxWidth >= 900;
                    final location = _pickupCard(context);
                    final dates = _dateCard(context);
                    if (!twoColumns) {
                      return Column(
                        children: [location, const SizedBox(height: 18), dates],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: location),
                        const SizedBox(width: 18),
                        Expanded(flex: 4, child: dates),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                _customFieldsCard(context),
                const SizedBox(height: 20),
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

  Widget _pickupCard(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                        'Recojo en Huancayo',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        'Esta ubicación aparecerá dentro del formulario.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _locationAddress,
              onChanged: (_) => setState(() {}),
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Dirección del local',
                hintText: 'Pje. Porvenir 149, Huancayo 12001',
              ),
              validator: _required,
            ),
            const SizedBox(height: 14),
            PickupLocationMap(location: _locationPreview, height: 280),
          ],
        ),
      ),
    );
  }

  Widget _dateCard(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.pinkSoft,
                  child: Icon(Icons.calendar_month_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Días de entrega',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        'Se publican junto con este formulario.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _deliveryDayPicker(
              context,
              icon: Icons.storefront_outlined,
              title: 'Recojo en Huancayo',
              selected: _pickupWeekdays,
            ),
            const Divider(height: 32),
            _deliveryDayPicker(
              context,
              icon: Icons.local_shipping_outlined,
              title: 'Envíos por Shalom',
              selected: _shalomWeekdays,
            ),
          ],
        ),
      ),
    );
  }

  Widget _deliveryDayPicker(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Set<int> selected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 21),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.labelLarge),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (
              var weekday = DateTime.monday;
              weekday <= DateTime.sunday;
              weekday++
            )
              FilterChip(
                label: Text(_weekdayNames[weekday]!),
                labelStyle: TextStyle(
                  color: selected.contains(weekday)
                      ? Colors.white
                      : AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
                selectedColor: AppColors.ink,
                checkmarkColor: Colors.white,
                selected: selected.contains(weekday),
                onSelected: (enabled) => setState(() {
                  if (enabled) {
                    selected.add(weekday);
                  } else {
                    selected.remove(weekday);
                  }
                }),
              ),
          ],
        ),
      ],
    );
  }

  Widget _customFieldsCard(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final heading = Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: AppColors.pinkSoft,
                      child: Icon(Icons.person_outline_rounded),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tus datos de contacto',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            'Nombre y teléfono siempre se mantienen. Puedes añadir más preguntas aquí mismo.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final addButton = Tooltip(
                  message: 'Agregar campo al formulario',
                  child: FilledButton.icon(
                    onPressed: _fields.length >= 10 ? null : _editField,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Agregar campo'),
                  ),
                );
                if (constraints.maxWidth < 520) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      heading,
                      const SizedBox(height: 12),
                      Align(alignment: Alignment.centerRight, child: addButton),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: heading),
                    const SizedBox(width: 12),
                    addButton,
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            const Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _FixedContactField(
                  icon: Icons.person_outline_rounded,
                  label: 'Nombre',
                  hint: '¿Cómo te llamas?',
                ),
                _FixedContactField(
                  icon: Icons.phone_outlined,
                  label: 'Teléfono',
                  hint: '+51 999 999 999',
                ),
              ],
            ),
            const Divider(height: 32),
            if (_fieldEditorIndex != null) ...[
              _InlineCheckoutFieldEditor(
                key: ValueKey('field-editor-$_fieldEditorIndex'),
                initial: _fieldEditorIndex! < 0
                    ? null
                    : _fields[_fieldEditorIndex!],
                onApply: _applyField,
                onCancel: () => setState(() => _fieldEditorIndex = null),
              ),
              const SizedBox(height: 12),
            ],
            if (_fields.isEmpty && _fieldEditorIndex == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 26,
                ),
                decoration: BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text(
                  'Pulsa el lápiz para agregar otra pregunta al formulario.',
                  textAlign: TextAlign.center,
                ),
              )
            else if (_fieldEditorIndex == null)
              LayoutBuilder(
                builder: (context, constraints) {
                  final tileWidth = constraints.maxWidth < 320
                      ? constraints.maxWidth
                      : 320.0;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (var index = 0; index < _fields.length; index++)
                        SizedBox(
                          width: tileWidth,
                          child: _CheckoutFieldTile(
                            field: _fields[index],
                            canMoveUp: index > 0,
                            canMoveDown: index < _fields.length - 1,
                            onToggle: (value) => setState(() {
                              _fields[index] = _fields[index].copyWith(
                                enabled: value,
                              );
                            }),
                            onEdit: () => _editField(index),
                            onDelete: () =>
                                setState(() => _fields.removeAt(index)),
                            onMoveUp: () => _moveField(index, -1),
                            onMoveDown: () => _moveField(index, 1),
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

class _FixedContactField extends StatelessWidget {
  const _FixedContactField({
    required this.icon,
    required this.label,
    required this.hint,
  });

  final IconData icon;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(hint, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.lock_outline_rounded, size: 16),
        ],
      ),
    );
  }
}

class _InlineCheckoutFieldEditor extends StatefulWidget {
  const _InlineCheckoutFieldEditor({
    super.key,
    this.initial,
    required this.onApply,
    required this.onCancel,
  });

  final CheckoutCustomField? initial;
  final ValueChanged<CheckoutCustomField> onApply;
  final VoidCallback onCancel;

  @override
  State<_InlineCheckoutFieldEditor> createState() =>
      _InlineCheckoutFieldEditorState();
}

class _InlineCheckoutFieldEditorState
    extends State<_InlineCheckoutFieldEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _hint;
  late String _icon;
  late bool _required;
  late bool _multiline;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.initial?.label ?? '');
    _hint = TextEditingController(text: widget.initial?.hint ?? '');
    _icon = widget.initial?.icon ?? CheckoutFieldIcons.fallbackKey;
    _required = widget.initial?.required ?? false;
    _multiline = widget.initial?.multiline ?? false;
    _enabled = widget.initial?.enabled ?? true;
  }

  @override
  void dispose() {
    _label.dispose();
    _hint.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onApply(
      CheckoutCustomField(
        id:
            widget.initial?.id ??
            'field_${DateTime.now().microsecondsSinceEpoch}',
        label: _label.text.trim(),
        icon: _icon,
        hint: _hint.text.trim(),
        required: _required,
        multiline: _multiline,
        enabled: _enabled,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.pinkSoft.withValues(alpha: .42),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.initial == null ? 'Agregar campo' : 'Editar campo',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final fields = [
                    TextFormField(
                      controller: _label,
                      maxLength: 60,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del campo',
                        hintText: 'Ej. DNI para la agencia',
                      ),
                      validator: _requiredText,
                    ),
                    TextFormField(
                      controller: _hint,
                      maxLength: 100,
                      decoration: const InputDecoration(
                        labelText: 'Texto de ayuda (opcional)',
                      ),
                    ),
                  ];
                  if (constraints.maxWidth < 760) {
                    return Column(
                      children: [
                        fields.first,
                        const SizedBox(height: 8),
                        fields.last,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: fields.first),
                      const SizedBox(width: 12),
                      Expanded(child: fields.last),
                    ],
                  );
                },
              ),
              const SizedBox(height: 4),
              Text(
                'Icono del campo',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in CheckoutFieldIcons.options)
                    Tooltip(
                      message: option.label,
                      child: ChoiceChip(
                        avatar: Icon(option.icon, size: 18),
                        label: Text(option.label),
                        selected: _icon == option.key,
                        onSelected: (_) => setState(() => _icon = option.key),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: 245,
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Obligatorio'),
                      subtitle: const Text('El cliente deberá completarlo.'),
                      value: _required,
                      onChanged: (value) => setState(() => _required = value),
                    ),
                  ),
                  SizedBox(
                    width: 245,
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Respuesta larga'),
                      subtitle: const Text('Cuadro de varias líneas.'),
                      value: _multiline,
                      onChanged: (value) => setState(() => _multiline = value),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Visible'),
                      value: _enabled,
                      onChanged: (value) => setState(() => _enabled = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cancel = TextButton(
                    onPressed: widget.onCancel,
                    child: const Text('Cancelar'),
                  );
                  final apply = FilledButton(
                    onPressed: _submit,
                    child: const Text('Aplicar'),
                  );
                  if (constraints.maxWidth < 320) {
                    return Row(
                      children: [
                        Expanded(child: cancel),
                        const SizedBox(width: 8),
                        Expanded(child: apply),
                      ],
                    );
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [cancel, const SizedBox(width: 8), apply],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckoutFieldTile extends StatelessWidget {
  const _CheckoutFieldTile({
    required this.field,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final CheckoutCustomField field;
  final bool canMoveUp;
  final bool canMoveDown;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: field.enabled ? AppColors.surface : AppColors.canvas,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: AppColors.pinkSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(CheckoutFieldIcons.resolve(field.icon), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      field.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      [
                        field.required ? 'Obligatorio' : 'Opcional',
                        field.multiline ? 'Respuesta larga' : 'Respuesta corta',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Switch(value: field.enabled, onChanged: onToggle),
            ],
          ),
          if (field.hint.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                field.hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Subir',
                visualDensity: VisualDensity.compact,
                onPressed: canMoveUp ? onMoveUp : null,
                icon: const Icon(Icons.keyboard_arrow_up_rounded),
              ),
              IconButton(
                tooltip: 'Bajar',
                visualDensity: VisualDensity.compact,
                onPressed: canMoveDown ? onMoveDown : null,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
              ),
              IconButton(
                tooltip: 'Editar campo',
                visualDensity: VisualDensity.compact,
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Quitar campo',
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
                color: AppColors.error,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminCheckoutMessage extends StatelessWidget {
  const _AdminCheckoutMessage({required this.title, required this.message});

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

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'Este campo es obligatorio.' : null;

String? _requiredText(String? value) => _required(value);
