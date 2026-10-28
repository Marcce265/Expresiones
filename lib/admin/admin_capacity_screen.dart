import 'package:flutter/material.dart';

import '../models/production_capacity.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/app_notice.dart';
import 'admin_operations_repository.dart';
import 'admin_ui.dart';

class AdminCapacityScreen extends StatelessWidget {
  const AdminCapacityScreen({super.key, required this.repository});

  final AdminOperationsRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Días de entrega'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        shape: const Border(
          bottom: BorderSide(color: AppColors.border, width: .8),
        ),
      ),
      body: StreamBuilder<ProductionCapacitySnapshot>(
        stream: repository.watchCapacity(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ScheduleMessage(
              title: 'No se pudieron cargar los días',
              message: '${snapshot.error}',
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final schedule = snapshot.data!;
          return _DeliveryDaysEditor(
            key: ValueKey(
              schedule.updatedAt?.millisecondsSinceEpoch ??
                  schedule.toMap().toString(),
            ),
            initial: schedule,
            onSave: repository.saveCapacity,
          );
        },
      ),
    );
  }
}

class _DeliveryDaysEditor extends StatefulWidget {
  const _DeliveryDaysEditor({
    super.key,
    required this.initial,
    required this.onSave,
  });

  final ProductionCapacitySnapshot initial;
  final Future<void> Function(ProductionCapacitySnapshot) onSave;

  @override
  State<_DeliveryDaysEditor> createState() => _DeliveryDaysEditorState();
}

class _DeliveryDaysEditorState extends State<_DeliveryDaysEditor> {
  late final Set<int> _pickupWeekdays;
  late final Set<int> _shalomWeekdays;
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
    _pickupWeekdays = Set.of(widget.initial.weekdaysForDelivery('pickup'));
    _shalomWeekdays = Set.of(widget.initial.weekdaysForDelivery('shalom'));
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_pickupWeekdays.isEmpty || _shalomWeekdays.isEmpty) {
      showAppNotice(
        context,
        'Selecciona al menos un día para cada forma de entrega.',
        tone: AppNoticeTone.error,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(
        ProductionCapacitySnapshot(
          weeklyCapacityPoints: widget.initial.weeklyCapacityPoints,
          deliveryWeekdays: Map.unmodifiable({
            'pickup': Set.unmodifiable(_pickupWeekdays),
            'shalom': Set.unmodifiable(_shalomWeekdays),
          }),
          reservedPointsByDate: widget.initial.reservedPointsByDate,
          overridesByDate: widget.initial.overridesByDate,
          horizonDays: widget.initial.horizonDays,
          timezone: widget.initial.timezone,
        ),
      );
      if (mounted) {
        showAppNotice(
          context,
          'Días de entrega actualizados.',
          tone: AppNoticeTone.success,
        );
      }
    } catch (error) {
      if (mounted) {
        showAppNotice(
          context,
          'No se pudieron guardar los días: $error',
          tone: AppNoticeTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        ResponsivePage(
          maxWidth: 980,
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AdminSectionIntro(
                eyebrow: 'Calendario de entrega',
                title: 'Días disponibles',
                description: 'Elige qué días podrán seleccionar tus clientes para recojo y para envíos por Shalom.',
              ),
              const SizedBox(height: 18),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _methodDays(
                        context,
                        icon: Icons.storefront_outlined,
                        title: 'Recojo en Huancayo',
                        description: 'Días disponibles para recoger un pedido terminado.',
                        selected: _pickupWeekdays,
                      ),
                      const Divider(height: 42),
                      _methodDays(
                        context,
                        icon: Icons.local_shipping_outlined,
                        title: 'Envíos por Shalom',
                        description:
                            'Días en que salen pedidos hacia las agencias.',
                        selected: _shalomWeekdays,
                      ),
                    ],
                  ),
                ),
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
                      : const Icon(Icons.save_outlined),
                  label: const Text('Guardar días'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _methodDays(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Set<int> selected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.pinkSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
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
                  fontWeight: FontWeight.w500,
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
}

class _ScheduleMessage extends StatelessWidget {
  const _ScheduleMessage({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_busy_outlined, size: 42),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
