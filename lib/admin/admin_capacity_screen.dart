import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/production_capacity.dart';
import '../theme/app_theme.dart';
import 'admin_operations_repository.dart';

class AdminCapacityScreen extends StatelessWidget {
  const AdminCapacityScreen({super.key, required this.repository});

  final AdminOperationsRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Capacidad de producción')),
      body: StreamBuilder<ProductionCapacitySnapshot>(
        stream: repository.watchCapacity(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _CapacityMessage(
              title: 'No se pudo cargar la capacidad',
              message: '${snapshot.error}',
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final capacity = snapshot.data!;
          return _CapacityEditor(
            key: ValueKey(
              capacity.updatedAt?.millisecondsSinceEpoch ??
                  capacity.toMap().toString(),
            ),
            initial: capacity,
            onSave: repository.saveCapacity,
          );
        },
      ),
    );
  }
}

class _CapacityEditor extends StatefulWidget {
  const _CapacityEditor({
    super.key,
    required this.initial,
    required this.onSave,
  });

  final ProductionCapacitySnapshot initial;
  final Future<void> Function(ProductionCapacitySnapshot) onSave;

  @override
  State<_CapacityEditor> createState() => _CapacityEditorState();
}

class _CapacityEditorState extends State<_CapacityEditor> {
  late final Map<int, TextEditingController> _weekly;
  late final TextEditingController _horizon;
  late final Map<String, int> _reserved;
  late final Map<String, ProductionDayOverride> _overrides;
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
    _weekly = {
      for (var weekday = 1; weekday <= 7; weekday++)
        weekday: TextEditingController(
          text: '${widget.initial.weeklyCapacityPoints[weekday] ?? 0}',
        ),
    };
    _horizon = TextEditingController(text: '${widget.initial.horizonDays}');
    _reserved = Map.of(widget.initial.reservedPointsByDate);
    _overrides = Map.of(widget.initial.overridesByDate);
  }

  @override
  void dispose() {
    for (final controller in _weekly.values) {
      controller.dispose();
    }
    _horizon.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final weekly = <int, int>{};
    for (final entry in _weekly.entries) {
      final value = int.tryParse(entry.value.text.trim());
      if (value == null || value < 0) {
        _show('Revisa la capacidad de ${_weekdayNames[entry.key]}.');
        return;
      }
      weekly[entry.key] = value;
    }
    final horizon = int.tryParse(_horizon.text.trim());
    if (horizon == null || horizon < 1 || horizon > 365) {
      _show('El horizonte debe estar entre 1 y 365 días.');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(
        ProductionCapacitySnapshot(
          weeklyCapacityPoints: weekly,
          reservedPointsByDate: Map.unmodifiable(_reserved),
          overridesByDate: Map.unmodifiable(_overrides),
          horizonDays: horizon,
          timezone: widget.initial.timezone,
        ),
      );
      if (mounted) _show('Capacidad actualizada.');
    } catch (error) {
      if (mounted) _show('No se pudo guardar: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editDate([String? existingKey]) async {
    final initialDate = existingKey == null
        ? DateTime.now()
        : DateTime.tryParse(existingKey) ?? DateTime.now();
    final result = await showDialog<_DayDraft>(
      context: context,
      builder: (context) => _DayEditorDialog(
        initialDate: initialDate,
        reservedPoints: existingKey == null ? 0 : _reserved[existingKey] ?? 0,
        dayOverride: existingKey == null ? null : _overrides[existingKey],
        dateLocked: existingKey != null,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (result.reservedPoints == 0) {
        _reserved.remove(result.key);
      } else {
        _reserved[result.key] = result.reservedPoints;
      }
      if (result.override == null) {
        _overrides.remove(result.key);
      } else {
        _overrides[result.key] = result.override!;
      }
    });
  }

  void _show(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final dateKeys = {..._reserved.keys, ..._overrides.keys}.toList()..sort();
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      children: [
        const _CapacityInfo(),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900 ? 2 : 1;
            final width = (constraints.maxWidth - (columns - 1) * 18) / columns;
            return Wrap(
              spacing: 18,
              runSpacing: 18,
              children: [
                SizedBox(width: width, child: _weeklyCard(context)),
                SizedBox(width: width, child: _datesCard(context, dateKeys)),
              ],
            );
          },
        ),
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
            label: const Text('Guardar capacidad'),
          ),
        ),
      ],
    );
  }

  Widget _weeklyCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Capacidad semanal',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Puntos máximos disponibles por día de la semana.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            for (var weekday = 1; weekday <= 7; weekday++) ...[
              Row(
                children: [
                  Expanded(child: Text(_weekdayNames[weekday]!)),
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: _weekly[weekday],
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Puntos'),
                    ),
                  ),
                ],
              ),
              if (weekday != 7) const SizedBox(height: 10),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _horizon,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Días disponibles para reservar',
                helperText: 'Entre 1 y 365 días.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _datesCard(BuildContext context, List<String> dateKeys) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Reservas y excepciones',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Agregar fecha',
                  onPressed: _editDate,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            Text(
              'Registra puntos ya comprometidos, cierres o una capacidad especial.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (dateKeys.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No hay fechas especiales.')),
              )
            else
              for (final key in dateKeys) _dateTile(context, key),
          ],
        ),
      ),
    );
  }

  Widget _dateTile(BuildContext context, String key) {
    final date = DateTime.tryParse(key);
    final override = _overrides[key];
    final reserved = _reserved[key] ?? 0;
    final description = <String>[
      '$reserved puntos reservados',
      if (override?.isClosed ?? false) 'Cerrado',
      if (override?.capacityPoints != null)
        'Capacidad ${override!.capacityPoints}',
      if (override?.reason.isNotEmpty ?? false) override!.reason,
    ].join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: override?.isClosed ?? false
            ? AppColors.pinkSoft
            : AppColors.canvas,
        child: Icon(
          override?.isClosed ?? false
              ? Icons.event_busy_outlined
              : Icons.event_available_outlined,
        ),
      ),
      title: Text(date == null ? key : DateFormat('dd/MM/yyyy').format(date)),
      subtitle: Text(description),
      trailing: Wrap(
        spacing: 2,
        children: [
          IconButton(
            tooltip: 'Editar fecha',
            onPressed: () => _editDate(key),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Quitar fecha',
            onPressed: () => setState(() {
              _reserved.remove(key);
              _overrides.remove(key);
            }),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _DayDraft {
  const _DayDraft({
    required this.key,
    required this.reservedPoints,
    required this.override,
  });

  final String key;
  final int reservedPoints;
  final ProductionDayOverride? override;
}

class _DayEditorDialog extends StatefulWidget {
  const _DayEditorDialog({
    required this.initialDate,
    required this.reservedPoints,
    required this.dayOverride,
    required this.dateLocked,
  });

  final DateTime initialDate;
  final int reservedPoints;
  final ProductionDayOverride? dayOverride;
  final bool dateLocked;

  @override
  State<_DayEditorDialog> createState() => _DayEditorDialogState();
}

class _DayEditorDialogState extends State<_DayEditorDialog> {
  late DateTime _date;
  late final TextEditingController _reserved;
  late final TextEditingController _capacity;
  late final TextEditingController _reason;
  late bool _closed;

  @override
  void initState() {
    super.initState();
    _date = dateOnly(widget.initialDate);
    _reserved = TextEditingController(text: '${widget.reservedPoints}');
    _capacity = TextEditingController(
      text: widget.dayOverride?.capacityPoints?.toString() ?? '',
    );
    _reason = TextEditingController(text: widget.dayOverride?.reason ?? '');
    _closed = widget.dayOverride?.isClosed ?? false;
  }

  @override
  void dispose() {
    _reserved.dispose();
    _capacity.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (selected != null) setState(() => _date = selected);
  }

  void _submit() {
    final reserved = int.tryParse(_reserved.text.trim());
    final capacityText = _capacity.text.trim();
    final capacity = capacityText.isEmpty ? null : int.tryParse(capacityText);
    if (reserved == null ||
        reserved < 0 ||
        (capacityText.isNotEmpty && (capacity == null || capacity < 0))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa cantidades válidas.')),
      );
      return;
    }
    final reason = _reason.text.trim();
    final hasOverride = _closed || capacity != null || reason.isNotEmpty;
    Navigator.pop(
      context,
      _DayDraft(
        key: dateKey(_date),
        reservedPoints: reserved,
        override: hasOverride
            ? ProductionDayOverride(
                capacityPoints: capacity,
                isClosed: _closed,
                reason: reason,
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Capacidad de una fecha'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fecha'),
              subtitle: Text(DateFormat('dd/MM/yyyy').format(_date)),
              trailing: widget.dateLocked
                  ? null
                  : IconButton(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_month_outlined),
                    ),
            ),
            TextField(
              controller: _reserved,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Puntos ya reservados',
                helperText: 'Carga confirmada para ese día.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _capacity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Capacidad especial',
                helperText: 'Vacío para usar la capacidad semanal.',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Taller cerrado'),
              value: _closed,
              onChanged: (value) => setState(() => _closed = value),
            ),
            TextField(
              controller: _reason,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Motivo o nota pública',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Aplicar')),
      ],
    );
  }
}

class _CapacityInfo extends StatelessWidget {
  const _CapacityInfo();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.pinkSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'Un punto representa aproximadamente 30 minutos del trabajo combinado '
        'del taller. Ajusta esta equivalencia con tiempos reales antes de '
        'confirmar fechas automáticamente.',
      ),
    );
  }
}

class _CapacityMessage extends StatelessWidget {
  const _CapacityMessage({required this.title, required this.message});

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
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            SelectableText(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
